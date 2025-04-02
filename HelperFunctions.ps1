<# PowerShell Profile Helper Functions
Version: 1.0
Last Updated: 2025-03-30
Author: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Provides shared helper functions for PowerShell profile scripts.

.DESCRIPTION
This script defines common functions used by both the base
(Microsoft.Powershell_profile.ps1) and advanced (profile.ps1) user profiles.
It includes functions for logging, checking administrator status, and reloading profiles.
This file should be dot-sourced near the beginning of the profile scripts that use it.

Changelog:
- 2025-03-30: Initial creation. Moved Write-LogMessage, Test-AdminRole, Reload-Profile
              from profile.ps1 / base profile to centralize shared logic. Added header.
#>

#region Helper Functions

function Write-LogMessage {
    <#
    .SYNOPSIS
    Writes a formatted message to the console and a specified log file.
    .DESCRIPTION
    Logs a message with a timestamp and severity level to a text file.
    Also writes the message to the appropriate PowerShell stream (Verbose, Warning, or Error)
    based on the specified level. Automatically creates the log directory if it doesn't exist.
    .PARAMETER Message
    The core message text to log.
    .PARAMETER Level
    The severity level of the message. Valid options are 'Information', 'Warning', 'Error'. Defaults to 'Information'.
    'Information' writes to Verbose stream, 'Warning' to Warning stream, 'Error' to Error stream.
    .PARAMETER LogPath
    The full path to the log file. Defaults to "$env:USERPROFILE\PowerShell\logs\profile.log".
    .EXAMPLE
    Write-LogMessage -Message "Operation started." -Level Information
    .EXAMPLE
    Write-LogMessage -Message "Configuration value missing." -Level Warning
    .EXAMPLE
    Write-LogMessage -Message "Critical process failed: $($_.Exception.Message)" -Level Error
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information',

        [string]$LogPath = "$env:USERPROFILE\PowerShell\logs\profile.log"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir -PathType Container)) { # Check specifically for container
        try {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Could not create log directory: $logDir. Error: $_"
            # Avoid writing if directory fails, but don't stop script just for logging failure
        }
    }

    # Attempt to write to log file
    try {
        Add-Content -Path $LogPath -Value $logMessage -ErrorAction Stop
    } catch {
        Write-Warning "Could not write to log file: $LogPath. Error: $_"
    }


    # Write to appropriate PowerShell stream
    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message } # Note: Write-Error behavior depends on $ErrorActionPreference
        default   { Write-Verbose $Message } # Information level logs go to Verbose stream
    }
}

function Test-AdminRole {
    <#
    .SYNOPSIS
    Checks if the current PowerShell session is running with Administrator privileges.
    .DESCRIPTION
    Uses the .NET WindowsPrincipal class to determine if the current user identity is
    part of the built-in Administrators group. Returns $true or $false.
    .OUTPUTS
    System.Boolean - Returns $true if the session is elevated (Administrator), $false otherwise.
    .EXAMPLE
    if (Test-AdminRole) { Write-Host "Running as Admin" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    try {
        $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
        return $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-Warning "Could not determine admin role: $_"
        return $false # Default to false if check fails
    }
}

function Reload-Profile {
    <#
    .SYNOPSIS
    Reloads the current user's PowerShell profile script(s).
    .DESCRIPTION
    Dot-sources the CurrentUserCurrentHost ($PROFILE) and CurrentUserAllHosts
    profile scripts to apply changes made since the session started.
    .EXAMPLE
    Reload-Profile
    #>
    [CmdletBinding()]
    param()

    # Determine paths reliably
    $currentUserCurrentHostPath = $PROFILE # Usually CurrentUserCurrentHost
    $currentUserAllHostsPath = $PROFILE.CurrentUserAllHosts

    Write-Verbose "Attempting to reload profile scripts..."

    # Reload CurrentUserCurrentHost ($PROFILE)
    if (Test-Path -LiteralPath $currentUserCurrentHostPath -PathType Leaf) {
        Write-Verbose "Dot-sourcing profile: $currentUserCurrentHostPath"
        try {
            . $currentUserCurrentHostPath
        } catch {
            Write-Error "Error loading profile '$currentUserCurrentHostPath': $_"
        }
    } else {
        Write-Verbose "Profile file not found, skipping: $currentUserCurrentHostPath"
    }

    # Reload CurrentUserAllHosts (if different and exists)
    if ($currentUserAllHostsPath -ne $currentUserCurrentHostPath) {
        if (Test-Path -LiteralPath $currentUserAllHostsPath -PathType Leaf) {
            Write-Verbose "Dot-sourcing profile: $currentUserAllHostsPath"
            try {
                . $currentUserAllHostsPath
            } catch {
                 Write-Error "Error loading profile '$currentUserAllHostsPath': $_"
            }
        }
        else {
            Write-Verbose "Profile file not found, skipping: $currentUserAllHostsPath"
        }
    }

    Write-Host "Profile(s) reloaded." -ForegroundColor Green
}

#endregion Helper Functions

#region Aliases
Set-Alias -Name reload                -Value Reload-Profile                 -Force
#endregion Aliases
