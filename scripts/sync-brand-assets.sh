#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# ⚓ SailorOps Brand Asset Sync Engine
# ──────────────────────────────────────────────────────────────
# Detects brand asset changes and distributes them to all org
# repositories via PR or direct push. Produces a summary report.
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors & formatting ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}⚓${NC} $*" >&2; }
ok()    { echo -e "${GREEN}✓${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}⚠${NC} $*" >&2; }
err()   { echo -e "${RED}✗${NC} $*" >&2; }

# ── Environment validation ──
# ── Configuration parsing ──
CONFIG_FILE="brand-sync.yml"

get_config_val() {
  local key="$1"
  if [ -f "$CONFIG_FILE" ]; then
    # Very basic YAML parser for simple key-value pairs
    grep -E "^\s*${key}:" "$CONFIG_FILE" | head -n1 | cut -d':' -f2- | xargs || echo ""
  else
    echo ""
  fi
}

if [ -z "${GH_TOKEN:-}" ]; then
  err "GH_TOKEN is not set."
  log "For cross-repository synchronization, a Personal Access Token (PAT) with 'repo' and 'read:org' scopes is required."
  log "Please add GORELEASER_TOKEN to your GitHub secrets."
  exit 1
fi
: "${TARGET_PATH:=$(get_config_val "target_path" || echo ".github/brand")}"
: "${SYNC_MODE:=$(get_config_val "mode" || echo "pr")}"
: "${PR_BRANCH:=$(get_config_val "pr_branch" || echo "sailorops/sync-brand-assets")}"
: "${DRY_RUN:=false}"
: "${EXCLUDE_REPOS:=$(get_config_val "exclude" || echo ".github")}"
: "${SKIP_ARCHIVED:=$(get_config_val "skip_archived" || echo "true")}"
: "${SKIP_FORKS:=$(get_config_val "skip_forks" || echo "true")}"
: "${TARGET_REPO:=}"

# Fix for the exclude list which might be a multi-line YAML array
if [ -f "$CONFIG_FILE" ]; then
  EXCLUDES_RAW=$(sed -n '/exclude:/,$p' "$CONFIG_FILE" | grep -E "^\s*-\s" | sed 's/^\s*-\s*//' | tr '\n' ',' | sed 's/,$//')
  [ -n "$EXCLUDES_RAW" ] && EXCLUDE_REPOS="$EXCLUDES_RAW"
fi

BRAND_DIR="brand"
WORK_DIR=$(mktemp -d)
SUMMARY_FILE=$(mktemp)
REPORT_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

# Counters for the summary
SYNCED=0
SKIPPED=0
FAILED=0
UP_TO_DATE=0

trap 'rm -rf "$WORK_DIR"' EXIT

# ──────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────

# Compute SHA256 manifest of a directory (for diffing)
manifest() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -type f -not -name '.gitkeep' -exec sha256sum {} \; | \
      sed "s|$dir/||" | sort -k2
  fi
}

# Get the org name from GITHUB_REPOSITORY
get_org() {
  echo "${GITHUB_REPOSITORY%%/*}"
}

# Check if a repo is in the exclusion list
is_excluded() {
  local repo_name="$1"
  IFS=',' read -ra EXCLUDES <<< "$EXCLUDE_REPOS"
  for exclude in "${EXCLUDES[@]}"; do
    exclude=$(echo "$exclude" | xargs)  # trim whitespace
    if [[ "$repo_name" == "$exclude" ]]; then
      return 0
    fi
  done
  return 1
}

# List all repos in the org via GitHub API
list_org_repos() {
  local org="$1"
  local page=1
  local per_page=100

  log "Listing repos for org: $org"
  while true; do
    local response
    set +e
    response=$(gh api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/orgs/${org}/repos?per_page=${per_page}&page=${page}&type=all")
    local exit_code=$?
    set -e
    
    if [ $exit_code -ne 0 ]; then
      err "gh api failed with exit code $exit_code"
      err "Response: $response"
      return 1
    fi

    local count
    count=$(echo "$response" | jq 'length')
    [ "$count" -eq 0 ] && break

    echo "$response" | jq -r '.[] | [
      .name,
      .archived,
      .fork,
      .default_branch,
      .clone_url
    ] | @tsv'

    [ "$count" -lt "$per_page" ] && break
    ((page++))
  done
}

# ──────────────────────────────────────────────────────────────
# Sync a single repository
# ──────────────────────────────────────────────────────────────
sync_repo() {
  local repo_name="$1"
  local default_branch="$2"
  local clone_url="$3"
  local org="$4"
  local full_name="${org}/${repo_name}"

  log "Processing ${full_name}..."

  # Clone the target repo
  local repo_dir="${WORK_DIR}/${repo_name}"
  local auth_url="https://x-access-token:${GH_TOKEN}@github.com/${full_name}.git"

  if ! git clone --depth 1 --branch "$default_branch" "$auth_url" "$repo_dir" 2>/dev/null; then
    err "Failed to clone ${full_name}"
    echo "| ${full_name} | ❌ Clone failed | - |" >> "$SUMMARY_FILE"
    ((FAILED++))
    return 1
  fi

  # Create target directory if needed
  mkdir -p "${repo_dir}/${TARGET_PATH}"

  # Generate manifests for comparison
  local source_manifest target_manifest
  source_manifest=$(manifest "$BRAND_DIR")
  target_manifest=$(manifest "${repo_dir}/${TARGET_PATH}")

  # Compare
  if [ "$source_manifest" = "$target_manifest" ]; then
    ok "${full_name} is already up to date"
    echo "| ${full_name} | ✅ Up to date | - |" >> "$SUMMARY_FILE"
    ((UP_TO_DATE++))
    rm -rf "$repo_dir"
    return 0
  fi

  # Determine changed files
  local changes
  changes=$(diff <(echo "$source_manifest") <(echo "$target_manifest") || true)
  local change_count
  change_count=$(echo "$changes" | grep -c '^[<>]' || echo 0)

  log "  → ${change_count} file difference(s) detected"

  # Dry run — report but don't push
  if [ "$DRY_RUN" = "true" ]; then
    warn "[DRY RUN] Would sync ${change_count} file(s) to ${full_name}"
    echo "| ${full_name} | 🔍 Dry run — ${change_count} change(s) | - |" >> "$SUMMARY_FILE"
    ((SKIPPED++))
    rm -rf "$repo_dir"
    return 0
  fi

  # ── Apply changes ──
  # Clear old assets and copy fresh set
  rm -rf "${repo_dir:?}/${TARGET_PATH:?}"/*
  cp -r "${BRAND_DIR}/"* "${repo_dir}/${TARGET_PATH}/"

  cd "$repo_dir"

  git add "${TARGET_PATH}/"
  COMMIT_MSG="⚓ sync: update brand assets from .github

Automated brand asset synchronization by SailorOps.
Source: ${GITHUB_REPOSITORY}@${GITHUB_SHA:0:7}
Trigger: ${GITHUB_EVENT_NAME}
Changes: ${change_count} file(s) updated"

  git commit -m "$COMMIT_MSG" --allow-empty-message

  if [ "$SYNC_MODE" = "pr" ]; then
    # ── PR mode: push to a branch and open/update PR ──
    git checkout -B "$PR_BRANCH"
    git push --force origin "$PR_BRANCH"

    # Check for existing PR
    local existing_pr
    existing_pr=$(gh pr list \
      --repo "$full_name" \
      --head "$PR_BRANCH" \
      --state open \
      --json number \
      --jq '.[0].number // empty' || echo "")

    if [ -n "$existing_pr" ]; then
      gh pr comment "$existing_pr" \
        --repo "$full_name" \
        --body "🔄 Brand assets updated — ${change_count} file(s) changed.
Source commit: ${GITHUB_REPOSITORY}@\`${GITHUB_SHA:0:7}\`"
      ok "${full_name} — updated PR #${existing_pr}"
      echo "| ${full_name} | 🔄 Updated PR #${existing_pr} | ${change_count} |" >> "$SUMMARY_FILE"
    else
      local pr_url
      pr_url=$(gh pr create \
        --repo "$full_name" \
        --head "$PR_BRANCH" \
        --base "$default_branch" \
        --title "⚓ Sync brand assets from SailorOps" \
        --body "## ⚓ Brand Asset Sync

This PR updates brand assets from the central \`.github\` repository.

**Source:** \`${GITHUB_REPOSITORY}@${GITHUB_SHA:0:7}\`
**Changes:** ${change_count} file(s) updated
**Trigger:** \`${GITHUB_EVENT_NAME}\`

### What changed
These brand assets ensure visual consistency across the SailorOps ecosystem.
Review the changes below and merge when ready.

---
*Automated by [SailorOps Brand Sync](https://github.com/${GITHUB_REPOSITORY})*" \
        --label "brand-sync" || echo "")

      if [ -n "$pr_url" ]; then
        ok "${full_name} — opened new PR"
        echo "| ${full_name} | 🆕 Opened PR | ${change_count} |" >> "$SUMMARY_FILE"
      else
        # Retry without label (it may not exist yet)
        pr_url=$(gh pr create \
          --repo "$full_name" \
          --head "$PR_BRANCH" \
          --base "$default_branch" \
          --title "⚓ Sync brand assets from SailorOps" \
          --body "## ⚓ Brand Asset Sync

This PR updates brand assets from the central \`.github\` repository.

**Source:** \`${GITHUB_REPOSITORY}@${GITHUB_SHA:0:7}\`
**Changes:** ${change_count} file(s) updated

---
*Automated by SailorOps Brand Sync*" || echo "FAILED")

        if [ "$pr_url" != "FAILED" ]; then
          ok "${full_name} — opened new PR (no label)"
          echo "| ${full_name} | 🆕 Opened PR | ${change_count} |" >> "$SUMMARY_FILE"
        else
          err "${full_name} — failed to create PR"
          echo "| ${full_name} | ❌ PR creation failed | ${change_count} |" >> "$SUMMARY_FILE"
          ((FAILED++))
          cd - > /dev/null
          rm -rf "$repo_dir"
          return 1
        fi
      fi
    fi
  else
    # ── Direct mode: push straight to default branch ──
    if git push origin "$default_branch" 2>/dev/null; then
      ok "${full_name} — pushed directly to ${default_branch}"
      echo "| ${full_name} | 📤 Direct push | ${change_count} |" >> "$SUMMARY_FILE"
    else
      err "${full_name} — direct push failed"
      echo "| ${full_name} | ❌ Push failed | ${change_count} |" >> "$SUMMARY_FILE"
      ((FAILED++))
      cd - > /dev/null
      rm -rf "$repo_dir"
      return 1
    fi
  fi

  ((SYNCED++))
  cd - > /dev/null
  rm -rf "$repo_dir"
  return 0
}

# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────
main() {
  local org
  org=$(get_org)
  
  # Configure Git identity for commits
  git config --global user.name "SailorOps Bot"
  git config --global user.email "bot@sailorops.io"
  git config --global init.defaultBranch main

  echo ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "  SailorOps Brand Asset Sync"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "  Org:         ${org}"
  log "  Source:      ${BRAND_DIR}/"
  log "  Target:      ${TARGET_PATH}/"
  log "  Mode:        ${SYNC_MODE}"
  log "  Dry run:     ${DRY_RUN}"
  log "  Excludes:    ${EXCLUDE_REPOS}"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Initialize summary table header
  echo "| Repository | Status | Changes |" >> "$SUMMARY_FILE"
  echo "|------------|--------|---------|" >> "$SUMMARY_FILE"

  # Single repo mode
  if [ -n "$TARGET_REPO" ]; then
    log "Single-repo mode: syncing to ${TARGET_REPO} only"

    local default_branch
    default_branch=$(gh api "/repos/${org}/${TARGET_REPO}" --jq '.default_branch' 2>/dev/null) || {
      err "Cannot fetch repo info for ${TARGET_REPO}"
      exit 1
    }

    sync_repo "$TARGET_REPO" "$default_branch" "" "$org"
  else
    # Full org sync
    log "Discovering repositories in ${org}..."

    while IFS=$'\t' read -r name archived fork default_branch clone_url; do
      # Skip exclusions
      if is_excluded "$name"; then
        warn "Skipping ${name} (excluded)"
        echo "| ${org}/${name} | ⏭ Excluded | - |" >> "$SUMMARY_FILE"
        ((SKIPPED++)) || true
        continue
      fi

      # Skip archived repos
      if [ "$SKIP_ARCHIVED" = "true" ] && [ "$archived" = "true" ]; then
        warn "Skipping ${name} (archived)"
        echo "| ${org}/${name} | ⏭ Archived | - |" >> "$SUMMARY_FILE"
        ((SKIPPED++)) || true
        continue
      fi

      # Skip forks
      if [ "$SKIP_FORKS" = "true" ] && [ "$fork" = "true" ]; then
        warn "Skipping ${name} (fork)"
        echo "| ${org}/${name} | ⏭ Fork | - |" >> "$SUMMARY_FILE"
        ((SKIPPED++)) || true
        continue
      fi

      sync_repo "$name" "$default_branch" "$clone_url" "$org" || true
    done < <(list_org_repos "$org")
  fi

  # ── Summary Report ──
  echo ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "  Sync Complete"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  ok  "  Synced:      ${SYNCED}"
  log "  Up to date:  ${UP_TO_DATE}"
  warn "  Skipped:     ${SKIPPED}"
  [ "$FAILED" -gt 0 ] && err "  Failed:      ${FAILED}"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Write GitHub Actions Job Summary
  {
    echo "## ⚓ SailorOps Brand Asset Sync Report"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| ✅ Synced | ${SYNCED} |"
    echo "| 🟢 Up to date | ${UP_TO_DATE} |"
    echo "| ⏭ Skipped | ${SKIPPED} |"
    echo "| ❌ Failed | ${FAILED} |"
    echo ""
    echo "### Details"
    echo ""
    cat "$SUMMARY_FILE"
    echo ""
    echo "---"
    echo "*Source: \`${GITHUB_REPOSITORY}@${GITHUB_SHA:0:7}\` · Trigger: \`${GITHUB_EVENT_NAME}\` · Mode: \`${SYNC_MODE}\`*"
  } >> "$REPORT_FILE"

  # Fail the workflow if any repos failed
  if [ "$FAILED" -gt 0 ]; then
    err "Sync completed with ${FAILED} failure(s)"
    exit 1
  fi

  ok "All repositories synced successfully"
}

main "$@"
