# Set up deferred module loading
$FolPath = "C:\Alex\PowerShellProfileScripts"
$scriptFiles = Get-ChildItem -Path $FolPath -Filter *.ps1
foreach ($script in $scriptFiles) {
  . $script.FullName
}
Set-Alias ~ (Get-Variable HOME).Value
$myPat = "2uHVUzz9TtXtZo99Hm6A9JFgxjCQ4LfcHEEoZDxZYeIRCLjS0cbWJQQJ99BCACAAAAAO2tJ0AAASAZDO3eoS"
$env:Pat = $myPat
function writeTMPwd {
	Write-Host "TMPWD = xRrAY&XeMPJPL6NUBgf2i;Biy5knuEnp" -Fore Green
}

kubectl completion powershell | Out-String | Invoke-Expression
Set-Alias -Name tmpwd -Value writeTMPwd
function Show-DailyGreeting {
    $hour = (Get-Date).Hour
    $name = "Alex"
    $greeting = if ($hour -lt 12) {
        "Good Morning"
    } elseif ($hour -lt 18) {
        "Good Afternoon"
    } else {
        "Good Evening"
    }
    Write-Host "$greeting, $name!" -ForegroundColor Cyan
}

Show-DailyGreeting
Show-TeleportAliasPatterns