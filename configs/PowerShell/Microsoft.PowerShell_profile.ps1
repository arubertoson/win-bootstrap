$target = (Get-Item -Path $PSCommandPath -Force).Target


. (Resolve-Path "$target/../../../psrc.ps1")