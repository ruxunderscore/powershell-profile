# 🎨 PowerShell Profile (Pretty PowerShell)

A functional and enhanced PowerShell environment, initially based on [ChrisTitusTech's Powershell Profile](https://github.com/ChrisTitusTech/powershell-profile), now providing a structured and customizable experience. This repository contains two key profile components: a self-updating base profile and an advanced user profile with extra features.

## ✨ Features

- **Base Profile (`Microsoft.Powershell_profile.ps1`):**
    - Auto-updates from this repository.
    - Integrations: Starship, Zoxide (auto-install attempt), Terminal-Icons, Chocolatey.
    - PSReadLine enhancements (custom colors, keybindings, history).
    - Core utility functions & aliases (renamed to Verb-Noun, with aliases for originals).
    - Comment-Based Help for functions.
    - Admin prompt indicator.
- **Advanced Profile (`profile.ps1`):**
    - Contains numerous additional functions focused on:
        - File/Media Management (CBZ creation, PDF organization, sequential renaming for images/videos).
        - Image Processing (via ImageMagick dependency).
        - Video Info (via ffprobe dependency).
        - Git integration helpers.
        - Folder creation utilities.
        - And more...
    - Extensive Comment-Based Help.
    - Robust dependency checking for its advanced features.
    - _Optionally_ installed during setup to `$PROFILE.CurrentUserAllHosts`.

## ⚡ One Line Install (Elevated PowerShell Recommended)

Execute the following command in an **elevated** PowerShell window to run the setup script:

```powershell
irm "https://undersc.red/profile" | iex
```

**What the installer does:**

1.  Checks for Admin rights and Internet connectivity.
2.  Installs dependencies: Chocolatey, Winget packages (Starship, Zoxide, Eza), PowerShell Modules (Terminal-Icons), and Nerd Fonts (Cascadia Code).
3.  Installs the **Shared Helper Functions** (`HelperFunctions.ps1`) required by the profiles.
4.  Installs the **Base Profile** (`Microsoft.Powershell_profile.ps1`) (which uses the helpers) to `$PROFILE`, backing up any existing file.
5.  **Prompts you** whether to download and install the **Advanced Profile** (`profile.ps1`) (which also uses the helpers) to `$PROFILE.CurrentUserAllHosts`, backing up any existing file.

_Restart your PowerShell session after the setup completes!_

## 🔧 Customizing Your Setup

The base profile (`Microsoft.Powershell_profile.ps1`) is designed to auto-update from this repository.

⚠️ **DO NOT directly edit the `Microsoft.Powershell_profile.ps1` file located at `$PROFILE`!** Your changes _will_ be overwritten during updates.

**The correct way to add your own customizations:**

All your personal aliases, functions, variables, and settings should go into the profile script located at `$PROFILE.CurrentUserAllHosts`.

This file is loaded _after_ the base profile, allowing you to override settings or add your functionality. After restarting PowerShell post-setup, you can easily open this file using the alias `ep`. (This runs the `Open-UserProfileScript` function).

**Based on your choice during setup:**

- **If you chose YES** to download the advanced profile:
    - The `ep` command will open `profile.ps1` (which was downloaded to `$PROFILE.CurrentUserAllHosts`).
    - You can modify this file, remove functions you don't need, or add your own alongside the existing advanced functions.
- **If you chose NO** to download the advanced profile:
    - The `ep` command will open `$PROFILE.CurrentUserAllHosts`. This file might be empty or non-existent initially (the command will create it if needed when opened by editors like VS Code or Notepad).
    - Add all your custom aliases, functions, `$env:` settings, module imports, etc., into this file.

This ensures your personal configurations are preserved across updates to the base profile.

---

Now, enjoy your enhanced and stylish PowerShell experience! 🚀