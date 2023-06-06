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

.EXAMPLE
.\bootstrap.ps1 -PackagesFile "C:\path\to\file" -Workspace "home"

#>

param (
    [Parameter(Mandatory=$true)]
    [string]$PackagesFile,

    [Parameter(Mandatory=$false)]
    [ValidateSet("work", "home", "global")]
    [string]$Workspace = "home",

    [Parameter(Mandatory=$false)]
    [string]$PackageName,

    [Parameter(Mandatory=$false)]
    [string]$PackageManager
)

# Show verbose output
$VerbosePreference = "Continue"

# Util functions
Invoke-Expression (Get-Content $PSScriptRoot\setup.ps1 -Raw)
Invoke-Expression (Get-Content $PSScriptRoot\utils.ps1 -Raw)
Invoke-Custom-Setup

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
