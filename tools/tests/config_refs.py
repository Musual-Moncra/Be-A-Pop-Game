"""
config_refs
Static check: every `SomeConfig.Field` read in src must name a top-level field that exists in that
config's `return { ... }` table. Catches code still reading a config field that was renamed or removed,
which otherwise only fails at runtime. Run by tools/tests/run.sh; exits 1 on any missing field.
"""

import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[2]
config_dirs = [root / "src/modules/Config", root / "src/serverstorage/Modules/Config"]

fields = {}
for folder in config_dirs:
    for path in folder.glob("*.lua"):
        text = path.read_text()
        body = text[text.find("return {") :]
        depth = 0
        keys = set()
        for line in body.splitlines()[1:]:
            if depth == 0:
                match = re.match(r"\t([A-Za-z_][A-Za-z0-9_]*)\s*=", line)
                if match:
                    keys.add(match.group(1))
            depth += line.count("{") - line.count("}")
            if depth < 0:
                break
        fields[path.stem] = keys

usage = re.compile(r"\b([A-Z][A-Za-z]*Config)\.([A-Za-z_][A-Za-z0-9_]*)")
problems = []
for path in (root / "src").rglob("*.lua"):
    if "Packages" in path.parts:
        continue
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if line.lstrip().startswith("--"):
            continue
        for config, field in usage.findall(line):
            if config in fields and field not in fields[config]:
                problems.append(f"{path.relative_to(root)}:{number}: {config}.{field} does not exist")

for problem in problems:
    print(problem)
print(f"CONFIG REFS: {len(problems)} missing")
sys.exit(1 if problems else 0)
