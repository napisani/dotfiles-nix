"""Rollout harness tests with fake CLI boundaries and disposable HOMEs."""

import json
import os
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from rollout import checks, console, data, plan, steps  # noqa: E402
from rollout.common import DOTFILES, RolloutError, allowlisted_link, load_host, move_aside  # noqa: E402

STORE = "/nix/store/00000000000000000000000000000000-home-manager-files"


class Fixture(unittest.TestCase):
    """A disposable HOME, run directory and fake-command directory first on PATH."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="rollout-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.home = self.root / "home"
        self.run_dir = self.root / "run"
        self.bin = self.root / "bin"
        self.calls = self.root / "calls.jsonl"
        for directory in (self.home, self.run_dir, self.bin):
            directory.mkdir()
        environment = patch.dict(os.environ, {"PATH": f"{self.bin}:{os.environ['PATH']}", "CALLS": str(self.calls)})
        environment.start()
        self.addCleanup(environment.stop)

    def fake(self, name, body="", status=0):
        """A fake command that records its argv and environment, runs `body`, then exits `status`."""
        script = self.bin / name
        script.write_text(textwrap.dedent(f"""\
            #!{sys.executable}
            import json, os, sys
            with open(os.environ["CALLS"], "a") as calls:
                calls.write(json.dumps({{"argv": [{name!r}, *sys.argv[1:]],
                    "prefix": os.environ.get("MISE_SYSTEM_BREW_PREFIX"),
                    "autoremove": os.environ.get("HOMEBREW_NO_AUTOREMOVE")}}) + "\\n")
            args = sys.argv[1:]
        """) + textwrap.dedent(body) + f"\nsys.exit({status})\n")
        script.chmod(0o755)
        return script

    def recorded(self, name=None):
        if not self.calls.exists():
            return []
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        return [call for call in calls if name is None or call["argv"][0] == name]

    def write(self, relative, text="data\n"):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path


class CommonTests(Fixture):
    def test_only_store_and_checkout_links_are_allowlisted(self):
        store = self.home / "store-link"
        store.symlink_to(f"{STORE}/.bashrc")
        checkout = self.home / "checkout-link"
        checkout.symlink_to(DOTFILES / "bootstrap.sh")
        other = self.home / "other-link"
        other.symlink_to(self.root / "elsewhere")
        regular = self.write("regular")
        self.assertTrue(allowlisted_link(store))
        self.assertTrue(allowlisted_link(checkout))
        self.assertFalse(allowlisted_link(other))
        self.assertFalse(allowlisted_link(regular))

    def test_move_aside_never_overwrites_an_earlier_move(self):
        first = self.write("file", "one")
        move_aside(first, self.run_dir, "file")
        second = self.write("file", "two")
        with self.assertRaises(RolloutError):
            move_aside(second, self.run_dir, "file")
        self.assertEqual((self.run_dir / "moved/file").read_text(), "one")
        self.assertEqual(second.read_text(), "two")

    def test_host_decisions_and_role_declarations(self):
        work = load_host("nicks-loancrate-mbp")
        self.assertEqual(work.flake_name, "Nicks-Loancrate-MacBook-Pro")
        self.assertIn("brew-cask:omniwm", work.casks())
        self.assertTrue(work.needs_approval("brew-cask:karabiner-elements"))
        personal = load_host("nicks-mbp")
        self.assertIn("brew-cask:discord", personal.casks())
        self.assertIn("helm", personal.declarations()["tools"])
        maclab = load_host("maclab")
        self.assertNotIn("brew-cask:docker-desktop", maclab.casks())
        self.assertNotIn("brew-cask:omniwm", maclab.casks())
        self.assertEqual(load_host("supermicro").casks(), [])
        for host in ["nicks-mbp", "nicks-loancrate-mbp", "maclab", "supermicro"]:
            decisions = load_host(host).decisions
            self.assertEqual(decisions["controller"], "maclab")
            self.assertNotRegex(json.dumps(decisions), r"\d+\.\d+\.\d+\.\d+|fe80:", "addresses stay private")


class DataTests(Fixture):
    def host(self, protected, regenerable=()):
        host = load_host("maclab")
        host.decisions = {**host.decisions, "data": {"protected": protected, "regenerable": list(regenerable)}}
        return host

    def test_backup_keeps_data_and_skips_regenerable_paths(self):
        self.write(".example/settings.json", "{}")
        self.write(".example/cache/blob", "x" * 100)
        (self.home / ".example/link").symlink_to("settings.json")
        host = self.host([".example"], [".example/cache"])
        saved = data.backup(self.run_dir, self.home, host)
        self.assertIn(".example/settings.json", saved["entries"])
        self.assertNotIn(".example/cache/blob", saved["entries"])
        self.assertEqual(saved["entries"][".example/link"]["target"], "settings.json")
        self.assertEqual((self.run_dir / "backup/files/.example/settings.json").read_text(), "{}")
        self.write(".example/settings.json", "changed")
        again = data.backup(self.run_dir, self.home, host)
        self.assertEqual(again["created"], saved["created"])
        self.assertEqual((self.run_dir / "backup/files/.example/settings.json").read_text(), "{}")

    def test_regenerable_patterns_never_hide_credentials_or_app_roots(self):
        spec = {"credentials": [".aws"], "regenerable": [".aws", "Library/Containers", "Library/Caches"]}
        self.assertFalse(data.regenerable(".aws/credentials", spec))
        self.assertFalse(data.regenerable("Library/Containers", spec))
        self.assertTrue(data.regenerable("Library/Caches/thing", spec))
        spec["regenerable"].append("Library/Containers/com.docker.docker/Data/vms")
        self.assertTrue(data.regenerable("Library/Containers/com.docker.docker/Data/vms/0/Docker.raw", spec))

    def test_restore_handles_missing_emptied_and_newer_files(self):
        missing = self.write(".example/missing", "keep me")
        emptied = self.write(".example/emptied", "content")
        newer = self.write(".example/newer", "content")
        replaced = self.write(".example/replaced", "content")
        os.utime(emptied, ns=(1, 1_000_000_000))
        data.backup(self.run_dir, self.home, self.host([".example"]))
        missing.unlink()
        emptied.write_text("")
        os.utime(emptied, ns=(1, 1))
        newer.write_text("")
        replaced.unlink()
        replaced.mkdir()
        preview = data.compare_and_restore(self.run_dir, self.home, apply=False)
        self.assertFalse(missing.exists())
        result = data.compare_and_restore(self.run_dir, self.home)
        self.assertEqual(preview, result)
        self.assertEqual(missing.read_text(), "keep me")
        self.assertEqual(emptied.read_text(), "content")
        self.assertEqual((self.run_dir / "moved/.example/emptied").read_text(), "")
        self.assertEqual(newer.read_text(), "")
        reasons = {item["path"]: item["reason"] for item in result["manual"]}
        self.assertIn("newer", reasons[".example/newer"])
        self.assertIn("another type", reasons[".example/replaced"])
        self.assertTrue((self.run_dir / "backup/files/.example/missing").exists(), "backups are never removed")

    def test_estimate_reports_unreadable_directories(self):
        locked = self.write(".example/locked/file").parent
        locked.chmod(0)
        self.addCleanup(locked.chmod, 0o700)
        result = data.estimate(self.home, self.host([".example"]), timeout=60)
        if os.geteuid() != 0:
            self.assertEqual(result["unreadable"], [".example/locked"])


class PlanTests(Fixture):
    def generation(self, files):
        generation = self.root / "generation"
        generation.mkdir()
        (generation / "putter.json").write_text(json.dumps({"files": [
            {"source": f"{STORE}/{relative}", "target": str(self.home / relative)} for relative in files]}))
        (generation / "LaunchAgents").mkdir()
        (generation / "LaunchAgents" / f"{plan.LEGACY_OMNIWM}.plist").write_text("plist")
        root = self.home / plan.HM_ROOT
        root.parent.mkdir(parents=True)
        root.symlink_to(generation)
        return generation

    def test_plan_retires_home_manager_and_moves_unknown_targets(self):
        host = load_host("nicks-mbp")
        self.generation([".bashrc", ".config/git/config"])
        (self.home / ".bashrc").symlink_to(f"{STORE}/.bashrc")
        self.write(".config/git/config", "user edit")
        self.write(".inputrc", "manual")
        self.write(".claude/CLAUDE.md", "rendered")
        self.write(f"Library/LaunchAgents/{plan.LEGACY_OMNIWM}.plist", "plist")
        gh = self.home / plan.RETIRED_LINKS[0]
        gh.parent.mkdir(parents=True)
        gh.symlink_to("/nix/store/1111-gh-stack")
        profile = self.home / plan.HM_PROFILES / "home-manager-1-link"
        profile.parent.mkdir(parents=True)
        profile.symlink_to("/nix/store/2222-home-manager-generation")
        self.write(".config/mise/config.toml", "manual mise config")
        actions = {item["path"]: item["action"] for item in plan.make_plan(host, self.home)["actions"]}
        self.assertEqual(actions[".bashrc"], "remove-link")
        self.assertNotIn(".config/git/config", [p for p, a in actions.items() if a == "remove-link"])
        self.assertEqual(actions[".config/git/config"], "move-aside")
        self.assertEqual(actions[".inputrc"], "move-aside")
        self.assertEqual(actions[".claude/CLAUDE.md"], "preserve-copy")
        self.assertEqual(actions[plan.HM_ROOT], "retire-root")
        self.assertEqual(actions[profile.relative_to(self.home).as_posix()], "retire-root")
        self.assertEqual(actions[f"Library/LaunchAgents/{plan.LEGACY_OMNIWM}.plist"], "retire-agent")
        self.assertEqual(actions[plan.RETIRED_LINKS[0]], "remove-link")
        self.assertEqual(actions[".config/mise/config.toml"], "move-aside")

    def test_apply_moves_never_deletes_and_resumes(self):
        host = load_host("nicks-mbp")
        self.generation([".bashrc"])
        self.fake("nix-store", "from pathlib import Path\nPath(args[args.index('--add-root') + 1]).symlink_to(args[-1])\n")
        self.fake("launchctl", "sys.exit(113 if args[0] == 'print' else 0)\n")
        (self.home / ".bashrc").symlink_to(f"{STORE}/.bashrc")
        self.write(".inputrc", "manual")
        self.write(f"Library/LaunchAgents/{plan.LEGACY_OMNIWM}.plist", "plist")
        planned = plan.make_plan(host, self.home)
        plan.apply_plan(planned, self.run_dir, self.home, host.live_checkout)
        self.assertFalse((self.home / ".bashrc").is_symlink())
        self.assertEqual((self.run_dir / "moved/.inputrc").read_text(), "manual")
        self.assertEqual((self.run_dir / f"moved/Library/LaunchAgents/{plan.LEGACY_OMNIWM}.plist").read_text(), "plist")
        self.assertTrue((self.run_dir / "retired-roots" / plan.HM_ROOT.replace("/", "__")).is_symlink())
        self.write(".inputrc", "recreated by the user")
        plan.apply_plan(planned, self.run_dir, self.home, host.live_checkout)
        self.assertEqual((self.home / ".inputrc").read_text(), "recreated by the user")

    def test_apply_refuses_to_remove_a_link_outside_the_allowlist(self):
        link = self.home / "personal"
        link.symlink_to(self.root / "elsewhere")
        with self.assertRaises(RolloutError):
            plan.apply_plan({"actions": [{"path": "personal", "action": "remove-link"}]},
                            self.run_dir, self.home, DOTFILES)
        self.assertTrue(link.is_symlink())


class ConsoleTests(Fixture):
    def test_create_pins_tools_and_writes_the_user_steps(self):
        self.fake("nix-store", "from pathlib import Path\nPath(args[args.index('--add-root') + 1]).symlink_to(args[-1])\n")
        tmux = self.fake("tmux", "sys.exit(1 if 'has-session' in args else 0)\n")
        result = console.create(self.run_dir, load_host("nicks-mbp"), 120, "nicks-mbp")
        self.assertEqual(result["window_hours"], 5.0)
        self.assertIn("attach -t migration", result["attach"])
        pinned = json.loads((self.run_dir / "toolchain.json").read_text())
        self.assertEqual(pinned["tmux"], str(tmux))
        start = (self.run_dir / "start-privileged-session.sh").read_text()
        self.assertIn("sudo -v", start)
        self.assertIn("unlock-keychain", start)
        self.assertIn("caffeinate", start)
        sends = [call["argv"] for call in self.recorded("tmux") if "send-keys" in call["argv"]]
        self.assertEqual(sends[0][-2:], ["-l", f"set +o history; unset HISTFILE; umask 077; cd {Path.home()}"])
        self.assertEqual(sends[1][-1], "Enter")
        self.assertIn("rollout --host nicks-mbp", (self.run_dir / "rollout.sh").read_text())

    def test_window_tracks_the_estimate_within_the_cap(self):
        self.assertEqual(console.window_seconds(30), 30 * 60 * 2 + 3600)
        self.assertEqual(console.window_seconds(10_000), console.MAX_WINDOW_HOURS * 3600)

    def test_keepalive_stops_at_the_deadline_or_end_marker_and_drops_sudo(self):
        self.fake("sudo")
        console.write_scripts(self.run_dir, 60, macos=False)
        script = self.run_dir / "keepalive-until.sh"
        started = time.time()
        subprocess.run(["bash", script, self.run_dir, str(int(time.time()) + 1)], check=True, timeout=30)
        self.assertLess(time.time() - started, 10)
        self.assertIn(["sudo", "-k"], [call["argv"] for call in self.recorded("sudo")])
        (self.run_dir / "end-privileged-session").touch()
        subprocess.run(["bash", script, self.run_dir, str(int(time.time()) + 3600)], check=True, timeout=30)

    def test_privileges_and_close(self):
        self.fake("sudo")
        sleeper = subprocess.Popen(["sleep", "60"])
        self.addCleanup(sleeper.kill)
        (self.run_dir / "privileged-session.ready").write_text(str(int(time.time()) + 600))
        (self.run_dir / "keepalive.pid").write_text(str(sleeper.pid))
        state = console.privileges(self.run_dir)
        self.assertTrue(state["live"])
        self.assertGreater(state["remaining"], 500)
        record = console.close(self.run_dir)
        sleeper.wait(timeout=10)
        self.assertEqual(record["keepalive"], "stopped")
        self.assertEqual(record["sudo"], "invalidated")
        self.assertFalse(console.privileges(self.run_dir)["live"])

    def test_send_rejects_multi_line_input(self):
        (self.run_dir / "toolchain.json").write_text("{}")
        with self.assertRaises(RolloutError):
            console.send(self.run_dir, "echo one\necho two")


DRIVER = """
import sys, time
sys.path.insert(0, {harness!r})
from pathlib import Path
from rollout import steps
from rollout.common import load_host
marker = Path({marker!r})
def first(ctx):
    return {{"ok": True}}
def second(ctx):
    if marker.exists():
        return {{"ok": True}}
    time.sleep(60)
def third(ctx):
    return {{"ok": True}}
steps.STEPS = [("first", first, {{"migrate"}}), ("second", second, {{"migrate"}}), ("third", third, {{"migrate"}})]
ctx = steps.Context(load_host("supermicro"), {run_dir!r}, {home!r}, require_console=False)
ctx.save_state(mode="migrate")
sys.exit(steps.rollout(ctx))
"""


class RolloutTests(Fixture):
    def context(self, name="nicks-mbp"):
        ctx = steps.Context(load_host(name), self.run_dir, self.home, require_console=False)
        ctx.save_state(mode="migrate")
        return ctx

    def test_a_dropped_run_resumes_at_the_interrupted_step(self):
        marker = self.root / "fixed"
        driver = self.root / "driver.py"
        driver.write_text(DRIVER.format(harness=str(HERE), marker=str(marker),
                                        run_dir=str(self.run_dir), home=str(self.home)))
        process = subprocess.Popen([sys.executable, driver], start_new_session=True)
        deadline = time.time() + 30
        while not (self.run_dir / "steps/02-second.started").exists() and time.time() < deadline:
            time.sleep(0.1)
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        with patch.object(steps, "STEPS", [("first", None, set()), ("second", None, set()), ("third", None, set())]):
            states = {item["step"]: item["state"] for item in steps.status(self.run_dir)}
        self.assertEqual(states, {"first": "done", "second": "running", "third": "pending"})
        marker.touch()
        subprocess.run([sys.executable, driver], check=True, timeout=60)
        self.assertEqual((self.run_dir / "steps/02-second.exit").read_text().strip(), "0")
        self.assertEqual((self.run_dir / "steps/03-third.exit").read_text().strip(), "0")
        self.assertEqual(json.loads((self.run_dir / "steps/01-first.json").read_text())["ok"], True)

    def test_a_failed_step_stops_the_run_and_writes_the_report(self):
        calls = []

        def ok(ctx):
            calls.append("ok")
            return {}

        def broken(ctx):
            raise RolloutError("needs review")

        ctx = self.context()
        ctx.wrapup("Approve karabiner-elements", "Open it once")
        with patch.object(steps, "STEPS", [("ok", ok, {"migrate"}), ("broken", broken, {"migrate"}),
                                           ("after", ok, {"migrate"})]):
            self.assertEqual(steps.rollout(ctx), 1)
            self.assertEqual(steps.rollout(ctx), 1)
        self.assertEqual(calls, ["ok"])
        report = (self.run_dir / "report.md").read_text()
        self.assertIn("broken | failed (1)", report)
        self.assertIn("Approve karabiner-elements", report)

    def test_catch_up_skips_migration_only_steps(self):
        ran = []
        ctx = self.context("maclab")
        ctx.save_state(mode="catch-up")
        record = lambda name: lambda ctx: ran.append(name) or {}  # noqa: E731
        with patch.object(steps, "STEPS", [("backup", record("backup"), {"migrate"}),
                                           ("switch", record("switch"), {"migrate", "catch-up"})]):
            self.assertEqual(steps.rollout(ctx), 0)
        self.assertEqual(ran, ["switch"])

    def test_console_step_requires_live_privileges_with_time_left(self):
        ctx = steps.Context(load_host("nicks-mbp"), self.run_dir, self.home)
        with patch.object(type(ctx.host), "live_checkout", property(lambda host: host.checkout)):
            with self.assertRaisesRegex(RolloutError, "not live"):
                steps.step_console(ctx)
            sleeper = subprocess.Popen(["sleep", "60"])
            self.addCleanup(sleeper.kill)
            (self.run_dir / "keepalive.pid").write_text(str(sleeper.pid))
            (self.run_dir / "privileged-session.ready").write_text(str(int(time.time()) + 300))
            with self.assertRaisesRegex(RolloutError, "min left"):
                steps.step_console(ctx)
            (self.run_dir / "privileged-session.ready").write_text(str(int(time.time()) + 4 * 3600))
            self.assertTrue(steps.step_console(ctx)["live"])

    def test_nix_rtk_hooks_are_retired_with_a_copy(self):
        settings = self.write(".claude/settings.json", json.dumps({"hooks": {"PreToolUse": [
            {"matcher": "Bash", "hooks": [{"command": "/nix/store/abc-rtk/bin/rtk hook claude"},
                                          {"command": "manual-hook"}]},
            {"matcher": "Bash", "hooks": [{"command": "/nix/store/abc-rtk/bin/rtk hook claude"}]}]}}))
        retired = steps.retire_nix_rtk_hooks(self.context())
        self.assertEqual(retired, [".claude/settings.json"])
        groups = json.loads(settings.read_text())["hooks"]["PreToolUse"]
        self.assertEqual(groups, [{"matcher": "Bash", "hooks": [{"command": "manual-hook"}]}])
        self.assertIn("/nix/store", (self.run_dir / "rtk-retired/.claude/settings.json").read_text())

    def cask_fakes(self, *, dry_run_status=0, apply_status=0, installed_by_mise=()):
        packages = [{"package": token, "state": "installed", "managed_by": "mise"} for token in installed_by_mise]
        mise = self.home / ".local/bin/mise"
        mise.parent.mkdir(parents=True, exist_ok=True)
        mise.write_text(self.fake("mise", f"""
            if args[-3:] == ["packages", "status", "--json"]:
                print(json.dumps({{"brew-cask": {{"available": True, "packages": {json.dumps(packages)}}}}}))
            elif "--dry-run" in args:
                sys.exit({dry_run_status})
            elif "apply" in args:
                sys.exit({apply_status})
        """).read_text())
        mise.chmod(0o755)
        self.fake("brew", """
            if args[:2] == ["info", "--json=v2"]:
                print(json.dumps({"casks": [{"token": "slack", "full_token": "slack"},
                                            {"token": "karabiner-elements", "full_token": "karabiner-elements"}]}))
        """)
        self.fake("launchctl", "sys.exit(113)\n")
        self.fake("pgrep", "sys.exit(1)\n")

    def test_cask_transfer_dry_runs_with_an_empty_prefix_before_uninstalling(self):
        self.cask_fakes()
        ctx = self.context()
        self.assertEqual(steps.transfer_cask(ctx, "brew-cask:slack", {}, {"slack": "slack"}), "transferred")
        mise_calls = [call for call in self.recorded("mise") if "apply" in call["argv"]]
        self.assertIn("--dry-run", mise_calls[0]["argv"])
        self.assertEqual(list(Path(mise_calls[0]["prefix"]).iterdir()), [])
        self.assertEqual(self.recorded("brew")[0]["argv"], ["brew", "uninstall", "--cask", "slack"])
        self.assertEqual(self.recorded("brew")[0]["autoremove"], "1")
        self.assertNotIn("--zap", self.recorded("brew")[0]["argv"])

    def test_failed_dry_run_keeps_the_homebrew_copy(self):
        self.cask_fakes(dry_run_status=1)
        with self.assertRaisesRegex(RolloutError, "Homebrew copy kept"):
            steps.transfer_cask(self.context(), "brew-cask:slack", {}, {"slack": "slack"})
        self.assertEqual(self.recorded("brew"), [])

    def test_approval_casks_fail_into_the_wrap_up_list_and_the_run_continues(self):
        if not load_host("nicks-mbp").macos:
            self.skipTest("macOS host")
        self.cask_fakes(apply_status=1, installed_by_mise=["slack"])
        ctx = self.context()
        with patch.object(type(ctx.host), "casks", lambda host: ["brew-cask:slack", "brew-cask:karabiner-elements"]):
            result = steps.step_casks(ctx)
        self.assertEqual(result["packages"]["brew-cask:slack"]["detail"], "already mise-owned")
        self.assertEqual(result["packages"]["brew-cask:karabiner-elements"]["status"], "failed")
        wrapup = json.loads((self.run_dir / "wrapup.json").read_text())
        self.assertIn("System Settings", wrapup[0]["instructions"])
        self.assertTrue((self.run_dir / "casks/karabiner-elements.json").exists())

    def test_cleanup_removes_only_allowlisted_packages_and_links(self):
        self.fake("brew", """
            if args[:2] == ["list", "--formula"]:
                print("workmux\\nhelm\\nripgrep\\nopencode")
            elif args[:2] == ["list", "--cask"]:
                print("claude-code\\nslack")
            elif args[:2] == ["uses", "--installed"]:
                print("something-else" if args[2] == "helm" else "")
        """)
        gh = self.home / plan.RETIRED_LINKS[0]
        gh.parent.mkdir(parents=True)
        gh.symlink_to("/nix/store/1111-gh-stack")
        ctx = self.context()
        with patch.object(type(ctx.host), "macos", True):
            result = steps.step_cleanup(ctx)
        uninstalls = [call["argv"] for call in self.recorded("brew") if call["argv"][0:2] == ["brew", "uninstall"]]
        self.assertIn(["brew", "uninstall", "--formula", "workmux"], uninstalls)
        self.assertIn(["brew", "uninstall", "--formula", "opencode"], uninstalls)
        self.assertIn(["brew", "uninstall", "--cask", "claude-code"], uninstalls)
        self.assertNotIn(["brew", "uninstall", "--formula", "ripgrep"], uninstalls)
        self.assertNotIn(["brew", "uninstall", "--formula", "helm"], uninstalls)
        self.assertFalse(gh.is_symlink())
        self.assertIn(plan.RETIRED_LINKS[0], result["removed"])
        self.assertTrue(all("--zap" not in call and "--force" not in call for call in uninstalls))


class CheckTests(Fixture):
    def test_tool_resolution_rejects_a_tool_outside_mise(self):
        install = self.root / "installs/node"
        (install / "bin").mkdir(parents=True)
        legacy = self.root / "legacy-node"
        legacy.write_text("#!/bin/sh\n")
        legacy.chmod(0o755)
        mise = self.fake("mise", f"""
            if "where" in args:
                print({str(install)!r})
        """)
        self.fake("bash", f"""
            print("node\\t" + {str(legacy)!r})
        """)
        host = load_host("supermicro")
        with patch.object(type(host), "declarations", lambda host: {"tools": {"node": "1"}, "packages": {}, "repos": {}}):
            result = checks.tool_resolution(host, self.home, mise)
        self.assertEqual(result["status"], "fail")
        self.assertIn("login:node", result["detail"])

    def test_dangling_skill_links_fail_verification(self):
        skills = self.home / ".claude/skills"
        skills.mkdir(parents=True)
        (skills / "gone").symlink_to(self.root / "missing")
        self.assertEqual(checks.skill_links(self.home)["status"], "fail")
        (skills / "gone").unlink()
        self.assertEqual(checks.skill_links(self.home)["status"], "ok")

    def test_unreachable_repositories_fail_preflight(self):
        self.fake("git", "sys.exit(128 if 'lc-script' in ' '.join(args) else 0)\n")
        host = load_host("nicks-loancrate-mbp")
        results = {r["name"]: r for r in checks.preflight(
            host, self.home, estimate={"files": 0, "bytes": 0, "allocated_bytes": 0, "unreadable": []})}
        self.assertEqual(results["repo-access"]["status"], "fail")
        self.assertIn("lc-script", results["repo-access"]["detail"])

    def test_a_blocked_read_is_reported_instead_of_hanging(self):
        results = {r["name"]: r for r in checks.preflight(
            load_host("supermicro"), self.home,
            estimate={"files": 0, "bytes": 0, "allocated_bytes": 0, "unreadable": [], "blocked": "Library/Containers/x"})}
        self.assertEqual(results["protected-paths-readable"]["status"], "fail")


if __name__ == "__main__":
    unittest.main()
