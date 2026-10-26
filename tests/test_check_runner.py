import contextlib
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from check import run


class GodotCheckRunnerTests(unittest.TestCase):
    def invoke(self, outcomes):
        with patch("check.platform.system", return_value="Windows"), \
                patch("check.subprocess.run", side_effect=outcomes), \
                contextlib.redirect_stdout(io.StringIO()):
            return run(["godot"], marker="PASS", godot=True)

    def test_requires_clean_exit_after_shutdown_crash(self):
        result = self.invoke([
            subprocess.CompletedProcess([], 0xC0000005, "PASS\n"),
            subprocess.CompletedProcess([], 0, "PASS\n"),
        ])
        self.assertEqual(result, "PASS")

    def test_repeated_shutdown_crashes_fail(self):
        outcomes = [subprocess.CompletedProcess([], 0xC0000005, "PASS\n")] * 3
        with self.assertRaises(RuntimeError):
            self.invoke(outcomes)

    def test_script_error_is_not_hidden_by_shutdown_retry(self):
        with self.assertRaises(RuntimeError):
            self.invoke([subprocess.CompletedProcess([], 0xC0000005, "SCRIPT ERROR: bad\nPASS")])

    def test_other_exit_errors_fail_without_retry(self):
        with self.assertRaises(RuntimeError):
            self.invoke([subprocess.CompletedProcess([], 1, "PASS\n")])
