<# PowerShell Profile
Version: 1.7.1
Last Updated: 2025-03-30
Author: RuxUnderscore <https://github.com/ruxunderscore/>
License: MIT License

.SYNOPSIS
Advanced PowerShell profile with custom functions for file/media management,
Git integration, image processing, and system utilities.

.DESCRIPTION
This profile provides a rich set of functions and configurations aimed at
streamlining development workflows, media organization, and general PowerShell usage.
It includes features like:
- Robust helper functions for logging and admin checks (Note: Core helpers now reside in base profile).
- Advanced file/folder management: CBZ creation with metadata, PDF organization,
  sequential image/video renaming (including Plex/Jellyfin standards),
  permission management, numbered folder creation.
- Image processing via ImageMagick.
- Video metadata retrieval via ffprobe.
- Symbolic link creation for organizing 'favorite' folders.
- Wrappers for external tools (WinUtil, Hastebin).
- Conditional Git integration with helper functions and aliases.
- Extensive Comment-Based Help for functions.
- Dependency checking for required modules and external tools.
#>

<# Changelog:
- 2024-05-20: Initialized Changelog
- 2024-09-08: Disabled `Set-StrictMode -Version Latest` as it causes issues with some ps1 scripts outside of this profile.
- 2024-10-05: Added Rename-AnimeEpisodes function.
- 2025-03-29: Refactored output/error handling for consistency (Verbose, Information, LogMessage). Added Admin checks. Corrected linter warnings (UseNullComparison, UnusedVariable).
- 2025-03-29: Renamed `Rename-AnimeEpisodes` to `Rename-SeriesEpisodes` and `Rename-NewAnimeEpisode` to `Rename-NewSeriesEpisode` for broader use. Added Comment-Based Help examples/stubs.
- 2025-03-29: Added generic `New-NumberedFolders` function, refactored `New-ChapterFolders` and `New-SeasonFolders` to use it. Implemented `-WhatIf` support across modifying functions. Added full Comment-Based Help. Corrected logic error in Compress-ToCBZ.
- 2025-03-29: Centralized file extension lists into global variables ($global:Default*Extensions). Added `Reload-Profile` helper function (renamed from original concept) and alias (`reload`). Added aliases for common custom functions (`rimg`, `mpdf`, `cbz`, `cimg`). Resolved SuppressMessageAttribute issues by renaming.
- 2025-03-30: Parameterized metadata (Writer, Genre, AgeRating, Manga, Language) in `Compress-ToCBZ`. Corrected ComicInfo <Count> tag usage. Adjusted XML heredoc formatting for cleanliness.
- 2025-03-30: Added optional `-PublicationDate` parameter to `Compress-ToCBZ` with multi-format parsing to set Year/Month/Day in ComicInfo.xml.
- 2025-03-30: Updated header format, added License and Synopsis.
- 2025-03-30: Moved core helper functions (Write-LogMessage, Test-AdminRole) to Microsoft.Powershell_profile.ps1 (Base Profile). Moved Aliases region to end of script for better organization.
- 2025-04-07: Changed SeriesName handling in New-SeriesEpisodes and other fixes
#>

#region Configuration
using namespace System.Drawing
using namespace System.Drawing.Imaging
using namespace System.IO

# PowerShell Configuration
$ErrorActionPreference = 'Stop'
Set-PSReadLineOption -EditMode Windows
$ProgressPreference = 'Continue'

# Configure PowerShell history
$MaximumHistoryCount = 1000
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount $MaximumHistoryCount


# Module imports and dependency checks
$requiredModules = @(
    @{Name = 'PSReadLine'; MinimumVersion = '2.1.0' }
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module.Name |
            Where-Object { $_.Version -ge $module.MinimumVersion })) {
        Write-Warning "Required module $($module.Name) (>= $($module.MinimumVersion)) is not installed."
    }
}

function Test-ExternalDependency {
    <#
    .SYNOPSIS
    Checks if an external command-line tool is available in the PATH.
    .DESCRIPTION
    A helper function used during profile loading to verify if required external programs
    (like git, ffprobe, magick, starship) can be found via Get-Command.
    Outputs a warning message if the command is not found.
    .PARAMETER Command
    The name of the command to check (e.g., 'git', 'ffprobe').
    .PARAMETER ErrorMessage
    The warning message to display if the command is not found.
    .OUTPUTS
    System.Boolean - Returns $true if the command is found, $false otherwise.
    .NOTES
    Used internally by the profile setup region.
    #>
    param (
        [string]$Command,
        [string]$ErrorMessage
    )

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Warning $ErrorMessage
        return $false
    }
    return $true
}

$dependencies = @{
    'ffprobe'  = 'FFmpeg tools not found. Some video functions may not work.'
    'starship' = 'Starship prompt not found. Default prompt will be used.'
    'git'      = 'Git not found. Version control functions will be disabled.'
    'magick'   = 'ImageMagick is not installed. Please install from https://imagemagick.org/'
}

$availableDependencies = @{}
foreach ($dep in $dependencies.GetEnumerator()) {
    $availableDependencies[$dep.Key] = Test-ExternalDependency -Command $dep.Key -ErrorMessage $dep.Value
}

# -- START: Added Global Constants --
Write-Verbose "Defining global constants for file extensions..." # Optional verbose message
# Used for file processing/checks where only the extension is needed
$global:DefaultImageCheckExtensions = @('.webp', '.jpeg', '.jpg', '.png')
$global:DefaultVideoCheckExtensions = @('.mkv', '.mp4', '.avi', '.mov', '.wmv', '.m4v')

# Used specifically for Get-ChildItem -Filter parameter which often uses wildcards
$global:DefaultVideoFilterExtensions = @('*.mkv', '*.mp4', '*.avi', '*.mov', '*.wmv', '*.m4v')
# -- END: Added Global Constants --
#endregion

#region Helper Functions
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

#region Generic Functions
function New-NumberedFolders {
    <#
    .SYNOPSIS
    Creates a sequence of numbered folders based on a specified naming format.
    .DESCRIPTION
    Generates folders for a range of numbers (MinNumber to MaxNumber), formatting the folder name
    using the provided NameFormat string (which should include a format specifier like {0:D2} or {0:D3}).
    .PARAMETER MinNumber
    The starting number in the sequence. Mandatory.
    .PARAMETER MaxNumber
    The ending number in the sequence. Mandatory.
    .PARAMETER NameFormat
    A .NET format string used to generate the folder name. The number will be substituted for {0}.
    Example: "Chapter {0:D3}", "season {0:D2}", "Item_{0:D4}". Mandatory.
    .PARAMETER BasePath
    The parent directory where the numbered folders should be created. Defaults to the current directory.
    .EXAMPLE
    PS C:\Manga\MySeries\Volume 1> New-NumberedFolders -MinNumber 1 -MaxNumber 10 -NameFormat "Chapter {0:D3}"
    Creates folders 'Chapter 001' through 'Chapter 010'.
    .EXAMPLE
    PS C:\Shows\MySeries> New-NumberedFolders -MinNumber 1 -MaxNumber 5 -NameFormat "season {0:D2}" -BasePath C:\Shows\MySeries
    Creates folders 'season 01' through 'season 05' inside 'C:\Shows\MySeries'.
    .NOTES
    - Uses New-Item -Force, so it won't error if a folder already exists.
    - Supports -WhatIf to preview folder creation.
    - Uses Write-Verbose for progress and Write-Information for summary.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [int]$MinNumber,

        [Parameter(Mandatory = $true)]
        [int]$MaxNumber,

        [Parameter(Mandatory = $true)]
        [string]$NameFormat, # Example: "Chapter {0:D3}" or "season {0:D2}"

        [Parameter(Mandatory = $false)]
        [string]$BasePath = (Get-Location).Path
    )

    process {
        Write-Verbose "Creating numbered folders from $MinNumber to $MaxNumber using format '$NameFormat' in '$BasePath'."
        if ($MinNumber -gt $MaxNumber) {
            Write-Warning "Minimum number ($MinNumber) is greater than maximum number ($MaxNumber). No folders will be created."
            return
        }

        for ($i = $MinNumber; $i -le $MaxNumber; $i++) {
            try {
                # Format the folder name using the provided string and number padding
                $folderName = $NameFormat -f $i
            }
            catch {
                Write-LogMessage -Level Error -Message "Invalid NameFormat string provided: '$NameFormat'. Error: $_"
                throw "Invalid NameFormat string." # Stop processing if format is bad
            }

            $folderPath = Join-Path -LiteralPath $BasePath -ChildPath $folderName

            if (-not (Test-Path $folderPath -PathType Container)) {
                # Check specifically for container
                # Wrap New-Item
                if ($PSCmdlet.ShouldProcess($folderPath, "Create Directory using format '$NameFormat'")) {
                    Write-Verbose "Creating folder: $folderPath"
                    try {
                        New-Item -LiteralPath $folderPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-LogMessage -Level Error -Message "Failed to create folder '$folderPath': $_"
                        # Decide whether to continue or stop; continuing seems reasonable for folder creation loop
                    }
                }
            }
            else {
                Write-Verbose "Folder already exists: $folderPath"
            }
        }
    }
    end {
        Write-Information "Numbered folder creation completed for range $MinNumber-$MaxNumber in '$BasePath'."
    }
}
#endregion

#region File Management Functions
function Compress-ToCBZ {
    <#
    .SYNOPSIS
    Creates a Comic Book Zip (.cbz) archive from image files in the current directory,
    automatically generating a ComicInfo.xml metadata file.
    .DESCRIPTION
    This function assumes a specific parent/grandparent folder structure to determine
    Series Title, Volume Number, and Chapter Number for the metadata.

    Structure 1: Grandparent (Series) \ Parent (Volume X) \ Current (Chapter Y)
    Structure 2: Parent (Series) \ Current (Chapter Y) (Assumes Volume 1)

    It counts the image files (excluding any existing ComicInfo.xml) for the PageCount,
    creates a ComicInfo.xml file with derived metadata and allows overriding defaults/providing values
    for Genre, AgeRating, Language, Manga format, Writer/Artist, and Publication Date via parameters.

    It compresses all files in the current directory (including the temporary XML) into a .cbz file
    named 'Series Vol.XXX Ch.XXX.cbz' (padded numbers), places it in the parent directory, and finally removes the temporary ComicInfo.xml.
    .PARAMETER Path
    The path to the chapter directory containing the images. Defaults to the current directory (".").
    .PARAMETER Force
    Switch parameter. If specified, allows overwriting an existing .cbz file with the same name.
    .PARAMETER seriesWriter
    [Optional] Specifies the writer of the series for the ComicInfo.xml. Defaults to the same value for Penciller, Inker, Colorist, and CoverArtist.
    .PARAMETER Genre
    [Optional] Specifies the Genre tag for the ComicInfo.xml.
    .PARAMETER AgeRating
    [Optional] Specifies the AgeRating tag for the ComicInfo.xml.
    .PARAMETER PublicationDate
    [Optional] Specifies the publication date for the ComicInfo.xml (Year, Month, Day tags).
    Accepts "YYYY-MM-DD".
    If omitted or unparseable, the Year/Month/Day tags will be empty.
    .PARAMETER LanguageISO
    [Optional] Specifies the LanguageISO tag for the ComicInfo.xml (e.g., 'en', 'ja'). Defaults to 'en'.
    .PARAMETER Manga
    [Optional] Specifies the Manga tag ('Yes' or 'No'). Defaults to 'Yes' ($true). Use -Manga:$false for 'No'.
    .EXAMPLE
    PS C:\Comics\My Indie Comic\Chapter 001> Compress-ToCBZ -seriesWriter "Creator Name" -PublicationDate "2024-11-15"
    Creates CBZ using specified writer and sets Year=2024, Month=11, Day=15 in ComicInfo.xml.
    .NOTES
    - Relies heavily on the parent/grandparent folder names matching 'Volume #' and 'Chapter #'.
    - Uses Write-LogMessage for logging progress and errors.
    - Supports -WhatIf.
    - Publication Date parsing accepts "yyyy-MM-dd" as the format.
    - If PublicationDate cannot be parsed, Year/Month/Day tags will be empty.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Path = (Get-Location).Path, # Corrected default from "." to specific Path property

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$seriesWriter,

        [Parameter(Mandatory = $false)]
        [string]$Genre,

        [Parameter(Mandatory = $false)]
        [string]$AgeRating,

        [Parameter(Mandatory = $false)]
        [string]$PublicationDate,

        [Parameter(Mandatory = $false)]
        [string]$LanguageISO = 'en',

        [Parameter(Mandatory = $false)]
        [bool]$Manga = $true # Default value ($true means 'Yes')
    )

    begin {
        Write-LogMessage -Message "Starting CBZ compression for path: $Path" -Level Information

        if (-not (Test-Path -Path $Path)) {
            Write-LogMessage -Message "Path not found: $Path" -Level Error
            return
        }
    }

    process {
        # Define $comicInfoXmlPath early so it's available in catch block for cleanup
        $comicInfoXmlPath = Join-Path -Path $Path -ChildPath "ComicInfo.xml"

        try {
            # Get the current directory name and its parent
            $currentDir = Split-Path -Leaf (Resolve-Path $Path)
            $parentDir = Split-Path -Leaf (Split-Path -Parent (Resolve-Path $Path))
            $grandparentDir = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent (Resolve-Path $Path)))

            # Extract chapter number
            if ($currentDir -match "Chapter (\d+)") {
                $chapterNumber = [int]$Matches[1]
            }
            else {
                throw "Unable to extract chapter number from folder name '$currentDir'." # Added context
            }

            # Determine volume number and series title
            if ($parentDir -match "Volume (\d+)") {
                $volumeNumber = [int]$Matches[1]
                $seriesTitle = $grandparentDir
            }
            else {
                # If parent isn't Volume, assume parent is Series, Volume is 1
                $volumeNumber = 1
                $seriesTitle = $parentDir
            }

            # --- START: Date Parsing Logic ---
            $parsedDate = $null
            $xmlYear = ''
            $xmlMonth = ''
            $xmlDay = ''

            # Check if the user provided the parameter and it's not just whitespace
            if ($PSBoundParameters.ContainsKey('PublicationDate') -and -not [string]::IsNullOrWhiteSpace($PublicationDate)) {
                Write-Verbose "Attempting to parse PublicationDate: '$PublicationDate'"
                try {
                    # Use only the single format string and InvariantCulture:
                    $parsedDate = [DateTime]::ParseExact($PublicationDate.Trim(), "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture) # <-- Simplified ParseExact
                    Write-Verbose "Successfully parsed PublicationDate '$PublicationDate' to '$($parsedDate.ToString('yyyy-MM-dd'))'."

                    # Extract components if parsing succeeded
                    $xmlYear = $parsedDate.Year.ToString() # Ensure it's a string
                    $xmlMonth = $parsedDate.Month.ToString("00")
                    $xmlDay = $parsedDate.Day.ToString("00")

                }
                catch {
                    # --- MODIFIED INNER CATCH: Use Write-Warning ---
                    # Log a warning if parsing fails, leave Year/Month/Day blank
                    Write-Warning "Could not parse provided PublicationDate '$PublicationDate' using format 'yyyy-MM-dd'. Year/Month/Day tags will be empty. Error: $($_.Exception.Message)"
                    # Reset variables just in case (should already be empty)
                    $xmlYear = ''
                    $xmlMonth = ''
                    $xmlDay = ''
                }
            }
            else {
                # If -PublicationDate not provided, intentionally leave Y/M/D empty
                Write-Verbose "No PublicationDate provided. Year/Month/Day tags will be empty."
            }
            # --- END: Date Parsing Logic ---

            $pageCount = (Get-ChildItem -Path $Path -File | Where-Object { $_.Name -ne "ComicInfo.xml" } | Measure-Object).Count # Added Path

            # Create ComicInfo.xml content
            $comicInfoXml = @"
<?xml version='1.0' encoding='utf-8'?>
<ComicInfo>
  <Series>$seriesTitle</Series>
  <LocalizedSeries></LocalizedSeries>
  <Count></Count>
  <Writer>$seriesWriter</Writer>
  <Penciller>$seriesWriter</Penciller>
  <Inker>$seriesWriter</Inker>
  <Colorist>$seriesWriter</Colorist>
  <Letterer></Letterer>
  <CoverArtist>$seriesWriter</CoverArtist>
  <Genre>$Genre</Genre>
  <AgeRating>$AgeRating</AgeRating>
  <Title>$seriesTitle</Title>
  <Summary></Summary>
  <Tags></Tags>
  <Web></Web>
  <Number>$chapterNumber</Number>
  <Volume>$volumeNumber</Volume>
  <Format></Format>
  <Manga>$(if($Manga){'Yes'}else{'No'})</Manga>
  <Year>$xmlYear</Year>
  <Month>$xmlMonth</Month>
  <Day>$xmlDay</Day>
  <LanguageISO>$LanguageISO</LanguageISO>
  <Notes>ComicInfo.xml created with Compress-ToCBZ on $(Get-Date -Format "yyyy-MM-dd")</Notes>
  <PageCount>$pageCount</PageCount>
</ComicInfo>
"@

            # Define CBZ path info ($comicInfoXmlPath defined earlier)
            $cbzFileName = "{0} Vol.{1:D3} Ch.{2:D3}.cbz" -f $seriesTitle, $volumeNumber, $chapterNumber
            # Place CBZ in the PARENT directory (e.g., the Volume folder or Series folder)
            $parentPath = Split-Path -Parent (Resolve-Path $Path)   # Get the immediate parent path
            $cbzDestinationDir = Split-Path -Parent $parentPath     # Get the parent of the parent
            $cbzFullPath = Join-Path -Path $cbzDestinationDir -ChildPath $cbzFileName

            if ((Test-Path $cbzFullPath) -and -not $Force) {
                throw "CBZ file '$cbzFullPath' already exists. Use -Force to overwrite."
            }

            # Action 1: Save ComicInfo.xml
            if ($PSCmdlet.ShouldProcess($comicInfoXmlPath, "Save temporary ComicInfo.xml")) {
                $comicInfoXml | Out-File -FilePath $comicInfoXmlPath -Encoding utf8 -ErrorAction Stop
            }
            else {
                Write-Warning "WhatIf: Skipping CBZ creation as temporary ComicInfo.xml was not saved."
                return
            }

            # Action 2: Compress files to CBZ
            if ($PSCmdlet.ShouldProcess($cbzFullPath, "Create CBZ archive from contents of '$($Path)'")) {
                # Ensure we are compressing items *inside* the target Path
                Compress-Archive -Path (Join-Path -Path $Path -ChildPath '*') -DestinationPath $cbzFullPath -Force:$Force -ErrorAction Stop # Pass $Force switch
                Write-LogMessage -Message "Created $cbzFileName (in $cbzDestinationDir) with $pageCount pages" -Level Information
                Write-Verbose "Successfully created '$cbzFileName' in '$cbzDestinationDir'."
            }

            # Action 3: Clean up ComicInfo.xml (only if it was actually created)
            if (Test-Path $comicInfoXmlPath) {
                if ($PSCmdlet.ShouldProcess($comicInfoXmlPath, "Remove temporary ComicInfo.xml")) {
                    Remove-Item -Path $comicInfoXmlPath -Force -ErrorAction Stop
                    Write-Verbose "Removed temporary '$comicInfoXmlPath'."
                }
            }

        } # End of main 'try' block
        # --- MODIFIED OUTER CATCH BLOCK ---
        catch {
            Write-Warning "DEBUG: Outer catch triggered. Original error follows:"

            # Attempt cleanup (moved before throw)
            if ($PSCmdlet.ShouldProcess($comicInfoXmlPath, "Attempt cleanup of temporary ComicInfo.xml after error")) {
                 if (Test-Path $comicInfoXmlPath) { Remove-Item -Path $comicInfoXmlPath -Force -ErrorAction SilentlyContinue }
            }

            throw # Let PowerShell print the original error ($_)
        }
        # --- END OF MODIFIED OUTER CATCH BLOCK ---
    } # End of 'process' block

    end {
        Write-Information "CBZ compression process completed for path '$Path'."
        Write-Information "MangaManager is recommended to make any further adjustments to the created CBZ file's metadata (ComicInfo.xml)." # Suggestion for next steps
        Write-Information "Get it here: https://github.com/MangaManagerORG/Manga-Manager"
    }
} # End of function Compress-ToCBZ

function Move-PDFsToFolders {
    <#
    .SYNOPSIS
    Moves PDF files found in a directory into new subfolders named after each PDF's base name.
    .DESCRIPTION
    Scans the specified directory for files with the '.pdf' extension. For each PDF found,
    it creates a new subdirectory named identically to the PDF file (excluding the extension)
    and then moves the PDF file into that newly created subdirectory.
    .PARAMETER DirectoryPath
    The path to the directory containing the PDF files. Defaults to the current directory.
    Can accept input from the pipeline.
    .PARAMETER Force
    Switch parameter. If specified, allows overwriting a file if it somehow already exists
    in the target subfolder (e.g., from a previous run). Also forces creation of the subfolder.
    .EXAMPLE
    PS C:\Downloads> Move-PDFsToFolders
    Moves 'MyDocument.pdf' into 'C:\Downloads\MyDocument\MyDocument.pdf', 'Another.pdf' into 'C:\Downloads\Another\Another.pdf', etc.
    .EXAMPLE
    PS C:\Docs> Get-ChildItem -Filter *.pdf | Move-PDFsToFolders -Force -WhatIf
    Shows which PDFs in C:\Docs would be moved into subfolders, overwriting if necessary, without actually moving them.
    .INPUTS
    System.String[] - Can accept directory paths via pipeline.
    .NOTES
    - Supports -WhatIf and -Confirm through CmdletBinding.
    - Uses Write-LogMessage for logging progress, warnings (file exists), and errors.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)] # Already present
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$DirectoryPath = (Get-Location).Path,

        [switch]$Force
    )

    begin {
        Write-LogMessage -Message "Starting PDF organization in: $DirectoryPath" -Level Information
    }

    process {
        try {
            if (-not (Test-Path -LiteralPath $DirectoryPath)) {
                throw "Directory not found: $DirectoryPath"
            }

            $pdfFiles = Get-ChildItem -LiteralPath $DirectoryPath -Filter *.pdf -File # Ensure only files

            foreach ($pdfFile in $pdfFiles) {
                $folderPath = Join-Path -Path $DirectoryPath -ChildPath $pdfFile.BaseName
                $destination = Join-Path -Path $folderPath -ChildPath $pdfFile.Name

                if ((Test-Path -LiteralPath $destination) -and -not $Force) {
                    Write-LogMessage -Message "File already exists: $destination. Skipping." -Level Warning
                    continue
                }

                # Check if folder needs creating *before* processing the file move
                $folderExists = Test-Path -LiteralPath $folderPath -PathType Container
                if (-not $folderExists) {
                    # Wrap New-Item
                    if ($PSCmdlet.ShouldProcess($folderPath, "Create directory")) {
                        New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
                        Write-Verbose "Created directory '$folderPath'."
                        $folderExists = $true # Assume success for subsequent move check
                    }
                    else {
                        # If WhatIf prevents folder creation, cannot move file
                        Write-Warning "WhatIf: Skipping move of '$($pdfFile.Name)' as directory '$folderPath' would not be created."
                        continue
                    }
                }

                # Wrap Move-Item (already correctly wrapped from previous script)
                if ($folderExists -and $PSCmdlet.ShouldProcess($pdfFile.FullName, "Move to $destination")) {
                    Move-Item -LiteralPath $pdfFile.FullName -Destination $destination -Force:$Force # -Force used for overwrite if -Force switch is passed
                    Write-LogMessage -Message "Moved $($pdfFile.Name) to $folderPath" -Level Information
                    Write-Verbose "Successfully moved '$($pdfFile.Name)' to '$destination'."
                }
            }
        }
        catch {
            Write-LogMessage -Message "Error moving PDFs: $_" -Level Error
            throw
        }
    }
    end {
        Write-Information "PDF organization process completed for path '$DirectoryPath'."
    }
}

function Rename-ImageFilesSequentially {
    <#
    .SYNOPSIS
    Renames image files in a directory to a sequential, zero-padded numeric format (e.g., 001.jpg).
    .DESCRIPTION
    Finds image files (.webp, .jpeg, .jpg, .png) in the specified directory.
    It sorts the files based first on any leading numbers (treating '10a' after '10'), then alphabetically for non-numeric names.
    It uses a temporary subdirectory ('TempRename') to avoid naming collisions during the process.
    Files are moved to the temp directory with sequential names (e.g., 001.ext, 002.ext) and then moved back to the original directory.
    .PARAMETER Path
    The directory containing the image files to rename. Defaults to the current directory.
    .PARAMETER LeadingZeros
    The number of digits to use for the sequential number, padded with leading zeros. Defaults to 3 (e.g., 001, 002 ... 010 ... 100).
    .EXAMPLE
    PS C:\Images> Rename-ImageFilesSequentially
    Renames image files like 'cover.jpg', 'page1.png', 'page10.png', 'page2.png' into '001.jpg', '002.png', '003.png', '004.png' (order depends on sorting).
    .EXAMPLE
    PS C:\Scans> Rename-ImageFilesSequentially -LeadingZeros 4
    Renames images sequentially starting from '0001.webp', '0002.jpg', etc.
    .NOTES
    - Supports -WhatIf and -Confirm through CmdletBinding.
    - Handles common image extensions: .webp, .jpeg, .jpg, .png.
    - Sorting logic prioritizes numeric names, then number+letter names, then others.
    - Uses a temporary subfolder named 'TempRename' which is created and removed automatically.
    - Uses Write-Verbose for detailed steps, Write-Information for summary, and Write-LogMessage for errors.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string]$Path = ".",

        [Parameter(Mandatory = $false)]
        [int]$LeadingZeros = 3 # Default to three leading zeros
    )

    $imageExtensions = $global:DefaultImageCheckExtensions
    $tempDirName = "TempRename"
    $tempPath = Join-Path -Path $Path -ChildPath $tempDirName
    $nameFormat = "{0:D$LeadingZeros}"
    $counter = 1

    # Create a temporary directory if it doesn't exist
    if (-not (Test-Path -LiteralPath $tempPath -PathType Container)) {
        # Minor change: Wrap New-Item for temp dir creation (low impact)
        if ($PSCmdlet.ShouldProcess($tempPath, "Create temporary directory")) {
            Write-Verbose "Creating temporary directory: '$tempPath'"
            New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        }
        else {
            Write-Warning "WhatIf: Cannot proceed without creating temporary directory '$tempPath'."
            return
        }
    }

    # Get all image files
    $imageFiles = Get-ChildItem -LiteralPath $Path | Where-Object { -not $_.PSIsContainer -and $_.Extension -in $imageExtensions }

    # Sort the image files based on the described naming conventions
    $sortedImageFiles = $imageFiles | Sort-Object {
        $baseName = $_.BaseName
        if ($baseName -match '^\d+$') {
            # Pure number: sort as integer
            [int]$baseName
        }
        elseif ($baseName -match '^(\d+)([a-zA-Z]+)$') {
            # Number with sub-letter: sort by number then letter
            [int]$Matches[1], $Matches[2]
        }
        else {
            # Non-numeric or other patterns: push to the end with original name as tie-breaker
            [int]::MaxValue, $baseName
        }
    }, Name

    Write-Verbose "Found $($sortedImageFiles.Count) image files to process."
    Write-Verbose "Moving sorted image files to temporary directory and renaming sequentially."

    foreach ($file in $sortedImageFiles) {
        $extension = $file.Extension
        $newNameBase = $nameFormat -f $counter
        $newTempPath = Join-Path -Path $tempPath -ChildPath "$newNameBase$extension"

        Write-Verbose "Moving and renaming '$($file.Name)' to '$newNameBase$extension' in temporary directory."

        if ($PSCmdlet.ShouldProcess($file.Name, "Rename to '$newNameBase$extension' in temporary directory '$tempPath'")) {
            try {
                Move-Item -Path $file.FullName -Destination $newTempPath -Force -ErrorAction Stop
                Write-Verbose "Successfully moved and renamed '$($file.Name)' to '$newNameBase$extension' in temporary directory."
                $counter++
            }
            catch { Write-LogMessage -Level Error -Message "Error moving and renaming '$($file.Name)': $($_.Exception.Message)" }
        }
    }

    Write-Verbose "Moving sequentially renamed files back to the original directory."
    # Get the sequentially named files from the temporary directory
    $renamedFiles = Get-ChildItem -LiteralPath $tempPath | Where-Object { -not $_.PSIsContainer -and $_.Extension -in $imageExtensions }

    foreach ($file in $renamedFiles) {
        $destinationPath = Join-Path -Path $Path -ChildPath $file.Name
        Write-Verbose "Moving '$($file.Name)' from temporary directory to '$destinationPath'."
        if ($PSCmdlet.ShouldProcess($file.Name, "Move from temporary directory to original location '$destinationPath'")) {
            try {
                Move-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                Write-Verbose "Successfully moved '$($file.Name)' back to original directory."
            }
            catch { Write-LogMessage -Level Error -Message "Error moving '$($file.Name)' back from temporary directory: $($_.Exception.Message)" }
        }
    }

    # Clean up the temporary directory
    Write-Verbose "Cleaning up temporary directory: '$tempPath'"
    # Wrap Remove-Item
    if (Test-Path -LiteralPath $tempPath) {
        # Check if it exists (it might not if -WhatIf stopped creation)
        if ($PSCmdlet.ShouldProcess($tempPath, "Remove temporary directory (Recursive)")) {
            Remove-Item -Path $tempPath -Recurse -Force | Out-Null
            Write-Verbose "Successfully removed temporary directory '$tempPath'."
        }
    }

    # CONSISTENCY: Use Write-Information for final summary/status
    Write-Information "Sequential renaming process completed for path '$Path'."
}

function Rename-NumberedFiles {
    <#
    .SYNOPSIS
    Renames files with purely numeric basenames in a directory to have consistent zero-padding.
    .DESCRIPTION
    Finds all files in the specified path whose base names consist only of digits (e.g., '1.txt', '10.jpg', '05.png').
    It calculates the maximum number of digits found across all such files (e.g., 2 if '10.jpg' is the highest)
    and renames each numeric file to pad its name with leading zeros up to that maximum length (e.g., '1.txt' -> '01.txt', '10.jpg' -> '10.jpg').
    .PARAMETER Path
    The directory path containing the files to rename. Defaults to the current directory.
    .EXAMPLE
    PS C:\Data> Rename-NumberedFiles
    If files '1.dat', '5.dat', '12.dat' exist, they will be renamed to '01.dat', '05.dat', '12.dat'.
    .NOTES
    - Supports -WhatIf (if added via CmdletBinding/ShouldProcess).
    - Only affects files whose base name contains *only* digits. 'File1.txt' or '1a.jpg' are ignored.
    - Uses Write-Verbose for detailed steps and Write-Information for summary. Logs warnings/errors via Write-LogMessage.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [string]$Path = "."
    )

    # Get all files in the specified path
    $files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue

    # Filter files with numeric names
    $numericFiles = $files | Where-Object { $_.BaseName -match '^\d+$' }

    # Sort files numerically
    $sortedFiles = $numericFiles | Sort-Object { [int]($_.BaseName) }

    if ($sortedFiles.Count -eq 0) {
        Write-Verbose "No files with purely numeric names found in '$Path'."
        return
    }

    # Get the maximum number of digits
    $maxDigits = ($sortedFiles | Measure-Object -Property BaseName -Maximum).Maximum.ToString().Length
    Write-Verbose "Found $($sortedFiles.Count) numeric files. Padding to $maxDigits digits."

    # Rename files
    foreach ($file in $sortedFiles) {
        $newName = "{0:D$maxDigits}$($file.Extension)" -f [int]($file.BaseName)

        # Avoid renaming if the name is already correct
        if ($file.Name -eq $newName) {
            Write-Verbose "Skipping '$($file.Name)' as it already has the correct padding."
            continue
        }

        try {
            # Wrap Rename-Item
            if ($PSCmdlet.ShouldProcess($file.FullName, "Rename to '$newName'")) {
                Rename-Item -Path $file.FullName -NewName $newName -Force -ErrorAction Stop
                Write-Verbose "Renamed: $($file.Name) -> $newName"
            }
        }
        catch {
            Write-LogMessage -Level Warning -Message "Failed to rename $($file.Name): $_"
        }
    }
    Write-Information "Numeric file renaming process completed for path '$Path'."
}

function Set-StandardSeasonFolderNames {
    <#
    .SYNOPSIS
    Renames season folders in the current directory to a standard 'season XX' format.

    .DESCRIPTION
    Searches the current directory for folders whose names match patterns like 'season 1', 'Season_02', etc.
    It extracts the season number and renames the folder to the standard 'season XX' format (e.g., 'season 01', 'season 02'), ensuring a two-digit padded number.

    .EXAMPLE
    PS C:\MySeries> Set-StandardSeasonFolderNames
    Looks for folders like 'season 1', 'season_2', 'Season 03' in C:\MySeries and renames them to
    'season 01', 'season 02', 'season 03' respectively.

    .NOTES
    - Only operates in the current directory.
    - Looks for folders starting with 'season' (case-insensitive), potentially followed by whitespace or underscore, then digits.
    - Renames are done using Rename-Item -Force.
    - Uses Write-Verbose for detailed output and Write-Information for summary.
    - Errors are logged using Write-LogMessage.
    - Supports -WhatIf (if added via CmdletBinding/ShouldProcess).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param ()

    # Get the current directory
    $Path = (Get-Location).Path; Write-Verbose "Standardizing season folder names in: $Path"

    # Get all directories in the current path that match the pattern "season <number>"
    $seasonFolders = Get-ChildItem -LiteralPath $Path -Directory | Where-Object { $_.Name -match '(?i)^season[_\s]*\d+$' }

    if ($seasonFolders.Count -eq 0) { Write-Verbose "No folders matching the pattern 'season [number]' found."; return }

    Write-Verbose "Found potential season folders:"; $seasonFolders | Format-Table -Property Name, FullName | Out-String | Write-Verbose

    foreach ($folder in $seasonFolders) {
        # Extract the season number from the folder name
        if ($folder.Name -match '(?i)season[_\s]*(\d+)') {
            $seasonNumber = "{0:D2}" -f [int]$Matches[1]  # Format the season number with leading zero if necessary
            $newName = "season $seasonNumber"  # Construct the new standardized folder name
            $parentPath = Split-Path -Path $folder.FullName -Parent  # Get the parent path of the folder

            # Ensure the parent path is not empty
            if (-not [string]::IsNullOrEmpty($parentPath)) {
                $newPath = Join-Path -Path $parentPath -ChildPath $newName  # Construct the full path for the new folder name

                # Rename the folder if the new name is different from the current name
                if ($folder.Name -ne $newName) {
                    try {
                        # Wrap Rename-Item
                        # Note: $newPath contains the full destination path including the new name
                        if ($PSCmdlet.ShouldProcess($folder.FullName, "Rename folder to '$newName' (full path: '$newPath')")) {
                            Rename-Item -LiteralPath $folder.FullName -NewName $newPath -Force -ErrorAction Stop
                            Write-Verbose "Renamed: $($folder.Name) -> $newName"
                        }
                    }
                    catch { Write-LogMessage -Level Error -Message "Failed to rename $($folder.Name): $_" }
                }
                else {
                    # CONSISTENCY: Use Write-Verbose for info
                    Write-Verbose "No renaming needed for: $($folder.Name)"
                }
            }
            else {
                # CONSISTENCY: Use Write-LogMessage for errors
                Write-LogMessage -Level Error -Message "Failed to get parent path for folder: $($folder.FullName)"
            }
        }
        else {
            # This case should ideally not be hit due to the Where-Object filter, but good for safety
            Write-LogMessage -Level Warning -Message "Could not extract season number from folder name (unexpected): $($folder.Name)"
        }
    }

    # CONSISTENCY: Use Write-Information for final summary
    Write-Information "Season folder name standardization complete!"
}

function Rename-SeriesEpisodes {
    <#
    .SYNOPSIS
    Renames video files within season folders (or the current folder) to a standard series episode format.

    .DESCRIPTION
    This function processes video files (mkv, mp4, avi, etc.) located within 'season XX' subfolders of the current directory,
    or directly within the current directory if no season folders are found.
    It renames the files sequentially to the standard Plex/Jellyfin format: 'series_name_sXXeYY.ext'.

    The series name is derived from the first file found unless provided via the SeriesName parameter.
    Season numbers (sXX) are derived from the 'season XX' folder names or use the DefaultSeason parameter.
    Episode numbers (eYY) are assigned sequentially based on the sorted file list within each season.

    The function attempts to clean common group tags (e.g., '[Group]') from the beginning of original filenames
    before attempting to derive the series name.

    .PARAMETER SeriesName
    An optional string specifying the series name to use in the renamed files. Spaces will be replaced with underscores.
    If not provided, the function attempts to derive the name from the first video file found in the first season folder (or current directory).

    .PARAMETER DefaultSeason
    The season number (integer) to use if processing files outside of a 'season XX' folder structure, or if a folder name doesn't match the pattern. Defaults to 1.

    .EXAMPLE
    PS C:\Path\To\My Show> Rename-SeriesEpisodes
    Processes 'season 01', 'season 02' subfolders, derives the series name, and renames episodes like 'my_show_s01e01.mkv', 'my_show_s02e01.mkv', etc.

    .EXAMPLE
    PS C:\Path\To\My Show\season 03> Rename-SeriesEpisodes -SeriesName "My Awesome Show"
    Processes only the current 'season 03' folder, using the provided series name, resulting in files like 'my_awesome_show_s03e01.mkv', etc.

    .EXAMPLE
    PS C:\Path\To\My Show\Specials> Rename-SeriesEpisodes -DefaultSeason 0
    Processes files in the current 'Specials' directory, using season number 0 (s00) and deriving the series name, e.g., 'my_show_s00e01.mkv'.

    .NOTES
    - Supported video extensions: .mkv, .mp4, .avi, .mov, .wmv, .m4v.
    - Deriving the series name from filenames can be unreliable if filenames are inconsistent. Providing -SeriesName is recommended for accuracy.
    - Files are sorted by name before assigning episode numbers. Ensure original files sort correctly for proper numbering.
    - Uses Write-Verbose for detailed steps, Write-Information for summary, Write-Warning for non-critical issues, and Write-LogMessage for errors.
    - Supports -WhatIf (if added via CmdletBinding/ShouldProcess).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$SeriesName,

        [Parameter(Mandatory = $false)]
        [int]$DefaultSeason = 1
    )

    # Define supported video file extensions
    $videoExtensions = $global:DefaultVideoFilterExtensions

    # Format SeriesName if provided (replace spaces with underscores)
    if ($SeriesName) {
        $SeriesName = $SeriesName -replace '\s+', '_'
        Write-Verbose "Using provided SeriesName: $SeriesName"
    }

    # Get the current directory
    $BaseDirectory = (Get-Location).Path
    Write-Verbose "Base directory: $BaseDirectory"

    # Check if the current directory is a season folder
    if ($BaseDirectory -match '(?i)(\\season\s*\d+)$') {
        # Simplified regex
        Write-Verbose "Running within a season folder: $(Split-Path -Leaf $BaseDirectory)"
        $seasonFolders = @((New-Object -TypeName PSObject -Property @{ Name = (Split-Path -Leaf $BaseDirectory); FullName = $BaseDirectory }))
    }
    else {
        # Get all season folders
        Write-Verbose "Searching for season folders in $BaseDirectory"
        $seasonFolders = Get-ChildItem -Path $BaseDirectory -Directory | Where-Object { $_.Name -match '(?i)^season\s*\d+$' }

        if ($seasonFolders.Count -eq 0) {
            Write-LogMessage -Level Warning -Message "No season folders found in $BaseDirectory. Processing files in base directory using default season number: $DefaultSeason"
            # Create a dummy object to represent the base directory as the folder to process
            $seasonFolders = @((New-Object -TypeName PSObject -Property @{ Name = "DefaultSeason"; FullName = $BaseDirectory }))
        }
        else {
            Write-Verbose "Found $($seasonFolders.Count) season folders to process."
        }
    }

    # Determine SeriesName from first file if not provided (do this once)
    $derivedSeriesName = $null
    if (-not $SeriesName -and $seasonFolders.Count -gt 0) {
        Write-Verbose "SeriesName not provided, attempting to derive from first video file..."
        $firstFolderFiles = @()
        foreach ($ext in $videoExtensions) {
            $firstFolderFiles += Get-ChildItem -LiteralPath $seasonFolders[0].FullName -Filter $ext -File -ErrorAction SilentlyContinue
        }
        if ($firstFolderFiles.Count -gt 0) {
            $firstFileSorted = $firstFolderFiles | Sort-Object Name | Select-Object -First 1
            $cleanFirstName = $firstFileSorted.Name -replace '(?i)^\[.*?\]\s*', ''
            if ($cleanFirstName -match '(?i)^(.*?)\s*(-|\[|\.)') {
                # Added period as separator
                $derivedSeriesName = ($Matches[1].Trim() -replace '\s+', '_').ToLower()
                Write-Verbose "Derived SeriesName: $derivedSeriesName"
                $effectiveSeriesName = $derivedSeriesName
            }
            else {
                Write-LogMessage -Level Warning -Message "Could not derive series name from first file: $($firstFileSorted.Name)"
            }
        }
        else {
            Write-LogMessage -Level Warning -Message "No video files found in first folder ($($seasonFolders[0].Name)) to derive series name."
        }
    }
    else {
      $effectiveSeriesName = $SeriesName
    }
    # Use provided SeriesName or the derived one
    # $effectiveSeriesName = $SeriesName -or $derivedSeriesName

    if (-not $effectiveSeriesName) {
        Write-LogMessage -Level Error -Message "Cannot proceed without a SeriesName (either provide one or ensure files allow derivation)."
        return
    }

    foreach ($seasonFolder in $seasonFolders) {
        Write-Verbose "Processing folder: $($seasonFolder.FullName)"
        # Extract the season number from the folder name or use the default season number
        $folderSeason = $DefaultSeason
        if ($seasonFolder.Name -match '(?i)season\s*(\d+)') {
            # Match specific 'season' prefix
            $folderSeason = [int]$Matches[1]
        }
        elseif ($seasonFolder.Name -eq "DefaultSeason") {
            # Keep default season number if it's the dummy object
            Write-Verbose "Using default season number: $DefaultSeason"
        }
        else {
            Write-LogMessage -Level Warning -Message "Folder '$($seasonFolder.Name)' doesn't match 'season XX' format, using default season $DefaultSeason."
        }
        Write-Verbose "Using Season Number: $folderSeason"

        # Get all video files in the current season folder
        $files = @()
        foreach ($ext in $videoExtensions) {
            $files += Get-ChildItem -LiteralPath $seasonFolder.FullName -Filter $ext -File -ErrorAction SilentlyContinue # Added -File and SilentlyContinue
        }

        if ($files.Count -eq 0) {
            Write-Verbose "No video files found in folder: $($seasonFolder.FullName)"
            continue # Move to the next season folder
        }

        # Sort files by name to attempt correct episode numbering
        $sortedFiles = $files | Sort-Object Name

        # Initialize episode counter
        $episodeCounter = 1

        foreach ($file in $sortedFiles) {
            # Get the file extension from the original file
            $extension = $file.Extension.ToLower()

            # Construct new file name
            $newName = "{0}_s{1:d2}e{2:d2}{3}" -f $effectiveSeriesName, $folderSeason, $episodeCounter, $extension

            # Construct full path for the new file
            $newPath = Join-Path $seasonFolder.FullName $newName

            # Avoid renaming if the name is already correct
            if ($file.Name -eq $newName) {
                Write-Verbose "Skipping '$($file.Name)', already correctly named."
                $episodeCounter++ # Increment even if skipped to maintain sequence for next files
                continue
            }

            # Rename the file
            try {
                if ($PSCmdlet.ShouldProcess($file.FullName, "Rename to '$newName'")) {
                    Rename-Item -LiteralPath $file.FullName -NewName $newPath -Force -ErrorAction Stop # Pass $newPath here as it includes the target directory
                    Write-Verbose "Renamed: $($file.Name) -> $newName"
                }
            }
            catch {
                # CONSISTENCY: Use Write-LogMessage for errors
                Write-LogMessage -Level Error -Message "Failed to rename '$($file.Name)' to '$newName': $_"
            }

            # Increment episode counter
            $episodeCounter++
        }
    }

    # CONSISTENCY: Use Write-Information for final summary - UPDATE NAME
    Write-Information "Series episode renaming complete!"
}

function Rename-NewSeriesEpisode {
    <#
    .SYNOPSIS
    Renames a single new video episode file to the standard 'series_name_sXXeYY.ext' format based on existing files in the same directory.

    .DESCRIPTION
    This function takes the path to a single video file (e.g., a newly downloaded episode).
    It examines other video files (currently .mkv) in the same directory that already match the 'series_name_sXXeYY.mkv' pattern.
    It determines the correct Series Name and Season Number (sXX) from the existing files with the highest episode number.
    It then calculates the next sequential Episode Number (eYY) and renames the input file accordingly.

    If no correctly named existing files are found, it attempts to parse the Series Name from the input filename
    (using a common pattern like '[Group] Series Name - 01 ...') and assumes it's Season 01, Episode 01.

    .PARAMETER FilePath
    The full path to the single video file that needs to be renamed. The path can be quoted and contain spaces. Backticks from tab-completion are handled.

    .EXAMPLE
    PS C:\MyShow\Season 02> Rename-NewSeriesEpisode -FilePath '.\[Subs] My Show - 15 [1080p].mkv'
    Assuming 'my_show_s02e14.mkv' exists, this renames the new file to 'my_show_s02e15.mkv'.

    .EXAMPLE
    PS C:\MyShow\Season 01> Rename-NewSeriesEpisode -FilePath '.\First.Episode.S01E01.mkv'
    If no other 'my_show_s01eXX.mkv' files exist, it might try to derive 'my_show' (depending on parsing logic) and rename it to 'my_show_s01e01.mkv'.

    .NOTES
    - Works for TV Shows, Anime, and other series following a Season/Episode structure.
    - Checks if the input file extension is in the globally defined list ($global:DefaultVideoCheckExtensions).
    - Assumes existing files consistently use the target naming format ('series_name_sXXeYY.mkv'). Inconsistent naming might lead to incorrect results.
    - Parsing the series name from the new file when no others exist is less reliable than using existing files.
    - Uses Write-Verbose for detailed steps and Write-LogMessage for errors/warnings.
    - Supports -WhatIf (if added via CmdletBinding/ShouldProcess).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    # Remove PowerShell's auto-completion backticks from the file path
    $cleanFilePath = ($FilePath.Trim("`'") -replace '`', '') # Trim both backticks and single quotes potentially added by completion
    Write-Verbose "Original FilePath: $FilePath"
    Write-Verbose "Cleaned FilePath: $cleanFilePath"

    # Get the file info using Get-Item with -LiteralPath to handle special characters
    try {
        $file = Get-Item -LiteralPath $cleanFilePath -ErrorAction Stop
        Write-Verbose "File found: $($file.FullName)"
    }
    catch {
        # CONSISTENCY: Use Write-LogMessage for errors
        Write-LogMessage -Level Error -Message "Could not find file: '$cleanFilePath'. Error: $_"
        return
    }

    # Check if the file extension is mkv (or other desired video types)
    if ($file.Extension -notin $global:DefaultVideoCheckExtensions) {
        # Example: limit to mkv/mp4
        Write-LogMessage -Level Error -Message "File '$($file.Name)' has extension '$($file.Extension)' which is not in the supported list defined in `$global:DefaultVideoCheckExtensions."
        return
    }

    # Get the directory
    $BaseDirectory = $file.DirectoryName
    Write-Verbose "Base Directory: $BaseDirectory"

    # Extract the series name and season number from existing files (matching the target format)
    $existingFiles = Get-ChildItem -LiteralPath $BaseDirectory -Filter "*.mkv" -File | Where-Object { $_.Name -match '(?i)^(.+)_s(\d{2})e(\d{2})\.mkv$' }

    $seriesName = $null
    $seasonNumber = 1 # Default if no existing files
    $maxEpisode = 0

    if ($existingFiles.Count -eq 0) {
        # If no existing renamed files found, try to parse the *new* file's name (less reliable)
        Write-Verbose "No existing renamed files found. Attempting to parse series name from '$($file.Name)' and assuming S01E01."
        # Example parsing logic (adjust regex as needed for common download formats)
        if ($file.Name -match '(?i)^\[.*?\]\s*(.+?)\s*-\s*(\d+)') {
            # Example: [Group] Series Name - 01 ...
            $seriesName = ($Matches[1].Trim() -replace '\s+', '_').ToLower()
            $seasonNumber = 1 # Assume season 1 for the first file
            $newEpisodeNumber = 1 # Assume episode 1
            Write-Verbose "Derived series name: '$seriesName'. Starting with S01E01."
        }
        else {
            Write-LogMessage -Level Error -Message "Cannot determine series name from filename '$($file.Name)' and no existing renamed files found."
            return
        }
    }
    else {
        # Get the highest episode number and consistent series/season from existing files
        Write-Verbose "Found $($existingFiles.Count) existing renamed files. Determining next episode number."
        $seriesName = $null # Reset
        $seasonNumber = 0 # Reset

        foreach ($existingFile in $existingFiles | Sort-Object { [int]($_.Name -replace '(?i)^.+_s\d{2}e(\d{2})\.mkv$', '$1') }) {
            # Sort by episode num
            if ($existingFile.Name -match '(?i)^(.+)_s(\d{2})e(\d{2})\.mkv$') {
                $currentSeriesName = $Matches[1]
                $currentSeasonNumber = [int]$Matches[2]
                $currentEpisodeNumber = [int]$Matches[3]

                # Use the details from the highest episode number file for consistency
                if ($currentEpisodeNumber -ge $maxEpisode) {
                    # Use >= to handle single existing file case
                    $maxEpisode = $currentEpisodeNumber
                    # Standardize on the series/season from the latest episode found
                    if ($seriesName -ne $currentSeriesName -and $null -ne $seriesName) {
                        # Null check fixed
                        Write-LogMessage -Level Warning -Message "Inconsistent series names found ('$seriesName' vs '$currentSeriesName'). Using name from latest episode."
                    }
                    if ($seasonNumber -ne $currentSeasonNumber -and $seasonNumber -ne 0) {
                        Write-LogMessage -Level Warning -Message "Inconsistent season numbers found ('$seasonNumber' vs '$currentSeasonNumber'). Using season from latest episode."
                    }
                    $seriesName = $currentSeriesName
                    $seasonNumber = $currentSeasonNumber
                }
            }
        }

        if ($null -eq $seriesName) {
            # Null check fixed
            Write-LogMessage -Level Error -Message "Could not determine series name or season from existing files despite finding some."
            return # Should not happen if regex matches
        }

        # Increment the episode number for the new file
        $newEpisodeNumber = $maxEpisode + 1
        Write-Verbose "Determined Series: '$seriesName', Season: $seasonNumber, Highest Episode: $maxEpisode. New episode number: $newEpisodeNumber"
    }

    # Construct the new file name
    $newFileName = "{0}_s{1:d2}e{2:d2}{3}" -f $seriesName, $seasonNumber, $newEpisodeNumber, $file.Extension # Use original extension
    $newFilePath = Join-Path -Path $BaseDirectory -ChildPath $newFileName
    Write-Verbose "New FilePath proposed: $newFilePath"

    # Check if target file already exists (maybe it was already renamed?)
    if (Test-Path -LiteralPath $newFilePath) {
        Write-LogMessage -Level Warning -Message "Target file '$newFileName' already exists. Skipping rename for '$($file.Name)'."
        return
    }

    # Rename the file
    try {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Rename to '$newFileName'")) {
            Rename-Item -LiteralPath $file.FullName -NewName $newFileName -Force -ErrorAction Stop
            Write-Verbose "Successfully renamed file '$($file.Name)' to '$newFileName'"
        }
    }
    catch {
        Write-LogMessage -Level Error -Message "Failed to rename '$($file.Name)' to '$newFileName': $_"
    }
    # No summary message needed for single file function
}

function Set-RecursivePermissions {
    <#
    .SYNOPSIS
    Recursively sets 'Modify' permissions for the 'Everyone' group on a specified directory and its contents.
    .DESCRIPTION
    This function grants the 'Everyone' group 'Modify' access rights to the specified folder
    and all files and subfolders contained within it, recursively.
    It uses the .NET FileSystemAccessRule and Set-Acl cmdlet.
    *** USE WITH CAUTION! *** Granting 'Everyone:Modify' is highly permissive and may have security implications.
    .PARAMETER Path
    The path to the root directory where permissions should be applied. Defaults to the current directory.
    .EXAMPLE
    PS C:\SharedData> Set-RecursivePermissions -Path .\MyFolder -Verbose
    Sets 'Everyone:Modify' on 'C:\SharedData\MyFolder' and everything inside it, showing progress.
    .NOTES
    - **REQUIRES ADMINISTRATOR PRIVILEGES TO RUN.** The function will throw an error if not run as Administrator.
    - Use this function only when you fully understand the implications of granting broad modify access.
    - It replaces existing ACL rules for 'Everyone' using SetAccessRule.
    - Uses Write-Verbose for progress and Write-LogMessage for errors.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [string]$Path = (Get-Location)
    )

    # CONSISTENCY: Admin Check
    begin {
        if (-not (Test-AdminRole)) {
            Write-LogMessage -Level Error -Message "Administrator privileges are required to set permissions using this function."
            # Use throw to ensure the pipeline stops if this function is called incorrectly
            throw "Administrator privileges required."
        }
        Write-Verbose "Administrator privileges verified."
    }

    process {
        try {
            # Convert path to literal path to handle special characters
            $LiteralPath = (Resolve-Path -LiteralPath $Path).ProviderPath # Ensure it's a resolved, provider path
            Write-Verbose "Setting permissions recursively for path: $LiteralPath"

            # Get the parent item first
            $ParentItem = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop # Add -Force for hidden items

            # Get all child items recursively using LiteralPath
            $ChildItems = Get-ChildItem -LiteralPath $LiteralPath -Recurse -Force |
            Where-Object { $_ -ne $null }

            # Combine parent and children
            $Items = @($ParentItem) + @($ChildItems)
            Write-Verbose "Found $($Items.Count) items (including root) to process."


            foreach ($Item in $Items) {
                # Skip if item somehow became null
                if ($null -eq $Item) { continue } # Rule Followed: $null on left

                $ItemPath = $null # Reset for safety
                try {
                    $ItemPath = $Item.FullName
                    if ([string]::IsNullOrEmpty($ItemPath)) {
                        # Preferred method for strings
                        Write-LogMessage -Level Warning -Message "Skipping item with null or empty FullName."
                        continue
                    }

                    Write-Verbose "Processing permissions for: $ItemPath"
                    # Get current ACL using PowerShell cmdlet
                    $Acl = Get-Acl -LiteralPath $ItemPath -ErrorAction Stop

                    # Check if ACL retrieval failed (Acl object would be null)
                    if ($null -eq $Acl) {
                        # Rule Followed: $null on left
                        Write-LogMessage -Level Warning -Message "Could not retrieve ACL for $ItemPath. Skipping."
                        continue
                    }

                    # Create the access rule for Everyone:Modify
                    $Account = [System.Security.Principal.NTAccount]"Everyone"
                    $Rights = [System.Security.AccessControl.FileSystemRights]::Modify
                    $Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
                    $Propagation = [System.Security.AccessControl.PropagationFlags]::None
                    $Type = [System.Security.AccessControl.AccessControlType]::Allow

                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $Account, $Rights, $Inheritance, $Propagation, $Type
                    )

                    # Modify and set the ACL
                    # Use SetAccessRule instead of AddAccessRule to replace existing rules for 'Everyone' if conflicting
                    $Acl.SetAccessRule($AccessRule)

                    # Apply the modified ACL
                    if ($PSCmdlet.ShouldProcess($ItemPath, "Set ACL rule 'Everyone:Modify' (Inherited)")) {
                        Set-Acl -LiteralPath $ItemPath -AclObject $Acl -ErrorAction Stop
                        Write-Verbose "Successfully set 'Everyone:Modify' permission for: $ItemPath"
                    }
                }
                catch {
                    # Log errors for individual items
                    Write-LogMessage -Level Error -Message "Failed to set permissions for '$($ItemPath ?? $Item.Name)': $($_.Exception.Message)"
                    # Continue processing other items
                    continue
                }
            }
        }
        catch {
            # Log errors during item retrieval or outer processing
            Write-LogMessage -Level Error -Message "Failed during permission setting process for path '$Path'. Error: $($_.Exception.Message)"
            # Optionally re-throw if you want the script to halt completely on outer errors
            # throw $_
        }
    }

    End {
        # CONSISTENCY: Use Write-Information for summary
        Write-Information "Permission setting operation completed for path '$Path'."
    }
}
#endregion

#region Folder Creation Functions
function New-ChapterFolders {
    <#
    .SYNOPSIS
    Creates a sequence of numbered chapter folders (e.g., 'Chapter 001', 'Chapter 002') in a specified directory. Uses New-NumberedFolders internally.
    .PARAMETER MinimumChapter
    The starting chapter number in the sequence.
    .PARAMETER MaximumChapter
    The ending chapter number in the sequence.
    .PARAMETER BasePath
    The parent directory where the chapter folders should be created. Defaults to the current directory.
    .EXAMPLE
    PS C:\Manga\MySeries\Volume 1> New-ChapterFolders -MinimumChapter 1 -MaximumChapter 10
    Creates folders 'Chapter 001' through 'Chapter 010'.
    .LINK
    New-NumberedFolders
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Enter the minimum Chapter number.")]
        [int]$MinimumChapter,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the maximum Chapter number.")]
        [int]$MaximumChapter,

        [Parameter(Mandatory = $false)]
        [string]$BasePath = (Get-Location).Path
    )
    # Call the generic function, passing the specific format
    New-NumberedFolders -MinNumber $MinimumChapter -MaxNumber $MaximumChapter -NameFormat "Chapter {0:D3}" -BasePath $BasePath
}

function New-SeasonFolders {
    <#
    .SYNOPSIS
    Creates a sequence of numbered season folders (e.g., 'season 01', 'season 02') in a specified directory. Uses New-NumberedFolders internally.
    .PARAMETER MinimumSeason
    The starting season number in the sequence.
    .PARAMETER MaximumSeason
    The ending season number in the sequence.
    .PARAMETER BasePath
    The parent directory where the season folders should be created. Defaults to the current directory.
    .EXAMPLE
    PS C:\Shows\MySeries> New-SeasonFolders -MinimumSeason 1 -MaximumSeason 5
    Creates folders 'season 01' through 'season 05'.
    .LINK
    New-NumberedFolders
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Enter the minimum Season number.")]
        [int]$MinimumSeason,

        [Parameter(Mandatory = $true, HelpMessage = "Enter the maximum Season number.")]
        [int]$MaximumSeason,

        [Parameter(Mandatory = $false)]
        [string]$BasePath = (Get-Location).Path
    )
    # Call the generic function, passing the specific format
    New-NumberedFolders -MinNumber $MinimumSeason -MaxNumber $MaximumSeason -NameFormat "season {0:D2}" -BasePath $BasePath
}
#endregion

#region Image Processing Functions
function Convert-ImageFormat {
    <#
    .SYNOPSIS
    Batch converts images from one format to another using the ImageMagick 'magick' command.
    .DESCRIPTION
    Finds all images matching the InputFormat extension in the specified Path(s) and converts them
    to the OutputFormat, placing the results in the OutputPath directory.
    Supports optional quality settings (for JPG/WEBP), optimization flags, and deleting original files.
    .PARAMETER InputFormat
    The file extension of the source images (e.g., 'png', 'jpg', 'webp').
    .PARAMETER OutputFormat
    The desired file extension for the converted images (e.g., 'jpg', 'webp', 'png').
    .PARAMETER OutputPath
    The directory where converted images will be saved. Defaults to the current directory. Will be created if it doesn't exist.
    .PARAMETER KeepOriginal
    Switch parameter. If specified, the original input files will NOT be deleted after successful conversion. Defaults to deleting originals.
    .PARAMETER Quality
    Integer (0-100) specifying the quality setting for lossy formats like JPG and WEBP. Defaults to 85. Ignored for lossless formats unless overridden by optimization flags.
    .PARAMETER Optimize
    Switch parameter. If specified, applies some basic optimization settings during conversion:
    - JPG/JPEG: Adds '-strip -interlace Plane'.
    - PNG: Adds '-strip -define png:compression-level=9'.
    - WEBP: Adds '-define webp:lossless=true' (Note: Overrides Quality for WEBP).
    .PARAMETER LogPath
    The path to the log file for recording conversion progress and errors. Defaults to "$env:USERPROFILE\PowerShell\logs\imageconversion.log".
    .PARAMETER Path
    The directory or directories containing the input images. Defaults to the current directory. Can accept multiple paths and pipeline input.
    .EXAMPLE
    PS C:\Input> Convert-ImageFormat png jpg -OutputPath C:\Output -Quality 90 -KeepOriginal
    Converts all PNGs in C:\Input to JPGs in C:\Output with 90% quality, keeping the original PNGs.
    .EXAMPLE
    PS C:\Temp> Get-ChildItem -Directory | Convert-ImageFormat webp png -Optimize
    Converts all WEBPs found in subdirectories of C:\Temp to optimized PNGs in the current directory (C:\Temp), deleting the original WEBPs.
    .INPUTS
    System.String[] - Can accept input directory paths via the pipeline for the Path parameter.
    .NOTES
    - REQUIRES ImageMagick to be installed and the 'magick' command available in the system PATH.
    - Supported formats include: jpg, jpeg, png, gif, bmp, webp, tiff, heic, pdf, svg (validation performed).
    - Uses Write-LogMessage extensively for logging and Write-Information for the final summary. Write-Verbose shows the magick command being executed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0)] [string]$InputFormat,
        [Parameter(Mandatory = $true, Position = 1)] [string]$OutputFormat,
        [Parameter(Position = 2)] [string]$OutputPath = (Get-Location).Path,
        [Parameter(Position = 3)] [switch]$KeepOriginal,
        [Parameter(Position = 4)] [int]$Quality = 85,
        [Parameter(Position = 5)] [switch]$Optimize,
        [Parameter(Position = 6)] [string]$LogPath = "$env:USERPROFILE\PowerShell\logs\imageconversion.log",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] [string[]]$Path = (Get-Location).Path
    )

    begin {
        $errorCount = 0
        $successCount = 0
        if (-not $availableDependencies['magick']) {
            $errorMsg = "ImageMagick required..."
            Write-LogMessage -Message $errorMsg -Level Error -LogPath $LogPath
            throw $errorMsg
        }
        $OutputPath = (Resolve-Path -Path $OutputPath -ErrorAction Stop).Path
        if (-not (Test-Path -Path $OutputPath)) {
            try {
                New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
                Write-LogMessage -Message "Created output directory: $OutputPath" -Level Information -LogPath $LogPath
            }
            catch {
                Write-LogMessage -Message "Failed to create output directory: $_" -Level Error -LogPath $LogPath
                throw
            }
        }
        $supportedFormats = @('jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'heic', 'pdf', 'svg')
        if ($InputFormat -notin $supportedFormats) {
            $errorMsg = "Input format '$InputFormat' not supported..."
            Write-LogMessage -Message $errorMsg -Level Error -LogPath $LogPath
            throw $errorMsg
        }
        if ($OutputFormat -notin $supportedFormats) {
            $errorMsg = "Output format '$OutputFormat' not supported..."
            Write-LogMessage -Message $errorMsg -Level Error -LogPath $LogPath
            throw $errorMsg
        }
        Write-LogMessage -Message "Starting batch conversion: $InputFormat -> $OutputFormat" -Level Information -LogPath $LogPath
    }

    process {
        foreach ($currentPath in $Path) {
            try {
                $resolvedPath = (Resolve-Path -Path $currentPath -ErrorAction Stop).Path
                Write-LogMessage -Message "Processing directory: $resolvedPath" -Level Information -LogPath $LogPath
            }
            catch {
                Write-LogMessage -Message "Failed to resolve path $currentPath : $_" -Level Error -LogPath $LogPath
                continue
            }
            try {
                $imageFiles = Get-ChildItem -Path $resolvedPath -Filter "*.$InputFormat" -File -ErrorAction Stop
            }
            catch {
                Write-LogMessage -Message "Error accessing directory $resolvedPath : $_" -Level Error -LogPath $LogPath
                continue
            }
            if ($imageFiles.Count -eq 0) {
                Write-LogMessage -Message "No .$InputFormat files found in $resolvedPath" -Level Warning -LogPath $LogPath
                continue
            }

            foreach ($imageFile in $imageFiles) {
                $outputFilePath = Join-Path -Path $OutputPath -ChildPath ($imageFile.BaseName + ".$OutputFormat"); $magickArgs = @('convert', "`"$($imageFile.FullName)`""); # ... (add optimize/quality args) ...

                if ($Optimize) {
                    switch ($OutputFormat.ToLower()) {
                        'jpg' { $magickArgs += @('-strip', '-interlace', 'Plane') }
                        'jpeg' { $magickArgs += @('-strip', '-interlace', 'Plane') }
                        'png' { $magickArgs += @('-strip', '-define', 'png:compression-level=9') }
                        'webp' { $magickArgs += @('-define', 'webp:lossless=true') }
                    }
                    Write-LogMessage -Message "Applied optimization settings for $OutputFormat" -Level Information -LogPath $LogPath
                }
                if ($OutputFormat -in @('jpg', 'jpeg', 'webp')) {
                    $magickArgs += @('-quality', $Quality)
                }
                $magickArgs += "`"$outputFilePath`""


                try {
                    Write-LogMessage -Message "Processing: $($imageFile.FullName)" -Level Information -LogPath $LogPath # Keep detailed log
                    $cmdString = "magick $($magickArgs -join ' ')"
                    Write-Verbose "Executing command: $cmdString" # Use Verbose for console command view

                    # We can't make Start-Process respect -WhatIf for the magick command itself,
                    # but we proceed assuming conversion happens for the potential Remove-Item step.
                    $process = Start-Process -FilePath 'magick' -ArgumentList $magickArgs -Wait -NoNewWindow -PassThru

                    if ($process.ExitCode -eq 0) {
                        $successCount++
                        Write-LogMessage -Message "Successfully converted: $($imageFile.Name) -> $outputFilePath" -Level Information -LogPath $LogPath
                        Write-Verbose "Successfully converted: $($imageFile.Name) -> $outputFilePath"

                        if (-not $KeepOriginal) {
                            if ($PSCmdlet.ShouldProcess($imageFile.FullName, "Remove original file after conversion")) {
                                Write-Verbose "Removing original file: $($imageFile.FullName)"
                                Remove-Item -Path $imageFile.FullName -Force
                                Write-LogMessage -Message "Removed original file: $($imageFile.FullName)" -Level Information -LogPath $LogPath
                            }
                        }
                    }
                    else {
                        throw "ImageMagick process exited with code $($process.ExitCode)"
                    }
                }
                catch {
                    $errorCount++
                    Write-LogMessage -Message "Error converting $($imageFile.Name): $_" -Level Error -LogPath $LogPath
                }
            }
        }
    }

    end {
        $summary = "Conversion completed. $successCount files converted successfully. $errorCount errors occurred."
        Write-LogMessage -Message $summary -Level Information -LogPath $LogPath
        Write-Information $summary
    }
}
#endregion

#region Media Information Functions
function Get-VideoInfo {
    <#
    .SYNOPSIS
    Retrieves basic video metadata (codec, resolution, duration) for specified video files using ffprobe.
    .DESCRIPTION
    Uses the 'ffprobe' command-line tool (part of FFmpeg) to extract technical information
    about video files. Returns a custom object for each processed file.
    .PARAMETER Path
    An array of paths to the video files to analyze. Can accept input from the pipeline. Mandatory.
    .PARAMETER IncludeAudio
    Switch parameter. If specified, includes the codec name of the first audio stream ('AudioCodec') in the output object.
    .PARAMETER IncludeSubtitles
    Switch parameter. If specified, includes a count of embedded subtitle tracks ('SubtitleTracks') in the output object.
    .EXAMPLE
    PS C:\Videos> Get-VideoInfo -Path '.\MyMovie.mkv', '.\Clip.mp4' -IncludeAudio
    Gets video codec, resolution, and duration, plus the audio codec, for the two specified files.
    .EXAMPLE
    PS C:\Videos> Get-ChildItem -Filter *.mkv | Get-VideoInfo -IncludeAudio -IncludeSubtitles
    Gets video, audio, and subtitle info for all MKV files in the current directory.
    .INPUTS
    System.String[] - Accepts video file paths via the pipeline.
    .OUTPUTS
    PSCustomObject - Outputs a custom object for each successfully processed file with properties like:
    - Path (string)
    - Filename (string)
    - VideoCodec (string)
    - Resolution (string, e.g., '1920x1080')
    - Duration (string, seconds)
    - AudioCodec (string, if -IncludeAudio specified)
    - SubtitleTracks (int, if -IncludeSubtitles specified)
    .NOTES
    - REQUIRES FFmpeg to be installed and the 'ffprobe' command available in the system PATH.
    - Uses Write-LogMessage for warnings (file not found) and errors during processing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Path,

        [switch]$IncludeAudio,
        [switch]$IncludeSubtitles
    )

    begin {
        if (-not $availableDependencies['ffprobe']) {
            throw "FFprobe is required for this function but was not found."
        }
    }

    process {
        foreach ($filePath in $Path) {
            try {
                if (-not (Test-Path -LiteralPath $filePath)) {
                    Write-LogMessage -Message "File not found: $filePath" -Level Warning
                    continue
                }

                $videoInfo = [PSCustomObject]@{
                    Path       = $filePath
                    Filename   = Split-Path -Leaf $filePath
                    VideoCodec = & ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $filePath
                    Resolution = & ffprobe -v error -select_streams v:0 -show_entries stream=width, height -of csv=p=0:s=x $filePath
                    Duration   = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $filePath
                }

                if ($IncludeAudio) {
                    $videoInfo | Add-Member -MemberType NoteProperty -Name AudioCodec -Value `
                    (& ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $filePath)
                }

                if ($IncludeSubtitles) {
                    $videoInfo | Add-Member -MemberType NoteProperty -Name SubtitleTracks -Value `
                    (@(& ffprobe -v error -select_streams s -show_entries stream=index, codec_name, language -of csv=p=0 $filePath).Count)
                }

                $videoInfo
            }
            catch {
                Write-LogMessage -Message "Error processing $filePath : $_" -Level Error
            }
        }
    }
}
#endregion

#region Symbolic Link Functions
function New-FavoriteLinks {
    <#
    .SYNOPSIS
    Creates directory junctions (symbolic links) in a destination folder for specific source folders marked with a star emoji (⭐).
    .DESCRIPTION
    Recursively searches the SourcePath for directories whose names end with the '⭐' emoji.
    For each matching folder found, it attempts to create a directory junction (using 'cmd /c mklink /J') in the DestinationPath.

    The name of the junction is derived from the source folder structure, ideally formatted as 'Artist - Work Name'
    if the source folder is found at 'SourcePath\Artist\Work Name⭐'. If not nested directly under an 'Artist' folder,
    it defaults to 'Work Name'.
    .PARAMETER SourcePath
    The root directory to search recursively for folders ending with '⭐'. Mandatory.
    .PARAMETER DestinationPath
    The directory where the directory junctions (links) will be created. Will be created if it doesn't exist. Mandatory.
    .EXAMPLE
    PS C:\> New-FavoriteLinks -SourcePath D:\Manga -DestinationPath C:\MangaFavorites
    Searches D:\Manga for folders like 'D:\Manga\ArtistName\Cool Series⭐'. If found, creates a junction
    at 'C:\MangaFavorites\ArtistName - Cool Series' pointing to 'D:\Manga\ArtistName\Cool Series⭐'.
    .NOTES
    - Requires Administrator privileges or Developer Mode enabled on Windows to create junctions. A warning is issued if not running as Admin, but creation is still attempted.
    - The link naming convention works best if starred folders are nested one level deep under an 'Artist' folder within the SourcePath.
    - Uses 'cmd /c mklink /J' for creating junctions.
    - Uses Write-Verbose for detailed progress/status and Write-LogMessage for warnings/errors.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    begin {
        # Junction creation often requires elevation or Developer Mode enabled
        if (-not (Test-AdminRole)) {
            Write-LogMessage -Level Warning -Message "Administrator privileges or Developer Mode may be required to create junctions. Proceeding attempt..."
            # Don't throw, just warn, as it might work depending on user settings (Dev Mode)
        }
        # Ensure destination exists
        if (-not (Test-Path -LiteralPath $DestinationPath -PathType Container)) {
            if ($PSCmdlet.ShouldProcess($DestinationPath, "Create destination directory")) {
                Write-LogMessage -Level Information -Message "Destination path '$DestinationPath' does not exist. Creating..."
                try { New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null } catch { Write-LogMessage -Level Error -Message "Failed to create destination directory '$DestinationPath': $_."; throw "Failed to create destination directory." }
            }
            else {
                Write-Warning "WhatIf: Cannot create links as destination directory '$DestinationPath' would not be created."
                # Need to stop the function here if destination isn't created. Using 'return' in begin is tricky.
                # Let's throw, caught by PowerShell before Process block runs usually.
                throw "WhatIf: Destination directory creation skipped."
            }
        }
    }

    process {
        $foldersWithStar = @() # Initialize
        try {
            $foldersWithStar = Get-ChildItem -LiteralPath $SourcePath -Directory -Recurse -ErrorAction Stop | Where-Object { $_.Name -match '⭐$' } # Added trailing $
            Write-Verbose "Found $($foldersWithStar.Count) folders marked with ⭐ in '$SourcePath'."
        }
        catch {
            Write-LogMessage -Level Error -Message "Failed to list directories in source path '$SourcePath': $_"
            return # Cannot proceed if source cannot be read
        }

        # Loop through each folder and create symbolic links
        foreach ($folder in $foldersWithStar) {
            $folderName = $folder.Name
            $linkName = $null
            $linkPath = $null

            try {
                # Try to determine relative path and artist (adjust if structure differs)
                $relativePath = $folder.FullName.Substring($SourcePath.Length).TrimStart('\/')
                $pathParts = $relativePath -split '[\\/]'
                if ($pathParts.Count -ge 2) {
                    $artist = $pathParts[0] # Assumes structure is SourcePath\Artist\Work⭐
                    $linkName = "$artist - $($folderName.TrimEnd('⭐').Trim())" # Cleaner link name
                }
                else {
                    # Fallback if not nested under an artist folder
                    $linkName = $folderName.TrimEnd('⭐').Trim()
                }

                $linkPath = Join-Path -Path $DestinationPath -ChildPath $linkName

                # Check if the junction already exists
                if (Test-Path -LiteralPath $linkPath) {
                    # Verify if it's actually a Junction and points to the right target
                    $existingItem = Get-Item -LiteralPath $linkPath -Force
                    if ($existingItem.LinkType -ne 'Junction' -or $existingItem.Target -ne $folder.FullName) {
                        Write-LogMessage -Level Warning -Message "Item '$linkName' already exists at '$linkPath' but is not a correct junction. Skipping."
                    }
                    else {
                        Write-Verbose "Junction already exists and is correct: '$linkPath'"
                    }
                }
                else {
                    # Wrap Start-Process for mklink
                    # Note: The target/action description for ShouldProcess is less specific here,
                    # as we are controlling the execution of 'cmd', not 'mklink' directly from PowerShell's perspective.
                    if ($PSCmdlet.ShouldProcess("cmd.exe", "Execute 'mklink /J ""$linkPath"" ""$($folder.FullName)""' to create junction")) {
                        Write-Verbose "Creating Junction for '$($folder.FullName)' at '$($linkPath)'"
                        $cmdArgs = "/c mklink /J `"$linkPath`" `"$($folder.FullName)`""
                        $process = Start-Process cmd -ArgumentList $cmdArgs -Wait -NoNewWindow -PassThru -ErrorAction Stop

                        if ($process.ExitCode -eq 0) {
                            # CONSISTENCY: Use Write-Verbose for success detail
                            Write-Verbose "Junction created successfully: '$linkPath' -> '$($folder.FullName)'"
                        }
                        else {
                            # Error message likely printed by mklink itself
                            Write-LogMessage -Level Error -Message "mklink command failed with exit code $($process.ExitCode) for link '$linkName'."
                        }
                    }
                }
            }
            catch {
                # CONSISTENCY: Use Write-LogMessage for errors
                Write-LogMessage -Level Error -Message "Failed to process or create link for folder '$($folder.FullName)' (Proposed link name: '$linkName'): $_"
            }
        }
        Write-Information "Favorite link creation process completed."
    }
}
#endregion

#region External Tools
function Invoke-WinUtil {
    <#
    .SYNOPSIS
    Runs the latest WinUtil full-release script from Chris Titus Tech.
    .DESCRIPTION
    Downloads and executes the WinUtil script using Invoke-Expression.
    .EXAMPLE
    Invoke-WinUtil
    .NOTES
    Requires internet connectivity.
    #>
    [CmdletBinding()]
    param()
    Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

function Invoke-WinUtilDev {
    <#
    .SYNOPSIS
    Runs the latest WinUtil pre-release script from Chris Titus Tech.
    .DESCRIPTION
    Downloads and executes the WinUtil development script using Invoke-Expression.
    .EXAMPLE
    Invoke-WinUtilDev
    .NOTES
    Requires internet connectivity. Use with caution as it's a pre-release version.
    #>
    [CmdletBinding()]
    param()
    Invoke-RestMethod https://christitus.com/windev | Invoke-Expression
}

function Upload-Hastebin {
    <#
    .SYNOPSIS
    Uploads the content of a specified file to Chris Titus Tech's hastebin instance.
    .DESCRIPTION
    Reads the content of the provided file and POSTs it to http://bin.christitus.com/documents.
    Copies the resulting URL to the clipboard and outputs it to the console.
    .PARAMETER FilePath
    The path to the file whose content should be uploaded. Mandatory.
    .EXAMPLE
    Upload-Hastebin -FilePath .\my-script.ps1
    .NOTES
    Requires internet connectivity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File path does not exist: $FilePath"
        return
    }

    $Content = Get-Content $FilePath -Raw
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Set-Clipboard $url
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}

#endregion

#region Git Integration
if ($availableDependencies['git']) {
    function Git-Status {
        <#
        .SYNOPSIS
        Wrapper function for 'git status'.
        .DESCRIPTION
        Retrieves the current status of the Git repository in the current directory.
        This function is useful for scripts or functions that need to check the status of the repository.
        .NOTES
        Requires 'git' command to be available. Typically aliased to 'gst'.
        #>
        [CmdletBinding()]
        param()
        git status
    }

    function Git-GetBranch {
        <#
        .SYNOPSIS
        Wrapper function for 'git branch'.
        .DESCRIPTION
        Returns the current Git branch name.
        This function is useful for scripts or functions that need to know the current branch context.
        .NOTES
        Requires 'git' command to be available. Typically aliased to 'gb'.
        #>
        [CmdletBinding()]
        param()
        git branch
    }

    function Git-SwitchBranch {
        <#
        .SYNOPSIS
        Wrapper function for 'git checkout <branch>'.
        .DESCRIPTION
        Switches to a specified Git branch. If no branch name is provided, defaults to 'main'.
        .PARAMETER BranchName
        The name of the Git branch to switch to.
        .EXAMPLE
        Switch-GitBranch dev
        Checks out the 'dev' branch. Defaults to 'main' if no branch name is provided.
        .NOTES
        Requires 'git' command to be available. Typically aliased to 'gco'.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $false)]
            [string]$BranchName = "main"
        )
        git checkout $BranchName
    }

    function Git-Add {
        <#
        .SYNOPSIS
        Wrapper function for 'git add .'.
        .DESCRIPTION
        Stages all changes in the current directory for the next commit.
        This includes new files, modified files, and deleted files.
        .NOTES
        Requires 'git' command to be available. Typically used before committing changes.
        #>
        [CmdletBinding()]
        param()
        git add .
    }

    function Git-CommitMessage {
        <#
        .SYNOPSIS
        Wrapper function for 'git commit -m <message>'.
        .DESCRIPTION
        Commits the staged changes with a specified commit message.
        .PARAMETER CommitMessage
        The commit message to use for the commit. This parameter is mandatory.
        .EXAMPLE
        .\Git-CommitMessage -CommitMessage "Added new feature X"
        Commits the staged changes with the message "Added new feature X".
        .NOTES
        Requires 'git' command to be available. This is typically used after staging changes with Git-Add.
        This function is designed to be used in conjunction with Git-Add.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, HelpMessage = "Enter the commit message.")]
            [string]$CommitMessage
        )
        git commit -m "$CommitMessage"
    }

    function Git-Push {
        <#
        .SYNOPSIS
        Wrapper function for 'git push'.
        .DESCRIPTION
        Pushes the committed changes to the remote repository.
        .NOTES
        Requires 'git' command to be available. This is typically used after committing changes with Git-CommitMessage.
        #>
        [CmdletBinding()]
        param()
        git push
    }

    function Git-Clone {
        <#
        .SYNOPSIS
        Wrapper function for 'git clone'.
        .DESCRIPTION
        Clones a remote Git repository to a local directory.
        This function simplifies the cloning process by allowing you to specify the repository URL and the destination path.
        .PARAMETER RepoUrl
        The URL of the remote Git repository to clone. This parameter is mandatory.
        .PARAMETER DestinationPath
        The local directory where the repository will be cloned. If not specified, defaults to the current directory.
        .EXAMPLE
        .\Git-Clone https://github.com/ruxunderscore/powershell-profile.git -DestinationPath M:\MyRepo
        Clones the repository from the specified URL into the local directory M:\MyRepo.
        .NOTES
        Requires 'git' command to be available. This is typically used to create a local copy of a remote repository.
        The function takes two parameters: RepoUrl (the URL of the remote repository) and DestinationPath (the local directory to clone into).
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, HelpMessage = "Enter the repository URL to clone.")]
            [string]$RepoUrl,

            [Parameter(Mandatory = $false, HelpMessage = "Enter the destination path for the cloned repository. Defaults to current directory.")]
            [string]$DestinationPath = (Get-Location).Path
        )
        git clone "$RepoUrl" "$DestinationPath"
    }

    function Git-Commit {
        <#
        .SYNOPSIS
        Wrapper function for 'git commit -m <message>'.
        .PARAMETER CommitMessage
        The commit message to use for the commit. This parameter is mandatory.
        .DESCRIPTION
        Stages all changes in the current directory and commits them with a specified commit message.
        .EXAMPLE
        .\Git-Commit -CommitMessage "Updated documentation"
        .NOTES
        Requires 'git' command to be available. This is typically used after making changes to files in a Git repository.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, HelpMessage = "Enter the commit message.")]
            [string]$CommitMessage
        )
        git add .
        git commit -m "$CommitMessage"
    }
    function Git-LazyCommit {
        <#
        .SYNOPSIS
        Wrapper function for a lazy commit process.
        .PARAMETER CommitMessage
        The commit message to use for the commit. This parameter is mandatory.
        .DESCRIPTION
        Stages all changes and commits them with a specified commit message, then pushes to the remote repository.
        .EXAMPLE
        .\Git-LazyCommit -CommitMessage "Finalized feature Y"
        This will add all changes, commit them with the message "Finalized feature Y", and then push the changes to the remote repository.
        .NOTES
        Requires 'git' command to be available. This is a convenience function for users who want to quickly commit and push changes in one step.
        This function combines the functionality of Git-Add, Git-CommitMessage, and Git-Push into a single operation.
        #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, HelpMessage = "Enter the commit message.")]
            [string]$CommitMessage
        )
        git add .
        git commit -m "$CommitMessage"
        git push
    }
}
#endregion

#region Profile Initialization

# Set custom window title
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion.ToString())"

# Create custom directory for temporary files if needed
$CustomTempPath = Join-Path $env:USERPROFILE "PowerShell\temp"
if (-not (Test-Path -Path $CustomTempPath)) {
    New-Item -ItemType Directory -Path $CustomTempPath -Force | Out-Null
}

Write-LogMessage -Message "PowerShell profile loaded successfully" -Level Information
#endregion

#region Aliases
Set-Alias -Name rimg -Value Rename-ImageFilesSequentially -Force
Set-Alias -Name mpdf -Value Move-PDFsToFolders -Force
Set-Alias -Name cbz -Value Compress-ToCBZ -Force
Set-Alias -Name cimg -Value Convert-ImageFormat -Force

# External Tool Aliases
Set-Alias -Name winutil -Value Invoke-WinUtil -Force
Set-Alias -Name winutildev -Value Invoke-WinUtilDev -Force
Set-Alias -Name hb -Value Upload-Hastebin -Force

# Git Aliases (only if Git is available)
if ($availableDependencies['git']) {
    Set-Alias -Name gs -Value Git-Status -Force
    Set-Alias -Name ga -Value Git-Add -Force
    Set-Alias -Name gb -Value Git-GetBranch -Force
    Set-Alias -Name gsw -Value Git-SwitchBranch -Force
    Set-Alias -Name gcm -Value Git-CommitMessage -Force
    Set-Alias -Name gco -Value Git-SwitchBranch -Force # Alias for checkout
    Set-Alias -Name gp -Value Git-Push -Force
    Set-Alias -Name gcl -Value Git-Clone -Force
    Set-Alias -Name gcom -Value Git-Commit -Force
    Set-Alias -Name lazyg -Value Git-LazyCommit -Force
}

#endregion
