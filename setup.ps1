<# PowerShell Environment Setup Script
Version: 1.1
Last Updated: 2025-03-30
Original Author: Chris Titus Tech (Concept/Base)
Current Maintainer: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Installs necessary tools, fonts, and the PowerShell profile script(s).

.DESCRIPTION
This script prepares a Windows environment for a customized PowerShell experience.
It performs the following steps:
- Checks for Administrator privileges and internet connectivity.
- Installs dependencies: Chocolatey, Winget packages (Starship, Zoxide, Eza),
  PowerShell Modules (Terminal-Icons), and Nerd Fonts.
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
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
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


#region Base Profile Setup ($PROFILE)

Write-Host "`n--- Setting up Base PowerShell Profile ($PROFILE) ---" -ForegroundColor Cyan
$BaseProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/Microsoft.PowerShell_profile.ps1"

# --- Determine Profile Path and Directory ---
# $PROFILE variable automatically holds the correct path for the current host/user
$profilePath = $PROFILE
$profileDir = Split-Path -Path $profilePath -Parent

# --- Check/Create Profile Directory ---
Write-Host "Ensuring profile directory exists: $profileDir"
if (!(Test-Path -Path $profileDir -PathType Container)) {
    try {
        $null = New-Item -Path $profileDir -ItemType Directory -Force -ErrorAction Stop
        Write-Host "Profile directory created." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create profile directory '$profileDir'. Cannot proceed with profile setup. Error: $_"
        Read-Host "Press Enter to exit..."
        exit 1
    }
} else {
    Write-Host "Profile directory already exists."
}

# --- Backup Existing Profile ---
if (Test-Path -Path $profilePath -PathType Leaf) {
    $backupProfilePath = "$profilePath.old"
    Write-Host "Existing profile found. Backing up to: $backupProfilePath" -ForegroundColor Yellow
    try {
        Copy-Item -Path $profilePath -Destination $backupProfilePath -Force -ErrorAction Stop
        Write-Host "Backup successful." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to backup existing profile at '$profilePath'. Will attempt to overwrite. Error: $_"
    }
}

# --- Download Base Profile ---
Write-Host "Downloading base profile from $BaseProfileUrl..."
try {
    Invoke-RestMethod -Uri $BaseProfileUrl -OutFile $profilePath -ErrorAction Stop
    Write-Host "Base profile ($profilePath) downloaded/updated successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to download or save the base profile. Please check the URL and permissions. Error: $_"
    # Consider restoring backup if download fails? More complex logic.
}

# --- User Guidance for Base Profile ---
Write-Host "`nNOTE:" -ForegroundColor Yellow
Write-Host "The base profile includes an auto-updater. Direct changes to:"
Write-Host "$profilePath"
Write-Host "may be overwritten. Use the 'ep' alias (after restarting PowerShell) to edit your user-specific profile."

#endregion Base Profile Setup


#region Optional Advanced Profile Setup ($PROFILE.CurrentUserAllHosts)

Write-Host "`n--- Optional Advanced Profile Setup ---" -ForegroundColor Cyan

# --- Prompt User ---
$promptMessage = @"

You have the option to download an advanced user profile ('profile.ps1')
which contains many additional functions for media management, Git, etc.
This will be installed to the 'CurrentUserAllHosts' location:
$($PROFILE.CurrentUserAllHosts)

This is the file typically edited using the 'ep' alias from the base profile.
If you choose yes, any existing file at that location will be backed up.

Download the advanced profile? (Y/N):
"@
$choice = Read-Host -Prompt $promptMessage

# --- Handle User Choice ---
if ($choice -match '^[Y]') { # Match Y or Yes, case-insensitive
    Write-Host "Proceeding with advanced profile download..."

    # --- Define Paths and URL ---
    $UserAllHostsProfilePath = $PROFILE.CurrentUserAllHosts
    # Ensure the directory exists (usually the same as $profileDir, but check just in case)
    $UserAllHostsProfileDir = Split-Path -Path $UserAllHostsProfilePath -Parent
    if (!(Test-Path -Path $UserAllHostsProfileDir -PathType Container)) {
         try {
             $null = New-Item -Path $UserAllHostsProfileDir -ItemType Directory -Force -ErrorAction Stop
             Write-Host "Created directory for CurrentUserAllHosts profile." -ForegroundColor Green
         } catch {
             Write-Error "Failed to create directory '$UserAllHostsProfileDir'. Cannot proceed with advanced profile setup. Error: $_"
             # Skip the rest of this section
             continue # In case this was in a loop - here it just moves past the if block
         }
    }

    # *** IMPORTANT: Make sure this URL points to YOUR raw profile.ps1 file ***
    $AdvancedProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/profile.ps1" # Assumed URL

    # --- Backup Existing ---
    if (Test-Path -Path $UserAllHostsProfilePath -PathType Leaf) {
        $backupUserAllHostsPath = "$UserAllHostsProfilePath.old"
        Write-Host "Existing CurrentUserAllHosts profile found. Backing up to: $backupUserAllHostsPath" -ForegroundColor Yellow
        try {
            Copy-Item -LiteralPath $UserAllHostsProfilePath -Destination $backupUserAllHostsPath -Force -ErrorAction Stop
            Write-Host "Backup successful." -ForegroundColor Green
        } catch {
            Write-Warning "Failed to backup existing profile at '$UserAllHostsProfilePath'. Will attempt to overwrite. Error: $_"
        }
    }

    # --- Download Advanced Profile ---
    Write-Host "Downloading advanced profile from $AdvancedProfileUrl..."
    try {
        Invoke-RestMethod -Uri $AdvancedProfileUrl -OutFile $UserAllHostsProfilePath -ErrorAction Stop
        Write-Host "Advanced profile ($UserAllHostsProfilePath) downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to download or save the advanced profile. Please check the URL and permissions. Error: $_"
    }

} else {
    Write-Host "Skipping advanced profile download." -ForegroundColor Yellow
    Write-Host "You can manually place your customizations in:"
    Write-Host $PROFILE.CurrentUserAllHosts
}

#endregion Optional Advanced Profile Setup


#region Completion Message

Write-Host "`n--- Setup Summary ---" -ForegroundColor Cyan

# Basic check for profile file existence
if (Test-Path -Path $PROFILE) {
    Write-Host "- Base profile setup appears successful." -ForegroundColor Green
} else {
     Write-Warning "- Base profile file ($PROFILE) not found. Setup may be incomplete."
}

# Check for key tools (optional, but good feedback)
if (Get-Command starship -ErrorAction SilentlyContinue){ Write-Host "- Starship appears installed." -ForegroundColor Green} else { Write-Warning "- Starship installation may have failed."}
if (Get-Command zoxide -ErrorAction SilentlyContinue){ Write-Host "- Zoxide appears installed." -ForegroundColor Green} else { Write-Warning "- Zoxide installation may have failed."}
if (Get-Command eza -ErrorAction SilentlyContinue){ Write-Host "- eza appears installed." -ForegroundColor Green} else { Write-Warning "- eza installation may have failed."}

Write-Host "`nSetup script finished." -ForegroundColor Cyan
Write-Host ">>> Please RESTART your PowerShell session for all changes to take effect! <<<" -ForegroundColor White -BackgroundColor DarkMagenta

#endregion Completion Message