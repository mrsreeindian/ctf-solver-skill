#!/usr/bin/env bash
# ============================================================
# CTF Solver — Steganography Helper
# Usage: bash stego_helper.sh <file> [password]
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/detect_platform.sh" ]; then
  source "$SCRIPT_DIR/detect_platform.sh"
fi

FILE="$1"
PASS="${2:-}"
if [ -z "$FILE" ]; then echo "Usage: stego_helper.sh <file> [password]"; exit 1; fi

WRITEUP_TARGET="${WRITEUP_DIR:-/tmp/ctf}"
mkdir -p "$WRITEUP_TARGET" /tmp/ctf 2>/dev/null || true

CYAN="\e[36m"; GREEN="\e[32m"; YELLOW="\e[33m"; RESET="\e[0m"
hdr() { echo -e "\n${CYAN}══════ $1 ══════${RESET}\n"; }
EXT="${FILE##*.}"
LOWER_EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

hdr "FILE INFO"
file "$FILE"
exiftool "$FILE" 2>/dev/null | head -25

hdr "STRINGS SEARCH (flag patterns)"
strings "$FILE" | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}' | head -10
strings "$FILE" | grep -iE 'flag|secret|hidden|password|key' | head -10

hdr "BINWALK (embedded files)"
binwalk "$FILE"
echo ""
echo "To extract: binwalk -e '$FILE'"

if [[ "$LOWER_EXT" =~ ^(jpg|jpeg|png|bmp|gif|tiff|webp)$ ]]; then
  hdr "IMAGE: STEGHIDE EXTRACTION"
  if [ -n "$PASS" ]; then
    steghide extract -sf "$FILE" -p "$PASS" 2>&1 || echo "Steghide extraction failed with provided password"
  else
    steghide extract -sf "$FILE" -p "" 2>&1 || echo "No empty-password steghide data (try with a password)"
    echo ""
    echo "Brute-force passwords: stegseek '$FILE' /usr/share/wordlists/rockyou.txt"
  fi

  hdr "IMAGE: ZSTEG ANALYSIS (PNG/BMP LSB)"
  if [[ "$LOWER_EXT" =~ ^(png|bmp)$ ]]; then
    zsteg -a "$FILE" 2>/dev/null | head -40 || echo "zsteg not installed: sudo apt install zsteg"
  else
    echo "zsteg best for PNG/BMP. Current: $LOWER_EXT"
  fi

  hdr "IMAGE: STEGSOLVE COLOR PLANES"
  echo "Manual: stegsolve (Java GUI) → analyze color bit planes"
  echo "Quick LSB check (Python):"
  python3 - "$FILE" << 'PYEOF'
import sys
try:
    from PIL import Image
    f = sys.argv[1] if len(sys.argv) > 1 else None
    if not f:
        print("  [Run with file arg to auto-check LSB]")
    else:
        img = Image.open(f).convert("RGB")
        w, h = img.size
        bits = []
        for y in range(min(h, 50)):
            for x in range(w):
                r, g, b = img.getpixel((x, y))
                bits += [r & 1, g & 1, b & 1]
        chars = [chr(int(''.join(map(str, bits[i:i+8])), 2)) for i in range(0, len(bits)-7, 8)]
        result = ''.join(c for c in chars if 32 <= ord(c) < 127)
        print(f"  LSB preview (first 100 chars): {result[:100]}")
except Exception as e:
    print(f"  PIL check failed: {e}")
PYEOF
fi

if [[ "$LOWER_EXT" =~ ^(wav|mp3|ogg|flac|aiff)$ ]]; then
  hdr "AUDIO: MP3STEGO / STEGHIDE"
  steghide extract -sf "$FILE" -p "${PASS:-}" 2>&1 || echo "No steghide data in audio"

  hdr "AUDIO: SPECTROGRAM HINT"
  echo "View spectrogram for hidden data: Audacity → Analyze → Spectrogram"
  python3 - "$FILE" "$WRITEUP_TARGET/spectrogram.png" << 'PYEOF'
import sys
try:
    import scipy.io.wavfile as wav
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    audio_path = sys.argv[1]
    out_path = sys.argv[2]
    rate, data = wav.read(audio_path)
    if data.ndim > 1:
        data = data[:, 0]
    plt.figure(figsize=(12, 4))
    plt.specgram(data, Fs=rate)
    plt.savefig(out_path)
    print(f"  Spectrogram generated: {out_path}")
except Exception as e:
    print(f"  Spectrogram generation skipped / failed: {e}")
PYEOF
  echo "Spectrogram location: $WRITEUP_TARGET/spectrogram.png"

  hdr "AUDIO: DTMF TONES"
  echo "Decode DTMF: multimon-ng -t wav -a DTMF '$FILE' 2>/dev/null"
  multimon-ng -t wav -a DTMF "$FILE" 2>/dev/null | head -20 || echo "multimon-ng not installed: sudo apt install multimon-ng"
fi

hdr "OUTGUESS (JPEG steganography)"
outguess -r "$FILE" /tmp/ctf/outguess_out.txt 2>/dev/null && cat /tmp/ctf/outguess_out.txt || echo "outguess found nothing"

hdr "WHITESPACE STEGANOGRAPHY CHECK"
cat "$FILE" | cat -A | grep -c "\^I\|\\ \$" | xargs echo "Trailing whitespace/tab lines:"
echo "Decode SNOW: stegsnow -C '$FILE'"

hdr "BASE64 / ENCODED DATA CHECK"
strings "$FILE" | grep -iE '^[A-Za-z0-9+/]{20,}={0,2}$' | while read -r b64; do
  decoded=$(echo "$b64" | base64 -d 2>/dev/null | strings | head -3)
  [ -n "$decoded" ] && echo "BASE64 decoded: $decoded"
done | head -10

hdr "STEGO BRUTE-FORCE (if password unknown)"
echo "stegseek '$FILE' /usr/share/wordlists/rockyou.txt"
if [ -f /usr/share/wordlists/rockyou.txt ] || [ -f /usr/share/wordlists/rockyou.txt.gz ]; then
  echo "rockyou.txt found — run above command"
else
  echo "rockyou.txt not found. Install: sudo apt install wordlists; sudo gzip -d /usr/share/wordlists/rockyou.txt.gz"
fi
