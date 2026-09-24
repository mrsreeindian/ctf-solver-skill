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
  Works on Windows (WSL Kali), Linux (native Debian or Docker), and macOS (Docker).
---

# CTF Solver — Master Playbook

> [!IMPORTANT]
> **Before anything else**: Determine challenge delivery type:
> - **Local file** → copy to Kali workspace (see Phase 0)
> - **Remote netcat** → `nc HOST PORT` or pwntools `remote('HOST', PORT)`
> - **HTTP/HTTPS URL or IP:PORT** → `curl -sv http://IP:PORT`
> - **Online CTF platform** → open the URL, read the challenge, download attached files

---

## PHASE 0 — Platform Detection & Setup

### Step 0A: Detect the OS

Run this first to know which execution pattern to use:

**On Windows (PowerShell):**
```powershell
$IsWin = $true
$KaliCmd = { param($cmd) wsl -d kali-linux -- bash -c $cmd }
$WriteupDir = "$env:USERPROFILE\Documents\CTF-Writeups"
New-Item -ItemType Directory -Force $WriteupDir | Out-Null
```

**On Linux/macOS (bash) — detect automatically:**
```bash
source /PATH/TO/SKILL/scripts/detect_platform.sh
echo "Platform: $PLATFORM | Exec: $EXEC_METHOD | Writeups: $WRITEUP_DIR"
```

### Step 0B: Run Setup (once per machine)

```bash
# Windows:
wsl -d kali-linux -- bash "/mnt/c/path/to/scripts/setup_tools.sh"

# Linux (Debian/Kali) — native:
bash /PATH/TO/SKILL/scripts/setup_tools.sh

# Linux (non-Debian) or macOS — Docker:
bash /PATH/TO/SKILL/scripts/kali_exec.sh --status   # check container
# Container is auto-created + tools installed on first use of kali_exec.sh
```

### Step 0C: Platform Execution Reference Table

| OS | Kali available via | Run command pattern |
|---|---|---|
| **Windows** | WSL (`kali-linux` distro) | `wsl -d kali-linux -- bash -c "CMD"` |
| **Linux (Kali)** | Native | `bash -c "CMD"` |
| **Linux (Debian/Ubuntu)** | Native apt | `bash -c "CMD"` |
| **Linux (Arch/RHEL/etc.)** | Docker container `ctf_kali` | `docker exec ctf_kali bash -c "CMD"` |
| **macOS** | Docker container `ctf_kali` | `docker exec ctf_kali bash -c "CMD"` |
| **Any (universal)** | `kali_exec.sh` wrapper | `bash scripts/kali_exec.sh "CMD"` |

> [!TIP]
> Use `bash scripts/kali_exec.sh "CMD"` on Linux/macOS — it auto-routes to native or Docker.
> On Windows always use `wsl -d kali-linux -- bash -c "CMD"`.

---

## PHASE 1 — Triage & Category Detection

### Step 1A: Prepare the Challenge File

**Windows:**
```powershell
wsl -d kali-linux -- bash -c "mkdir -p /tmp/ctf && cp '/mnt/c/path/to/challenge' /tmp/ctf/chal"
# Download from URL:
wsl -d kali-linux -- bash -c "mkdir -p /tmp/ctf && wget 'http://CHALLENGE_URL' -O /tmp/ctf/chal"
```

**Linux/macOS:**
```bash
mkdir -p /tmp/ctf && cp /path/to/challenge /tmp/ctf/chal
# Download from URL:
mkdir -p /tmp/ctf && wget "http://CHALLENGE_URL" -O /tmp/ctf/chal
# Via Docker (if using container):
docker cp /path/to/challenge ctf_kali:/tmp/ctf/chal
```

### Step 1B: Run Auto-Triage

**Windows:**
```powershell
wsl -d kali-linux -- bash "/mnt/PATH/TO/SKILL/scripts/triage.sh" "/tmp/ctf/chal"
```

**Linux/macOS:**
```bash
bash /PATH/TO/SKILL/scripts/kali_exec.sh -f /PATH/TO/SKILL/scripts/triage.sh /tmp/ctf/chal
# OR if native:
bash /PATH/TO/SKILL/scripts/triage.sh /tmp/ctf/chal
# OR via Docker directly:
docker exec ctf_kali bash -c "bash /tmp/triage.sh /tmp/ctf/chal"
```

### Step 1C: Classify the Category

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

After classification, **read the corresponding reference file** and execute:

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

```
flag{...}     picoCTF{...}   bi0sCTF{...}
CTF{...}      HTB{...}       DUCTF{...}
```

Search output for flag patterns:
```bash
# Windows:
wsl -d kali-linux -- bash -c "strings /tmp/ctf/output | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}'"

# Linux/macOS (native or Docker via kali_exec):
bash scripts/kali_exec.sh "strings /tmp/ctf/output | grep -iE '[a-zA-Z0-9_]+\{[^}]+\}'"
```

---

## PHASE 4 — Writeup Generation

Save writeup to the platform-specific Documents folder:

| OS | Writeup folder |
|---|---|
| Windows | `C:\Users\<you>\Documents\CTF-Writeups\` |
| Linux / macOS | `~/Documents/CTF-Writeups/` |

**Windows:**
```powershell
$writeup = @"
[writeup markdown content]
"@
$writeup | Out-File "$env:USERPROFILE\Documents\CTF-Writeups\CTFNAME_CHALNAME.md" -Encoding utf8
```

**Linux/macOS:**
```bash
cat > "$HOME/Documents/CTF-Writeups/CTFNAME_CHALNAME.md" << 'EOF'
[writeup markdown content]
EOF
```

Also create a Markdown **artifact** in the conversation so the user sees it immediately.

**Writeup MUST include:**
1. Challenge name, event, category, difficulty
2. The **flag** prominently at the top
3. Initial triage output
4. Identified vulnerability/hidden data
5. Step-by-step exploitation/extraction with **actual commands run**
6. The exploit script (if any)
7. Key takeaways — technique explanation

---

## Universal Execution Patterns

### Windows (PowerShell)
```powershell
# Single command in Kali WSL:
wsl -d kali-linux -- bash -c "COMMAND"

# Run a skill script:
wsl -d kali-linux -- bash "/mnt/c/.../scripts/SCRIPT.sh" ARG1

# Copy file to WSL:
wsl -d kali-linux -- bash -c "cp '/mnt/c/path/to/file' /tmp/ctf/chal"
```

### Linux / macOS (bash)
```bash
# Via kali_exec.sh wrapper (auto-routes native or Docker):
bash /PATH/TO/SKILL/scripts/kali_exec.sh "COMMAND"

# Run a script via wrapper:
bash /PATH/TO/SKILL/scripts/kali_exec.sh -f /PATH/TO/SKILL/scripts/SCRIPT.sh ARG1

# Directly on Debian/Kali (native):
bash -c "COMMAND"

# Directly via Docker (non-Debian Linux / macOS):
docker exec ctf_kali bash -c "COMMAND"

# Copy file to Docker workspace:
docker cp /local/path ctf_kali:/tmp/ctf/chal
```

### Interactive Kali Shell
```bash
# Windows:
wsl -d kali-linux

# Linux/macOS (Docker):
docker exec -it ctf_kali bash

# Linux/macOS (via wrapper):
bash /PATH/TO/SKILL/scripts/kali_exec.sh --interactive
```

---

## Error Handling

| Error | Platform | Fix |
|---|---|---|
| `ModuleNotFoundError: pwn` | Any | Re-run `setup_tools.sh` |
| WSL not started | Windows | `wsl -d kali-linux` (starts it) |
| `Cannot connect to Docker` | Linux/macOS | Start Docker Desktop / `sudo systemctl start docker` |
| `Container ctf_kali not found` | Linux/macOS | Run `kali_exec.sh --status` to auto-create |
| Tool not found (native) | Debian | `sudo apt install -y TOOL` |
| Tool not found (Docker) | Linux/macOS | `docker exec ctf_kali bash -c "apt install -y TOOL"` |
| Permission denied on script | Any | `chmod +x SCRIPT.sh` |
| ASLR randomizes addresses | Any | `echo 0 \| sudo tee /proc/sys/kernel/randomize_va_space` |
| Writeup folder missing | Linux/macOS | `mkdir -p ~/Documents/CTF-Writeups` |
