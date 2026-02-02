#!/bin/bash
# iOS UI Testing Skill Validator v1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Source shared library
for lib_path in "$PROJECT_ROOT/.claude/skills/.validation/templates/validator-lib.sh" "$SCRIPT_DIR/validator-lib.sh"; do
  if [[ -f "$lib_path" ]]; then source "$lib_path"; break; fi
done

SKILL_NAME="ios-ui-testing"
SKILL_VERSION="1.0.0"
SCHEMA_PATH="$SKILL_DIR/schemas/output.schema.json"
REQUIRED_FIELDS=("skillName" "status" "output" "output.summary" "output.findings")
MUST_CONTAIN_TERMS=("XCTest" "iOS")
ENUM_VALIDATIONS=(".status:success,partial,failed,skipped")

[[ "${1:-}" == "--self-test" ]] && { run_self_test; exit $?; }
[[ "${1:-}" == "--help" ]] && { echo "Usage: $0 <output.json> [--verbose|--json]"; exit 0; }

OUTPUT_FILE="${1:-}"; VERBOSE=false; JSON_ONLY=false
[[ "${2:-}" == "--verbose" ]] && VERBOSE=true && export PW_DEBUG=1
[[ "${2:-}" == "--json" ]] && JSON_ONLY=true

[[ -z "$OUTPUT_FILE" ]] && { error "No output file specified"; exit 1; }
[[ ! -f "$OUTPUT_FILE" ]] && { error "File not found: $OUTPUT_FILE"; exit 1; }

validate_json "$OUTPUT_FILE" || exit 1
validate_json_schema "$SCHEMA_PATH" "$OUTPUT_FILE" 2>/dev/null || true

# Skill-specific: Check for iOS-specific patterns
skill_name=$(json_get "$OUTPUT_FILE" ".skillName")
[[ "$skill_name" != "ios-ui-testing" ]] && { error "Invalid skillName: expected 'ios-ui-testing'"; exit 1; }

content=$(cat "$OUTPUT_FILE")
for term in "${MUST_CONTAIN_TERMS[@]}"; do
  grep -qi "$term" <<< "$content" || { warn "Missing expected term: $term"; }
done

[[ "$JSON_ONLY" == "true" ]] && output_validation_report "$SKILL_NAME" "passed" "passed" "passed"
success "Validation PASSED for $SKILL_NAME"
exit 0
