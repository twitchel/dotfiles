# Test Reporting

## Overview

This repository now includes automated test reporting that runs on every pull request. Test results are published in multiple formats for easy review.

## Features

### 1. GitHub Actions Job Summary
After each test run, a summary is automatically added to the GitHub Actions job page showing:
- Total number of tests
- Number of passed tests (✅)
- Number of failed tests (❌)
- Detailed output in a collapsible section

### 2. Pull Request Comments
Test results are automatically posted as a comment on the pull request. The comment:
- Shows a summary of test results
- Lists any failed tests
- Includes detailed output in a collapsible section
- Updates automatically on subsequent test runs (doesn't create duplicate comments)

### 3. Downloadable Artifacts
The following files are uploaded as workflow artifacts:
- `test-results.tap` - TAP (Test Anything Protocol) format results
- `test-output.log` - Verbose test output
- `test-report.md` - Markdown formatted report

## Example Report

```markdown
## Test Results

- **Total Tests:** 7
- **Passed:** ✅ 7
- **Failed:** ❌ 0

<details>
<summary>View Detailed Test Output</summary>

\`\`\`
Launching ZUnit
ZUnit: 0.8.2
ZSH:   zsh 5.9 (x86_64-ubuntu-linux-gnu)

✔ Test that common aliases can be defined
✔ Test mkcd alias functionality
✔ Test alias command returns non-empty for defined aliases
✔ Test source_file function can source existing files
✔ Test source_file function definition
✔ Test that ZSH_SOURCED is set after sourcing .zshrc
✔ Test that ZDOTDIR is set correctly

7 tests run in 169ms

Results                        
✔ Passed      7                    
✘ Failed      0                      
‼ Errors      0                      
● Skipped     0                 
‼ Warnings    0                 
\`\`\`
</details>

*Updated at: 2026-02-16T01:40:45.707Z*
```

## How It Works

1. **Test Execution**: Tests run using zsh-zunit in verbose mode
2. **Output Capture**: Both verbose output and TAP format are captured
3. **Report Generation**: A bash script parses the TAP output and generates a markdown report
4. **Job Summary**: The report is added to `$GITHUB_STEP_SUMMARY`
5. **Artifact Upload**: Test files are uploaded as workflow artifacts
6. **PR Comment**: GitHub Actions script posts/updates the PR comment
7. **Status Check**: The workflow fails if any tests failed (after reporting completes)

## Benefits

- **Visibility**: Test results are immediately visible on the PR without checking workflow logs
- **History**: Artifacts preserve test results for future reference
- **Automation**: No manual steps required - everything happens automatically
- **Updates**: Comments update on subsequent runs instead of creating spam
- **Accessibility**: Multiple formats (TAP, Markdown, Logs) for different use cases
