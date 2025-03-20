function LoadModule ($m) {
  if (Get-Module | Where-Object { $_.Name -eq $m }) {
  } else {
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $m }) {
      Import-Module $m
    } else {
      if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
        Install-Module -Name $m -Force -Scope CurrentUser
        Import-Module $m
      } else {
        Write-Host "Module $m not imported, not available and not in online gallery, exiting."
        EXIT 1
      }
    }
  }
}
  
function Start-EC2RemoteDesktopViaSessionManager {
  [CmdletBinding(SupportsShouldProcess)] param(
    [Parameter(Position = 0)] [string]$ProfileName,
    [Parameter(Mandatory = $true, Position = 1)] [string]$InstanceId,
    [Parameter(Position = 2)] [string]$Region,
    [Parameter(Position = 3)] [string]$PrivateKeyFile
  )
  if ($ProfileName) {
    $password = Get-EC2PasswordData -ProfileName $ProfileName -InstanceId $InstanceId -Region $Region -PemFile $PrivateKeyFile
  } else {
    $password = Get-EC2PasswordData -InstanceId $InstanceId -Region $Region -PemFile $PrivateKeyFile	  
  }
  $password = ConvertTo-SecureString -String $password -AsPlainText -Force
  $Credential = New-Object PSCredential "Administrator", $password
  
  $LocalPort = ( Get-Random -Minimum 30001 -Maximum 39999 ).ToString('00000') #33389
  $PortForwardParams = @{ portNumber = (, "3389"); localPortNumber = (, $LocalPort.ToString()) }
  if ($Region) {
    $session = Start-SSMSession -ProfileName $ProfileName -Target $InstanceId -DocumentName AWS-StartPortForwardingSession -Parameters $PortForwardParams -Region $Region
  } else {
    $session = Start-SSMSession -ProfileName $ProfileName -Target $InstanceId -DocumentName AWS-StartPortForwardingSession -Parameters $PortForwardParams
  }
  
  # We now need to emulate awscli - it invokes session-manager-plugin with the new session information.
  # AWS Tools for PowerShell don't do this. Also some of the objects seem to look a bit different, and the
  # plugin is pernickety, so we have to jump through some hoops to get all the objects matching up as close
  # as we can.
  
  $SessionData = @{
    SessionId        = $session.SessionID
    StreamUrl        = $session.StreamUrl
    TokenValue       = $session.TokenValue
    ResponseMetadata = @{
      RequestId      = $session.ResponseMetadata.RequestId
      HTTPStatusCode = $session.HttpStatusCode
      RetryAttempts  = 0
      HTTPHeaders    = @{
        server             = "server"
        "content-type"     = "application/x-amz-json-1.1"
        "content-length"   = $session.ContentLength
        connection         = "keep-alive"
        "x-amzn-requestid" = $session.ResponseMetadata.RequestId
      }
    }
  }
  
  $RequestData = @{
    Target       = $InstanceId
    DocumentName = "AWS-StartPortForwardingSession"
    Parameters   = $PortForwardParams
  }
  
  $Arguments = (
      (ConvertTo-Json $SessionData -Compress),
    $Region,
    "StartSession",
    "",
      (ConvertTo-Json $RequestData -Compress),
    "https://ssm.$($Region).amazonaws.com"
  )
  
  # Now we have to do some PowerShell hacking. Start-Process takes an array of arguments, which is great,
  # but it doesn't actually do what we expect it to - see https://github.com/PowerShell/PowerShell/issues/5576.
  # So instead we have to turn it into an escaped string ourselves...
  $EscapedArguments = $Arguments | ForEach-Object { $escaped = $_ -replace "`"", "\`""; "`"$($escaped)`"" }
  $ArgumentString = $EscapedArguments -join " "
  
  # Start the Session Manager plugin:
  if ($PSCmdlet.ShouldProcess($session.SessionId, 'Start Session Manager plugin')) {
    try {
      $Process = Start-Process -FilePath "session-manager-plugin.exe" -ArgumentList $ArgumentString -NoNewWindow -PassThru
    } catch {
      Write-Error "Unable to start the process session-manager-plugin.exe. Have you installed the Session Manager Plugin as described in https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-windows ?"
      exit
    }
    # Wait a moment for it to connect to the session and open up the local ports
    Start-Sleep -Seconds 2
  
    # The port should be open now - let's connect
    if ($PSCmdlet.ShouldProcess($InstanceId, 'Start remote desktop session')) {
      Start-RemoteDesktop -HostName "127.0.0.1" -Credential $Credential -Port $LocalPort
    }
  
    # Once the desktop session has finished, kill the session manager plugin
    $Process.Kill()
  }
  
}
  
function Start-RemoteDesktop {
  [CmdletBinding(SupportsShouldProcess)] param(
    [Parameter(Mandatory = $true, Position = 0)] [String] $HostName,
    [Parameter(Mandatory = $true, Position = 1)] [PSCredential] $Credential,
    [Parameter()] [Int32] [string]$Port
  )
  $nwcredential = $Credential.GetNetworkCredential()
  
  if ($PSCmdlet.ShouldProcess($HostName, 'Adding credentials to store')) {
    Start-Process -FilePath "$($env:SystemRoot)\system32\cmdkey.exe" -ArgumentList ("/generic:TERMSRV/$HostName", "/user:$($nwcredential.UserName)", "/pass:$($nwcredential.Password)") -WindowStyle Hidden -Wait
  }
  
  if ($PSCmdlet.ShouldProcess($HostName, 'Connecting mstsc')) {
    if ($PSBoundParameters.ContainsKey('Port')) {
      $target = "$($HostName):$($Port)"
    } else {
      $target = $HostName
    }
    $MonitorCount = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | Where-Object { $_.Active }).Length
    if ($MonitorCount -eq 1) {
      $NewWidth = "1728"
      $NewHeight = "973"
    } Else {
      $NewWidth = "2304"
      $NewHeight = "1296"		
      #Add-Type -AssemblyName System.Windows.Forms
      #$All = [System.Windows.Forms.Screen]::AllScreens
      #Foreach ($S in $All) {
      #  $Width = ($S.Bounds.Width | Measure-Object -Maximum).Maximum
      #  $Height = ($S.Bounds.Height | Measure-Object -Maximum).Maximum
      #  $NewWidth = [int][Math]::Ceiling($width / 100 * 90)
      #  $NewHeight = [int][Math]::Ceiling($height / 100 * 90)
      #  }
    }
    Start-Process -FilePath "$($env:SystemRoot)\system32\mstsc.exe" -ArgumentList ("/admin /w:$NewWidth /h:$NewHeight /v", $target) -NoNewWindow -Wait
  }
}
  
Function Format-Bytes {
  Param
  (
    [Parameter(
      ValueFromPipeline = $true
    )]
    [ValidateNotNullOrEmpty()]
    [float]$number
  )
  Begin {
    $sizes = 'KB', 'MB', 'GB', 'TB', 'PB'
  }
  Process {
    # New for loop
    for ($x = 0; $x -lt $sizes.count; $x++) {
      if ($number -lt [int64]"1$($sizes[$x])") {
        if ($x -eq 0) {
          return "$number B"
        } else {
          $num = $number / [int64]"1$($sizes[$x-1])"
          $num = "{0:N2}" -f $num
          return "$num $($sizes[$x-1])"
        }
      }
    }
  }
  End {}
}
  
function GetReg {
  $tshConfig = tsh apps config
  $appName = ($tshConfig | Select-String -Pattern "^Name:\s+(.+)$").Matches.Groups[1].Value
  $awsRoleArn = ($tshConfig | Select-String -Pattern "^AWS ARN:\s+(.+)$").Matches.Groups[1].Value

  $Region = "eu-west-1"
  if ($appName -match "yl-usproduction|yl-usstaging") {
    $Region = "us-east-2"
  }

  [PSCustomObject]@{
    Region     = $Region
    AppName    = $appName
    AwsRoleArn = $awsRoleArn
  }
}
  
function GetPemFile {
  $regInfo = GetReg
  $Prof = $($regInfo.AppName)
  $PathtoOldPEMFile = "C:\Keys"
  $PathtoNewPEMFile = "C:\Keys\New"
  switch -wildcard ($Prof) {
  
    "*admin*" { $pemFile = Join-Path $PathtoOldPEMFile "yl-admin-eu-west-1-2023.pem" } 
    "*dev*" { $pemFile = Join-Path $PathtoNewPEMFile "yl-dev-eu-west-1-2023.pem" } 
    "*prod*" { $pemFile = Join-Path $PathtoNewPEMFile "yl-prod-eu-west-1-2023.pem" } 
    "*sandbox*" { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-Sandbox-eu-west-1.pem" }
    "*staging*" { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-stag-eu-west-1.pem" }
    "*usadmin*" { $pemFile = Join-Path $PathtoNewPEMFile "yl-usadmin-us-east-2-2023.pem" }     
    "*usprod*" { $pemFile = Join-Path $PathtoNewPEMFile "yl-usprod-us-east-2-2023.pem" } 
    "*usstaging*" { $pemFile = Join-Path $PathtoNewPEMFile "Youlend-USStag-us-east-2.pem" } 
    #"*admin*"     { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-Admin-eu-west-1-hq.pem" } 
    #"*dev*"       { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-Dev-eu-west-1.pem"      } 
    #"*dev*"       { $pemFile = Join-Path $PathtoOldPEMFile "YouLend-Dev-eu-west-1.pem"       } 
    #"*prod*" { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-Prod-eu-west-1.pem" } 
    #"*sandbox*"   { $pemFile = Join-Path $PathtoOldPEMFile "yl-sandbox-eu-west-1-2023.pem"   } 
    #"*staging*"   { $pemFile = Join-Path $PathtoOldPEMFile "yl-staging-eu-west-1-2023.pem"   } 
    #"*usadmin*" { $pemFile = Join-Path $PathtoNewPEMFile "YouLend-Admin-us-east-2-hq.pem" } 
    #"*usprod*" { $pemFile = Join-Path $PathtoOldPEMFile "Youlend-USProd-us-east-2.pem" } 
    #"*usstaging*" { $pemFile = Join-Path $PathtoOldPEMFile "yl-usstaging-us-east-2-2023.pem" } 
  }
  $pemFile 
}
  
function StartRDP {
  param($Inst)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $pemFile = GetPemFile $Prof
  Write-Host "Connecting to $Inst (Profile: $Prof Region: $Reg PemFile: $pemFile)" -Fore Green
  if ($Prof -like "*us*") {
    Write-Warning "Connecting to US Server, this may fail a few times before it successfully connects - (Networking issues)"
  }
  Start-EC2RemoteDesktopViaSessionManager -ProfileName $Prof -InstanceId $Inst -Region $Reg -PrivateKeyFile $pemFile
}
  
function GetPasswordData {
  param($QueryString)
  if ($QueryString -eq "taskmaster") {
    $QueryString = "TaskMaster"
  }
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $pemFile = GetPemFile $Prof
  Write-Host "Checking for $QueryString ($Prof - $Reg - $pemFile)"
  $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running', 'stopped' }).Instances
  if ([string]::IsNullOrWhiteSpace($ec2List)) {
    $textInfo = (Get-Culture).TextInfo
    $QueryString = $textInfo.ToTitleCase($QueryString)
    $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running', 'stopped' }).Instances
  }
  ForEach ($i in $ec2List) {
    $Name = ($i.Tags | Where-Object -Property Key -EQ Name).value
    $Pass = Get-EC2PasswordData	-ProfileName $Prof -InstanceId $i.InstanceId -Region $Reg -PemFile $pemFile
    Write-Host "($i.InstanceId - $Name) - Admin Password is:`t" -NoNewline
    Write-Host $Pass -Fore Yellow
  }
}
  
function StartRDBuild {
  $Prof = "assume-admin"
  $Inst = "i-0997f15b1ac9eeac2"
  $Reg = GetReg $Prof
  $pemFile = "C:\Keys\YouLend-Admin-eu-west-1-hq.pem" #GetPemFile $Prof
  $Pass = Get-EC2PasswordData -ProfileName $Prof -InstanceId $Inst -Region $Reg -PemFile $pemFile
  Write-Host "Admin`: `t $Pass"
  Start-EC2RemoteDesktopViaSessionManager	-ProfileName $Prof -InstanceId $Inst -Region $Reg -PrivateKeyFile $pemFile
}
  
function StartRDBuild2 {
  $isVpnConnected = ipcfg | findstr "10.102.0.2"
  if ($isVpnConnected) {
    Write-Host "VPN Connected, USE RDS"
  } else {
    $Prof = "assume-admin"
    $Inst = "i-0f44699dd96266e8c"
    $Reg = GetReg $Prof
    $pemFile = GetPemFile $Prof
    $Pass = Get-EC2PasswordData	-ProfileName $Prof -InstanceId $Inst -Region $Reg -PemFile $pemFile
    Write-Host "Admin`: `t $Pass"
    Start-EC2RemoteDesktopViaSessionManager	-ProfileName $Prof -InstanceId $Inst -Region $Reg -PrivateKeyFile $pemFile
  }
}
  
function StartSSM {
  param($Inst)
  $regInfo = GetReg
  $Region = $($regInfo.Region)
  tsh aws ssm start-session --target $Inst --region $Region
}
  
function Set-AwsProfile {
  param($Prof)
  $creds = Get-Content ~/.aws/credentials | Select-String -Pattern "(?<=\[).*(?=\])"
  if ($Prof.Length -eq 1) {
    $Prof = $creds[$Prof] -Replace "(\[|\])", ""
  }
  if ($Prof) {
    $ENV:AWS_PROFILE = "$Prof"
    $ENV:AWS_DEFAULT_PROFILE = "$Prof"
  } else {
    $creds
  }
  #tsh apps logout "$Prof" | Out-Null
  #tsh apps login $Prof
}
  
function Get-AwsProfile {
  # $Prof = $ENV:AWS_PROFILE
  # Write-Host "Using: $Prof" -Fore Yellow
  $tshConfig = tsh apps config
  $appName = ($tshConfig | Select-String -Pattern "^Name:\s+(.+)$").Matches.Groups[1].Value
  $awsRoleArn = ($tshConfig | Select-String -Pattern "^AWS ARN:\s+(.+)$").Matches.Groups[1].Value
  Write-Host "Using: $appName" -Fore Yellow
  Write-Host "Role: $awsRoleArn" -Fore Yellow
}
  
function CheckInstStatus {
  param($QueryString)
  
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }).Instances
  foreach ($i in $ec2List) {
    $Name = ($i.Tags | Where-Object -Property Key -EQ Name).value
    $InstanceID = $i.InstanceId
  }
  $StatVal = (Get-EC2InstanceStatus -ProfileName $Prof -Region $Reg -InstanceId $InstanceID).SystemStatus.Status.Value #ok - or initializing
  $RunVal = (Get-EC2InstanceStatus -ProfileName $Prof -Region $Reg -InstanceId $InstanceID).InstanceState.Name.Value	#running
  do {
    Write-Host "Checking $Name Please Wait..." -Fore Yellow
    Start-Sleep -S 20
  } until ($STatVal -eq "ok" -and $RunVal -eq "running")
  Write-Host "$Name - available..." -Fore Green
}
  
function GetInstances {
  param (
    [string]$Value,
    [string]$Tag = "Name"
  )

  $regInfo = GetReg
  $Region = $($regInfo.Region)
  $KeyFile = GetPemFile
  # Fetch EC2 instance details
  $instances = tsh aws ec2 describe-instances --region $Region --query 'Reservations[*].Instances[*].[InstanceId,Placement.AvailabilityZone,InstanceType,Platform,LaunchTime,PrivateIpAddress,PublicIpAddress,State.Name,Tags[?Key==`Name`]| [0].Value]' --output text |
  ForEach-Object {
    $fields = $_ -split "`t"  # Split fields by tab delimiter
    $platform = if ($fields[3] -eq "windows") { "Windows" } else { "Linux/UNIX" }

    # Create object
    [PSCustomObject]@{
      InstanceId       = $fields[0]
      AvailabilityZone = $fields[1]
      InstanceType     = $fields[2]
      Platform         = $platform
      LaunchTime       = $fields[4]
      PrivateIpAddress = $fields[5]
      PublicIpAddress  = $fields[6]
      State            = $fields[7]
      Name             = $fields[8]
    }
  }

  # Filter results if a search value is provided
  if ($Value) {
    $instances = $instances | Where-Object { $_.Name -match $Value }
  }

  # Retrieve Windows admin password if applicable
  $instances | ForEach-Object {
    if ($_.Platform -eq "Windows" -and $_.State -eq "running") {
      $passwordData = tsh aws ec2 get-password-data --region $Region --instance-id $_.InstanceId --priv-launch-key $KeyFile --query 'PasswordData' --output text
      if ($passwordData) {
        $_ | Add-Member -MemberType NoteProperty -Name "AdminPassword" -Value $passwordData
      } else {
        $_ | Add-Member -MemberType NoteProperty -Name "AdminPassword" -Value "N/A"
      }
    }
  }

  # Display results in a sorted table
  if ($instances) {
    $instances | Sort-Object Name, LaunchTime | Format-Table -AutoSize -Property InstanceId, Name, Platform, State, PrivateIpAddress, PublicIpAddress, LaunchTime, AdminPassword
  } else {
    Write-Host "No instances found matching '$Value'." -ForegroundColor Red
  }
}

function GetTaskMasterIP {
  $regInfo = GetReg
  $Region = $($regInfo.Region)
  $InstanceName = "TaskMaster"

  # Ensure AWS credentials are set
  if (-not $env:AWS_ACCESS_KEY_ID) {
      Write-Host "Error: No AWS credentials found. Please assume a role first." -ForegroundColor Red
      return
  }

  # Fetch instance information
  $instances = Get-EC2Instance -Region $Region -Filter @{Name = "tag:Name"; Values = "TaskMaster" }
  
  if ($instances.Instances) {
      $PrivateIP = $instances.Instances.PrivateIpAddress
      Write-Host "TaskMaster IPAddress: $PrivateIP" -ForegroundColor Yellow
      # return $PrivateIP
  } else {
      Write-Host "No instance found with name '$InstanceName'" -ForegroundColor Red
      return $null
  }
}

  
function GetInstancesForProfile {
  param (
    [string[]]$QueryString
  )
  
  $Reg = GetReg $Prof
  $pemFile = GetPemFile $Prof
  Write-Host "*********" -Fore Green
  Write-Host "Prof: $($Prof.ToUpper())" -Fore Cyan
  Write-Host "Region: $Reg"
    
  if (![string]::IsNullOrWhiteSpace($QueryString)) {
    Write-Host "Finding: $QueryString ...Please Wait (Searching through all instances for a match)"
  } else {
    Write-Host "Finding: *Everything* - may take a while. ...Please Wait"
  }
    
  Write-Host "*********`n" -Fore Green
  
  if ([string]::IsNullOrWhiteSpace($QueryString)) { $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{'name' = 'instance-state-name'; 'values' = 'running', 'stopped' }).Instances } Else {
    $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running', 'stopped' }).Instances
    if ([string]::IsNullOrWhiteSpace($ec2List)) {
      $textInfo = (Get-Culture).TextInfo
      $QueryString = $textInfo.ToTitleCase($QueryString)
      $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running', 'stopped' }).Instances
    }
  }
  
  $instanceCount = $ec2List.Count
  #Write-Host "There are $instanceCount matching instances... (Fetching them)`n" -Fore Yellow
  
  $esc = [char]27
  $greenBright = 92
  $redBright = 91
  
  if ($ec2List) {
    $Data = @()
  
    foreach ($i in $ec2List) {
      $Name = ($i.Tags | Where-Object -Property Key -EQ Name).value
      #$Role         = $i.IamInstanceProfile.Arn -Split "/"
      $InstanceID = $i.InstanceId
      $PrivateIP = $i.PrivateIpAddress
      $Zone = $i.Placement.AvailabilityZone
      $InstanceType = $i.InstanceType
      $KeyPair = $i.KeyName
      #$LaunchTime   = $i.LaunchTime
      #$Vols         = Get-EC2Volume -ProfileName $Prof -Region $Reg -Filter @{ Name="attachment.instance-id"; Values="$InstanceID" }
      #  foreach ($vol in $Vols) {
      #      $size = $vol.Size
      #      $type = $vol.VolumeType
      #  }
      $Platform = $i.PlatformDetails
      $PublicIP = $i.PublicIpAddress
      $State = $i.State.Name.Value
      #if ($State -eq "terminated") {
      #    $Name = "-"
      #    $InstanceID = "-"
      #}
      #$Hibernation = $i.HibernationOptions.Configured
      $LaunchTime = $i.LaunchTime
      $dateTime = [DateTime]::ParseExact($LaunchTime, "MM/dd/yyyy HH:mm:ss", $null)
      $Launched = $dateTime.ToString("dd/MM/yy hh:mm")
      $Launched = $Launched.Replace(", ", "/")
      #$LocalHostName = ($i.Tags | Where-Object -Property Key -eq LocalHostName).value
      if ($Platform -eq "Windows" -and $State -eq "running") {
        $Pass = Get-EC2PasswordData	-ProfileName $Prof -InstanceId $InstanceID -Region $Reg -PemFile $pemFile -EA 0
        if ([string]::IsNullOrWhiteSpace($InstanceID)) { $Pass = "" } else { $InstanceID = "RDP $InstanceID" }
      }
      if ($Platform -eq "Linux/UNIX" -and $State -eq "running") {
        if ([string]::IsNullOrWhiteSpace($InstanceID)) { $Pass = "" } else { $Pass = ""; $InstanceID = "SSM $InstanceID" }
      }
      if ($State -eq "stopped") {
        $State = "$esc[${redBright}m$($State)$esc[0m"
        $Name = "$esc[${redBright}m$($Name)$esc[0m"
        $Pass = "-"
      } 
      if ($State -eq "running") {
        $State = "$esc[${greenBright}m$($State)$esc[0m"
        $Name = "$esc[${greenBright}m$($Name)$esc[0m"
      }
      $Record = [pscustomobject] @{
        Profile          = $Prof
        Name             = $Name
        #Role              = $Role[1]
        InstanceID       = $InstanceID
        PrivateIP        = $PrivateIP
        Zone             = $Zone
        InstanceType     = $InstanceType
        #VolType           = "$type $size"
        Platform         = $Platform
        #LocalHostName    = $LocalHostName
        PublicIP         = $PublicIP
        State            = $State
        #Hibernation      = $Hibernation
        LaunchTime       = $Launched
        KeyPair          = $KeyPair
        "Admin Password" = $Pass
      }	
      $Data += $Record
    }
    $Data | Sort-Object Name | Format-Table * -AutoSize
  } else {
    Write-Host "($Prof)`tNo Instances found, have they been terminated?" -Fore Yellow
  }
}

function DownloadS3File {
  param($Bucket, $File)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  Copy-S3Object -ProfileName $Prof -Region $Reg -BucketName $Bucket -Key $File -LocalFile $File
}

function DownloadS3Index {
  param()
  $Prof = "assume-admin"
  $Reg = GetReg $Prof
  Copy-S3Object -ProfileName $Prof -Region $Reg -BucketName headquarter-youlend-helm-repo -Key index.yaml -LocalFile index.yaml -Force
}


function Get-S3Files {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString -like "*/*") {
    $TopLevel = $QueryString.Split("/")[0]
    $Fol = $QueryString.Split("/")[1]
    Write-Host "Bucket = $TopLevel - Fol = $Fol"
    $s3Files = Get-S3Object -BucketName $TopLevel -ProfileName $Prof -Region $Reg -KeyPrefix $Fol | ForEach-Object {
      $properties = [ordered]@{
        FileName = $_.Key
        Size     = Format-Bytes $_.Size
        Date     = $_.LastModified
      }
      New-Object -TypeName PSObject -Property $properties
    }
  } else {
    $s3Files = Get-S3Object -BucketName $QueryString -ProfileName $Prof -Region $Reg | ForEach-Object {
      $properties = [ordered]@{
        FileName = $_.Key
        Size     = Format-Bytes $_.Size
        Date     = $_.LastModified
      }
      New-Object -TypeName PSObject -Property $properties
    }
  }
  $s3Files | Format-Table -AutoSize
}

function GetBucketList {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString.Length -eq 0) {
    Get-S3Bucket -ProfileName $Prof -Region $Reg | Select-Object BucketName, CreationDate
  } else {
    Get-S3Bucket -ProfileName $Prof -Region $Reg | Where-Object { $_.BucketName -like "*$QueryString*" } | Select-Object BucketName, CreationDate
  }
  
}

function FindInstance {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  foreach ($P in $Prof) {
    Write-Host "*** Searching $P ($Reg) for $QueryString ***" -Fore Cyan
    $Inst = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $QueryString).Instances 
    #$id = $inst.InstanceId
    if ($inst) {
      $Name = ($Inst.Tags | Where-Object -Property Key -EQ Name).value
      Write-Host "$name `t found in $P $Reg" -Fore Yellow
    } else {
      Write-Host "Instance not found, it might have been terminated?"
    }
  }
}

function RebootInstance {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString -like "i-*") {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $QueryString).Instances 
  } else {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{Name = "instance-state-name"; Values = "running" }).Instances
  }
  Foreach ($inst in $insts) {
    $Id = $inst.InstanceId
    $Name = ($Inst.Tags | Where-Object -Property Key -EQ Name).value
    Write-Host "** Found: $Name ($Id) ***"
    Write-Host "Stopping: $Name" -Fore Yellow
    Stop-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $Id
    Do { 
      $state = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $inst).Instances.State.Name.Value
      Write-Host "($Id) Current State = $state" -Fore Cyan
      Start-Sleep -S 5 
    } 
    While ($state -ne "stopped")
    Write-Host "Starting: $Name" -Fore Yellow
    Start-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $Id
    Do { 
      $state = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $inst).Instances.State.Name.Value
      Write-Host "($Id) Current State = $state" -Fore Cyan
      Start-Sleep -S 5 
    }
    While ($state -ne "running")
  }
}

function StartInstance {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString -like "i-*") {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $QueryString).Instances 
  } else {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }).Instances
  }
  if ($insts) {
    Foreach ($inst in $insts) {
      $Id = $inst.InstanceId
      $Name = $inst.Tags | Where-Object { $_.key -eq "Name" } | Select-Object -expand Value
      Write-Host "** Found: $Name ($Id) ***"
      Write-Host "Starting: $Name" -Fore Yellow
      Start-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $Id
      Write-Host "Instance Started.. Please Wait a few minutes before trying to connect: $Name" -Fore Yellow
    }
  } else {
    Write-Host "No Instances Found, are you sure there are any there??"
  }
}

function StopInstance {
  param($QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString -like "i-*") {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $QueryString).Instances 
  } else {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }).Instances
  }
  Foreach ($inst in $insts) {
    $Id = $inst.InstanceId
    $Name = $inst.Tags | Where-Object { $_.key -eq "Name" } | Select-Object -expand Value
    Write-Host "** Found: $Name ($Id) ***"
    Write-Host "Stopping: $Name" -Fore Yellow
    Stop-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $Id
  }
}

function CheckSSMStatus {
  param($QueryString)
  Write-Host "*********`n`n Testing $QueryString`n`n*********`n" -Fore Yellow
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  if ($QueryString -like "i-*") {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $QueryString).Instances 
  } else {
    $insts = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{Name = "instance-state-name"; Values = "running" }).Instances
  }
  if ($insts.count -eq 0) { Write-Error "No instances found, are you using the correct aws role?" }
  Foreach ($inst in $insts) {
    $Id = $inst.InstanceId
    $Name = (Get-EC2Tag -ProfileName $Prof -Region $Reg -Filter @{Name = "resource-id"; Values = $Id }, @{Name = "key"; Values = "Name" }).Value
    $Res = (Get-SSMConnectionStatus -ProfileName $Prof -Region $Reg -Target $Id).Status
    if ($Res -eq "Connected") {
      Write-Host "$Name`t$Res`tssm $id" -Fore Green
    } else {
      Write-Host "$Name`t$Res`tssm $id" -Fore Red
    }
  }
}

function SSMMulti {
  param($QueryString)
  Write-Host "*********`n`n Will ssm remote into all: $QueryString`n`n*********`n" -Fore Yellow
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof

  $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running' }).Instances
  if ($ec2List.count -eq 0) {
    $textInfo = (Get-Culture).TextInfo
    $QueryString = $textInfo.ToTitleCase($QueryString)
    $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }, @{'name' = 'instance-state-name'; 'values' = 'running' }).Instances
  }
  if ($ec2List.count -eq 0) { Write-Error "No instances found, are you using the correct AWS role?"; Return }

  $instanceCount = $ec2List.Count
  Write-Host "There are $instanceCount instances to go through..." -Fore Yellow
  $processedCount = 0

  ForEach ($i in $ec2List) {
    $Name = ($i.Tags | Where-Object -Property Key -EQ Name).Value
    $InstanceID = $i.InstanceId
    $PrivIp = $i.PrivateIpAddress

    if ($InstanceID -eq "") {
      exit
    } else {
      Write-Host "[$processedCount] SSMing to: $Name ($PrivIp) - (ID: $InstanceID)" -Fore Cyan
      aws ssm start-session --target $InstanceID --profile $Prof --region $Reg
      $processedCount++
      
      # Check if we have connected to the last instance
      if ($processedCount -eq $instanceCount) {
        Write-Host "Connected to the last instance. Exiting loop."
        break
      }
    }
  }
}

function GrantAlexFTP {
  param($QueryString)
  $textInfo = (Get-Culture).TextInfo
  $QueryString = $textInfo.ToLower($QueryString)
  Write-Host "*********`n Adding you to $QueryString Ftp SG`n*********`n" -Fore Yellow
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $MyExternalIP = (Invoke-WebRequest -Uri "https://api.ipify.org/").Content + "/32"  
  $GroupId = (Get-EC2SecurityGroup -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "$QueryString*-ftp" }).GroupId
  $IpRange = New-Object -TypeName Amazon.EC2.Model.IpRange
  $IpRange.CidrIp = $MyExternalIP
  $IpRange.Description = "Alex W"
  $IpPermission = New-Object Amazon.EC2.Model.IpPermission
  $IpPermission.IpProtocol = "tcp"
  $IpPermission.ToPort = 22
  $IpPermission.FromPort = 22
  $IpPermission.Ipv4Ranges = $IpRange
  Grant-EC2SecurityGroupIngress -ProfileName $Prof -Region $Reg -GroupId $GroupId -IpPermission $IpPermission
}

function Get-S3BucketSize {
  param ([string] $BucketName)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $ObjectList = Get-S3Object -ProfileName $Prof -Region $Reg -BucketName $BucketName

  $Sum = $ObjectList | Select-Object -ExpandProperty Size | Measure-Object -Sum
  [PSCustomObject]@{
    BucketName = $BucketName
    SizeInMB   = $Sum.Sum / 1Mb
  }
}


function Get-SecurityGroup {
  param ([string] $SGName)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  Get-EC2SecurityGroup -ProfileName $Prof -Region $Reg -GroupId $SGName | Select-Object GroupName, Description | Format-Table * -Auto
}

function GetSnapshot {
  param ([string] $SNID)
  $ErrorActionPreference = "SilentlyContinue"  
  $Profs = (Get-AWSCredential -ListProfileDetail | Where-Object { $_.ProfileName -like "assume-*" }).ProfileName
  foreach ($Prof in $Profs) {
    $Reg = GetReg $Prof
    Write-Host "************  $Prof  ************"
    Get-EC2Snapshot -ProfileName $Prof -Region $Reg -SnapshotId $SNID
  }
}

function Get-Tags {
  param ([string] $QueryString)
  $Prof = $ENV:AWS_PROFILE
  $Reg = GetReg $Prof
  $ec2List = (Get-EC2Instance -ProfileName $Prof -Region $Reg -Filter @{Name = "tag:Name"; Values = "*$QueryString*" }).Instances
  ForEach ($i in $ec2List) {
    $InstanceID = $i.InstanceId
    $Name = ($i.Tags | Where-Object -Property Key -EQ Name).value
    Write-Host "Tags for $Name ($InstanceID)`n" -Fore Green
    (Get-EC2Instance -ProfileName $Prof -Region $Reg -InstanceId $InstanceID).Instances.Tags | Sort-Object Key | Format-Table -Auto
  }
}

function Get-AwsList {
  $tshConfig = tsh apps ls
  # Extract the application names from the table format
  $Profs = $tshConfig -split "`n" | Select-Object -Skip 2 | ForEach-Object { ($_ -split "\s{2,}" | Select-Object -First 1).Trim() }
  Write-Host "Profiles:" -ForegroundColor Yellow
  $Profs | ForEach-Object { $_ -replace "roun...", "round" }
}

New-Alias -Name "addmeftp" GrantAlexFTP -Force
New-Alias -Name "awsl" Get-AwsList -Force
New-Alias -Name "awsp" Set-AwsProfile -Force
New-Alias -Name "awsq" Get-AwsProfile -Force
New-Alias -Name "check" CheckInstStatus -Force
New-Alias -Name "checkssm" CheckSSMStatus -Force
New-Alias -Name "findinst" FindInstance -Force
New-Alias -Name "getags" Get-Tags -Force
New-Alias -Name "getbuckets" GetBucketList -Force
New-Alias -Name "getindex" DownloadS3Index -Force
New-Alias -Name "getpass" -Value GetPasswordData -Force
New-Alias -Name "gets3file" DownloadS3File -Force
New-Alias -Name "getsg" Get-SecurityGroup -Force
New-Alias -Name "getsnap" GetSnapshot -Force
New-Alias -Name "grep" findstr -Force
New-Alias -Name "instag" GetInstances -Force
New-Alias -Name "instt" GetInsts2 -Force
New-Alias -Name "mon" CheckInstStatus -Force
New-Alias -Name "s3buckets" GetBucketList -Force
New-Alias -Name "s3files" Get-S3Files -Force
New-Alias -Name "s3size" Get-S3BucketSize -Force
New-Alias -Name "ssm" StartSSM -Force
New-Alias -Name "ssmm" SSMMulti -Force
New-Alias -Name "startit" StartInstance -Force
New-Alias -Name "stopit" StopInstance -Force
New-Alias -Name "taskip" GetTaskMasterIP -Force
