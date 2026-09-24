# CTF Solver Skill for Antigravity / Claude Code

<div align="center">

![CTF Solver](https://img.shields.io/badge/Antigravity-Skill-blue?style=for-the-badge&logo=google)
![Categories](https://img.shields.io/badge/Categories-7-green?style=for-the-badge)
![WSL](https://img.shields.io/badge/WSL-Kali%20Linux-red?style=for-the-badge&logo=linux)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

**A fully automated CTF challenge solver skill for [Google Antigravity](https://antigravity.dev) and Claude Code.**  
Covers all 7 CTF categories using [wiki.bi0s.in](https://wiki.bi0s.in) methodology, with WSL Kali Linux tooling, auto-triage, and structured writeup generation.

</div>

---

## Features

- **7 CTF Categories** — Binary Exploitation (Pwn), Reverse Engineering, Cryptography, Forensics, Steganography, Web Exploitation, Hardware
- **Auto-triage** — classifies any challenge file automatically using `file`, `checksec`, `binwalk`, `exiftool`, and string analysis
- **bi0s wiki methodology** — each category follows the structured approach from [wiki.bi0s.in](https://wiki.bi0s.in)
- **WSL Kali Linux** — runs all Linux-native tools through WSL without leaving your Windows workflow
- **One-command install** — single PowerShell command sets everything up, installs all tools, prompts for global vs project scope
- **Auto writeup** — generates a full Markdown writeup per challenge, saved to `Documents\CTF-Writeups\`
- **Supports any challenge delivery** — local files, `nc HOST PORT`, HTTP/HTTPS URLs, IP:PORT targets

---

## Platform Support

| OS | Kali Linux via | Auto-install |
|---|---|---|
| **Windows** | WSL2 (`kali-linux` distro) preferred, Docker fallback | ✅ `install.ps1` |
| **Linux — Debian/Ubuntu/Kali** | Native `apt` (no container needed) | ✅ `install.sh` |
| **Linux — Arch / RHEL / Fedora / etc.** | Docker + `kalilinux/kali-rolling` container | ✅ `install.sh` |
| **macOS** | Docker + `kalilinux/kali-rolling` container | ✅ `install.sh` |

---

## Installation

### Windows — One Command

```powershell
git clone https://github.com/mrsreeindian/ctf-solver-skill.git
cd ctf-solver-skill
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

**The installer:**
- Detects WSL Kali → falls back to Docker if not found
- Asks: **Global** (all projects) or **Project-scoped** (current folder)
- Optionally installs all CTF tools in Kali (~5-10 min)
- Creates `Documents\CTF-Writeups\`

### Linux & macOS — One Command

```bash
git clone https://github.com/mrsreeindian/ctf-solver-skill.git
cd ctf-solver-skill
bash install.sh
```

**What it does per platform:**
- **Kali / Debian / Ubuntu** → installs CTF tools natively via `apt` + `pip3`
- **Arch / RHEL / Fedora / openSUSE** → installs Docker, pulls `kalilinux/kali-rolling`, creates a persistent container `ctf_kali`
- **macOS** → installs Docker Desktop (via Homebrew if available), same container approach

### One-liner (curl, no clone needed)

```bash
# Linux / macOS:
curl -sSL https://raw.githubusercontent.com/mrsreeindian/ctf-solver-skill/master/install.sh | bash
```

### Global vs Project-Scoped

The installer always asks:
1. **Global** — `~/.gemini/config/skills/ctf-solver/` → available in **all** projects
2. **Project-scoped** — `.agents/skills/ctf-solver/` in the **current** folder only

---

## Usage

Once installed, just tell Antigravity or Claude Code:

```
"Solve this CTF challenge: [attach file]"
"Find the flag at nc challenge.bi0sctf.in 9001"  
"Exploit the web CTF at http://192.168.1.100:8080"
"Analyze this binary and get the flag"
"This is a forensics challenge: [attach .pcap]"
"Solve this crypto challenge: [attach ciphertext]"
```

The agent will:
1. **Triage** the challenge (auto-detect category)
2. **Execute** the category-specific playbook
3. **Exploit / extract** the flag
4. **Generate a writeup** saved to `Documents\CTF-Writeups\`

---

## File Structure

```
ctf-solver-skill/
├── install.ps1                 ← Single-command installer
├── SKILL.md                    ← Master orchestrator (Antigravity reads this)
├── references/
│   ├── pwn.md                  ← Binary exploitation methodology
│   ├── rev.md                  ← Reverse engineering methodology
│   ├── crypto.md               ← Cryptography methodology
│   ├── forensics.md            ← Forensics (network/memory/disk/image)
│   ├── stego.md                ← Steganography methodology
│   ├── web.md                  ← Web exploitation methodology
│   └── hardware.md             ← Hardware / firmware methodology
├── scripts/
│   ├── setup_tools.sh          ← Installs all CTF tools in Kali WSL
│   ├── triage.sh               ← Auto-classifies challenge files
│   ├── pwn_helper.sh           ← checksec, ROPgadget, pwntools template
│   ├── rev_helper.sh           ← r2, ghidra, packing check, ltrace
│   ├── stego_helper.sh         ← steghide, zsteg, LSB, spectrogram
│   ├── forensics_helper.sh     ← PCAP/tshark, Volatility, binwalk
│   ├── crypto_helper.sh        ← encoding detect, RSA, freq analysis
│   └── web_helper.sh           ← recon, sqlmap, LFI, JWT, SSRF
└── templates/
    └── writeup_template.md     ← Structured writeup template
```

---

## Tools Installed by `setup_tools.sh`

| Category | Tools |
|---|---|
| **Pwn** | pwntools, GDB + GEF + pwndbg, ROPgadget, one\_gadget, checksec, patchelf, pwninit |
| **Rev** | radare2, Ghidra (if available), ltrace, strace, upx |
| **Crypto** | pycryptodome, z3-solver, RsaCtfTool, gmpy2, SageMath, hashcat, john |
| **Forensics** | binwalk, foremost, volatility3, tshark, exiftool |
| **Stego** | steghide, stegseek, zsteg, outguess, stegsnow, multimon-ng |
| **Web** | sqlmap, ffuf, gobuster, nikto, flask-unsign, curl |
| **General** | Python 3, pip, requests, Pillow, impacket, git |

---

## Category Coverage

### Binary Exploitation (Pwn)
- `checksec` protection analysis (NX, ASLR, Canary, PIE, RELRO)
- ret2win, ret2libc, ROP chain construction
- Format string attacks (leak canary / libc base)
- Heap exploitation hints
- libc version identification (libc.rip)
- Full pwntools exploit template generation

### Reverse Engineering
- Static: `nm`, `objdump`, radare2, Ghidra headless
- Dynamic: GDB + pwndbg, ltrace, strace
- Packing detection and UPX unpacking
- angr symbolic execution template
- Anti-debug detection
- Binary patching guide

### Cryptography
- Encoding detection (base64, hex, URL, ROT, XOR single-byte)
- RSA attacks: small e, Wiener, common modulus, Fermat factorization, known p&q
- AES: ECB detection, CBC bit-flip, padding oracle
- Classical ciphers: frequency analysis, IC-based Vigenere key length
- Z3 constraint solving template
- Hash cracking (hashcat/john)

### Forensics
- Network: PCAP analysis (tshark), TCP stream extraction, HTTP object export, DNS exfil
- Memory: Volatility 3 (pslist, cmdline, netscan, filescan, clipboard)
- Image: binwalk extraction, foremost carving, exiftool metadata
- Disk: fdisk, mount, deleted file recovery

### Steganography
- Image: steghide, stegseek brute-force, zsteg LSB, outguess, PIL LSB manual
- Audio: spectrogram, DTMF, Morse code detection, mp3stego
- Text: whitespace stego (stegsnow), zero-width characters, acrostic patterns
- QR/barcode: zbarimg, pyzbar

### Web Exploitation
- Recon: directory fuzzing (ffuf/gobuster), header analysis, source review
- SQLi: manual payloads + sqlmap automation
- LFI/RFI: traversal + PHP wrappers (filter, input, data)
- SSTI: Jinja2/Flask RCE payloads
- JWT: decode, alg:none, weak secret cracking (hashcat), flask-unsign
- SSRF: internal network probing, AWS metadata
- XXE: XML injection for file read

### Hardware
- Firmware: binwalk extraction, squashfs/JFFS2 unpacking
- Embedded RE: ARM/MIPS with Ghidra/radare2
- Side-channel: CPA key recovery template (numpy)
- Timing attacks: statistical measurement template
- ESP32/ESP8266: esptool flash extraction

---

## Methodology

This skill follows the **[bi0s wiki](https://wiki.bi0s.in)** methodology from team bi0s (Amrita Vishwa Vidyapeetham) — one of India's top CTF teams and creators of bi0sCTF.

Each reference file mirrors the structured approach taught at bi0s for:
- Systematic triage before any exploitation
- Mitigation-aware exploit development
- Clean, reproducible writeup generation

---

## Writeup Output

Every solved challenge generates a Markdown writeup at:
```
C:\Users\<you>\Documents\CTF-Writeups\<CTF_NAME>_<CHALLENGE>.md
```

Writeups include:
- 🏁 **Flag** (prominently at the top)
- Triage output
- Vulnerability / hidden data analysis
- Step-by-step commands with output
- Full exploit/solve script
- Technique explanation for learning

---

## Contributing

PRs welcome! Areas to improve:
- Additional pwn techniques (SROP, ret2dl-resolve, kernel pwn)
- More crypto attacks (lattice-based, elliptic curve)
- Hardware: ChipWhisperer integration scripts
- OSINT category
- Android / iOS RE category

---

## License

MIT © [Sreedev M Nair](https://github.com/mrsreeindian)

---

<div align="center">

Made with ❤️ for the CTF community | Based on [wiki.bi0s.in](https://wiki.bi0s.in)

</div>
