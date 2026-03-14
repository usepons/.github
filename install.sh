#!/bin/sh
set -e

# Pons Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/usepons/.github/main/install.sh | sh
# Or download and run: sh install.sh [--yes|-y]

PONS_INSTALLER_VERSION="1.0.0"
DENO_MIN_VERSION="2"
DENO_BIN_DIR="$HOME/.deno/bin"
AUTO_YES=0

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=1 ;;
  esac
done

# TTY detection — auto-accept when piped
if [ ! -t 0 ]; then
  AUTO_YES=1
fi

# Color support
setup_colors() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
  else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
  fi
}

setup_colors

# Output helpers
info()    { printf "${CYAN}  ℹ ${RESET}%s\n" "$1"; }
success() { printf "${GREEN}  ✓ ${RESET}%s\n" "$1"; }
warn()    { printf "${YELLOW}  ⚠ ${RESET}%s\n" "$1"; }
error()   { printf "${RED}  ✗ ${RESET}%s\n" "$1"; }

# Prompt helper — returns 0 for yes, 1 for no
# Usage: confirm "message [Y/n]" Y   or   confirm "message [y/N]" N
# Second arg is the default when user presses Enter (Y or N)
confirm() {
  if [ "$AUTO_YES" = "1" ]; then
    return 0
  fi
  printf "%s " "$1"
  read -r answer </dev/tty
  case "$answer" in
    "") # empty = use default
      case "$2" in
        N|n) return 1 ;;
        *) return 0 ;;
      esac ;;
    [yY]*) return 0 ;;
    *) return 1 ;;
  esac
}

# State tracking
DENO_FRESHLY_INSTALLED=0

banner() {
  cat <<'BANNER'

    ____
   / __ \____  ____  _____
  / /_/ / __ \/ __ \/ ___/
 / ____/ /_/ / / / (__  )
/_/    \____/_/ /_/____/

BANNER
  printf "  ${BOLD}Pons Installer${RESET} v%s\n\n" "$PONS_INSTALLER_VERSION"
}

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Darwin) PLATFORM="macOS" ;;
    Linux)  PLATFORM="Linux" ;;
    *)
      error "Unsupported operating system: $OS"
      error "This installer supports macOS and Linux. For Windows, use install.ps1."
      exit 1
      ;;
  esac

  info "Detected $PLATFORM ($ARCH)"
}

check_connectivity() {
  info "Checking internet connectivity..."
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsS --max-time 5 https://jsr.io >/dev/null 2>&1; then
      error "Cannot reach jsr.io. Please check your internet connection."
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -q --timeout=5 -O /dev/null https://jsr.io 2>/dev/null; then
      error "Cannot reach jsr.io. Please check your internet connection."
      exit 1
    fi
  else
    warn "Neither curl nor wget found. Skipping connectivity check."
  fi
}

# Returns 0 if installed deno meets minimum version, 1 otherwise
check_deno_version() {
  deno_ver="$(deno --version 2>/dev/null | head -1 | sed 's/deno //')"
  if [ -z "$deno_ver" ]; then
    return 1
  fi
  major="$(printf '%s' "$deno_ver" | cut -d. -f1)"
  if [ "$major" -ge "$DENO_MIN_VERSION" ] 2>/dev/null; then
    return 0
  fi
  return 1
}

install_deno() {
  # Check if already installed and meets version requirement
  if command -v deno >/dev/null 2>&1; then
    deno_ver="$(deno --version | head -1 | sed 's/deno //')"
    if check_deno_version; then
      DENO_FRESHLY_INSTALLED=0
      success "Deno found (v$deno_ver)"
      return 0
    else
      warn "Deno v$deno_ver found but v${DENO_MIN_VERSION}.0.0+ is required"
    fi
  fi

  info "Installing Deno..."

  # macOS: try brew first
  if [ "$PLATFORM" = "macOS" ] && command -v brew >/dev/null 2>&1; then
    info "Trying Homebrew..."
    if brew install deno 2>/dev/null; then
      if check_deno_version; then
        deno_ver="$(deno --version | head -1 | sed 's/deno //')"
        DENO_FRESHLY_INSTALLED=1
        success "Deno installed via Homebrew (v$deno_ver)"
        return 0
      else
        warn "Homebrew installed an outdated Deno version, falling back to official installer"
      fi
    fi
  fi

  # Fallback: official installer
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://deno.land/install.sh | sh
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://deno.land/install.sh | sh
  else
    error "Neither curl nor wget found. Cannot install Deno."
    error "Install Deno manually: https://deno.land/#installation"
    exit 1
  fi

  # Source the new deno into current PATH
  export PATH="$DENO_BIN_DIR:$PATH"

  if command -v deno >/dev/null 2>&1 && check_deno_version; then
    DENO_FRESHLY_INSTALLED=1
    deno_ver="$(deno --version | head -1 | sed 's/deno //')"
    success "Deno installed (v$deno_ver)"
  else
    error "Deno installation failed."
    error "Install Deno manually: https://deno.land/#installation"
    exit 1
  fi
}

ensure_path() {
  # Check if deno bin dir is already in PATH
  case ":$PATH:" in
    *":$DENO_BIN_DIR:"*) return 0 ;;
  esac

  warn "Deno's bin directory is not in your PATH: $DENO_BIN_DIR"
  warn "The 'pons' command won't be available until it is."

  # Determine shell profile file
  shell_name="$(basename "${SHELL:-/bin/sh}")"
  case "$shell_name" in
    zsh)  profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
    *)    profile="$HOME/.profile" ;;
  esac

  if confirm "  Add it to $profile? [Y/n]"; then
    # Skip if already in the profile file
    if [ -f "$profile" ] && grep -q "$DENO_BIN_DIR" "$profile" 2>/dev/null; then
      info "Already present in $profile (PATH may need a shell restart)"
      return 0
    fi

    printf '\n# Added by Pons installer\nexport PATH="%s:$PATH"\n' "$DENO_BIN_DIR" >> "$profile"
    success "Added to $profile"
    info "Restart your terminal or run: source $profile"
  else
    info "Skipped. Add this to your shell profile manually:"
    info "  export PATH=\"$DENO_BIN_DIR:\$PATH\""
  fi
}

install_pons() {
  # Check if already installed
  if command -v pons >/dev/null 2>&1; then
    pons_ver="$(pons --version 2>/dev/null || echo "unknown")"
    warn "Pons is already installed ($pons_ver)"
    if ! confirm "  Reinstall? [y/N]" N; then
      success "Keeping existing Pons installation"
      return 0
    fi
    # Force reinstall
    info "Reinstalling Pons..."
    deno install -gAf -n pons jsr:@pons/cli
  else
    info "Installing Pons CLI..."
    deno install -gA -n pons jsr:@pons/cli
  fi

  # Verify
  export PATH="$DENO_BIN_DIR:$PATH"
  if command -v pons >/dev/null 2>&1; then
    pons_ver="$(pons --version 2>/dev/null || echo "")"
    success "Pons CLI installed${pons_ver:+ ($pons_ver)}"
  else
    error "Pons installation could not be verified."
    error "Try running manually: deno install -gA -n pons jsr:@pons/cli"
    exit 1
  fi
}

print_success() {
  deno_ver="$(deno --version | head -1 | sed 's/deno //')"
  pons_ver="$(pons --version 2>/dev/null || echo "")"

  printf "\n"
  if [ "$DENO_FRESHLY_INSTALLED" = "1" ]; then
    printf "  ${GREEN}✓${RESET} Deno installed (v%s)\n" "$deno_ver"
  else
    printf "  ${GREEN}✓${RESET} Deno found (v%s)\n" "$deno_ver"
  fi
  printf "  ${GREEN}✓${RESET} Pons CLI installed${pons_ver:+ ($pons_ver)}\n"
  printf "\n"
  printf "  ${BOLD}Get started:${RESET}\n"
  printf "    pons install && pons onboard    Start the kernel\n"
  printf "    pons modules list               List installed modules\n"
  printf "\n"
  printf "  ${BOLD}Uninstall:${RESET}\n"
  printf "    deno uninstall pons\n"
  printf "\n"
  printf "  ${BOLD}Documentation:${RESET} https://github.com/usepons\n"
  printf "\n"
}

main() {
  banner
  if [ "$AUTO_YES" = "1" ] && [ -t 1 ]; then
    info "Running non-interactively, accepting all defaults"
  fi
  detect_platform
  check_connectivity
  install_deno
  ensure_path
  install_pons
  print_success
}

main
