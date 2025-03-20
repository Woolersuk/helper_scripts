function winget {
    param (
        [Parameter(Position=0)]
        [string]$Command,
        
        [Parameter(ValueFromRemainingArguments=$true)]
        $RemainingArgs
    )
    
    switch ($Command) {
        "install" { Install-WinGetPackage -Name $RemainingArgs[0] }
        "search" { Find-WinGetPackage -Name $RemainingArgs[0] }
        "list" { Get-WinGetPackage }
        "upgrade" { Update-WinGetPackage }
        "uninstall" { Uninstall-WinGetPackage -Name $RemainingArgs[0] }
        "--version" { Get-WinGetVersion }
        "export" { Export-WinGetPackage }
        default { Write-Host "Unknown winget command: $Command" }
    }
}