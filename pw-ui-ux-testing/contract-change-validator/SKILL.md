---
name: contract-change-validator
description: "Extract, validate, and diff contracts across a multi-repo codebase. Discovers REST APIs, TypeScript interfaces, test data, events, URLs, and library versions. JSON output with congruence scoring."
license: MIT
version: 1.0.0
category: qe-automation
platforms:
  - web
  - api
frameworks:
  - agentic-qe
tags:
  - bl-245
  - contracts
  - validation
  - diff
  - extraction
  - breaking-changes
  - congruence
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: pending
---

# Contract Change Validator

Extract, validate, and diff contracts across a multi-repo codebase. Discovers 6 contract types, detects breaking changes, and scores cross-type congruence.

---

## Overview

This skill is a **hybrid analyzer** (BL-241 pattern) that:
1. Discovers contracts across 6 types via Glob patterns (or `aqe qe contracts validate` if available)
2. Extracts structured contract inventories from source code
3. Diffs contracts between branches to find breaking changes
4. Checks cross-type congruence (are API changes reflected in TypeScript types? test data? events?)
5. Applies AISP quality gates (contracts covered, breaking changes documented, congruence score)
6. Outputs structured JSON with markdown summary

### Contract Types

| # | Type | Discovery Patterns | Extraction |
|---|------|-------------------|------------|
| 1 | **REST API** | `**/openapi.{yaml,json}`, `**/swagger.*`, route decorators | Endpoints, params, response schemas |
| 2 | **Data Definitions** | `**/types/**/*.ts`, `**/interfaces/**/*.ts`, `**/*.d.ts` | Exported interfaces/types with fields |
| 3 | **Test Data** | `**/fixtures/**`, `**/mocks/**`, `**/__fixtures__/**` | JSON/TS object shapes |
| 4 | **Messages/Events** | `**/events/**`, `**/messages/**`, `**/queues/**` | Event schemas, message types |
| 5 | **URLs/Communication** | `**/config/**`, `.env*`, `**/constants.*` | Service URLs, ports, protocols |
| 6 | **Library Versions** | `package.json`, `package-lock.json` | Dependency name + semver range |

### Input Formats (CLI-first)

| Format | Example | How to Use |
|--------|---------|------------|
| **Default (current dir)** | Extract contracts from `.` | `/contract-change-validator` |
| **Specific path** | Extract from `src/` | `/contract-change-validator path:src/` |
| **Diff mode** | Diff against main | `/contract-change-validator diff --base main` |
| **Combined** | Path + diff | `/contract-change-validator path:src/ diff --base main` |
| **Breaking check** | Check for breaking changes | `/contract-change-validator diff --base main --check-breaking` |
| **Multi-repo** | Point at contracts repo | `/contract-change-validator path:../contracts/` |

### CLI Usage

```bash
# Extract all contracts from current directory
claude -p "/contract-change-validator"

# Specific path
claude -p "/contract-change-validator path:src/"

# Diff contracts against main branch
claude -p "/contract-change-validator diff --base main"

# Combined: path + diff + breaking change check
claude -p "/contract-change-validator path:src/ diff --base main --check-breaking"

# Multi-repo: point at a contracts directory
claude -p "/contract-change-validator path:../contracts/"
```

---

## Execution Flow

```
PHASE 1: Parse Input
  |-- Detect mode: extract / diff / both
  |-- Resolve target path (default: .)
  |-- Parse --base branch (default: main)
  |-- Parse --check-breaking flag

PHASE 2: AQE Foundation (Bash)
  |-- aqe qe contracts validate (if available)
  |-- aqe code index <path> (for KG-based discovery)
  |-- Fallback: Glob patterns for each of 6 contract types

PHASE 3: Contract Discovery & Extraction
  |-- For each contract type, discover files via Glob
  |-- Read files and extract structured contract data
  |-- Build contract inventory with type, location, contents

PHASE 4: Diff Analysis (if diff mode)
  |-- git diff --name-only <base>...HEAD filtered by contract patterns
  |-- For changed contract files: extract before/after versions
  |-- Classify changes: added, removed, modified, breaking
  |-- Spawn agents (parallel, run_in_background: true):
  |     |-- qe-contract-validator: validate contract structure
  |     |-- qe-api-compatibility (conditional): breaking change detection

PHASE 5: Congruence Check
  |-- Cross-reference: API endpoints <-> TypeScript types
  |-- Cross-reference: TypeScript types <-> Test data shapes
  |-- Cross-reference: API endpoints <-> Event schemas
  |-- Cross-reference: Config URLs <-> API base paths
  |-- Identify: missed updates, unadhered contracts
  |-- Compute congruence score (0-100)

PHASE 6: AISP Quality Gates
  |-- Gate 1: contractsCovered -- all 6 types discovered (or justified absent)
  |-- Gate 2: breakingChangesDocumented -- all breaking changes have migration notes
  |-- Gate 3: congruenceScore -- cross-type congruence >= 80%
  |-- Tier: gold (3/3) / silver (2/3) / bronze (0-1/3)

PHASE 7: Output + Persist
  |-- Save to docs/contract-changes/<project>/latest.json
  |-- Display markdown summary table
  |-- Recommendations for congruence issues
```

---

## Implementation

### PHASE 1: Parse Input

```javascript
function parseInput(args) {
  const result = { mode: 'extract', targetPath: '.', baseBranch: null, checkBreaking: false };
  const pathMatch = args.match(/path:(\S+)/);
  if (pathMatch) result.targetPath = pathMatch[1];
  if (args.includes('diff')) {
    result.mode = pathMatch ? 'both' : 'diff';
    const baseMatch = args.match(/--base\s+(\S+)/);
    result.baseBranch = baseMatch ? baseMatch[1] : 'main';
  }
  if (args.includes('--check-breaking')) result.checkBreaking = true;
  return result;
}
```

### PHASE 2: AQE Foundation

Run verified AQE CLI commands if available:

```bash
# Contract validation (from v3/src/domains/contract-testing/)
aqe qe contracts validate <contractPath> --check-breaking

# Knowledge graph for discovery (from v3/src/cli/commands/code.ts)
aqe code index <targetPath>
```

**Fallback**: If `aqe` is not available, use Glob for discovery:

```javascript
// REST API contracts
const apiContracts = Glob('{**/openapi.yaml,**/openapi.json,**/swagger.yaml,**/swagger.json}', { path: targetPath });

// Data definitions
const typeContracts = Glob('{**/types/**/*.ts,**/interfaces/**/*.ts,**/*.d.ts}', { path: targetPath });

// Test data / fixtures
const testDataContracts = Glob('{**/fixtures/**/*.json,**/fixtures/**/*.ts,**/__fixtures__/**/*,**/mocks/**/*.json}', { path: targetPath });

// Events / messages
const eventContracts = Glob('{**/events/**/*.ts,**/messages/**/*.ts,**/queues/**/*.ts}', { path: targetPath });

// URLs / config
const configContracts = Glob('{**/config/**/*.ts,**/config/**/*.json,.env,.env.*,**/constants.ts}', { path: targetPath });

// Library versions
const packageFiles = Glob('{package.json,**/package.json}', { path: targetPath });
```

### PHASE 3: Contract Discovery & Extraction

For each discovered file, extract structured contract data:

```javascript
// REST API: parse OpenAPI spec
function extractRestApi(filePath, content) {
  // Parse YAML/JSON -> extract paths, methods, parameters, response schemas
  return {
    type: 'rest-api',
    source: filePath,
    endpoints: [{ method, path, parameters, requestBody, responses }],
    version: spec.info?.version
  };
}

// Data Definitions: parse TypeScript exports
function extractDataDefinitions(filePath, content) {
  // Grep for exported interfaces/types
  // Extract field names and types
  return {
    type: 'data-definition',
    source: filePath,
    definitions: [{ name, fields: [{ name, type, optional }] }]
  };
}

// Test Data: extract object shapes from fixtures
function extractTestData(filePath, content) {
  return {
    type: 'test-data',
    source: filePath,
    shapes: [{ name, fields, sampleValues }]
  };
}

// Events: extract event schemas
function extractEvents(filePath, content) {
  return {
    type: 'event',
    source: filePath,
    events: [{ name, payload, channel }]
  };
}

// URLs: extract service communication
function extractUrls(filePath, content) {
  // Regex: URLs, service names, ports
  return {
    type: 'url-config',
    source: filePath,
    urls: [{ name, url, protocol }]
  };
}

// Libraries: extract dependencies
function extractLibraries(filePath, content) {
  const pkg = JSON.parse(content);
  return {
    type: 'library-version',
    source: filePath,
    dependencies: Object.entries(pkg.dependencies || {}).map(([name, version]) => ({ name, version })),
    devDependencies: Object.entries(pkg.devDependencies || {}).map(([name, version]) => ({ name, version }))
  };
}
```

### PHASE 4: Diff Analysis

```javascript
// Get changed files between branches
Bash(`git diff --name-only ${baseBranch}...HEAD`);

// Filter to contract-relevant files
const contractPatterns = [
  'openapi', 'swagger', 'types/', 'interfaces/', '.d.ts',
  'fixtures/', 'mocks/', '__fixtures__/',
  'events/', 'messages/', 'queues/',
  'config/', '.env', 'constants',
  'package.json'
];

// For each changed contract file, extract before/after
// git show <base>:<file> for baseline version
// Compare extracted contracts to find:
//   - Added endpoints/types/events
//   - Removed endpoints/types/events
//   - Modified (field type changes, new required fields, etc.)
//   - Breaking changes (removals, type changes, new required fields)
```

### PHASE 5: Congruence Check

The key differentiator -- cross-type validation:

```javascript
function checkCongruence(contracts) {
  const issues = [];

  // 1. API endpoints should have matching TypeScript types
  for (const endpoint of contracts.restApi.endpoints) {
    const matchingType = contracts.dataDefinitions.find(d =>
      d.name.toLowerCase().includes(endpoint.responseName?.toLowerCase())
    );
    if (!matchingType) {
      issues.push({
        type: 'missing-type-for-endpoint',
        severity: 'HIGH',
        endpoint: `${endpoint.method} ${endpoint.path}`,
        message: `No TypeScript type found for API response`
      });
    }
  }

  // 2. TypeScript types should have matching test fixtures
  for (const def of contracts.dataDefinitions.definitions) {
    const matchingFixture = contracts.testData.find(td =>
      td.name.toLowerCase().includes(def.name.toLowerCase())
    );
    if (!matchingFixture) {
      issues.push({
        type: 'missing-fixture-for-type',
        severity: 'MEDIUM',
        typeName: def.name,
        message: `No test fixture found for type`
      });
    }
  }

  // 3. Events should have matching TypeScript types
  for (const event of contracts.events.events) {
    const matchingType = contracts.dataDefinitions.find(d =>
      d.name.toLowerCase().includes(event.name?.toLowerCase())
    );
    if (!matchingType) {
      issues.push({
        type: 'missing-type-for-event',
        severity: 'HIGH',
        eventName: event.name,
        message: `No TypeScript type found for event payload`
      });
    }
  }

  // 4. Config URLs should match API base paths
  // 5. Library versions should be consistent across packages

  const congruenceScore = Math.max(0, 100 - (issues.length * 5));
  return { issues, congruenceScore };
}
```

### PHASE 6: AISP Quality Gates

```javascript
function computeQualityGates(inventory, changes, congruence) {
  // Gate 1: All contract types discovered (or explicitly marked absent)
  const typesFound = new Set(inventory.contracts.map(c => c.type));
  const allTypes = ['rest-api', 'data-definition', 'test-data', 'event', 'url-config', 'library-version'];
  const contractsCovered = {
    pass: typesFound.size >= 4, // At least 4 of 6 types present
    actual: typesFound.size,
    threshold: 4,
    found: [...typesFound],
    missing: allTypes.filter(t => !typesFound.has(t))
  };

  // Gate 2: Breaking changes documented (only in diff mode)
  const breakingChanges = changes?.breaking || [];
  const documented = breakingChanges.filter(bc => bc.migrationNote);
  const breakingChangesDocumented = {
    pass: breakingChanges.length === 0 || documented.length === breakingChanges.length,
    actual: documented.length,
    total: breakingChanges.length,
    undocumented: breakingChanges.filter(bc => !bc.migrationNote)
  };

  // Gate 3: Cross-type congruence >= 80%
  const congruenceGate = {
    pass: congruence.congruenceScore >= 80,
    actual: congruence.congruenceScore,
    threshold: 80,
    issues: congruence.issues.length
  };

  const rulesPassed = [contractsCovered, breakingChangesDocumented, congruenceGate]
    .filter(g => g.pass).length;
  const tier = rulesPassed === 3 ? 'gold' : rulesPassed >= 2 ? 'silver' : 'bronze';

  return { contractsCovered, breakingChangesDocumented, congruenceScore: congruenceGate, tier, rulesPassed, rulesTotal: 3 };
}
```

---

## Output Schema

```typescript
interface ContractChangeValidatorOutput {
  skillName: "contract-change-validator";
  version: "1.0.0";
  timestamp: string;
  status: "success" | "partial" | "failed";
  trustTier: 3;
  output: {
    targetPath: string;
    analysisType: "extract" | "diff" | "both";

    summary: {
      totalContracts: number;
      byType: {
        restApi: number;
        dataDefinitions: number;
        testData: number;
        events: number;
        urlConfig: number;
        libraryVersions: number;
      };
      breakingChanges: number;
      missedUpdates: number;
      congruenceScore: number; // 0-100
      note: string;
    };

    contracts: Array<{
      type: "rest-api" | "data-definition" | "test-data" | "event" | "url-config" | "library-version";
      source: string;
      data: object; // Type-specific extracted data
    }>;

    changes?: {
      baseBranch: string;
      added: Array<{ type: string; source: string; detail: string }>;
      removed: Array<{ type: string; source: string; detail: string }>;
      modified: Array<{ type: string; source: string; detail: string; breaking: boolean }>;
      breaking: Array<{
        type: string;
        source: string;
        changeType: string; // removed-endpoint, type-change, required-field-added, etc.
        impact: "high" | "medium" | "low";
        detail: string;
        migrationNote?: string;
      }>;
    };

    congruenceIssues: Array<{
      type: string;
      severity: "HIGH" | "MEDIUM" | "LOW";
      source: string;
      target: string;
      message: string;
    }>;

    qualityGates: {
      contractsCovered: { pass: boolean; actual: number; threshold: number; found: string[]; missing: string[] };
      breakingChangesDocumented: { pass: boolean; actual: number; total: number };
      congruenceScore: { pass: boolean; actual: number; threshold: 80 };
      tier: "gold" | "silver" | "bronze";
      rulesPassed: number;
      rulesTotal: 3;
    };

    recommendations: string[];
  };
}
```

---

## Output Summary Format

```
CONTRACT CHANGE VALIDATOR
==========================

Target:    [target path]
Project:   [project name]
Generated: [timestamp]
Mode:      [extract / diff / both]

CONTRACTS DISCOVERED
  REST API:           ___
  Data Definitions:   ___
  Test Data:          ___
  Events/Messages:    ___
  URLs/Config:        ___
  Library Versions:   ___
  TOTAL:              ___

[DIFF SECTION - only if diff mode]
CHANGES vs [base branch]
  Added:     ___ contracts
  Removed:   ___ contracts
  Modified:  ___ contracts
  Breaking:  ___ changes

CONGRUENCE CHECK
  Score:               ___ / 100
  Issues Found:        ___
    HIGH severity:     ___
    MEDIUM severity:   ___
    LOW severity:      ___

QUALITY GATES                              [GOLD / SILVER / BRONZE]
  Contracts covered (>= 4/6):     [PASS/FAIL] (actual: ___)
  Breaking changes documented:    [PASS/FAIL] (actual: ___/___)
  Congruence score (>= 80%):      [PASS/FAIL] (actual: ___)

RECOMMENDATIONS
  - [actionable items for congruence issues]

NOTE: Contract extraction uses static analysis (Glob + pattern matching).
      Not instrumented runtime analysis -- reflects file-level patterns only.

OUTPUT
  JSON: docs/contract-changes/[project]/latest.json
```

---

## AISP Quality Gate Definition

```aisp
A5.1.ContractChangeValidator@2026-02-12
gamma := "contract-change-validator-gate"

[Sigma:Types]{
  Contract := {type: ContractType, source: String, data: Object}
  ContractType := RestApi | DataDefinition | TestData | Event | UrlConfig | LibraryVersion
  CongruenceIssue := {type: String, severity: Severity, source: String, target: String}
  Severity := HIGH | MEDIUM | LOW
}

[Gamma:QualityGates]{
  |{t | t in discoveredTypes}| >= 4
    |- contracts_covered

  forall bc in breakingChanges. bc.migrationNote != null
    |- breaking_documented

  congruenceScore >= 80
    |- congruence_adequate

  contracts_covered AND breaking_documented AND congruence_adequate
    => tier = gold
}
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| `aqe` not installed | Fall back to Glob discovery (warn user) |
| No contract files found | Report empty inventory with note |
| Git not available (diff mode) | Skip diff, report extract only |
| OpenAPI parse failure | Skip file, include in partial results |
| Zero contracts | Status = "failed", recommend running `aqe init` |

---

## Dependencies

| Dependency | Required | Purpose |
|------------|----------|---------|
| Glob + Grep | Always available | Contract file discovery |
| Read | Always available | File content extraction |
| Git | Optional | Diff mode comparisons |
| `aqe qe contracts validate` | Optional | AQE contract validation |
| `aqe code index` | Optional | KG-based discovery |
| qe-contract-validator agent | Optional | Deep contract validation |
| qe-api-compatibility agent | Optional | Breaking change detection |

---

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `test-inventory` | Discovers test files (BL-241) -- this skill discovers contracts |
| `test-quality-evaluator` | Grades test realism (BL-242) |
| `frontend-test-spec-generator` | Generates test specs (BL-240) |
| `contract-testing` | Consumer-driven contract testing |
| `api-testing-patterns` | API testing patterns |

---

## Changelog

### v1.0.0 (2026-02-12)
- Initial release for BL-245
- 7-phase execution: parse, AQE foundation, discovery, diff, congruence, quality gates, output
- 6 contract types: REST API, Data Definitions, Test Data, Events, URLs, Library Versions
- Cross-type congruence checking with scoring
- Breaking change detection with migration note tracking
- AISP quality gates: contracts covered, breaking documented, congruence score
- JSON output with two-level envelope (consistent with BL-240/241/242)
- CLI-first: `claude -p "/contract-change-validator"`
- Leverages existing AQE contract-testing domain when available

---

*Created for Linear Issue BL-245: Review and Enhance AI-Based Contract Change Extraction/Validation*
