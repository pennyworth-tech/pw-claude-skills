# Skill: env-dependency-extractor

## Metadata
- **Name**: env-dependency-extractor
- **Version**: 1.0.0
- **Description**: Extract and track environment variables, package dependencies, and external service dependencies across monorepo services. Detect mismatches, missing configs, and security risks.
- **Author**: @pennyworth-tech
- **Linear Issue**: BL-246
- **Tags**: environment, dependencies, configuration, extraction, monorepo
- **Trust Tier**: 2 (file system read + AQE CLI)

## Usage

```bash
# Extract all env vars and dependencies from current directory
claude -p "/env-dependency-extractor"

# Extract from specific path
claude -p "/env-dependency-extractor path:src/"

# Diff against main branch (detect changes/deltas)
claude -p "/env-dependency-extractor diff --base main"

# Filter by environment type
claude -p "/env-dependency-extractor --env production"
claude -p "/env-dependency-extractor --env test"

# Full analysis with security audit
claude -p "/env-dependency-extractor path:. diff --base main --audit-secrets"
```

## Phases

### PHASE 1: Parse Input
Parse CLI arguments to determine:
- `path`: Target directory (default: `.`)
- `diff`: Enable diff mode with `--base <branch>`
- `--env`: Filter by environment type (`production`, `test`, `development`, `all`)
- `--audit-secrets`: Enable secret detection in committed files
- `--output`: Output format (`json`, `markdown`, `both`; default: `json`)

### PHASE 2: AQE Foundation
Run AQE CLI tools for baseline data:

```bash
# Index codebase for dependency graph
aqe code index <path> 2>/dev/null || true

# Run dependency analysis
aqe dependencies <path> 2>/dev/null || true
```

If AQE CLI unavailable, fall back to Glob/Grep discovery (Phase 3).

### PHASE 3: Environment Variable Discovery
Scan for ALL environment variable definitions and references using 6 extraction strategies:

#### Strategy 1: .env files
```bash
# Find all .env pattern files
Glob("**/.env.example", "**/.env.local", "**/.env.development", "**/.env.production", "**/.env.test")
```
Parse each file line-by-line: `VARIABLE_NAME=default_value`

#### Strategy 2: process.env references (TypeScript/JavaScript)
```bash
Grep("process\\.env\\.", glob: "*.{ts,tsx,js,jsx}", exclude: "node_modules,.next,dist")
```
Extract variable name from `process.env.VARIABLE_NAME`.

#### Strategy 3: Python os.environ / os.getenv references
```bash
Grep("os\\.environ|os\\.getenv|environ\\.get", glob: "*.py", exclude: "__pycache__,venv,.venv")
```

#### Strategy 4: Pydantic Settings classes
```bash
Grep("class.*BaseSettings|Field\\(.*env=", glob: "*.py")
```
Parse field names with `env=` parameter or class Field defaults.

#### Strategy 5: Docker/Compose environment blocks
```bash
Grep("environment:|env_file:|ENV\\s", glob: "{docker-compose*.yml,Dockerfile*}")
```

#### Strategy 6: CI/CD secrets
```bash
Grep("secrets\\.|\\$\\{\\{.*secrets", glob: ".github/workflows/*.yml")
```

For each variable discovered, classify:
- **Name**: Variable name
- **Service**: Which service/directory owns it
- **Environment**: production, test, development, or all
- **HasDefault**: Whether a default value exists
- **IsSecret**: Whether it appears to be a secret (API keys, passwords, tokens)
- **Sources**: List of files where it's defined/referenced
- **UsedInCode**: Whether it's actually referenced in application code (not just .env)

### PHASE 4: Package Dependency Discovery
Scan for ALL package dependencies across language ecosystems:

#### JavaScript/TypeScript
```bash
Glob("**/package.json", exclude: "node_modules")
```
Parse `dependencies`, `devDependencies`, `peerDependencies`. Note version constraints and whether pinned or floating.

#### Python
```bash
Glob("**/requirements*.txt", "**/pyproject.toml", "**/setup.py", "**/Pipfile")
```
Parse package names and version specifiers.

#### Docker
```bash
Glob("**/Dockerfile*")
```
Extract `FROM` image:tag base images.

#### Lock Files
```bash
Glob("**/package-lock.json", "**/bun.lock", "**/yarn.lock", "**/poetry.lock", "**/Pipfile.lock")
```
Note presence/absence per service (missing lock files = risk).

For each dependency:
- **Name**: Package name
- **Version**: Version constraint
- **Pinned**: Whether version is pinned (==, exact) vs floating (^, ~, >=)
- **Service**: Which service uses it
- **Type**: runtime, dev, peer, build
- **Ecosystem**: npm, pip, docker

### PHASE 5: External Service Discovery
Identify all external service integrations:

```bash
# API URLs in config
Grep("https?://.*\\.com|https?://.*\\.io|https?://.*\\.ai", glob: "*.{ts,py,yml,yaml,env*}")

# Known provider patterns
Grep("openai|together|elevenlabs|cerebras|daily\\.co|google|apple|discord|ngrok|neo4j|postgres", glob: "*.{ts,py,yml,yaml}")
```

For each external service:
- **Provider**: Service name
- **Purpose**: What it's used for
- **AuthMethod**: API key, OAuth, connection string
- **EnvVars**: Which env vars configure it
- **Services**: Which internal services use it

### PHASE 6: Cross-Service Analysis
Detect mismatches and issues:

1. **Version Mismatches**: Same package used in multiple services with different versions
2. **Missing Env Vars**: Variable referenced in code but not in any .env file
3. **Orphaned Env Vars**: Variable in .env but never referenced in code
4. **Missing Lock Files**: Services without lock files (reproducibility risk)
5. **Unpinned Dependencies**: Dependencies using `latest` or wide floating ranges
6. **Secret Exposure Risk**: Secrets without .gitignore protection or committed to VCS
7. **Service URL Consistency**: Internal service URLs match docker-compose ports

Score each issue by severity (HIGH/MEDIUM/LOW) and compute overall health score (0-100).

### PHASE 7: AISP Quality Gates

| Gate | Rule | Threshold |
|------|------|-----------|
| Env Coverage | All .env.example vars have code references | >= 90% |
| Dependency Tracking | All services have dependency manifests discovered | 100% |
| Health Score | Cross-service analysis health | >= 75 |

**Tier Assignment**:
- **Gold**: 3/3 gates pass
- **Silver**: 2/3 gates pass
- **Bronze**: 0-1/3 gates pass

### PHASE 8: Output & Persist
Save structured JSON output:

```bash
# Primary output
docs/env-dependencies/<project>/latest.json

# Archived copy
docs/env-dependencies/<project>/archive/<timestamp>.json

# Markdown summary
docs/env-dependencies/<project>/latest-summary.md
```

## Diff Mode

When `diff --base <branch>` is specified, add Phase 5b after extraction:

1. Run `git diff <base>...HEAD` on all config files
2. Compare current extraction against base branch extraction
3. Report:
   - **Added**: New env vars or dependencies
   - **Removed**: Deleted env vars or dependencies
   - **Changed**: Version bumps, default value changes
   - **Breaking**: Removed required env vars, major version changes

## Output Schema

See `schemas/output.schema.json` for the full JSON Schema.

Key output sections:
- `envVars[]`: All discovered environment variables with metadata
- `dependencies[]`: All package dependencies with versions
- `externalServices[]`: External service integrations
- `crossServiceIssues[]`: Detected mismatches and problems
- `qualityGates`: AISP gate results with tier
- `summary`: Counts, health score, recommendations

## Integration with Existing AQE Fleet

```
User: claude -p "/env-dependency-extractor"
  |
  |-- Uses: aqe code index (existing CLI)
  |-- Uses: aqe dependencies (existing CLI)
  |-- Spawns: qe-dependency-mapper (existing agent)
  |-- Spawns: qe-code-intelligence (existing agent, for code-to-env mapping)
  |-- Spawns: qe-security-scanner (existing agent, for secret audit)
  |-- Stores: docs/env-dependencies/<project>/latest.json
  |-- Stores: AQE memory (environment patterns namespace)
  |
  v
[Output: JSON + Markdown Summary]
```

## Examples

### Example: Basic extraction
```bash
claude -p "/env-dependency-extractor"
```
Output: Full inventory of env vars, dependencies, and external services.

### Example: Detect changes before merging
```bash
claude -p "/env-dependency-extractor diff --base main"
```
Output: Delta report showing what env vars/deps changed on current branch.

### Example: Production audit
```bash
claude -p "/env-dependency-extractor --env production --audit-secrets"
```
Output: Production-only env vars with secret exposure analysis.
