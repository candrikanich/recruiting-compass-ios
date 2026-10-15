#!/usr/bin/env python3
"""Shut down and delete orphaned iOS simulators without touching anyone's live run.

    python3 scripts/sim_sweep.py            # act
    python3 scripts/sim_sweep.py --dry-run  # print what it would do
    python3 scripts/sim_sweep.py --tests-running  # exit 0 + print them if any xcodebuild test runs

Runs hourly from launchd (scripts/install-sim-sweep.sh). Several agents share this
Mac, so nothing here is global: a device named by a running xcodebuild/simctl/xctest
command line is never touched, and clones are only cleared while no xcodebuild runs.

- Booted for BOOTED_HOURS with nothing referencing it -> shut down (never deleted).
- Shut down, unused for STALE_HOURS, and named trc-* / agent-* -> deleted. Only those
  prefixes are throwaway by convention; hand-made devices are never deleted.
- Xcode's parallel-testing clone set -> cleared when no xcodebuild is running.
- Devices whose runtime is gone -> `simctl delete unavailable`.

Names or UDIDs listed one per line in ~/.config/recruiting-compass/sim-sweep-keep
are never touched.
"""

# launchd runs Apple's /usr/bin/python3 (3.9), which needs this for `X | None` annotations.
from __future__ import annotations

import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

BOOTED_HOURS = 3
STALE_HOURS = 24
THROWAWAY_PREFIXES = ("trc-", "agent-")
KEEP_FILE = Path.home() / ".config/recruiting-compass/sim-sweep-keep"
UDID_RE = re.compile(r"[0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}")
DESTINATION_NAME_RE = re.compile(r"name=([^,]+?)(?:,|\s+-|$)")
SIM_PROCESS_RE = re.compile(r"\b(xcodebuild|simctl|xctest)\b")
TEST_ACTIONS = {"test", "test-without-building"}
BOOLEAN_FLAGS = {"-quiet", "-verbose", "-json", "-allowProvisioningUpdates", "-disableAutomaticPackageResolution"}


@dataclass(frozen=True)
class Action:
    kind: str  # "shutdown" | "delete" | "delete-clone"
    udid: str
    name: str


def _last_used(device: dict) -> datetime | None:
    raw = device.get("lastUsedAt")
    if not raw:
        return None
    return datetime.strptime(raw, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)


def _idle_for(device: dict, hours: int, now: datetime) -> bool:
    # A device with no lastUsedAt was just created (e.g. a fresh clone); treat it as in use.
    last = _last_used(device)
    return last is not None and now - last >= timedelta(hours=hours)


def _referenced(processes: list[str]) -> tuple[set[str], set[str]]:
    udids: set[str] = set()
    names: set[str] = set()
    for command in processes:
        if SIM_PROCESS_RE.search(command):
            udids.update(u.upper() for u in UDID_RE.findall(command))
            names.update(n.strip() for n in DESTINATION_NAME_RE.findall(command))
    return udids, names


def plan(
    devices: list[dict],
    clones: list[dict],
    processes: list[str],
    keep: set[str],
    now: datetime,
) -> list[Action]:
    """Decide what to clean up. Pure: no simctl or ps calls."""
    ref_udids, ref_names = _referenced(processes)
    actions: list[Action] = []
    for d in devices:
        name, udid = d["name"], d["udid"]
        if name in keep or udid in keep or udid.upper() in ref_udids or name in ref_names:
            continue
        if d["state"] == "Booted":
            if _idle_for(d, BOOTED_HOURS, now):
                actions.append(Action("shutdown", udid, name))
        elif d["state"] == "Shutdown" and name.startswith(THROWAWAY_PREFIXES) and _idle_for(d, STALE_HOURS, now):
            actions.append(Action("delete", udid, name))

    xcodebuild_running = any("xcodebuild" in p for p in processes)
    if not xcodebuild_running:
        actions.extend(Action("delete-clone", c["udid"], c["name"]) for c in clones)
    return actions


def xcodebuild_test_runs(processes: list[str]) -> list[str]:
    """Command lines of running `xcodebuild test` / `test-without-building` processes.

    Matches on the executable, not a substring, so the shells and scripts that launched
    xcodebuild (or a grep for it) don't count as a second run.
    """
    return [p for p in processes if _is_xcodebuild_test(p.split())]


def _is_xcodebuild_test(tokens: list[str]) -> bool:
    if not tokens or Path(tokens[0]).name != "xcodebuild":
        return False
    prev = ""
    for token in tokens[1:]:
        # A bare word right after a value-taking option is its value (`-scheme test`), not an action.
        takes_value = prev.startswith("-") and prev not in BOOLEAN_FLAGS
        if token in TEST_ACTIONS and not takes_value:
            return True
        prev = token
    return False


def _devices(*set_args: str) -> list[dict]:
    out = subprocess.run(
        ["xcrun", "simctl", *set_args, "list", "devices", "-j"], capture_output=True, text=True, check=True
    ).stdout
    return [d for ds in json.loads(out)["devices"].values() for d in ds]


def _processes() -> list[str]:
    out = subprocess.run(["ps", "-axo", "command="], capture_output=True, text=True, check=True).stdout
    return out.splitlines()


def _keep() -> set[str]:
    if not KEEP_FILE.exists():
        return set()
    return {line.strip() for line in KEEP_FILE.read_text().splitlines() if line.strip() and not line.startswith("#")}


def _simctl(*args: str) -> None:
    subprocess.run(["xcrun", "simctl", *args], capture_output=True, check=False)


def main() -> int:
    if "--tests-running" in sys.argv[1:]:
        runs = xcodebuild_test_runs(_processes())
        print("\n".join(runs))
        return 0 if runs else 1
    dry_run = "--dry-run" in sys.argv[1:]
    actions = plan(_devices(), _devices("--set", "testing"), _processes(), _keep(), datetime.now(timezone.utc))
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    for a in actions:
        print(f"[{stamp}] {'would ' if dry_run else ''}{a.kind} {a.name} ({a.udid})")
        if dry_run:
            continue
        if a.kind == "shutdown":
            _simctl("shutdown", a.udid)
        elif a.kind == "delete":
            _simctl("delete", a.udid)
        elif a.kind == "delete-clone":
            _simctl("--set", "testing", "shutdown", a.udid)
            _simctl("--set", "testing", "delete", a.udid)
    if not dry_run:
        _simctl("delete", "unavailable")
    if not actions:
        print(f"[{stamp}] nothing to sweep")
    return 0


if __name__ == "__main__":
    sys.exit(main())
