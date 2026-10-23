#!/usr/bin/env python3
"""Run owner tests with private, redacted evidence and the original exit code."""
import datetime
import json
import platform
import re
import shlex
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    args = sys.argv[1:]
    if args[:1] == ["--"]:
        args = args[1:]
    if not args or any("race" in a for a in args):
        return 2
    start = datetime.datetime.now(datetime.timezone.utc)
    run_id = start.strftime("%Y%m%dT%H%M%SZ-") + uuid.uuid4().hex[:8]
    out = ROOT / "temp/integration-test-runs" / run_id
    (out / "artifacts").mkdir(parents=True, mode=0o700)
    def redact(text):
        return re.sub(r"(?i)(authorization|token|password|secret|api[_-]?key)(\s*[:=]\s*)[^\s,]+", r"\1\2[REDACTED]", text)
    def save(name, value):
        text = value if isinstance(value, str) else json.dumps(value, indent=2) + "\n"
        path = out / name
        path.write_text(redact(text))
        path.chmod(0o600)
    try:
        proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True, check=False)
        code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
    except OSError:
        code, stdout, stderr = 1, "", "Test command could not be executed.\n"
    end = datetime.datetime.now(datetime.timezone.utc)
    command = shlex.join(args)
    save("command.txt", command + "\n")
    save("stdout.log", stdout)
    save("stderr.log", stderr)
    save("env.json", {"platform": platform.system(), "arch": platform.machine(), "python": platform.python_version(), "capture": "allowlisted-only"})
    save("summary.json", {"schema_version": "yeisme.integration_test_evidence.v1", "project": "agent-workflow", "run_id": run_id, "layer": "integration", "command": command, "status": "passed" if code == 0 else "failed", "exit_code": code, "started_at": start.isoformat(), "finished_at": end.isoformat(), "duration_ms": int((end-start).total_seconds()*1000), "evidence": {"stdout": "stdout.log", "stderr": "stderr.log", "command": "command.txt", "env": "env.json", "artifacts": "artifacts/"}, "redaction": {"enabled": True, "policy": "yeisme-default"}})
    print(redact(stdout), end="")
    print(redact(stderr), end="", file=sys.stderr)
    print(f"[evidence] {out}", file=sys.stderr)
    return code if code >= 0 else 128-code

if __name__ == "__main__":
    sys.exit(main())
