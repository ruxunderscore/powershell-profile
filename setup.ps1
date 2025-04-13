<# PowerShell Environment Setup Script
Version: 1.2 (Refactored)
Last Updated: 2025-04-13
Original Author: ChrisTitusTech (Concept/Base)
Current Maintainer: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Installs necessary tools, fonts, helper functions, and the PowerShell profile script(s)
using a structured, function-based approach.

.DESCRIPTION
This script prepares a Windows environment for a customized PowerShell experience.
It performs the following steps by calling dedicated functions:
- Checks for Administrator privileges and internet connectivity.
- Installs dependencies: Chocolatey, Winget packages (Starship, Zoxide, Eza),
  PowerShell Modules (Terminal-Icons), and Nerd Fonts.
- Downloads the shared `HelperFunctions.ps1` script.
- Downloads and configures the base PowerShell profile script
  (`Microsoft.Powershell_profile.ps1`) from the specified GitHub repository.
- Optionally downloads and configures the user's advanced profile script (`profile.ps1`)
  to the CurrentUserAllHosts location.
- Provides user guidance and status messages.

Changelog:
- 2025-03-30 (v1.0): Initialized script based on CTT concept. Added Admin/Internet checks,
                      Nerd Font install function, tool installations (Starship, Choco,
                      Icons, Zoxide, Eza), profile download/backup logic, header/comments.
- 2025-03-30 (v1.1): Reorganized script structure logically (Checks, Dependencies, Profiles).
                      Added more comments. Implemented optional download for advanced user
                      profile (`profile.ps1`) to CurrentUserAllHosts location with backup.
- 2025-03-30 (v1.2): Added step to download shared `HelperFunctions.ps1`. Updated header/comments.
- 2025-04-13 (v1.2 Refactored): Moved core logic into functions for better structure.
#>

#region Functions

function Test-IsAdmin {
    Write-Host "Checking for Administrator privileges..."
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "Administrator privileges are required. Please re-run this script as an Administrator!"
        Read-Host "Press Enter to exit..."
        exit 1 # Use a non-zero exit code for error
    }
    Write-Host "Administrator privileges confirmed." -ForegroundColor Green
}

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
        Read-Host "Press Enter to exit..."
        exit 1
    }
}

function Install-Chocolatey {
    Write-Host "Checking/Installing Chocolatey Package Manager..."
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Attempting installation..."
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            Write-Host "Chocolatey installation attempted. Please verify success." -ForegroundColor Yellow
            $env:Path += ";$env:ProgramData\chocolatey\bin" # Add to PATH for current session
        }
        catch {
            Write-Warning "Failed to install Chocolatey. Some dependencies might fail. Error: $_"
        }
    } else {
        Write-Host "Chocolatey already installed." -ForegroundColor Green
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName,

        [Parameter(Mandatory=$true)]
        [string]$PackageId
    )
    Write-Host "Checking/Installing $PackageName (via winget)..."
    if (-not (Get-Command $PackageName -ErrorAction SilentlyContinue)) {
        try {
            winget install --id $PackageId -e --accept-package-agreements --accept-source-agreements -h
            Write-Host "$PackageName installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to install $PackageName via winget. Error: $_"
        }
    } else {
        Write-Host "$PackageName already installed." -ForegroundColor Green
    }
}

function Install-PSModule {
     param(
        [Parameter(Mandatory=$true)]
        [string]$ModuleName
    )
     Write-Host "Checking/Installing $ModuleName PowerShell module..."
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        try {
            Install-Module -Name $ModuleName -Repository PSGallery -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
            Write-Host "$ModuleName module installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to install $ModuleName module. Error: $_"
        }
    } else {
        Write-Host "$ModuleName module already installed." -ForegroundColor Green
    }
}

function Install-NerdFont {
    param (
        [string]$FontName = "CascadiaCode", # The name used in the Nerd Fonts release URL
        [string]$FontDisplayName = "CaskaydiaCove NF", # The name as it appears in Font Settings
        [string]$Version = "3.2.1" # Check Nerd Fonts releases for the latest version
    )

    Write-Host "Checking/Installing Nerd Font: $FontDisplayName..."
    try {
        Add-Type -AssemblyName System.Drawing
        $fontFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
        if ($fontFamilies -notcontains $FontDisplayName) {
            Write-Host "Font not found. Downloading $FontName v$Version..."
            $fontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v${Version}/${FontName}.zip"
            $zipFilePath = Join-Path -Path $env:TEMP -ChildPath "${FontName}.zip"
            $extractPath = Join-Path -Path $env:TEMP -ChildPath "${FontName}"

            Invoke-WebRequest -Uri $fontZipUrl -OutFile $zipFilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download complete. Extracting..."

            Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force -ErrorAction Stop
            Write-Host "Extraction complete. Installing fonts..."

            $fontsShellFolder = (New-Object -ComObject Shell.Application).Namespace(0x14) # 0x14 = Fonts folder

            Get-ChildItem -Path $extractPath -Recurse -Include "*.ttf", "*.otf" | ForEach-Object {
                $fontFileName = $_.Name
                if (-not (Test-Path (Join-Path $env:SystemRoot Fonts $fontFileName))) {
                    Write-Verbose "Installing $($_.Name)"
                    $fontsShellFolder.CopyHere($_.FullName, 0x10) # 0x10 = Supress progress dialogs
                } else {
                    Write-Verbose "Font '$($_.Name)' already exists. Skipping."
                }
            }
            Write-Host "$FontDisplayName fonts installed successfully." -ForegroundColor Green

            Write-Host "Cleaning up temporary files..."
            Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $zipFilePath -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Font '$FontDisplayName' already installed." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to download or install '$FontDisplayName' font. Manual installation required. Error: $_"
    }
}

function Download-ScriptFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,

        [Parameter(Mandatory=$true)]
        [string]$DestinationPath,

        [Parameter(Mandatory=$true)]
        [string]$Description,

        [switch]$BackupExisting
    )

    Write-Host "`nSetting up $Description ($DestinationPath)..."

    # Backup Existing if requested and file exists
    if ($BackupExisting -and (Test-Path -Path $DestinationPath -PathType Leaf)) {
        $backupPath = "$DestinationPath.old"
        Write-Host "Existing $Description found. Backing up to: $backupPath" -ForegroundColor Yellow
        try {
            Copy-Item -Path $DestinationPath -Destination $backupPath -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to backup existing $Description. Will attempt to overwrite. Error: $_"
        }
    }

    # Download the file
    Write-Host "Downloading $Description from $Url..."
    try {
        Invoke-RestMethod -Uri $Url -OutFile $DestinationPath -ErrorAction Stop
        Write-Host "$Description downloaded/updated successfully." -ForegroundColor Green
        return $true
    } catch {
        Write-Error "Failed to download or save the $Description. Error: $_"
        return $false
    }
}

function Show-SetupSummary {
    param(
        [string]$HelperScriptPath,
        [string]$BasePath,
        [string]$AdvancedPath,
        [bool]$AdvancedInstalledAttempted
    )
     Write-Host "`n--- Setup Summary ---" -ForegroundColor Cyan
    if (Test-Path -Path $HelperScriptPath) { Write-Host "- Helper script setup appears successful." -ForegroundColor Green } else { Write-Warning "- Helper script file ($HelperScriptPath) not found."}
    if (Test-Path -Path $BasePath) { Write-Host "- Base profile setup appears successful." -ForegroundColor Green } else { Write-Warning "- Base profile file ($BasePath) not found."}
    if ($AdvancedInstalledAttempted) {
        if (Test-Path -Path $AdvancedPath) { Write-Host "- Advanced profile setup appears successful." -ForegroundColor Green } else { Write-Warning "- Advanced profile file ($AdvancedPath) not found despite attempting download."}
    }

    # Check for key tools
    if (Get-Command starship -ErrorAction SilentlyContinue){ Write-Host "- Starship appears installed." -ForegroundColor Green} else { Write-Warning "- Starship installation may have failed."}
    if (Get-Command zoxide -ErrorAction SilentlyContinue){ Write-Host "- Zoxide appears installed." -ForegroundColor Green} else { Write-Warning "- Zoxide installation may have failed."}
    if (Get-Command eza -ErrorAction SilentlyContinue){ Write-Host "- eza appears installed." -ForegroundColor Green} else { Write-Warning "- eza installation may have failed."}

    Write-Host "`nSetup script finished." -ForegroundColor Cyan
    Write-Host ">>> Please RESTART your PowerShell session for all changes to take effect! <<<" -ForegroundColor White -BackgroundColor DarkMagenta
}

#endregion Functions

# --- Main Script Execution ---

Write-Host "Starting PowerShell Environment Setup..." -ForegroundColor Cyan

#region Initial Checks
Test-IsAdmin
Test-InternetConnection
#endregion Initial Checks

#region Dependency Installation
Write-Host "`n--- Installing Dependencies ---" -ForegroundColor Cyan
Install-Chocolatey
Install-WingetPackage -PackageName "Starship" -PackageId "Starship.Starship"
Install-WingetPackage -PackageName "Zoxide" -PackageId "ajeetdsouza.zoxide"
Install-WingetPackage -PackageName "Eza" -PackageId "eza-community.eza"
Install-PSModule -ModuleName "Terminal-Icons"
Install-NerdFont -FontName "CascadiaCode" -FontDisplayName "CaskaydiaCove NF" -Version "3.2.1"
#endregion Dependency Installation

#region Profile and Helper Script Setup
Write-Host "`n--- Setting up Profile Scripts ---" -ForegroundColor Cyan

# --- Define URLs ---
$BaseProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
$AdvancedProfileUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/profile.ps1"
$HelperScriptUrl = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/refs/heads/main/HelperFunctions.ps1"

# --- Determine Profile Paths and Directory ---
$profilePath = $PROFILE # CurrentUserCurrentHost
$profileDir = Split-Path -Path $profilePath -Parent
$UserAllHostsProfilePath = $PROFILE.CurrentUserAllHosts
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

# --- Download HelperFunctions.ps1 ---
$helperDownloaded = Download-ScriptFile -Url $HelperScriptUrl -DestinationPath $helperScriptPath -Description "Helper Script" -BackupExisting:$false
if (-not $helperDownloaded) {
     Write-Error "Critical helper script failed to download. Profiles may not load correctly."
     # Decide if you want to exit here
     # Read-Host "Press Enter to exit..."; exit 1
}

# --- Base Profile Setup ($PROFILE) ---
Download-ScriptFile -Url $BaseProfileUrl -DestinationPath $profilePath -Description "Base Profile" -BackupExisting:$true
Write-Host "NOTE: Base profile uses auto-update. Use 'ep' alias to edit user-specific profile." -ForegroundColor Yellow


# --- Optional Advanced Profile Setup ($PROFILE.CurrentUserAllHosts) ---
$downloadAdvanced = $false # Flag to track user choice
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
    $downloadAdvanced = $true
    Download-ScriptFile -Url $AdvancedProfileUrl -DestinationPath $UserAllHostsProfilePath -Description "Advanced Profile" -BackupExisting:$true
} else {
    Write-Host "Skipping advanced profile download." -ForegroundColor Yellow
    Write-Host "Your customizations should go in: $UserAllHostsProfilePath (use 'ep' alias later)."
}

#endregion Profile and Helper Script Setup

#region Completion Message
Show-SetupSummary -HelperScriptPath $helperScriptPath -BasePath $profilePath -AdvancedPath $UserAllHostsProfilePath -AdvancedInstalledAttempted $downloadAdvanced
#endregion Completion Message
