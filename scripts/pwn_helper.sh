#!/usr/bin/env bash
# ============================================================
# CTF Solver — Pwn / Binary Exploitation Helper
# Usage: bash pwn_helper.sh <binary> [libc.so]
# ============================================================
BIN="$1"
LIBC="$2"
if [ -z "$BIN" ]; then echo "Usage: pwn_helper.sh <binary> [libc.so]"; exit 1; fi

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }

hdr "CHECKSEC ANALYSIS"
checksec --file="$BIN"

hdr "ARCHITECTURE"
file "$BIN"
readelf -h "$BIN" 2>/dev/null | grep -E "Class|Machine|Type"

hdr "FUNCTION LIST"
nm -n "$BIN" 2>/dev/null | grep -v " U " | grep " T " || objdump -t "$BIN" 2>/dev/null | grep -E "\.text" | head -30

hdr "DANGEROUS / INTERESTING FUNCTIONS"
objdump -d "$BIN" 2>/dev/null | grep -iE "call.*<(gets|scanf|read|recv|fgets|strcpy|sprintf|system|exec|popen|win|flag|shell|backdoor)@?>" | head -30

hdr "PLT / GOT ENTRIES"
objdump -d "$BIN" 2>/dev/null | grep "@plt" | head -20

hdr "STRINGS WITH FLAG/SHELL HINTS"
strings "$BIN" | grep -iE "flag|win|shell|password|secret|key|/bin/sh|/bin/bash" | head -20

hdr "ROP GADGETS (top 30)"
ROPgadget --binary "$BIN" 2>/dev/null | head -30 || echo "ROPgadget not installed: pip3 install ROPgadget"

hdr "ONE_GADGET (libc RCE gadgets)"
if [ -n "$LIBC" ]; then
  one_gadget "$LIBC" 2>/dev/null || echo "one_gadget not installed: gem install one_gadget"
else
  echo "No libc provided. Try: one_gadget /lib/x86_64-linux-gnu/libc.so.6"
fi

hdr "PLTGOT ADDRESSES (for GOT overwrite / leak)"
objdump -R "$BIN" 2>/dev/null | head -30

hdr "OFFSET TO CRASH (cyclic pattern hint)"
echo "Run in GDB + pwndbg: cyclic 200 | ./binary  → then: cyclic -l ADDR_IN_RSP"
echo "Or use pwntools: from pwn import *; print(cyclic_find(0x6161616b))"

hdr "PWNTOOLS TEMPLATE"
ARCH=$(file "$BIN" | grep -o "64-bit\|32-bit" | head -1 | tr -d '-' | tr ' ' '_')
CONTEXT="amd64"
if echo "$ARCH" | grep -q "32"; then CONTEXT="i386"; fi

cat << TEMPLATE
─────────────────────────────────────────────────
from pwn import *

binary  = ELF("$BIN")
$([ -n "$LIBC" ] && echo "libc = ELF(\"$LIBC\")")
context.binary = binary
context.log_level = 'debug'  # Change to 'info' to reduce noise

# Local: io = process([binary.path])
# Remote: io = remote("HOST", PORT)
io = process([binary.path])

# GDB: Run with: gdb.attach(io, gdbscript="b *main+offset\nc")

payload = b"A" * OFFSET  # Find offset with cyclic
payload += p64(RETURN_ADDR)  # ret2win / one_gadget / ROP chain

io.sendlineafter(b"PROMPT", payload)
io.interactive()
─────────────────────────────────────────────────
TEMPLATE

hdr "LIBC VERSION IDENTIFICATION"
if [ -n "$LIBC" ]; then
  strings "$LIBC" | grep "GNU C Library" | head -3
  strings "$LIBC" | grep "GLIBC_" | sort -V | tail -5
fi
echo "Online libc lookup: https://libc.rip  |  https://libc.blukat.me"
