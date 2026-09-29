#!/usr/bin/env sh
set -euo pipefail

# release.sh — Bump version, commit, tag, and push a new release.
#
# Usage:
#   ./release.sh [patch|minor|major] [--dry-run]
#
# Requirements:
#   - Must be run from the repository root
#   - Working tree must be clean
#   - Must be on the main branch
#   - Remote 'origin' must exist

VERSION_FILE=".VERSION"
BRANCH="main"
TAG_PREFIX="v"

die()      { printf "release.sh: error: %s\n" "$*" >&2; exit 1; }
warn()     { printf "release.sh: warning: %s\n" "$*" >&2; }
info()     { printf "release.sh: %s\n" "$*"; }

# ── Argument parsing ────────────────────────────────────────────────────────
BUMP_TYPE="patch"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    patch|minor|major) BUMP_TYPE="$1"; shift ;;
    --dry-run)         DRY_RUN=1;     shift ;;
    *)                 die "Unknown argument: $1 (usage: $0 [patch|minor|major] [--dry-run])" ;;
  esac
done

# ── Environment validation ──────────────────────────────────────────────────

[ -d ".git" ] || die "Not a git repository (no .git directory found)."

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$CURRENT_BRANCH" = "$BRANCH" ] \
  || die "Must be on '$BRANCH' branch (currently on '$CURRENT_BRANCH')."

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  die "Working tree is dirty. Commit or stash your changes first."
fi

git remote get-url origin >/dev/null 2>&1 \
  || die "Remote 'origin' not found."

# ── Read current version ────────────────────────────────────────────────────

[ -f "$VERSION_FILE" ] \
  || die "$VERSION_FILE not found. Run the release script from the repository root."

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)

# Validate semver components are numeric
for _num in $MAJOR $MINOR $PATCH; do
  case "$_num" in
    *[!0-9]*) die "Invalid version component: '$_num'" ;;
  esac
done

# ── Compute new version ─────────────────────────────────────────────────────

case "$BUMP_TYPE" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_TAG="${TAG_PREFIX}${NEW_VERSION}"

# ── Dry-run mode (no changes at all) ────────────────────────────────────────

if [ "$DRY_RUN" = "1" ]; then
  info "Current version : $CURRENT_VERSION"
  info "Bump type       : $BUMP_TYPE"
  info "New version     : $NEW_VERSION"
  info "Tag             : $NEW_TAG"
  info "Files to update : .VERSION, install.sh, README.md"
  exit 0
fi

# ── Enforce immutability: refuse to overwrite existing tags ─────────────────

if git tag -l | grep -qx "$NEW_TAG"; then
  die "Tag '$NEW_TAG' already exists. Releases are immutable — use a different bump type."
fi

# ── Update .VERSION ─────────────────────────────────────────────────────────

printf '%s\n' "$NEW_VERSION" > "$VERSION_FILE"
info "Updated $VERSION_FILE: $CURRENT_VERSION → $NEW_VERSION"

# ── Update install.sh (ZSHX_TAG) ────────────────────────────────────────────

if [ -f "install.sh" ]; then
  sed -i "s/ZSHX_TAG=v${CURRENT_VERSION}/ZSHX_TAG=v${NEW_VERSION}/" install.sh
  info "Updated install.sh ZSHX_TAG to $NEW_TAG"
else
  warn "install.sh not found — skipping."
fi

# ── Update README.md (all refs/tags/vX.Y.Z URLs) ───────────────────────────

if [ -f "README.md" ]; then
  sed -i "s|refs/tags/v${CURRENT_VERSION}|refs/tags/v${NEW_VERSION}|g" README.md
  info "Updated README.md tag references to $NEW_TAG"
else
  warn "README.md not found — skipping."
fi

# ── Commit (all files in a single commit) ───────────────────────────────────

git add "$VERSION_FILE" install.sh README.md
git commit -m "chore: bump version to ${NEW_TAG}" \
  || die "Git commit failed (nothing to commit?)."

# ── Create tag ───────────────────────────────────────────────────────────────

git tag -a "$NEW_TAG" -m "Release ${NEW_TAG}" HEAD
info "Created tag $NEW_TAG"

# ── Push commit + tag ───────────────────────────────────────────────────────

info ""
info "=== Pushing release ==="
info "Commit : $(git rev-parse --short HEAD) — 'chore: bump version to ${NEW_TAG}'"
info "Tag    : $NEW_TAG"
info "Branch : $BRANCH → origin/$BRANCH"
info ""

if ! git push origin "$BRANCH" --tags; then
  die "Push failed. Check your remote access and network connection."
fi

info "=== Release ${NEW_TAG} published successfully! ==="
