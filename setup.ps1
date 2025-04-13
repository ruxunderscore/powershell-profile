<# PowerShell Environment Setup Script
Version: 1.2
Last Updated: 2025-03-30
Original Author: ChrisTitusTech (Concept/Base)
Current Maintainer: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Installs necessary tools, fonts, helper functions, and the PowerShell profile script(s).

.DESCRIPTION
This script prepares a Windows environment for a customized PowerShell experience.
It performs the following steps:
- Checks for Administrator privileges and internet connectivity.
- Installs dependencies: Chocolatey, Winget packages (Starship, Zoxide, Eza),
  PowerShell Modules (Terminal-Icons), and Nerd Fonts.
- Downloads the shared `HelperFunctions.ps1` script.
- Downloads and configures the base PowerShell profile script
  (`Microsoft.Powershell_profile.ps1`) from the specified GitHub repository.
- Optionally downloads and configures the user's advanced profile script (`profile.ps1`)
  to the CurrentUserAllHosts location.
- Provides user guidance and status messages.
#>

<# Changelog:
- 2025-03-30 (v1.0): Initialized script based on CTT concept. Added Admin/Internet checks,
                      Nerd Font install function, tool installations (Starship, Choco,
                      Icons, Zoxide, Eza), profile download/backup logic, header/comments.
- 2025-03-30 (v1.1): Reorganized script structure logically (Checks, Dependencies, Profiles).
                      Added more comments. Implemented optional download for advanced user
                      profile (`profile.ps1`) to CurrentUserAllHosts location with backup.
- 2025-03-30 (v1.2): Added step to download shared `HelperFunctions.ps1`. Updated header/comments.
#>

#region Initial Checks

# --- Script Header ---
Write-Host "Starting PowerShell Environment Setup..." -ForegroundColor Cyan

# --- Administrator Check ---
Write-Host "Checking for Administrator privileges..."
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Administrator privileges are required. Please re-run this script as an Administrator!"
    # Pause execution to allow user to read the error before the window closes if run directly
    Read-Host "Press Enter to exit..."
    exit 1 # Use a non-zero exit code for error
}
Write-Host "Administrator privileges confirmed." -ForegroundColor Green

# --- Internet Connectivity Check ---
# Function to test internet connectivity
function Test-InternetConnection {
    Write-Host "Testing internet connection..."
    try {
        # Test connection to a reliable host (e.g., Google's public DNS)
        $null = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
        Write-Host "Internet connection successful." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Internet connection failed or is unavailable. This script requires internet access."
        return $false
    }
}

# Check for internet connectivity before proceeding
if (-not (Test-InternetConnection)) {
    Read-Host "Press Enter to exit..."
    exit 1
}

#endregion Initial Checks

#region Dependency Installation

Write-Host "`n--- Installing Dependencies ---" -ForegroundColor Cyan

# --- Chocolatey Installation ---
Write-Host "Checking/Installing Chocolatey Package Manager..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Attempting installation..."
    try {
        # Ensure TLS 1.2+ is used, execute install script
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey installation attempted. Please verify success." -ForegroundColor Yellow
        # Add Chocolatey to PATH for the current session if install was successful
        $env:Path += ";$env:ProgramData\chocolatey\bin"
    }
    catch {
        Write-Warning "Failed to install Chocolatey. Some dependencies might fail. Error: $_"
    }
} else {
    Write-Host "Chocolatey already installed." -ForegroundColor Green
}

# --- Winget Packages Installation ---
# Install Starship Prompt
Write-Host "Checking/Installing Starship (via winget)..."
if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
    try {
        winget install --id Starship.Starship --exact --accept-package-agreements --accept-source-agreements --silent
        Write-Host "Starship installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to install Starship via winget. Error: $_"
    }
} else {
    Write-Host "Starship already installed." -ForegroundColor Green
}

# Install Zoxide
Write-Host "Checking/Installing Zoxide (via winget)..."
if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    try {
        winget install -e --id ajeetdsouza.zoxide --accept-package-agreements --accept-source-agreements --silent
        Write-Host "Zoxide installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to install Zoxide via winget. Error: $_"
    }
} else {
    Write-Host "Zoxide already installed." -ForegroundColor Green
}

# Install Eza
Write-Host "Checking/Installing Eza (via winget)..."
if (-not (Get-Command eza -ErrorAction SilentlyContinue)) {
    try {
        winget install --id eza-community.eza --exact --accept-package-agreements --accept-source-agreements --silent
        Write-Host "Eza installed successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to install Eza via winget. Error: $_"
    }
} else {
    Write-Host "Eza already installed." -ForegroundColor Green
}

# --- PowerShell Modules Installation ---
Write-Host "Checking/Installing Terminal-Icons PowerShell module..."
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    try {
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
        Write-Host "Terminal-Icons module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to install Terminal-Icons module. Error: $_"
    }
} else {
    Write-Host "Terminal-Icons module already installed." -ForegroundColor Green
}


# --- Nerd Fonts Installation ---
# Function to install Nerd Fonts (scoped locally to this script)
function Install-NerdFonts {
    param (
        [string]$FontName = "CascadiaCode", # The name used in the Nerd Fonts release URL
        [string]$FontDisplayName = "CaskaydiaCove NF", # The name as it appears in Font Settings
        [string]$Version = "3.2.1" # Check Nerd Fonts releases for the latest version
    )

    Write-Host "Checking/Installing Nerd Font: $FontDisplayName..."
    try {
        # Load System.Drawing assembly to check installed fonts
        Add-Type -AssemblyName System.Drawing
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        if ($fontFamilies -notcontains $FontDisplayName) {
            Write-Host "Font not found. Downloading $FontName v$Version..."
            $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${Version}/${FontName}.zip"
            $zipFilePath = Join-Path -Path $env:TEMP -ChildPath "${FontName}.zip"
            $extractPath = Join-Path -Path $env:TEMP -ChildPath "${FontName}"

            # Download the font archive
            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download complete. Extracting..."

            # Extract the archive
            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force -ErrorAction Stop
            Write-Host "Extraction complete. Installing fonts..."

            # Get the Windows Fonts directory COM object
            $fontsShellFolder = (New-Object -ComObject Shell.Application).Namespace(0x14) # 0x14 corresponds to the Fonts folder

            # Find and copy font files (usually .ttf, sometimes .otf)
            Get-ChildItem -Path $extractPath -Recurse -Include "*.ttf", "*.otf" | ForEach-Object {
                $fontFileName = $_.Name
                # Check if font already exists to avoid error/prompt from CopyHere
                if (-not (Test-Path (Join-Path $env:SystemRoot Fonts $fontFileName))) {
                    Write-Verbose "Installing $($_.Name)"
                    # CopyHere method with 0x10 flag suppresses progress dialogs
                    $fontsShellFolder.CopyHere($_.FullName, 0x10)
                } else {
                    Write-Verbose "Font '$($_.Name)' already exists in Fonts folder. Skipping."
                }
            }
            Write-Host "$FontDisplayName fonts installed successfully." -ForegroundColor Green

            # Cleanup temporary files
            Write-Host "Cleaning up temporary files..."
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Font '$FontDisplayName' already installed." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to download or install '$FontDisplayName' font. Manual installation may be required. Error: $_"
    }
}

# Install the desired Nerd Font
Install-NerdFonts -FontName "CascadiaCode" -FontDisplayName "CaskaydiaCove NF" -Version "3.2.1" # Specify desired version

#endregion Dependency Installation

#region Profile and Helper Script Setup

Write-Host "`n--- Setting up Profile Scripts ---" -ForegroundColor Cyan

# --- Define URLs ---
# *** IMPORTANT: Verify these URLs point to the RAW content of your files on GitHub/etc. ***
$BaseProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
$AdvancedProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/profile.ps1"
$HelperScriptUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/refs/heads/main/HelperFunctions.ps1"

# --- Determine Profile Paths and Directory ---
# $PROFILE variable automatically holds the correct path for the CurrentUserCurrentHost profile
$profilePath = $PROFILE
$profileDir = Split-Path -Path $profilePath -Parent # Should be C:\Users\user\Documents\PowerShell
$UserAllHostsProfilePath = $PROFILE.CurrentUserAllHosts # Often same dir, different filename
$helperScriptPath = Join-Path -Path $profileDir -ChildPath "HelperFunctions.ps1"

# --- Check/Create Profile Directory ---
Write-Host "Ensuring profile directory exists: $profileDir"
if (!(Test-Path -Path $profileDir -PathType Container)) {
    try {
        $null = New-Item -Path $profileDir -ItemType Directory -Force -ErrorAction Stop
        Write-Host "Profile directory created." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create profile directory '$profileDir'. Cannot proceed. Error: $_"
        Read-Host "Press Enter to exit..."
        exit 1
    }
} else {
    Write-Host "Profile directory already exists."
}

# --- Download HelperFunctions.ps1 --- ### NEW SECTION ###
Write-Host "Downloading shared helper script..."
try {
    Invoke-RestMethod -Uri $HelperScriptUrl -OutFile $helperScriptPath -ErrorAction Stop
    Write-Host "Helper script ($helperScriptPath) downloaded successfully." -ForegroundColor Green
} catch {
    # This is critical, as profiles depend on it. Treat as error.
    Write-Error "Failed to download or save the helper script. Profiles may not load correctly. Please check the URL '$HelperScriptUrl' and permissions. Error: $_"
    # Optionally exit here if helpers are essential for base profile function
    # Read-Host "Press Enter to exit..."; exit 1
}

# --- Base Profile Setup ($PROFILE) ---
Write-Host "`nSetting up Base PowerShell Profile ($profilePath)..."
# Backup Existing
if (Test-Path -Path $profilePath -PathType Leaf) {
    $backupProfilePath = "$profilePath.old"
    Write-Host "Existing base profile found. Backing up to: $backupProfilePath" -ForegroundColor Yellow
    try { Copy-Item -Path $profilePath -Destination $backupProfilePath -Force -ErrorAction Stop } catch { Write-Warning "Failed to backup existing base profile. Will attempt to overwrite. Error: $_" }
}
# Download Base Profile
Write-Host "Downloading base profile from $BaseProfileUrl..."
try {
    Invoke-RestMethod -Uri $BaseProfileUrl -OutFile $profilePath -ErrorAction Stop
    Write-Host "Base profile downloaded/updated successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to download or save the base profile. Error: $_"
}
Write-Host "NOTE: Base profile uses auto-update. Use 'ep' alias to edit user-specific profile." -ForegroundColor Yellow


# --- Optional Advanced Profile Setup ($PROFILE.CurrentUserAllHosts) ---
Write-Host "`nChecking for Advanced Profile installation..."
$promptMessage = @"

Download the advanced user profile ('profile.ps1')?
Contains many extra functions (media, Git, etc.). It will be installed to:
$UserAllHostsProfilePath
(Any existing file there will be backed up). Choose 'N' to skip.

Download advanced profile? (Y/N):
"@
$choice = Read-Host -Prompt $promptMessage

if ($choice -match '^[Y]') {
    Write-Host "Proceeding with advanced profile download..."
    # Backup Existing
    if (Test-Path -Path $UserAllHostsProfilePath -PathType Leaf) {
        $backupUserAllHostsPath = "$UserAllHostsProfilePath.old"
        Write-Host "Existing advanced profile found. Backing up to: $backupUserAllHostsPath" -ForegroundColor Yellow
        try { Copy-Item -LiteralPath $UserAllHostsProfilePath -Destination $backupUserAllHostsPath -Force -ErrorAction Stop } catch { Write-Warning "Failed to backup existing advanced profile. Will attempt to overwrite. Error: $_" }
    }
    # Download Advanced Profile
    Write-Host "Downloading advanced profile from $AdvancedProfileUrl..."
    try {
        Invoke-RestMethod -Uri $AdvancedProfileUrl -OutFile $UserAllHostsProfilePath -ErrorAction Stop
        Write-Host "Advanced profile ($UserAllHostsProfilePath) downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download or save the advanced profile. Error: $_"
    }
} else {
    Write-Host "Skipping advanced profile download." -ForegroundColor Yellow
    Write-Host "Your customizations should go in: $UserAllHostsProfilePath (use 'ep' alias later)."
}

#endregion Profile and Helper Script Setup

#region Completion Message

Write-Host "`n--- Setup Summary ---" -ForegroundColor Cyan
if (Test-Path -Path $helperScriptPath) { Write-Host "- Helper script setup appears successful." -ForegroundColor Green } else { Write-Warning "- Helper script file ($helperScriptPath) not found."}
if (Test-Path -Path $profilePath) { Write-Host "- Base profile setup appears successful." -ForegroundColor Green } else { Write-Warning "- Base profile file ($profilePath) not found."}
if ($choice -match '^[Y]') {
    if (Test-Path -Path $UserAllHostsProfilePath) { Write-Host "- Advanced profile setup appears successful." -ForegroundColor Green } else { Write-Warning "- Advanced profile file ($UserAllHostsProfilePath) not found despite attempting download."}
}

# Check for key tools (optional, but good feedback)
if (Get-Command starship -ErrorAction SilentlyContinue){ Write-Host "- Starship appears installed." -ForegroundColor Green} else { Write-Warning "- Starship installation may have failed."}
if (Get-Command zoxide -ErrorAction SilentlyContinue){ Write-Host "- Zoxide appears installed." -ForegroundColor Green} else { Write-Warning "- Zoxide installation may have failed."}
if (Get-Command eza -ErrorAction SilentlyContinue){ Write-Host "- eza appears installed." -ForegroundColor Green} else { Write-Warning "- eza installation may have failed."}

Write-Host "`nSetup script finished." -ForegroundColor Cyan
Write-Host ">>> Please RESTART your PowerShell session for all changes to take effect! <<<" -ForegroundColor White -BackgroundColor DarkMagenta

#endregion Completion Message
