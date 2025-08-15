# Claude Automation Scripts

This directory contains automation scripts that enable Claude to automatically solve GitHub issues by creating branches, implementing solutions, and creating pull requests.

## 🚀 Quick Start

To solve a GitHub issue automatically:

```bash
# Solve issue #123
./solve-issue.sh 123

# Or with a full GitHub URL
./solve-issue.sh https://github.com/Noomafi-Technologies/django-base-project/issues/123

# Dry run to see what would be done
./solve-issue.sh 123 --dry-run
```

## 📁 Script Overview

### `solve-issue.sh` - Main Orchestrator
The primary script that coordinates the entire workflow.

**Usage:**
```bash
./solve-issue.sh <issue-number> [options]
```

**Options:**
- `--dry-run`: Show what would be done without executing
- `--skip-tests`: Skip running tests after implementation
- `--no-pr`: Don't create pull request automatically
- `--help`: Show help message

### `issue-analyzer.py` - Issue Analysis
Analyzes GitHub issues to extract requirements and metadata.

**Features:**
- Fetches issue details using GitHub CLI
- Extracts requirements from issue body
- Determines issue type and complexity
- Suggests files that might need modification
- Generates appropriate branch names

**Usage:**
```bash
python3 issue-analyzer.py <issue-number>
```

### `branch-manager.sh` - Git Branch Management
Manages git branches for the automated workflow.

**Commands:**
```bash
./branch-manager.sh create <branch-name>     # Create new branch from main
./branch-manager.sh switch <branch-name>     # Switch to existing branch
./branch-manager.sh cleanup <branch-name>    # Delete branch locally and remotely
./branch-manager.sh sync                     # Sync with remote main branch
./branch-manager.sh status                   # Show current branch status
```

### `pr-creator.sh` - Pull Request Creation
Creates comprehensive pull requests with auto-generated content.

**Features:**
- Generates descriptive PR titles based on issue type
- Creates detailed PR body with issue reference
- Includes test plan and change summary
- Automatically links to the original issue

**Usage:**
```bash
./pr-creator.sh <issue-number> [branch-name] [title] [body-file]
```

## 🔧 Prerequisites

### Required Tools
- **Git** - Version control
- **GitHub CLI (`gh`)** - GitHub integration
- **jq** - JSON processing
- **Python 3** - For issue analysis script

### Installation Commands

**macOS (Homebrew):**
```bash
brew install gh jq python3
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install gh jq python3
```

### Authentication Setup
```bash
# Authenticate with GitHub
gh auth login

# Verify authentication
gh auth status
```

## 🏗️ Workflow Steps

The automation performs these steps automatically:

1. **📋 Issue Analysis**
   - Fetches issue details from GitHub
   - Extracts requirements and metadata
   - Determines implementation complexity
   - Suggests files to modify

2. **🌿 Branch Creation**
   - Syncs with main branch
   - Creates appropriately named feature branch
   - Sets up upstream tracking

3. **💻 Solution Implementation**
   - Analyzes issue requirements
   - Implements code changes
   - Follows project conventions

4. **🧪 Testing & Validation**
   - Runs project tests
   - Performs system checks
   - Validates implementation

5. **📝 Change Commitment**
   - Creates descriptive commit messages
   - References original issue
   - Includes Claude attribution

6. **🔄 Pull Request Creation**
   - Generates comprehensive PR description
   - Includes test plan and checklist
   - Links to original issue

## 📊 Issue Type Detection

The system automatically detects issue types based on labels and keywords:

| Type | Detection Criteria | Branch Prefix |
|------|-------------------|---------------|
| **Bug Fix** | Labels: `bug`, `fix` or keywords: `fix`, `bug`, `error` | `fix/` |
| **Feature** | Labels: `feature`, `new` or keywords: `add`, `new`, `create` | `feature/` |
| **Enhancement** | Labels: `enhancement`, `improvement` or keywords: `improve`, `enhance` | `enhancement/` |
| **Documentation** | Labels: `docs`, `documentation` | `docs/` |
| **Testing** | Labels: `test` | `test/` |

## 🎯 Branch Naming Convention

Branches are automatically named using this pattern:
```
{type}/issue-{number}-{sanitized-title}
```

**Examples:**
- `feature/issue-123-add-user-avatar-upload`
- `fix/issue-456-login-redirect-bug`
- `enhancement/issue-789-improve-api-performance`

## 📝 Commit Message Format

Commits follow conventional commit format:
```
{type}: {description} (fixes #{issue-number})

{detailed description}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## 🔍 Example Usage

### Solving a Bug Report
```bash
# Issue: "Login page shows 500 error after password reset"
./solve-issue.sh 123

# Results in:
# - Branch: fix/issue-123-login-page-500-error-password-reset
# - Commit: "fix: Login page shows 500 error after password reset (fixes #123)"
# - PR: "Fix: Login page shows 500 error after password reset (fixes #123)"
```

### Adding a New Feature
```bash
# Issue: "Add user avatar upload functionality"
./solve-issue.sh 456

# Results in:
# - Branch: feature/issue-456-add-user-avatar-upload-functionality
# - Commit: "feat: Add user avatar upload functionality (closes #456)"
# - PR: "Feature: Add user avatar upload functionality (closes #456)"
```

### Dry Run for Planning
```bash
# See what would be done without executing
./solve-issue.sh 789 --dry-run

# Output shows planned steps without making changes
```

## 🛡️ Safety Features

- **Dry Run Mode**: Preview changes before execution
- **Working Directory Checks**: Ensures clean state before operations
- **Branch Existence Validation**: Prevents conflicts with existing branches
- **Authentication Verification**: Confirms GitHub access before starting
- **Error Handling**: Graceful failure with descriptive error messages

## 🔧 Customization

### Modifying Issue Analysis
Edit `issue-analyzer.py` to:
- Add new issue type detection
- Modify complexity assessment
- Change file suggestion logic

### Customizing PR Templates
Edit `pr-creator.sh` to:
- Modify PR body template
- Add custom sections
- Change formatting

### Extending Branch Management
Edit `branch-manager.sh` to:
- Add new branch operations
- Modify naming conventions
- Add custom validations

## 📚 Integration with Claude

When Claude receives a request like "Solve issue #123", it will:

1. Run the issue analysis to understand requirements
2. Create the appropriate branch
3. Implement the solution based on the analysis
4. Test the implementation
5. Commit with proper messages
6. Create a comprehensive pull request

This creates a fully automated development workflow that maintains consistency and quality while reducing manual overhead.

## 🤝 Contributing

To improve the automation scripts:

1. Test changes with `--dry-run` first
2. Ensure scripts remain POSIX-compliant
3. Add error handling for edge cases
4. Update documentation for new features
5. Test with various issue types

---

**Note**: These scripts are designed to work with Claude Code's automated issue-solving capabilities. They provide the infrastructure for Claude to automatically understand, implement, and deploy solutions for GitHub issues.