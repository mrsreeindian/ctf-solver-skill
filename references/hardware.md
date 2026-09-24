# Hardware — bi0s Wiki Methodology

> Source: wiki.bi0s.in/hardware | CTF Hardware Playbook

> [!NOTE]
> Physical hardware challenges (JTAG probing, power analysis) require physical equipment.
> This playbook focuses on what CAN be automated: firmware analysis, protocol simulation,
> embedded binary reversing, and CTF-style hardware crypto challenges.

## Phase 1: Firmware Analysis

### 1.1 Initial Triage
```bash
file firmware.bin
binwalk firmware.bin            # Scan for signatures
binwalk -E firmware.bin         # Entropy (packed vs structured)
strings firmware.bin | head -50
xxd firmware.bin | head -16     # Magic bytes
```

### 1.2 Extraction
```bash
# Extract all embedded content
binwalk -e firmware.bin -C ./extracted/

# Check extracted content
ls -la ./extracted/
find ./extracted/ -type f | head -30
file ./extracted/**/*

# JFFS2 filesystem (common in routers)
sudo apt install mtd-utils
jefferson ./extracted/*.jffs2 -d ./jffs2_out/

# SquashFS (very common in embedded Linux)
unsquashfs ./extracted/*.squashfs

# UBIFS
ubireader_extract_images firmware.bin
```

### 1.3 Flag Locations in Firmware
```bash
# Direct string search
strings -n 5 firmware.bin | grep -iE 'flag\{|CTF\{|password|secret|admin'
strings firmware.bin | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}'

# After extraction:
find ./extracted/ -type f -exec strings -n 5 {} \; | grep -iE 'flag\{'

# Config files
find ./extracted/ -name "*.conf" -o -name "*.cfg" -o -name "*.json" \
     -o -name "passwd" -o -name "shadow" 2>/dev/null | xargs cat 2>/dev/null | head -50
```

---

## Phase 2: Embedded Binary Reverse Engineering

### 2.1 Architecture Detection
```bash
file ./embedded_binary
readelf -h ./embedded_binary 2>/dev/null

# Common embedded architectures:
# ARM (little-endian): Raspberry Pi, STM32
# MIPS (big-endian): Many routers (Mikrotik, TP-Link)
# AVR: Arduino
# PIC: Microchip PICs
```

### 2.2 Radare2 with ARM/MIPS
```bash
# ARM analysis
r2 -a arm -b 32 ./arm_binary
> aaa; afl; pdf @main

# MIPS
r2 -a mips -b 32 ./mips_binary

# Auto-detect (for ELF)
r2 -A ./embedded.elf
```

### 2.3 Ghidra with Embedded Support
- Ghidra supports ARM, MIPS, AVR, PIC out of the box
- Import binary → select correct language/processor
- Use Memory Map if binary is flat (no ELF headers)

### 2.4 ESP32 / ESP8266 Firmware
```bash
# Extract flash dump
python3 -m esptool --chip esp32 read_flash 0 ALL flash.bin 2>/dev/null
# Or: esptool.py -p /dev/ttyUSB0 read_flash 0 0x400000 flash.bin

# Analyze
binwalk -e flash.bin
strings flash.bin | grep -iE 'flag|ssid|password|wifi|secret'
```

---

## Phase 3: Protocol Analysis (CTF Simulation)

### 3.1 UART Simulation (Logic Analyzer data)
```bash
# If you have a .sal / .logicdata / CSV of UART capture:
# Use sigrok/PulseView for decoding
# Or parse CSV manually:
python3 << PYEOF
# CSV format: timestamp, value
import csv
with open('uart_capture.csv') as f:
    reader = csv.reader(f)
    data = list(reader)
# Look for flag in decoded bytes
PYEOF
```

### 3.2 I2C/SPI Data Parsing
```bash
# SPI: look for MOSI/MISO data streams
# Common flag delivery: device responds with flag over SPI/I2C
# Decode bytes from CSV export of logic analyzer
```

### 3.3 Baud Rate Detection (for UART challenges)
```bash
# Common baud rates to try: 9600, 115200, 57600, 38400, 19200
# If given signal timing: baud_rate = 1 / bit_time_in_seconds
```

---

## Phase 4: Hardware Crypto Challenges

### 4.1 Power Trace Analysis (ChipWhisperer-style CTF)
```python
import numpy as np

# Load traces (usually provided as .npy or .csv)
traces = np.load('power_traces.npy')   # shape: (num_traces, trace_length)
plaintext = np.load('plaintext.npy')   # shape: (num_traces, 16) — AES blocks

# Simple Power Analysis: Plot a single trace
import matplotlib.pyplot as plt
plt.plot(traces[0])
plt.savefig('/tmp/ctf/power_trace.png')

# Correlation Power Analysis (CPA) for AES key recovery:
def hamming_weight(x):
    return bin(x).count('1')

# For each key byte hypothesis (0-255), for each trace:
# Hypothetical power = HW(AES_Sbox[plaintext ^ key_hypothesis])
# Correlate with actual power trace
```

### 4.2 Timing Side-Channel (if server gives timing info)
```python
import socket, time, statistics

def try_key(key_byte):
    # Send to vulnerable server, measure response time
    start = time.perf_counter()
    # ... send request with key_byte ...
    return time.perf_counter() - start

# Average multiple measurements to reduce noise
measurements = {b: statistics.mean(try_key(b) for _ in range(50)) for b in range(256)}
likely_key = max(measurements, key=measurements.get)
print(f"Likely key byte: {hex(likely_key)}")
```

### 4.3 Fault Injection Analysis (theoretical)
```
# If the server/device can be made to fault (skip instruction):
# Common in: RSA CRT fault → factor n
# Detect: if two signatures with faults → gcd(sig1 - sig2, n) = p
from math import gcd
p = gcd(abs(sig1 - sig2), n)
if p != 1 and p != n:
    q = n // p
    print(f"Factored! p={p}, q={q}")
```

---

## Phase 5: Embedded File System Analysis

### 5.1 Squashfs
```bash
unsquashfs firmware.squashfs -d ./squashfs_root/
ls ./squashfs_root/
cat ./squashfs_root/etc/passwd
find ./squashfs_root/ -name "*.sh" | xargs grep -l flag
```

### 5.2 ROMFS / CramFS
```bash
sudo apt install cramfsprogs
cramfsck firmware.cramfs -v -x ./cramfs_root/
```

### 5.3 OpenWRT / Router Firmware
```bash
binwalk -e openwrt.bin
# Common structure: kernel + squashfs
# Look in: /etc/config/, /usr/bin/, /etc/dropbear/
```

---

## Hardware CTF Toolkit

| Task | Tool | Notes |
|---|---|---|
| Firmware extraction | `binwalk -e` | Always first step |
| SquashFS | `unsquashfs` | Most common embedded FS |
| JFFS2 | `jefferson` | Flash-based FS |
| ARM/MIPS RE | Ghidra + processor pack | Load as raw binary |
| ESP32 firmware | `esptool.py` | Flash dump / analysis |
| Power analysis | ChipWhisperer Python | For SCA challenges |
| Logic analyzer data | sigrok/PulseView | Decode UART/SPI/I2C |
| String search | `strings`, `grep` | Quick wins |
| CPA key recovery | Custom numpy scripts | Statistical SCA |
