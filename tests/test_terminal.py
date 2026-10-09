"""Installer and capture contracts; fake tmux never contacts a VPS."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / '08-terminal.sh'


class TerminalTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        bindir = self.root / 'bin'
        bindir.mkdir()
        tmux = bindir / 'tmux'
        tmux.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$HOME/tmux.calls"
case "$*" in
  *has-session*) exit "${SESSION_MISSING:-0}" ;;
  *capture-pane*)
    if [ -n "${CAPTURE_FILE:-}" ]; then cat "$CAPTURE_FILE"; else printf 'command\\n  indented output  \\n\\n'; fi
    exit "${CAPTURE_FAIL:-0}" ;;
esac
''')
        tmux.chmod(0o700)
        self.env = {**os.environ, 'HOME': str(self.root),
                    'PATH': str(bindir) + ':' + os.environ['PATH'], 'TMUX': ''}

    def install(self):
        return subprocess.run(['bash', str(SCRIPT), '--no-attach'],
                              env=self.env, capture_output=True, text=True)

    def helper(self, command, **env):
        return subprocess.run([str(self.root / '.local/bin/ocs'), command],
                              env={**self.env, **env}, capture_output=True, text=True)

    def test_install_twice_preserves_file(self):
        self.assertEqual(self.install().returncode, 0)
        path = self.root / '.local/bin/ocs'
        inode = path.stat().st_ino
        self.assertEqual(path.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.install().returncode, 0)
        self.assertEqual(path.stat().st_ino, inode)
        self.assertEqual(list(path.parent.glob('.ocs.*')), [])

    def test_conflicting_file_is_not_changed(self):
        path = self.root / '.local/bin/ocs'
        path.parent.mkdir(parents=True)
        path.write_text('unrelated helper')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(path.read_text(), 'unrelated helper')

    def test_missing_session_fails_without_output(self):
        self.install()
        result = self.helper('last', SESSION_MISSING='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')
        self.assertIn('No capture session', result.stderr)

    def test_capture_keeps_indentation_and_removes_trailing_blank(self):
        self.install()
        result = self.helper('last')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, 'command\n  indented output\n')
        self.assertIn('capture-pane -p -J -S -300 -t =ocs-copy:',
                      (self.root / 'tmux.calls').read_text())

    def test_capture_failure_is_not_clipboard_success(self):
        self.install()
        result = self.helper('last', CAPTURE_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_caps_capture_to_300_lines_and_preserves_unicode(self):
        self.install()
        payload = self.root / 'capture.txt'
        payload.write_text('\n'.join(f'line {i} → ✓' for i in range(500)) + '\n')
        result = self.helper('last', CAPTURE_FILE=str(payload))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.splitlines()), 300)
        self.assertTrue(result.stdout.startswith('line 200 → ✓\n'))

    def test_empty_capture(self):
        self.install()
        payload = self.root / 'capture.txt'
        payload.write_text('\n\n')
        self.assertEqual(self.helper('last', CAPTURE_FILE=str(payload)).stdout, '')

    def test_shell_uses_dedicated_socket(self):
        self.install()
        self.assertEqual(self.helper('shell').returncode, 0)
        self.assertIn('-L ocs-copy -f /dev/null new-session -A -s ocs-copy',
                      (self.root / 'tmux.calls').read_text())

    def test_nested_tmux_fails_with_detach_instruction(self):
        self.install()
        result = self.helper('shell', TMUX='existing')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Detach', result.stderr)


if __name__ == '__main__':
    unittest.main()
