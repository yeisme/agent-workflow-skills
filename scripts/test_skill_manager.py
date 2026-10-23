#!/usr/bin/env python3
"""Regression tests for the portable Yeisme Skill manager."""

from __future__ import annotations

import json
import os
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

    def snapshot(self):
        return {str(p.relative_to(self.project)): (p.read_bytes(), p.stat().st_mode & 0o111)
                for p in self.project.rglob("*") if p.is_file() and ".git" not in p.parts}

    def test_drift_blocks_every_mutation_and_preserves_bytes(self):
        self.run_manager("init")
        active = self.project / ".agents/skills/yeisme-skill-routing-governance/SKILL.md"
        original = active.read_bytes()
        for mutation in (lambda: active.write_text("user edit"), lambda: active.chmod(0o755), lambda: active.unlink()):
            mutation()
            before = self.snapshot()
            for args in [("sync",), ("profile", "remove", "yeisme-skill-routing-governance"), ("profile", "add", "sample-workflow"), ("configure-source",), ("init",)]:
                result = self.run_manager(*args, "--json", check=False)
                self.assertEqual(json.loads(result.stdout)["error"]["code"], "runtime_drift")
                self.assertEqual(before, self.snapshot())
            active.write_bytes(original)
            active.chmod(0o644)
        self.run_manager("sync")

    def test_source_update_migration_and_downgrade(self):
        self.run_manager("init")
        baseline = self.project / ".skills/runtime-baseline.v1.tsv"
        baseline.unlink()
        self.assertIn("state_migration_required", self.run_manager("sync", "--json", check=False).stdout)
        migrate = [str(ENGINE), "--project", str(self.project), "state", "migrate", "--json"]
        self.assertEqual(subprocess.run(migrate, capture_output=True, check=False).returncode, 0)
        source_doc = self.source / MANAGER_SOURCE.name / "SKILL.md"
        source_doc.write_text(source_doc.read_text() + "\nUpdated source.\n")
        self.assertIn("source_update_pending", self.run_manager("doctor", "--json").stdout)
        self.run_manager("sync")
        self.run_manager("validate")
        engine = self.source / MANAGER_SOURCE.name / "scripts/skills.sh"
        engine.write_text(engine.read_text().replace("# safe-management-contract: 1", "# old contract"))
        before = self.snapshot()
        self.assertIn("manager_downgrade_blocked", self.run_manager("sync", "--json", check=False).stdout)
        self.assertEqual(before, self.snapshot())

    def test_unsafe_source_and_baseline_are_rejected(self):
        self.run_manager("init")
        (self.source / MANAGER_SOURCE.name / "unsafe").symlink_to(self.source / "sample-workflow")
        before = self.snapshot()
        self.assertNotEqual(self.run_manager("sync", check=False).returncode, 0)
        self.assertEqual(before, self.snapshot())
        (self.source / MANAGER_SOURCE.name / "unsafe").unlink()
        baseline = self.project / ".skills/runtime-baseline.v1.tsv"
        baseline.write_text("invalid\n")
        self.assertIn("baseline_invalid", self.run_manager("sync", "--json", check=False).stdout)

    def test_interrupted_publish_requires_verified_recovery(self):
        self.run_manager("init")
        before = self.snapshot()
        fake = self.base / "fake-bin"
        fake.mkdir()
        mv = fake / "mv"
        real_mv = shutil.which("mv")
        mv.write_text('#!/bin/bash\nfor arg in "$@"; do\n case "$arg" in */.skill-txn.*/displaced-0) kill -KILL "$PPID"; exit 1;; esac\ndone\nexec ' + str(real_mv) + ' "$@"\n')
        mv.chmod(0o755)
        proc = subprocess.run([str(ENGINE), "--source", str(self.source), "--project", str(self.project), "sync"], env={**os.environ, "PATH": str(fake) + ":" + os.environ["PATH"]}, capture_output=True, check=False)
        self.assertNotEqual(proc.returncode, 0)
        txns = list((self.project / ".skills").glob(".skill-txn.*"))
        self.assertEqual(len(txns), 1)
        self.assertIn("recovery_required", self.run_manager("sync", "--json", check=False).stdout)
        doc = self.project / ".agents/skills/yeisme-skill-routing-governance/SKILL.md"
        original = doc.read_bytes()
        doc.write_text("new user edit")
        self.assertIn("recovery_conflict", self.run_manager("state", "recover", "--transaction", txns[0].name, "--json", check=False).stdout)
        self.assertEqual(doc.read_text(), "new user edit")
        doc.write_bytes(original)
        self.run_manager("state", "recover", "--transaction", txns[0].name)
        self.assertEqual(before, self.snapshot())
        self.run_manager("validate")

    def test_missing_legacy_source_and_unmanaged_conflict(self):
        self.run_manager("init")
        baseline = self.project / ".skills/runtime-baseline.v1.tsv"
        baseline.unlink()
        saved = self.base / "saved-source"
        self.source.rename(saved)
        result = subprocess.run([str(ENGINE), "--project", str(self.project), "state", "migrate", "--json"], capture_output=True, text=True, check=False)
        self.assertIn("source_missing", result.stdout)
        self.assertFalse(baseline.exists())
        saved.rename(self.source)
        self.assertEqual(subprocess.run([str(ENGINE), "--project", str(self.project), "state", "migrate"], capture_output=True, check=False).returncode, 0)
        self.run_manager("profile", "add", "sample-workflow")
        unknown = self.project / ".agents/skills/sample-workflow"
        unknown.mkdir()
        (unknown / "SKILL.md").write_text("user content")
        before = self.snapshot()
        self.assertIn("runtime_conflict", self.run_manager("sync", "--json", check=False).stdout)
        self.assertEqual(before, self.snapshot())

    def test_publication_failure_restores_old_state(self):
        self.run_manager("init")
        before = self.snapshot()
        fake = self.base / "fake-bin"
        fake.mkdir()
        real_mv = shutil.which("mv")
        mv = fake / "mv"
        mv.write_text('#!/bin/bash\nfor arg in "$@"; do\n case "$arg" in */.skill-txn.*/stage/.agents/skills) exit 55;; esac\ndone\nexec ' + str(real_mv) + ' "$@"\n')
        mv.chmod(0o755)
        proc = subprocess.run([str(ENGINE), "--source", str(self.source), "--project", str(self.project), "sync"], env={**os.environ, "PATH": str(fake) + ":" + os.environ["PATH"]}, capture_output=True, check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(before, self.snapshot())
        self.assertFalse(list((self.project / ".skills").glob(".skill-txn.*")))
        self.run_manager("validate")

    def test_dry_run_does_not_change_profile(self) -> None:
        self.run_manager("init")
        profile = self.project / ".skills" / "profiles" / "root.txt"
        before = profile.read_text(encoding="utf-8")
        files = self.snapshot()
        result = self.run_manager("profile", "add", "sample-workflow", "--dry-run", "--json")
        self.assertEqual(json.loads(result.stdout)["facts"]["dry_run"], "1")
        self.assertNotIn(".skill-txn", result.stdout)
        self.assertEqual(profile.read_text(encoding="utf-8"), before)
        self.assertEqual(files, self.snapshot())


if __name__ == "__main__":
    unittest.main()
