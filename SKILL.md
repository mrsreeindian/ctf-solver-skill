---
name: ctf-solver
description: >-
  Use this skill to solve CTF (Capture The Flag) challenges across ALL
  categories: binary exploitation (pwn), reverse engineering (rev),
  cryptography, forensics, steganography, web exploitation, and hardware.
  Activate when the user provides a CTF challenge as a file, a remote netcat
  address (nc HOST PORT), an HTTP/HTTPS URL, or an IP:PORT target. This skill
  will triage, classify, exploit, and produce a full Markdown writeup with the
  flag and exploitation explanation grounded in wiki.bi0s.in methodology.
  Uses WSL Kali Linux for all Linux-native tooling.
---

# CTF Solver — Master Playbook

> [!IMPORTANT]
> **Before anything else**: Determine challenge delivery type:
> - **Local file** → copy to WSL via `wsl -d kali-linux -- cp /mnt/c/path/to/file /tmp/chal`
> - **Remote netcat** → `nc HOST PORT` or pwntools `remote('HOST', PORT)`
> - **HTTP/HTTPS URL or IP:PORT** → `curl -sv http://IP:PORT` or use the browser
> - **Online CTF platform** → open the URL, read the challenge, download attached files

## Global Constants

```bash
WRITEUP_DIR="/mnt/c/Users/Sreedev M Nair/Documents/CTF-Writeups"
KALI_CMD="wsl -d kali-linux -- bash -c"
WSL_TMP="/tmp/ctf"
```

---

## PHASE 0 — Environment Setup

Run this ONCE per session (or when tools are missing):

```powershell
wsl -d kali-linux -- bash "/mnt/c/Users/Sreedev M Nair/Documents/Projects/ctf-solver-skill/scripts/setup_tools.sh"
```

Also ensure the writeup folder exists on Windows:
```powershell
New-Item -ItemType Directory -Force "C:\Users\Sreedev M Nair\Documents\CTF-Writeups"
```

---

## PHASE 1 — Triage & Category Detection

### Step 1A: Prepare the Challenge

```bash
# For a local file (Windows path):
wsl -d kali-linux -- bash -c "mkdir -p /tmp/ctf && cp '/mnt/c/path/to/challenge' /tmp/ctf/chal"

# For a URL download:
wsl -d kali-linux -- bash -c "mkdir -p /tmp/ctf && cd /tmp/ctf && wget 'http://CHALLENGE_URL' -O chal"

# For a web target (no file):
# → Proceed directly to PHASE 2 with category=web
```

### Step 1B: Run Auto-Triage Script

```bash
wsl -d kali-linux -- bash "/mnt/c/Users/Sreedev M Nair/Documents/Projects/ctf-solver-skill/scripts/triage.sh" "/tmp/ctf/chal"
```

### Step 1C: Classify the Category

Analyze triage output using these heuristics:

| Signal | Category |
|---|---|
| ELF/PE binary + `checksec` shows NX/Canary/PIE | **Pwn** or **Rev** |
| ELF with vulnerable functions (`gets`, `printf %s`) | **Pwn** |
| ELF/PE binary asking for password or doing complex logic | **Rev** |
| `.jpg/.png/.bmp/.wav/.mp3` with hidden data | **Stego** |
| `.pcap/.pcapng`, memory dump `.dmp/.raw`, disk image `.img` | **Forensics** |
| Ciphertext, base64 blob, RSA parameters, number theory | **Crypto** |
| URL, IP:PORT (HTTP), source code `.php/.js/.py` | **Web** |
| Firmware `.bin`, JTAG/UART references, `.uf2`, `.hex` | **Hardware** |
| Category stated explicitly in challenge description | Use stated category |

---

## PHASE 2 — Category-Specific Playbook

After classification, **read the corresponding reference file** and execute that playbook:

- **Pwn** → Read `references/pwn.md` + run `scripts/pwn_helper.sh`
- **Rev** → Read `references/rev.md` + run `scripts/rev_helper.sh`
- **Crypto** → Read `references/crypto.md` + run `scripts/crypto_helper.sh`
- **Forensics** → Read `references/forensics.md` + run `scripts/forensics_helper.sh`
- **Stego** → Read `references/stego.md` + run `scripts/stego_helper.sh`
- **Web** → Read `references/web.md` + run `scripts/web_helper.sh`
- **Hardware** → Read `references/hardware.md`

---

## PHASE 3 — Flag Extraction & Validation

### Recognizing a Flag

Most CTF flags match these patterns:
```
flag{...}          # Generic
CTF{...}           # Event-specific
picoCTF{...}       # picoCTF
bi0sCTF{...}       # bi0sCTF
HTB{...}           # HackTheBox
DUCTF{...}         # DownUnder CTF
```

Search for flag patterns in output:
```bash
wsl -d kali-linux -- bash -c "strings /tmp/ctf/output 2>/dev/null | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}'"
```

### Validate the Flag

- Confirm the flag string is complete (opening `{` and closing `}`)
- If the challenge is on a platform, submit it to verify
- If the flag contains non-printable chars, check encoding (base64, hex)

---

## PHASE 4 — Writeup Generation

After finding the flag, generate a full Markdown writeup using `templates/writeup_template.md`. Save it at:

**Windows path**: `C:\Users\Sreedev M Nair\Documents\CTF-Writeups\<CTF_NAME>_<CHALLENGE_NAME>.md`
**WSL path**: `/mnt/c/Users/Sreedev M Nair/Documents/CTF-Writeups/<CTF_NAME>_<CHALLENGE_NAME>.md`

Save via WSL:
```bash
wsl -d kali-linux -- bash -c "cat > '/mnt/c/Users/Sreedev M Nair/Documents/CTF-Writeups/CTFNAME_CHALNAME.md' << 'WRITEUP'
[writeup content here]
WRITEUP"
```

Also create a Markdown **artifact** in the conversation so the user sees it immediately.

The writeup MUST include:
1. Challenge name, event, category, difficulty
2. The **flag** prominently at the top
3. Initial triage output
4. Identified vulnerability/hidden data
5. Step-by-step exploitation/extraction with **actual commands run**
6. The exploit script (if any)
7. Key takeaways — technique explanation

---

## WSL Execution Pattern

Always use this pattern to run commands in Kali:
```powershell
# Single command:
wsl -d kali-linux -- bash -c "COMMAND_HERE"

# Multi-line script:
wsl -d kali-linux -- bash -c "
cd /tmp/ctf
COMMAND1
COMMAND2
"

# Run a script file:
wsl -d kali-linux -- bash "/mnt/c/Users/Sreedev M Nair/Documents/Projects/ctf-solver-skill/scripts/SCRIPT.sh" ARG1 ARG2

# Interactive GDB session (requires Windows Terminal):
wsl -d kali-linux -- bash -c "cd /tmp/ctf && gdb ./chal"
```

---

## Error Handling

| Error | Fix |
|---|---|
| `ModuleNotFoundError: pwn` | Run `setup_tools.sh` again |
| WSL not started | `wsl -d kali-linux` (starts it) |
| Tool not found | `wsl -d kali-linux -- bash -c "sudo apt install -y TOOLNAME"` |
| Permission denied on script | `wsl -d kali-linux -- bash -c "chmod +x /tmp/ctf/chal"` |
| Writeup folder missing | `New-Item -ItemType Directory -Force "C:\Users\Sreedev M Nair\Documents\CTF-Writeups"` |
| ASLR makes addresses change | Use `wsl -d kali-linux -- bash -c "echo 0 | sudo tee /proc/sys/kernel/randomize_va_space"` temporarily |
