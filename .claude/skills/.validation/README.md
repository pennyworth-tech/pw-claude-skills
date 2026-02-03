# Skill Validation Infrastructure

**Version**: 1.0.0
**Based on**: AQE v3.4.2 Skill Validation System

This directory contains the validation infrastructure for pw-claude-skills - ensuring skill outputs are deterministic and trustworthy.

## Directory Structure

```
.validation/
├── schemas/                  # JSON Schema definitions
│   ├── skill-frontmatter.schema.json    # SKILL.md frontmatter validation
│   ├── skill-output.template.json       # Base output schema template
│   └── skill-eval.schema.json           # Evaluation suite schema
├── templates/                # Templates for skill authors
│   ├── validate.template.sh             # Bash validator template
│   ├── validator-lib.sh                 # Shared validation utilities
│   ├── eval.template.yaml               # Evaluation suite template
│   └── skill-frontmatter.example.yaml   # Frontmatter example
├── examples/                 # Example skill outputs
│   └── *.example.json
├── test-data/               # Test data for validation
│   ├── minimal-output.json
│   ├── sample-output.json
│   └── invalid-output.json
└── README.md                # This file
```

## 4-Layer Validation Architecture

| Layer | Purpose | Files |
|-------|---------|-------|
| **L0** | Intent (SKILL.md) | Declarative instructions |
| **L1** | Schema | `schemas/*.schema.json` |
| **L2** | Validator | `scripts/validate.sh` |
| **L3** | Eval Suite | `evals/*.yaml` |

## Trust Tiers

| Tier | Name | Requirements | CI Behavior |
|------|------|--------------|-------------|
| 0 | advisory | SKILL.md only | No validation |
| 1 | structured | SKILL.md + JSON Schema | Warnings only |
| 2 | validated | SKILL.md + Schema + Validator | Warnings only |
| 3 | verified | All above + Eval Suite | Block on failure |

## Usage

### Validate a Skill Output

```bash
# Using the template directly
.validation/templates/validate.template.sh output.json

# With options
.validation/templates/validate.template.sh --verbose output.json
.validation/templates/validate.template.sh --json output.json  # JSON output
.validation/templates/validate.template.sh --self-test         # Self-test mode
```

### Create a Skill Validator

1. Copy `templates/validate.template.sh` to your skill's `scripts/` directory
2. Customize the configuration section at the top
3. Add skill-specific validation in `validate_skill_specific()`
4. Update the output schema path

### Create an Eval Suite

1. Copy `templates/eval.template.yaml` to your skill's `evals/` directory
2. Add test cases with inputs and expected outputs
3. Define passing criteria (pass rate, required patterns)

## Validation Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Validation passed |
| 1 | Validation failed |
| 2 | Validation skipped (missing tools) |

## For Skill Authors

When creating a new skill:

1. **Start with SKILL.md** (Trust Tier 0)
2. **Add trust_tier to frontmatter** with validation config
3. **Add output schema** in `your-skill/schemas/output.schema.json` (Trust Tier 1)
4. **Add validator script** in `your-skill/scripts/validate.sh` (Trust Tier 2)
5. **Add eval suite** in `your-skill/evals/eval.yaml` (Trust Tier 3)

## Skill Categories

| Category | Description |
|----------|-------------|
| `ios-testing` | iOS native app testing skills |
| `web-testing` | Web application testing skills |
| `development-practices` | Development methodology skills |
| `automation` | Automation and tooling skills |
| `ui-ux` | UI/UX focused testing skills |

---

*Part of pw-claude-skills Validation System - Based on AQE v3.4.2*
