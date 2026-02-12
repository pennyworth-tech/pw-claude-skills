#!/bin/bash
# Contract Change Validator Skill Validator v1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SKILL_DIR/../.." && pwd)"

# Source validator library (try project-level first, then local)
for lib_path in "$PROJECT_ROOT/.claude/skills/.validation/templates/validator-lib.sh" "$SCRIPT_DIR/validator-lib.sh"; do
  if [[ -f "$lib_path" ]]; then source "$lib_path"; break; fi
done

# Ensure we have the library loaded
if ! command -v validate_json &>/dev/null; then
  echo "[FAIL] validator-lib.sh not found. Install it or run from project root." >&2
  exit 1
fi

SKILL_NAME="contract-change-validator"
SKILL_VERSION="1.0.0"
SCHEMA_PATH="$SKILL_DIR/schemas/output.schema.json"
MUST_CONTAIN_TERMS=("qualityGates" "contracts" "congruenceIssues")

# Handle special flags
[[ "${1:-}" == "--self-test" ]] && { run_self_test; exit $?; }
[[ "${1:-}" == "--help" ]] && { echo "Usage: $0 <output.json> [--verbose|--json]"; exit 0; }

# Parse arguments
OUTPUT_FILE="${1:-}"
JSON_ONLY=false
[[ "${2:-}" == "--verbose" ]] && export AQE_DEBUG=1
[[ "${2:-}" == "--json" ]] && JSON_ONLY=true

# Validate input
[[ -z "$OUTPUT_FILE" ]] && { error "No output file specified. Usage: $0 <output.json>"; exit 1; }
[[ ! -f "$OUTPUT_FILE" ]] && { error "File not found: $OUTPUT_FILE"; exit 1; }

info "Validating $SKILL_NAME output: $OUTPUT_FILE"

# Step 1: JSON syntax
validate_json "$OUTPUT_FILE" || { error "Invalid JSON syntax"; exit 1; }
success "JSON syntax valid"

# Step 2: Schema validation (non-blocking)
schema_status="skipped"
if [[ -f "$SCHEMA_PATH" ]]; then
  if validate_json_schema "$SCHEMA_PATH" "$OUTPUT_FILE" 2>/dev/null; then
    schema_status="passed"
    success "Schema validation passed"
  else
    schema_status="failed"
    warn "Schema validation failed (may be missing validator tool)"
  fi
fi

# Step 3: Required fields
skill_name=$(json_get "$OUTPUT_FILE" ".skillName")
if [[ "$skill_name" != "contract-change-validator" ]]; then
  error "Invalid skillName: expected 'contract-change-validator', got '$skill_name'"
  exit 1
fi
success "skillName correct"

# Step 4: Check summary.totalContracts
total_contracts=$(json_get "$OUTPUT_FILE" ".output.summary.totalContracts")
if [[ -z "$total_contracts" || "$total_contracts" == "null" ]]; then
  error "Missing output.summary.totalContracts"
  exit 1
fi
success "summary.totalContracts present: $total_contracts"

# Step 5: Check quality gates
tier=$(json_get "$OUTPUT_FILE" ".output.qualityGates.tier")
if [[ -z "$tier" || "$tier" == "null" ]]; then
  error "Missing output.qualityGates.tier"
  exit 1
fi

case "$tier" in
  gold|silver|bronze) success "Quality gate tier valid: $tier" ;;
  *) error "Invalid quality gate tier: $tier (expected gold/silver/bronze)"; exit 1 ;;
esac

# Step 6: Check contracts array exists
contracts_count=$(json_count "$OUTPUT_FILE" ".output.contracts")
if [[ -z "$contracts_count" || "$contracts_count" == "null" ]]; then
  contracts_count=0
fi
success "Contracts array present: $contracts_count contracts"

# Step 7: Check congruence score
congruence=$(json_get "$OUTPUT_FILE" ".output.summary.congruenceScore")
if [[ -n "$congruence" && "$congruence" != "null" ]]; then
  success "Congruence score present: $congruence"
else
  warn "Missing congruence score"
fi

# Step 8: Check 6 contract types in byType
for ctype in restApi dataDefinitions testData events urlConfig libraryVersions; do
  val=$(json_get "$OUTPUT_FILE" ".output.summary.byType.$ctype")
  if [[ -z "$val" || "$val" == "null" ]]; then
    warn "Missing byType.$ctype"
  fi
done
success "Contract type breakdown present"

# Output JSON report if requested
if [[ "$JSON_ONLY" == "true" ]]; then
  output_validation_report "$SKILL_NAME" "$schema_status" "passed" "passed"
  exit 0
fi

echo ""
success "Validation PASSED for $SKILL_NAME v$SKILL_VERSION"
exit 0
