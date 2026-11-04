#!/usr/bin/env python3
"""Exercise profile rejection gates without using credentials or contacting Apple."""
import copy
import datetime
import hashlib
import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location('sign_canary', pathlib.Path(__file__).with_name('sign-canary.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ProfileGates(unittest.TestCase):
    def setUp(self):
        self.now = datetime.datetime(2026, 10, 30)
        self.bundle = 'com.local.launchcanary.legacy'
        self.identity = hashlib.sha1(b'test certificate').hexdigest().upper()
        self.profile = dict(CreationDate=self.now - datetime.timedelta(days=1),
                            ExpirationDate=self.now + datetime.timedelta(days=1),
                            ProvisionedDevices=['test-ipad'], ApplicationIdentifierPrefix=['TEAM'],
                            TeamIdentifier=['TEAM'], DeveloperCertificates=[b'test certificate'],
                            Entitlements={'application-identifier': 'TEAM.' + self.bundle,
                                          'com.apple.developer.team-identifier': 'TEAM',
                                          'get-task-allow': True})

    def validate(self, profile):
        return module.validate_profile(profile, self.bundle, 'test-ipad', self.identity, self.now)

    def test_matching_profile(self):
        self.assertEqual(self.validate(self.profile), self.profile['Entitlements'])

    def test_reject_invalid_authorizations(self):
        cases = [
            ('expired', 'ExpirationDate', self.now),
            ('future', 'CreationDate', self.now + datetime.timedelta(days=1)),
            ('other device', 'ProvisionedDevices', ['other-device']),
            ('other certificate', 'DeveloperCertificates', [b'other certificate']),
            ('other team', 'TeamIdentifier', ['OTHER']),
        ]
        for name, key, value in cases:
            with self.subTest(name=name):
                profile = copy.deepcopy(self.profile)
                profile[key] = value
                with self.assertRaises(ValueError):
                    self.validate(profile)

    def test_reject_unrelated_or_wildcard_app(self):
        for app in ['TEAM.com.example.other', 'TEAM.*', 'OTHER.' + self.bundle]:
            with self.subTest(app=app):
                profile = copy.deepcopy(self.profile)
                profile['Entitlements']['application-identifier'] = app
                with self.assertRaises(ValueError):
                    self.validate(profile)

    def test_reject_non_canary(self):
        with self.assertRaises(ValueError):
            module.validate_profile(self.profile, 'com.example.other', 'test-ipad', self.identity, self.now)

    def test_reject_non_development(self):
        self.profile['Entitlements']['get-task-allow'] = False
        with self.assertRaises(ValueError):
            self.validate(self.profile)


if __name__ == '__main__':
    unittest.main()
