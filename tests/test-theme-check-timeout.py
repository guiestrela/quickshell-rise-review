#!/usr/bin/env python3
"""Exercise delayed remote checks and pinned theme apply in isolated Git repos."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GIT = shutil.which("git") or "git"


class ThemeCheckTimeoutTests(unittest.TestCase):
    def test_default_probe_allows_slow_remote_and_pinned_update(self):
        with tempfile.TemporaryDirectory(prefix="theme-timeout-", dir=os.environ["TMPDIR"]) as tmp:
            base = Path(tmp)
            seed, remote, themes = base / "seed", base / "remote.git", base / "themes"
            themes.mkdir()
            env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
            for key in ("QS_THEME_TIMEOUT", "QS_THEME_FETCH_TIMEOUT", "QS_THEME_BUDGET"):
                env.pop(key, None)

            def git(*args):
                return subprocess.run([GIT, *map(str, args)], env=env, text=True,
                                      capture_output=True, check=True).stdout.strip()

            git("init", "--bare", remote)
            git("init", "-b", "main", seed)
            git("-C", seed, "config", "user.name", "Theme Test")
            git("-C", seed, "config", "user.email", "test@example.invalid")
            (seed / "theme.txt").write_text("initial\n")
            git("-C", seed, "add", "theme.txt")
            git("-C", seed, "commit", "-m", "initial")
            git("-C", seed, "remote", "add", "origin", remote)
            git("-C", seed, "push", "-u", "origin", "main")
            git("--git-dir", remote, "symbolic-ref", "HEAD", "refs/heads/main")
            git("clone", remote, themes / "demo")
            (seed / "theme.txt").write_text("updated\n")
            git("-C", seed, "commit", "-am", "update")
            git("-C", seed, "push", "origin", "main")
            target = git("-C", seed, "rev-parse", "HEAD")

            bindir = base / "bin"
            bindir.mkdir()
            shim = bindir / "git"
            shim.write_text("#!/usr/bin/env python3\nimport os,sys,time\n"
                            "if 'ls-remote' in sys.argv[1:]: time.sleep(10.1)\n"
                            f"os.execv({GIT!r}, [{GIT!r}, *sys.argv[1:]])\n")
            shim.chmod(0o755)
            current = base / "current"
            current.write_text("demo\n")
            state = base / "state.json"
            env.update(PATH=str(bindir) + os.pathsep + env["PATH"],
                       QS_THEMES_DIR=str(themes), QS_THEME_STATE=str(state),
                       QS_THEME_LOCK=str(base / "lock"), QS_CURRENT_FILE=str(current))
            checked = subprocess.run(["bash", str(ROOT / "scripts/qs-theme-update-check.sh")],
                                     env=env, text=True, capture_output=True, timeout=60)
            self.assertEqual(checked.returncode, 0, checked.stderr)
            data = json.loads(state.read_text())
            self.assertEqual(data["reachable"], 1, "slow reachable remote must not be marked offline")
            self.assertFalse(data["degraded"])
            self.assertEqual(data["outdated"], 1)
            self.assertEqual(data["themes"][0]["state"], "clean")
            self.assertEqual(data["themes"][0]["targetCommit"], target)
            applied = subprocess.run(["bash", str(ROOT / "scripts/qs-theme-apply-update.sh"), "demo"],
                                     env=env, text=True, capture_output=True, timeout=30)
            self.assertEqual(applied.returncode, 0, applied.stdout + applied.stderr)
            self.assertEqual(git("-C", themes / "demo", "rev-parse", "HEAD"), target)


if __name__ == "__main__":
    unittest.main()
