# Configuration
$Config = @{
    TemplatesPath = "C:\Nuget_Bits\templates"
    TempPath = "C:\Temp"
    DefaultPort = 6552
    DefaultPortNoAkka = 6558
    NuGetSource = "YouLend"
    NuGetApiKey = "AzureDevOps"
}

# Define Domain
$Domain = "JackTest"

# Function to rebuild a .NET project
function Rebuild-DotNetProject {
    param(
        [ValidateSet("Akka", "NoAkka")] [string]$TemplateType = "Akka",
        [int]$Port = 0
    )

    $Port = if ($Port -eq 0) { 
        if ($TemplateType -eq "Akka") { $Config.DefaultPort } else { $Config.DefaultPortNoAkka }
    }

    $templatePath = Join-Path $Config.TemplatesPath "YL.Template.Domain.$TemplateType"
    $templateName = "yl-domain-$($TemplateType.ToLower())"
    
    $DomainName = "$Domain$($TemplateType -eq 'Akka' ? 'With' : 'Without')"
    $outputPath = Join-Path $Config.TempPath $DomainName

    Write-Host "Resetting template..." -ForegroundColor Cyan
    dotnet new uninstall $templatePath
    Remove-Item -Path "$($Config.TempPath)\*" -Force -Recurse -ErrorAction SilentlyContinue
    dotnet new install $templatePath

    Write-Host "Creating new project at $outputPath..." -ForegroundColor Cyan
    dotnet new $templateName -n $DomainName -P $Port -o $outputPath --allow-scripts yes

    $newDomain = ($DomainName -replace "\\.", "-") + ".local-dev.kube"
    Write-Host "Adding hosts entry for $newDomain..." -ForegroundColor Cyan
    AHE $newDomain.ToLower()
}

# Function to remove .NET templates
function Remove-DotNetTemplate {
    param(
        [ValidateSet("Akka", "NoAkka", "Both")] [string]$TemplateType = "Both"
    )

    if ($TemplateType -eq "Both" -or $TemplateType -eq "Akka") {
        dotnet new uninstall (Join-Path $Config.TemplatesPath "YL.Template.Domain.Akka")
    }
    if ($TemplateType -eq "Both" -or $TemplateType -eq "NoAkka") {
        dotnet new uninstall (Join-Path $Config.TemplatesPath "YL.Template.Domain.NoAkka")
    }

    Remove-Item -Path "$($Config.TempPath)\*" -Force -Recurse -ErrorAction SilentlyContinue
}

# Function to build a .NET project
function Build-DotNetProject {
    param(
        [string]$DomainName,
        [ValidateSet("Akka", "NoAkka")] [string]$TemplateType = "Akka",
        [int]$Port = 6552
    )

    $templatePath = Join-Path $Config.TemplatesPath "YL.Template.Domain.$TemplateType"
    $templateName = "yl-domain-$($TemplateType.ToLower())"
    $outputPath = Join-Path $Config.TempPath $DomainName

    dotnet new install $templatePath --force
    dotnet new $templateName -n $DomainName -P $Port -o $outputPath --allow-scripts yes
}

# Function to find NuGet packages
function Find-NuGetPackages {
    param(
        [string]$SearchTerm = "Template",
        [string]$Source = $Config.NuGetSource,
        [switch]$IncludePrerelease
    )
    
    $prerelease = if ($IncludePrerelease) { "-Prerelease" } else { "" }
    Write-Host "Searching for packages with term '$SearchTerm'..." -ForegroundColor Cyan
    Invoke-Expression "nuget search $SearchTerm -Source $Source $prerelease"
}

# Function to pack a specific template
function Pack-Template {
    param(
        [ValidateSet("Akka", "NoAkka")] [string]$TemplateType,
        [string]$OutputPath = ""
    )
    
    $projectPath = Join-Path $Config.TemplatesPath "YL.Template.Domain.$TemplateType.csproj"
    if (-not (Test-Path $projectPath)) {
        Write-Host "Project not found: $projectPath" -ForegroundColor Red
        return
    }

    $OutputPath = if ($OutputPath) { $OutputPath } else { Join-Path $Config.TempPath "Domain$TemplateType" }
    if (-not (Test-Path $OutputPath)) { New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null }

    Write-Host "Packing $TemplateType template to $OutputPath..." -ForegroundColor Cyan
    dotnet pack $projectPath --output $OutputPath
}

# Function to push the latest NuGet package
function Push-NuGetPackage {
    param(
        [ValidateSet("Akka", "NoAkka")] [string]$TemplateType
    )

    $packagePath = Join-Path $Config.TempPath "Domain$TemplateType"
    if (-not (Test-Path $packagePath)) {
        Write-Host "Package directory not found: $packagePath" -ForegroundColor Red
        return
    }

    $latestPackage = Get-ChildItem -Path $packagePath -Filter "*.nupkg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latestPackage) {
        Write-Host "No package found in $packagePath" -ForegroundColor Red
        return
    }

    Write-Host "Pushing package $($latestPackage.Name) to $Config.NuGetSource..." -ForegroundColor Cyan
    dotnet nuget push $latestPackage.FullName --source $Config.NuGetSource --api-key $Config.NuGetApiKey --skip-duplicate
}

# Define aliases
Set-Alias -Name rbdt -Value Rebuild-DotNetProject
Set-Alias -Name rmdt -Value Remove-DotNetTemplate
Set-Alias -Name bdt -Value Build-DotNetProject
Set-Alias -Name findpack -Value Find-NuGetPackages
Set-Alias -Name packakka -Value Pack-Template
Set-Alias -Name packnoakka -Value Pack-Template
Set-Alias -Name pushakka -Value Push-NuGetPackage
Set-Alias -Name pushnoakka -Value Push-NuGetPackage