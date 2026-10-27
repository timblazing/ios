# T3 Mini 0.1.0 device checklist

Target: iPad mini 2, iOS 10.3.3. User confirmed on 2026-10-26 that threads and conversations work. Remaining checks require device verification.

- [ ] Launch T3 Mini; confirm the connection form and sidebar render without clipping.
- [x] Pair using a fresh read-only link or a private pre-provisioned install (user confirmed working conversations).
- [x] Confirm the active thread list appears (user verified).
- [ ] Confirm the displayed host label is correct.
- [x] Open a conversation (user verified).
- [ ] Compare its user/assistant text with desktop T3.
- [ ] Check a forked conversation with inherited messages.
- [ ] Refresh a conversation while an assistant reply is being written.
- [ ] Relaunch and connect without a code; confirm Keychain persistence works.
- [ ] Lock/unlock and background/foreground; reconnect with no credential re-entry.
- [ ] Rotate portrait/landscape with the keyboard open and closed.
- [ ] Scroll a long reply; confirm no severe hitching or unexpected app termination.
- [ ] Disconnect Wi-Fi or use an unreachable address; confirm a clear recoverable error.
- [ ] Use an invalid/consumed pairing credential; confirm no raw token appears in errors.
- [ ] Forget the session; confirm reconnect without a fresh link is denied.
- [ ] Confirm the app offers no send, terminal, or approval controls.

This is read-only and refresh-based. Tools, attachments, archived threads, rich
formatting, and earlier-history pagination are intentionally absent in 0.1.0.
