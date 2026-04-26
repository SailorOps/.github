#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# ⚓ Still Systems Brand Asset Sync Engine
# ──────────────────────────────────────────────────────────────
# Orchestrates the synchronization of branding files across
# organization repositories.
# ──────────────────────────────────────────────────────────────

set -e

# Configuration & Defaults
ORG="stillsystems"
SOURCE_DIR="brand"
TARGET_PATH="${TARGET_PATH:-.github/brand}"
SYNC_MODE="${SYNC_MODE:-pr}"
PR_BRANCH="${PR_BRANCH:-stillsystems/sync-brand-assets}"
EXCLUDE_REPOS="${EXCLUDE_REPOS:-.github}"
DRY_RUN="${DRY_RUN:-false}"
COMMIT_MSG="⚓ sync: update brand assets from .github / Automated brand asset synchronization by Still Systems."

# Helpers
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; }

# 1. Identify Target Repositories
log_info "Identifying target repositories in @$ORG..."

if [ -n "$TARGET_REPO" ]; then
    REPOS="$ORG/$TARGET_REPO"
    log_info "Targeting single repository: $REPOS"
else
    # Fetch all non-archived repositories in the organization
    QUERY="org:$ORG"
    [ "$SKIP_ARCHIVED" = "true" ] && QUERY="$QUERY archived:false"
    [ "$SKIP_FORKS" = "true" ] && QUERY="$QUERY fork:false"
    
    REPOS=$(gh repo list "$ORG" --json fullName --jq '.[].fullName' --limit 200)
    
    # Filter excludes
    IFS=',' read -ra ADDR <<< "$EXCLUDE_REPOS"
    for EXCLUDE in "${ADDR[@]}"; do
        REPOS=$(echo "$REPOS" | grep -v "$ORG/$EXCLUDE" || true)
    done
fi

REPO_COUNT=$(echo "$REPOS" | wc -w)
log_info "Found $REPO_COUNT potential repositories to sync"

# 2. Iterate and Sync
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

for REPO in $REPOS; do
    log_info "Processing $REPO..."
    
    # Clone and Prepare
    CLONE_DIR="$TEMP_DIR/${REPO#*/}"
    rm -rf "$CLONE_DIR"
    
    if ! gh repo clone "$REPO" "$CLONE_DIR" -- --depth 1 --quiet; then
        log_warn "Could not clone $REPO, skipping..."
        continue
    fi
    
    cd "$CLONE_DIR"
    
    # Update files
    mkdir -p "$TARGET_PATH"
    cp -r "$GITHUB_WORKSPACE/$SOURCE_DIR/." "$TARGET_PATH/"
    
    # Check for changes
    if [ -z "$(git status --porcelain)" ]; then
        log_info "No changes detected for $REPO."
        cd - > /dev/null
        continue
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log_success "[DRY-RUN] Would sync brand assets to $REPO"
        cd - > /dev/null
        continue
    fi
    
    # Git Setup
    git config user.name "Still Systems Bot"
    git config user.email "bot@stillsystems.io"
    
    if [ "$SYNC_MODE" = "direct" ]; then
        log_info "Pushing changes directly to $REPO..."
        git add .
        git commit -m "$COMMIT_MSG"
        git push origin "$(git branch --show-current)"
        log_success "Synced $REPO (Direct Push)"
    else
        log_info "Creating Pull Request for $REPO..."
        git checkout -b "$PR_BRANCH"
        git add .
        git commit -m "$COMMIT_MSG"
        
        # Force push branch to ensure latest assets are used
        git push origin "$PR_BRANCH" --force
        
        # Create PR if one doesn't exist
        if ! gh pr view "$PR_BRANCH" >/dev/null 2>&1; then
            gh pr create \
                --title "⚓ Sync brand assets from Still Systems" \
                --body "## Brand Asset Synchronization
This automated PR synchronizes brand assets from the central [.github](https://github.com/stillsystems/.github) repository.

### Changes
- Updated branding files in \`$TARGET_PATH\`
- Ensured visual consistency across the @$ORG workshop

*Automated by Still Systems Brand Sync*
---
⚓ **Still Systems** — Tools engineered for real-world conditions." \
                --label "brand-sync"
            log_success "Created PR for $REPO"
        else
            log_info "PR already exists for $REPO, branch updated."
        fi
    fi
    
    cd - > /dev/null
done

log_success "Brand asset synchronization complete."
