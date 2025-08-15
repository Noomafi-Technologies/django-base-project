#!/bin/bash

# Claude PR Creator
# Creates pull requests for automated issue solving

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <issue-number> [branch-name] [title] [body-file]"
    echo ""
    echo "Arguments:"
    echo "  issue-number    GitHub issue number to reference"
    echo "  branch-name     Source branch (default: current branch)"
    echo "  title          PR title (default: generated from issue)"
    echo "  body-file      File containing PR body (default: generated)"
    echo ""
    echo "Examples:"
    echo "  $0 123"
    echo "  $0 123 feature/issue-123-add-avatar"
    echo "  $0 123 feature/issue-123-add-avatar \"Add user avatar upload\""
}

# Function to get current branch
get_current_branch() {
    git branch --show-current
}

# Function to get issue info from analysis file
get_issue_info() {
    local issue_number="$1"
    local analysis_file="/tmp/issue-${issue_number}-analysis.json"
    
    if [ ! -f "$analysis_file" ]; then
        error "Issue analysis file not found: $analysis_file"
        error "Run issue-analyzer.py first"
        exit 1
    fi
    
    echo "$analysis_file"
}

# Function to generate PR title
generate_pr_title() {
    local issue_number="$1"
    local analysis_file="$2"
    
    # Extract title from analysis
    local issue_title=$(jq -r '.issue.title' "$analysis_file")
    local issue_type=$(jq -r '.issue.type' "$analysis_file")
    
    # Format title based on type
    case "$issue_type" in
        "fix")
            echo "Fix: $issue_title (fixes #$issue_number)"
            ;;
        "feature")
            echo "Feature: $issue_title (closes #$issue_number)"
            ;;
        "enhancement")
            echo "Enhancement: $issue_title (closes #$issue_number)"
            ;;
        "docs")
            echo "Docs: $issue_title (closes #$issue_number)"
            ;;
        *)
            echo "$issue_title (closes #$issue_number)"
            ;;
    esac
}

# Function to generate PR body
generate_pr_body() {
    local issue_number="$1"
    local analysis_file="$2"
    local branch_name="$3"
    
    local issue_title=$(jq -r '.issue.title' "$analysis_file")
    local issue_type=$(jq -r '.issue.type' "$analysis_file")
    local issue_url=$(jq -r '.issue.url' "$analysis_file")
    local requirements=$(jq -r '.issue.requirements[]' "$analysis_file" 2>/dev/null || echo "")
    local files_modified=$(git diff --name-only main...HEAD)
    
    cat << EOF
## 🔗 Related Issue
Closes #${issue_number}

## 📋 Problem Statement
${issue_title}

**Issue Type:** ${issue_type}
**Reference:** ${issue_url}

## 🚀 Solution Overview
This PR implements the solution for issue #${issue_number}.

### Requirements Addressed:
EOF

    # Add requirements if they exist
    if [ -n "$requirements" ]; then
        echo "$requirements" | while IFS= read -r req; do
            if [ -n "$req" ]; then
                echo "- ✅ $req"
            fi
        done
    else
        echo "- ✅ Implemented solution as described in the issue"
    fi

    cat << EOF

## 🔄 Changes Made

### Files Modified:
EOF

    # List modified files
    if [ -n "$files_modified" ]; then
        echo "$files_modified" | while IFS= read -r file; do
            echo "- \`$file\`"
        done
    else
        echo "- No files modified"
    fi

    echo ""
    echo "### Detailed Changes:"
    
    # Get commit messages for this PR
    local commits=$(git log --oneline main..HEAD --reverse)
    if [ -n "$commits" ]; then
        echo "$commits" | while IFS= read -r commit; do
            echo "- $commit"
        done
    fi

    cat << EOF

## 🧪 Testing

### Test Plan:
- [ ] Code compiles without errors
- [ ] Existing tests pass
- [ ] New functionality works as expected
- [ ] Edge cases handled appropriately
- [ ] No regressions introduced

### Manual Testing:
- [ ] Tested functionality manually
- [ ] Verified UI/UX if applicable
- [ ] Tested error scenarios
- [ ] Verified performance impact

## 📸 Screenshots (if applicable)
_Add screenshots or GIFs demonstrating the changes_

## 🔍 Code Review Checklist
- [ ] Code follows project style guidelines
- [ ] Comments added for complex logic
- [ ] No debugging code left behind
- [ ] Security considerations addressed
- [ ] Documentation updated if needed

## 💥 Breaking Changes
_List any breaking changes or note "None"_

## 📝 Additional Notes
_Any additional context, considerations, or follow-up items_

---

🤖 **Generated automatically by Claude Code**

**Branch:** \`${branch_name}\`
**Issue:** [#${issue_number}](${issue_url})
EOF
}

# Function to create pull request
create_pull_request() {
    local issue_number="$1"
    local branch_name="$2"
    local pr_title="$3"
    local pr_body="$4"
    
    info "Creating pull request..."
    
    # Create temporary file for PR body
    local body_file="/tmp/pr-body-${issue_number}.md"
    echo "$pr_body" > "$body_file"
    
    # Create PR using gh CLI
    local pr_url
    pr_url=$(gh pr create \
        --title "$pr_title" \
        --body-file "$body_file" \
        --base main \
        --head "$branch_name" \
        --assignee "@me")
    
    if [ $? -eq 0 ]; then
        log "Pull request created successfully!"
        log "URL: $pr_url"
        
        # Clean up temporary file
        rm -f "$body_file"
        
        return 0
    else
        error "Failed to create pull request"
        return 1
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    # Check if gh CLI is installed
    if ! command -v gh > /dev/null 2>&1; then
        error "GitHub CLI (gh) is not installed"
        error "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status > /dev/null 2>&1; then
        error "GitHub CLI is not authenticated"
        error "Run: gh auth login"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq > /dev/null 2>&1; then
        error "jq is not installed"
        error "Install it with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
        exit 1
    fi
    
    # Check if in git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
}

# Main function
main() {
    if [ $# -lt 1 ]; then
        error "Issue number is required"
        show_usage
        exit 1
    fi
    
    validate_prerequisites
    
    local issue_number="$1"
    local branch_name="${2:-$(get_current_branch)}"
    local custom_title="$3"
    local body_file="$4"
    
    # Validate issue number
    if ! [[ "$issue_number" =~ ^[0-9]+$ ]]; then
        error "Issue number must be a positive integer"
        exit 1
    fi
    
    # Get issue analysis
    local analysis_file
    analysis_file=$(get_issue_info "$issue_number")
    
    info "Creating PR for issue #$issue_number on branch $branch_name"
    
    # Generate or use provided title
    local pr_title
    if [ -n "$custom_title" ]; then
        pr_title="$custom_title"
    else
        pr_title=$(generate_pr_title "$issue_number" "$analysis_file")
    fi
    
    # Generate or use provided body
    local pr_body
    if [ -n "$body_file" ] && [ -f "$body_file" ]; then
        pr_body=$(cat "$body_file")
    else
        pr_body=$(generate_pr_body "$issue_number" "$analysis_file" "$branch_name")
    fi
    
    info "PR Title: $pr_title"
    
    # Push current branch if it has commits
    local commits_ahead=$(git rev-list --count main..HEAD 2>/dev/null || echo "0")
    if [ "$commits_ahead" -gt 0 ]; then
        info "Pushing $commits_ahead commit(s) to remote..."
        git push origin "$branch_name"
    else
        warn "No commits ahead of main branch"
    fi
    
    # Create the pull request
    create_pull_request "$issue_number" "$branch_name" "$pr_title" "$pr_body"
}

# Run main function with all arguments
main "$@"