# bi0s Wiki Methodology & CTF Knowledge Base

Welcome to the comprehensive CTF playbook and knowledge base for **ctf-solver-skill**, grounded in the proven methodologies from **[wiki.bi0s.in](https://wiki.bi0s.in)** (maintained by [Team bi0s](https://bi0s.in), India's premier CTF and security research team).

---

## 📚 Table of Contents

1. [Overview & Philosophy](#overview--philosophy)
2. [Category Playbooks](#category-playbooks)
   - [Binary Exploitation (Pwn)](../references/pwn.md)
   - [Reverse Engineering (Rev)](../references/rev.md)
   - [Cryptography (Crypto)](../references/crypto.md)
   - [Forensics](../references/forensics.md)
   - [Steganography (Stego)](../references/stego.md)
   - [Web Exploitation](../references/web.md)
   - [Hardware & Embedded Security](../references/hardware.md)
3. [Triage Methodology](#triage-methodology)
4. [Tooling & Environment Setup](#tooling--environment-setup)
5. [Writeup & Reporting Standards](#writeup--reporting-standards)
6. [External References](#external-references)

---

## 🎯 Overview & Philosophy

The bi0s CTF methodology follows four inviolable principles:

1. **Thorough Triage Before Exploitation**: Never launch blind exploits. Fingerprint the binary, identify active mitigations, examine symbols, and map all input vectors.
2. **Mitigation-Aware Exploit Development**: Modern defenses (NX, Canary, ASLR, PIE, RELRO, CSP, WAF) demand structured leak-then-exploit chains (e.g. info-leak -> libc resolution -> ROP -> ret2libc / one_gadget).
3. **Reproducibility**: Every solution must be scriptable with `pwntools`, Python `requests`, or automated shell scripts.
4. **Structured Writeup Generation**: Extract the flag, document the vulnerability root cause, detail reproduction steps, and explain the takeaway.

---

## 🧭 Category Playbooks & Guides

### 1. [Binary Exploitation (Pwn)](../references/pwn.md)
- **Checksec Analysis**: NX/DEP, Stack Canaries, PIE, Partial/Full RELRO.
- **Exploitation Primitives**:
  - `ret2win` (direct return address redirect)
  - `ret2libc` & ROP gadget chaining (`pop rdi; ret`, `ret` alignment)
  - Format string leaks (`%p`, `%s`, `%n` arbitrary write)
  - Stack pivot & SROP
  - Heap primitives (UAF, fastbin dup, tcache poisoning)
- **Environment Patching**: Using `pwninit` and `patchelf` with provided libc versions.

### 2. [Reverse Engineering (Rev)](../references/rev.md)
- **Static Analysis**: `file`, `strings`, `nm`, `objdump`, Ghidra headless, Radare2 / Cutter.
- **Dynamic Analysis**: GDB with GEF / pwndbg, `ltrace` for string compares, `strace` for syscall auditing.
- **De-obfuscation**: UPX unpacking (`upx -d`), entropy detection, anti-debugging (`ptrace`, `rdtsc`) bypasses.
- **Symbolic Execution**: Automated path solving with `angr` and Z3.

### 3. [Cryptography (Crypto)](../references/crypto.md)
- **Classical Ciphers**: Caesar, Vigenère (Index of Coincidence & Kasiski examination), monoalphabetic substitution (frequency analysis).
- **RSA Attacks**:
  - Small public exponent ($e=3$, Hastad broadcast)
  - Wiener's & Boneh-Durfee attacks for small private exponent $d$
  - Common modulus attacks ($\gcd(e_1, e_2) = 1$)
  - Fermat factorization ($p \approx q$)
  - Automated attacks via `RsaCtfTool`
- **Block Ciphers (AES)**: ECB pattern detection, CBC bit-flipping, padding oracle attacks.
- **Constraint Solving**: `z3-solver` and SageMath equations.

### 4. [Forensics](../references/forensics.md)
- **Network Forensics**: PCAP extraction with `tshark`, TCP stream reassembly, HTTP object export, DNS tunneling detection.
- **Memory Forensics**: Volatility 3 (`windows.pslist`, `cmdline`, `netscan`, `filescan`, `memmap`).
- **Disk & Artifact Forensics**: `binwalk` file carving, `foremost`, partition analysis with `fdisk`, file signature repair.

### 5. [Steganography (Stego)](../references/stego.md)
- **Image Stego**: `exiftool` metadata inspection, `steghide` extraction & `stegseek` password cracking, `zsteg` for PNG/BMP LSB plane analysis, color bit-plane separation with Stegsolve.
- **Audio Stego**: Spectrogram analysis with Matplotlib/Audacity, DTMF tone decoding with `multimon-ng`, Morse code signal analysis.
- **Text & Modern Stego**: Whitespace steganography (`stegsnow`), zero-width Unicode characters, QR code parsing.

### 6. [Web Exploitation](../references/web.md)
- **Reconnaissance**: Subdomain & directory fuzzing with `ffuf` / `gobuster`, parameter discovery.
- **Vulnerability Archetypes**:
  - SQL Injection (error-based, union-based, time-based blind, `sqlmap` pipelines)
  - Server-Side Template Injection (SSTI in Jinja2, Twig, EJS)
  - Local/Remote File Inclusion (LFI/RFI) & PHP filter wrapper chains
  - JSON Web Token (JWT) exploitation (`alg:none`, key confusion, weak secret cracking)
  - Server-Side Request Forgery (SSRF) & XML External Entity (XXE) injection

### 7. [Hardware & Embedded Security](../references/hardware.md)
- **Firmware Analysis**: Extracting SquashFS, JFFS2, and CramFS partitions using `binwalk -e`, `jefferson`, and `unsquashfs`.
- **Embedded Architecture Reversing**: ARM, MIPS, and AVR firmware reversing in Ghidra and Radare2.
- **Hardware Protocols**: UART pinout identification, baud rate calculation, SPI/I2C logic analyzer decoding with Sigrok/PulseView.
- **Side-Channel Analysis (SCA)**: Correlation Power Analysis (CPA) on AES power traces.

---

## 🔍 Triage Workflow

Whenever a challenge file is presented, run the auto-triage helper:

```bash
# Windows WSL
wsl -d kali-linux -- bash scripts/triage.sh /path/to/challenge

# Linux / macOS
bash scripts/kali_exec.sh -f scripts/triage.sh /path/to/challenge
```

The script automatically executes:
1. `file`: identifies ELF, PE, image, audio, PCAP, or archive
2. `checksec`: evaluates ELF exploit mitigations
3. `strings`: searches for `flag{...}`, `ctf{...}`, `bi0s{...}`, URLs, and keywords
4. `binwalk`: scans for hidden or appended nested files
5. `exiftool`: parses metadata, comments, and timestamps
6. `xxd`: inspects raw magic bytes

---

## 🛠️ Tooling & Kali Environment

All procedures run through native Kali Linux or persistent Docker containers. Key tools installed by `scripts/setup_tools.sh`:

| Category | Primary Utilities |
|---|---|
| **Binary Exploitation** | `pwntools`, `gdb-peda`, `pwndbg`, `gef`, `ROPgadget`, `one_gadget`, `checksec` |
| **Reverse Engineering** | `radare2`, `ghidra` (headless), `ltrace`, `strace`, `upx`, `angr` |
| **Cryptography** | `pycryptodome`, `z3-solver`, `RsaCtfTool`, `sagemath`, `hashcat`, `john` |
| **Forensics** | `volatility3`, `tshark`, `binwalk`, `foremost`, `exiftool` |
| **Steganography** | `steghide`, `stegseek`, `zsteg`, `outguess`, `stegsnow`, `multimon-ng` |
| **Web Exploitation** | `sqlmap`, `ffuf`, `gobuster`, `nikto`, `flask-unsign`, `curl` |

---

## 📝 Writeup Standards

All solutions generate an automated Markdown report compliant with the [writeup template](../templates/writeup_template.md) and save to `Documents/CTF-Writeups/`:

- **Flag**: Displayed prominently at the top.
- **Vulnerability Root Cause**: Concise technical explanation of the flaw.
- **Step-by-Step Reproduction**: Commands and intermediate output.
- **Full Exploit Code**: Self-contained script to replicate the solve.
- **Key Takeaways & Mitigations**: How to prevent or detect the flaw in production.

---

## 🔗 External References & Community

- **Official bi0s Wiki**: [https://wiki.bi0s.in](https://wiki.bi0s.in)
- **Team bi0s Website**: [https://bi0s.in](https://bi0s.in)
- **bi0s Blog & Writeups**: [https://blog.bi0s.in](https://blog.bi0s.in)
- **CTFtime Profile**: [Team bi0s on CTFtime](https://ctftime.org/team/662)
