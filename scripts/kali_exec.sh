#!/usr/bin/env bash
# ============================================================
# CTF Solver — Universal Kali Execution Wrapper
#
# Routes commands to the right Kali environment:
#   - Kali/Debian Linux  → runs natively
#   - Non-Debian Linux   → docker exec ctf_kali
#   - macOS              → docker exec ctf_kali
#   - (Windows WSL)      → runs natively (already in Kali)
#
# Usage:
#   bash kali_exec.sh "command to run"
#   bash kali_exec.sh -f /path/to/script.sh [args...]
#   bash kali_exec.sh -i                    (interactive shell)
#
# Environment:
#   CTF_WORK_DIR  - host working dir to mount (default: /tmp/ctf)
#   KALI_CONTAINER_NAME - Docker container name (default: ctf_kali)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect_platform.sh"

KALI_CONTAINER="${KALI_CONTAINER_NAME:-ctf_kali}"
KALI_IMAGE="kalilinux/kali-rolling"
CTF_WORK="${CTF_WORK_DIR:-/tmp/ctf}"
CYAN="\e[36m"; YELLOW="\e[33m"; GREEN="\e[32m"; RED="\e[31m"; RESET="\e[0m"

log()  { echo -e "${GREEN}[kali_exec]${RESET} $1" >&2; }
warn() { echo -e "${YELLOW}[kali_exec]${RESET} $1" >&2; }
err()  { echo -e "${RED}[kali_exec]${RESET} $1" >&2; }

# ─── Docker helpers ─────────────────────────────────────────
ensure_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found. Run install.sh first."
    exit 1
  fi
  if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon not running. Start Docker Desktop / dockerd first."
    exit 1
  fi
}

ensure_kali_container() {
  ensure_docker

  # Pull image if not present
  if ! docker image inspect "$KALI_IMAGE" &>/dev/null 2>&1; then
    log "Pulling $KALI_IMAGE (first time, ~500 MB)..."
    docker pull "$KALI_IMAGE"
  fi

  # Start container if not running
  if ! docker ps --format '{{.Names}}' | grep -q "^${KALI_CONTAINER}$"; then
    if docker ps -a --format '{{.Names}}' | grep -q "^${KALI_CONTAINER}$"; then
      log "Starting existing Kali container..."
      docker start "$KALI_CONTAINER" >/dev/null
    else
      log "Creating persistent Kali container '$KALI_CONTAINER'..."
      mkdir -p "$CTF_WORK"
      docker run -d \
        --name "$KALI_CONTAINER" \
        -v "${CTF_WORK}:/tmp/ctf" \
        -v "ctf_kali_home:/root" \
        --restart unless-stopped \
        "$KALI_IMAGE" sleep infinity >/dev/null
      log "Container created. Installing tools now..."
      # Copy and run setup script inside container
      docker cp "$SCRIPT_DIR/setup_tools.sh" "${KALI_CONTAINER}:/tmp/setup_tools.sh"
      docker exec "$KALI_CONTAINER" bash /tmp/setup_tools.sh
    fi
  fi
}

# ─── Run command in Kali ────────────────────────────────────
run_in_kali() {
  local cmd="$1"

  case "$EXEC_METHOD" in
    native)
      # Already on Kali/Debian — run directly
      bash -c "$cmd"
      ;;
    docker)
      ensure_kali_container
      # Sync host files to container working dir if a file path is in the command
      docker exec -i "$KALI_CONTAINER" bash -c "mkdir -p /tmp/ctf"
      docker exec -i "$KALI_CONTAINER" bash -c "$cmd"
      ;;
    *)
      err "Unknown exec method: $EXEC_METHOD"
      exit 1
      ;;
  esac
}

# ─── Run a script file in Kali ──────────────────────────────
run_script_in_kali() {
  local script="$1"; shift
  local args="$*"

  case "$EXEC_METHOD" in
    native)
      bash "$script" $args
      ;;
    docker)
      ensure_kali_container
      local basename
      basename=$(basename "$script")
      docker cp "$script" "${KALI_CONTAINER}:/tmp/${basename}"
      docker exec -i "$KALI_CONTAINER" bash "/tmp/${basename}" $args
      ;;
  esac
}

# ─── Copy file to Kali workspace ────────────────────────────
copy_to_kali() {
  local src="$1"
  local dest="${2:-/tmp/ctf/$(basename "$1")}"

  case "$EXEC_METHOD" in
    native)
      mkdir -p /tmp/ctf
      cp "$src" "$dest"
      echo "$dest"
      ;;
    docker)
      ensure_kali_container
      docker exec "$KALI_CONTAINER" mkdir -p /tmp/ctf
      docker cp "$src" "${KALI_CONTAINER}:${dest}"
      echo "$dest"
      ;;
  esac
}

# ─── Interactive shell ──────────────────────────────────────
interactive_kali() {
  case "$EXEC_METHOD" in
    native)
      bash
      ;;
    docker)
      ensure_kali_container
      docker exec -it "$KALI_CONTAINER" bash
      ;;
  esac
}

# ─── CLI entry point ────────────────────────────────────────
case "${1:-}" in
  -i|--interactive)
    interactive_kali
    ;;
  -f|--file)
    shift
    run_script_in_kali "$@"
    ;;
  --copy)
    shift
    copy_to_kali "$@"
    ;;
  --status)
    echo "Platform:    $PLATFORM"
    echo "Exec method: $EXEC_METHOD"
    echo "Writeup dir: $WRITEUP_DIR"
    if [ "$EXEC_METHOD" = "docker" ]; then
      echo "Container:   $KALI_CONTAINER"
      if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${KALI_CONTAINER}$"; then
        echo "Status:      running ✓"
      else
        echo "Status:      stopped"
      fi
    fi
    ;;
  "")
    echo "Usage: kali_exec.sh <command>"
    echo "       kali_exec.sh -f <script.sh> [args]"
    echo "       kali_exec.sh -i             (interactive shell)"
    echo "       kali_exec.sh --copy <file>  (copy file to Kali workspace)"
    echo "       kali_exec.sh --status       (show platform info)"
    ;;
  *)
    run_in_kali "$*"
    ;;
esac
