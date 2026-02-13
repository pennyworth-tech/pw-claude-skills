---
name: quality-data-collector
description: "Collect and analyze all 8 quality data points for backlit-core. Repeatable skill for Phase 1 baseline and ongoing manual runs until automated via CI."
category: quality-metrics
priority: high
tokenEstimate: 1500
agents: [qe-coverage-specialist, qe-security-scanner, qe-quality-gate, qe-visual-accessibility, qe-code-complexity]
implementation_status: initial
dependencies: []
tags: [quality, metrics, coverage, security, baseline, BL-461]
trust_tier: 3
validation:
  schema_path: schemas/output.json

---

# Quality Data Collector

Collect all 8 quality data points for `backlit-core` in a single structured run. Results are stored as JSON + markdown in `docs/quality-metrics/backlit-core/`.

## Arguments

- `<scope>` — Optional. Limit to specific service(s) (e.g., `ux-web`, `services-security`). Default: all services.
- `--output-dir` — Optional. Override output directory. Default: `docs/quality-metrics/backlit-core/`.

## Services in Scope

| Service | Language | Test Framework | Notes |
|---------|----------|----------------|-------|
| `ux-web` | TypeScript | vitest | Frontend web app |
| `services-security` | TypeScript | bun test | Auth, sessions, security |
| `ai-agent` | Python | pytest + pytest-cov | AI agent service |
| `services-graph` | Python | pytest | Graph/Neo4j service |
| `ai-realtime` | Python | — | Realtime AI service |
| `cli` | Python | — | CLI tool |
| `cust-gateway` | — | — | Customer gateway |
| `cust-graph` | — | — | Customer graph |
| `ux-ios` | Swift | XCTest | iOS app |

## Execution — 8 Data Points

Run all steps sequentially. For each step, capture structured output and handle failures gracefully (record `"status": "error"` with reason, do not abort the full run).

### Step 1: Unit Test Coverage

For each service with tests, run the test suite with coverage enabled:

```bash
# ux-web (vitest)
cd ux-web && npx vitest run --coverage --reporter=json 2>&1

# services-security (bun)
cd services-security && bun test --coverage 2>&1

# ai-agent (pytest)
cd ai-agent && python -m pytest tests/unit --cov --cov-report=json 2>&1
```

Capture per-service: lines %, branches %, functions %, statement count.

### Step 2: Integration Test Coverage

Run integration test suites where available:

```bash
# services-security
cd services-security && bun test tests/integration --coverage 2>&1

# ai-agent
cd ai-agent && python -m pytest tests/integration --cov --cov-report=json 2>&1
```

Capture: integration coverage %, test count, pass/fail count.

### Step 3: UI/UX Test Coverage (User Journeys)

Check for e2e/journey tests:

```bash
# ux-web (check for e2e tests)
find ux-web -name "*.e2e.*" -o -name "*.spec.*" -o -path "*/e2e/*" 2>/dev/null

# ux-ios (check for UI tests)
find ux-ios -name "*UITest*" -o -path "*/UITests/*" 2>/dev/null
```

Record: number of e2e test files, test count if runnable, identified user journeys.

### Step 4: CI Test Suite Runtime

Check recent GitHub Actions workflow runs for timing data:

```bash
gh run list --workflow=arborist-dag-run.yml --limit 5 --json databaseId,status,conclusion,updatedAt,createdAt 2>&1
```

For each run, compute wall-clock duration. Record: avg runtime, min, max, last 5 runs.

### Step 5: QE Test Coverage Score

Use the `qe-coverage-specialist` agent or MCP tool:

```typescript
Task("Analyze coverage gaps across backlit-core", `
  Perform coverage analysis on all services:
  - ux-web/src/
  - services-security/src/
  - ai-agent/
  - services-graph/
  Report: overall score, per-service scores, top uncovered areas.
`, "qe-coverage-specialist")
```

Or via MCP: `coverage_analyze_sublinear({ target: "src/" })`

### Step 6: QE Security Score

Use the `qe-security-scanner` agent or MCP tool:

```typescript
Task("Security audit of backlit-core", `
  Run SAST scan across all services.
  Report: overall score, vulnerability count by severity, top findings.
`, "qe-security-scanner")
```

Or via MCP: `security_scan_comprehensive({ target: ".", sast: true })`

### Step 7: QE Code Quality Score

Use the `qe-quality-gate` agent or MCP tool:

```typescript
Task("Quality assessment of backlit-core", `
  Evaluate code quality across all services.
  Report: overall score, complexity hotspots, code smells, tech debt estimate.
`, "qe-quality-gate")
```

Or via MCP: `quality_assess({ runGate: true })`

### Step 8: QE UX Score

Use the `qe-visual-accessibility` agent:

```typescript
Task("UX/accessibility assessment", `
  Evaluate ux-web for:
  - WCAG compliance level
  - Visual regression baseline
  - Responsive design coverage
  Report: overall UX score, accessibility issues by severity.
`, "qe-visual-accessibility")
```

## Output Format

All results are saved to `docs/quality-metrics/backlit-core/` with this structure:

```
docs/quality-metrics/backlit-core/
  YYYY-MM-DD/
    summary.md              # Human-readable summary
    raw-data.json           # Full structured data (schema below)
    unit-coverage/          # Per-service coverage reports
    security/               # Security scan results
```

### JSON Schema (raw-data.json)

```json
{
  "collectedAt": "ISO-8601 timestamp",
  "collectedBy": "manual | ci",
  "gitRef": "commit SHA",
  "gitBranch": "branch name",
  "dataPoints": {
    "unitCoverage": {
      "status": "success | error | skipped",
      "services": {
        "<service-name>": {
          "lines": 0.0,
          "branches": 0.0,
          "functions": 0.0,
          "statements": 0,
          "testCount": 0,
          "passCount": 0,
          "failCount": 0
        }
      }
    },
    "integrationCoverage": {
      "status": "success | error | skipped",
      "services": { }
    },
    "uiUxTests": {
      "status": "success | error | skipped",
      "e2eTestFiles": 0,
      "testCount": 0,
      "userJourneys": []
    },
    "ciRuntime": {
      "status": "success | error | skipped",
      "avgSeconds": 0,
      "minSeconds": 0,
      "maxSeconds": 0,
      "recentRuns": []
    },
    "qeCoverage": {
      "status": "success | error | skipped",
      "overallScore": 0.0,
      "perService": {},
      "topGaps": []
    },
    "qeSecurity": {
      "status": "success | error | skipped",
      "overallScore": 0.0,
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0,
      "topFindings": []
    },
    "qeCodeQuality": {
      "status": "success | error | skipped",
      "overallScore": 0.0,
      "complexityHotspots": [],
      "codeSmells": 0,
      "techDebtMinutes": 0
    },
    "qeUxScore": {
      "status": "success | error | skipped",
      "overallScore": 0.0,
      "wcagLevel": "",
      "issuesBySeverity": {}
    }
  }
}
```

## Summary Report Template (summary.md)

```markdown
# Quality Data Report — backlit-core

**Date:** YYYY-MM-DD
**Commit:** <short SHA>
**Branch:** <branch>
**Collected by:** manual

## Scorecard

| Data Point | Score/Value | Status | Delta |
|------------|-------------|--------|-------|
| Unit Coverage | XX% | pass/warn/fail | +/-X% |
| Integration Coverage | XX% | pass/warn/fail | +/-X% |
| UI/UX Tests | N journeys | pass/warn/fail | — |
| CI Runtime | Xs avg | pass/warn/fail | +/-Xs |
| QE Coverage | X/100 | pass/warn/fail | +/-X |
| QE Security | X/100 | pass/warn/fail | +/-X |
| QE Code Quality | X/100 | pass/warn/fail | +/-X |
| QE UX Score | X/100 | pass/warn/fail | +/-X |

## Details

### Unit Coverage
(per-service breakdown table)

### Integration Coverage
(per-service breakdown table)

...
```

## Delta Tracking

When a previous run exists in `docs/quality-metrics/backlit-core/`, load the most recent `raw-data.json` and compute deltas for each metric. Include deltas in the summary report.

## Rules

- NEVER fake data or assume values — always run real commands
- Record `"status": "error"` with the error message if a step fails; do NOT abort the entire run
- ALWAYS capture the git commit SHA and branch at the start of the run
- Store output in the date-stamped directory, never overwrite previous runs
- If a service has no tests, record `"status": "skipped"` with reason
