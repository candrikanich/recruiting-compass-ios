"""Unit tests for sim_sweep. Run: python3 -m unittest discover -s scripts -p 'sim_sweep_test.py'"""

import unittest
from datetime import datetime, timedelta, timezone

from sim_sweep import Action, lock_holder, plan, xcodebuild_test_runs

NOW = datetime(2026, 10, 14, 12, 0, tzinfo=timezone.utc)
UDID_A = "11111111-1111-1111-1111-111111111111"
UDID_B = "22222222-2222-2222-2222-222222222222"


def device(name, udid, state="Shutdown", hours_ago=48.0):
    return {
        "name": name,
        "udid": udid,
        "state": state,
        "isAvailable": True,
        "lastUsedAt": (NOW - timedelta(hours=hours_ago)).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def run(devices, clones=(), processes=(), keep=(), lock_held=False):
    return plan(list(devices), list(clones), list(processes), set(keep), NOW, lock_held)


class ShutdownTests(unittest.TestCase):
    def test_shuts_down_long_booted_device_nothing_references(self):
        actions = run([device("A11y Fix", UDID_A, "Booted", hours_ago=5)])
        self.assertEqual(actions, [Action("shutdown", UDID_A, "A11y Fix")])

    def test_leaves_recently_booted_device_alone(self):
        self.assertEqual(run([device("iPhone 17", UDID_A, "Booted", hours_ago=1)]), [])

    def test_leaves_device_named_by_running_xcodebuild_udid(self):
        procs = [f"xcodebuild test -scheme X -destination id={UDID_A}"]
        self.assertEqual(run([device("trc-391", UDID_A, "Booted", hours_ago=9)], processes=procs), [])

    def test_leaves_device_named_by_running_xcodebuild_name(self):
        procs = ["xcodebuild test -destination platform=iOS Simulator,name=iPhone 17"]
        self.assertEqual(run([device("iPhone 17", UDID_A, "Booted", hours_ago=9)], processes=procs), [])

    def test_unrelated_xcodebuild_does_not_protect_other_devices(self):
        procs = [f"xcodebuild test -destination id={UDID_B}"]
        actions = run([device("A11y Fix", UDID_A, "Booted", hours_ago=9)], processes=procs)
        self.assertEqual(actions, [Action("shutdown", UDID_A, "A11y Fix")])

    def test_keep_list_protects_by_name_or_udid(self):
        devices = [device("Perf iPhone 17", UDID_A, "Booted", 9), device("trc-1", UDID_B, "Booted", 9)]
        self.assertEqual(run(devices, keep={"Perf iPhone 17", UDID_B}), [])


class DeleteTests(unittest.TestCase):
    def test_deletes_stale_agent_devices(self):
        devices = [device("trc-391", UDID_A, hours_ago=30), device("agent-1234-a11y", UDID_B, hours_ago=30)]
        self.assertEqual(
            run(devices),
            [Action("delete", UDID_A, "trc-391"), Action("delete", UDID_B, "agent-1234-a11y")],
        )

    def test_keeps_fresh_agent_device(self):
        self.assertEqual(run([device("trc-verify-399b", UDID_A, hours_ago=2)]), [])

    def test_never_deletes_a_device_without_an_agent_prefix(self):
        self.assertEqual(run([device("Verify363 iPhone", UDID_A, hours_ago=500)]), [])

    def test_agent_device_with_no_last_used_is_kept(self):
        fresh_clone = {"name": "trc-399", "udid": UDID_A, "state": "Shutdown", "isAvailable": True}
        self.assertEqual(run([fresh_clone]), [])

    def test_long_booted_agent_device_is_shut_down_not_deleted(self):
        actions = run([device("trc-391", UDID_A, "Booted", hours_ago=30)])
        self.assertEqual(actions, [Action("shutdown", UDID_A, "trc-391")])

    def test_running_process_protects_stale_agent_device_from_delete(self):
        procs = [f"xcrun simctl boot {UDID_A}"]
        self.assertEqual(run([device("trc-391", UDID_A, hours_ago=30)], processes=procs), [])


class CloneTests(unittest.TestCase):
    def test_clears_clone_set_when_no_xcodebuild_runs(self):
        clones = [device("Clone 1 of iPhone 17", UDID_A, "Booted", 0.1)]
        self.assertEqual(run([], clones=clones), [Action("delete-clone", UDID_A, "Clone 1 of iPhone 17")])

    def test_leaves_clone_set_alone_while_any_xcodebuild_runs(self):
        clones = [device("Clone 1 of iPhone 17", UDID_A, "Booted", 9)]
        procs = [f"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -destination id={UDID_B}"]
        self.assertEqual(run([], clones=clones, processes=procs), [])

    def test_leaves_clone_set_alone_while_the_test_lock_is_held(self):
        clones = [device("Clone 1 of iPhone 17", UDID_A, "Shutdown", 9)]
        self.assertEqual(run([], clones=clones, lock_held=True), [])


ORPHAN = "/Library/Developer/CoreSimulator/Volumes/iOS_24B5084k/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 27.2.simruntime/Contents/Resources/RuntimeRoot/System/Library/Frameworks/Metal.framework/XPCServices/MTLCompilerService.xpc/MTLCompilerService"
KILL_ORPHANS = Action("kill-orphans", "", "2 simulator runtime services")


class OrphanTests(unittest.TestCase):
    def test_kills_runtime_services_when_nothing_is_booted(self):
        procs = [ORPHAN, ORPHAN.replace("MTLCompilerService", "SetStoreUpdateService")]
        self.assertEqual(run([device("iPhone 17", UDID_A)], processes=procs), [KILL_ORPHANS])

    def test_leaves_them_while_a_simulator_is_booted(self):
        self.assertEqual(run([device("iPhone 17", UDID_A, "Booted", 0.5)], processes=[ORPHAN, ORPHAN]), [])

    def test_leaves_them_while_a_clone_is_booted(self):
        clones = [device("Clone 1 of iPhone 17", UDID_A, "Booted", 0.1)]
        procs = [ORPHAN, ORPHAN, "xcodebuild test -destination id=X"]
        self.assertEqual(run([], clones=clones, processes=procs), [])

    def test_leaves_them_while_the_test_lock_is_held(self):
        self.assertEqual(run([], processes=[ORPHAN, ORPHAN], lock_held=True), [])

    def test_leaves_them_while_xcodebuild_runs(self):
        self.assertEqual(run([], processes=[ORPHAN, ORPHAN, "/usr/bin/xcodebuild build -scheme X"]), [])

    def test_host_metal_compiler_is_not_an_orphan(self):
        host = "/System/Library/Frameworks/Metal.framework/Versions/A/XPCServices/MTLCompilerService.xpc/MTLCompilerService"
        self.assertEqual(run([], processes=[host]), [])


class LockHolderTests(unittest.TestCase):
    OWNER = "pid=4242\nlabel=run-ios-tests unit tests\ndir=/w\nbranch=b\nstarted=2026-10-22 09:00:00\n"

    def test_live_holder_is_described(self):
        self.assertEqual(
            lock_holder(self.OWNER, alive=lambda pid: pid == 4242),
            "pid=4242 label=run-ios-tests unit tests dir=/w branch=b started=2026-10-22 09:00:00",
        )

    def test_dead_holder_is_stale(self):
        self.assertIsNone(lock_holder(self.OWNER, alive=lambda pid: False))

    def test_no_owner_file(self):
        self.assertIsNone(lock_holder(None, alive=lambda pid: True))
        self.assertIsNone(lock_holder("garbage", alive=lambda pid: True))


class XcodebuildTestRunsTests(unittest.TestCase):
    XCODEBUILD = "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"

    def test_finds_xcodebuild_test(self):
        procs = [f"{self.XCODEBUILD} test -scheme X -destination id={UDID_A}"]
        self.assertEqual(xcodebuild_test_runs(procs), procs)

    def test_finds_xcodebuild_test_without_building(self):
        procs = [f"{self.XCODEBUILD} test-without-building -project P -destination id={UDID_A}"]
        self.assertEqual(xcodebuild_test_runs(procs), procs)

    def test_ignores_build_for_testing(self):
        self.assertEqual(xcodebuild_test_runs([f"{self.XCODEBUILD} build-for-testing -scheme X"]), [])

    def test_ignores_test_word_in_an_argument_value(self):
        self.assertEqual(xcodebuild_test_runs([f"{self.XCODEBUILD} build -scheme test -only-testing:X/test"]), [])

    def test_finds_test_action_after_a_boolean_flag(self):
        procs = [f"{self.XCODEBUILD} -quiet test -scheme X"]
        self.assertEqual(xcodebuild_test_runs(procs), procs)

    def test_ignores_shells_and_scripts_that_mention_xcodebuild_test(self):
        procs = [
            "/bin/zsh -c xcodebuild test -scheme X",
            "bash -x scripts/e2e/nightly-local.sh --suite smoke",
            "grep xcodebuild test",
        ]
        self.assertEqual(xcodebuild_test_runs(procs), [])


if __name__ == "__main__":
    unittest.main()
