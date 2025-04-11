## Explanation of `profile.ps1` (Advanced PowerShell Profile)

This PowerShell script (`profile.ps1`) serves as an advanced user profile, building upon the base profile (`Microsoft.PowerShell_profile.ps1`) and shared `HelperFunctions.ps1`. It provides a wide range of custom functions and configurations designed for media management, development workflows, and enhanced command-line use.

**Key Sections and Features:**

1. **Configuration (`#region Configuration`)**
    
    - Sets PowerShell preferences like `$ErrorActionPreference = 'Stop'`.
    - Configures PSReadLine options for history.
    - Checks for required PowerShell modules (like PSReadLine).
    - Defines and checks for external command-line dependencies like `ffprobe`, `starship`, `git`, and `magick` using the `Test-ExternalDependency` helper function.
    - Sets up global variables for default image and video file extensions (`$global:DefaultImageCheckExtensions`, `$global:DefaultVideoCheckExtensions`, `$global:DefaultVideoFilterExtensions`).
2. **Helper Functions (`#region Helper Functions`)**
    
    - Loads shared functions (like `Write-LogMessage`, `Test-AdminRole`, `Reload-Profile`) by dot-sourcing `HelperFunctions.ps1`.
3. **Generic Functions (`#region Generic Functions`)**
    
    - `New-NumberedFolders`: A reusable function to create sequences of numbered folders (e.g., "Chapter 001", "season 02") based on a format string.
4. **File Management Functions (`#region File Management Functions`)**
    
    - `Compress-ToCBZ`: Creates Comic Book Zip (.cbz) files from image folders. It automatically attempts to derive Series, Volume, and Chapter information from the folder structure (`Series\Volume ##\Chapter ##` or `Series\Chapter ##`), generates a `ComicInfo.xml` metadata file (allowing overrides for writer, genre, rating, date, etc.), compresses the contents, places the CBZ in the _grandparent_ directory (as per the latest modification), and cleans up the temporary XML. _(Dependency: Implicitly `Compress-Archive`)_
    - `Move-PDFsToFolders`: Organizes PDF files by creating a subfolder named after each PDF and moving the file into it.
    - `Rename-ImageFilesSequentially`: Renames images (.webp, .jpeg, .jpg, .png) in a folder to a sequential format (e.g., `001.jpg`, `002.png`) using intelligent sorting and a temporary directory.
    - `Rename-NumberedFiles`: Renames files with purely numeric names (e.g., `1.txt`, `10.jpg`) to have consistent zero-padding based on the highest number found (e.g., `01.txt`, `10.jpg`).
    - `Set-StandardSeasonFolderNames`: Renames folders matching "season #" (case-insensitive, allows space or underscore) to the standard "season XX" format (two digits).
    - `Rename-SeriesEpisodes`: Renames video files within "season XX" folders (or the current folder) to the standard Plex/Jellyfin format (`series_name_sXXeYY.ext`). It attempts to derive the series name and uses season/episode numbering based on folder structure and file sorting. Allows overriding the series name and default season.
    - `Rename-NewSeriesEpisode`: Renames a _single_ new video file based on the naming convention and highest episode number of existing files (`series_name_sXXeYY.ext`) in the same directory.
    - `Set-RecursivePermissions`: **(Use with caution, requires Admin)** Grants 'Everyone:Modify' permissions recursively to a folder and its contents.
5. **Folder Creation Functions (`#region Folder Creation Functions`)**
    
    - `New-ChapterFolders`: A wrapper around `New-NumberedFolders` specifically for creating folders named "Chapter XXX" (3 digits).
    - `New-SeasonFolders`: A wrapper around `New-NumberedFolders` specifically for creating folders named "season XX" (2 digits).
6. **Image Processing Functions (`#region Image Processing Functions`)**
    
    - `Convert-ImageFormat`: Batch converts images between formats using ImageMagick, with options for quality, optimization, and keeping/deleting originals. _(Dependency: ImageMagick - `magick` command)_
7. **Media Information Functions (`#region Media Information Functions`)**
    
    - `Get-VideoInfo`: Retrieves video metadata (codec, resolution, duration, optional audio/subtitle info) using ffprobe. _(Dependency: FFmpeg - `ffprobe` command)_
8. **Symbolic Link Functions (`#region Symbolic Link Functions`)**
    
    - `New-FavoriteLinks`: Searches a source path for folders ending in a star emoji (⭐) and creates directory junctions (symbolic links) to them in a destination folder. Attempts to name links as "Artist - Work Name" based on folder structure. _(Dependency: `mklink` via `cmd.exe`, often requires Admin/Developer Mode)_
9. **External Tools (`#region External Tools`)**
    
    - `Invoke-WinUtil` / `Invoke-WinUtilDev`: Functions to run Chris Titus Tech's WinUtil scripts.
    - `Upload-Hastebin`: Uploads file content to `bin.christitus.com`.
10. **Git Integration (`#region Git Integration`)**
    
    - Provides wrapper functions (`Git-Status`, `Git-Add`, `Git-Commit`, `Git-Push`, etc.) for common Git commands. This section is only active if the `git` command is detected in the system PATH. _(Dependency: Git)_
11. **Profile Initialization (`#region Profile Initialization`)**
    
    - Sets a custom window title.
    - Ensures a custom temp directory exists.
    - Logs profile loading completion.
12. **Aliases (`#region Aliases`)**
    
    - Sets up numerous aliases for both built-in cmdlets and the custom functions defined in this profile (e.g., `reload`, `rimg`, `mpdf`, `cbz`, `cimg`, `gs`, `ga`, `gp`, etc.).