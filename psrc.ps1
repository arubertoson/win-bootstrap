
# Show verbose output
# $VerbosePreference = "Continue"

# NOTE: Don't know if this is necessary if gh is used.
# Invoke-Expression (Get-Content $PSScriptRoot\plugins\ssh.ps1 -Raw)
# Init-SSH

$ENV:STARSHIP_CONFIG = "$env:APPDATA\starship\starship.toml"
Invoke-Expression (&starship init powershell)