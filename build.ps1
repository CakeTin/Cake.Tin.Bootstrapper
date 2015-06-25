<#
 
.SYNOPSIS
This is a Powershell script to bootstrap a CakeTin build.
 
.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake/CakeTin)
and execute your Cake build script with the parameters you provide.

.PARAMETER Script
The build script to execute.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER Experimental
Tells Cake to use the latest Roslyn release.
 
.LINK
http://cakebuild.net
#>

Param(
    [string]$Script = "build/build.cake",
    [string]$Configuration = "Release",
    [string]$BUILD_EXE = "Build\bin\$Configuration\CakeTinBuild.exe",
    [string]$Target = "Default",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [Alias("DryRun","Noop")]
    [switch]$Experimental,
    [switch]$WhatIf
)

Write-Host "Initializing..."

$BUILD_DIR = Join-Path $PSScriptRoot "Build"
$TOOLS_DIR = Join-Path $BUILD_DIR "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$CAKE_EXE = Join-Path $TOOLS_DIR "Cake/Cake.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"

# Should we use the new Roslyn?
$UseExperimental = "";
if($Experimental.IsPresent) {
    $UseExperimental = "-experimental"
}

# Is this a dry run?
$UseDryRun = "";
if($WhatIf.IsPresent) {
    $UseDryRun = "-dryrun"
}

# Make sure Build folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $BUILD_DIR)) {
    New-Item -path $BUILD_DIR -itemtype directory
}

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    New-Item -path $TOOLS_DIR -name logfiles -itemtype directory
}

# Try find NuGet.exe in path if not exists
if (!(Test-Path $NUGET_EXE)) {
    "Trying to find nuget.exe in path"
    $NUGET_EXE_IN_PATH = &where.exe nuget.exe
    if ($NUGET_EXE_IN_PATH -ne $null -and (Test-Path $NUGET_EXE_IN_PATH)) {
        "Found $($NUGET_EXE_IN_PATH)"
        $NUGET_EXE = $NUGET_EXE_IN_PATH 
    }
}

# Try download NuGet.exe if not exists
if (!(Test-Path $NUGET_EXE)) {
    Invoke-WebRequest -Uri http://nuget.org/nuget.exe -OutFile $NUGET_EXE
}

# Make sure NuGet exists where we expect it.
if (!(Test-Path $NUGET_EXE)) {
    Throw "Could not find NuGet.exe"
}

# Save nuget.exe path to environment to be available to child processed
$ENV:NUGET_EXE = $NUGET_EXE

# Restore tools from NuGet.
Push-Location
Set-Location $TOOLS_DIR

# Restore packages
if (Test-Path $PACKAGES_CONFIG)
{
    Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion"
}
# Install just Cake if missing config
else
{
    Invoke-Expression "&`"$NUGET_EXE`" install Cake -ExcludeVersion"
}
Pop-Location
if ($LASTEXITCODE -ne 0)
{
    exit $LASTEXITCODE
}

# Make sure that Cake has been installed.
if (!(Test-Path $CAKE_EXE)) {
    Throw "Could not find Cake.exe"
}

# Start Cake
Invoke-Expression "$CAKE_EXE `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseDryRun $UseExperimental"

if ($LASTEXITCODE -eq 0)
{
#Write-Host $BUILD_EXE
	# Start Build Binary
	Invoke-Expression "$BUILD_EXE -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseDryRun $UseExperimental"
}

exit $LASTEXITCODE
