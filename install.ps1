#!/usr/bin/env pwsh
# ============================================================
# CTF Solver Skill — Installer
# Run with: pwsh -ExecutionPolicy Bypass -File install.ps1
# Or from PowerShell: .\install.ps1
# ============================================================

$ErrorActionPreference = 'Stop'

$Bold    = "`e[1m"
$Green   = "`e[32m"
$Yellow  = "`e[33m"
$Cyan    = "`e[36m"
$Red     = "`e[31m"
$Reset   = "`e[0m"

function Log   { param($msg) Write-Host "${Green}[+]${Reset} $msg" }
function Warn  { param($msg) Write-Host "${Yellow}[!]${Reset} $msg" }
function Error { param($msg) Write-Host "${Red}[-]${Reset} $msg" }
function Header { param($msg) Write-Host "${Cyan}${Bold}$msg${Reset}" }

Clear-Host
Header @"
╔══════════════════════════════════════════════════════╗
║           CTF Solver Skill — Installer               ║
║      bi0s wiki methodology for Antigravity           ║
╚══════════════════════════════════════════════════════╝
"@

$SourceDir = $PSScriptRoot

# ─── Step 1: Choose scope ───────────────────────────────────
Write-Host ""
Header "Step 1: Installation Scope"
Write-Host "  [1] Global  — Available in ALL projects (recommended)"
Write-Host "      Path: ~\.gemini\config\skills\ctf-solver\"
Write-Host ""
Write-Host "  [2] Project — Available only in the CURRENT directory"
Write-Host "      Path: .agents\skills\ctf-solver\  (in current folder)"
Write-Host ""

do {
    $choice = Read-Host "Choose scope [1/2]"
} while ($choice -notin @('1','2'))

if ($choice -eq '1') {
    $SkillDir = Join-Path $env:USERPROFILE ".gemini\config\skills\ctf-solver"
    $ScopeLabel = "Global (~\.gemini\config\skills\)"
} else {
    $SkillDir = Join-Path (Get-Location) ".agents\skills\ctf-solver"
    $ScopeLabel = "Project-scoped (.agents\skills\)"
}

Write-Host ""
Log "Installing to: $SkillDir"
Log "Scope: $ScopeLabel"

# ─── Step 2: Copy skill files ───────────────────────────────
Write-Host ""
Header "Step 2: Copying Skill Files"

$Dirs = @("references","scripts","templates")
foreach ($d in $Dirs) {
    $destPath = Join-Path $SkillDir $d
    New-Item -ItemType Directory -Force -Path $destPath | Out-Null
}

# Copy all files
Copy-Item "$SourceDir\SKILL.md"                     "$SkillDir\SKILL.md"                     -Force
Copy-Item "$SourceDir\references\*"                 "$SkillDir\references\"                   -Force
Copy-Item "$SourceDir\scripts\*"                    "$SkillDir\scripts\"                      -Force
Copy-Item "$SourceDir\templates\*"                  "$SkillDir\templates\"                    -Force

Log "Skill files copied to: $SkillDir"

# ─── Step 3: Fix script line endings (LF for bash) ──────────
Write-Host ""
Header "Step 3: Fixing Script Line Endings (CRLF → LF)"
Get-ChildItem "$SkillDir\scripts\" -Filter "*.sh" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $content = $content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($_.FullName, $content, [System.Text.Encoding]::UTF8)
    Log "Fixed: $($_.Name)"
}

# ─── Step 4: Create writeups folder ─────────────────────────
Write-Host ""
Header "Step 4: Creating Writeup Directory"
$WriteupDir = Join-Path $env:USERPROFILE "Documents\CTF-Writeups"
New-Item -ItemType Directory -Force -Path $WriteupDir | Out-Null
Log "Writeup folder: $WriteupDir"

# ─── Step 5: WSL Kali check → Docker fallback ───────────────
Write-Host ""
Header "Step 5: Kali Linux Environment"

$kaliAvailable = $false
$useDocker     = $false

try {
    $wslOutput = wsl --list --verbose 2>&1
    if ($wslOutput -match "kali") {
        Log "Kali Linux WSL detected ✓"
        $kaliAvailable = $true
    } else {
        Warn "kali-linux WSL distro not found. (wsl --install -d kali-linux to add it)"
    }
} catch {
    Warn "WSL not available."
}

if (-not $kaliAvailable) {
    Write-Host ""
    Warn "No WSL Kali found. Checking Docker as fallback..."
    try {
        $null = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Docker detected ✓ — will use Docker + Kali container"
            $useDocker = $true
        }
    } catch {}

    if (-not $useDocker) {
        Warn "Neither WSL Kali nor Docker found."
        Write-Host "  Option A (recommended): wsl --install -d kali-linux"
        Write-Host "  Option B:               https://www.docker.com/products/docker-desktop/"
        Warn "Skipping tool installation. Re-run install.ps1 after setup."
    }
}

# ─── Step 6: Install CTF tools ───────────────────────────────
Write-Host ""
if ($kaliAvailable) {
    $setupNow = Read-Host "Install CTF tools in Kali WSL now? (~5-10 min) [y/N]"
    if ($setupNow -imatch '^y') {
        Header "Step 6: Installing CTF Tools in Kali WSL"
        $wslScript = (wsl -d kali-linux -- wslpath -u "$SkillDir\scripts\setup_tools.sh") 2>$null
        if (-not $wslScript) {
            $wslScript = "/mnt/c" + ($SkillDir -replace 'C:','').Replace('\','/') + "/scripts/setup_tools.sh"
        }
        wsl -d kali-linux -- bash "$wslScript"
        Log "Tool installation complete."
    } else {
        Warn "Skipping. Run manually: wsl -d kali-linux -- bash `"$SkillDir\scripts\setup_tools.sh`""
    }
} elseif ($useDocker) {
    $setupNow = Read-Host "Set up Kali Docker container and install tools? (~5-10 min) [y/N]"
    if ($setupNow -imatch '^y') {
        Header "Step 6: Setting Up Kali Docker Container"
        Log "Pulling kalilinux/kali-rolling..."
        docker pull kalilinux/kali-rolling
        Log "Creating persistent container 'ctf_kali'..."
        docker rm -f ctf_kali 2>$null
        docker volume create ctf_kali_home | Out-Null
        $writeupFwd = $WriteupDir.Replace('\','/')
        docker run -d --name ctf_kali `
          -v "/tmp/ctf:/tmp/ctf" `
          -v "ctf_kali_home:/root" `
          -v "${writeupFwd}:/root/writeups" `
          --restart unless-stopped `
          kalilinux/kali-rolling sleep infinity | Out-Null
        Log "Installing CTF tools inside container..."
        docker cp "$SkillDir\scripts\setup_tools.sh" "ctf_kali:/tmp/setup_tools.sh"
        docker exec ctf_kali bash /tmp/setup_tools.sh
        Log "Done. Use: docker exec ctf_kali bash -c 'COMMAND'"
    } else {
        Warn "Skipping. Re-run install.ps1 to set up the container later."
    }
} else {
    Header "Step 6: Manual Setup Required"
    Warn "Set up WSL Kali or Docker Desktop, then re-run this installer."
}

# ─── Done! ──────────────────────────────────────────────────
Write-Host ""
Header @"
╔══════════════════════════════════════════════════════╗
║              Installation Complete! 🎉               ║
╚══════════════════════════════════════════════════════╝
"@
Write-Host ""
Log "Skill installed: $SkillDir"
Log "Writeups will be saved to: $WriteupDir"
Write-Host ""
Write-Host "${Cyan}Usage:${Reset}"
Write-Host "  Tell Antigravity: 'Solve this CTF challenge: [file/URL/nc host port]'"
Write-Host "  Or: 'Use the ctf-solver skill to find the flag in this binary'"
Write-Host ""
Write-Host "${Cyan}Quick test:${Reset}"
Write-Host "  wsl -d kali-linux -- bash `"$SkillDir\scripts\triage.sh`" /tmp/test_file"
Write-Host ""
Write-Host "${Yellow}Writeup directory:${Reset} $WriteupDir"
Write-Host ""
