# Pre-Push Code Review

Review my code changes before I push to GitHub.
Be adversarial.
Use multiple sug agents to review the code in different contexts and perspectives.

## What to Review

Ensure branch is rebased against origin/main or origin/master
On review tracked files that are different to origin/main or origin/master

## Review Categories

Analyze each changed file for the following issues, categorizing by severity:

### 🔴 Blockers (must fix before pushing)
- **Security vulnerabilities**: SQL injection, XSS, CSRF issues, insecure authentication, exposed credentials/secrets/API keys
- **Bugs & logic errors**: Nil/null reference errors, off-by-one errors, race conditions, incorrect conditionals
- **Accidentally committed debug code**: `binding.pry`, `debugger`, `console.log`, `byebug`, hardcoded test data, TODO/FIXME that blocks functionality
- **Linting issues**: run rubocop over the changed files
- **Commit message/s**: Ensure they meet the commitlint and use conventional commits

### 🟡 Warnings (strongly consider fixing)
- **Performance issues**: N+1 queries, missing database indexes, inefficient loops, memory leaks, unnecessary re-renders (React/JS)
- **Breaking changes**: API contract changes, removed public methods, changed method signatures, migration issues
- **Missing tests**: New public methods without tests, untested edge cases, reduced coverage for critical paths

### 🟢 Suggestions (nice to have)
- **Readability**: Complex methods that should be extracted, unclear naming, missing comments on non-obvious logic
- **Minor improvements**: Opportunities for Rails idioms, modern JS syntax, DRYing up code


## Output Format

### 1. Summary
Provide a brief overall assessment:
- Total files changed
- Count of issues by severity (🔴/🟡/🟢)
- **Verdict**: "Ready to push" / "Needs attention" / "Do not push"

### 2. File-by-File Breakdown
For each file with issues:

```
📄 path/to/file.rb
  🔴 [Security] Line 23: SQL injection vulnerability in user query
     → Suggested fix: Use parameterized query instead
     ```ruby
     User.where("name = ?", params[:name])
     ```

  🟡 [Performance] Line 45-50: N+1 query detected
     → Suggested fix: Add `.includes(:posts)` to the query
```

### 3. Auto-Fix Offers
After the breakdown, if you found any of these, offer to auto-fix:
- Remove debug statements (`binding.pry`, `console.log`, `debugger`, `byebug`)
- Remove accidental `puts` or `p` debugging output

Ask: "Would you like me to automatically remove the debug statements found in [list files]?"

---
