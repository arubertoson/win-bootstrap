<#
.SYNOPSIS
    A script for managing Windows packages using Scoop and WinGet.
.DESCRIPTION
    This PowerShell module provides functions for installing and uninstalling Windows packages 
    using the Scoop and WinGet package managers. It includes features for checking whether a 
    package or a Scoop bucket is already installed before attempting to install it, and for uninstalling 
    installed packages.
.NOTES
    To use the functions in this module, you must have Scoop and WinGet installed on your system.
    Each function includes a docstring with detailed information on its use. You can view these 
    docstrings by running Get-Help followed by the function name.

    Inspiration from Mike Pruett

    Author: Marcus Albertsson
#>

<#
.SYNOPSIS
    Installs a package using Scoop.
.DESCRIPTION
    This function uses Scoop to install a specified package. 
    It first checks whether the package is already installed and if not, proceeds with the installation.
.PARAMETER Package
    The name of the package to install.
.EXAMPLE
    Install-ScoopApp -Package "git"
    This command installs the "git" package using Scoop.
#>
function Install-ScoopApp {
    param (
        [string]$Package
    )
    Write-Verbose -Message "Preparing to install $Package"
    $scoopInfo = scoop info $Package
    if (! ($scoopInfo.Installed )) {
        Write-Verbose -Message "Installing $Package"
        try {
            scoop install $Package
        }
        catch {
            Write-Error "Failed to install $Package. Error: $_"
        }
    }
    else {
        Write-Verbose -Message "Package $Package already installed! Skipping..."
    }
}

<#
.SYNOPSIS
    Adds a bucket to Scoop.
.DESCRIPTION
    This function adds a specified bucket to Scoop. 
    It first checks whether the bucket is already added and if not, proceeds with the addition.
.PARAMETER Bucket
    The name of the bucket to add.
.EXAMPLE
    Enable-Bucket -Bucket "extras"
    This command adds the "extras" bucket to Scoop.
#>
function Enable-Bucket {
    param (
        [string]$Bucket
    )
    $scoopBucket = scoop bucket list
    if (!($scoopBucket.Name -eq "$Bucket")) {
        Write-Verbose -Message "Adding Bucket $Bucket to scoop..."
        try {
            scoop bucket add $Bucket
        }
        catch {
            Write-Error "Failed to install $Bucket. Error: $_"
        }
    }
    else {
        Write-Verbose -Message "Bucket $Bucket already added! Skipping..."
    }
}

<#
.SYNOPSIS
    Installs a package using WinGet.
.DESCRIPTION
    This function uses WinGet to install a specified package. 
    It first checks whether the package is already installed and if not, proceeds with the installation.
.PARAMETER PackageID
    The ID of the package to install.
.EXAMPLE
    Install-WinGetApp -PackageID "Microsoft.VisualStudioCode"
    This command installs the "Microsoft.VisualStudioCode" package using WinGet.
#>
function Install-WinGetApp {
    param (
        [string]$Package
    )
    Write-Verbose -Message "Preparing to install $Package"
    # Added accept options based on this issue - https://github.com/microsoft/winget-cli/issues/1559
    $result = winget list --exact "$Package" --accept-source-agreements
    
    Write-Verbose -Message ($result -join "`n")

    if ($result -like "No installed package found matching input criteria.*") {
        Write-Verbose -Message "Installing $Package"
        try {
            winget install --silent --id "$Package" --accept-source-agreements
        }
        catch {
            Write-Error "Failed to install $Bucket. Error: $_"
        }
    }
    else {
        Write-Verbose -Message "Package $Package already installed! Skipping..."
    }
}

<#
.SYNOPSIS
    Uninstalls a package.
.DESCRIPTION
    This function uninstalls a specified package. 
    It first checks whether the package is installed and if so, proceeds with the uninstallation.
.PARAMETER Package
    The name of the package to uninstall.
.EXAMPLE
    Remove-InstalledApp -Package "Microsoft.BingWeather"
    This command uninstalls the "Microsoft.BingWeather" package.
#>
function Remove-InstalledApp {
    param (
        [string]$Package
    )
    $app = Get-AppxPackage -AllUsers -Name $Package -ErrorAction SilentlyContinue
    if (!$app) {
        Write-Verbose -Message "Package $Package is not installed! Skipping..."
        return
    }

    Write-Verbose -Message "Uninstalling: $Package"
    try {
        $app | Remove-AppxPackage -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to uninstall $Package. Error: $_"
    }
}

<#
.SYNOPSIS
    Performs copy or link file operations for each file in the provided list.

.DESCRIPTION
    For each file object in the input array, the function performs a copy or creates a symbolic link based on the 'type' property. 
    The 'source' is the file path to copy or link from, and the 'destination' is the file path to copy or link to.
    The "{username}" in the 'destination' path gets replaced with the current user's username.

.PARAMETER files
    An array of file objects with 'source', 'destination', and 'type' properties.

.EXAMPLE
    $files = @(
        @{
            "source" = "./config/db.json"
            "destination" = "C:/Users/{username}/AppData/Roaming/Postman/db.json"
            "type" = "link"
        },
        @{
            "source" = "./config/settings.json"
            "destination" = "C:/Users/{username}/AppData/Roaming/VSCode/settings.json"
            "type" = "copy"
        }
    )

    Move-Config-Files $files
#>
function Move-Config-Files($files) {
    foreach ($file in $files) {
        $source = $file.source
        $destination = $file.destination -replace "{username}", $env:USERNAME

        try {
            if ($file.type -eq "copy") {
                Copy-Item $source $destination -Force
            }
            elseif ($file.type -eq "link") {
                New-Item -ItemType SymbolicLink -Path $destination -Target $source -Force
            }
        }
        catch {
            Write-Host "Error handling file: $source"
            Write-Host $_.Exception.Message
        }
    }
}