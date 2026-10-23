#!/usr/bin/env bash
# Shared safety contract. Sourced only from the installed manager directory.
# shellcheck disable=SC2034  # Projection globals are consumed by skills.sh.
BASELINE_HEADER=$'# runtime-baseline.v1\tminimum-manager=0.3.0'
SAFE_TARGETS=(.agents/skills .claude/skills .skills/profiles/root.txt .skills/source.local .skills/managed-runtime.txt .skills/runtime-baseline.v1.tsv)
TXN=""
LOCK_OWNED=0
SAFETY_PROJECT=""
DRY_STAGE=""

safe_path() {
  local p="$1"
  [[ "$p" == /* ]] || p="$PWD/$p"
  [[ "$p" != *$'\n'* && "$p" != *$'\r'* && "$p" != *$'\t'* ]] || return 1
  while [[ "$p" != / && -n "$p" ]]; do
    [[ ! -L "$p" ]] || return 1
    p="$(dirname -- "$p")"
  done
}

hash_input() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d ' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d ' ' -f1
  else return 1; fi
}

tree_digest() (
  set -euo pipefail
  local root="$1" p name mode content
  safe_path "$root" || exit 1
  if [[ ! -e "$root" ]]; then printf 'absent\n'; exit; fi
  find "$root" -print0 | LC_ALL=C sort -z | {
    while IFS= read -r -d '' p; do
      safe_path "$p" || exit 1
      name="${p#"$root"}"; name="${name#/}"
      mode="$(stat -c %a -- "$p" 2>/dev/null || stat -f %Lp -- "$p")" || exit 1
      mode="$((8#$mode & 0111))"
      if [[ -d "$p" ]]; then printf 'd\0%s\0%s\0' "$name" "$mode"
      elif [[ -f "$p" && ! -L "$p" ]]; then
        content="$(hash_input < "$p")" || exit 1
        printf 'f\0%s\0%s\0%s\0' "$name" "$mode" "$content"
      else exit 1; fi
    done
  } | hash_input
)

baseline_write() {
  local destination="$1" skill digest
  printf '%s\n' "$BASELINE_HEADER" > "$destination"
  while IFS= read -r skill; do
    validate_skill_name "$skill" || fail "baseline_invalid" "Invalid managed Skill name."
    digest="$(tree_digest "$PROJECT_DIR/.agents/skills/$skill")" || fail "unsafe_path" "Unsafe managed Skill tree."
    [[ "$digest" != absent && "$digest" == "$(tree_digest "$PROJECT_DIR/.claude/skills/$skill")" ]] || fail "runtime_drift" "Runtime copies differ."
    printf '%s\t%s\n' "$skill" "$digest" >> "$destination"
  done < <(manifest_entries)
}

baseline_check() {
  local path="$STATE_DIR/runtime-baseline.v1.tsv" skill digest extra names="" expected="" header
  [[ -f "$path" && ! -L "$path" ]] || return 2
  IFS= read -r header < "$path"
  [[ "$header" == "$BASELINE_HEADER" ]] || return 3
  while IFS=$'\t' read -r skill digest extra; do
    [[ "$skill" == \#* ]] && continue
    validate_skill_name "$skill" && [[ "$digest" =~ ^[a-f0-9]{64}$ && -z "$extra" ]] || return 3
    names+="$skill"$'\n'
    [[ "$(tree_digest "$PROJECT_DIR/.agents/skills/$skill")" == "$digest" && "$(tree_digest "$PROJECT_DIR/.claude/skills/$skill")" == "$digest" ]] || return 1
  done < "$path"
  expected="$(manifest_entries)"
  [[ "${names%$'\n'}" == "$expected" ]] || return 3
}

require_baseline() {
  local result=0
  if [[ -f "$MANIFEST_FILE" || -f "$STATE_DIR/runtime-baseline.v1.tsv" ]]; then
    baseline_check || result=$?
    case "$result" in
      0) ;;
      2) fail "state_migration_required" "Run state migrate with the original configured source before changing this project." ;;
      3) fail "baseline_invalid" "Managed baseline or manifest is invalid; no content was adopted." ;;
      *) fail "runtime_drift" "Managed runtime differs from its last synchronized baseline; preserve and resolve user edits first." ;;
    esac
  fi
}

require_safe_source() {
  load_source
  validate_source_raw || fail "source_invalid" "Target source must contain unique Skills."
  if [[ -f "$PROFILE_FILE" ]]; then profile_validate_raw || fail "profile_invalid" "Target source must resolve every requested Skill uniquely."; fi
  local manager
  manager="$(resolve_skill_raw "$MANAGER_SKILL")" || fail "manager_downgrade_blocked" "Target source must contain the safe manager."
  safe_path "$manager" && [[ -f "$manager/scripts/safe-state.sh" && ! -L "$manager/scripts/safe-state.sh" ]] &&
    grep -Fxq '# safe-management-contract: 1' "$manager/scripts/skills.sh" || fail "manager_downgrade_blocked" "Target source does not support safety contract v1."
  local skill source
  while IFS= read -r skill; do
    source="$(resolve_skill_raw "$skill")"
    tree_digest "$source" >/dev/null || fail "unsafe_path" "Source Skill contains unsafe paths or files."
  done < <(profile_entries)
}

command_state_migrate() {
  COMMAND_PATH="skills.state.migrate"
  if [[ -f "$STATE_DIR/runtime-baseline.v1.tsv" ]]; then require_baseline; PROJECTION_SUMMARY="Safety baseline already exists."; return; fi
  [[ -z "$SOURCE_INPUT" && -f "$SOURCE_FILE" ]] || fail "migration_source_invalid" "Migration requires the original source.local; do not pass --source."
  load_source
  validate_runtime_raw || fail "migration_conflict" "Original source, profile, manifest and both runtimes must match exactly."
  local skill src
  while IFS= read -r skill; do
    src="$(resolve_skill_raw "$skill")"
    [[ "$(tree_digest "$src")" == "$(tree_digest "$PROJECT_DIR/.agents/skills/$skill")" && "$(tree_digest "$src")" == "$(tree_digest "$PROJECT_DIR/.claude/skills/$skill")" ]] || fail "migration_conflict" "Legacy content or executable modes differ from the original source."
  done < <(manifest_entries)
  [[ "$DRY_RUN" -eq 1 ]] || baseline_write "$STATE_DIR/runtime-baseline.v1.tsv"
  PROJECTION_SUMMARY="Legacy state verified against the original source."
  add_fact "dry_run" "$DRY_RUN"
}

# Recovery only handles these fixed targets. Journal data is never evaluated.
restore_transaction() {
  local txn="$1" i old new current extra count=0
  local old_values=() new_values=()
  safe_path "$txn/journal" && [[ -f "$txn/journal" ]] || return 1
  while IFS=$'\t' read -r i old new extra; do
    [[ "$i" == "$count" && -z "$extra" && "$old" =~ ^(absent|[a-f0-9]{64})$ && "$new" =~ ^(absent|[a-f0-9]{64})$ ]] || return 1
    [[ "$count" -lt "${#SAFE_TARGETS[@]}" ]] || return 1
    if [[ -f "$txn/publishing" ]]; then [[ "$(tree_digest "$txn/old/$i")" == "$old" ]] || return 1; fi
    current="$(tree_digest "$PROJECT_DIR/${SAFE_TARGETS[$i]}")" || return 1
    [[ "$current" == "$old" || "$current" == "$new" || "$current" == absent && -f "$txn/moving-$i" ]] || return 1
    old_values[$i]="$old"; new_values[$i]="$new"
    count=$((count + 1))
  done < "$txn/journal"
  [[ "$count" -eq "${#SAFE_TARGETS[@]}" ]] || return 1
  # Prepublication interruptions never changed targets; no backup copy is needed.
  if [[ ! -f "$txn/publishing" ]]; then
    for i in "${!SAFE_TARGETS[@]}"; do [[ "$(tree_digest "$PROJECT_DIR/${SAFE_TARGETS[$i]}")" == "${old_values[$i]}" ]] || return 1; done
    rm -rf -- "$txn"; return
  fi
  # All paths are prevalidated before any restoration.
  for i in "${!SAFE_TARGETS[@]}"; do
    local target="$PROJECT_DIR/${SAFE_TARGETS[$i]}"
    current="$(tree_digest "$target")" || return 1
    [[ "$current" == "${old_values[$i]}" || "$current" == "${new_values[$i]}" || "$current" == absent && -f "$txn/moving-$i" ]] || return 1
    rm -rf -- "$target"
    if [[ -e "$txn/old/$i" ]]; then mkdir -p -- "$(dirname -- "$target")"; cp -pR -- "$txn/old/$i" "$target" || return 1; fi
  done
  rm -rf -- "$txn"
}

transaction_exit() {
  local code=$?
  trap - EXIT INT TERM
  PROJECT_DIR="$SAFETY_PROJECT"
  [[ -z "$DRY_STAGE" ]] || rm -rf -- "$DRY_STAGE"
  if [[ -n "$TXN" && -d "$TXN" ]]; then
    if [[ -f "$TXN/journal" ]]; then
      if ! restore_transaction "$TXN"; then
        printf 'Recovery required: %s\n' "$(basename -- "$TXN")" >&2
      fi
    else rm -rf -- "$TXN"; fi
  fi
  if [[ "$LOCK_OWNED" -eq 1 ]]; then rm -rf -- "$PROJECT_DIR/.skills/.manager-lock"; fi
  if [[ "$code" -ne 0 && "$PROJECTION_STATUS" != failed ]]; then
    PROJECTION_STATUS="failed"; PROJECTION_ERROR_CODE="transaction_failed"
    PROJECTION_ERROR_MESSAGE="Manager transaction failed; inspect recovery state before retrying."
    PROJECTION_SUMMARY="$PROJECTION_ERROR_MESSAGE"; render_projection
  fi
  exit "$code"
}

command_state_recover() {
  COMMAND_PATH="skills.state.recover"
  [[ "${1:-}" == --transaction && "${2:-}" =~ ^\.skill-txn\.[a-zA-Z0-9]+$ && $# -eq 2 ]] || fail "transaction_invalid" "Use state recover --transaction <reported-id>."
  local txn="$STATE_DIR/$2" pid=""
  safe_path "$STATE_DIR/.manager-lock" && safe_path "$STATE_DIR/.recovery-lock" || fail "unsafe_path" "Unsafe lock path."
  if [[ -f "$STATE_DIR/.manager-lock/pid" ]]; then
    read -r pid < "$STATE_DIR/.manager-lock/pid"
    [[ "$pid" =~ ^[0-9]+$ ]] || fail "lock_invalid" "Invalid writer identity."
    if kill -0 "$pid" 2>/dev/null; then fail "writer_active" "A manager writer may still be active; no lock was taken."; fi
  fi
  [[ "$DRY_RUN" -eq 0 ]] || fail "dry_run_unsupported" "Recovery requires explicit execution."
  mkdir "$STATE_DIR/.recovery-lock" 2>/dev/null || fail "writer_active" "Another recovery may be active."
  if ! restore_transaction "$txn"; then
    rmdir "$STATE_DIR/.recovery-lock"
    fail "recovery_conflict" "Transaction or target changed; no automatic overwrite is allowed."
  fi
  rm -rf -- "$STATE_DIR/.manager-lock"
  rmdir "$STATE_DIR/.recovery-lock"
  PROJECTION_SUMMARY="Recorded transaction restored; user data was not touched."
}

safe_mutation() {
  local original_project="$PROJECT_DIR" stage i old new target
  SAFETY_PROJECT="$PROJECT_DIR"
  safe_path "$PROJECT_DIR" || fail "unsafe_path" "Project path must not traverse symlinks."
  [[ ! -e "$STATE_DIR/.recovery-lock" ]] || fail "recovery_required" "A recovery lock exists; inspect the active recovery before continuing."
  for target in "${SAFE_TARGETS[@]}" .skills/.manager-lock; do safe_path "$PROJECT_DIR/$target" || fail "unsafe_path" "Managed paths must not traverse symlinks."; done
  local pending
  pending="$(find "$STATE_DIR" -maxdepth 1 -name '.skill-txn.*' -print 2>/dev/null || true)"
  [[ -z "$pending" ]] || fail "recovery_required" "An unfinished manager transaction requires explicit state recover."
  if [[ "$COMMAND" != state ]]; then require_baseline; fi
  if [[ "$COMMAND" == init && -f "$SOURCE_FILE" && -n "$SOURCE_INPUT" ]]; then
    [[ "$(canonical_dir "$SOURCE_INPUT")" == "$(head -n 1 "$SOURCE_FILE")" ]] || fail "source_rebind_required" "Use configure-source explicitly; init cannot rebind an existing project."
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    stage="$(mktemp -d)"; DRY_STAGE="$stage"
    trap transaction_exit EXIT
  else
    mkdir -p "$STATE_DIR"
    mkdir "$STATE_DIR/.manager-lock" 2>/dev/null || fail "writer_active" "Another manager holds the project lock."
    LOCK_OWNED=1; printf '%s\n' "$$" > "$STATE_DIR/.manager-lock/pid"
    trap transaction_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    TXN="$(mktemp -d "$STATE_DIR/.skill-txn.XXXXXXXX")"; stage="$TXN/stage"; mkdir "$stage" "$TXN/old"
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    for i in "${!SAFE_TARGETS[@]}"; do
      old="$(tree_digest "$PROJECT_DIR/${SAFE_TARGETS[$i]}")" || fail "unsafe_path" "Unsafe managed tree."
      printf '%s\t%s\t%s\n' "$i" "$old" "$old" >> "$TXN/journal.initial"
    done
    mv "$TXN/journal.initial" "$TXN/journal"
  fi
  # Snapshot fixed targets before executing the command in an isolated project tree.
  for i in "${!SAFE_TARGETS[@]}"; do
    target="${SAFE_TARGETS[$i]}"
    tree_digest "$PROJECT_DIR/$target" >/dev/null || fail "unsafe_path" "Unsafe managed tree."
    if [[ -e "$PROJECT_DIR/$target" ]]; then
      mkdir -p "$stage/$(dirname "$target")"; cp -pR "$PROJECT_DIR/$target" "$stage/$target"
      [[ "$DRY_RUN" -eq 1 ]] || cp -pR "$PROJECT_DIR/$target" "$TXN/old/$i"
    fi
  done
  PROJECT_DIR="$stage"; STATE_DIR="$stage/.skills"; PROFILE_FILE="$STATE_DIR/profiles/root.txt"; SOURCE_FILE="$STATE_DIR/source.local"; MANIFEST_FILE="$STATE_DIR/managed-runtime.txt"
  # Dry-run still executes against a disposable staged tree so all checks are real.
  local requested_dry="$DRY_RUN"; DRY_RUN=0
  dispatch_command
  if [[ "$COMMAND" != state && ! ( "$COMMAND" == profile && "${REMAINING_ARGS[0]:-}" == create && ! -f "$MANIFEST_FILE" ) ]]; then
    require_safe_source
    if [[ -f "$MANIFEST_FILE" ]]; then
      local desired
      desired="$(profile_entries)"
      printf '%s\n' "$desired" | line_in_stream "$MANAGER_SKILL" || fail "manager_required" "Keep the safety manager in the profile."
    fi
  fi
  DRY_RUN="$requested_dry"
  for i in "${!PROJECTION_FACT_VALUES[@]}"; do
    PROJECTION_FACT_VALUES[$i]="${PROJECTION_FACT_VALUES[$i]//"$stage"/"$original_project"}"
    [[ "${PROJECTION_FACT_KEYS[$i]}" != dry_run ]] || PROJECTION_FACT_VALUES[$i]="$DRY_RUN"
  done
  for i in "${!PROJECTION_ACTION_COMMANDS[@]}"; do PROJECTION_ACTION_COMMANDS[$i]="${PROJECTION_ACTION_COMMANDS[$i]//"$stage"/"$original_project"}"; done
  PROJECT_DIR="$original_project"; STATE_DIR="$PROJECT_DIR/.skills"; PROFILE_FILE="$STATE_DIR/profiles/root.txt"; SOURCE_FILE="$STATE_DIR/source.local"; MANIFEST_FILE="$STATE_DIR/managed-runtime.txt"
  if [[ "$DRY_RUN" -eq 1 ]]; then rm -rf "$stage"; DRY_STAGE=""; trap - EXIT; PROJECTION_SUMMARY="Validated dry-run; no project files changed."; return; fi
  if [[ "$COMMAND" != state ]]; then require_baseline; fi
  for i in "${!SAFE_TARGETS[@]}"; do
    old="$(tree_digest "$TXN/old/$i")"; new="$(tree_digest "$stage/${SAFE_TARGETS[$i]}")"
    [[ "$old" == "$(tree_digest "$PROJECT_DIR/${SAFE_TARGETS[$i]}")" ]] || fail "runtime_drift" "Project changed while staging; no replacement was started."
    printf '%s\t%s\t%s\n' "$i" "$old" "$new" >> "$TXN/journal.pending"
  done
  mv "$TXN/journal.pending" "$TXN/journal"
  : > "$TXN/publishing"
  for i in "${!SAFE_TARGETS[@]}"; do
    target="$PROJECT_DIR/${SAFE_TARGETS[$i]}"; mkdir -p "$(dirname "$target")"
    [[ "$(tree_digest "$target")" == "$(tree_digest "$TXN/old/$i")" ]] || fail "runtime_drift" "Target changed immediately before publication."
    : > "$TXN/moving-$i"
    [[ ! -e "$target" ]] || mv "$target" "$TXN/displaced-$i"
    [[ ! -e "$stage/${SAFE_TARGETS[$i]}" ]] || mv "$stage/${SAFE_TARGETS[$i]}" "$target"
  done
  rm -rf "$TXN"; TXN=""
  rm -rf "$STATE_DIR/.manager-lock"; LOCK_OWNED=0
  trap - EXIT INT TERM
  # Git exclusion is advisory, outside managed domain state.
  if [[ "$COMMAND" == init && -f "$PROJECT_DIR/.git/info/exclude" ]] && ! grep -Fxq '.skills/source.local' "$PROJECT_DIR/.git/info/exclude"; then
    printf '\n.skills/source.local\n' >> "$PROJECT_DIR/.git/info/exclude"
  fi
}
