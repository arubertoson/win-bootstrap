<#
.SYNOPSIS
This is a script for doing things.

.DESCRIPTION
This script does several things, depending on the parameters passed in.

.PARAMETER PackagesFile
The path to the packages file.

.PARAMETER Workspace
The workspace to use. Can be 'work', 'home', or 'global'.

.PARAMETER Help
Shows this help message.

.PARAMETER Setup
Runs the setup functions Invoke-Admin-Setup and Invoke-User-Setup from the setup.ps1 script.

.EXAMPLE
.\bootstrap.ps1 -PackagesFile "C:\path\to\file" -Workspace "home"
#>

param (
    [Parameter(Mandatory=$false)]
    [string]$PackagesFile,

    [Parameter(Mandatory=$false)]
    [string[]]$PackageNames,

    [Parameter(Mandatory=$false)]
    [ValidateSet("work", "home", "global")]
    [string]$Workspace = "home",

    [Parameter(Mandatory=$false)]
    [string]$PackageName,

    [Parameter(Mandatory=$false)]
    [string]$PackageManager,

    [Parameter(Mandatory=$false)]
    [switch]$Setup = $false
)

# Show verbose output
$VerbosePreference = "Continue"

# If the Setup switch was provided, run the setup functions
if ($Setup) {
    # Check if we are running as administrator
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # We are not running as an administrator, so throw an error
        throw "You must run this script as an Administrator. Start PowerShell with the 'Run as Administrator' option."
    }

    # Import the setup functions from the setup.ps1 script
    Invoke-Expression (Get-Content $PSScriptRoot\setup.ps1 -Raw)

    # Call the setup functions
    Invoke-Admin-Setup
    Invoke-User-Setup

    return
} else {
    # If we are not in setup mode, the PackagesFile parameter must be provided
    if ($null -eq $PackagesFile) {
        throw "You must provide a PackagesFile when not using the -Setup switch."
    }
}

# Util functions
Invoke-Expression (Get-Content $PSScriptRoot\utils.ps1 -Raw)

# Setup windows with current scope
$DispatchTable = @{
    Scoop  = "Install-ScoopApp"
    WinGet = "Install-WinGetApp"
    Remove = "Remove-InstalledApp"
}

$Packages = Get-Content -Path $PackagesFile | ConvertFrom-Json 

foreach ($package in $Packages) {
    $manager = $package.manager.name
    $ws = $package.workspace.ToLower()

    # Skip this package if the PackageNames parameter was provided and this package's name is not in the list
    if ($PackageNames -and $package.package -notin $PackageNames) {
        continue
    }

    if ($Workspace -ne $ws -and $ws -ne "global") {
        continue
    }

    if ($PackageName -and $package.package -ne $PackageName) {
        continue
    }
    
    if ($PackageManager -and $manager -ne $PackageManager) {
        continue
    }

    $command = $DispatchTable[$manager]

    switch ($manager) {
        "Scoop" {
            Enable-Bucket -Bucket $package.manager.bucket
            & $command -Package $package.package -Bucket $package.manager.bucket
        }
        "WinGet" {
            & $command -Package $package.package
        }
        "Remove" {
            & $command -Package $package.package
        }
    }

    if ($package.files) {
        Move-Config-Files -files $package.files
    }  
}
