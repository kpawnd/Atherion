#!/usr/bin/env python3
import glob
import subprocess
import sys

PATTERNS = ("faronics", "deepfreeze", "deep_freeze", "deep freeze")

KNOWN_PATH_GLOBS = [
    "/Applications/Deep Freeze.app",
    "/Applications/Faronics*.app",
    "/Library/Application Support/Faronics*",
    "/Library/Application Support/Deep Freeze*",
    "/Library/LaunchDaemons/com.faronics*.plist",
    "/Library/LaunchDaemons/com.deepfreeze*.plist",
    "/Library/LaunchAgents/com.faronics*.plist",
    "/Library/LaunchAgents/com.deepfreeze*.plist",
    "/Library/Preferences/com.faronics*",
    "/Library/Preferences/com.deepfreeze*",
    "/Library/PrivilegedHelperTools/com.faronics*",
    "/Library/PrivilegedHelperTools/com.deepfreeze*",
    "/private/var/db/receipts/*faronics*",
    "/private/var/db/receipts/*deepfreeze*",
]


def low(s: str) -> str:
    return s.lower()


def match_any(value: str) -> bool:
    v = low(value)
    return any(p in v for p in PATTERNS)


def emit(kind: str, value: str) -> None:
    if value:
        print(f"{kind}|{value}")


seen = set()

# Launch labels
try:
    out = subprocess.check_output(["launchctl", "list"], stderr=subprocess.DEVNULL, text=True)
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            label = parts[2].strip()
            if match_any(label):
                key = ("LABEL", label)
                if key not in seen:
                    seen.add(key)
                    emit("LABEL", label)
except Exception:
    pass

# Package receipts
try:
    out = subprocess.check_output(["pkgutil", "--pkgs"], stderr=subprocess.DEVNULL, text=True)
    for receipt in out.splitlines():
        receipt = receipt.strip()
        if match_any(receipt):
            key = ("RECEIPT", receipt)
            if key not in seen:
                seen.add(key)
                emit("RECEIPT", receipt)
except Exception:
    pass

# Known paths
for pattern in KNOWN_PATH_GLOBS:
    for path in glob.glob(pattern):
        key = ("PATH", path)
        if key not in seen:
            seen.add(key)
            emit("PATH", path)
