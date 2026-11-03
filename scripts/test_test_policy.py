"""Behavioral checks for test-mode dispatch, using disposable repositories."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('test-policy.py')
spec = importlib.util.spec_from_file_location('policy', SCRIPT)
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class TestPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        (self.root / 'scripts/test-policy.py').write_bytes(SCRIPT.read_bytes())
        self.marker = self.root / 'ran'
        self.config = {'unit': {'paths': ['src/*'], 'command': [sys.executable, '-c',
                       "from pathlib import Path; Path('ran').write_text('yes')"]}}
        (self.root / '.test-policy.json').write_text(json.dumps(self.config))
        self.git('init', '-q')
        self.git('add', '.')
        self.git('-c', 'user.name=Test', '-c', 'user.email=test@example.org', 'commit', '-qm', 'Initial')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True, timeout=20)

    def run_policy(self, *args):
        env = {k: v for k, v in os.environ.items() if not k.startswith(('TEST_', 'GITHUB_', 'CI_'))}
        return subprocess.run([sys.executable, str(self.root / 'scripts/test-policy.py'), *args],
                              cwd=self.root, env=env, text=True, capture_output=True, timeout=20)

    def test_manual_skips_even_without_git_or_valid_base(self):
        result = self.run_policy('--mode', 'manual', '--base', 'missing')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())
        self.assertIn('Tests not run', result.stdout)

    def test_release_executes_without_a_diff(self):
        result = self.run_policy('--mode', 'release')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.marker.read_text(), 'yes')

    def test_targeted_uses_changed_component_only(self):
        (self.root / 'README.md').write_text('Documentation')
        self.assertEqual(self.run_policy().returncode, 0)
        self.assertFalse(self.marker.exists())
        (self.root / 'src').mkdir()
        (self.root / 'src/app.py').write_text('pass')
        result = self.run_policy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())

    def test_bad_base_and_mode_fail_without_fallback(self):
        for args in (('--base', 'missing'), ('--mode', 'unknown'), ('--base', '0' * 40)):
            with self.subTest(args=args):
                self.assertNotEqual(self.run_policy(*args).returncode, 0)
                self.assertFalse(self.marker.exists())

    def test_plan_does_not_execute(self):
        result = self.run_policy('--mode', 'release', '--plan')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())

    def test_failure_is_propagated(self):
        self.config['unit']['command'] = [sys.executable, '-c', 'raise SystemExit(7)']
        (self.root / '.test-policy.json').write_text(json.dumps(self.config))
        self.assertEqual(self.run_policy('--mode', 'release').returncode, 7)

    def test_dependency_selection_includes_transitive_consumers(self):
        graph = {'core': [], 'service': ['core'], 'tests': ['service'], 'other': []}
        self.assertEqual(policy.dependents({'core'}, graph), {'core', 'service', 'tests'})

    def test_swift_selection_is_filtered(self):
        data = {'targets': [{'name': 'Core', 'path': 'Sources/Core', 'type': 'library'},
                {'name': 'CoreTests', 'path': 'Tests/CoreTests', 'type': 'test', 'target_dependencies': ['Core']},
                {'name': 'OtherTests', 'path': 'Tests/OtherTests', 'type': 'test'}]}
        with patch.object(policy, 'output', return_value=json.dumps(data)):
            self.assertEqual(policy.native_targets('swift', policy.ROOT, {'Sources/Core/Model.swift'}),
                             ['--filter', 'CoreTests'])
        cargo = {'workspace_members': ['core-id', 'client-id', 'other-id'], 'packages': [
            {'id': 'core-id', 'name': 'core', 'manifest_path': str(policy.ROOT / 'crates/core/Cargo.toml'), 'dependencies': []},
            {'id': 'client-id', 'name': 'client', 'manifest_path': str(policy.ROOT / 'crates/client/Cargo.toml'), 'dependencies': [{'name': 'core'}]},
            {'id': 'other-id', 'name': 'other', 'manifest_path': str(policy.ROOT / 'crates/other/Cargo.toml'), 'dependencies': []}]}
        with patch.object(policy, 'output', return_value=json.dumps(cargo)):
            self.assertEqual(policy.native_targets('cargo', policy.ROOT, {'crates/core/src/lib.rs'}),
                             ['-p', 'client', '-p', 'core'])
        packages = [{'ImportPath': 'app/core', 'Dir': str(policy.ROOT / 'core')},
                    {'ImportPath': 'app/client', 'Dir': str(policy.ROOT / 'client'), 'Imports': ['app/core']},
                    {'ImportPath': 'app/other', 'Dir': str(policy.ROOT / 'other')}]
        with patch.object(policy, 'output', return_value='\n'.join(json.dumps(p) for p in packages)):
            self.assertEqual(policy.native_targets('go', policy.ROOT, {'core/main.go'}),
                             ['app/client', 'app/core'])


if __name__ == '__main__':
    unittest.main()
