#!/bin/bash
# =============================================================================
# pw-claude-skills Validator Template v1.0.0
# Copy this template to: your-skill/scripts/validate.sh
# =============================================================================
#
# Usage: ./validate.sh <output-file> [options]
#
# Options:
#   --self-test    Run validator self-test mode
#   --verbose      Enable verbose output
#   --json         Output results as JSON only
#   --help         Show this help message
#
# Exit Codes:
#   0 - Validation passed
#   1 - Validation failed
#   2 - Validation skipped (missing tools)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine paths
if [[ "$SCRIPT_DIR" == *"/templates"* ]]; then
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
  SKILL_DIR="$SCRIPT_DIR"
else
  SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  PROJECT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"
fi

# Source shared library
VALIDATOR_LIB=""
for lib_path in \
  "$SCRIPT_DIR/validator-lib.sh" \
  "$PROJECT_ROOT/.claude/skills/.validation/templates/validator-lib.sh" \
  "$SKILL_DIR/scripts/validator-lib.sh"; do
  if [[ -f "$lib_path" ]]; then
    VALIDATOR_LIB="$lib_path"
    break
  fi
done

if [[ -n "$VALIDATOR_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$VALIDATOR_LIB"
else
  echo "ERROR: Validator library not found"
  exit 1
fi

# =============================================================================
# SKILL-SPECIFIC CONFIGURATION - MODIFY THIS SECTION
# =============================================================================

# Skill name (should match SKILL.md name)
SKILL_NAME="REPLACE_WITH_SKILL_NAME"

# Skill version
SKILL_VERSION="1.0.0"

# Required tools
REQUIRED_TOOLS=()

# Optional tools
OPTIONAL_TOOLS=("jq" "ajv" "jsonschema" "python3")

# Path to output JSON schema
SCHEMA_PATH="$SKILL_DIR/schemas/output.json"

# Path to sample test data for self-test mode
SAMPLE_OUTPUT_PATH="$PROJECT_ROOT/.claude/skills/.validation/test-data/sample-output.json"

# =============================================================================
# CONTENT VALIDATION CONFIGURATION
# =============================================================================

# Required fields in output
REQUIRED_FIELDS=("skillName" "status" "output")

# Fields that must have non-empty values
REQUIRED_NON_EMPTY_FIELDS=()

# Terms that MUST appear in output (case-insensitive)
MUST_CONTAIN_TERMS=()

# Terms that must NOT appear in output
MUST_NOT_CONTAIN_TERMS=()

# Enum validations: "field_path:value1,value2,value3"
ENUM_VALIDATIONS=(
  ".status:success,partial,failed,skipped"
)

# =============================================================================
# Argument Parsing
# =============================================================================

OUTPUT_FILE=""
SELF_TEST=false
VERBOSE=false
JSON_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test)
      SELF_TEST=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      export PW_DEBUG=1
      shift
      ;;
    --json)
      JSON_ONLY=true
      shift
      ;;
    -h|--help)
      cat << 'HELP_EOF'
pw-claude-skills Validator

Usage: ./validate.sh <output-file> [options]
       ./validate.sh --self-test [--verbose]

Arguments:
  <output-file>     Path to skill output JSON file to validate

Options:
  --self-test       Run validator self-test mode
  --verbose, -v     Enable verbose/debug output
  --json            Output results as JSON only
  --help, -h        Show this help message

Exit Codes:
  0 - Validation passed
  1 - Validation failed
  2 - Validation skipped (missing required tools)

HELP_EOF
      exit 0
      ;;
    -*)
      error "Unknown option: $1"
      exit 1
      ;;
    *)
      OUTPUT_FILE="$1"
      shift
      ;;
  esac
done

# =============================================================================
# Self-Test Mode
# =============================================================================

if [[ "$SELF_TEST" == "true" ]]; then
  echo "=============================================="
  info "Running $SKILL_NAME Validator Self-Test"
  echo "=============================================="
  echo ""

  self_test_passed=true

  # Check tools
  echo "--- Step 1: Tool Check ---"
  if [[ ${#REQUIRED_TOOLS[@]} -eq 0 ]]; then
    success "No required tools specified"
  else
    for tool in "${REQUIRED_TOOLS[@]}"; do
      if command_exists "$tool"; then
        success "Required tool available: $tool"
      else
        error "Required tool MISSING: $tool"
        self_test_passed=false
      fi
    done
  fi
  echo ""

  # Check schema file
  echo "--- Step 2: Schema File ---"
  if [[ -n "$SCHEMA_PATH" ]] && [[ -f "$SCHEMA_PATH" ]]; then
    success "Schema file exists: $SCHEMA_PATH"
    if validate_json "$SCHEMA_PATH" 2>/dev/null; then
      success "Schema file is valid JSON"
    else
      error "Schema file is NOT valid JSON"
      self_test_passed=false
    fi
  elif [[ -n "$SCHEMA_PATH" ]]; then
    warn "Schema file not found: $SCHEMA_PATH"
  else
    info "No schema path configured (trust_tier 0)"
  fi
  echo ""

  # Run library self-test
  echo "--- Step 3: Library Self-Test ---"
  if run_self_test 2>/dev/null; then
    success "Library self-test passed"
  else
    error "Library self-test FAILED"
    self_test_passed=false
  fi
  echo ""

  # Summary
  echo "=============================================="
  if [[ "$self_test_passed" == "true" ]]; then
    success "Self-test PASSED"
    exit 0
  else
    error "Self-test FAILED"
    exit 1
  fi
fi

# =============================================================================
# Validation Functions
# =============================================================================

validate_tools() {
  if [[ ${#REQUIRED_TOOLS[@]} -eq 0 ]]; then
    debug "No required tools specified"
    return 0
  fi

  local missing=()
  for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command_exists "$tool"; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required tools: ${missing[*]}"
    return 1
  fi

  debug "All required tools available"
  return 0
}

validate_schema() {
  local output_file="$1"

  if [[ -z "$SCHEMA_PATH" ]]; then
    debug "No schema path configured, skipping schema validation"
    return 2
  fi

  if [[ ! -f "$SCHEMA_PATH" ]]; then
    warn "Schema file not found: $SCHEMA_PATH"
    return 2
  fi

  debug "Validating against schema: $SCHEMA_PATH"

  local result
  result=$(validate_json_schema "$SCHEMA_PATH" "$output_file" 2>&1)
  local status=$?

  case $status in
    0)
      success "Schema validation passed"
      return 0
      ;;
    1)
      error "Schema validation failed"
      if [[ "$VERBOSE" == "true" ]]; then
        echo "$result"
      fi
      return 1
      ;;
    2)
      warn "Schema validation skipped (no validator available)"
      return 2
      ;;
  esac
}

validate_required_fields() {
  local output_file="$1"
  local missing=()

  for field in "${REQUIRED_FIELDS[@]}"; do
    local value
    value=$(json_get "$output_file" ".$field" 2>/dev/null)
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
      missing+=("$field")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing required fields: ${missing[*]}"
    return 1
  fi

  success "All required fields present"
  return 0
}

validate_skill_specific() {
  local output_file="$1"

  debug "Running skill-specific validations..."

  # ADD YOUR SKILL-SPECIFIC VALIDATIONS HERE

  return 0
}

# =============================================================================
# Main Validation Flow
# =============================================================================

main() {
  if [[ -z "$OUTPUT_FILE" ]]; then
    error "No output file specified"
    echo "Usage: $0 <output-file> [options]"
    exit 1
  fi

  if [[ ! -f "$OUTPUT_FILE" ]]; then
    error "Output file not found: $OUTPUT_FILE"
    exit 1
  fi

  if [[ "$JSON_ONLY" != "true" ]]; then
    echo "=============================================="
    info "Validating $SKILL_NAME Output"
    echo "=============================================="
    echo ""
  fi

  local tool_status="passed"
  local json_status="passed"
  local schema_status="passed"
  local fields_status="passed"
  local specific_status="passed"

  # Step 1: Check tools
  if ! validate_tools; then
    tool_status="failed"
    exit $EXIT_SKIP
  fi

  # Step 2: Validate JSON syntax
  if ! validate_json "$OUTPUT_FILE"; then
    json_status="failed"
    exit $EXIT_FAIL
  fi

  # Step 3: Validate schema
  local schema_exit_code
  validate_schema "$OUTPUT_FILE" && schema_exit_code=0 || schema_exit_code=$?
  case $schema_exit_code in
    1) schema_status="failed" ;;
    2) schema_status="skipped" ;;
  esac

  # Step 4: Validate required fields
  if ! validate_required_fields "$OUTPUT_FILE"; then
    fields_status="failed"
  fi

  # Step 5: Skill-specific validation
  if ! validate_skill_specific "$OUTPUT_FILE"; then
    specific_status="failed"
  fi

  # Determine overall status
  local overall_status="passed"
  if [[ "$json_status" == "failed" ]] || \
     [[ "$schema_status" == "failed" ]] || \
     [[ "$fields_status" == "failed" ]] || \
     [[ "$specific_status" == "failed" ]]; then
    overall_status="failed"
  elif [[ "$schema_status" == "skipped" ]]; then
    overall_status="partial"
  fi

  # Output results
  if [[ "$JSON_ONLY" == "true" ]]; then
    output_validation_report "$SKILL_NAME" "$schema_status" "$fields_status" "$tool_status"
  else
    echo ""
    echo "=============================================="
    echo "Validation Summary for $SKILL_NAME"
    echo "=============================================="
    echo "  JSON Syntax:  $json_status"
    echo "  Schema:       $schema_status"
    echo "  Fields:       $fields_status"
    echo "  Skill-specific: $specific_status"
    echo "  --------------"
    echo "  Overall:      $overall_status"
    echo "=============================================="
  fi

  case "$overall_status" in
    "passed")
      [[ "$JSON_ONLY" != "true" ]] && success "Validation PASSED"
      exit $EXIT_PASS
      ;;
    "partial")
      [[ "$JSON_ONLY" != "true" ]] && warn "Validation PARTIAL"
      exit $EXIT_PASS
      ;;
    "failed")
      [[ "$JSON_ONLY" != "true" ]] && error "Validation FAILED"
      exit $EXIT_FAIL
      ;;
  esac
}

main
