#!/usr/bin/env bash
# ============================================================
# CTF Solver — Reverse Engineering Helper
# Usage: bash rev_helper.sh <binary>
# ============================================================
BIN="$1"
if [ -z "$BIN" ]; then echo "Usage: rev_helper.sh <binary>"; exit 1; fi

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }
mkdir -p /tmp/ctf/rev_out

hdr "FILE & ARCHITECTURE INFO"
file "$BIN"
readelf -h "$BIN" 2>/dev/null | grep -E "Class|Machine|Type|Entry|Flags" || echo "Not an ELF"

hdr "PACKING CHECK (UPX / high entropy)"
upx -l "$BIN" 2>/dev/null && echo "→ UPX PACKED! Unpack with: upx -d '$BIN'" || echo "Not UPX packed"
echo "Entropy per section:"
python3 -c "
import math, sys
data = open('$BIN','rb').read()
if data:
    from collections import Counter
    freq = Counter(data)
    entropy = -sum(v/len(data)*math.log2(v/len(data)) for v in freq.values())
    print(f'  Full file entropy: {entropy:.3f}/8.0 (>7.5 = likely packed/encrypted)')
" 2>/dev/null

hdr "STRINGS ANALYSIS"
echo "--- Interesting strings ---"
strings -n 5 "$BIN" | grep -iE 'flag|win|correct|wrong|password|key|secret|fail|congrats|success' | head -20
echo ""
echo "--- All strings (first 50) ---"
strings -n 5 "$BIN" | head -50

hdr "SYMBOLS & FUNCTIONS"
nm -n "$BIN" 2>/dev/null | grep " [Tt] " | head -40 || \
objdump -t "$BIN" 2>/dev/null | grep -E "\.text|FUNC" | head -30

hdr "LIBRARY CALLS (ltrace hints)"
objdump -d "$BIN" 2>/dev/null | grep "@plt" | grep -iE 'strcmp|strncmp|memcmp|strcasecmp|check|verify|validate|printf|puts|scanf' | head -20

hdr "DISASSEMBLY (main function)"
objdump -d "$BIN" 2>/dev/null | grep -A 100 "<main>:" | head -60

hdr "ANTI-DEBUG DETECTION"
strings "$BIN" | grep -iE 'ptrace|IsDebuggerPresent|NtQueryInformationProcess|RDTSC|cpuid' | head -10
objdump -d "$BIN" 2>/dev/null | grep -iE 'ptrace|cpuid|rdtsc' | head -10

hdr "GHIDRA HEADLESS ANALYSIS (if available)"
GHIDRA_PATH=$(ls /opt/ghidra*/support/analyzeHeadless 2>/dev/null | head -1)
if [ -n "$GHIDRA_PATH" ]; then
  mkdir -p /tmp/ctf/ghidra_proj
  echo "Running Ghidra headless analysis..."
  "$GHIDRA_PATH" /tmp/ctf/ghidra_proj CTF_Project \
    -import "$BIN" \
    -postScript DecompileAllScript.java \
    -deleteProject 2>/dev/null | tail -20 || echo "Ghidra headless failed"
else
  echo "Ghidra not found. Install: sudo apt install ghidra"
  echo "Alternative: Use Radare2 decompiler (r2dec/rz-ghidra)"
fi

hdr "RADARE2 ANALYSIS"
echo "Running r2 analysis (auto)..."
r2 -A -q -c 'afl; pdf @main' "$BIN" 2>/dev/null | head -80 || echo "radare2 not found: sudo apt install radare2"

hdr "DYNAMIC ANALYSIS HINTS"
echo "--- ltrace (library call trace) ---"
echo "  timeout 5 ltrace -e 'strcmp+memcmp+strncmp' ./$BIN <<< 'test_input' 2>&1 | head -20"
echo ""
echo "--- strace (syscall trace) ---"
echo "  timeout 5 strace ./$BIN <<< 'test_input' 2>&1 | head -20"
echo ""
echo "--- GDB one-liners ---"
echo "  gdb -q -ex 'b strcmp' -ex 'run <<< AAAAA' -ex 'x/s \$rdi' -ex 'x/s \$rsi' -ex 'q' ./$BIN"

hdr "KNOWN PATTERN SEARCH (XOR flag decode)"
python3 << PYEOF
import re, sys

try:
    data = open("$BIN", "rb").read()
except:
    sys.exit(0)

# Look for XOR decode loop patterns (CTF classic)
flag_bytes = [b for b in b"flag{"]
for key in range(256):
    xord = bytes(b ^ key for b in data[:200])
    try:
        decoded = xord.decode('ascii', errors='ignore')
        if 'flag{' in decoded or 'CTF{' in decoded:
            print(f"XOR key 0x{key:02x} reveals flag pattern in first 200 bytes!")
            print(decoded[:100])
    except:
        pass
PYEOF

hdr "REV HELPER COMPLETE"
echo "Manual analysis: radare2 -A $BIN  →  aaa; afl; pdf @main"
echo "Decompiler UI: Ghidra / Cutter (cutter $BIN)"
