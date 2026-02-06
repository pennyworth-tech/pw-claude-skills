---
name: test-inventory
description: "Generate a comprehensive test inventory with static analysis, coverage gap detection, and diff comparison. Uses aqe code index + aqe coverage as foundation with Glob+Grep fallback."
license: MIT
version: 1.0.0
category: qe-automation
platforms:
  - web
  - mobile
  - api
frameworks:
  - agentic-qe
tags:
  - test-inventory
  - static-analysis
  - coverage
  - diff
  - hybrid
  - quality-gates
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: passing
---

# Test Inventory

Generate a comprehensive test inventory with static analysis, coverage gap detection, and diff comparison.

## Prerequisites

This skill works best with the **agentic-qe** fleet for knowledge graph and coverage analysis, but falls back to Glob+Grep if AQE is not available.

### Setup (recommended)

```bash
# 1. Add the agentic-qe MCP server to your project
claude mcp add agentic-qe -- npx -y agentic-qe@latest mcp start

# 2. Initialize agentic-qe in your project (creates .agentic-qe/ config)
npx agentic-qe@latest init --auto

# 3. Copy this skill into your project
cp -r test-inventory/ .claude/skills/test-inventory/
```

### Minimal Setup (no AQE)

The skill works without AQE -- it falls back to Glob + Grep for test file discovery. You just won't get knowledge graph stats or risk-weighted coverage gaps.

```bash
# Just copy the skill
cp -r test-inventory/ .claude/skills/test-inventory/
```

## Usage

```bash
# Generate inventory of current directory
claude -p "/test-inventory"

# Specific path
claude -p "/test-inventory path:src/services/"

# Diff against main branch
claude -p "/test-inventory diff --base main"

# Combined: path + diff
claude -p "/test-inventory path:src/ diff --base main"
```

## What It Does

1. **Discovers all test files** (*.test.ts, *.spec.ts, etc.) via AQE knowledge graph or Glob
2. **Extracts test metadata** (framework, test names, dependencies, env vars)
3. **Groups by service** using directory structure or KG-derived boundaries
4. **Detects coverage gaps** with risk-weighted scoring
5. **Computes diff** against a base branch or previous inventory baseline
6. **Runs quality gates**: service coverage, env var documentation, search latency
7. **Outputs structured JSON** saved to `docs/test-inventory/<project>/latest.json`

## Output

The skill produces a JSON file with:
- **summary**: total files, cases, services, estimated coverage, framework/type breakdown
- **services**: per-service test file inventory with dependencies and code mappings
- **kgStats**: knowledge graph metrics (nodes, edges, search latency)
- **coverageGaps**: risk-scored source files lacking test coverage
- **qualityGates**: AISP gates with gold/silver/bronze tier
- **changes**: (diff mode only) added/removed/modified test files

See `schemas/output.schema.json` for the full JSON Schema.

## Validation

```bash
# Validate an output file
./scripts/validate.sh docs/test-inventory/my-project/latest.json

# Verbose mode
./scripts/validate.sh docs/test-inventory/my-project/latest.json --verbose

# JSON output
./scripts/validate.sh docs/test-inventory/my-project/latest.json --json
```

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `frontend-test-spec-generator` | Generates test specs from feature specs (BL-240) |
| `qcsd-refinement-swarm` | Quality-focused test analysis |

---

*Created for Linear Issue BL-241: Test Inventory System with Static Analysis and Diff Comparison*
