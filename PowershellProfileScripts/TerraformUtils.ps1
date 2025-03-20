function InstallTerraformVersion {
  param ($downloadVersion)
  Write-Host "Downloading and installing Terraform $downloadVersion" -Fore Green
  $releasesUrl = 'https://api.github.com/repos/hashicorp/terraform/releases'
  $releases = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $releasesUrl -Headers $gheader
  $downloadVersion = $releases.Where({ !$_.prerelease })[0].name.trim('v')
  $terraformFile = "terraform_${downloadVersion}_windows_amd64.zip"
  $terraformURL = "https://releases.hashicorp.com/terraform/${downloadVersion}/${terraformFile}"
  Invoke-WebRequest -UseBasicParsing -Uri $terraformURL -DisableKeepAlive -OutFile "${env:Temp}\${terraformFile}" -ErrorAction SilentlyContinue
  Unblock-File "${env:Temp}\${terraformFile}"
  Write-Host "Created ${env:Temp}\${terraformFile}" -Fore Cyan
  #Expand-Archive -Path "${env:Temp}\${terraformFile}" -DestinationPath ${env:windir} -Force
  #Remove-Item -Path "${env:Temp}\${terraformFile}" -Force
  #$FilePath = "C:\Windows\terraform.exe"
  #if (Test-Path $FilePath -PathType Leaf) {
  #    $CreateTime = (Get-ItemProperty -Path $FilePath).CreationTime
  #    Write-Host "**** Terraform Installed Successfully (Created at`: $CreateTime) ****"
  #} else {
  #    Write-Host "**** ERROR: Terraform is Not Installed....`tCheck why.. ****"
  #}  
}

function cleanupfiles { Write-Host "Running Clean" -Fore Yellow; Remove-Item ".terra*" -Recurse -Force }

function cleanupfols {
  Get-ChildItem *.terra*-cache* -r | remove-item -r -force
}

function runPreCommit { pre-commit run -a }

function terraformp { Write-Host "Running TF Plan" -Fore Yellow; terraform plan }
function terraformpa { Write-Host "Running TF Plan" -Fore Yellow; terraform plan; tf apply --auto-approve }
function terraformi { Write-Host "Running TF Init" -Fore Yellow; terraform init }
function terraformip { Write-Host "Running TF Init/Plan" -Fore Yellow; terraform init; terraform plan }
function terraformiu { Write-Host "Running TF Init" -Fore Yellow; terraform init -upgrade }
function terraforma { Write-Host "Running TF Apply" -Fore Yellow; terraform apply --auto-approve }
function terraformd { Write-Host "Running Destroy!" -Fore Red; terraform destroy }
function terraformda { Write-Host "Running Destroy! (Auto Approve)" -Fore Red; terraform destroy --auto-approve }
function terragrunto { tg output }
function terragruntp { Write-Host "Running TG Plan" -ForegroundColor Yellow; tg plan --terragrunt-forward-tf-stdout --terragrunt-log-level warn }
function terragruntpro { Write-Host "Running TG Plan" -Fore Yellow; tg plan --terragrunt-forward-tf-stdout --terragrunt-log-level warn -refresh-only }
function terragrunti { Write-Host "Running TG Init" -Fore Yellow; tg init --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragruntip { Write-Host "Running TG Init/Plan" -Fore Yellow; tg init --terragrunt-forward-tf-stdout --terragrunt-log-level warn; tg plan --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragruntiu { Write-Host "Running TG Init" -Fore Yellow; tg init -upgrade --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragrunta { Write-Host "Running TG Apply" -Fore Yellow; tg apply --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragruntd { Write-Host "Running Destroy!" -Fore Red; tg destroy --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragruntda { Write-Host "Running Destroy! (Auto Approve)" -Fore Red; tg destroy --auto-approve --terragrunt-forward-tf-stdout --terragrunt-log-level warn}
function terragruntdapa { Write-Host "Running Destroy/Plan/Apply! (Auto Approve)" -Fore Yellow; tg destroy --auto-approve --terragrunt-forward-tf-stdout --terragrunt-log-level warn; tg plan --terragrunt-forward-tf-stdout --terragrunt-log-level warn; tg apply --terragrunt-forward-tf-stdout --terragrunt-log-level warn }
function terragruntpa { Write-Host "Running Plan/Apply" -Fore Yellow; tg plan --terragrunt-forward-tf-stdout --terragrunt-log-level warn; tg apply --terragrunt-forward-tf-stdout --terragrunt-log-level warn }
function cleanupfiles { Write-Host "Running Clean" -Fore Yellow; Remove-Item ".terra*" -Recurse -Force }
function restartrunf { ; cleanupfiles; tfi; tfp }
function restartrunfa { ; cleanupfiles; tfi; tfp; tfa }
function restartrundf { tfda; cleanupfiles; tfi; tfp }
function restartrundfa { tfda; cleanupfiles; tfi; tfp; tfa }
function restartrung { ; cleanupfiles; tgi; tgp }
function restartrunga { ; cleanupfiles; tgi; tgp; tga }
function restartrundg { tgda; cleanupfiles; tgi; tgp }
function restartrundga { tgda; cleanupfiles; tgi; tgp; tga }
function terraformv { Write-Host "Running TF Validate" -Fore Yellow; terraform init; terraform validate }
function terragruntv { Write-Host "Running TF Validate" -Fore Yellow; tg init; tg validate }
function TGAllInit { Write-Host "Running TG All Init" -Fore Yellow; tg run-all init }
function TGAllPlan { Write-Host "Running TG All Plan" -Fore Yellow; tg run-all plan }
function TGAllFmt { Write-Host "Running TG All Format" -Fore Yellow; tg run-all hclfmt }
function TGUpdate { Write-Host "Running TG Update" -Fore Yellow; tg get -update }
function TFUpdate { Write-Host "Running TF Update" -Fore Yellow; terraform get -update }
function terraformformat { Write-Host "Formatting..."; terraform fmt }
function terragruntformat { Write-Host "Formatting..."; tg hclfmt }

function TGForceUnlock {
  param ($id)
  Write-Host "Unlocking $id" -Fore Yellow; tg force-unlock $id -force
}

function TGAllInit { Write-Host "Running TG All Init" -Fore Yellow; tg run-all init }
function TGAllPlan { Write-Host "Running TG All Plan" -Fore Yellow; tg run-all plan }
function TGAllFmt { Write-Host "Running TG All Format" -Fore Yellow; tg run-all hclfmt }

function invoketfversion { param ([string] $i); Invoke-Terraform -TFVersion $i }


New-Alias -Name "allfmt" TGAllFmt -Force
New-Alias -Name "allinit" TGAllInit -Force
New-Alias -Name "allplan" TGAllPlan -Force
New-Alias -Name "cleanall" -Value cleanupfols -Force
New-Alias -Name "pcra" -Value runPreCommit -Force
New-Alias -Name "rerundf" -Value restartrundf -Force
New-Alias -Name "rerundfa" -Value restartrundfa -Force
New-Alias -Name "rerundg" -Value restartrundg -Force
New-Alias -Name "rerundga" -Value restartrundga -Force
New-Alias -Name "rerunf" -Value restartrunf -Force
New-Alias -Name "rerunfa" -Value restartrunfa -Force
New-Alias -Name "rerung" -Value restartrung -Force
New-Alias -Name "rerunga" -Value restartrunga -Force
#New-Alias -Name "tf" terraform -Force
New-Alias -Name "tfa" -Value terraforma -Force
New-Alias -Name "tfd" -Value terraformd -Force
New-Alias -Name "tfda" -Value terraformda -Force
New-Alias -Name "tfenv" -Value invoketfversion -Force
New-Alias -Name "tff" terraformformat -Force
New-Alias -Name "tfi" -Value terraformi -Force
New-Alias -Name "tfip" -Value terraformip -Force
New-Alias -Name "tfiu" -Value terraformiu -Force
New-Alias -Name "tfp" -Value terraformp -Force
New-Alias -Name "tfpa" -Value terraformpa -Force
New-Alias -Name "tfupdate" TFUpdate -Force
New-Alias -Name "tfv" -Value terraformv -Force
New-Alias -Name "tg" terragrunt -Force
New-Alias -Name "tga" -Value terragrunta -Force
New-Alias -Name "tgd" -Value terragruntd -Force
New-Alias -Name "tgda" -Value terragruntda -Force
New-Alias -Name "tgdpa" -Value terragruntdapa -Force
New-Alias -Name "tgf" terragruntformat -Force
New-Alias -Name "tgfu" TGForceUnlock -Force
New-Alias -Name "tgi" -Value terragrunti -Force
New-Alias -Name "tgip" -Value terragruntip -Force
New-Alias -Name "tgiu" -Value terragruntiu -Force
New-Alias -Name "tgo" -Value terragrunto -Force
New-Alias -Name "tgp" -Value terragruntp -Force
New-Alias -Name "tgpa" -Value terragruntpa -Force
New-Alias -Name "tgpro" -Value terragruntpro -Force
New-Alias -Name "tgupdate" TGUpdate -Force
New-Alias -Name "tgv" -Value terragruntv -Force