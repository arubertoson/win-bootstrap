<#
.SYNOPSIS
    Script sets ExecutivePolicy for CurrentUser and installs necessary tools.
.DESCRIPTION
    Sets ExecutivePolicy to Unrestricted for CurrentUser Scope and installs/updates WinGet, PowerShell 7, Scoop, git, Aria2, and WSL.
.NOTES
    Author: Marcus Albertsson
#>

<#
.SYNOPSIS
    Sets the ExecutionPolicy for CurrentUser to Unrestricted.
.DESCRIPTION
    Checks if the current ExecutionPolicy for the CurrentUser scope is not "Unrestricted" and if it's not, sets it to "Unrestricted".
#>
function Set-ExecutionPolicyForCurrentUser {
    if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "Unrestricted") {
        Write-Verbose -Message "Setting Execution Policy for Current User..."
        Start-Process -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy", "-Scope", "CurrentUser", "-ExecutionPolicy", "Unrestricted", "-Force" -Verb RunAs -Wait
    }
}

function Find-Installed-Package {
    param(
        [string]$PackageName
    )

    $package = Get-AppxPackage -Name $PackageName

    if ($null -eq $package) {
        return $false
    }
    return $true
}

<#
.SYNOPSIS
    Installs or updates WinGet to the latest version.
.DESCRIPTION
    Downloads and installs or updates the WinGet package from GitHub.
#>
function Install-Or-Update-WinGet {
    Write-Verbose -Message "Installing/Updating WinGet to the latest version..."
    
    # This is required for testing in Windows Sandbox
    $depName = "Microsoft.VCLibs.140.00.UWPDesktop"
    $hasDepedency = Find-Installed-Package -PackageName $depName 
    
    if (!$hasDepedency) {
        $url = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $depPath = "$env:TEMP\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        
        Invoke-WebRequest -Uri $url -OutFile $depPath
        
        Add-AppxPackage -Path $depPath
        Remove-Item $depPath
    }

    # get latest download url
    $URL = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $URL = (Invoke-WebRequest -Uri $URL).Content | ConvertFrom-Json |
            Select-Object -ExpandProperty "assets" |
            Where-Object "browser_download_url" -Match '.msixbundle' |
            Select-Object -ExpandProperty "browser_download_url"

    $filePath = Join-Path -Path $env:TEMP -ChildPath "Setup.msix"

    # download install and cleanup
    Invoke-WebRequest -Uri $URL -OutFile $filePath -UseBasicParsing
    Add-AppxPackage -Path $filePath
    Remove-Item $filePath

    Write-Verbose -Message "Winget setup done..."
}

<#
.SYNOPSIS
    Installs PowerShell 7 if it is not already installed.
.DESCRIPTION
    Checks if PowerShell 7 is installed. If not, downloads and installs PowerShell 7 from the official Microsoft link.
#>
function Install-PowerShell7 {
    $PS7 = winget list --exact -q Microsoft.PowerShell --accept-source-agreements
    if (!$PS7) {
        Write-Verbose -Message "Installing/Updating PowerShell to the latest version..."

        Write-Verbose -Message "Installing PowerShell 7..."
        Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
    }

    Write-Verbose -Message "PowerShell setup done..."
}

<#
.SYNOPSIS
    Installs Scoop if it is not already installed.
.DESCRIPTION
    Checks if Scoop is installed. If not, downloads and installs Scoop from the official Scoop link and then updates Scoop to ensure the latest version is installed.
#>
function Install-Scoop {
    $scoopInstalled = Get-Command "scoop" -ErrorAction SilentlyContinue
    if ($null -eq $scoopInstalled) {
        Write-Verbose -Message "Installing/Updating Scoop to the latest version..."

        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh'))
        
        # Update to ensure that we have the latest scoop
        Install-ScoopApp -Package "git-with-openssh"
        Install-And-Configure-Aria2
        scoop update
    }

    Write-Verbose -Message "Scoop setup done..."
}

<#
.SYNOPSIS
    Installs and configures the Aria2 Download Manager using Scoop.
.DESCRIPTION
    Calls the Install-ScoopApp function to install Aria2 and then configures it. If a scheduled task named "Aria2RPC" doesn't exist, it creates one.
#>
function Install-And-Configure-Aria2 {
    Install-ScoopApp -Package "aria2"
    scoop config aria2-enabled true
    scoop config aria2-warning-enabled false

    # Create a scheduled task for Aria2 if it doesn't already exist
    if (!(Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
        $Action = New-ScheduledTaskAction -Execute $Env:UserProfile\scoop\apps\aria2\current\aria2c.exe -Argument "--enable-rpc --rpc-listen-all" -WorkingDirectory $Env:UserProfile\Downloads
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Principal = New-ScheduledTaskPrincipal -UserID "$Env:ComputerName\$Env:Username" -LogonType S4U
        $Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
    }
}

<#
.SYNOPSIS
    Installs Ubuntu through WSL if it is not already installed.
.DESCRIPTION
    Checks if Ubuntu is installed through WSL. If not, installs Ubuntu using WinGet.
#>
function Install-Ubuntu {
    $ubuntuInstalled = wsl -l -q | Select-String "Ubuntu"
    if (!$ubuntuInstalled) {
        Write-Verbose -Message "Installing Ubuntu..."
        winget install --name Canonical.Ubuntu.2204 --exact --accept-source-agreements
    }
    else {
        Write-Verbose -Message "Ubuntu is already installed."
    }

    Write-Verbose -Message "WSL with Ubuntu done..."
}


function Invoke-Custom-Setup {
    # Set-ExecutionPolicyForCurrentUser
    Install-Or-Update-WinGet
    Install-PowerShell7
    Install-Scoop
    Install-Ubuntu
}
