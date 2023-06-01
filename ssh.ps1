function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal]`
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-NativeSshAgent() {
    # Native Windows ssh-agent service
    $service = Get-Service "ssh-agent" -ErrorAction Ignore
    # Native ssh.exe binary version must include "OpenSSH"
    $nativeSsh = Get-Command "ssh.exe" -ErrorAction Ignore `
        | ForEach-Object FileVersionInfo `
        | Where-Object ProductVersion -match OpenSSH

    # Output error if native ssh.exe exists but without ssh-agent.service
    if ($nativeSsh -and !$service) {
        Write-Host "You have Win32-OpenSSH binaries installed but missed the ssh-agent service. Please fix it." -f DarkRed
    }

    $result = @{}
    $result.service = $service
    $result.nativeSsh = $nativeSsh

    return $result
}

function Start-NativeSshAgent([switch]$Verbose) {
    $result = Get-NativeSshAgent
    $service = $result.service
    $nativeSsh = $result.nativeSsh

    if (!$service) {
        if ($nativeSsh) {
            # ssh-agent service doesn't exist, but native ssh.exe found,
            # exit with true so Start-SshAgent doesn't try to do any other work.
            return $true
        } else {
            return $false
        }
    }

    # Enable the servivce if it's disabled and we're an admin
    if ($service.StartType -eq "Disabled") {
        if (Test-Administrator) {
            Set-Service "ssh-agent" -StartupType 'Manual'
        } else {
            Write-Host "The ssh-agent service is disabled. Please enable the service and try again." -f DarkRed
            Write-Host "You can enable it by running 'Set-Service ssh-agent -StartupType Manual'" -f Cyan
            Write-Host "If you don't want to use the native agent set 'ignoreNativeAgent' true in your theme config" -f Cyan

            # Exit with true so Start-SshAgent doesn't try to do any other work.
            return $true
        }
    }

    # Start the service
    if ($service.Status -ne "Running") {
        if ($Verbose) {
            Write-Host "Starting ssh-agent service."
        }
        Start-Service "ssh-agent"
    }

    Add-SshKey -Verbose:$Verbose

    return $true
}


function ssh_init {
    if (!(Test-Path "$env:USERPROFILE/.ssh")) {
        New-Item "$env:USERPROFILE/.ssh" -ItemType Directory | Out-Null
    }

    $Verbose = $false
    if ($ssh.verbose -eq "true") {
        $Verbose = $true
    }

    if (Test-IsSshBinaryMissing -Verbose:$Verbose) { 
        return 
    }

    Start-NativeSshAgent -Verbose:$Verbose
}