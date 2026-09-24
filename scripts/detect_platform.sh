#!/usr/bin/env bash
# ============================================================
# CTF Solver — Platform Detection Helper
# Outputs: WINDOWS | KALI | DEBIAN | DOCKER_LINUX | MACOS
# Usage: source detect_platform.sh; echo $PLATFORM $EXEC_METHOD
# ============================================================

detect_platform() {
  local os=""
  local exec_method=""

  # Windows (Git Bash / MSYS / WSL inside Windows shows Linux but check WSLENV)
  if [[ -n "$WSLENV" || -n "$WSL_DISTRO_NAME" ]]; then
    os="WSL"
    exec_method="native"   # Already inside WSL/Kali
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="MACOS"
    exec_method="docker"
  elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "linux"* ]]; then
    # Check specific distro
    local distro=""
    if [ -f /etc/os-release ]; then
      distro=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
    fi
    case "$distro" in
      kali)
        os="KALI"
        exec_method="native"
        ;;
      ubuntu|debian|linuxmint|pop|elementary|zorin|raspbian|mx|parrot)
        os="DEBIAN"
        exec_method="native"   # install tools natively via apt
        ;;
      *)
        os="LINUX_OTHER"
        exec_method="docker"   # non-Debian: use Docker + Kali container
        ;;
    esac
  else
    os="UNKNOWN"
    exec_method="docker"
  fi

  export PLATFORM="$os"
  export EXEC_METHOD="$exec_method"
  export CTF_DISTRO="$distro"
}

detect_platform

# Set writeup dir based on platform
case "$PLATFORM" in
  MACOS|KALI|DEBIAN|LINUX_OTHER|WSL)
    export WRITEUP_DIR="$HOME/Documents/CTF-Writeups"
    ;;
  *)
    export WRITEUP_DIR="$HOME/Documents/CTF-Writeups"
    ;;
esac

mkdir -p "$WRITEUP_DIR" 2>/dev/null || true
