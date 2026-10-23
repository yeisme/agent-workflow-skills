#!/usr/bin/env python3
"""Add only the owner manager regression/evidence steps to generated CI."""
from pathlib import Path

import yaml

path = Path(__file__).resolve().parents[1] / ".github/workflows/ci.yml"
data = yaml.safe_load(path.read_text())
if True in data:
    data["on"] = data.pop(True)
for name in ("quick-check", "check-full"):
    steps = data["jobs"][name]["steps"]
    additions = [
        {"name": "Portable manager regression", "run": "python3 scripts/run-evidence.py -- python3 scripts/test_skill_manager.py"},
        {"name": "Preserve manager evidence", "if": "always()", "uses": "actions/upload-artifact@v4", "with": {"name": "manager-" + name, "path": "temp/integration-test-runs/"}},
    ]
    for item in additions:
        existing = next((i for i, step in enumerate(steps) if step.get("name") == item["name"]), None)
        if existing is None:
            steps.append(item)
        else:
            steps[existing] = item
path.write_text("# Change-aware CI maintained by repository scripts.\n" + yaml.safe_dump(data, sort_keys=False))
print("manager_ci=updated")
