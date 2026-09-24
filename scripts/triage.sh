#!/usr/bin/env bash
# ============================================================
# CTF Solver — Auto-Triage Script
# Usage: bash triage.sh <file_path>
# ============================================================
FILE="$1"
if [ -z "$FILE" ]; then echo "Usage: triage.sh <file>"; exit 1; fi
if [ ! -f "$FILE" ]; then echo "File not found: $FILE"; exit 1; fi

BOLD="\e[1m"; CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
sep() { echo -e "${CYAN}══════════════════════════════════════════════${RESET}"; }
hdr() { sep; echo -e "${BOLD}${GREEN}  $1${RESET}"; sep; }

hdr "FILE TYPE & BASIC INFO"
file "$FILE"
echo "Size: $(du -sh "$FILE" | cut -f1)"
echo "MD5:  $(md5sum "$FILE" | cut -d' ' -f1)"
echo "SHA1: $(sha1sum "$FILE" | cut -d' ' -f1)"

hdr "CHECKSEC (ELF Protections)"
checksec --file="$FILE" 2>/dev/null || echo "Not an ELF or checksec not installed"

hdr "STRINGS (top 60, length >= 6)"
strings -n 6 "$FILE" | head -60

hdr "FLAG PATTERN SEARCH"
strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]{1,60}\}' | head -20
echo "(checking for: flag{}, CTF{}, HTB{}, picoCTF{}, bi0sCTF{}, etc.)"

hdr "ENTROPY & BINWALK SCAN"
binwalk "$FILE" 2>/dev/null || echo "binwalk not installed"

hdr "EXIFTOOL METADATA"
exiftool "$FILE" 2>/dev/null | head -30 || echo "exiftool not installed"

hdr "HEX DUMP (first 256 bytes)"
xxd "$FILE" | head -16

hdr "FILE SYMBOLS (nm)"
nm "$FILE" 2>/dev/null | grep -v " U " | head -30 || echo "No symbols / not an ELF"

hdr "DYNAMIC IMPORTS (objdump)"
objdump -p "$FILE" 2>/dev/null | grep -A5 "Dynamic Section" | head -20 || echo "Not an ELF"

hdr "DANGEROUS FUNCTIONS"
objdump -d "$FILE" 2>/dev/null | grep -iE "call.*<(gets|scanf|strcpy|sprintf|system|exec|popen|fgets|read|recv)@" | head -20 || echo "None found or not an ELF"

hdr "TRIAGE COMPLETE"
echo "File: $FILE"
echo ""
echo "SUGGESTED CATEGORIES:"
FTYPE=$(file "$FILE")
if echo "$FTYPE" | grep -q "ELF"; then
  echo "  → Likely: PWN or REV (ELF binary detected)"
  echo "    Run: scripts/pwn_helper.sh $FILE  (if exploitation)"
  echo "         scripts/rev_helper.sh $FILE  (if reversing)"
elif echo "$FTYPE" | grep -qiE "JPEG|PNG|BMP|GIF|TIFF|image"; then
  echo "  → Likely: STEGO or FORENSICS (image file)"
  echo "    Run: scripts/stego_helper.sh $FILE"
elif echo "$FTYPE" | grep -qiE "audio|WAVE|MPEG|mp3|ogg"; then
  echo "  → Likely: STEGO (audio file)"
  echo "    Run: scripts/stego_helper.sh $FILE"
elif echo "$FTYPE" | grep -qiE "pcap|tcpdump"; then
  echo "  → Likely: FORENSICS (network capture)"
  echo "    Run: scripts/forensics_helper.sh $FILE"
elif echo "$FTYPE" | grep -qiE "ASCII|text|UTF"; then
  echo "  → Likely: CRYPTO or WEB (text/ciphertext)"
  echo "    Run: scripts/crypto_helper.sh $FILE"
elif echo "$FTYPE" | grep -qiE "data|binary|firmware"; then
  echo "  → Likely: FORENSICS or HARDWARE (binary data)"
fi
