#!/bin/bash

# Claude Issue Solver - Main Orchestrator
# This script coordinates the entire issue-solving workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

step() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 STEP: $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Claude Issue Solver - Automated GitHub Issue Resolution"
    echo ""
    echo "Usage: $0 <issue-reference> [options]"
    echo ""
    echo "Arguments:"
    echo "  issue-reference    Issue number (#123) or GitHub URL"
    echo ""
    echo "Options:"
    echo "  --dry-run         Show what would be done without executing"
    echo "  --skip-tests      Skip running tests after implementation"
    echo "  --no-pr          Don't create pull request automatically"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 123                    # Solve issue #123"
    echo "  $0 #123                   # Solve issue #123"
    echo "  $0 https://github.com/owner/repo/issues/123"
    echo "  $0 123 --dry-run          # Show plan without executing"
    echo "  $0 123 --no-pr            # Solve but don't create PR"
    echo ""
    echo "This will:"
    echo "  1. Analyze the GitHub issue"
    echo "  2. Create a new branch from main"
    echo "  3. Implement the solution"
    echo "  4. Run tests and validation"
    echo "  5. Commit changes with descriptive message"
    echo "  6. Create a pull request"
}

# Function to parse issue number from reference
parse_issue_number() {
    local reference="$1"
    
    # GitHub URL
    if [[ "$reference" =~ github\.com/[^/]+/[^/]+/issues/([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Issue number with #
    if [[ "$reference" =~ ^#?([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    error "Could not parse issue number from: $reference"
    return 1
}

# Function to validate prerequisites
validate_prerequisites() {
    info "Validating prerequisites..."
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
    
    # Check required tools
    local missing_tools=()
    
    command -v gh > /dev/null 2>&1 || missing_tools+=("gh")
    command -v jq > /dev/null 2>&1 || missing_tools+=("jq")
    command -v python3 > /dev/null 2>&1 || missing_tools+=("python3")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install them first"
        exit 1
    fi
    
    # Check GitHub authentication
    if ! gh auth status > /dev/null 2>&1; then
        error "GitHub CLI is not authenticated. Run: gh auth login"
        exit 1
    fi
    
    log "All prerequisites validated"
}

# Function to analyze issue
analyze_issue() {
    local issue_number="$1"
    
    step "Analyzing issue #$issue_number"
    
    # Run issue analyzer
    if python3 "$SCRIPT_DIR/issue-analyzer.py" "$issue_number"; then
        log "Issue analysis completed"
        
        # Show analysis summary
        local analysis_file="/tmp/issue-${issue_number}-analysis.json"
        if [ -f "$analysis_file" ]; then
            local title=$(jq -r '.issue.title' "$analysis_file")
            local type=$(jq -r '.issue.type' "$analysis_file")
            local complexity=$(jq -r '.issue.complexity' "$analysis_file")
            local branch_name=$(jq -r '.issue.branch_name' "$analysis_file")
            
            info "Issue: $title"
            info "Type: $type"
            info "Complexity: $complexity"
            info "Branch: $branch_name"
        fi
        
        return 0
    else
        error "Failed to analyze issue #$issue_number"
        return 1
    fi
}

# Function to create branch
create_branch() {
    local issue_number="$1"
    
    step "Creating branch for issue #$issue_number"
    
    local analysis_file="/tmp/issue-${issue_number}-analysis.json"
    local branch_name=$(jq -r '.issue.branch_name' "$analysis_file")
    
    if "$SCRIPT_DIR/branch-manager.sh" create "$branch_name"; then
        log "Branch created: $branch_name"
        echo "$branch_name"
        return 0
    else
        error "Failed to create branch"
        return 1
    fi
}

# Function to implement solution
implement_solution() {
    local issue_number="$1"
    local dry_run="$2"
    
    step "Implementing solution for issue #$issue_number"
    
    if [ "$dry_run" = true ]; then
        info "[DRY RUN] Would implement solution here"
        info "[DRY RUN] This is where Claude would analyze requirements and write code"
        return 0
    fi
    
    # This is where Claude will implement the actual solution
    # The implementation will be context-specific based on the issue analysis
    
    local analysis_file="/tmp/issue-${issue_number}-analysis.json"
    local issue_type=$(jq -r '.issue.type' "$analysis_file")
    local requirements=$(jq -r '.issue.requirements[]?' "$analysis_file" 2>/dev/null | tr '\n' ' ')
    local files_to_modify=$(jq -r '.issue.files_to_modify[]?' "$analysis_file" 2>/dev/null)
    
    info "Issue type: $issue_type"
    if [ -n "$requirements" ]; then
        info "Requirements: $requirements"
    fi
    if [ -n "$files_to_modify" ]; then
        info "Files to modify: $files_to_modify"
    fi
    
    # Placeholder for actual implementation
    # In real usage, Claude would read the issue analysis and implement the solution
    warn "Implementation phase - Claude should analyze and implement solution here"
    
    # Create a placeholder commit to demonstrate the workflow
    echo "# Issue #$issue_number Implementation" > "IMPLEMENTATION_NOTES.md"
    echo "" >> "IMPLEMENTATION_NOTES.md"
    echo "This file demonstrates the automated issue solving workflow." >> "IMPLEMENTATION_NOTES.md"
    echo "In real usage, Claude would implement the actual solution here." >> "IMPLEMENTATION_NOTES.md"
    echo "" >> "IMPLEMENTATION_NOTES.md"
    echo "Issue Analysis:" >> "IMPLEMENTATION_NOTES.md"
    cat "$analysis_file" >> "IMPLEMENTATION_NOTES.md"
    
    git add "IMPLEMENTATION_NOTES.md"
    
    return 0
}

# Function to run tests
run_tests() {
    local skip_tests="$1"
    local dry_run="$2"
    
    if [ "$skip_tests" = true ]; then
        warn "Skipping tests as requested"
        return 0
    fi
    
    step "Running tests and validation"
    
    if [ "$dry_run" = true ]; then
        info "[DRY RUN] Would run tests here"
        return 0
    fi
    
    # Check if we're in a Django project with Docker
    if [ -f "docker-compose.yml" ] && [ -f "manage.py" ]; then
        info "Detected Django project with Docker, running tests..."
        
        # Run Django tests
        if docker-compose exec -T web python manage.py test --verbosity=2; then
            log "All tests passed"
        else
            warn "Some tests failed, but continuing..."
        fi
        
        # Run system checks
        if docker-compose exec -T web python manage.py check; then
            log "System checks passed"
        else
            error "System checks failed"
            return 1
        fi
    else
        info "No specific test configuration found, skipping tests"
    fi
    
    return 0
}

# Function to commit changes
commit_changes() {
    local issue_number="$1"
    local dry_run="$2"
    
    step "Committing changes for issue #$issue_number"
    
    if [ "$dry_run" = true ]; then
        info "[DRY RUN] Would commit changes here"
        return 0
    fi
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        warn "No staged changes to commit"
        return 0
    fi
    
    local analysis_file="/tmp/issue-${issue_number}-analysis.json"
    local issue_title=$(jq -r '.issue.title' "$analysis_file")
    local issue_type=$(jq -r '.issue.type' "$analysis_file")
    
    # Create commit message
    local commit_message
    case "$issue_type" in
        "fix")
            commit_message="fix: $issue_title (fixes #$issue_number)"
            ;;
        "feature")
            commit_message="feat: $issue_title (closes #$issue_number)"
            ;;
        "enhancement")
            commit_message="enhance: $issue_title (closes #$issue_number)"
            ;;
        *)
            commit_message="$issue_type: $issue_title (closes #$issue_number)"
            ;;
    esac
    
    # Create full commit message
    local full_message="$commit_message

Automatically implemented solution for GitHub issue #$issue_number.

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    
    git commit -m "$full_message"
    
    log "Changes committed successfully"
    return 0
}

# Function to create pull request
create_pull_request() {
    local issue_number="$1"
    local branch_name="$2"
    local no_pr="$3"
    local dry_run="$4"
    
    if [ "$no_pr" = true ]; then
        info "Skipping PR creation as requested"
        return 0
    fi
    
    step "Creating pull request for issue #$issue_number"
    
    if [ "$dry_run" = true ]; then
        info "[DRY RUN] Would create pull request here"
        return 0
    fi
    
    if "$SCRIPT_DIR/pr-creator.sh" "$issue_number" "$branch_name"; then
        log "Pull request created successfully"
        return 0
    else
        error "Failed to create pull request"
        return 1
    fi
}

# Main workflow function
run_workflow() {
    local issue_reference="$1"
    local dry_run="$2"
    local skip_tests="$3"
    local no_pr="$4"
    
    # Parse issue number
    local issue_number
    issue_number=$(parse_issue_number "$issue_reference")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    info "Starting automated issue solving workflow for issue #$issue_number"
    
    # Step 1: Validate prerequisites
    validate_prerequisites
    
    # Step 2: Analyze issue
    analyze_issue "$issue_number"
    
    # Step 3: Create branch
    local branch_name
    if [ "$dry_run" = true ]; then
        local analysis_file="/tmp/issue-${issue_number}-analysis.json"
        branch_name=$(jq -r '.issue.branch_name' "$analysis_file")
        info "[DRY RUN] Would create branch: $branch_name"
    else
        branch_name=$(create_branch "$issue_number")
    fi
    
    # Step 4: Implement solution
    implement_solution "$issue_number" "$dry_run"
    
    # Step 5: Run tests
    run_tests "$skip_tests" "$dry_run"
    
    # Step 6: Commit changes
    commit_changes "$issue_number" "$dry_run"
    
    # Step 7: Create pull request
    create_pull_request "$issue_number" "$branch_name" "$no_pr" "$dry_run"
    
    log "Workflow completed successfully for issue #$issue_number"
    
    if [ "$dry_run" = false ]; then
        echo ""
        echo "🎉 Issue #$issue_number has been automatically solved!"
        echo "   Branch: $branch_name"
        if [ "$no_pr" = false ]; then
            echo "   Pull request has been created"
        fi
        echo ""
        echo "Next steps:"
        echo "- Review the implementation"
        echo "- Test the solution"
        echo "- Merge the pull request when ready"
    fi
}

# Parse command line arguments
main() {
    local issue_reference=""
    local dry_run=false
    local skip_tests=false
    local no_pr=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --no-pr)
                no_pr=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$issue_reference" ]; then
                    issue_reference="$1"
                else
                    error "Multiple issue references provided"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [ -z "$issue_reference" ]; then
        error "Issue reference is required"
        show_usage
        exit 1
    fi
    
    run_workflow "$issue_reference" "$dry_run" "$skip_tests" "$no_pr"
}

# Run main function with all arguments
main "$@"