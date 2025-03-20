# Set up deferred module loading
$FolPath = "C:\Alex\PowerShellProfileScripts"
$scriptFiles = Get-ChildItem -Path $FolPath -Filter *.ps1
foreach ($script in $scriptFiles) {
  . $script.FullName
}
Set-Alias ~ (Get-Variable HOME).Value
$myPat = "tokenhere"
$env:Pat = $myPat
function writeTMPwd {
	Write-Host "TMPWD = not_here" -Fore Green
}
#tplogin
#tsh apps login yl-admin --aws-role sudo_admin
#tsh apps login yl-production --aws-role sudo_prod
#tsh apps login yl-usproduction --aws-role sudo_usprod
#tsh apps login yl-sandbox --aws-role sudo_sandbox
#tsh apps login yl-staging --aws-role sudo_staging
#tsh apps login yl-development --aws-role sudo_dev
#Write-Host "Using Profile: $ENV:AWS_PROFILE" -Fore Yellow
#Write-Host "/////////////////////// Teleport Shortcuts" -Fore Yellow
#(get-alias taw*).DisplayName
#(get-alias tl*).DisplayName
#(get-alias tk*).DisplayName
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