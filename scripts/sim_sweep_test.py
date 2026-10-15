"""Unit tests for sim_sweep.plan(). Run: python3 -m unittest discover -s scripts -p 'sim_sweep_test.py'"""

import unittest
from datetime import datetime, timedelta, timezone

from sim_sweep import Action, plan

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


def run(devices, clones=(), processes=(), keep=()):
    return plan(list(devices), list(clones), list(processes), set(keep), NOW)


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


if __name__ == "__main__":
    unittest.main()
