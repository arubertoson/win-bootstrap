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
    Resolves environment variables in a path.

.DESCRIPTION
    The Resolve-EnvPath function takes a path as input, which can include environment variables 
    in the format '$env:VARNAME'. It replaces each occurrence of an environment variable with its 
    value. It handles both '/' and '\' as path separators. It returns the resolved path.

.PARAMETER Path
    The path to resolve. This can include environment variables in the format '$env:VARNAME'.

.EXAMPLE
    PS > $path = Resolve-EnvPath '$env:USERPROFILE\Documents\file.txt'
    PS > echo $path

    This will replace '$env:USERPROFILE' with the value of the 'USERPROFILE' environment variable, 
    and then join the parts back together to form a complete path, regardless of the original path 
    separator used.

#>
function Resolve-EnvPath {
    param (
        [Parameter(Mandatory = $true)]
        [string] $InputPath
    )

    $Path = $ExecutionContext.InvokeCommand.ExpandString($InputPath)

    # Split the path into parts, handling both / and \ as separators
    $parts = $Path -split '[/\\]'

    # Process each part
    for ($i = 0; $i -lt $parts.Count; $i++) {
        # If this part starts with $env:, it's an environment variable
        if ($parts[$i] -match '^\$env:') {
            # Extract the environment variable name
            $varName = $parts[$i] -replace '^\$env:', ''
            
            # Get the value of the environment variable
            $varValue = Get-Content "env:$varName"
            
            # Replace the part with the value of the environment variable
            $parts[$i] = $varValue
        }
    }

    # Join the parts back together using the appropriate separator
    $resolvedPath = Expand-EnvironmentVariablesInString (Join-Path -Path $parts[0] -ChildPath ($parts[1..($parts.Count - 1)] -join '\'))

    if ($resolvedPath.StartsWith(".")) {
        $resolvedPath = Resolve-Path -Path $resolvedPath
    }

    return $resolvedPath
}

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
        $source = Resolve-EnvPath $file.source
        $destination = Resolve-EnvPath $file.destination

        Write-Verbose "Source: $source --> $destination"

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


function Expand-EnvironmentVariablesInString {
    param (
        [string]$InputString
    )

    $regex = [regex]::new('\$env:(\w+)')
    $matches = $regex.Matches($InputString)

    foreach ($match in $matches) {
        $varName = $match.Groups[1].Value
        $varValue = [Environment]::GetEnvironmentVariable($varName)
        $InputString = $InputString.Replace($match.Value, $varValue)
    }

    return $InputString
}
