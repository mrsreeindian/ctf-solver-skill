#!/usr/bin/env bash
# ============================================================
# CTF Solver Skill — Cross-Platform Installer
# Supports: Linux (Debian/non-Debian), macOS
# For Windows: use install.ps1 instead
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/mrsreeindian/ctf-solver-skill/master/install.sh | bash
#   OR: bash install.sh
# ============================================================
set -e

REPO_URL="https://github.com/mrsreeindian/ctf-solver-skill"
BOLD="\e[1m"; GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; RED="\e[31m"; RESET="\e[0m"

log()    { echo -e "${GREEN}[+]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
err()    { echo -e "${RED}[-]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}$1${RESET}\n"; }

# ─── Detect OS ──────────────────────────────────────────────
detect_os() {
  OS="$(uname -s)"
  case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)
      PLATFORM="linux"
      if [ -f /etc/os-release ]; then
        DISTRO_ID=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        DISTRO_LIKE=$(grep -i '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]' 2>/dev/null || echo "")
      fi
      # Check if Debian-based (apt-get available)
      if command -v apt-get &>/dev/null; then
        LINUX_TYPE="debian"
      else
        LINUX_TYPE="other"
      fi
      ;;
    *) err "Unsupported OS: $OS. Use install.ps1 on Windows." ;;
  esac
}

# ─── Install Docker ─────────────────────────────────────────
install_docker_linux() {
  log "Installing Docker..."
  if command -v yum &>/dev/null; then
    # RHEL/CentOS/Fedora
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
  elif command -v pacman &>/dev/null; then
    # Arch
    sudo pacman -Sy --noconfirm docker
    sudo systemctl start docker
    sudo systemctl enable docker
  elif command -v zypper &>/dev/null; then
    # openSUSE
    sudo zypper install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
  else
    # Generic: use Docker's get.docker.com script
    warn "Using Docker's official install script..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo systemctl start docker
    sudo systemctl enable docker
  fi
  sudo usermod -aG docker "$USER"
  log "Docker installed. You may need to log out/in for group changes to take effect."
  log "Run: newgrp docker  (to use docker without logout)"
}

install_docker_mac() {
  log "macOS detected. Checking for Docker..."
  if command -v docker &>/dev/null; then
    log "Docker already installed."
    return
  fi
  if command -v brew &>/dev/null; then
    log "Installing Docker via Homebrew..."
    brew install --cask docker
    log "Please open Docker Desktop from Applications and start it."
    log "Then re-run this installer."
    open /Applications/Docker.app 2>/dev/null || true
    read -rp "Press Enter once Docker Desktop is running..."
  else
    warn "Homebrew not found. Please install Docker Desktop manually:"
    echo "  https://www.docker.com/products/docker-desktop/"
    read -rp "Press Enter once Docker Desktop is installed and running..."
  fi
}

# ─── Clone/update repo ──────────────────────────────────────
get_source() {
  if [ -f "$(dirname "$0")/SKILL.md" ]; then
    # Running from cloned repo
    SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
    log "Using local source: $SOURCE_DIR"
  else
    # Download from GitHub
    log "Cloning ctf-solver-skill from GitHub..."
    if command -v git &>/dev/null; then
      git clone "$REPO_URL" /tmp/ctf-solver-skill-install
      SOURCE_DIR="/tmp/ctf-solver-skill-install"
    else
      err "git not found. Install git first: sudo apt install git"
    fi
  fi
}

# ─── Choose scope ───────────────────────────────────────────
choose_scope() {
  header "Installation Scope"
  echo "  [1] Global  — Available in ALL projects (recommended)"
  echo "      Path: ~/.config/antigravity/skills/ctf-solver/"
  echo "            OR ~/.gemini/config/skills/ctf-solver/"
  echo ""
  echo "  [2] Project — Available only in the CURRENT directory"
  echo "      Path: .agents/skills/ctf-solver/"
  echo ""
  read -rp "Choose scope [1/2]: " SCOPE_CHOICE

  case "$SCOPE_CHOICE" in
    2)
      SKILL_DIR="$(pwd)/.agents/skills/ctf-solver"
      SCOPE_LABEL="Project-scoped (.agents/skills/)"
      ;;
    *)
      # Try Antigravity global, fall back to gemini global
      if [ -d "$HOME/.gemini/config" ]; then
        SKILL_DIR="$HOME/.gemini/config/skills/ctf-solver"
      else
        SKILL_DIR="$HOME/.config/antigravity/skills/ctf-solver"
      fi
      SCOPE_LABEL="Global ($SKILL_DIR)"
      ;;
  esac
}

# ─── Copy files ─────────────────────────────────────────────
install_files() {
  header "Installing Skill Files"
  mkdir -p "$SKILL_DIR/references" "$SKILL_DIR/scripts" "$SKILL_DIR/templates"

  cp "$SOURCE_DIR/SKILL.md"           "$SKILL_DIR/SKILL.md"
  cp "$SOURCE_DIR/references/"*.md    "$SKILL_DIR/references/"
  cp "$SOURCE_DIR/scripts/"*.sh       "$SKILL_DIR/scripts/"
  cp "$SOURCE_DIR/templates/"*.md     "$SKILL_DIR/templates/"

  # Ensure scripts are executable
  chmod +x "$SKILL_DIR/scripts/"*.sh

  log "Skill files installed: $SKILL_DIR"

  # Writeup folder
  WRITEUP_DIR="$HOME/Documents/CTF-Writeups"
  mkdir -p "$WRITEUP_DIR"
  log "Writeup directory: $WRITEUP_DIR"
}

# ─── Setup Kali environment ─────────────────────────────────
setup_kali_env() {
  header "Setting Up Kali Linux Environment"

  if [ "$PLATFORM" = "linux" ] && [ "$LINUX_TYPE" = "debian" ]; then
    log "Debian-based Linux detected. Installing CTF tools natively..."
    bash "$SKILL_DIR/scripts/setup_tools.sh"
  else
    # Docker path: macOS or non-Debian Linux
    if [ "$PLATFORM" = "macos" ]; then
      install_docker_mac
    else
      log "Non-Debian Linux ($DISTRO_ID). Installing Docker + Kali container..."
      install_docker_linux
    fi

    log "Pulling Kali Linux Docker image (kalilinux/kali-rolling)..."
    docker pull kalilinux/kali-rolling

    log "Creating persistent Kali container 'ctf_kali'..."
    docker rm -f ctf_kali 2>/dev/null || true
    docker volume create ctf_kali_home >/dev/null

    WRITEUP_DIR="$HOME/Documents/CTF-Writeups"
    mkdir -p "$WRITEUP_DIR"

    docker run -d \
      --name ctf_kali \
      -v "/tmp/ctf:/tmp/ctf" \
      -v "ctf_kali_home:/root" \
      -v "$WRITEUP_DIR:/root/writeups" \
      --restart unless-stopped \
      kalilinux/kali-rolling sleep infinity

    log "Installing CTF tools inside Kali container (this takes ~5-10 min)..."
    docker cp "$SKILL_DIR/scripts/setup_tools.sh" ctf_kali:/tmp/setup_tools.sh
    docker exec ctf_kali bash /tmp/setup_tools.sh

    log "Kali container 'ctf_kali' is ready."
    log "  Run interactively: docker exec -it ctf_kali bash"
    log "  Execute command:   docker exec ctf_kali bash -c 'COMMAND'"
  fi
}

# ─── Print usage instructions ───────────────────────────────
print_usage() {
  header "Installation Complete! 🎉"
  echo ""
  log "Skill installed:   $SKILL_DIR"
  log "Writeup directory: $HOME/Documents/CTF-Writeups"
  echo ""
  echo -e "${CYAN}Usage:${RESET}"
  echo "  Tell Antigravity/Claude: 'Solve this CTF challenge: [file/URL/nc host port]'"
  echo ""
  echo -e "${CYAN}Execution wrapper:${RESET}"

  if [ "$PLATFORM" = "linux" ] && [ "$LINUX_TYPE" = "debian" ]; then
    echo "  bash $SKILL_DIR/scripts/kali_exec.sh 'command'   (native)"
  else
    echo "  docker exec ctf_kali bash -c 'command'           (via Docker)"
    echo "  bash $SKILL_DIR/scripts/kali_exec.sh 'command'   (auto-routed)"
  fi

  echo ""
  echo -e "${CYAN}Quick test:${RESET}"
  echo "  bash $SKILL_DIR/scripts/kali_exec.sh --status"
  echo "  bash $SKILL_DIR/scripts/kali_exec.sh 'uname -a && which python3'"
  echo ""
}

# ─── Main ───────────────────────────────────────────────────
main() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║      CTF Solver Skill — Cross-Platform Installer     ║"
  echo "║     Supports: Linux (native/Docker), macOS (Docker)  ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${RESET}"

  detect_os
  log "Platform: $OS${DISTRO_ID:+ ($DISTRO_ID)}"

  get_source
  choose_scope
  install_files
  setup_kali_env
  print_usage
}

main "$@"
