# Forensics — bi0s Wiki Methodology

> Source: wiki.bi0s.in/forensics | CTF Forensics Playbook

## Phase 1: File Identification & Carving

### 1.1 Identify File Type
```bash
file ./challenge_file
exiftool ./challenge_file   # metadata
xxd ./challenge_file | head -8  # magic bytes
```

### Common Magic Bytes

| Magic | Format |
|---|---|
| `FF D8 FF` | JPEG |
| `89 50 4E 47` | PNG |
| `47 49 46 38` | GIF |
| `50 4B 03 04` | ZIP/DOCX/XLSX |
| `1F 8B 08` | GZIP |
| `7F 45 4C 46` | ELF |
| `52 61 72 21` | RAR |
| `25 50 44 46` | PDF |
| `4D 5A` | PE/EXE |
| `4F 67 67 53` | OGG |

### 1.2 Binwalk — Embedded File Extraction
```bash
binwalk ./file              # scan for embedded files
binwalk -e ./file           # extract all embedded files
binwalk -e --dd='.*' ./file # extract everything
binwalk -E ./file           # entropy analysis

# Manual extraction at offset:
dd if=./file of=./extracted skip=OFFSET bs=1 count=SIZE
```

### 1.3 Foremost — File Carving
```bash
foremost -i ./file -o ./carved_out/
ls ./carved_out/
```

### 1.4 Strings Search
```bash
strings ./file | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}'  # flag pattern
strings ./file | grep -iE 'flag|secret|hidden|password'
strings -n 4 ./file | head -100
```

---

## Phase 2: Image Forensics

### 2.1 Metadata Analysis
```bash
exiftool image.jpg    # EXIF data (GPS, timestamps, comments, artist)
# Look for: GPS coordinates, UserComment, Copyright, Artist, Software

# Hidden EXIF comment:
exiftool -Comment image.jpg

# XMP data:
exiftool -X image.jpg
```

### 2.2 JPEG / PNG Hidden Data
```bash
# Steghide (JPEG)
steghide extract -sf image.jpg -p ""         # try empty password
steghide info image.jpg                       # check capacity/embedded

# Stegseek (brute force)
stegseek image.jpg /usr/share/wordlists/rockyou.txt

# zsteg (PNG)
zsteg -a image.png        # all methods
zsteg -b 1 -o xy image.png  # LSB horizontal
zsteg -b 1 -o yx image.png  # LSB vertical

# LSB Python check:
python3 -c "
from PIL import Image
img = Image.open('image.png').convert('RGB')
bits = []
for y in range(img.size[1]):
    for x in range(img.size[0]):
        bits.extend([v & 1 for v in img.getpixel((x, y))])
chars = [chr(int(''.join(map(str,bits[i:i+8])),2)) for i in range(0,len(bits)-7,8)]
print(''.join(c for c in chars if 32<=ord(c)<127)[:200])
"
```

### 2.3 Corrupted File Repair
```bash
# PNG CRC fix (if header corrupted):
pngcheck -v image.png    # diagnose
# Recalculate CRC with Python or 'pngcsum'

# JPEG repair:
jpegoptim image.jpg  # or use GIMP
```

---

## Phase 3: Network Forensics (PCAP)

### 3.1 Wireshark / tshark
```bash
# Protocol summary
tshark -r capture.pcap -q -z io,phs

# Top conversations
tshark -r capture.pcap -q -z conv,tcp

# HTTP requests
tshark -r capture.pcap -Y "http.request" -T fields \
       -e http.host -e http.request.uri -e http.request.method

# HTTP response data (flag in body)
tshark -r capture.pcap -Y "http" -T fields -e http.file_data | strings | grep -iE 'flag\{'

# Export HTTP objects
tshark -r capture.pcap --export-objects "http,./http_objects/"

# Follow TCP stream (stream 0)
tshark -r capture.pcap -q -z follow,tcp,ascii,0

# Filter by IP
tshark -r capture.pcap -Y "ip.addr == 192.168.1.1"

# Extract credentials (FTP/HTTP Basic)
tshark -r capture.pcap -Y "ftp" -T fields -e ftp.request.command -e ftp.request.arg
tshark -r capture.pcap -Y "http.authorization" -T fields -e http.authorization
```

### 3.2 DNS Exfiltration Detection
```bash
tshark -r capture.pcap -Y "dns" -T fields -e dns.qry.name | head -30
# Flag might be base64-encoded in DNS queries: flag.data.attacker.com
# Decode subdomain: echo "ZmxhZ3t0ZXN0fQ" | base64 -d
```

### 3.3 TLS / Encrypted Traffic
```bash
# If you have the private key:
# Wireshark → Edit → Preferences → Protocols → TLS → RSA keys
# Or: pre-master secret log file (SSLKEYLOGFILE)

# Extract master secret from memory dump first
```

---

## Phase 4: Memory Forensics (Volatility 3)

### 4.1 Basic Commands
```bash
# Profile detection (Volatility 3 — no profile needed)
vol3 -f memory.dmp windows.info     # Windows
vol3 -f memory.dmp linux.bash       # Linux bash history

# Process list
vol3 -f memory.dmp windows.pslist
vol3 -f memory.dmp windows.pstree

# Suspicious processes
vol3 -f memory.dmp windows.cmdline   # command line args
vol3 -f memory.dmp windows.netscan   # network connections

# Dump specific process memory
vol3 -f memory.dmp windows.memmap --pid PID --dump

# Registry
vol3 -f memory.dmp windows.registry.hivelist
vol3 -f memory.dmp windows.registry.printkey --key "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"

# Files
vol3 -f memory.dmp windows.filescan | grep -i flag
vol3 -f memory.dmp windows.dumpfiles --physaddr ADDR

# Clipboard / screenshots
vol3 -f memory.dmp windows.clipboard
vol3 -f memory.dmp windows.screenshot
```

### 4.2 Strings in Memory Dump
```bash
strings memory.dmp | grep -iE 'flag\{|CTF\{|bi0s\{' | head -20
strings -e l memory.dmp | grep -iE 'flag' | head -20  # Unicode strings
```

---

## Phase 5: Disk / Archive Forensics

### 5.1 ZIP / Archive Analysis
```bash
# Inspect without extracting
zipinfo -v archive.zip
7z l archive.zip

# Crack ZIP password
zip2john archive.zip > hash.txt
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt

# Fix corrupted ZIP
zip -FF archive.zip --out fixed.zip
```

### 5.2 Deleted File Recovery
```bash
# Mount disk image
sudo mount -o loop,ro disk.img /mnt/forensics/
ls /mnt/forensics/

# Recover deleted files (ext4)
ext4magic disk.img -a    # recover all deleted

# testdisk
testdisk disk.img   # menu-driven recovery
```

---

## Quick Reference

| Tool | Purpose |
|---|---|
| `binwalk -e` | Extract embedded files |
| `foremost` | Carve files by magic |
| `exiftool` | Metadata extraction |
| `tshark` | CLI Wireshark / PCAP analysis |
| `vol3` | Memory forensics |
| `steghide` | JPEG stego extraction |
| `zsteg` | PNG/BMP LSB stego |
| `strings` | Quick plaintext search |
| `xxd` | Hex dump / magic bytes |
