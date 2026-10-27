import importlib.util
from pathlib import Path
import unittest
from urllib.parse import urlencode

spec = importlib.util.spec_from_file_location('gateway', Path(__file__).resolve().parents[1] / 'lan-gateway.py')
gateway = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gateway)


class Routes(unittest.TestCase):
    def test_only_read_endpoints(self):
        for path in ['/.well-known/t3/environment', '/api/orchestration/shell', '/api/orchestration/threads/abc-123/bounded']:
            self.assertTrue(gateway.allowed('GET', path))
        for path in ['/api/orchestration/command', '/oauth/token', '/api/orchestration/threads/../bounded', '/api/orchestration/shell?token=abc']:
            self.assertFalse(gateway.allowed('GET', path))
        self.assertFalse(gateway.allowed('POST', '/api/orchestration/shell'))

    def test_pairing_scope_cannot_escalate(self):
        form = dict(grant_type='urn:ietf:params:oauth:grant-type:token-exchange', subject_token='test-code',
                    subject_token_type='urn:t3:params:oauth:token-type:environment-bootstrap',
                    requested_token_type='urn:ietf:params:oauth:token-type:access_token', scope='orchestration:read')
        self.assertTrue(gateway.allowed('POST', '/oauth/token', urlencode(form).encode()))
        form['scope'] = 'orchestration:operate'
        self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(form).encode()))
        form['scope'] = 'orchestration:read'
        self.assertFalse(gateway.allowed('POST', '/oauth/token', urlencode(form).encode() + b'&scope=access%3Awrite'))
        self.assertFalse(gateway.allowed('POST', '/oauth/token', b'\xff'))


if __name__ == '__main__':
    unittest.main()
