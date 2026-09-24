# Steganography — bi0s Wiki Methodology

> Source: wiki.bi0s.in/stego | CTF Stego Playbook

## Quick Decision Tree

```
File received →
├── Image (JPEG/PNG/BMP/GIF)?
│   ├── Run exiftool → check metadata/comments
│   ├── Run steghide → check for embedded data
│   ├── Run zsteg (PNG/BMP) → LSB analysis
│   ├── Run binwalk → embedded files
│   └── Check color planes (stegsolve / PIL)
├── Audio (WAV/MP3)?
│   ├── Open in Audacity → spectrogram view
│   ├── Run steghide extract
│   ├── Check DTMF tones (multimon-ng)
│   └── Look for Morse code in spectrogram
├── Text file?
│   ├── Check whitespace stego (stegsnow)
│   ├── Check zero-width characters (Unicode)
│   └── Check every Nth character / first letters
└── Video (MP4/AVI)?
    ├── Extract frames: ffmpeg -i video.mp4 frames/%04d.png
    └── Analyze individual frames as images
```

---

## Phase 1: Universal First Steps

```bash
file ./stego_file
exiftool ./stego_file      # Always run this first
strings -n 5 ./stego_file | grep -iE 'flag|secret|hidden|password'
binwalk ./stego_file       # Check for embedded files
binwalk -e ./stego_file    # Extract if found
xxd ./stego_file | head -8 # Check magic bytes (file may be renamed)
```

---

## Phase 2: Image Steganography

### 2.1 Metadata Hidden Flag
```bash
exiftool image.jpg | grep -iE 'comment|artist|copyright|usercomment|description|title|subject'
# Flag often hidden in: Comment, Copyright, Artist, UserComment, XMP fields
```

### 2.2 Steghide (JPEG/BMP/WAV/AU)
```bash
# Info
steghide info image.jpg

# Extract (no password)
steghide extract -sf image.jpg -p ""

# Extract (known password)
steghide extract -sf image.jpg -p "PASSWORD"

# Brute-force password
stegseek image.jpg /usr/share/wordlists/rockyou.txt
# If no rockyou: sudo apt install wordlists; sudo gzip -d /usr/share/wordlists/rockyou.txt.gz
```

### 2.3 zsteg (PNG, BMP — LSB Analysis)
```bash
zsteg -a image.png           # Try all methods
zsteg image.png              # Default: LSB, 8 bits
zsteg -b 1 -o xy image.png  # LSB, horizontal scan
zsteg -b 1 -o yx image.png  # LSB, vertical scan
zsteg -b 2 image.png         # 2nd bit plane
zsteg -c 1 image.png         # Single color channel
```

### 2.4 outguess (JPEG)
```bash
outguess -r image.jpg output.txt
cat output.txt
```

### 2.5 Stegsolve (GUI) — Color Plane Analysis
```bash
# Install: apt install stegsolve OR download jar:
# wget http://www.caesum.com/handbook/Stegsolve.jar
java -jar Stegsolve.jar   # Open image → use left/right arrows to cycle bit planes
# Look for: bit plane 0 (LSB) of red/green/blue channel containing a QR code or text
```

### 2.6 Manual PIL LSB Analysis
```python
from PIL import Image

def lsb_extract(path, bits=1, channel='R', order='xy'):
    img = Image.open(path).convert('RGB')
    w, h = img.size
    bit_stream = []
    channels = {'R':0,'G':1,'B':2}
    ch_idx = channels[channel]
    pixels = [(x,y) for y in range(h) for x in range(w)] if order=='xy' else [(x,y) for x in range(w) for y in range(h)]
    for (x,y) in pixels:
        val = img.getpixel((x,y))[ch_idx]
        for b in range(bits):
            bit_stream.append((val >> b) & 1)
    chars = []
    for i in range(0, len(bit_stream)-7, 8):
        byte = int(''.join(map(str, bit_stream[i:i+8])), 2)
        if 32 <= byte < 127:
            chars.append(chr(byte))
    return ''.join(chars)

for ch in 'RGB':
    result = lsb_extract('image.png', channel=ch)
    if 'flag' in result.lower():
        print(f"Found in {ch}: {result[:100]}")
    else:
        print(f"{ch}: {result[:50]}")
```

---

## Phase 3: Audio Steganography

### 3.1 Spectrogram Analysis (most common audio stego)
```bash
# Audacity: Open file → View → Spectrogram
# OR: command-line spectrogram
python3 << PYEOF
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import scipy.io.wavfile as wav

rate, data = wav.read('audio.wav')
if data.ndim > 1: data = data[:,0]
plt.figure(figsize=(20,5))
plt.specgram(data, Fs=rate, cmap='inferno')
plt.title('Spectrogram — look for text/QR in frequency domain')
plt.savefig('/tmp/ctf/spectrogram.png', dpi=150)
print('Saved: /tmp/ctf/spectrogram.png')
PYEOF
# View: copy to Windows
cp /tmp/ctf/spectrogram.png "/mnt/c/Users/Sreedev M Nair/Documents/CTF-Writeups/spectrogram.png"
```

### 3.2 DTMF Tone Decoding
```bash
multimon-ng -t wav -a DTMF audio.wav
# Maps to phone keypad digits → may encode flag
```

### 3.3 Morse Code in Audio
```bash
# Listen to audio — short/long beeps = morse
# Or: detect peaks in amplitude envelope
python3 -c "
import scipy.io.wavfile as wav; import numpy as np
r, d = wav.read('audio.wav')
if d.ndim>1: d=d[:,0]
# Energy in 100ms windows
window = int(r * 0.1)
energy = [np.mean(np.abs(d[i:i+window])) for i in range(0, len(d)-window, window)]
threshold = np.mean(energy) * 0.5
morse = ''.join('.' if e > threshold else ' ' for e in energy)
print('Morse signal:', morse[:100])
"
```

### 3.4 MP3Stego / DeepSound
```bash
# If audio was encoded with MP3Stego:
# mp3stego-decode -X audio.mp3 output.txt
# DeepSound: Windows tool, audio may need Windows to decode

# Try steghide on WAV:
steghide extract -sf audio.wav -p ""
```

---

## Phase 4: Text / Whitespace Steganography

### 4.1 Whitespace Stego (stegsnow / SNOW)
```bash
stegsnow -C -p "PASSWORD" message.txt  # decompress hidden message
stegsnow -C message.txt                # try without password
```

### 4.2 Zero-Width Character Stego
```python
# Detect zero-width characters in text
with open('text.txt', 'r', encoding='utf-8') as f:
    content = f.read()

# Zero-width characters: U+200B, U+200C, U+200D, U+FEFF, U+00AD
import unicodedata
zw = [c for c in content if unicodedata.category(c) in ['Cf', 'Cc']]
if zw:
    print(f"Found {len(zw)} zero-width/control chars")
    # Map to binary: e.g., U+200B=0, U+200C=1
    bits = ''.join('0' if ord(c)==0x200B else '1' if ord(c)==0x200C else '' for c in content)
    chars = [chr(int(bits[i:i+8],2)) for i in range(0,len(bits)-7,8) if bits[i:i+8]]
    print('Decoded:', ''.join(chars))
```

### 4.3 Acrostic / Pattern Stego
```python
# First letter of each line / word
with open('text.txt') as f:
    lines = f.readlines()
first_letters = ''.join(line.strip()[0] for line in lines if line.strip())
print("First letters:", first_letters)
# May spell out the flag
```

---

## Phase 5: QR Codes / Barcodes

```bash
# Decode QR code from image
zbarimg image.png 2>/dev/null
python3 -c "
from pyzbar.pyzbar import decode; from PIL import Image
data = decode(Image.open('image.png'))
for d in data: print(d.type, d.data)
" 2>/dev/null || echo "pip3 install pyzbar"
```

---

## Tool Reference

| Tool | Install | Use |
|---|---|---|
| `steghide` | `apt install steghide` | JPEG/BMP/WAV embed/extract |
| `stegseek` | `apt install stegseek` | Brute-force steghide |
| `zsteg` | `apt install zsteg` | PNG/BMP LSB |
| `outguess` | `apt install outguess` | JPEG stego |
| `exiftool` | `apt install libimage-exiftool-perl` | Metadata |
| `stegsnow` | `apt install stegsnow` | Whitespace stego |
| `multimon-ng` | `apt install multimon-ng` | DTMF / radio |
| `binwalk` | `apt install binwalk` | Embedded files |
| Stegsolve | `java -jar Stegsolve.jar` | Color plane GUI |
| Audacity | GUI | Spectrogram visual |
