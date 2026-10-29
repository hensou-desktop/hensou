#!/usr/bin/env python3
"""Check the kit's import and resource boundary, without loading a shell."""
from pathlib import Path
import re
import subprocess
import sys

kit = Path(__file__).resolve().parent
root = kit / "qml" / "Hensou"
for file in root.glob("*.qml"):
    text = re.sub(r"//[^\n]*", "", file.read_text())
    assert not re.search(r"\b(Quickshell|QsWindow|FileView|XMLHttpRequest|Process)\b", text), file
    assert not re.search(r"^import\s+[\"'].*(?:\.\./|Hensou)", text, re.M), file
    assert "Screen.devicePixelRatio" not in re.sub(r"//[^\n]*", "", text), file
exports = (root / "qmldir").read_text().splitlines()
assert exports[0] == "module Hensou"
for file in root.glob("*.qml"):
    entry = ("singleton " if "pragma Singleton" in file.read_text() else "") + f"{file.stem} 1.0 {file.name}"
    assert entry in exports, entry
subprocess.run([sys.executable, str(kit / "generate-resources.py"), "--check"], check=True)
print("HENSOU_BOUNDARY_PASSED")
