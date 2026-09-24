#!/usr/bin/env bash
# ============================================================
# CTF Solver — Forensics Helper
# Usage: bash forensics_helper.sh <file> [type: pcap|memory|image|disk]
# ============================================================
FILE="$1"
TYPE="${2:-auto}"
if [ -z "$FILE" ]; then echo "Usage: forensics_helper.sh <file> [pcap|memory|image|disk|auto]"; exit 1; fi

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }
mkdir -p /tmp/ctf/forensics_out

hdr "FILE IDENTIFICATION"
file "$FILE"
exiftool "$FILE" 2>/dev/null | head -20

# Auto-detect type
if [ "$TYPE" = "auto" ]; then
  FTYPE=$(file "$FILE")
  if echo "$FTYPE" | grep -qiE "pcap|tcpdump|capture"; then TYPE="pcap"
  elif echo "$FTYPE" | grep -qiE "memory dump|crash dump|Windows"; then TYPE="memory"
  elif echo "$FTYPE" | grep -qiE "filesystem|partition|disk|FAT|ext[234]"; then TYPE="disk"
  elif echo "$FTYPE" | grep -qiE "JPEG|PNG|image|GIF|TIFF"; then TYPE="image"
  else TYPE="generic"
  fi
  echo "Auto-detected type: $TYPE"
fi

case "$TYPE" in
  pcap)
    hdr "NETWORK FORENSICS (PCAP)"
    echo "--- PROTOCOL SUMMARY ---"
    tshark -r "$FILE" -q -z io,phs 2>/dev/null | head -30

    echo "--- TOP CONVERSATIONS ---"
    tshark -r "$FILE" -q -z conv,tcp 2>/dev/null | head -20
    tshark -r "$FILE" -q -z conv,udp 2>/dev/null | head -10

    echo "--- HTTP REQUESTS ---"
    tshark -r "$FILE" -Y "http.request" -T fields -e http.host -e http.request.uri 2>/dev/null | head -20

    echo "--- HTTP RESPONSES (look for flag in body) ---"
    tshark -r "$FILE" -Y "http" -T fields -e http.file_data 2>/dev/null | strings | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10

    echo "--- DNS QUERIES ---"
    tshark -r "$FILE" -Y "dns.flags.response == 0" -T fields -e dns.qry.name 2>/dev/null | head -20

    echo "--- FTP / CREDENTIALS ---"
    tshark -r "$FILE" -Y "ftp" -T fields -e ftp.request.command -e ftp.request.arg 2>/dev/null | head -20

    echo "--- EXTRACT ALL HTTP OBJECTS ---"
    tshark -r "$FILE" --export-objects "http,/tmp/ctf/forensics_out" 2>/dev/null && \
      echo "Objects extracted to /tmp/ctf/forensics_out/" || echo "No HTTP objects"

    echo "--- TCP STREAMS (first 3) ---"
    for i in 0 1 2; do
      echo "== Stream $i =="
      tshark -r "$FILE" -q -z follow,tcp,ascii,$i 2>/dev/null | head -20
    done

    echo "--- FLAG SEARCH IN ALL PACKETS ---"
    tshark -r "$FILE" -T fields -e data.text 2>/dev/null | strings | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    ;;

  memory)
    hdr "MEMORY FORENSICS (Volatility 3)"
    echo "Profile detection:"
    vol3 -f "$FILE" windows.info 2>/dev/null || \
    python3 -m volatility3 -f "$FILE" windows.info 2>/dev/null || \
    echo "Trying linux profile..."
    vol3 -f "$FILE" linux.bash 2>/dev/null | head -20

    echo "--- PROCESS LIST ---"
    vol3 -f "$FILE" windows.pslist 2>/dev/null | head -30 || \
    python3 -m volatility3 -f "$FILE" windows.pslist 2>/dev/null | head -30

    echo "--- CMDLINE ---"
    vol3 -f "$FILE" windows.cmdline 2>/dev/null | head -30

    echo "--- NETWORK CONNECTIONS ---"
    vol3 -f "$FILE" windows.netstat 2>/dev/null | head -20

    echo "--- REGISTRY HIVES ---"
    vol3 -f "$FILE" windows.registry.hivelist 2>/dev/null | head -20

    echo "--- DUMP NOTEPAD / SUSPICIOUS PROCESSES ---"
    echo "To dump a process: vol3 -f '$FILE' windows.memmap --pid PID --dump"
    echo "To search strings: vol3 -f '$FILE' windows.strings --strings-file /tmp/ctf/strings.txt"

    echo "--- STRINGS SEARCH IN DUMP ---"
    strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    strings "$FILE" | grep -iE 'flag|password|secret' | head -20
    ;;

  image)
    hdr "IMAGE / FILE CARVING (Forensics)"
    echo "--- BINWALK EXTRACTION ---"
    binwalk -e "$FILE" -C /tmp/ctf/forensics_out/ 2>/dev/null
    echo "Extracted to /tmp/ctf/forensics_out/"

    echo "--- FOREMOST CARVING ---"
    foremost -i "$FILE" -o /tmp/ctf/forensics_out/foremost/ 2>/dev/null
    echo "Carved files:"
    find /tmp/ctf/forensics_out/foremost/ -type f 2>/dev/null | head -20

    echo "--- STRINGS & FLAG SEARCH ---"
    strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    ;;

  disk)
    hdr "DISK FORENSICS"
    echo "--- PARTITION TABLE ---"
    fdisk -l "$FILE" 2>/dev/null || parted "$FILE" print 2>/dev/null

    echo "--- MOUNT & EXPLORE ---"
    echo "To mount: sudo mount -o loop,ro '$FILE' /mnt/forensics_mount"
    echo "Then: find /mnt/forensics_mount -name '*.txt' -o -name '*.log' 2>/dev/null | head -20"

    echo "--- STRINGS SEARCH ---"
    strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    strings "$FILE" | grep -iE 'flag|secret|password|hidden' | head -20
    ;;

  *)
    hdr "GENERIC FORENSICS ANALYSIS"
    echo "--- BINWALK ---"
    binwalk "$FILE"
    echo "--- STRINGS ---"
    strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
    strings "$FILE" | head -40
    ;;
esac

hdr "FORENSICS ANALYSIS COMPLETE"
echo "Output directory: /tmp/ctf/forensics_out/"
ls /tmp/ctf/forensics_out/ 2>/dev/null | head -20
