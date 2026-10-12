#!/usr/bin/env python3
"""Print failed tests from `xcresulttool get test-results tests` JSON.

  xcresult-failures.py tests.json            # markdown, for the GitHub issue
  xcresult-failures.py tests.json --oneline  # first failure, for a notification

The first line of a failure message is the cause; the rest is XCUITest's
element dump, which goes in a collapsed block so the issue stays readable.
"""
import json
import sys


def failed_cases(node, suite=""):
    kind = node.get("nodeType")
    if kind == "Test Suite":
        suite = node.get("name", suite)
    if kind == "Test Case" and node.get("result") == "Failed":
        messages = [
            c.get("name", "")
            for c in node.get("children", [])
            if c.get("nodeType") == "Failure Message"
        ]
        yield suite, node.get("name", "?"), messages
        return
    for child in node.get("children", []):
        yield from failed_cases(child, suite)


def main():
    with open(sys.argv[1]) as f:
        nodes = json.load(f).get("testNodes", [])
    cases = [c for n in nodes for c in failed_cases(n)]

    if "--oneline" in sys.argv[2:]:
        if cases:
            suite, name, messages = cases[0]
            cause = messages[0].splitlines()[0] if messages else "no failure message"
            more = f" (+{len(cases) - 1} more)" if len(cases) > 1 else ""
            print(f"{suite}.{name}{more}: {cause[:160]}")
        return

    for suite, name, messages in cases:
        print(f"- **`{suite}.{name}`**")
        for message in messages or ["(no failure message recorded)"]:
            first, _, rest = message.partition("\n")
            print(f"  - {first}")
            if rest.strip():
                print("    <details><summary>element dump</summary>\n")
                print("    ```")
                for line in rest.strip().splitlines():
                    print(f"    {line}")
                print("    ```\n    </details>")


if __name__ == "__main__":
    main()
