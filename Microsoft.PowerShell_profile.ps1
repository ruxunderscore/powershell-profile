<# PowerShell Profile (Auto-Updating Base)
Version: 1.04
Last Updated: 2025-03-30
Original Author: ChrisTitusTech (Concept/Base)
Current Maintainer: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Base PowerShell profile with auto-update capabilities, core utilities, and integrations.
Installed and managed via setup.ps1 and repository updates.

.DESCRIPTION
This script serves as the primary PowerShell profile (`$PROFILE`). Key features include:
- Automatic self-update checking against the ruxunderscore/powershell-profile repository.
- Automatic PowerShell update checking via Winget.
- Helper functions for logging (Write-LogMessage) and Admin checks (Test-AdminRole).
- Configuration settings (telemetry opt-out, editor preferences).
- Integration with Terminal-Icons, Chocolatey, Starship, and Zoxide.
- A collection of utility functions (renamed to Verb-Noun) and aliases for common tasks.
- PSReadLine configuration for enhanced command-line editing.
- A mechanism (`Open-UserProfileScript`/`ep`) for users to add customizations in a separate file.
- Direct console feedback (Write-Host) during startup update checks.
#>

<# Changelog:
- 2025-03-29: Initial refactor (v1.03) from CTT concept, adding auto-updates, utilities, PSReadLine config, Starship/Zoxide integration.
- 2025-03-29: Certain utility functions migrated to profile.ps1 (User's custom profile).
- 2025-03-30: Updated header format, added detailed synopsis, attribution, and changelog (v1.03 base).
- 2025-03-30: Moved Write-LogMessage/Test-AdminRole helpers from user profile; refactored logging/admin checks. Renamed functions to Verb-Noun; added Comment-Based Help. Added Write-Host for startup status visibility. Created aliases for original function names; consolidated all aliases to end of script (v1.04).
#>

#region Configuration
### PowerShell Profile Refactor
### Version 1.04 - Refactored & Renamed

$debug = $false

# Define the path to the file that stores the last execution time
$currentDocumentFolder = $([Environment]::GetFolderPath('MyDocuments'))
$timeFilePath = $(Join-Path -Path $currentDocumentFolder -ChildPath "\PowerShell\LastExecutionTime.txt")

# Define the update interval in days, set to -1 to always check
$updateInterval = 7

if ($debug) {
    Write-Host "#######################################" -ForegroundColor Red
    Write-Host "#           Debug mode enabled        #" -ForegroundColor Red
    Write-Host "#          ONLY FOR DEVELOPMENT       #" -ForegroundColor Red
    Write-Host "#                                     #" -ForegroundColor Red
    Write-Host "#       IF YOU ARE NOT DEVELOPING     #" -ForegroundColor Red
    Write-Host "#       JUST RUN \`Update-Profile\`     #" -ForegroundColor Red
    Write-Host "#        to discard all changes       #" -ForegroundColor Red
    Write-Host "#   and update to the latest profile  #" -ForegroundColor Red
    Write-Host "#               version               #" -ForegroundColor Red
    Write-Host "#######################################" -ForegroundColor Red
}


#################################################################################################################################
############                                                                                                         ############
############                                          !!!   WARNING:   !!!                                           ############
############                                                                                                         ############
############                DO NOT MODIFY THIS FILE. THIS FILE IS HASHED AND UPDATED AUTOMATICALLY.                  ############
############                    ANY CHANGES MADE TO THIS FILE WILL BE OVERWRITTEN BY COMMITS TO                      ############
############                       https://github.com/ruxunderscore/powershell-profile.git.                          ############
############                                                                                                         ############
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
############                                                                                                         ############
############                      IF YOU WANT TO MAKE CHANGES, USE THE Edit-Profile FUNCTION                         ############
############                              AND SAVE YOUR CHANGES IN THE FILE CREATED.                                 ############
############                                                                                                         ############
#################################################################################################################################

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Initial GitHub.com connectivity check with 1 second timeout
$global:canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
#endregion

#region Helper Functions
# Helper functions moved from profile.ps1 (User Script) for base profile use.

# --- Load Shared Helper Functions ---
$HelperScriptPath = $null # Ensure variable is reset/scoped locally if needed
try {
    # Construct path relative to the directory containing the currently executing profile script
    $HelperScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "HelperFunctions.ps1"

    if (Test-Path $HelperScriptPath -PathType Leaf) {
        Write-Verbose "Dot-sourcing helper functions from '$HelperScriptPath'..."
        . $HelperScriptPath # Execute the helper script in the current scope

        # Optional: Verify loading by checking if a key function exists now
        if (Get-Command Write-LogMessage -ErrorAction SilentlyContinue) {
            # Use the function now that it should be loaded (logs to Verbose stream)
            Write-LogMessage -Message "Successfully loaded helper functions from '$HelperScriptPath'." -Level Information
        } else {
            # This warning indicates dot-sourcing ran but functions aren't defined - problem inside HelperFunctions.ps1?
            Write-Warning "Dot-sourcing '$HelperScriptPath' seemed to complete, but key helper functions (like Write-LogMessage) are still not defined."
        }
    } else {
        Write-Warning "Helper script not found at expected location: '$HelperScriptPath'. Some profile features may fail."
    }
} catch {
    Write-Error "FATAL: Failed to load critical helper script '$HelperScriptPath'. Profile loading aborted. Error: $_"
    # Stop further profile execution if helpers are essential
    throw "Critical helper functions failed to load."
}
# --- End Load ---

#endregion

#region Updates
# Check for Profile Updates
function Update-BaseProfile {
    <#
    .SYNOPSIS
    Checks the remote GitHub repository for updates to this profile script and applies them if found.
    .DESCRIPTION
    Compares the hash of the current profile ($PROFILE) with the latest version available at
    https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/Microsoft.PowerShell_profile.ps1.
    If the hashes differ, downloads the new version and overwrites the current profile.
    Provides console feedback during the check and logs results using Write-LogMessage.
    .NOTES
    Requires internet connectivity to github.com and raw.githubusercontent.com.
    Suggests restarting the shell after an update.
    Uses a temporary file during the download process.
    #>
    try {
        $url = "https://raw.githubusercontent.com/ruxunderscore/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        # Provide direct feedback to the user THAT a check is happening
        Write-Host "Checking for profile updates..." -ForegroundColor Cyan
        # Log the action (visible in verbose or log file)
        Write-LogMessage -Message "Checking for profile updates from $url" -Level Information

        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction Stop # Stop if download fails
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"

        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            # Provide direct feedback THAT an update occurred
            Write-Host "Profile has been updated. Please restart PowerShell." -ForegroundColor Magenta
            # Log the result
            Write-LogMessage -Message "Profile has been updated. Please restart your shell to reflect changes" -Level Information
        }
        else {
            # Provide direct feedback on the result
            Write-Host "Profile is up to date." -ForegroundColor Green
            # Log the result
            Write-LogMessage -Message "Profile is up to date." -Level Information
        }
    }
    catch {
        # Log the error
        Write-LogMessage -Message "Unable to check for profile updates: $_" -Level Error
        # Provide direct feedback THAT an error occurred
        Write-Warning "Failed to check for profile updates. See log for details."
    }
    finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}

# Check if not in debug mode AND (updateInterval is -1 OR file doesn't exist OR time difference is greater than the update interval)
if (-not $debug -and `
    ($updateInterval -eq -1 -or `
            -not (Test-Path $timeFilePath) -or `
        ((Get-Date) - [datetime]::ParseExact((Get-Content -Path $timeFilePath), 'yyyy-MM-dd', $null)).TotalDays -gt $updateInterval)) {

    Update-Profile
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath

}
elseif (-not $debug) {
    Write-LogMessage -Message "Profile update skipped. Last update check was within the last $updateInterval day(s)." -Level Warning
}
else {
    Write-LogMessage -Message "Skipping profile update check in debug mode" -Level Warning
}

function Invoke-PowerShellUpdateCheck {
    <#
    .SYNOPSIS
    Checks if a newer version of PowerShell Core is available on GitHub and optionally updates using Winget.
    .DESCRIPTION
    Compares the current PowerShell version ($PSVersionTable.PSVersion) with the latest release tag
    found via the GitHub API (api.github.com/repos/PowerShell/PowerShell/releases/latest).
    If an update is needed, it attempts to run 'winget upgrade Microsoft.PowerShell'.
    Provides console feedback and logs results using Write-LogMessage.
    .NOTES
    Requires internet connectivity to api.github.com.
    Requires Winget to be installed and functional for the update process.
    Suggests restarting the shell after an update.
    #>
    try {
        # Provide direct feedback
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        # Log the action
        Write-LogMessage -Message "Checking for PowerShell updates..." -Level Information

        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl -ErrorAction Stop
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')

        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            # Provide direct feedback
            Write-Host "Updating PowerShell to version $latestVersion..." -ForegroundColor Yellow
            # Log the action (use Warning level as it's a significant action)
            Write-LogMessage -Message "Updating PowerShell to version $latestVersion..." -Level Warning

            Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow

            # Provide direct feedback
            Write-Host "PowerShell has been updated. Please restart PowerShell." -ForegroundColor Magenta
            # Log the result
            Write-LogMessage -Message "PowerShell has been updated. Please restart your shell to reflect changes" -Level Information
        }
        else {
            # Provide direct feedback
            Write-Host "PowerShell ($currentVersion) is up to date." -ForegroundColor Green
            # Log the result
            Write-LogMessage -Message "Your PowerShell ($currentVersion) is up to date." -Level Information
        }
    }
    catch {
        # Log the error
        Write-LogMessage -Message "Failed to check or update PowerShell. Error: $_" -Level Error
        # Provide direct feedback THAT an error occurred
        Write-Warning "Failed to check or update PowerShell. See log for details."
    }
}

# skip in debug mode

# Update check logic - uses Invoke-PowerShellUpdateCheck now
if (-not $debug -and `
    ($updateInterval -eq -1 -or `
            -not (Test-Path $timeFilePath) -or `
        ((Get-Date).Date - [datetime]::ParseExact((Get-Content -Path $timeFilePath), 'yyyy-MM-dd', $null).Date).TotalDays -gt $updateInterval)) {

    Invoke-PowerShellUpdateCheck # Renamed function call
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath
}
elseif (-not $debug) {
    Write-LogMessage -Message "PowerShell update check skipped. Last update check was within the last $updateInterval day(s)." -Level Warning
}
else {
    Write-LogMessage -Message "Skipping PowerShell update check in debug mode" -Level Warning
}
#endregion

#region Utilities
function Clear-SystemCache {
    <#
    .SYNOPSIS
    Clears various system and user cache locations in Windows.
    .DESCRIPTION
    Attempts to remove files from common cache/temporary directories, including:
    - Windows Prefetch ($env:SystemRoot\Prefetch)
    - Windows Temp ($env:SystemRoot\Temp)
    - User Temp ($env:TEMP)
    - Internet Explorer Cache ($env:LOCALAPPDATA\Microsoft\Windows\INetCache)
    Logs progress using Write-LogMessage. Silently continues on errors (e.g., files in use).
    .NOTES
    May require Administrator privileges to clear some system locations effectively.
    #>
    Write-LogMessage -Message "Clearing system caches..." -Level Information

    Write-LogMessage -Message "Clearing Windows Prefetch..." -Level Information
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    Write-LogMessage -Message "Clearing Windows Temp..." -Level Information
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-LogMessage -Message "Clearing User Temp..." -Level Information
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-LogMessage -Message "Clearing Internet Explorer Cache..." -Level Information
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-LogMessage -Message "System cache clearing attempt completed." -Level Information
}

# Admin Check and Prompt Customization (Uses Test-AdminRole added earlier)
$isAdmin = Test-AdminRole
function prompt {
    <#
    .SYNOPSIS
    Customizes the PowerShell prompt string based on Admin status.
    .DESCRIPTION
    Sets the command prompt to show the current location followed by:
    - "] # " if running as Administrator.
    - "] $ " if running as a standard user.
    PowerShell automatically calls the function named 'prompt'.
    #>
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    <#
    .SYNOPSIS
    Checks if a command (cmdlet, function, alias, external executable) exists in the current session.
    .PARAMETER Command
    The name of the command to check.
    .EXAMPLE
    Test-CommandExists -Command git
    Returns $true if 'git' can be found, $false otherwise.
    .OUTPUTS
    System.Boolean
    #>
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists pvim) { 'pvim' }
elseif (Test-CommandExists vim) { 'vim' }
elseif (Test-CommandExists vi) { 'vi' }
elseif (Test-CommandExists code) { 'code' }
elseif (Test-CommandExists notepad++) { 'notepad++' }
elseif (Test-CommandExists sublime_text) { 'sublime_text' }
else { 'notepad' }

function New-EmptyFile {
    <#
    .SYNOPSIS
    Creates a new, empty file in the current directory. Equivalent to Unix 'touch'.
    .PARAMETER Path
    The name (or relative path) of the file to create.
    .EXAMPLE
    New-EmptyFile -Path "myfile.txt"
    Creates an empty file named 'myfile.txt'.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    "" | Out-File -FilePath $Path -Encoding ASCII -ErrorAction Stop
}

function Find-FileRecursive {
    <#
    .SYNOPSIS
    Finds files recursively matching a pattern (uses wildcards). Equivalent to 'find *name*'.
    .PARAMETER NamePattern
    The name pattern to search for. Wildcards (*) are supported.
    .EXAMPLE
    Find-FileRecursive -NamePattern "*.log"
    Finds all files ending with '.log' in the current directory and subdirectories.
    .OUTPUTS
    System.String - Outputs the full path of each matching file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$NamePattern
    )
    Get-ChildItem -Recurse -Filter $NamePattern -File -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output $_.FullName
    }
}

# Network Utilities
function Get-PubIP {
    <#
    .SYNOPSIS
    Retrieves the public IP address of the machine using an external service.
    .DESCRIPTION
    Makes a web request to http://ifconfig.me/ip and returns the content, which is the public IP.
    .EXAMPLE
    Get-PubIP
    .NOTES
    Requires internet connectivity. Relies on the availability of ifconfig.me.
    .OUTPUTS
    System.String - The public IP address.
    #>
    (Invoke-WebRequest http://ifconfig.me/ip -ErrorAction Stop).Content
}

# System Utilities
function Start-ElevatedProcess {
    <#
    .SYNOPSIS
    Starts a new process (default: Windows Terminal with PowerShell) with Administrator privileges.
    Equivalent to Unix 'sudo' or 'su'.
    .PARAMETER Command
    [Optional] A string containing the command and arguments to execute within the new elevated PowerShell session.
    If omitted, just opens an elevated Windows Terminal with PowerShell.
    .EXAMPLE
    Start-ElevatedProcess # Opens an elevated PowerShell in Windows Terminal
    Start-ElevatedProcess -Command "Get-Service | Out-GridView" # Runs command elevated
    .NOTES
    Requires Windows Terminal ('wt.exe') to be installed and in the PATH.
    Triggers a UAC prompt.
    #>
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string]$Command
    )
    if ($Command) {
        $argList = "-NoExit -Command `"$Command`"" # Ensure command string is quoted
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe $argList"
    }
    else {
        Start-Process wt -Verb runAs
    }
}

function Get-SystemUptime {
    <#
    .SYNOPSIS
    Displays the system's last boot time and current uptime duration.
    .DESCRIPTION
    Retrieves the system's last boot time using WMI (for PS 5.1) or `net statistics workstation` (for PS Core).
    Calculates the duration since the last boot and displays both the boot time and the uptime in days, hours, minutes, seconds.
    Logs results using Write-LogMessage.
    .EXAMPLE
    Get-SystemUptime
    .NOTES
    The method for getting boot time differs between PowerShell versions.
    Parsing `net statistics` output depends on system locale's date/time format. Includes logic to handle common formats.
    #>
    try {
        # check powershell version
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem -ErrorAction Stop).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)
            $lastBootStr = $bootTime.ToString("yyyy-MM-dd HH:mm:ss") # Use a consistent format for logging
        }
        else {
            $lastBootStrRaw = net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
            if (-not $lastBootStrRaw) { throw "Could not retrieve 'Statistics since' string." }

            # Date format detection logic...
            $dateFormat = $null; $timeFormat = $null # Initialize
            if ($lastBootStrRaw -match '^\d{2}/\d{2}/\d{4}') { $dateFormat = 'MM/dd/yyyy' } # Common US
            elseif ($lastBootStrRaw -match '^\d{2}\.\d{2}\.\d{4}') { $dateFormat = 'dd.MM.yyyy' } # Common EU
            elseif ($lastBootStrRaw -match '^\d{4}-\d{2}-\d{2}') { $dateFormat = 'yyyy-MM-dd' } # ISO
            # Add more date formats as needed...
            else { throw "Unrecognized date format in '$lastBootStrRaw'." }

            # Time format detection logic...
            if ($lastBootStrRaw -match '\b(AM|PM)\b') { $timeFormat = 'h:mm:ss tt' }
            else { $timeFormat = 'HH:mm:ss' }

            $bootTime = [System.DateTime]::ParseExact($lastBootStrRaw, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture) # Use InvariantCulture if format is fixed
            $lastBootStr = $bootTime.ToString("yyyy-MM-dd HH:mm:ss") # Use a consistent format for logging
        }

        # Format the start time
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::CurrentCulture) # Use CurrentCulture for display

        Write-LogMessage -Message "System started on: $formattedBootTime (Raw: $($lastBootStrRaw ?? $lastBootStr))" -Level Information
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray # Keep direct output for this

        $uptime = (Get-Date) - $bootTime
        $days = $uptime.Days; $hours = $uptime.Hours; $minutes = $uptime.Minutes; $seconds = $uptime.Seconds
        $uptimeString = "Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds

        Write-LogMessage -Message $uptimeString -Level Information
        Write-Host $uptimeString -ForegroundColor Blue # Keep direct output for this

    }
    catch {
        Write-LogMessage -Message "An error occurred while retrieving system uptime: $_" -Level Error
    }
}

function Expand-ZipArchiveHere {
    <#
    .SYNOPSIS
    Expands a specified ZIP archive into the current directory.
    .PARAMETER ArchiveFileName
    The name (or relative path) of the .zip file to extract.
    .EXAMPLE
    Expand-ZipArchiveHere -ArchiveFileName "myarchive.zip"
    Extracts contents of myarchive.zip into the current folder.
    .NOTES
    Uses the built-in Expand-Archive cmdlet. Assumes the file exists in the current PWD.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchiveFileName
    )
    $currentDir = $PWD.Path
    Write-LogMessage -Message "Extracting '$ArchiveFileName' to '$currentDir'" -Level Information
    $fullFile = Get-ChildItem -Path $currentDir -Filter $ArchiveFileName | Select-Object -First 1 -ExpandProperty FullName
    if ($fullFile) {
        Expand-Archive -Path $fullFile -DestinationPath $currentDir -Force -ErrorAction Stop
        Write-LogMessage -Message "Successfully extracted '$ArchiveFileName'." -Level Information
    }
    else {
        Write-LogMessage -Message "Archive file '$ArchiveFileName' not found in '$currentDir'." -Level Error
    }
}

function Search-FileContent {
    <#
    .SYNOPSIS
    Searches for a RegEx pattern within files in a directory, or within pipeline input. Equivalent to Unix 'grep'.
    .PARAMETER Regex
    The regular expression pattern to search for.
    .PARAMETER DirectoryPath
    [Optional] The path to the directory containing files to search. If omitted, searches pipeline input.
    .EXAMPLE
    Search-FileContent -Regex "Error:\s+\d+" -DirectoryPath "C:\Logs" # Searches files in C:\Logs
    Get-Content .\myfile.txt | Search-FileContent -Regex "keyword" # Searches pipeline input
    .OUTPUTS
    Microsoft.PowerShell.Commands.MatchInfo - Objects representing matches found by Select-String.
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Regex,

        [Parameter(Position = 1)]
        [string]$DirectoryPath
    )
    if ( $DirectoryPath ) {
        Get-ChildItem $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue | Select-String -Pattern $Regex
    }
    else {
        $input | Select-String -Pattern $Regex
    }
}

function Get-DiskVolumeInfo {
    <#
    .SYNOPSIS
    Displays information about disk volumes. Equivalent to Unix 'df'.
    .DESCRIPTION
    Uses the Get-Volume cmdlet to retrieve and display details about connected disk volumes,
    including drive letter, filesystem type, health status, and size information.
    .EXAMPLE
    Get-DiskVolumeInfo
    .OUTPUTS
    Microsoft.Storage.Management.MSFT_Volume - Objects returned by Get-Volume.
    #>
    Get-Volume
}

function Replace-FileContent {
    <#
    .SYNOPSIS
    Performs a simple string replacement within a specified file. Equivalent to basic 'sed'.
    .PARAMETER FilePath
    The path to the file to modify.
    .PARAMETER FindString
    The exact string to search for.
    .PARAMETER ReplaceString
    The string to replace occurrences of FindString with.
    .EXAMPLE
    Replace-FileContent -FilePath ".\config.txt" -FindString "old_value" -ReplaceString "new_value"
    .NOTES
    Reads the entire file content, performs replacement, and writes the entire content back.
    Not suitable for very large files due to memory usage. Performs literal string replacement, not regex.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$FindString,
        [Parameter(Mandatory = $true)]
        [string]$ReplaceString
    )
    (Get-Content $FilePath -Raw -ErrorAction Stop).Replace($FindString, $ReplaceString) | Set-Content -Path $FilePath -ErrorAction Stop
    Write-LogMessage -Message "Content replacement completed in '$FilePath'." -Level Information
}

function Get-CommandPath {
    <#
    .SYNOPSIS
    Displays the definition or path of a command. Equivalent to Unix 'which'.
    .PARAMETER CommandName
    The name of the command (cmdlet, function, alias, executable) to locate.
    .EXAMPLE
    Get-CommandPath -CommandName git
    Get-CommandPath -CommandName Get-ChildItem
    .OUTPUTS
    System.String - The path or definition of the command.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )
    Get-Command $CommandName -ErrorAction Stop | Select-Object -ExpandProperty Definition
}

function Set-TemporaryEnvironmentVariable {
    <#
   .SYNOPSIS
   Sets an environment variable for the *current PowerShell process only*. Equivalent to Unix 'export'.
   .PARAMETER Name
   The name of the environment variable to set.
   .PARAMETER Value
   The value to assign to the environment variable.
   .EXAMPLE
   Set-TemporaryEnvironmentVariable -Name "MY_VAR" -Value "my_value"
   $env:MY_VAR # Returns "my_value"
   .NOTES
   Changes are not persistent and only affect the current PowerShell session and its child processes.
   #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )
    Set-Item -Force -Path "env:$Name" -Value $Value
    Write-LogMessage -Message "Set environment variable '$Name' for current process." -Level Information
}

function Stop-ProcessByName {
    <#
    .SYNOPSIS
    Stops (kills) all processes matching a specified name. Equivalent to Unix 'pkill'.
    .PARAMETER ProcessName
    The name of the process(es) to stop. Wildcards are not supported by default here, matches exact name.
    .EXAMPLE
    Stop-ProcessByName -ProcessName "notepad"
    .NOTES
    Uses Get-Process | Stop-Process. Errors if the process is not found are suppressed.
    Use with caution.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName
    )
    Get-Process $ProcessName -ErrorAction SilentlyContinue | Stop-Process -Force # Add -Force for robustness
    Write-LogMessage -Message "Attempted to stop process(es) named '$ProcessName'." -Level Information
}

function Get-ProcessByName {
    <#
   .SYNOPSIS
   Lists processes matching a specified name. Equivalent to Unix 'pgrep'.
   .PARAMETER ProcessName
   The name of the process(es) to list.
   .EXAMPLE
   Get-ProcessByName -ProcessName "powershell"
   .OUTPUTS
   System.Diagnostics.Process - Process objects matching the name.
   #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName
    )
    Get-Process $ProcessName -ErrorAction SilentlyContinue # Allow Get-Process errors to show if needed
}

function Get-FileHead {
    <#
    .SYNOPSIS
    Displays the first N lines of a file. Equivalent to Unix 'head'.
    .PARAMETER Path
    The path to the file.
    .PARAMETER Lines
    [Optional] The number of lines to display from the beginning. Defaults to 10.
    .EXAMPLE
    Get-FileHead -Path ".\mylog.txt" -Lines 5 # Shows first 5 lines
    Get-FileHead -Path ".\report.csv"        # Shows first 10 lines
    .OUTPUTS
    System.String[] - The first N lines of the file content.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$Lines = 10
    )
    Get-Content $Path -Head $Lines -ErrorAction Stop
}

function Get-FileTail {
    <#
   .SYNOPSIS
   Displays the last N lines of a file, optionally waiting for new lines. Equivalent to Unix 'tail'.
   .PARAMETER Path
   The path to the file.
   .PARAMETER Lines
   [Optional] The number of lines to display from the end. Defaults to 10.
   .PARAMETER Follow
   [Optional] Switch parameter. If present (-Follow or -f), waits for new lines to be appended to the file (like 'tail -f').
   .EXAMPLE
   Get-FileTail -Path ".\mylog.txt" -Lines 20 # Shows last 20 lines
   Get-FileTail -Path ".\realtimelog.log" -Follow # Shows last 10 lines and waits for more
   .OUTPUTS
   System.String[] - The last N lines of the file content. Waits if -Follow is specified.
   #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$Lines = 10,
        [Alias('f')] # Add alias for the switch parameter
        [switch]$Follow = $false
    )
    Get-Content $Path -Tail $Lines -Wait:$Follow -ErrorAction Stop
}

# Quick File Creation
function New-FileHere {
    <#
    .SYNOPSIS
    Quickly creates a new, empty file in the current directory.
    .PARAMETER Name
    The name of the file to create.
    .EXAMPLE
    New-FileHere -Name "notes.txt"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    New-Item -ItemType File -Path . -Name $Name -ErrorAction Stop | Out-Null # Suppress output object
    Write-LogMessage -Message "Created empty file '$Name' in '$PWD'." -Level Information
}

# Directory Management
function New-DirectoryAndEnter {
    <#
   .SYNOPSIS
   Creates a new directory (including parent directories if needed) and immediately changes into it.
   .PARAMETER DirectoryName
   The name or relative path of the directory to create and enter.
   .EXAMPLE
   New-DirectoryAndEnter -DirectoryName "MyNewProject"
   #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryName
    )
    mkdir $DirectoryName -Force -ErrorAction Stop | Out-Null # mkdir is an alias for New-Item -Type Directory
    Set-Location $DirectoryName -ErrorAction Stop
    Write-LogMessage -Message "Created and entered directory '$DirectoryName'." -Level Information
}

function Move-ItemToRecycleBin {
    <#
    .SYNOPSIS
    Moves a specified file or directory to the Windows Recycle Bin.
    .PARAMETER Path
    The path to the file or directory to move to the Recycle Bin.
    .EXAMPLE
    Move-ItemToRecycleBin -Path ".\oldfile.txt"
    Move-ItemToRecycleBin -Path ".\obsolete_folder"
    .NOTES
    Uses the Shell.Application COM object to perform the 'delete' verb, which typically sends items to the Recycle Bin.
    Logs success or errors using Write-LogMessage.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    try {
        $fullPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path

        if (Test-Path $fullPath) {
            $item = Get-Item $fullPath -ErrorAction Stop

            if ($item.PSIsContainer) { $parentPath = $item.Parent.FullName }
            else { $parentPath = $item.DirectoryName }

            # Ensure parent path is valid before using COM object
            if (-not (Test-Path $parentPath -PathType Container)) { throw "Could not determine valid parent path for '$fullPath'." }

            $shell = New-Object -ComObject 'Shell.Application'
            $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

            if ($shellItem) {
                $shellItem.InvokeVerb('delete')
                Write-LogMessage -Message "Item '$fullPath' has been moved to the Recycle Bin." -Level Information
            }
            else {
                Write-LogMessage -Message "Could not find the shell item '$($item.Name)' within '$parentPath' to send to Recycle Bin." -Level Error
            }
        }
        else {
            # This condition should ideally be caught by Resolve-Path, but double-check
            Write-LogMessage -Message "Item '$fullPath' does not exist." -Level Error
        }
    }
    catch {
        Write-LogMessage -Message "Error moving item '$Path' to Recycle Bin: $_" -Level Error
    }
}
#endregion

#region Aliases & Shortcuts
### Quality of Life Aliases

# Navigation Shortcuts
function Enter-DocumentsDirectory {
    <#
    .SYNOPSIS
    Changes the current location to the user's Documents directory.
    .DESCRIPTION
    Determines the path to the user's Documents folder using Environment.GetFolderPath or a default ($HOME\Documents)
    and then uses Set-Location to navigate there.
    .EXAMPLE
    Enter-DocumentsDirectory
    #>
    $docsPath = if ([System.Environment]::GetFolderPath("MyDocuments")) { [System.Environment]::GetFolderPath("MyDocuments") } else { Join-Path $HOME "Documents" }
    try {
        Set-Location -Path $docsPath -ErrorAction Stop
        Write-LogMessage -Message "Changed location to Documents: $docsPath" -Level Information
    }
    catch {
        Write-LogMessage -Message "Could not change location to Documents path '$docsPath': $_" -Level Error
    }
}

function Enter-DesktopDirectory {
    <#
   .SYNOPSIS
   Changes the current location to the user's Desktop directory.
   .DESCRIPTION
   Determines the path to the user's Desktop folder using Environment.GetFolderPath or a default ($HOME\Desktop)
   and then uses Set-Location to navigate there.
   .EXAMPLE
   Enter-DesktopDirectory
   #>
    $desktopPath = if ([System.Environment]::GetFolderPath("Desktop")) { [System.Environment]::GetFolderPath("Desktop") } else { Join-Path $HOME "Desktop" }
    try {
        Set-Location -Path $desktopPath -ErrorAction Stop
        Write-LogMessage -Message "Changed location to Desktop: $desktopPath" -Level Information
    }
    catch {
        Write-LogMessage -Message "Could not change location to Desktop path '$desktopPath': $_" -Level Error
    }
}

# Enhanced Listing
function Get-ChildItemFormatted {
    <#
    .SYNOPSIS
    Lists items in the current directory using Get-ChildItem -Force | Format-Table -AutoSize. Includes hidden/system items.
    .EXAMPLE
    Get-ChildItemFormatted
    .NOTES
    Alias: la
    #>
    Get-ChildItem -Path . -Force | Format-Table -AutoSize
}

function Get-ChildItemFormattedHidden {
    <#
   .SYNOPSIS
   Lists items in the current directory using Get-ChildItem -Force -Hidden | Format-Table -AutoSize. Explicitly includes hidden items again.
   .EXAMPLE
   Get-ChildItemFormattedHidden
   .NOTES
   Alias: ll. The original `-Hidden` switch is somewhat redundant with `-Force` but kept for clarity/original intent.
   #>
    Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize
}

# Quick Access to System Information
function Get-SystemInformation {
    <#
   .SYNOPSIS
   Displays detailed system information using Get-ComputerInfo.
   .EXAMPLE
   Get-SystemInformation
   .NOTES
   Alias: sysinfo
   .OUTPUTS
   Microsoft.PowerShell.Commands.ComputerInfo - Object containing system details.
   #>
    Get-ComputerInfo
}

# Networking Utilities
function Clear-ClientDnsCache {
    <#
   .SYNOPSIS
   Clears the local DNS resolver cache using Clear-DnsClientCache.
   .EXAMPLE
   Clear-ClientDnsCache
   .NOTES
   Requires Administrator privileges. Alias: flushdns
   #>
    Clear-DnsClientCache -ErrorAction Stop # Requires Admin
    Write-LogMessage -Message "DNS client cache has been flushed." -Level Information
}

# Clipboard Utilities
function Set-ClipboardText {
    <#
    .SYNOPSIS
    Copies the provided text to the clipboard.
    .PARAMETER Text
    The string value to copy to the clipboard.
    .EXAMPLE
    Set-ClipboardText -Text "Hello World"
    "Some Text" | Set-ClipboardText # Also accepts pipeline input
    .NOTES
    Alias: cpy
    #>
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text
    )
    Set-Clipboard -Value $Text
}

function Get-ClipboardText {
    <#
   .SYNOPSIS
   Retrieves text content from the clipboard.
   .EXAMPLE
   Get-ClipboardText
   .NOTES
   Alias: pst
   .OUTPUTS
   System.String - The text content of the clipboard.
   #>
    Get-Clipboard
}
#endregion

#region PSReadLine Configuration
# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode                      = 'Windows'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    Colors                        = @{
        Command   = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator  = '#FFB6C1'  # LightPink (pastel)
        Variable  = '#DDA0DD'  # Plum (pastel)
        String    = '#FFDAB9'  # PeachPuff (pastel)
        Number    = '#B0E0E6'  # PowderBlue (pastel)
        Type      = '#F0E68C'  # Khaki (pastel)
        Comment   = '#D3D3D3'  # LightGray (pastel)
        Keyword   = '#8367c7'  # Violet (pastel)
        Error     = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource              = 'History'
    PredictionViewStyle           = 'ListView'
    BellStyle                     = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Improved prediction settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }
    
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock
#endregion

#region Integrations (Starship, Zoxide)
# Initialize Starship prompt if available
# Assuming $availableDependencies is populated elsewhere or Test-CommandExists is used
if (Test-CommandExists starship) {
    # Simplified check example
    try {
        Invoke-Expression (&starship init powershell)
        # Uses LogMessage - already consistent
        Write-LogMessage -Message "Starship prompt initialized successfully" -Level Information
    }
    catch {
        # Uses LogMessage - already consistent
        Write-LogMessage -Message "Failed to initialize Starship prompt: $_" -Level Warning
    }
}
else {
    Write-LogMessage -Message "Starship command not found. Skipping initialization." -Level Warning
}


## Final Line to set prompt
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Write-LogMessage -Message "Zoxide found. Initializing..." -Level Information
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
else {
    # Use LogMessage for Warning level
    Write-LogMessage -Message "zoxide command not found. Attempting to install via winget..." -Level Warning
    try {
        winget install -e --id ajeetdsouza.zoxide
        # Use LogMessage for Information level
        Write-LogMessage -Message "zoxide installed successfully via winget. Initializing..." -Level Information
        # Need to re-run init after install
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }
    catch {
        # Use LogMessage for Error level
        Write-LogMessage -Message "Failed to install zoxide via winget. Error: $_" -Level Error
    }
}
#endregion

#region Help & Initialization

# Load User Customizations (Potentially from CTTcustom.ps1 or the AllHosts profile)
# Ensure this path is correct for your setup
$UserCustomProfilePath = Join-Path -Path $PSScriptRoot -ChildPath "CTTcustom.ps1" # Example path
if (Test-Path $UserCustomProfilePath) {
    Write-LogMessage -Message "Loading user customizations from '$UserCustomProfilePath'" -Level Information
    try {
        Invoke-Expression -Command "& `"$UserCustomProfilePath`"" # Consider dot-sourcing: . $UserCustomProfilePath
    }
    catch {
        Write-LogMessage -Message "Error loading user customizations from '$UserCustomProfilePath': $_" -Level Error
    }
}
else {
    Write-LogMessage -Message "User customization file not found at '$UserCustomProfilePath'. Skipping." -Level Information
}

# Quick Access to Editing the Profile
function Open-UserProfileScript {
    <#
   .SYNOPSIS
   Opens the current user's 'AllHosts' profile script for editing using the configured editor ($EDITOR).
   .DESCRIPTION
   Identifies the profile script path for 'CurrentUserAllHosts' ($PROFILE.CurrentUserAllHosts)
   and opens it using the editor determined earlier in the profile script ($EDITOR, e.g., vim, code, notepad).
   This is the recommended place for user-specific, persistent customizations.
   .EXAMPLE
   Open-UserProfileScript
   .NOTES
   Alias: ep, Edit-Profile
   #>
    & $EDITOR $PROFILE.CurrentUserAllHosts
}
#endregion
#region Aliases
# Consolidated aliases for built-in cmdlets, external tools, and renamed functions

Write-LogMessage -Message "Setting profile aliases..." -Level Information

# External Editor Alias (Based on $EDITOR detection)
Set-Alias -Name vim -Value $EDITOR -Option AllScope -Force

# --- Aliases for Renamed Functions (Original Name -> New Name) ---
Set-Alias -Name Update-Profile                -Value Update-BaseProfile               -Option AllScope -Force
Set-Alias -Name Update-PowerShell             -Value Invoke-PowerShellUpdateCheck    -Option AllScope -Force
Set-Alias -Name Clear-Cache                   -Value Clear-SystemCache              -Option AllScope -Force
Set-Alias -Name touch                         -Value New-EmptyFile                  -Option AllScope -Force
Set-Alias -Name ff                            -Value Find-FileRecursive            -Option AllScope -Force
Set-Alias -Name admin                         -Value Start-ElevatedProcess          -Option AllScope -Force
Set-Alias -Name uptime                        -Value Get-SystemUptime               -Option AllScope -Force
Set-Alias -Name unzip                         -Value Expand-ZipArchiveHere          -Option AllScope -Force
Set-Alias -Name grep                          -Value Search-FileContent             -Option AllScope -Force
Set-Alias -Name df                            -Value Get-DiskVolumeInfo             -Option AllScope -Force
Set-Alias -Name sed                           -Value Replace-FileContent            -Option AllScope -Force
Set-Alias -Name which                         -Value Get-CommandPath                -Option AllScope -Force
Set-Alias -Name export                        -Value Set-TemporaryEnvironmentVariable -Option AllScope -Force
Set-Alias -Name pkill                         -Value Stop-ProcessByName             -Option AllScope -Force
Set-Alias -Name pgrep                         -Value Get-ProcessByName              -Option AllScope -Force
Set-Alias -Name head                          -Value Get-FileHead                   -Option AllScope -Force
Set-Alias -Name tail                          -Value Get-FileTail                   -Option AllScope -Force
Set-Alias -Name nf                            -Value New-FileHere                   -Option AllScope -Force
Set-Alias -Name mkcd                          -Value New-DirectoryAndEnter          -Option AllScope -Force
Set-Alias -Name trash                         -Value Move-ItemToRecycleBin          -Option AllScope -Force
Set-Alias -Name docs                          -Value Enter-DocumentsDirectory       -Option AllScope -Force
Set-Alias -Name dtop                          -Value Enter-DesktopDirectory         -Option AllScope -Force
Set-Alias -Name la                            -Value Get-ChildItemFormatted         -Option AllScope -Force
Set-Alias -Name ll                            -Value Get-ChildItemFormattedHidden   -Option AllScope -Force
Set-Alias -Name sysinfo                       -Value Get-SystemInformation          -Option AllScope -Force
Set-Alias -Name flushdns                      -Value Clear-ClientDnsCache           -Option AllScope -Force
Set-Alias -Name cpy                           -Value Set-ClipboardText              -Option AllScope -Force
Set-Alias -Name pst                           -Value Get-ClipboardText              -Option AllScope -Force
Set-Alias -Name Edit-Profile                  -Value Open-UserProfileScript         -Option AllScope -Force

# --- Other Common Aliases ---
Set-Alias -Name ep -Value Open-UserProfileScript -Option AllScope -Force # Short alias for editing profile
Set-Alias -Name su -Value Start-ElevatedProcess -Option AllScope -Force # Unix sudo/su equivalent
Set-Alias -Name k9 -Value Stop-ProcessByName -Option AllScope -Force # Quick process kill by name

# Zoxide Aliases (Conditional initialization happens earlier)
# These might be set by zoxide init itself, but defining here ensures they exist if init runs later or fails partially.
# Check if Zoxide's function exists before setting alias, to avoid errors if Zoxide isn't setup
if (Get-Command '__zoxide_z' -ErrorAction SilentlyContinue) {
    Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
}
if (Get-Command '__zoxide_zi' -ErrorAction SilentlyContinue) {
    Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
}


#endregion Aliases
