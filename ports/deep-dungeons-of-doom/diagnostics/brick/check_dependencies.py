"""Read ELF metadata; do not execute ARM64 files."""
import json
import argparse
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--root", required=True, type=Path, help="Private output from Prepare-Libraries.ps1")
parser.add_argument("--ruffle", required=True, type=Path, help="Reviewed ARM64 Ruffle executable")
args = parser.parse_args()
root = args.root.resolve()
lib = root / "portable/lib"
main = args.ruffle.resolve()
files = [main] + list(lib.iterdir())
missing = []
architectures = set()
for file in files:
    header = subprocess.check_output(["readelf", "-h", str(file)], text=True)
    match = re.search(r"Machine:\s*(.+)", header)
    architectures.add(match.group(1).strip() if match else "unknown")
    dynamic = subprocess.check_output(["readelf", "-d", str(file)], text=True)
    for needed in re.findall(r"Shared library: \[(.+?)\]", dynamic):
        if not (lib / needed).is_file():
            missing.append({"file":file.name,"needed":needed})
result = {"objectsChecked":len(files),"architectures":sorted(architectures),"missingDirectDependencies":missing,"scope":"ELF declared dependencies only; no execution, graphics, or runtime dlopen compatibility verified"}
(root / "dependency-check.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
if missing or architectures != {"AArch64"}:
    raise SystemExit(1)
