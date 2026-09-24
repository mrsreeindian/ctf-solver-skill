#!/usr/bin/env bash
# ============================================================
# CTF Solver — Cryptography Helper
# Usage: bash crypto_helper.sh <file_or_text> [hint]
# ============================================================
INPUT="$1"
HINT="${2:-}"
if [ -z "$INPUT" ]; then echo "Usage: crypto_helper.sh <file_or_ciphertext_file> [hint]"; exit 1; fi

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }
mkdir -p /tmp/ctf/crypto_out

# Determine if input is a file or a string
if [ -f "$INPUT" ]; then
  CIPHERTEXT=$(cat "$INPUT")
else
  CIPHERTEXT="$INPUT"
fi

echo "Input (first 200 chars): ${CIPHERTEXT:0:200}"

hdr "ENCODING DETECTION & DECODE"
python3 << PYEOF
import base64, binascii, urllib.parse, re, sys

ct = """$CIPHERTEXT"""

# Base64
try:
    dec = base64.b64decode(ct.strip()).decode(errors='replace')
    if any(c.isprintable() for c in dec[:20]):
        print(f"[BASE64] Decoded: {dec[:200]}")
except: pass

# Hex
try:
    if re.match(r'^[0-9a-fA-F\s]+$', ct.strip()):
        dec = bytes.fromhex(ct.strip().replace(' ','').replace('\n','')).decode(errors='replace')
        print(f"[HEX] Decoded: {dec[:200]}")
except: pass

# URL encoding
try:
    dec = urllib.parse.unquote(ct.strip())
    if dec != ct.strip():
        print(f"[URL] Decoded: {dec[:200]}")
except: pass

# ROT13
import codecs
rot = codecs.encode(ct, 'rot_13')
if re.search(r'flag\{|CTF\{|bi0s', rot, re.I):
    print(f"[ROT13] Match found: {rot[:200]}")

# Try all ROT variants
for i in range(1, 26):
    rotated = ''.join(chr((ord(c)-65+i)%26+65) if c.isupper() else chr((ord(c)-97+i)%26+97) if c.islower() else c for c in ct)
    if re.search(r'flag\{|CTF\{|bi0s|the flag', rotated, re.I):
        print(f"[ROT{i}] Match found: {rotated[:100]}")

# XOR single byte
raw = ct.encode() if isinstance(ct, str) else ct
for key in range(256):
    xord = bytes(b ^ key for b in raw[:min(len(raw),200)])
    dec = xord.decode(errors='replace')
    if re.search(r'flag\{|CTF\{|bi0s', dec, re.I):
        print(f"[XOR key=0x{key:02x}] Match: {dec[:100]}")
PYEOF

hdr "HASH IDENTIFICATION"
python3 << PYEOF
import re
ct = """$CIPHERTEXT""".strip()
hashlen = len(ct.replace(' ','').replace('\n',''))
print(f"Length: {len(ct)}, Hex chars: {all(c in '0123456789abcdefABCDEF' for c in ct.replace(' ',''))}")
if re.match(r'^[0-9a-fA-F]{32}$', ct): print("→ MD5 hash")
elif re.match(r'^[0-9a-fA-F]{40}$', ct): print("→ SHA1 hash")
elif re.match(r'^[0-9a-fA-F]{64}$', ct): print("→ SHA256 hash")
elif re.match(r'^[0-9a-fA-F]{96}$', ct): print("→ SHA384 hash")
elif re.match(r'^[0-9a-fA-F]{128}$', ct): print("→ SHA512 hash")
elif re.match(r'^\$2[aby]\$', ct): print("→ bcrypt hash")
elif re.match(r'^\$1\$', ct): print("→ MD5 crypt hash")
elif re.match(r'^\$6\$', ct): print("→ SHA512 crypt hash")
PYEOF

echo "Hash cracking:"
echo "  hashcat -m 0 '$INPUT' /usr/share/wordlists/rockyou.txt      # MD5"
echo "  hashcat -m 100 '$INPUT' /usr/share/wordlists/rockyou.txt    # SHA1"
echo "  john --wordlist=/usr/share/wordlists/rockyou.txt '$INPUT'"

hdr "RSA ATTACK (if RSA params found in file)"
if [ -f "$INPUT" ]; then
  python3 << PYEOF
import re
with open("$INPUT") as f:
    content = f.read()

# Look for RSA parameters
n_match = re.search(r'[nN]\s*=\s*([0-9]+)', content)
e_match = re.search(r'[eE]\s*=\s*([0-9]+)', content)
c_match = re.search(r'[cC]\s*=\s*([0-9]+)', content)
p_match = re.search(r'[pP]\s*=\s*([0-9]+)', content)
q_match = re.search(r'[qQ]\s*=\s*([0-9]+)', content)

if n_match: print(f"Found N (len={len(n_match.group(1))} digits)")
if e_match: print(f"Found e = {e_match.group(1)}")
if c_match: print(f"Found c (len={len(c_match.group(1))} digits)")
if p_match and q_match:
    print(f"Found p and q! Can compute private key directly.")
    from Crypto.Util.number import inverse, long_to_bytes
    try:
        p, q = int(p_match.group(1)), int(q_match.group(1))
        n = p * q
        e = int(e_match.group(1)) if e_match else 65537
        c = int(c_match.group(1)) if c_match else None
        phi = (p-1)*(q-1)
        d = inverse(e, phi)
        if c:
            m = pow(c, d, n)
            flag = long_to_bytes(m)
            print(f"Decrypted: {flag}")
    except Exception as ex:
        print(f"RSA compute error: {ex}")
elif n_match:
    print("Run RsaCtfTool for automated attacks:")
    print(f"  RsaCtfTool --publickey <key.pem> --attack all --uncipherfile <ciphertext>")
    print(f"  RsaCtfTool -n N -e E --uncipher C --attack all")
PYEOF
fi

hdr "CLASSICAL CIPHER ANALYSIS"
python3 << PYEOF
import re
from collections import Counter

ct = """$CIPHERTEXT""".strip()
letters = [c.upper() for c in ct if c.isalpha()]

if letters:
    freq = Counter(letters)
    total = len(letters)
    print("Letter frequencies (top 8):")
    for char, cnt in sorted(freq.items(), key=lambda x: -x[1])[:8]:
        bar = '█' * int(cnt/total*40)
        print(f"  {char}: {cnt:3d} ({cnt/total*100:.1f}%) {bar}")
    print()
    print("English most frequent: E T A O I N S H R")
    print("If frequency matches → Substitution / Caesar cipher")
    print()
    # IC (Index of Coincidence) for Vigenere key length hint
    N = len(letters)
    ic = sum(freq[c]*(freq[c]-1) for c in freq) / (N*(N-1)) if N > 1 else 0
    print(f"Index of Coincidence: {ic:.4f}")
    print("  IC ≈ 0.065 → English (simple substitution)")
    print("  IC ≈ 0.038 → Random / Vigenere with longer key")
    if ic > 0.06:
        print("  → Try Caesar / simple substitution")
    elif 0.04 < ic < 0.06:
        print("  → Try Vigenere / Beaufort")
else:
    print("No alphabetic characters found — may be binary/encoded")
PYEOF

hdr "AES ECB BLOCK ANALYSIS"
python3 << PYEOF
import base64, binascii, re
ct = """$CIPHERTEXT""".strip()

# Try to decode as hex or base64 to get bytes
raw = None
try:
    raw = bytes.fromhex(ct.replace(' ','').replace('\n',''))
    print("Input decoded as hex")
except:
    try:
        raw = base64.b64decode(ct)
        print("Input decoded as base64")
    except:
        raw = ct.encode()

if raw:
    print(f"Total bytes: {len(raw)}")
    print(f"Block size check (16-byte AES blocks): {len(raw) % 16 == 0}")
    
    # Check for ECB repeating blocks
    blocks_16 = [raw[i:i+16] for i in range(0, len(raw)-15, 16)]
    repeats = len(blocks_16) - len(set(blocks_16))
    if repeats > 0:
        print(f"⚠ ECB DETECTED: {repeats} repeating 16-byte blocks!")
        print("→ ECB block analysis / cut-and-paste attack possible")
    else:
        print(f"No repeating blocks (blocks analyzed: {len(blocks_16)})")
        print("→ May be CBC / CTR / stream cipher")
PYEOF

hdr "USEFUL CRYPTO COMMANDS"
echo "CyberChef (web): https://gchq.github.io/CyberChef/"
echo "Online hash: https://crackstation.net"
echo "RSA tool:    RsaCtfTool --publickey key.pem --attack all --uncipherfile cipher"
echo "Z3 solver:   python3 -c \"from z3 import *; x=Int('x'); s=Solver(); s.add(x>0); print(s.check(), s.model())\""
echo "SageMath:    sage -c 'factor(N)'  |  sage -c 'discrete_log(...)'"
