---
name: ralph-wiggum
description: Iterative self-referential development loop methodology for autonomous AI task completion. Use when implementing complex features requiring refinement, getting tests to pass, or executing well-defined tasks with automatic verification. Named after Ralph Wiggum for persistent iteration despite setbacks.
license: MIT
version: 1.0.0
category: methodology
platforms:
  - all
tags:
  - tdd
  - iteration
  - autonomous
  - development-loop
  - self-referential
  - methodology
trust_tier: 3
validation:
  schema_path: schemas/output.schema.json
  validator_path: scripts/validate.sh
  eval_path: evals/eval.yaml
  validation_status: verified
---

# Ralph Wiggum - Iterative Development Loop

A methodology for autonomous, iterative AI development using self-referential feedback loops.

## Core Concept

Ralph is fundamentally **"a loop"** - a mechanism that:
1. Feeds Claude a prompt repeatedly
2. Allows Claude to work iteratively
3. Re-feeds the same prompt with modified files
4. Continues until a completion promise is detected

**Key Innovation**: The prompt never changes between iterations, but Claude sees its own past work in modified files and git history, enabling autonomous self-improvement.

## When to Use Ralph

### Ideal Use Cases
- Well-defined tasks with clear success criteria
- Tasks requiring iteration and refinement (TDD cycles)
- Greenfield projects with automatic verification
- Tasks with test-based validation (tests, linters, builds)
- Long-running implementation tasks

### Not Recommended For
- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Production debugging
- Interactive decision-making

## Prompt Design Patterns

### 1. Clear Completion Criteria

**Bad:**
```
Build a todo API and make it good.
```

**Good:**
```
Build a REST API for todos.

When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- README with API docs
- Output: <promise>COMPLETE</promise>
```

### 2. Incremental Phases

**Bad:**
```
Create a complete e-commerce platform.
```

**Good:**
```
Implement user authentication following TDD:

Phase 1: User registration (model, tests)
Phase 2: Login endpoint (JWT, tests)
Phase 3: Token refresh (tests)
Phase 4: Password reset (tests)

After each phase:
- Run tests: npm test
- If failures, fix and retry
- Only proceed when all tests pass

Output <promise>DONE</promise> when all phases complete.
```

### 3. Self-Correction Mechanisms

```
Implement feature X following TDD:

1. Write failing tests first
2. Implement minimal code to pass
3. Run tests: npm test
4. If any fail:
   - Read error messages
   - Debug and fix
   - Run tests again
5. Refactor if needed
6. Repeat until all green
7. Output: <promise>COMPLETE</promise>
```

### 4. Safety Limits and Fallbacks

Always include iteration limits and fallback instructions:

```
Maximum iterations: 20

If not complete after 15 iterations:
- Document what's blocking progress
- List what was attempted
- Suggest alternative approaches
- Output: <promise>BLOCKED</promise>
```

## Implementation Template

### Basic Loop Structure

```bash
# Ralph loop pseudo-implementation
while true; do
    # Feed prompt to Claude
    claude_output=$(claude --prompt "$PROMPT")

    # Check for completion promise
    if echo "$claude_output" | grep -q "<promise>$COMPLETION_PROMISE</promise>"; then
        echo "Task complete!"
        break
    fi

    # Increment iteration
    iteration=$((iteration + 1))

    # Safety check
    if [ $iteration -ge $max_iterations ]; then
        echo "Max iterations reached"
        break
    fi

    # Loop continues - Claude sees modified files
done
```

### Pennyworth Fleet Integration

For PWF pipeline integration, Ralph methodology applies at the Refinement phase:

```typescript
// TDD Refinement Loop following Ralph principles
interface RalphConfig {
  maxIterations: number;
  completionPromise: string;
  verificationCommand: string;  // e.g., "npm test"
}

async function refinementLoop(config: RalphConfig): Promise<void> {
  let iteration = 0;

  while (iteration < config.maxIterations) {
    // Execute TDD cycle
    const result = await executeTDDCycle();

    // Verify with automated tests
    const verification = await runCommand(config.verificationCommand);

    if (verification.success && result.testsPass) {
      // Completion promise achieved
      console.log(`<promise>${config.completionPromise}</promise>`);
      break;
    }

    // Iteration continues - agent sees previous work
    iteration++;
  }
}
```

## Best Practices

### 1. Prompt Stability
Keep prompts consistent - the power of Ralph comes from seeing your own work evolve, not from changing instructions.

### 2. Verifiable Success
Always use automated verification:
- Test suites
- Linters
- Build commands
- Type checking

### 3. Git History as Memory
Commit after meaningful progress:
```bash
git add -A && git commit -m "Iteration $n: [description]"
```

### 4. Explicit Exit Conditions
Always define multiple exit paths:
- Success: `<promise>COMPLETE</promise>`
- Blocked: `<promise>BLOCKED</promise>`
- Max iterations reached
- Unrecoverable error

### 5. Progress Markers
Include progress tracking in your prompt:
```
After each iteration, log:
- Files modified
- Tests passing/failing
- Current blockers
- Next action
```

## Philosophy

1. **Iteration > Perfection** - Don't aim for perfect on first try; let the loop refine
2. **Failures Are Data** - "Deterministically bad" failures are predictable and informative
3. **Operator Skill Matters** - Success depends on writing good prompts
4. **Persistence Wins** - Keep trying until success; the loop handles retry logic
5. **Self-Reference is Power** - Seeing your own work enables improvement

## Example: TDD Feature Implementation

```
Implement user authentication for the Express API.

## Requirements
- POST /api/auth/register - Create new user
- POST /api/auth/login - Return JWT
- GET /api/auth/me - Return current user (protected)
- POST /api/auth/refresh - Refresh token

## TDD Process (Each Iteration)
1. Check current test status: npm test
2. If tests failing:
   - Read error messages
   - Fix the specific failure
   - Run tests again
3. If tests passing but feature incomplete:
   - Write next failing test
   - Implement to pass
4. Commit progress: git add -A && git commit -m "Progress: [description]"

## Verification Commands
- Tests: npm test
- Lint: npm run lint
- Types: npm run typecheck

## Completion Criteria
- All 4 endpoints implemented
- All tests passing
- Coverage > 80%
- No lint errors
- No type errors

When all criteria met, output: <promise>AUTH_COMPLETE</promise>

## Fallback (after 15 iterations)
If blocked, document:
- What's working
- What's failing
- Suggested resolution
Output: <promise>AUTH_BLOCKED</promise>
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Ralph Loop
on: workflow_dispatch
  inputs:
    prompt_file:
      description: 'Path to prompt file'
      required: true
    max_iterations:
      description: 'Maximum iterations'
      default: '20'
    completion_promise:
      description: 'Completion marker'
      required: true

jobs:
  ralph:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Ralph Loop
        run: |
          ./scripts/ralph-loop.sh \
            --prompt "${{ inputs.prompt_file }}" \
            --max-iterations "${{ inputs.max_iterations }}" \
            --completion-promise "${{ inputs.completion_promise }}"
```

## Resources

- Original technique: https://ghuntley.com/ralph/
- Claude Code Plugin: https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator
