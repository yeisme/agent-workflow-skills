#!/usr/bin/env python3
"""Validate a standalone first-party Skills repository."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_METADATA = ("display_name:", "short_description:", "default_prompt:")


def value(text: str, key: str) -> str | None:
    match = re.search(rf"(?m)^{re.escape(key)}:\s*(.+?)\s*$", text)
    return match.group(1).strip("\"'") if match else None


def main() -> int:
    errors: list[str] = []
    names: set[str] = set()
    skills = sorted(ROOT.glob("*/SKILL.md"))
    for skill_file in skills:
        skill_dir = skill_file.parent
        text = skill_file.read_text(encoding="utf-8")
        name = value(text, "name")
        if name != skill_dir.name:
            errors.append(f"{skill_file}: name must equal directory {skill_dir.name}")
        if not value(text, "description"):
            errors.append(f"{skill_file}: missing description")
        if name in names:
            errors.append(f"duplicate skill name: {name}")
        if name:
            names.add(name)
        metadata = skill_dir / "agents" / "openai.yaml"
        if not metadata.is_file():
            errors.append(f"{skill_dir}: missing agents/openai.yaml")
            continue
        metadata_text = metadata.read_text(encoding="utf-8")
        for field in REQUIRED_METADATA:
            if field not in metadata_text:
                errors.append(f"{metadata}: missing {field[:-1]}")

    if not skills:
        errors.append("no top-level Skills found")
    if errors:
        print("FAIL: Skills validation failed", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"PASS: validated {len(skills)} Skills")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
