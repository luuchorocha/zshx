#!/usr/bin/env sh
# install.sh — Installer for zshx (framework-free zsh config)
# Usage:
#   Local clone: ./install.sh [--uninstall] [--install-dir PATH] [--force] [--dry-run]
#   Remote:      curl -fsSL https://raw.githubusercontent.com/luuchorocha/zshx/refs/tags/v1.0.0/install.sh | sh -s -- [OPTIONS]

set -e

# ── Constants (override via environment) ────────────────────────────────
ZSHX_REPO="${ZSHX_REPO:-https://github.com/luuchorocha/zshx}"
ZSHX_TAG="${ZSHX_TAG:-v1.0.0}"
ZSHX_DEFAULT_DIR="${ZSHX_DEFAULT_DIR:-$HOME/.config/zshx}"

# ── State variables ─────────────────────────────────────────────────────
ZSHX_INSTALL_DIR=""
ZSHX_MODE=""       # "local" or "remote"
ZSHX_UNINSTALL=0
ZSHX_FORCE=0
ZSHX_DRY_RUN=0

# ── Helpers ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: install.sh [OPTIONS]

Options:
  --uninstall         Remove zshx installation (unlink .zshrc, delete install dir)
  --install-dir PATH  Install zshx to a custom directory (default: $ZSHX_DEFAULT_DIR)
  --force             Skip confirmation prompts and overwrite without backup
  --dry-run           Show what would be done without making changes
  --help              Show this help message

Install zshx — a framework-free zsh configuration.

Environment overrides:
  ZSHX_REPO          Git repository URL (default: $ZSHX_REPO)
  ZSHX_TAG           Tag to check out (default: $ZSHX_TAG)
  ZSHX_DEFAULT_DIR   Default install path (default: $ZSHX_DEFAULT_DIR)

Remote install via curl:
  curl -fsSL https://raw.githubusercontent.com/luuchorocha/zshx/refs/tags/v1.0.0/install.sh | sh -s -- [OPTIONS]

EOF
}

die() { printf 'install.sh: error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'install.sh: warning: %s\n' "$*" >&2; }
info() { printf 'install.sh: %s\n' "$*"; }

# ── Guardrails ──────────────────────────────────────────────────────────
_check_prereqs() {
  if [ "$(id -u)" = "0" ]; then
    die "This installer must not be run as root."
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    die "zsh is required but not found. Install zsh first (e.g. brew install zsh or apt install zsh)."
  fi

  # Remote mode requires git and curl
  if [ "$ZSHX_MODE" = "remote" ]; then
    command -v git >/dev/null 2>&1 || die "git is required for remote installation but was not found."
    command -v curl >/dev/null 2>&1 || die "curl is required for remote installation but was not found."
  fi
}

# ── Mode detection ──────────────────────────────────────────────────────
_detect_mode() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ -f "$(git rev-parse --show-toplevel)/zshx" ]; then
    ZSHX_MODE="local"
    ZSHX_INSTALL_DIR="${ZSHX_INSTALL_DIR:-$(git rev-parse --show-toplevel)}"
  else
    ZSHX_MODE="remote"
    ZSHX_INSTALL_DIR="${ZSHX_INSTALL_DIR:-$ZSHX_DEFAULT_DIR}"
  fi
}

# ── Existing state detection ────────────────────────────────────────────
_detect_existing_state() {
  # Returns: "none", "partial", or "full"
  if [ -d "$ZSHX_INSTALL_DIR" ]; then
    if [ -f "$ZSHX_INSTALL_DIR/zshx" ] && [ -d "$ZSHX_INSTALL_DIR/zshx.d" ]; then
      echo "full"
    else
      echo "partial"
    fi
  elif [ -L ~/.zshrc ] || [ -e ~/.zshrc ]; then
    if [ -L ~/.zshrc ] && printf '%s' "$(readlink ~/.zshrc)" | grep -q 'zshx'; then
      echo "full"
    else
      echo "partial"
    fi
  else
    echo "none"
  fi
}

# ── Install logic ───────────────────────────────────────────────────────
_local_install() {
  info "Installing from local clone: $ZSHX_INSTALL_DIR"
  mkdir -p "$ZSHX_INSTALL_DIR"

  cp -f "$(git rev-parse --show-toplevel)/zshx" "$ZSHX_INSTALL_DIR/zshx"
  chmod +x "$ZSHX_INSTALL_DIR/zshx"

  if [ -d "$(git rev-parse --show-toplevel)/zshx.d" ]; then
    cp -r "$(git rev-parse --show-toplevel)/zshx.d/"* "$ZSHX_INSTALL_DIR/zshx.d/" 2>/dev/null || true
  fi

  info "Files installed to $ZSHX_INSTALL_DIR"
}

_remote_install() {
  info "Cloning zshx from $ZSHX_REPO at tag $ZSHX_TAG → $ZSHX_INSTALL_DIR"

  if [ -d "$ZSHX_INSTALL_DIR" ]; then
    # Treat as a git repo that needs updating, not a fresh clone
    if git -C "$ZSHX_INSTALL_DIR" rev-parse --git-dir >/dev/null 2>&1; then
      info "Existing git repo found. Pulling updates…"
      git -C "$ZSHX_INSTALL_DIR" fetch origin || warn "Could not fetch from remote."
      git -C "$ZSHX_INSTALL_DIR" checkout "$ZSHX_TAG" || warn "Could not check out tag $ZSHX_TAG."
    else
      rm -rf "$ZSHX_INSTALL_DIR"
      git clone --depth 1 --branch "$ZSHX_TAG" "$ZSHX_REPO" "$ZSHX_INSTALL_DIR"
    fi
  else
    mkdir -p "$(dirname "$ZSHX_INSTALL_DIR")"
    git clone --depth 1 --branch "$ZSHX_TAG" "$ZSHX_REPO" "$ZSHX_INSTALL_DIR"
  fi

  chmod +x "$ZSHX_INSTALL_DIR/zshx"
  info "Repository cloned to $ZSHX_INSTALL_DIR"
}

_setup_zshrc() {
  if [ -L ~/.zshrc ]; then
    current_target="$(readlink ~/.zshrc)"
    if [ "$current_target" = "$ZSHX_INSTALL_DIR/zshx" ]; then
      info ".zshrc is already a symlink to zshx — skipping."
      return 0
    fi
  elif [ -e ~/.zshrc ]; then
    # File exists but not a correct symlink
    if [ "$ZSHX_FORCE" = "1" ] || [ "$ZSHX_DRY_RUN" = "0" ]; then
      backup="${ZSHX_INSTALL_DIR}/.zshrc.bak"
      cp -f ~/.zshrc "$backup" 2>/dev/null && warn ".zshrc backed up to $backup"
    fi
  else
    # No .zshrc at all
    if [ "$ZSHX_DRY_RUN" = "0" ]; then
      mkdir -p "$(dirname ~/.zshrc)"
      printf 'source %s/zshx\n' "$ZSHX_INSTALL_DIR" > ~/.zshrc
      info ".zshrc created."
    fi
  fi

  if [ "$ZSHX_DRY_RUN" = "0" ]; then
    ln -sf "$ZSHX_INSTALL_DIR/zshx" ~/.zshrc
  fi
}

# ── Uninstall logic ─────────────────────────────────────────────────────
_uninstall() {
  state="$(_detect_existing_state)"
  info "Current state: $state"

  # Unlink .zshrc
  if [ -L ~/.zshrc ]; then
    target="$(readlink ~/.zshrc)"
    case "$target" in
      *zshx*)
        info ".zshrc was linked to zshx — unlinking."
        if [ "$ZSHX_FORCE" = "0" ] && [ -d "$ZSHX_INSTALL_DIR" ] && [ -e "$ZSHX_INSTALL_DIR/.zshrc.bak" ]; then
          cp -f "$ZSHX_INSTALL_DIR/.zshrc.bak" ~/.zshrc
          info "Restored .zshrc from backup: $ZSHX_INSTALL_DIR/.zshrc.bak"
        else
          rm -f ~/.zshrc
          warn ".zshrc unlinked (no usable backup found — your original content is lost)."
        fi
        ;;
      *)
        info ".zshrc was linked to something else ($target) — not touching it."
        ;;
    esac
  elif [ -e ~/.zshrc ]; then
    warn ".zshrc exists but is not a zshx symlink. Leaving it alone."
  else
    info "No .zshrc found. Nothing to unlink."
  fi

  # Remove install directory (remote mode only, or --force)
  if [ "$ZSHX_MODE" = "local" ]; then
    warn "Running in local mode — preserving your git clone at $ZSHX_INSTALL_DIR."
    info "To fully uninstall: manually remove this directory with rm -rf '$ZSHX_INSTALL_DIR'."
  else
    if [ "$ZSHX_FORCE" = "0" ] && [ "$ZSHX_DRY_RUN" = "0" ]; then
      printf "Remove %s? [y/N] " "$ZSHX_INSTALL_DIR"
      read -r confirm
      case "$confirm" in
        [yY]*) ;;
        *) info "Aborted." ; exit 0 ;;
      esac
    fi
    if [ "$ZSHX_DRY_RUN" = "0" ]; then
      rm -rf "$ZSHX_INSTALL_DIR"
      info "Install directory removed."
    fi
  fi

  info "Uninstall complete."
}

# ── Flag parsing ────────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --help)          usage; exit 0 ;;
    --uninstall)     ZSHX_UNINSTALL=1 ; shift ;;
    --force)         ZSHX_FORCE=1 ; shift ;;
    --dry-run)       ZSHX_DRY_RUN=1 ; shift ;;
    --install-dir)
      if [ $# -gt 1 ]; then
        ZSHX_INSTALL_DIR="$2"
        shift 2
      else
        die "--install-dir requires a path argument"
      fi
      ;;
    *)               die "Unknown option: $1 (use --help)" ;;
  esac
done

# ── Main flow ───────────────────────────────────────────────────────────
_detect_mode
[ "$ZSHX_UNINSTALL" = "1" ] && { _check_prereqs; _uninstall; exit 0; }

_check_prereqs

if [ "$ZSHX_DRY_RUN" = "1" ]; then
  info "[DRY-RUN] Mode: $ZSHX_MODE"
  info "[DRY-RUN] Target: $ZSHX_INSTALL_DIR"
  info "[DRY-RUN] Existing state: $(_detect_existing_state)"
  exit 0
fi

state="$(_detect_existing_state)"

if [ "$state" = "full" ] && [ -d "$ZSHX_INSTALL_DIR" ]; then
  info "zshx is already installed at $ZSHX_INSTALL_DIR — skipping install."
else
  if [ "$ZSHX_MODE" = "local" ]; then
    _local_install
  else
    _remote_install
  fi

  _setup_zshrc

  info ""
  info "=== zshx installed successfully! ==="
  info "Install dir: $ZSHX_INSTALL_DIR"
  info "To update later: cd $ZSHX_INSTALL_DIR && git pull"
  info "To start zsh:   exec zsh"
  info "To uninstall:   ./install.sh --uninstall"
  info ""
fi
