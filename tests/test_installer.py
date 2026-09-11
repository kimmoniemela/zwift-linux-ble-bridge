"""Installer safety/flow checks with isolated destinations and stubbed system tools.

Run: python -m unittest discover -s tests -v
No package installation, service changes, downloads or real credentials.
"""
import os
from pathlib import Path
import pty
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zwift-installer-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.mock = self.base / "mock"
        self.mock.mkdir()
        self.env = dict(os.environ, PATH=f"{self.mock}:{os.environ['PATH']}")
        self.env["EVENTS"] = str(self.base / "events")
        self.tool("pacman", '[[ $1 == -Q ]]')
        self.tool("sudo", 'printf "sudo %s\\n" "$*" >> "$EVENTS"')
        self.tool("systemctl", 'printf "systemctl %s\\n" "$*" >> "$EVENTS"')
        self.tool("less", ':')
        self.tool("makepkg", 'printf "makepkg\\n" >> "$EVENTS"')

    def tool(self, name, body):
        p = self.mock / name
        p.write_text("#!/bin/bash\nset -eu\n" + body + "\n")
        p.chmod(0o755)

    def run_shell(self, body, interactive=False):
        # Override task-owned destinations only; never replace HOME.
        assignments = {
            "BIN": self.base / "bin", "PREFIX": self.base / "qz",
            "CACHE": self.base / "cache", "STATE": self.base / "state",
            "QZ_CONFIG": self.base / "config/qz.conf",
            "ZWIFT_CONFIG": self.base / "config/zwift.conf",
        }
        setup = f"source {shlex.quote(str(ROOT / 'install.sh'))}\n"
        setup += "\n".join(f"{k}={shlex.quote(str(v))}" for k, v in assignments.items())
        if interactive:
            master, slave = pty.openpty()
            try:
                return subprocess.run(["bash", "-c", setup + "\n" + body],
                                      env=self.env, stdin=slave, capture_output=True,
                                      text=True, timeout=20)
            finally:
                os.close(master)
                os.close(slave)
        return subprocess.run(["bash", "-c", setup + "\n" + body],
                              env=self.env, input="", capture_output=True,
                              text=True, timeout=20)

    def test_check_does_not_install_or_write(self):
        r = self.run_shell("main --check")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse((self.base / "events").exists())
        self.assertFalse((self.base / "state").exists())
        self.assertFalse((self.base / "config").exists())

    def test_invalid_jobs_fails_before_changes(self):
        for args in ("--jobs 0", "--jobs nope", "--jobs"):
            r = self.run_shell("main " + args)
            self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.base / "state").exists())

    def test_unsupported_architecture_fails_before_changes(self):
        self.tool("uname", 'printf "aarch64\\n"')
        r = self.run_shell("main --check")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Only x86-64", r.stderr)
        self.assertFalse((self.base / "events").exists())

    def test_existing_settings_are_preserved_without_execution(self):
        config = self.base / "config"
        config.mkdir()
        target = config / "zwift.conf"
        marker = self.base / "never-execute-settings"
        contents = f'NETWORKING="bridge"\n$(touch {shlex.quote(str(marker))})\n'
        target.write_text(contents)
        r = self.run_shell('install_preserving "$ROOT/config/netbrain-zwift.conf" "$ZWIFT_CONFIG" 600')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(target.read_text(), contents)
        example = Path(str(target) + ".zwift-linux-example")
        self.assertIn('NETWORKING="host"', example.read_text())
        self.assertEqual(example.stat().st_mode & 0o777, 0o600)
        self.assertFalse(marker.exists())

    def test_symlink_destination_is_rejected(self):
        target = self.base / "config"
        target.mkdir()
        (target / "zwift.conf").symlink_to(self.base / "outside")
        r = self.run_shell('install_preserving "$ROOT/config/netbrain-zwift.conf" "$ZWIFT_CONFIG" 600')
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.base / "outside").exists())

    def test_aur_refusal_never_builds(self):
        self.tool("pacman", 'exit 1')
        r = self.run_shell('checkout_source() { :; }; LOG="$STATE"; install_aur qt5-charts test')
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.base / "events").exists())

    def test_official_package_preferred_to_aur(self):
        self.tool("pacman", '[[ $1 == -Si ]]')
        r = self.run_shell('LOG="$STATE"; install_aur qt5-charts test')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("sudo pacman -S --needed qt5-charts", (self.base / "events").read_text())

    def flow_setup(self):
        # Stub only external build/install boundaries; exercise installer flow.
        self.tool("git", ':')
        self.tool("qmake", ':')
        self.tool("make", '''
[[ ${MOCK_MAKE_FAIL:-0} == 0 ]] || exit 23
printf '#!/bin/bash\nprintf "smoke-test\\\\n" >> "$EVENTS"\nexit "${MOCK_SMOKE_FAIL:-0}"\n' > qdomyos-zwift
chmod +x qdomyos-zwift
''')
        return r'''
confirm() { :; }
checkout_source() {
    mkdir -p "$2/src/icons" "$2/bin"
    printf 'licence\n' > "$2/LICENSE"
    printf 'icon\n' > "$2/src/icons/icon.png"
    cat > "$2/bin/install.sh" <<'UPSTREAM'
#!/bin/bash
printf '#!/bin/bash\nexit 0\n' > "$XDG_BIN_HOME/zwift"
chmod +x "$XDG_BIN_HOME/zwift"
UPSTREAM
}
main
'''

    def test_fresh_flow_and_repeat_preserve_user_changes(self):
        r = self.run_shell(self.flow_setup(), interactive=True)
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        self.assertTrue((self.base / "qz/bin/qdomyos-zwift").is_file())
        self.assertIn("smoke-test", (self.base / "events").read_text())
        config = self.base / "config/qz.conf"
        config.write_text("[General]\nheart_rate_belt_name=My sensor\n")
        binary = self.base / "qz/bin/qdomyos-zwift"
        before = binary.read_bytes()
        r = self.run_shell(self.flow_setup(), interactive=True)
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        self.assertIn("My sensor", config.read_text())
        self.assertEqual(binary.read_bytes(), before)

    def test_failed_build_never_installs_qz_binary(self):
        self.env["MOCK_MAKE_FAIL"] = "1"
        r = self.run_shell(self.flow_setup(), interactive=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.base / "qz/bin/qdomyos-zwift").exists())
        self.assertNotIn("smoke-test", (self.base / "events").read_text())
        self.assertIn("Installation stopped", r.stderr)

    def test_failed_smoke_test_never_installs_qz_binary(self):
        self.env["MOCK_SMOKE_FAIL"] = "24"
        r = self.run_shell(self.flow_setup(), interactive=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse((self.base / "qz/bin/qdomyos-zwift").exists())
        self.assertIn("smoke-test", (self.base / "events").read_text())


if __name__ == "__main__":
    unittest.main()
