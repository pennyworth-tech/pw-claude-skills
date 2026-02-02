#!/bin/bash
# =============================================================================
# pw-claude-skills Validator Library v1.0.0
# Shared functions for skill validation scripts
# Based on AQE v3.4.2 Skill Validation System
# =============================================================================

# Prevent multiple inclusion
if [[ -n "${_PW_VALIDATOR_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
export _PW_VALIDATOR_LIB_LOADED=1

# =============================================================================
# Configuration
# =============================================================================
export PW_VALIDATOR_VERSION="1.0.0"
export PW_VALIDATION_LOG="${PW_VALIDATION_LOG:-/tmp/pw-validation.log}"

# Exit codes
export EXIT_PASS=0
export EXIT_FAIL=1
export EXIT_SKIP=2

# Colors (disable if not in terminal)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
  NC=''
fi

# =============================================================================
# Logging Functions
# =============================================================================

_log_to_file() {
  if [[ -n "${PW_VALIDATION_LOG:-}" ]] && [[ "$PW_VALIDATION_LOG" != "/dev/null" ]]; then
    echo "$*" >> "$PW_VALIDATION_LOG" 2>/dev/null || true
  fi
}

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
  _log_to_file "[INFO] $*"
}

success() {
  echo -e "${GREEN}[PASS]${NC} $*"
  _log_to_file "[PASS] $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
  _log_to_file "[WARN] $*"
}

error() {
  echo -e "${RED}[FAIL]${NC} $*" >&2
  _log_to_file "[FAIL] $*"
}

debug() {
  if [[ -n "${PW_DEBUG:-}" ]]; then
    echo -e "${CYAN}[DEBUG]${NC} $*"
    _log_to_file "[DEBUG] $*"
  fi
}

# =============================================================================
# Tool Detection Functions
# =============================================================================

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

check_tool() {
  local tool="$1"
  local required="${2:-false}"

  if command_exists "$tool"; then
    debug "Tool available: $tool"
    return 0
  else
    if [[ "$required" == "true" ]]; then
      error "Required tool missing: $tool"
      return 1
    else
      warn "Optional tool missing: $tool"
      return 2
    fi
  fi
}

check_required_tools() {
  local tools=("$@")
  local missing=()
  local found=()

  for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
      found+=("$tool")
    else
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}"
    return 1
  fi

  success "All required tools present: ${found[*]}"
  return 0
}

# =============================================================================
# JSON Validation Functions
# =============================================================================

validate_json() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    error "File not found: $file"
    return 1
  fi

  if command_exists "jq"; then
    if jq empty "$file" 2>/dev/null; then
      debug "JSON syntax valid (jq): $file"
      return 0
    else
      error "Invalid JSON syntax in: $file"
      return 1
    fi
  elif command_exists "python3"; then
    if python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
      debug "JSON syntax valid (python3): $file"
      return 0
    else
      error "Invalid JSON syntax in: $file"
      return 1
    fi
  elif command_exists "node"; then
    if node -e "JSON.parse(require('fs').readFileSync('$file'))" 2>/dev/null; then
      debug "JSON syntax valid (node): $file"
      return 0
    else
      error "Invalid JSON syntax in: $file"
      return 1
    fi
  else
    warn "No JSON parser available (jq, python3, node)"
    return 2
  fi
}

# =============================================================================
# JSON Schema Validation Functions
# =============================================================================

validate_json_schema() {
  local schema_path="$1"
  local data_path="$2"

  if [[ ! -f "$schema_path" ]]; then
    error "Schema file not found: $schema_path"
    return 1
  fi

  if [[ ! -f "$data_path" ]]; then
    error "Data file not found: $data_path"
    return 1
  fi

  if ! validate_json "$schema_path"; then
    error "Schema file is not valid JSON: $schema_path"
    return 1
  fi

  if ! validate_json "$data_path"; then
    error "Data file is not valid JSON: $data_path"
    return 1
  fi

  if command_exists "ajv"; then
    debug "Using ajv for schema validation"
    local result
    result=$(ajv validate -s "$schema_path" -d "$data_path" 2>&1)
    local status=$?
    if [[ $status -eq 0 ]]; then
      debug "Schema validation passed (ajv)"
      return 0
    else
      error "Schema validation failed (ajv): $result"
      return 1
    fi
  elif command_exists "jsonschema"; then
    debug "Using jsonschema CLI for validation"
    local result
    result=$(jsonschema -i "$data_path" "$schema_path" 2>&1)
    local status=$?
    if [[ $status -eq 0 ]]; then
      debug "Schema validation passed (jsonschema)"
      return 0
    else
      error "Schema validation failed (jsonschema): $result"
      return 1
    fi
  elif command_exists "python3"; then
    debug "Attempting Python jsonschema validation"
    local result
    result=$(python3 -c "
import json
import sys
try:
    from jsonschema import validate, ValidationError
    with open('$schema_path') as f:
        schema = json.load(f)
    with open('$data_path') as f:
        data = json.load(f)
    validate(instance=data, schema=schema)
    print('Schema validation passed')
    sys.exit(0)
except ImportError:
    print('SKIP: Python jsonschema not installed')
    sys.exit(2)
except ValidationError as e:
    print(f'FAIL: {e.message}')
    sys.exit(1)
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
" 2>&1)
    local status=$?
    case $status in
      0) debug "Schema validation passed (python3)"; return 0 ;;
      2) warn "Python jsonschema not installed, skipping schema validation"; return 2 ;;
      *) error "Schema validation failed (python3): $result"; return 1 ;;
    esac
  else
    warn "No JSON schema validator available (ajv, jsonschema, python3+jsonschema)"
    return 2
  fi
}

validate_schema_syntax() {
  local schema_path="$1"

  if [[ ! -f "$schema_path" ]]; then
    error "Schema file not found: $schema_path"
    return 1
  fi

  if ! validate_json "$schema_path"; then
    return 1
  fi

  local has_schema has_type
  has_schema=$(json_get "$schema_path" '."$schema"')
  has_type=$(json_get "$schema_path" '.type')

  if [[ -z "$has_schema" ]] && [[ -z "$has_type" ]]; then
    warn "Schema file may not be a valid JSON Schema (missing \$schema and type)"
    return 0
  fi

  debug "Schema file appears valid: $schema_path"
  return 0
}

# =============================================================================
# JSON Parsing Functions
# =============================================================================

json_get() {
  local json_file="$1"
  local path="$2"

  if command_exists "jq"; then
    jq -r "$path" "$json_file" 2>/dev/null
  elif command_exists "python3"; then
    python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
path = '$path'.strip('.')
for key in path.split('.'):
    if key.startswith('[') and key.endswith(']'):
        idx = int(key[1:-1])
        data = data[idx]
    else:
        data = data.get(key, '')
print(data)
" 2>/dev/null
  else
    error "No JSON parser available (jq or python3)"
    return 1
  fi
}

json_count() {
  local json_file="$1"
  local path="$2"

  if command_exists "jq"; then
    jq "$path | length" "$json_file" 2>/dev/null
  elif command_exists "python3"; then
    python3 -c "
import json
with open('$json_file') as f:
    data = json.load(f)
path = '$path'.strip('.')
for key in path.split('.'):
    if key:
        data = data.get(key, [])
print(len(data) if isinstance(data, list) else 0)
" 2>/dev/null
  else
    return 1
  fi
}

# =============================================================================
# Content Validation Functions
# =============================================================================

contains_all() {
  local content="$1"
  shift
  local terms=("$@")
  local missing=()

  for term in "${terms[@]}"; do
    if ! grep -qi "$term" <<< "$content"; then
      missing+=("$term")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    debug "Missing required terms: ${missing[*]}"
    return 1
  fi

  return 0
}

contains_none() {
  local content="$1"
  shift
  local terms=("$@")
  local found=()

  for term in "${terms[@]}"; do
    if grep -qi "$term" <<< "$content"; then
      found+=("$term")
    fi
  done

  if [[ ${#found[@]} -gt 0 ]]; then
    debug "Found forbidden terms: ${found[*]}"
    return 1
  fi

  return 0
}

validate_enum() {
  local value="$1"
  shift
  local allowed=("$@")

  for v in "${allowed[@]}"; do
    if [[ "$value" == "$v" ]]; then
      return 0
    fi
  done

  debug "Invalid enum value: '$value' (allowed: ${allowed[*]})"
  return 1
}

# =============================================================================
# Result Output Functions
# =============================================================================

output_result() {
  local status="$1"
  local message="$2"
  local details="${3:-}"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  if command_exists "jq"; then
    jq -n \
      --arg status "$status" \
      --arg message "$message" \
      --arg details "$details" \
      --arg timestamp "$timestamp" \
      --arg version "$PW_VALIDATOR_VERSION" \
      '{
        status: $status,
        message: $message,
        details: $details,
        timestamp: $timestamp,
        validatorVersion: $version
      }'
  else
    cat <<EOF
{
  "status": "$status",
  "message": "$message",
  "details": "$details",
  "timestamp": "$timestamp",
  "validatorVersion": "$PW_VALIDATOR_VERSION"
}
EOF
  fi
}

output_validation_report() {
  local skill_name="$1"
  local schema_status="$2"
  local content_status="$3"
  local tool_status="$4"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local overall_status="passed"
  if [[ "$schema_status" == "failed" ]] || [[ "$content_status" == "failed" ]] || [[ "$tool_status" == "failed" ]]; then
    overall_status="failed"
  elif [[ "$schema_status" == "skipped" ]] || [[ "$content_status" == "skipped" ]] || [[ "$tool_status" == "skipped" ]]; then
    overall_status="partial"
  fi

  if command_exists "jq"; then
    jq -n \
      --arg skill "$skill_name" \
      --arg overall "$overall_status" \
      --arg schema "$schema_status" \
      --arg content "$content_status" \
      --arg tools "$tool_status" \
      --arg timestamp "$timestamp" \
      '{
        skillName: $skill,
        overallStatus: $overall,
        validations: {
          schema: $schema,
          content: $content,
          tools: $tools
        },
        timestamp: $timestamp
      }'
  else
    cat <<EOF
{
  "skillName": "$skill_name",
  "overallStatus": "$overall_status",
  "validations": {
    "schema": "$schema_status",
    "content": "$content_status",
    "tools": "$tool_status"
  },
  "timestamp": "$timestamp"
}
EOF
  fi
}

# =============================================================================
# Self-Test Function
# =============================================================================

run_self_test() {
  local verbose=false
  [[ "${1:-}" == "--verbose" ]] && verbose=true

  info "Running validator library self-test (v$PW_VALIDATOR_VERSION)..."
  echo ""

  local tests_passed=0
  local tests_failed=0

  # Test command_exists
  if command_exists "bash"; then
    ((tests_passed++)) || true
    success "command_exists('bash'): found"
  else
    ((tests_failed++)) || true
    error "command_exists('bash'): not found"
  fi

  # Test logging functions
  if info "Test info" >/dev/null 2>&1; then
    ((tests_passed++)) || true
    success "info(): works"
  else
    ((tests_failed++)) || true
    error "info(): failed"
  fi

  echo ""
  info "Self-test complete: Passed=$tests_passed, Failed=$tests_failed"

  if [[ $tests_failed -gt 0 ]]; then
    error "Self-test FAILED"
    return 1
  fi

  success "Self-test PASSED"
  return 0
}

# Run self-test if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --version)
      echo "pw-claude-skills Validator Library v$PW_VALIDATOR_VERSION"
      ;;
    *)
      run_self_test "$@"
      ;;
  esac
  exit $?
fi
