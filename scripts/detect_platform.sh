#!/usr/bin/env bash
# ============================================================
# CTF Solver — Platform Detection Helper
# Outputs: WINDOWS | KALI | DEBIAN | DOCKER_LINUX | MACOS | WSL
# Usage: source detect_platform.sh; echo $PLATFORM $EXEC_METHOD
# ============================================================

detect_platform() {
  local os=""
  local exec_method=""
  local distro=""

  if [ -f /etc/os-release ]; then
    distro=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
  fi

  # 1. WSL Detection (robust check via env, /run/WSL, or /proc/version)
  if [[ -n "$WSLENV" || -n "$WSL_DISTRO_NAME" || -d "/run/WSL" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    os="WSL"
    exec_method="native"
  elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]; then
    os="MACOS"
    exec_method="docker"
  elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "linux"* || "$(uname -s 2>/dev/null)" == "Linux" ]]; then
    case "$distro" in
      kali)
        os="KALI"
        exec_method="native"
        ;;
      ubuntu|debian|linuxmint|pop|elementary|zorin|raspbian|mx|parrot)
        os="DEBIAN"
        exec_method="native"
        ;;
      *)
        os="LINUX_OTHER"
        exec_method="docker"
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

# Determine best writeup directory
if [ "$PLATFORM" = "WSL" ]; then
  # Prefer Windows host Documents folder if mounted
  WIN_DOCS=""
  if [ -n "$USERPROFILE" ] && command -v wslpath &>/dev/null; then
    WP=$(wslpath "$USERPROFILE" 2>/dev/null)
    [ -d "$WP/Documents" ] && WIN_DOCS="$WP/Documents/CTF-Writeups"
  fi

  if [ -z "$WIN_DOCS" ] && [ -d "/mnt/c/Users" ]; then
    for u in /mnt/c/Users/*; do
      bname="${u##*/}"
      case "$bname" in
        "All Users"|"Default"|"Default User"|"Public") continue ;;
        *)
          if [ -d "$u/Documents" ]; then
            WIN_DOCS="$u/Documents/CTF-Writeups"
            break
          fi
          ;;
      esac
    done
  fi

  export WRITEUP_DIR="${WIN_DOCS:-$HOME/Documents/CTF-Writeups}"
else
  export WRITEUP_DIR="$HOME/Documents/CTF-Writeups"
fi

mkdir -p "$WRITEUP_DIR" 2>/dev/null || true
