#!/bin/bash

# Claude Branch Manager
# Manages git branches for automated issue solving

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
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  create <branch-name>     Create new branch from main"
    echo "  switch <branch-name>     Switch to existing branch"
    echo "  cleanup <branch-name>    Delete branch locally and remotely"
    echo "  sync                     Sync with remote main branch"
    echo "  status                   Show current branch status"
    echo ""
    echo "Examples:"
    echo "  $0 create feature/issue-123-add-user-avatar"
    echo "  $0 switch feature/issue-123-add-user-avatar"
    echo "  $0 cleanup feature/issue-123-add-user-avatar"
    echo "  $0 sync"
    echo "  $0 status"
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not in a git repository"
        exit 1
    fi
}

# Function to check if branch exists locally
branch_exists_local() {
    local branch="$1"
    git show-ref --verify --quiet "refs/heads/$branch"
}

# Function to check if branch exists on remote
branch_exists_remote() {
    local branch="$1"
    git ls-remote --exit-code --heads origin "$branch" > /dev/null 2>&1
}

# Function to get current branch
get_current_branch() {
    git branch --show-current
}

# Function to check if working directory is clean
is_working_dir_clean() {
    git diff-index --quiet HEAD --
}

# Function to sync with main branch
sync_with_main() {
    info "Syncing with main branch..."
    
    local current_branch=$(get_current_branch)
    
    # Stash changes if working directory is not clean
    local stash_created=false
    if ! is_working_dir_clean; then
        warn "Working directory not clean, stashing changes..."
        git stash push -m "claude-automation: temporary stash before sync"
        stash_created=true
    fi
    
    # Switch to main and pull latest
    git checkout main
    git pull origin main
    
    # Switch back to original branch if not main
    if [ "$current_branch" != "main" ] && [ "$current_branch" != "" ]; then
        git checkout "$current_branch"
        
        # Pop stash if we created one
        if [ "$stash_created" = true ]; then
            info "Restoring stashed changes..."
            git stash pop
        fi
    fi
    
    log "Successfully synced with main branch"
}

# Function to create new branch
create_branch() {
    local branch_name="$1"
    
    if [ -z "$branch_name" ]; then
        error "Branch name is required"
        show_usage
        exit 1
    fi
    
    info "Creating branch: $branch_name"
    
    # Check if branch already exists
    if branch_exists_local "$branch_name"; then
        error "Branch '$branch_name' already exists locally"
        exit 1
    fi
    
    if branch_exists_remote "$branch_name"; then
        error "Branch '$branch_name' already exists on remote"
        exit 1
    fi
    
    # Ensure we're synced with main
    sync_with_main
    
    # Create and checkout new branch
    git checkout -b "$branch_name"
    
    log "Created and switched to branch: $branch_name"
    
    # Push branch to remote
    git push -u origin "$branch_name"
    
    log "Branch pushed to remote with upstream tracking"
}

# Function to switch to existing branch
switch_branch() {
    local branch_name="$1"
    
    if [ -z "$branch_name" ]; then
        error "Branch name is required"
        show_usage
        exit 1
    fi
    
    info "Switching to branch: $branch_name"
    
    # Check if working directory is clean
    if ! is_working_dir_clean; then
        error "Working directory not clean. Please commit or stash changes first."
        exit 1
    fi
    
    # If branch exists locally, just switch
    if branch_exists_local "$branch_name"; then
        git checkout "$branch_name"
        
        # Pull latest changes if tracking remote
        if git rev-parse --verify "$branch_name@{upstream}" > /dev/null 2>&1; then
            git pull
        fi
    elif branch_exists_remote "$branch_name"; then
        # Branch exists on remote but not locally, fetch and checkout
        git fetch origin "$branch_name"
        git checkout -b "$branch_name" "origin/$branch_name"
    else
        error "Branch '$branch_name' does not exist locally or on remote"
        exit 1
    fi
    
    log "Switched to branch: $branch_name"
}

# Function to cleanup branch
cleanup_branch() {
    local branch_name="$1"
    
    if [ -z "$branch_name" ]; then
        error "Branch name is required"
        show_usage
        exit 1
    fi
    
    # Don't allow deleting main or current branch
    if [ "$branch_name" = "main" ] || [ "$branch_name" = "master" ]; then
        error "Cannot delete main/master branch"
        exit 1
    fi
    
    local current_branch=$(get_current_branch)
    if [ "$current_branch" = "$branch_name" ]; then
        info "Switching to main branch first..."
        git checkout main
    fi
    
    info "Cleaning up branch: $branch_name"
    
    # Delete local branch if it exists
    if branch_exists_local "$branch_name"; then
        git branch -D "$branch_name"
        log "Deleted local branch: $branch_name"
    fi
    
    # Delete remote branch if it exists
    if branch_exists_remote "$branch_name"; then
        git push origin --delete "$branch_name"
        log "Deleted remote branch: $branch_name"
    fi
    
    log "Branch cleanup completed: $branch_name"
}

# Function to show branch status
show_status() {
    info "Branch Status"
    echo ""
    
    local current_branch=$(get_current_branch)
    echo "Current branch: $current_branch"
    
    if [ "$current_branch" != "" ]; then
        # Check if tracking remote
        if git rev-parse --verify "$current_branch@{upstream}" > /dev/null 2>&1; then
            local upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}")
            echo "Upstream: $upstream"
            
            # Check ahead/behind status
            local ahead=$(git rev-list --count HEAD.."$upstream" 2>/dev/null || echo "0")
            local behind=$(git rev-list --count "$upstream"..HEAD 2>/dev/null || echo "0")
            
            if [ "$ahead" -gt 0 ]; then
                echo "Behind upstream: $ahead commits"
            fi
            if [ "$behind" -gt 0 ]; then
                echo "Ahead of upstream: $behind commits"
            fi
            if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
                echo "Up to date with upstream"
            fi
        else
            echo "No upstream tracking branch"
        fi
    fi
    
    # Working directory status
    if is_working_dir_clean; then
        echo "Working directory: clean"
    else
        echo "Working directory: has changes"
        git status --porcelain
    fi
    
    echo ""
    echo "Recent branches:"
    git for-each-ref --count=5 --sort=-committerdate refs/heads/ --format='%(refname:short) (%(committerdate:relative))'
}

# Main script logic
main() {
    check_git_repo
    
    local command="$1"
    shift
    
    case "$command" in
        "create")
            create_branch "$@"
            ;;
        "switch")
            switch_branch "$@"
            ;;
        "cleanup")
            cleanup_branch "$@"
            ;;
        "sync")
            sync_with_main
            ;;
        "status")
            show_status
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"