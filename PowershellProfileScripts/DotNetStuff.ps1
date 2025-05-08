function Rebuild-DotNet {
	clear-host
	dotnet new install C:\Nuget_Bits\new_templates\YL.Template.Web.Api.ThirdParty --force
	rm C:\Temp\* -Force -Recurse
	dotnet new yl-template-web-api-thirdparty -n YL.Web.Api.ThirdParty.AlexTest -o C:\Temp\YL.Web.Api.ThirdParty.AlexTest --allow-scripts yes
}

function DotNetRemover {
	  param(
        [switch]$F  # Use [switch] since it's a flag (true/false)
    )
    $Command = "dotnet new uninstall"
    if ($F) {
        $Command += " $F"
    }
    Invoke-Expression $Command		
}

function DotNetInstaller {
	param($Fol)
	dotnet new install $Fol
}

function DotNetPacker {
    param(
        [string]$Fol
    )
    $csprojFile = Get-ChildItem -Path $Fol -Filter *.csproj -File | Select-Object -First 1
    if (-not $csprojFile) {
        Write-Host "csproj not found in '$Fol' - you must specify a valid .csproj file!" -ForegroundColor Yellow
        return
    }
    dotnet pack $csprojFile.FullName
}

function DotNetPusher {
    param(
        [string]$File
    )
    $nupkgFile = Get-Item $File
    if (-not $nupkgFile) {
        Write-Host "nupkg not found - you must specify a valid .nupkg file!" -ForegroundColor Yellow
        return
    }
    dotnet nuget push $nupkgFile.FullName  --source "YouLend" --api-key AzureDevOps
}

function ListDotNetTemplates {
    param(
        [switch]$Pr  # Use [switch] since it's a flag (true/false)
    )

    $Command = "nuget search 'template' -source 'YouLend'"
    if ($Pr) {
        $Command += " -PreRelease"
    }
    Invoke-Expression $Command
}

function DotNetInstallerFromTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$T,   # Type (e.g. YL.Web.Api.Customer)

        [Parameter(Mandatory)]
        [string]$N,   # Name (e.g. Alex)

        [switch]$P    # Optional switch for extra param
    )

    # Build Template Name correctly
    $template = "yl-template-" + ($T -replace "^YL\.?", "" -replace "Template\.?", "" -replace "\.", "-").ToLower()

    # Build Project Name
    $projectName = "$T.$N"

    # Build Output Path
    $outputPath = "C:\Tmp\$projectName"

    # Build base command
    $cmd = "dotnet new $template -n $projectName -o $outputPath --allow-scripts yes"

    # Add optional parameter if -P is used
    if ($P) {
        $cmd += " -P 6552"
    }

    Write-Host "Running: $cmd" -ForegroundColor Cyan
    Invoke-Expression $cmd
}

Set-Alias RBDN Rebuild-DotNet
Set-Alias DNI DotNetInstaller
Set-Alias DNNew DotNetInstallerFromTemplate
#Example: DNNew -T YL.Web.Api.Customer -N Alex
Set-Alias DNU DotNetRemover
Set-Alias Pack DotNetPacker
Set-Alias Push DotNetPusher
Set-Alias GetTemplates ListDotNetTemplates
