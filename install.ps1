# Pons Installer for Windows
# Usage: irm https://raw.githubusercontent.com/usepons/.github/main/install.ps1 | iex
# Or download and run: .\install.ps1 [-Yes]
#
# If running from a downloaded file, you may need:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

param(
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$PonsInstallerVersion = "1.0.0"
$DenoMinVersion = [version]"2.0.0"
$DenoBinDir = Join-Path $env:USERPROFILE ".deno\bin"

# Non-interactive detection
$NonInteractive = $Yes -or
    (-not [Environment]::UserInteractive) -or
    ([Console]::IsInputRedirected)

$DenoFreshlyInstalled = $false

function Write-Info    { param($Msg) Write-Host "  i " -ForegroundColor Cyan -NoNewline; Write-Host $Msg }
function Write-Success { param($Msg) Write-Host "  ✓ " -ForegroundColor Green -NoNewline; Write-Host $Msg }
function Write-Warn    { param($Msg) Write-Host "  ⚠ " -ForegroundColor Yellow -NoNewline; Write-Host $Msg }
function Write-Err     { param($Msg) Write-Host "  ✗ " -ForegroundColor Red -NoNewline; Write-Host $Msg }

# Prompt helper — Default param: 'Y' means Enter=yes, 'N' means Enter=no
function Confirm-Prompt {
    param($Prompt, [string]$Default = 'Y')
    if ($NonInteractive) { return $true }
    $answer = Read-Host "$Prompt"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return ($Default -eq 'Y')
    }
    return ($answer -match '^[yY]')
}

function Show-Banner {
    Write-Host ""
    Write-Host "    ____"
    Write-Host "   / __ \____  ____  _____"
    Write-Host "  / /_/ / __ \/ __ \/ ___/"
    Write-Host " / ____/ /_/ / / / (__  )"
    Write-Host "/_/    \____/_/ /_/____/"
    Write-Host ""
    Write-Host "  " -NoNewline
    Write-Host "Pons Installer" -ForegroundColor White -NoNewline
    Write-Host " v$PonsInstallerVersion"
    Write-Host ""
}

function Test-Connectivity {
    Write-Info "Checking internet connectivity..."
    try {
        $null = Invoke-WebRequest -Uri "https://jsr.io" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    }
    catch {
        Write-Err "Cannot reach jsr.io. Please check your internet connection."
        exit 1
    }
}

function Test-DenoVersion {
    try {
        $output = & deno --version 2>$null
        if (-not $output) { return $false }
        $firstLine = ($output | Select-Object -First 1)
        $verStr = $firstLine -replace '^deno\s+', ''
        $ver = [version]$verStr
        return ($ver -ge $DenoMinVersion)
    }
    catch {
        return $false
    }
}

function Get-DenoVersion {
    try {
        $output = & deno --version 2>$null
        $firstLine = ($output | Select-Object -First 1)
        return ($firstLine -replace '^deno\s+', '')
    }
    catch {
        return "unknown"
    }
}

function Install-Deno {
    # Check if already installed
    if (Get-Command deno -ErrorAction SilentlyContinue) {
        $ver = Get-DenoVersion
        if (Test-DenoVersion) {
            $script:DenoFreshlyInstalled = $false
            Write-Success "Deno found (v$ver)"
            return
        }
        Write-Warn "Deno v$ver found but v$DenoMinVersion+ is required"
    }

    Write-Info "Installing Deno..."
    $installed = $false

    # Try winget
    if (-not $installed -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Info "Trying winget..."
        try {
            & winget install DenoLand.Deno --accept-source-agreements --accept-package-agreements 2>$null
            # Refresh PATH after winget install
            $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
            if ((Get-Command deno -ErrorAction SilentlyContinue) -and (Test-DenoVersion)) {
                $installed = $true
                $script:DenoFreshlyInstalled = $true
                Write-Success "Deno installed via winget (v$(Get-DenoVersion))"
            }
        }
        catch {
            Write-Warn "winget installation failed, trying next method..."
        }
    }

    # Try scoop
    if (-not $installed -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Info "Trying Scoop..."
        try {
            & scoop install deno 2>$null
            if ((Get-Command deno -ErrorAction SilentlyContinue) -and (Test-DenoVersion)) {
                $installed = $true
                $script:DenoFreshlyInstalled = $true
                Write-Success "Deno installed via Scoop (v$(Get-DenoVersion))"
            }
        }
        catch {
            Write-Warn "Scoop installation failed, trying next method..."
        }
    }

    # Fallback: official installer
    if (-not $installed) {
        Write-Info "Using official Deno installer..."
        try {
            Invoke-RestMethod https://deno.land/install.ps1 | Invoke-Expression
            # Refresh PATH
            $env:PATH = "$DenoBinDir;$env:PATH"
            if ((Get-Command deno -ErrorAction SilentlyContinue) -and (Test-DenoVersion)) {
                $installed = $true
                $script:DenoFreshlyInstalled = $true
                Write-Success "Deno installed (v$(Get-DenoVersion))"
            }
        }
        catch {
            # fall through
        }
    }

    if (-not $installed) {
        Write-Err "Deno installation failed."
        Write-Err "Install Deno manually: https://deno.land/#installation"
        exit 1
    }
}

function Ensure-Path {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

    if ($env:PATH -split ';' | Where-Object { $_ -eq $DenoBinDir }) {
        return
    }

    Write-Warn "Deno's bin directory is not in your PATH: $DenoBinDir"
    Write-Warn "The 'pons' command won't be available until it is."

    if (Confirm-Prompt "  Add it to your PATH? [Y/n]") {
        # Check if already in persistent user PATH
        if ($userPath -split ';' | Where-Object { $_ -eq $DenoBinDir }) {
            Write-Info "Already in user PATH (restart your terminal to apply)"
            return
        }

        $newPath = "$DenoBinDir;$userPath"
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:PATH = "$DenoBinDir;$env:PATH"
        Write-Success "Added to user PATH"
        Write-Info "Restart your terminal for the change to take full effect"
    }
    else {
        Write-Info "Skipped. Add this directory to your PATH manually: $DenoBinDir"
    }
}

function Install-Pons {
    if (Get-Command pons -ErrorAction SilentlyContinue) {
        $ponsVer = try { & pons --version 2>$null } catch { "unknown" }
        Write-Warn "Pons is already installed ($ponsVer)"
        if (-not (Confirm-Prompt "  Reinstall? [y/N]" 'N')) {
            Write-Success "Keeping existing Pons installation"
            return
        }
        Write-Info "Reinstalling Pons..."
        & deno install -gAf -n pons jsr:@pons/cli
    }
    else {
        Write-Info "Installing Pons CLI..."
        & deno install -gA -n pons jsr:@pons/cli
    }

    # Refresh PATH and verify
    $env:PATH = "$DenoBinDir;$env:PATH"
    if (Get-Command pons -ErrorAction SilentlyContinue) {
        $ponsVer = try { & pons --version 2>$null } catch { "" }
        $verMsg = if ($ponsVer) { " ($ponsVer)" } else { "" }
        Write-Success "Pons CLI installed$verMsg"
    }
    else {
        Write-Err "Pons installation could not be verified."
        Write-Err "Try running manually: deno install -gA -n pons jsr:@pons/cli"
        exit 1
    }
}

function Show-Success {
    $denoVer = Get-DenoVersion
    $ponsVer = try { & pons --version 2>$null } catch { "" }
    $denoLabel = if ($script:DenoFreshlyInstalled) { "Deno installed" } else { "Deno found" }

    Write-Host ""
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "$denoLabel (v$denoVer)"
    Write-Host "  ✓ " -ForegroundColor Green -NoNewline
    Write-Host "Pons CLI installed$(if ($ponsVer) { " ($ponsVer)" })"
    Write-Host ""
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Get started:" -ForegroundColor White
    Write-Host "    pons install && pons onboard      Start the kernel"
    Write-Host "    pons modules list                 List installed modules"
    Write-Host ""
    Write-Host "  Uninstall:" -ForegroundColor White
    Write-Host "    deno uninstall pons"
    Write-Host ""
    Write-Host "  Documentation:" -NoNewline -ForegroundColor White
    Write-Host " https://github.com/usepons"
    Write-Host ""
}

# Main
Show-Banner
if ($NonInteractive) {
    Write-Info "Running non-interactively, accepting all defaults"
}
Test-Connectivity
Install-Deno
Ensure-Path
Install-Pons
Show-Success
