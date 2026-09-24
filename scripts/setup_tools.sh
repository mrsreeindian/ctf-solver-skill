#!/usr/bin/env bash
# ============================================================
# CTF Solver — Tool Setup Script for Kali Linux (WSL)
# Run via: wsl -d kali-linux -- bash /path/to/setup_tools.sh
# ============================================================
set -e
BOLD="\e[1m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"

log()  { echo -e "${GREEN}[+]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
err()  { echo -e "${RED}[-]${RESET} $1"; }

log "Starting CTF tool setup in Kali Linux WSL..."

# ─── APT packages ───────────────────────────────────────────
log "Updating package lists..."
sudo apt-get update -qq 2>/dev/null

APT_TOOLS=(
  # Core utilities
  gdb gdb-peda pwndbg
  ltrace strace
  ncat netcat-traditional
  file xxd hexdump
  curl wget
  git python3 python3-pip python3-venv
  ruby-dev
  # Binary analysis
  radare2
  checksec
  binwalk
  patchelf
  upx-ucl
  # Forensics
  foremost
  tshark
  wireshark-common
  exiftool
  dc3dd
  # Steganography
  steghide
  stegseek
  zsteg
  outguess
  # Password / hash
  john
  hashcat
  # Web
  sqlmap
  ffuf
  gobuster
  nikto
  # Crypto / math
  sagemath
  # Archive
  p7zip-full
  unzip
  squashfs-tools
)

log "Installing APT packages (this may take a few minutes)..."
sudo apt-get install -y -qq "${APT_TOOLS[@]}" 2>/dev/null || warn "Some APT packages may have failed — continuing..."

# ─── Python packages ────────────────────────────────────────
log "Installing Python packages..."
PY_TOOLS=(
  pwntools
  pycryptodome
  z3-solver
  requests
  gmpy2
  sympy
  Pillow
  tqdm
  flask-unsign
  pyOpenSSL
  impacket
  volatility3
  ROPgadget
)
pip3 install -q --break-system-packages "${PY_TOOLS[@]}" 2>/dev/null || \
  pip3 install -q "${PY_TOOLS[@]}" 2>/dev/null || \
  warn "Some Python packages may have failed — continuing..."

# ─── Ruby gems ──────────────────────────────────────────────
log "Installing one_gadget (ruby gem)..."
sudo gem install one_gadget 2>/dev/null || warn "one_gadget install failed (non-critical)"

# ─── RsaCtfTool ─────────────────────────────────────────────
if ! command -v RsaCtfTool &>/dev/null; then
  log "Installing RsaCtfTool..."
  git clone -q https://github.com/RsaCtfTool/RsaCtfTool /opt/RsaCtfTool 2>/dev/null || true
  pip3 install -q --break-system-packages -r /opt/RsaCtfTool/requirements.txt 2>/dev/null || true
  sudo ln -sf /opt/RsaCtfTool/RsaCtfTool.py /usr/local/bin/RsaCtfTool 2>/dev/null || true
fi

# ─── GEF for GDB ────────────────────────────────────────────
if ! grep -q "gef" ~/.gdbinit 2>/dev/null; then
  log "Installing GEF (GDB Enhanced Features)..."
  bash -c "$(wget -qO- https://gef.blah.cat/sh 2>/dev/null)" 2>/dev/null || warn "GEF install failed (non-critical)"
fi

# ─── pwndbg ─────────────────────────────────────────────────
if ! command -v pwndbg &>/dev/null && [ ! -d /opt/pwndbg ]; then
  log "Installing pwndbg..."
  git clone -q https://github.com/pwndbg/pwndbg /opt/pwndbg 2>/dev/null || true
  bash /opt/pwndbg/setup.sh 2>/dev/null || warn "pwndbg install failed (non-critical)"
fi

# ─── Ghidra headless (optional, large download) ─────────────
GHIDRA_CHECK=$(command -v ghidra 2>/dev/null || command -v analyzeHeadless 2>/dev/null || ls /opt/ghidra*/support/analyzeHeadless 2>/dev/null | head -1)
if [ -z "$GHIDRA_CHECK" ]; then
  warn "Ghidra not found. To install: sudo apt install ghidra (or download from ghidra.re)"
  warn "Skipping Ghidra auto-install (large package ~1GB)"
fi

# ─── libc-database ──────────────────────────────────────────
if [ ! -d /opt/libc-database ]; then
  log "Setting up libc-database..."
  git clone -q https://github.com/niklasb/libc-database /opt/libc-database 2>/dev/null || warn "libc-database clone failed"
fi

# ─── Create CTF workspace and writeup folder ────────────────
mkdir -p /tmp/ctf
WRITEUP_WIN="/mnt/c/Users/Sreedev M Nair/Documents/CTF-Writeups"
mkdir -p "$WRITEUP_WIN" 2>/dev/null || warn "Could not create writeup folder (may already exist)"

# ─── Final report ───────────────────────────────────────────
echo ""
log "═══════════════════════════════════════"
log "  CTF Tool Setup Complete!"
log "═══════════════════════════════════════"
echo ""
echo "  Tool status:"
for tool in gdb r2 binwalk steghide sqlmap ffuf pwntools; do
  if command -v "$tool" &>/dev/null || python3 -c "import pwn" &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET} $tool"
  else
    echo -e "  ${YELLOW}?${RESET} $tool (may need manual install)"
  fi
done
echo ""
log "Writeup folder: $WRITEUP_WIN"
log "CTF workspace:  /tmp/ctf"
