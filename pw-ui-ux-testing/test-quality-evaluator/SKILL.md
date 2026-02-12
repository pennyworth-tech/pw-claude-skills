---
name: test-quality-evaluator
description: "Grade component/integration tests on realism using static mock/real pattern detection. A-F grades, thumbs up/down, brief comments."
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
  - bl-242
  - test-quality
  - evaluator
  - realism
  - grading
  - haiku
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: passing
---

# Test Quality Evaluator

Grade component and integration tests on realism using static mock/real pattern detection. A-F grades, thumbs up/down, brief comments.

---

## Overview

This skill is a **lightweight static analyzer** that:
1. Discovers test files via Glob (or `aqe quality --gate` if available)
2. Reads each file and counts mock vs. real signals using weighted pattern matching
3. Computes a 0-100 realism score per file, maps to A-F grade + thumbs up/down
4. Aggregates into a summary with grade distribution
5. Applies AISP quality gates (minimum quality, acceptable failures, evidence quality)
6. Outputs structured JSON with markdown summary

**No agents, no vectors, no memory needed.** Single-pass static analysis optimized for Haiku.

### Input Formats (CLI-first)

| Format | Example | How to Use |
|--------|---------|------------|
| **Default (current dir)** | Evaluate `.` | `/test-quality-evaluator` |
| **Specific path** | Evaluate `tests/integration/` | `/test-quality-evaluator path:tests/integration/` |
| **Verbose mode** | Show per-file signals | `/test-quality-evaluator path:tests/ --verbose` |

### CLI Usage

```bash
# Evaluate tests in current directory
claude -p "/test-quality-evaluator"

# Specific path
claude -p "/test-quality-evaluator path:tests/integration/"

# Verbose mode (per-file signal details)
claude -p "/test-quality-evaluator path:tests/ --verbose"
```

---

## Execution Flow

```
PHASE 1: Parse Input
  |-- Extract target path (default: . or tests/)
  |-- Parse --verbose flag
  |-- Identify test file globs (*.test.ts, *.spec.ts, *.integration.*, *.component.*)

PHASE 2: AQE Foundation (Bash)
  |-- aqe quality --gate (if available)
  |-- Fallback: Glob for test files matching patterns

PHASE 3: Static Analysis (per test file)
  |-- Read file content
  |-- Count MOCK signals (negative weights)
  |-- Count REAL signals (positive weights)
  |-- Compute raw score, normalize to 0-100
  |-- Map to grade (A/B/C/D/F) and thumbs (up/down)
  |-- Generate brief comment on detected patterns

PHASE 4: Aggregate Summary
  |-- averageScore = mean(all file scores)
  |-- averageGrade from averageScore
  |-- overallThumbsUp = averageGrade in [A,B,C]
  |-- dataQuality: HIGH (avg>=60), MEDIUM (avg>=30), LOW (<30)
  |-- gradeDistribution: { A: n, B: n, C: n, D: n, F: n }

PHASE 5: AISP Quality Gates
  |-- Gate 1: minimumQuality -- averageScore >= 70
  |-- Gate 2: acceptableFailures -- F-grade ratio <= 10%
  |-- Gate 3: evidenceQuality -- file:line refs >= 60% of findings
  |-- Tier: gold (3/3) / silver (2/3) / bronze (0-1/3)

PHASE 6: Output + Persist
  |-- Save to docs/test-quality/<project>/latest.json
  |-- Display markdown summary table
  |-- Recommendations for D/F graded files
```

---

## Implementation

### PHASE 1: Parse Input

```javascript
function parseInput(args) {
  const result = { targetPath: '.', verbose: false };
  const pathMatch = args.match(/path:(\S+)/);
  if (pathMatch) result.targetPath = pathMatch[1];
  if (args.includes('--verbose')) result.verbose = true;
  return result;
}
```

### PHASE 2: AQE Foundation

Run `aqe quality --gate` if available. This is the only verified quality command.

```bash
aqe quality --gate
```

**IMPORTANT**: If `aqe` is not available or fails, fall back to Glob:

```javascript
const testFiles = Glob('**/*.{test,spec}.{ts,tsx,js,jsx}', { path: targetPath });
const integrationFiles = Glob('**/*.integration.{test,spec}.{ts,tsx,js,jsx}', { path: targetPath });
const componentFiles = Glob('**/*.component.{test,spec}.{ts,tsx,js,jsx}', { path: targetPath });
```

### PHASE 3: Static Analysis

For each test file, count weighted mock and real signals:

```javascript
const MOCK_SIGNALS = {
  'jest.mock':         -20, 'vi.mock':           -20,
  'mockReturnValue':   -15, 'mockResolvedValue':  -15, 'mockRejectedValue': -15,
  'jest.fn()':         -10, 'vi.fn()':            -10,
  'nock(':             -25, 'msw':                -25, 'createMockServer':  -25,
  'sinon.stub':        -15, 'sinon.spy':          -15,
  'jest.spyOn':        -10, 'vi.spyOn':           -10,
};

const REAL_SIGNALS = {
  'Model.create':      +25, 'Model.find':         +25,
  'db.query':          +25, 'prisma.':            +25,
  'request(app)':      +20, 'request(server)':    +20, 'supertest':   +20,
  'deleteMany':        +15, 'truncate':           +15,
  'testcontainers':    +40, '.container':         +40,
  'fetch(':            +20, 'axios.':             +20,
  'docker':            +30, 'pg.Pool':            +25, 'mongoose.connect': +25,
};

// Normalize: baseline 50, clamped to [0, 100]
const score = Math.max(0, Math.min(100, 50 + rawScore));
const grade = score >= 80 ? 'A' : score >= 60 ? 'B' : score >= 40 ? 'C' : score >= 20 ? 'D' : 'F';
const thumbsUp = ['A', 'B', 'C'].includes(grade);
```

### PHASE 5: AISP Quality Gates

```javascript
function computeQualityGates(summary, evaluations) {
  const minimumQuality = { pass: summary.averageScore >= 70, actual: summary.averageScore, threshold: 70 };
  const fRatio = summary.gradeDistribution.F / summary.totalEvaluated;
  const acceptableFailures = { pass: fRatio <= 0.10, actual: Math.round(fRatio * 100) / 100, threshold: 0.10 };
  const filesWithSignals = evaluations.filter(e => e.signals.mockCount > 0 || e.signals.realCount > 0).length;
  const evidenceRatio = filesWithSignals / summary.totalEvaluated;
  const evidenceQuality = { pass: evidenceRatio >= 0.60, actual: Math.round(evidenceRatio * 100) / 100, threshold: 0.60 };
  const rulesPassed = [minimumQuality, acceptableFailures, evidenceQuality].filter(g => g.pass).length;
  const tier = rulesPassed === 3 ? 'gold' : rulesPassed >= 2 ? 'silver' : 'bronze';
  return { minimumQuality, acceptableFailures, evidenceQuality, tier, rulesPassed, rulesTotal: 3 };
}
```

---

## Output Schema

```typescript
interface TestQualityOutput {
  skillName: "test-quality-evaluator";
  version: "1.0.0";
  timestamp: string;
  status: "success" | "partial" | "failed";
  trustTier: 3;
  output: {
    targetPath: string;
    analysisType: "static";
    summary: {
      totalTestFiles: number;
      totalEvaluated: number;
      averageScore: number;
      averageGrade: "A"|"B"|"C"|"D"|"F";
      overallThumbsUp: boolean;
      dataQuality: "HIGH"|"MEDIUM"|"LOW";
      gradeDistribution: { A: number; B: number; C: number; D: number; F: number };
      note: string;
    };
    evaluations: Array<{
      testFile: string;
      grade: "A"|"B"|"C"|"D"|"F";
      score: number;
      thumbsUp: boolean;
      comment: string;
      signals: { mockCount: number; realCount: number; topMockPatterns: string[]; topRealPatterns: string[] };
    }>;
    qualityGates: {
      minimumQuality: { pass: boolean; actual: number; threshold: 70 };
      acceptableFailures: { pass: boolean; actual: number; threshold: 0.10 };
      evidenceQuality: { pass: boolean; actual: number; threshold: 0.60 };
      tier: "gold"|"silver"|"bronze";
      rulesPassed: number;
      rulesTotal: 3;
    };
    recommendations: string[];
  };
}
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| `aqe` not installed | Fall back to Glob discovery (warn user) |
| No test files found | Report empty evaluation with warning |
| File read fails | Skip file, include in partial results |
| Zero evaluations | Status = "failed", no gates computed |

---

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `test-inventory` | Discovers all tests (BL-241) -- this skill grades them |
| `frontend-test-spec-generator` | Generates test specs (BL-240) |
| `risk-based-testing` | Risk prioritization for D/F files |

---

## Changelog

### v1.0.0 (2026-02-06)
- Initial release for BL-242
- Lightweight static analysis: mock/real pattern detection with weighted scoring
- 6-phase execution: parse, AQE foundation, static analysis, aggregate, quality gates, output
- A-F grading with thumbs up/down and brief comments
- AISP quality gates: minimum quality, acceptable failures, evidence quality
- Haiku-optimized (no agents, no vectors, no memory)
- Structured JSON output with two-level envelope
- CLI-first: `claude -p "/test-quality-evaluator"`

---

*Created for Linear Issue BL-242: Component/Integration Test Quality Evaluator*
