#!/usr/bin/env python3
"""Regression tests for the portable Yeisme Skill manager."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "yeisme-skill-routing-governance" / "scripts" / "skills.sh"
MANAGER_SOURCE = ROOT / "yeisme-skill-routing-governance"
BUILDER_PROFILE_SOURCE = ROOT / "yeisme-builder-profile"


def write_skill(root: Path, directory: str, name: str, description: str) -> Path:
    skill = root / directory
    (skill / "agents").mkdir(parents=True)
    (skill / "SKILL.md").write_text(
        "---\n"
        f"name: {name}\n"
        f"description: Use when {description}.\n"
        "---\n\n"
        f"# {name}\n",
        encoding="utf-8",
    )
    (skill / "agents" / "openai.yaml").write_text(
        "interface:\n"
        f'  display_name: "{name}"\n'
        f'  short_description: "Use when {description}."\n'
        f'  default_prompt: "Use ${name}."\n',
        encoding="utf-8",
    )
    return skill


class SkillManagerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.source = self.base / "source"
        self.project = self.base / "project"
        self.source.mkdir()
        self.project.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=self.project, check=True)
        shutil.copytree(MANAGER_SOURCE, self.source / MANAGER_SOURCE.name)
        shutil.copytree(BUILDER_PROFILE_SOURCE, self.source / BUILDER_PROFILE_SOURCE.name)
        write_skill(self.source, "sample-workflow", "sample-workflow", "running sample work")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_manager(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        result = subprocess.run(
            [
                str(ENGINE),
                "--source",
                str(self.source),
                "--project",
                str(self.project),
                *args,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        if check and result.returncode != 0:
            self.fail(f"manager failed: {result.stderr}\nstdout={result.stdout}")
        return result

    def test_init_profile_sync_remove_and_unknown_preservation(self) -> None:
        initialized = self.run_manager("init")
        self.assertIn("Status: success", initialized.stdout)

        profile = self.project / ".skills" / "profiles" / "root.txt"
        source_local = self.project / ".skills" / "source.local"
        manifest = self.project / ".skills" / "managed-runtime.txt"
        profile_text = profile.read_text(encoding="utf-8")
        self.assertIn("yeisme-skill-routing-governance", profile_text)
        self.assertNotIn("yeisme-builder-profile", profile_text)
        self.assertEqual(source_local.read_text(encoding="utf-8").strip(), str(self.source))
        self.assertIn(".skills/source.local", (self.project / ".git" / "info" / "exclude").read_text(encoding="utf-8"))
        self.assertTrue(manifest.is_file())
        for home in (".agents", ".claude"):
            self.assertFalse((self.project / home / "skills" / "yeisme-builder-profile").exists())

        self.run_manager("profile", "add", "yeisme-builder-profile")
        self.run_manager("sync")
        for home in (".agents", ".claude"):
            self.assertTrue((self.project / home / "skills" / "yeisme-builder-profile" / "SKILL.md").is_file())

        self.run_manager("profile", "add", "sample-workflow")
        self.run_manager("sync")
        for home in (".agents", ".claude"):
            self.assertTrue((self.project / home / "skills" / "sample-workflow" / "SKILL.md").is_file())

        for home in (".agents", ".claude"):
            manual = self.project / home / "skills" / "manual-skill"
            manual.mkdir()
            (manual / "SKILL.md").write_text("manual\n", encoding="utf-8")

        self.run_manager("profile", "remove", "sample-workflow")
        self.run_manager("sync")
        for home in (".agents", ".claude"):
            self.assertFalse((self.project / home / "skills" / "sample-workflow").exists())
            self.assertTrue((self.project / home / "skills" / "manual-skill" / "SKILL.md").is_file())

        validated = self.run_manager("validate", "--agent")
        self.assertIn("spec_version=1.0", validated.stdout)
        self.assertIn("mode=agent", validated.stdout)
        self.assertIn("command=skills.validate", validated.stdout)
        self.assertIn("status=success", validated.stdout)

    def test_json_output_and_ambiguous_source_failure(self) -> None:
        self.run_manager("init")
        status = self.run_manager("status", "--json")
        envelope = json.loads(status.stdout)
        self.assertEqual(envelope["spec_version"], "1.0")
        self.assertEqual(envelope["mode"], "json")
        self.assertEqual(envelope["command"], "skills.status")
        self.assertEqual(envelope["status"], "success")

        duplicate = self.source / "duplicate-sample"
        shutil.copytree(self.source / "sample-workflow", duplicate)
        failed = self.run_manager("resolve", "sample-workflow", "--agent", check=False)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn("status=failed", failed.stdout)
        self.assertIn("error.code=ambiguous_skill", failed.stdout)

        failed_json = self.run_manager("resolve", "sample-workflow", "--json", check=False)
        self.assertNotEqual(failed_json.returncode, 0)
        error_envelope = json.loads(failed_json.stdout)
        self.assertEqual(error_envelope["status"], "failed")
        self.assertEqual(error_envelope["error"]["code"], "ambiguous_skill")

    def test_dry_run_does_not_change_profile(self) -> None:
        self.run_manager("init")
        profile = self.project / ".skills" / "profiles" / "root.txt"
        before = profile.read_text(encoding="utf-8")
        self.run_manager("profile", "add", "sample-workflow", "--dry-run")
        self.assertEqual(profile.read_text(encoding="utf-8"), before)


if __name__ == "__main__":
    unittest.main()
