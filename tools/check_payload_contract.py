#!/usr/bin/env python3
"""Guard the Dart <-> Swift shared-cache contract.

lib/models/widget_payload.dart and ios/TidalWidget/Shared/SharedState.swift
describe the same JSON blob in two languages. Nothing links them: rename a key
on one side and the widget silently renders an empty cache forever, with no
compile error and no runtime exception anywhere.

So diff the key sets directly. Cheap, and it catches the exact drift that would
otherwise cost an afternoon.

Usage: python3 tools/check_payload_contract.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DART = ROOT / "lib" / "models" / "widget_payload.dart"
SWIFT = ROOT / "ios" / "TidalWidget" / "Shared" / "SharedState.swift"
BRIDGE = ROOT / "lib" / "services" / "widget_bridge.dart"

# Keys Swift never reads. canSendAt is app-only (the widget has no compose
# button), and 'v' is the schema version.
SWIFT_IGNORES = {"canSendAtMs", "v"}


def dart_keys() -> set[str]:
    body = DART.read_text()
    block = re.search(r"Map<String, dynamic> toJson\(\) => \{(.*?)\n      \};", body, re.S)
    if not block:
        sys.exit("could not find toJson() in widget_payload.dart")
    return set(re.findall(r"'([A-Za-z]+)':", block.group(1)))


def swift_keys() -> set[str]:
    # Keys the Swift side pulls out of the decoded dictionary.
    return set(re.findall(r'j\["([A-Za-z]+)"\]', SWIFT.read_text()))


def states(text: str, pattern: str) -> set[str]:
    return set(re.findall(pattern, text, re.M))


def main() -> int:
    problems = []

    d, s = dart_keys(), swift_keys()
    missing_in_swift = d - s - SWIFT_IGNORES
    unknown_in_swift = s - d
    if missing_in_swift:
        problems.append(f"Swift never reads: {sorted(missing_in_swift)}")
    if unknown_in_swift:
        problems.append(f"Swift reads keys Dart never writes: {sorted(unknown_in_swift)}")

    # The state machine must be identical on both sides or a state renders as
    # its fallback instead of itself.
    dart_states = states(DART.read_text(), r"^  (\w+)[,;]$")
    swift_states = set(
        re.search(r"enum LetterState: String \{\s*case ([^\n}]+)", SWIFT.read_text())
        .group(1).replace(" ", "").split(",")
    )
    dart_states = {x for x in dart_states if x in {"empty", "waiting", "open", "faded"}}
    if dart_states != swift_states:
        problems.append(f"LetterState differs: dart={sorted(dart_states)} swift={sorted(swift_states)}")

    # Storage keys, the App Group id and the widget kind must match exactly.
    # A mismatched kind is the classic silent no-op: updateWidget succeeds and
    # nothing ever refreshes.
    bridge, swift_src = BRIDGE.read_text(), SWIFT.read_text()
    for label, dart_pat, swift_pat in [
        ("app group", r"appGroupId = '([^']+)'", r'appGroup = "([^"]+)"'),
        ("state key", r"stateKey = '([^']+)'", r'stateKey = "([^"]+)"'),
        ("pending key", r"pendingOpenKey = '([^']+)'", r'pendingOpenKey = "([^"]+)"'),
        ("widget kind", r"iOSWidgetName = '([^']+)'", r'widgetKind = "([^"]+)"'),
    ]:
        a = re.search(dart_pat, bridge)
        b = re.search(swift_pat, swift_src)
        if not a or not b:
            problems.append(f"{label}: could not locate on both sides")
        elif a.group(1) != b.group(1):
            problems.append(f"{label} mismatch: dart={a.group(1)!r} swift={b.group(1)!r}")

    if problems:
        print("shared-cache contract BROKEN:")
        for p in problems:
            print("  -", p)
        return 1

    print(f"contract ok: {len(d)} keys, states {sorted(swift_states)}, ids match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
