#!/usr/bin/env bash
set -euo pipefail

MANAGER_VERSION="0.1.0"
OUTPUT_SPEC_VERSION="1.0"
MANAGER_SKILL="yeisme-skill-routing-governance"
OUTPUT_MODE="summary"
PROJECT_INPUT="$PWD"
SOURCE_INPUT=""
DRY_RUN=0
COMMAND=""
COMMAND_PATH="skills.help"

PROJECT_DIR=""
SOURCE_DIR=""
STATE_DIR=""
PROFILE_FILE=""
SOURCE_FILE=""
MANIFEST_FILE=""

PROJECTION_STATUS="success"
PROJECTION_SUMMARY=""
PROJECTION_ERROR_CODE=""
PROJECTION_ERROR_MESSAGE=""
PROJECTION_ERROR_SUGGESTION=""
PROJECTION_FACT_KEYS=()
PROJECTION_FACT_VALUES=()
PROJECTION_ITEMS=()
PROJECTION_ACTION_NAMES=()
PROJECTION_ACTION_COMMANDS=()

usage() {
  cat <<'EOF'
Usage: scripts/skills.sh [global options] <command> [arguments]

Portable Yeisme Skill manager (alpha).

Global options:
  --project DIR       Project to manage. Defaults to the current directory.
  --source DIR        Skill source checkout. Required for first init.
  --dry-run           Preview a supported state change.
  --agent             Emit stable key=value output.
  --json              Emit one JSON envelope.
  --no-color          Accepted for automation; output never requires color.
  --version           Print the manager version.
  --help              Show this help.

Commands:
  init                         Configure source, create the root profile, add the
                               routing manager, sync, and validate the project.
  configure-source             Update .skills/source.local.
  doctor                       Check tools, source, profile, and runtime state.
  status                       Show project, source, profile, and managed counts.
  list-source                  List every discoverable Skill.
  search QUERY                 Search Skill names, paths, descriptions, and text.
  resolve SKILL               Print the unique source directory for a Skill.
  profile create              Create .skills/profiles/root.txt.
  profile show                Show active Skill names.
  profile add SKILL           Add a unique source Skill to the profile.
  profile remove SKILL        Remove a Skill from the profile.
  profile validate            Validate source uniqueness and profile references.
  sync                         Generate managed Skills in .agents and .claude.
  validate                     Validate profile, manifest, and managed runtimes.

Examples:
  scripts/skills.sh --project /srv/app --source /opt/yeisme-agent-my-skills init
  scripts/skills.sh --project /srv/app search "frontend motion"
  scripts/skills.sh --project /srv/app profile add ui-spec-frontend-workflow
  scripts/skills.sh --project /srv/app sync
  scripts/skills.sh --project /srv/app validate --agent
EOF
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

agent_value() {
  local value="$1"
  if [[ "$value" =~ ^[a-zA-Z0-9_./:@%+=,-]+$ ]]; then
    printf '%s' "$value"
    return
  fi
  printf '"%s"' "$(json_escape "$value")"
}

reset_projection() {
  PROJECTION_STATUS="success"
  PROJECTION_SUMMARY=""
  PROJECTION_ERROR_CODE=""
  PROJECTION_ERROR_MESSAGE=""
  PROJECTION_ERROR_SUGGESTION=""
  PROJECTION_FACT_KEYS=()
  PROJECTION_FACT_VALUES=()
  PROJECTION_ITEMS=()
  PROJECTION_ACTION_NAMES=()
  PROJECTION_ACTION_COMMANDS=()
}

add_fact() {
  PROJECTION_FACT_KEYS[${#PROJECTION_FACT_KEYS[@]}]="$1"
  PROJECTION_FACT_VALUES[${#PROJECTION_FACT_VALUES[@]}]="$2"
}

add_item() {
  PROJECTION_ITEMS[${#PROJECTION_ITEMS[@]}]="$1"
}

add_action() {
  PROJECTION_ACTION_NAMES[${#PROJECTION_ACTION_NAMES[@]}]="$1"
  PROJECTION_ACTION_COMMANDS[${#PROJECTION_ACTION_COMMANDS[@]}]="$2"
}

render_projection() {
  local i
  case "$OUTPUT_MODE" in
    agent)
      printf 'spec_version=%s\n' "$OUTPUT_SPEC_VERSION"
      printf 'mode=agent\n'
      printf 'command=%s\n' "$COMMAND_PATH"
      printf 'status=%s\n' "$PROJECTION_STATUS"
      for ((i = 0; i < ${#PROJECTION_FACT_KEYS[@]}; i++)); do
        printf 'fact.%s=' "${PROJECTION_FACT_KEYS[$i]}"
        agent_value "${PROJECTION_FACT_VALUES[$i]}"
        printf '\n'
      done
      for ((i = 0; i < ${#PROJECTION_ITEMS[@]}; i++)); do
        printf 'item.%d=' "$((i + 1))"
        agent_value "${PROJECTION_ITEMS[$i]}"
        printf '\n'
      done
      for ((i = 0; i < ${#PROJECTION_ACTION_NAMES[@]}; i++)); do
        printf 'action.%s=' "${PROJECTION_ACTION_NAMES[$i]}"
        agent_value "${PROJECTION_ACTION_COMMANDS[$i]}"
        printf '\n'
      done
      if [[ "$PROJECTION_STATUS" == "failed" ]]; then
        printf 'error.code=%s\n' "$PROJECTION_ERROR_CODE"
        printf 'error.message='; agent_value "$PROJECTION_ERROR_MESSAGE"; printf '\n'
        if [[ -n "$PROJECTION_ERROR_SUGGESTION" ]]; then
          printf 'error.suggestion='; agent_value "$PROJECTION_ERROR_SUGGESTION"; printf '\n'
        fi
      fi
      ;;
    json)
      printf '{"spec_version":"%s","mode":"json","command":"%s","status":"%s"' \
        "$OUTPUT_SPEC_VERSION" "$(json_escape "$COMMAND_PATH")" "$PROJECTION_STATUS"
      if [[ -n "$PROJECTION_SUMMARY" ]]; then
        printf ',"summary":"%s"' "$(json_escape "$PROJECTION_SUMMARY")"
      fi
      printf ',"facts":{'
      for ((i = 0; i < ${#PROJECTION_FACT_KEYS[@]}; i++)); do
        [[ "$i" -eq 0 ]] || printf ','
        printf '"%s":"%s"' "$(json_escape "${PROJECTION_FACT_KEYS[$i]}")" "$(json_escape "${PROJECTION_FACT_VALUES[$i]}")"
      done
      printf '},"actions":['
      for ((i = 0; i < ${#PROJECTION_ACTION_NAMES[@]}; i++)); do
        [[ "$i" -eq 0 ]] || printf ','
        printf '{"name":"%s","command":"%s"}' \
          "$(json_escape "${PROJECTION_ACTION_NAMES[$i]}")" \
          "$(json_escape "${PROJECTION_ACTION_COMMANDS[$i]}")"
      done
      printf '],"evidence":[],"data":{"items":['
      for ((i = 0; i < ${#PROJECTION_ITEMS[@]}; i++)); do
        [[ "$i" -eq 0 ]] || printf ','
        printf '"%s"' "$(json_escape "${PROJECTION_ITEMS[$i]}")"
      done
      printf ']}'
      if [[ "$PROJECTION_STATUS" == "failed" ]]; then
        printf ',"error":{"code":"%s","message":"%s"' \
          "$(json_escape "$PROJECTION_ERROR_CODE")" \
          "$(json_escape "$PROJECTION_ERROR_MESSAGE")"
        if [[ -n "$PROJECTION_ERROR_SUGGESTION" ]]; then
          printf ',"suggestion":"%s"' "$(json_escape "$PROJECTION_ERROR_SUGGESTION")"
        fi
        printf ',"retryable":false}'
      fi
      printf '}\n'
      ;;
    summary)
      if [[ "$PROJECTION_STATUS" == "failed" ]]; then
        printf 'Status: failed\n' >&2
        printf 'Error: %s\n' "$PROJECTION_ERROR_MESSAGE" >&2
        if [[ -n "$PROJECTION_ERROR_SUGGESTION" ]]; then
          printf 'Recommended next step: %s\n' "$PROJECTION_ERROR_SUGGESTION" >&2
        fi
        return
      fi
      printf 'Status: success\n'
      [[ -z "$PROJECTION_SUMMARY" ]] || printf 'Summary: %s\n' "$PROJECTION_SUMMARY"
      for ((i = 0; i < ${#PROJECTION_FACT_KEYS[@]}; i++)); do
        printf '%s: %s\n' "${PROJECTION_FACT_KEYS[$i]}" "${PROJECTION_FACT_VALUES[$i]}"
      done
      for ((i = 0; i < ${#PROJECTION_ITEMS[@]}; i++)); do
        printf '%s\n' "${PROJECTION_ITEMS[$i]}"
      done
      if [[ ${#PROJECTION_ACTION_NAMES[@]} -gt 0 ]]; then
        printf 'Recommended next step: %s\n' "${PROJECTION_ACTION_COMMANDS[0]}"
      fi
      ;;
  esac
}

fail() {
  PROJECTION_STATUS="failed"
  PROJECTION_ERROR_CODE="$1"
  PROJECTION_ERROR_MESSAGE="$2"
  PROJECTION_ERROR_SUGGESTION="${3:-}"
  PROJECTION_SUMMARY="$2"
  render_projection
  exit 1
}

canonical_dir() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  (cd "$path" && pwd -P)
}

initialize_project_paths() {
  PROJECT_DIR="$(canonical_dir "$PROJECT_INPUT")" || fail \
    "project_missing" \
    "Project directory does not exist: $PROJECT_INPUT" \
    "Create the project directory, then rerun the command."
  STATE_DIR="$PROJECT_DIR/.skills"
  PROFILE_FILE="$STATE_DIR/profiles/root.txt"
  SOURCE_FILE="$STATE_DIR/source.local"
  MANIFEST_FILE="$STATE_DIR/managed-runtime.txt"
}

load_source() {
  local configured=""
  if [[ -n "$SOURCE_INPUT" ]]; then
    configured="$SOURCE_INPUT"
  elif [[ -f "$SOURCE_FILE" ]]; then
    configured="$(sed -n '1p' "$SOURCE_FILE")"
  fi
  [[ -n "$configured" ]] || fail \
    "source_unconfigured" \
    "No Skill source is configured for $PROJECT_DIR." \
    "Run scripts/skills.sh --project $PROJECT_DIR --source /path/to/skills configure-source"
  SOURCE_DIR="$(canonical_dir "$configured")" || fail \
    "source_missing" \
    "Skill source directory does not exist: $configured" \
    "Run configure-source with a valid Yeisme Skills checkout."
}

skill_files() {
  find "$SOURCE_DIR" \
    \( -type d \( -name .git -o -name .agents -o -name .claude -o -name node_modules -o -name temp \) -prune \) -o \
    \( -type f -name SKILL.md -print \) | sort
}

skill_name_from_file() {
  local file="$1"
  local name
  name="$(sed -n 's/^name:[[:space:]]*//p' "$file" | sed -n '1p')"
  name="${name#\"}"; name="${name%\"}"
  name="${name#\'}"; name="${name%\'}"
  printf '%s\n' "$name"
}

skill_description_from_file() {
  local file="$1"
  local description
  description="$(sed -n 's/^description:[[:space:]]*//p' "$file" | sed -n '1p')"
  description="${description#\"}"; description="${description%\"}"
  description="${description#\'}"; description="${description%\'}"
  printf '%s\n' "$description"
}

relative_to_source() {
  local path="$1"
  case "$path" in
    "$SOURCE_DIR"/*) printf '%s\n' "${path#"$SOURCE_DIR"/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

source_matches() {
  local requested="$1"
  local file name
  while IFS= read -r file; do
    name="$(skill_name_from_file "$file")"
    if [[ "$name" == "$requested" ]]; then
      dirname "$file"
    fi
  done < <(skill_files)
}

validate_skill_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9._-]*$ ]]
}

resolve_skill_raw() {
  local requested="$1"
  validate_skill_name "$requested" || return 2
  local matches count
  matches="$(source_matches "$requested")"
  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    return 3
  fi
  if [[ "$count" -gt 1 ]]; then
    printf '%s\n' "$matches" >&2
    return 4
  fi
  printf '%s\n' "$matches"
}

RESOLVED_SKILL_DIR=""

resolve_skill_required() {
  local requested="$1"
  local resolved=""
  local result=0
  resolved="$(resolve_skill_raw "$requested")" || result=$?
  if [[ "$result" -eq 0 ]]; then
    RESOLVED_SKILL_DIR="$resolved"
    return
  fi
  case "$result" in
    2) fail "invalid_skill_name" "Invalid Skill name: $requested" "Use a lowercase published Skill name." ;;
    3) fail "unknown_skill" "Unknown Skill: $requested" "Run list-source or search before changing the profile." ;;
    4) fail "ambiguous_skill" "Skill name is ambiguous: $requested" "Remove or rename the duplicate source before continuing." ;;
    *) fail "skill_resolution_failed" "Failed to resolve Skill: $requested" ;;
  esac
}

validate_source_raw() {
  local inventory file dir name description
  inventory="$(mktemp)"
  while IFS= read -r file; do
    dir="$(dirname "$file")"
    name="$(skill_name_from_file "$file")"
    description="$(skill_description_from_file "$file")"
    if ! validate_skill_name "$name"; then
      rm -f "$inventory"
      printf 'invalid name in %s\n' "$file" >&2
      return 1
    fi
    if [[ "$name" != "$(basename "$dir")" ]]; then
      rm -f "$inventory"
      printf 'name does not match directory: %s\n' "$file" >&2
      return 1
    fi
    if [[ -z "$description" ]]; then
      rm -f "$inventory"
      printf 'missing description: %s\n' "$file" >&2
      return 1
    fi
    printf '%s\t%s\n' "$name" "$dir" >> "$inventory"
  done < <(skill_files)
  if [[ ! -s "$inventory" ]]; then
    rm -f "$inventory"
    printf 'no Skills found under %s\n' "$SOURCE_DIR" >&2
    return 1
  fi
  local duplicates
  duplicates="$(cut -f1 "$inventory" | sort | uniq -d)"
  if [[ -n "$duplicates" ]]; then
    printf 'duplicate Skill names:\n' >&2
    while IFS= read -r name; do
      [[ -z "$name" ]] || grep -F "${name}"$'\t' "$inventory" >&2
    done <<< "$duplicates"
    rm -f "$inventory"
    return 1
  fi
  rm -f "$inventory"
}

profile_entries() {
  [[ -f "$PROFILE_FILE" ]] || return 0
  sed 's/[[:space:]]*#.*$//' "$PROFILE_FILE" | sed '/^[[:space:]]*$/d' | sort -u
}

manifest_entries() {
  [[ -f "$MANIFEST_FILE" ]] || return 0
  sed 's/[[:space:]]*#.*$//' "$MANIFEST_FILE" | sed '/^[[:space:]]*$/d' | sort -u
}

line_in_stream() {
  local needle="$1"
  grep -Fxq "$needle"
}

create_profile_raw() {
  mkdir -p "$(dirname "$PROFILE_FILE")"
  if [[ -f "$PROFILE_FILE" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  printf '# Active Skills for this project.\n# Managed by the portable Yeisme Skill manager.\n' > "$PROFILE_FILE"
}

profile_add_raw() {
  local skill="$1"
  resolve_skill_required "$skill"
  create_profile_raw
  if profile_entries | line_in_stream "$skill"; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  printf '\n%s\n' "$skill" >> "$PROFILE_FILE"
}

profile_remove_raw() {
  local skill="$1"
  [[ -f "$PROFILE_FILE" ]] || fail "profile_missing" "Profile does not exist: $PROFILE_FILE" "Run profile create or init."
  if ! profile_entries | line_in_stream "$skill"; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  local staged
  staged="$(mktemp "$(dirname "$PROFILE_FILE")/.profile.XXXXXX")"
  awk -v skill="$skill" '
    {
      normalized=$0
      sub(/[[:space:]]*#.*/, "", normalized)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", normalized)
      if (normalized != skill) print
    }
  ' "$PROFILE_FILE" > "$staged"
  mv "$staged" "$PROFILE_FILE"
}

profile_validate_raw() {
  [[ -f "$PROFILE_FILE" ]] || return 1
  validate_source_raw || return 1
  local skill
  while IFS= read -r skill; do
    resolve_skill_raw "$skill" >/dev/null || return 1
  done < <(profile_entries)
}

write_source_config_raw() {
  [[ -n "$SOURCE_INPUT" ]] || fail "source_required" "--source is required for configure-source." "Pass the public Yeisme Skills checkout path."
  SOURCE_DIR="$(canonical_dir "$SOURCE_INPUT")" || fail "source_missing" "Skill source directory does not exist: $SOURCE_INPUT"
  mkdir -p "$STATE_DIR"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    printf '%s\n' "$SOURCE_DIR" > "$SOURCE_FILE"
    local local_exclude="$PROJECT_DIR/.git/info/exclude"
    if [[ -f "$local_exclude" ]] && ! grep -Fxq '.skills/source.local' "$local_exclude"; then
      printf '\n.skills/source.local\n' >> "$local_exclude"
    fi
  fi
}

write_manifest_to() {
  local destination="$1"
  {
    printf '# schema_version=1\n'
    printf '# Generated by portable Yeisme Skill manager.\n'
    profile_entries
  } > "$destination"
}

sync_raw() {
  profile_validate_raw || fail "profile_invalid" "Skill source or profile is invalid." "Run profile validate and fix every reported source conflict."
  mkdir -p "$STATE_DIR"

  local stage_root agents_stage claude_stage agents_active claude_active
  stage_root="$(mktemp -d "$STATE_DIR/.skill-sync.XXXXXX")"
  agents_stage="$stage_root/agents-stage"
  claude_stage="$stage_root/claude-stage"
  agents_active="$PROJECT_DIR/.agents/skills"
  claude_active="$PROJECT_DIR/.claude/skills"
  mkdir -p "$agents_stage" "$claude_stage"
  if [[ -d "$agents_active" ]]; then cp -R "$agents_active/." "$agents_stage/"; fi
  if [[ -d "$claude_active" ]]; then cp -R "$claude_active/." "$claude_stage/"; fi

  local old_skill skill src target
  while IFS= read -r old_skill; do
    [[ -z "$old_skill" ]] && continue
    if ! profile_entries | line_in_stream "$old_skill"; then
      rm -rf "${agents_stage:?}/$old_skill" "${claude_stage:?}/$old_skill"
    fi
  done < <(manifest_entries)

  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    resolve_skill_required "$skill"
    src="$RESOLVED_SKILL_DIR"
    for target in "$agents_stage/$skill" "$claude_stage/$skill"; do
      if [[ -e "$target" ]] && ! manifest_entries | line_in_stream "$skill"; then
        if [[ ! -d "$target" ]] || ! diff -qr "$src" "$target" >/dev/null 2>&1; then
          rm -rf "$stage_root"
          fail "runtime_conflict" "Unmanaged runtime entry conflicts with profile Skill: $skill" "Remove the conflicting entry or make it identical to the source before syncing."
        fi
      fi
      rm -rf "$target"
      cp -R "$src" "$target"
    done
  done < <(profile_entries)

  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if ! diff -qr "$agents_stage/$skill" "$claude_stage/$skill" >/dev/null; then
      rm -rf "$stage_root"
      fail "staged_runtime_mismatch" "Staged runtime contents differ for Skill: $skill"
    fi
  done < <(profile_entries)

  local manifest_stage="$stage_root/managed-runtime.txt"
  write_manifest_to "$manifest_stage"
  SYNC_COUNT="$(profile_entries | wc -l | tr -d ' ')"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    rm -rf "$stage_root"
    return 0
  fi

  mkdir -p "$PROJECT_DIR/.agents" "$PROJECT_DIR/.claude"
  local agents_backup="$stage_root/agents-backup"
  local claude_backup="$stage_root/claude-backup"
  local manifest_backup="$stage_root/manifest-backup"
  [[ ! -d "$agents_active" ]] || mv "$agents_active" "$agents_backup"
  [[ ! -d "$claude_active" ]] || mv "$claude_active" "$claude_backup"
  [[ ! -f "$MANIFEST_FILE" ]] || cp "$MANIFEST_FILE" "$manifest_backup"

  local applied=0
  if mv "$agents_stage" "$agents_active" && mv "$claude_stage" "$claude_active" && mv "$manifest_stage" "$MANIFEST_FILE"; then
    applied=1
  fi
  if [[ "$applied" -ne 1 ]]; then
    rm -rf "$agents_active" "$claude_active"
    [[ ! -d "$agents_backup" ]] || mv "$agents_backup" "$agents_active"
    [[ ! -d "$claude_backup" ]] || mv "$claude_backup" "$claude_active"
    if [[ -f "$manifest_backup" ]]; then
      cp "$manifest_backup" "$MANIFEST_FILE"
    else
      rm -f "$MANIFEST_FILE"
    fi
    rm -rf "$stage_root"
    fail "sync_failed" "Failed to replace managed runtimes; previous runtime was restored."
  fi
  rm -rf "$stage_root"
}

validate_runtime_raw() {
  profile_validate_raw || return 1
  [[ -f "$MANIFEST_FILE" ]] || return 1
  local mismatch
  mismatch="$(comm -3 <(profile_entries) <(manifest_entries) || true)"
  [[ -z "$mismatch" ]] || return 1
  local skill src agents_skill claude_skill
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    src="$(resolve_skill_raw "$skill")" || return 1
    agents_skill="$PROJECT_DIR/.agents/skills/$skill"
    claude_skill="$PROJECT_DIR/.claude/skills/$skill"
    [[ -d "$agents_skill" && ! -L "$agents_skill" ]] || return 1
    [[ -d "$claude_skill" && ! -L "$claude_skill" ]] || return 1
    diff -qr "$src" "$agents_skill" >/dev/null || return 1
    diff -qr "$src" "$claude_skill" >/dev/null || return 1
    diff -qr "$agents_skill" "$claude_skill" >/dev/null || return 1
  done < <(profile_entries)
}

command_init() {
  COMMAND_PATH="skills.init"
  [[ "$DRY_RUN" -eq 0 ]] || fail "dry_run_unsupported" "init does not support --dry-run." "Use profile add or sync with --dry-run after initialization."
  write_source_config_raw
  create_profile_raw
  load_source
  profile_add_raw "$MANAGER_SKILL"
  sync_raw
  validate_runtime_raw || fail "runtime_invalid" "Initialization completed but runtime validation failed."
  PROJECTION_SUMMARY="Project Skill management is initialized."
  add_fact "project" "$PROJECT_DIR"
  add_fact "source" "$SOURCE_DIR"
  add_fact "managed_count" "$SYNC_COUNT"
  add_action "search" "scripts/skills.sh --project $PROJECT_DIR search \"task terms\""
}

command_configure_source() {
  COMMAND_PATH="skills.configure-source"
  write_source_config_raw
  PROJECTION_SUMMARY="Project Skill source is configured."
  add_fact "project" "$PROJECT_DIR"
  add_fact "source" "$SOURCE_DIR"
  add_action "validate_profile" "scripts/skills.sh --project $PROJECT_DIR profile validate"
}

command_list_source() {
  COMMAND_PATH="skills.list-source"
  load_source
  validate_source_raw || fail "source_invalid" "Skill source validation failed."
  local file name description dir count=0
  while IFS= read -r file; do
    name="$(skill_name_from_file "$file")"
    description="$(skill_description_from_file "$file")"
    dir="$(dirname "$file")"
    add_item "$name\t$(relative_to_source "$dir")\t$description"
    count=$((count + 1))
  done < <(skill_files)
  PROJECTION_SUMMARY="Source Skills were listed."
  add_fact "count" "$count"
  add_fact "source" "$SOURCE_DIR"
}

command_search() {
  COMMAND_PATH="skills.search"
  local query="${1:-}"
  [[ -n "$query" ]] || fail "query_required" "search requires a query."
  load_source
  local file dir name description count=0
  while IFS= read -r file; do
    dir="$(dirname "$file")"
    name="$(skill_name_from_file "$file")"
    description="$(skill_description_from_file "$file")"
    if printf '%s\n%s\n%s\n' "$name" "$dir" "$description" | grep -Fqi -- "$query" || grep -Fqi -- "$query" "$file"; then
      add_item "$name\t$(relative_to_source "$dir")\t$description"
      count=$((count + 1))
    fi
  done < <(skill_files)
  PROJECTION_SUMMARY="Skill search completed."
  add_fact "query" "$query"
  add_fact "count" "$count"
  add_action "resolve" "scripts/skills.sh --project $PROJECT_DIR resolve <skill-name>"
}

command_resolve() {
  COMMAND_PATH="skills.resolve"
  local skill="${1:-}"
  [[ -n "$skill" ]] || fail "skill_required" "resolve requires a Skill name."
  load_source
  local resolved
  resolve_skill_required "$skill"
  resolved="$RESOLVED_SKILL_DIR"
  PROJECTION_SUMMARY="Skill source was resolved."
  add_fact "skill" "$skill"
  add_fact "path" "$resolved"
}

command_profile() {
  local action="${1:-}"
  local skill="${2:-}"
  case "$action" in
    create)
      COMMAND_PATH="skills.profile.create"
      create_profile_raw
      PROJECTION_SUMMARY="Project Skill profile is available."
      add_fact "profile" "$PROFILE_FILE"
      ;;
    show)
      COMMAND_PATH="skills.profile.show"
      [[ -f "$PROFILE_FILE" ]] || fail "profile_missing" "Profile does not exist: $PROFILE_FILE" "Run profile create or init."
      local count=0 entry
      while IFS= read -r entry; do add_item "$entry"; count=$((count + 1)); done < <(profile_entries)
      PROJECTION_SUMMARY="Active Skill profile was listed."
      add_fact "count" "$count"
      add_fact "profile" "$PROFILE_FILE"
      ;;
    add)
      COMMAND_PATH="skills.profile.add"
      [[ -n "$skill" ]] || fail "skill_required" "profile add requires a Skill name."
      load_source
      profile_add_raw "$skill"
      PROJECTION_SUMMARY="Skill is assigned to the project profile."
      add_fact "skill" "$skill"
      add_fact "dry_run" "$DRY_RUN"
      add_action "sync" "scripts/skills.sh --project $PROJECT_DIR sync"
      ;;
    remove)
      COMMAND_PATH="skills.profile.remove"
      [[ -n "$skill" ]] || fail "skill_required" "profile remove requires a Skill name."
      profile_remove_raw "$skill"
      PROJECTION_SUMMARY="Skill is removed from the project profile."
      add_fact "skill" "$skill"
      add_fact "dry_run" "$DRY_RUN"
      add_action "sync" "scripts/skills.sh --project $PROJECT_DIR sync"
      ;;
    validate)
      COMMAND_PATH="skills.profile.validate"
      load_source
      profile_validate_raw || fail "profile_invalid" "Skill source or profile validation failed."
      PROJECTION_SUMMARY="Skill source and profile are valid."
      add_fact "profile" "$PROFILE_FILE"
      add_fact "count" "$(profile_entries | wc -l | tr -d ' ')"
      ;;
    *) fail "profile_action_required" "profile requires create, show, add, remove, or validate." ;;
  esac
}

command_sync() {
  COMMAND_PATH="skills.sync"
  load_source
  sync_raw
  PROJECTION_SUMMARY="Managed Skills were synchronized to both runtimes."
  add_fact "project" "$PROJECT_DIR"
  add_fact "managed_count" "$SYNC_COUNT"
  add_fact "dry_run" "$DRY_RUN"
  add_action "validate" "scripts/skills.sh --project $PROJECT_DIR validate"
}

command_validate() {
  COMMAND_PATH="skills.validate"
  load_source
  validate_runtime_raw || fail "runtime_invalid" "Profile, manifest, or managed runtime validation failed." "Run sync after fixing source and profile errors."
  PROJECTION_SUMMARY="Managed Skill runtimes are valid."
  add_fact "project" "$PROJECT_DIR"
  add_fact "managed_count" "$(manifest_entries | wc -l | tr -d ' ')"
}

command_status() {
  COMMAND_PATH="skills.status"
  load_source
  PROJECTION_SUMMARY="Project Skill management status is available."
  add_fact "manager_version" "$MANAGER_VERSION"
  add_fact "project" "$PROJECT_DIR"
  add_fact "source" "$SOURCE_DIR"
  add_fact "profile" "$PROFILE_FILE"
  add_fact "profile_count" "$(profile_entries | wc -l | tr -d ' ')"
  add_fact "managed_count" "$(manifest_entries | wc -l | tr -d ' ')"
}

command_doctor() {
  COMMAND_PATH="skills.doctor"
  local required missing=""
  for required in awk comm cp cut diff dirname find grep mktemp mv sed sort uniq wc; do
    if ! command -v "$required" >/dev/null 2>&1; then
      missing="$missing $required"
    fi
  done
  [[ -z "$missing" ]] || fail "missing_tools" "Required tools are missing:$missing"
  load_source
  validate_source_raw || fail "source_invalid" "Skill source validation failed."
  [[ -f "$PROFILE_FILE" ]] || fail "profile_missing" "Profile does not exist: $PROFILE_FILE" "Run init or profile create."
  PROJECTION_SUMMARY="Portable Skill manager prerequisites are healthy."
  add_fact "manager_version" "$MANAGER_VERSION"
  add_fact "project" "$PROJECT_DIR"
  add_fact "source" "$SOURCE_DIR"
  if validate_runtime_raw; then add_fact "runtime_state" "valid"; else add_fact "runtime_state" "needs_sync"; fi
}

parse_global_options() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 ]] || fail "option_value_required" "--project requires a directory."
        PROJECT_INPUT="$2"; shift 2 ;;
      --source)
        [[ $# -ge 2 ]] || fail "option_value_required" "--source requires a directory."
        SOURCE_INPUT="$2"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --agent) OUTPUT_MODE="agent"; shift ;;
      --json) OUTPUT_MODE="json"; shift ;;
      --no-color) shift ;;
      --version)
        printf '%s\n' "$MANAGER_VERSION"
        exit 0
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --) shift; break ;;
      -*) fail "unknown_option" "Unknown option: $1" "Run scripts/skills.sh --help." ;;
      *)
        COMMAND="$1"
        shift
        REMAINING_ARGS=("$@")
        return
        ;;
    esac
  done
  REMAINING_ARGS=()
}

parse_remaining_global_options() {
  local filtered=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project)
        [[ $# -ge 2 ]] || fail "option_value_required" "--project requires a directory."
        PROJECT_INPUT="$2"; shift 2 ;;
      --source)
        [[ $# -ge 2 ]] || fail "option_value_required" "--source requires a directory."
        SOURCE_INPUT="$2"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --agent) OUTPUT_MODE="agent"; shift ;;
      --json) OUTPUT_MODE="json"; shift ;;
      --no-color) shift ;;
      --) shift; while [[ $# -gt 0 ]]; do filtered[${#filtered[@]}]="$1"; shift; done ;;
      *) filtered[${#filtered[@]}]="$1"; shift ;;
    esac
  done
  REMAINING_ARGS=("${filtered[@]}")
}

main() {
  reset_projection
  REMAINING_ARGS=()
  parse_global_options "$@"
  if [[ -z "$COMMAND" ]]; then
    usage
    exit 0
  fi
  parse_remaining_global_options "${REMAINING_ARGS[@]}"
  initialize_project_paths
  case "$COMMAND" in
    init) command_init "${REMAINING_ARGS[@]}" ;;
    configure-source) command_configure_source "${REMAINING_ARGS[@]}" ;;
    doctor) command_doctor "${REMAINING_ARGS[@]}" ;;
    status) command_status "${REMAINING_ARGS[@]}" ;;
    list-source) command_list_source "${REMAINING_ARGS[@]}" ;;
    search) command_search "${REMAINING_ARGS[@]}" ;;
    resolve) command_resolve "${REMAINING_ARGS[@]}" ;;
    profile) command_profile "${REMAINING_ARGS[@]}" ;;
    sync) command_sync "${REMAINING_ARGS[@]}" ;;
    validate) command_validate "${REMAINING_ARGS[@]}" ;;
    help) usage; exit 0 ;;
    *) fail "unknown_command" "Unknown command: $COMMAND" "Run scripts/skills.sh --help." ;;
  esac
  render_projection
}

main "$@"
