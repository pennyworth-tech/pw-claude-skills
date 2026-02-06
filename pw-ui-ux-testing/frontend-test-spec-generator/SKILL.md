---
name: frontend-test-spec-generator
description: "Generate frontend test specifications from feature specs using SFDIPOT analysis, BDD scenarios, and AISP quality gates. Delegates to the qcsd-refinement-swarm from the agentic-qe fleet for multi-agent analysis."
license: MIT
version: 1.1.0
category: qe-automation
platforms:
  - web
  - mobile
frameworks:
  - agentic-qe
tags:
  - frontend
  - test-specs
  - bdd
  - sfdipot
  - aisp
  - quality-gates
  - swarm
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: passing
---

# Frontend Test Specification Generator

Generate comprehensive frontend test specifications from feature specs using AI-powered multi-agent analysis.

## Prerequisites

This skill requires the **agentic-qe** fleet, which provides the `qcsd-refinement-swarm` skill and all underlying QE agents.

### Setup

```bash
# 1. Add the agentic-qe MCP server to your project
claude mcp add agentic-qe -- npx -y agentic-qe@latest mcp start

# 2. Initialize agentic-qe in your project (creates .agentic-qe/ config)
npx agentic-qe@latest init --auto

# 3. Copy this skill into your project
cp -r frontend-test-spec-generator/ .claude/skills/frontend-test-spec-generator/
```

### Optional: Linear Integration

For `linear:` input format, add the Linear MCP server:

```bash
claude mcp add linear -- npx -y @anthropic/linear-mcp-server@latest
```

### Optional: CLI Usage

Run non-interactively from the command line:

```bash
# From a Linear issue
claude -p "/frontend-test-spec-generator linear:BL-245"

# From a file
claude -p "/frontend-test-spec-generator file:docs/features/checkout.md"

# Inline via pipe
cat docs/features/my-spec.md | claude -p "/frontend-test-spec-generator"
```

---

## When to Use This Skill

- Sprint refinement sessions to validate feature specs before committing to a sprint
- Generating structured test specifications from user stories or epics
- Identifying gaps, risks, and missing requirements in feature specs
- Producing BDD scenarios and SFDIPOT test ideas for QE teams

## What This Skill Does

1. **Parses feature specs** from text, files, Linear issues, or URLs
2. **Delegates to qcsd-refinement-swarm** (5-7 agents analyzing in parallel)
3. **Extracts test deliverables** - BDD scenarios, SFDIPOT test ideas, INVEST validation
4. **Applies quality gates** - basic thresholds + AISP rules (P0 distribution, human exploration, passive verbs)
5. **Produces structured JSON** with recommendation (READY / CONDITIONAL / NOT-READY)

---

## How to Use

### Basic Usage

```
/frontend-test-spec-generator <paste your feature spec here>
```

### From a File

```
/frontend-test-spec-generator file:docs/features/checkout-flow.md
```

### From a Linear Issue

```
/frontend-test-spec-generator linear:BL-245
```

### From a URL

```
/frontend-test-spec-generator url:https://your-wiki.com/feature-spec
```

### With Linear Update (posts results back to the issue)

```
/frontend-test-spec-generator linear:BL-245 --update-linear
```

---

## Execution Flow

```
/frontend-test-spec-generator
  |
  v
PHASE 1: Parse Input
  |- Detect type (text, file, linear, url)
  |- Extract story content
  |- Validate required elements
  |
  v
PHASE 2: Delegate to QCSD Refinement Swarm (from agentic-qe)
  |- Core agents: SFDIPOT assessor, BDD generator, Requirements validator
  |- Conditional agents: Contract validator, Dependency mapper (if flagged)
  |- Transformation: Test idea rewriter
  |
  v
PHASE 3: Extract Test Deliverables
  |- 02-sfdipot-analysis.md -> test ideas by factor
  |- 03-bdd-scenarios.md -> Gherkin scenarios
  |- 04-requirements-validation.md -> gaps, INVEST score
  |- 08-rewritten-test-ideas.md -> actionable specs
  |
  v
PHASE 4a: Quality Gates
  |- INVEST completeness >= 70%
  |- BDD scenario count >= 5
  |- Test idea quality >= 80%
  |
  v
PHASE 4b: AISP Quality Gates
  |- P0 distribution: 8-12% of total test ideas
  |- Human exploration: >= 10% marked automationFitness:human
  |- Passive verb scan: no "Verify"/"Check"/"Ensure" starts
  |- Tier: gold (3/3) / silver (2/3) / bronze (0-1/3)
  |
  v
PHASE 5: Format JSON Output + Summary
```

---

## AISP Quality Gates (Phase 4b)

Three rules from [bar181/aisp-open-core](https://github.com/bar181/aisp-open-core):

| Rule | Threshold | What it catches |
|------|-----------|-----------------|
| P0 Distribution | 8-12% of total test ideas | Too many or too few critical tests |
| Human Exploration | >= 10% marked for manual testing | Over-automation, missing exploratory coverage |
| Passive Verb Check | 0 violations | "Verify X" / "Check Y" patterns (untestable) |

**Tier classification:**
- **Gold**: All 3 rules pass
- **Silver**: 2/3 pass
- **Bronze**: 0-1 pass - overrides recommendation to CONDITIONAL

---

## Output Schema

The skill produces a structured JSON file (`test-spec-output.json`):

```json
{
  "storyId": "string",
  "storyName": "string",
  "recommendation": "READY | CONDITIONAL | NOT-READY",
  "testEnhancementNeeded": true,
  "qualityScore": {
    "invest": 78,
    "testability": 76,
    "bddCoverage": 100,
    "testIdeaQuality": 99.3,
    "overall": 88
  },
  "aispQualityGates": {
    "p0Distribution": { "actual": 0.10, "target": "0.08-0.12", "pass": true },
    "humanExploration": { "actual": 0.12, "target": ">=0.10", "pass": true },
    "passiveVerbCheck": { "violations": 0, "violatingIds": [], "pass": true },
    "tier": "gold",
    "rulesPassed": 3,
    "rulesTotal": 3
  },
  "specifications": {
    "bddScenarios": {
      "count": 18,
      "happyPath": 4,
      "errorPath": 4,
      "boundary": 4,
      "security": 5,
      "file": "03-bdd-scenarios.md"
    },
    "testIdeas": {
      "count": 43,
      "p0Critical": 18,
      "p1High": 19,
      "p2Medium": 6,
      "rewriteQuality": 99.3,
      "file": "08-rewritten-test-ideas.md"
    },
    "sfdipotFactors": {
      "coverage": "7/7",
      "p0Factors": ["function", "data", "time"],
      "p1Factors": ["structure", "interfaces", "operations"],
      "p2Factors": ["platform"],
      "totalTestIdeas": 85,
      "file": "02-sfdipot-analysis.md"
    }
  },
  "gaps": [],
  "actionItems": [],
  "flags": {
    "HAS_API": true,
    "HAS_REFACTORING": false,
    "HAS_DEPENDENCIES": true,
    "HAS_SECURITY": true
  },
  "outputFolder": "docs/qcsd-refinement/{story-id}/",
  "generatedAt": "ISO-8601 timestamp"
}
```

---

## Output Summary Format

After processing, the skill displays:

```
FRONTEND TEST SPECIFICATION GENERATED
--------------------------------------
Story: [Story Name]
ID:    [Story ID]

RECOMMENDATION: [READY / CONDITIONAL / NOT-READY]

QUALITY SCORES:
  INVEST Completeness:  ___%
  BDD Coverage:         ___%
  Test Idea Quality:    ___/100
  Overall:              ___/100

AISP QUALITY GATES:             [GOLD/SILVER/BRONZE]
  P0 Distribution:     ___% (target: 8-12%)     [PASS/FAIL]
  Human Exploration:   ___% (target: >= 10%)     [PASS/FAIL]
  Passive Verb Check:  ___ violations            [PASS/FAIL]

TEST SPECIFICATIONS:
  BDD Scenarios:        __ (__ happy, __ error, __ edge)
  SFDIPOT Test Ideas:   __ (__ P0, __ P1, __ P2)
  Rewritten Test Ideas: __ (___% quality)

GAPS IDENTIFIED: __
ACTION ITEMS:    __

OUTPUT: [output folder path]
JSON:   [output folder]/test-spec-output.json
```

---

## Example

**User**: `/frontend-test-spec-generator`

```
## User Story: Shopping Cart Persistence

As a returning customer,
I want my shopping cart to persist across sessions,
So that I can continue shopping where I left off.

### Acceptance Criteria
1. Cart persists for 30 days in localStorage
2. Logged-in users sync via /api/cart/sync
3. Cart merge when anonymous user logs in
```

**Output**: Structured JSON with 18 BDD scenarios, 85 SFDIPOT test ideas across 7 factors, 3 critical gaps identified, CONDITIONAL recommendation.

---

## Error Handling

| Error | Handling |
|-------|----------|
| Empty input | Prompt user for feature spec |
| Linear issue not found | Display error with issue ID |
| File not found | Display error with file path |
| agentic-qe not installed | Display setup instructions |
| Swarm timeout | Retry once, then report partial results |

---

## Dependencies

| Dependency | Required | Source |
|------------|----------|--------|
| `agentic-qe` (qcsd-refinement-swarm) | Yes | `npx agentic-qe@latest` |
| Linear MCP server | No (for `linear:` input) | `@anthropic/linear-mcp-server` |
| `testability-scoring` skill | No (additional quality gates) | pw-claude-skills repo |

---

## Tips

- Use `linear:` input for the best experience - it auto-extracts title, description, and acceptance criteria
- Run during sprint refinement sessions to validate stories before committing
- AISP bronze tier is a strong signal that the feature spec needs work before sprint entry
- The 8-12% P0 distribution rule prevents both "everything is critical" and "nothing is critical" anti-patterns

---

## Changelog

### v1.1.0 (2026-02-06)
- Add Phase 4b: AISP quality gates (P0 distribution, human exploration, passive verb scan)
- Add `aispQualityGates` to output JSON schema with tier classification (gold/silver/bronze)
- Bronze tier overrides recommendation to CONDITIONAL with action item
- Passive verb violations trigger re-run suggestion for test-idea-rewriting

### v1.0.0 (2026-02-04)
- Initial release
- Wrapper around qcsd-refinement-swarm from agentic-qe fleet
- JSON output format
- Support for text, file, linear, url inputs

**Credit:** Based on Pennyworth Tech's QCSD (Quality Criteria Shift-left Delivery) methodology
