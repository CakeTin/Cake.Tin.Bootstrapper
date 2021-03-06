<#
 
.SYNOPSIS
This is a Powershell script to bootstrap a Cake.Tin build.
 
.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake/Cake.tin), compile
and execute your Cake.Tin solution with the parameters you provide.

.PARAMETER Solution
The build Solution to compile and execute.
.PARAMETER Target
The build target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER WhatIf
Performs a dry run of the build.
No tasks will be executed.
.PARAMETER Experimental
Tells Cake to use the latest Roslyn release.
 
.LINK
http://cakebuild.net
#>

Param(
    [string]$Solution = "Build\Build.sln",
    [string]$Configuration = "Release",
    [string]$BuildExe = "Build\bin\$Configuration\Build.exe",
    [string]$Target = "Default",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [Alias("DryRun","Noop")]
    [switch]$Experimental,
    [switch]$WhatIf
)

$LIB_DIR = Join-Path $PSScriptRoot "Build\lib"
$NUGET_EXE = Join-Path $LIB_DIR "nuget.exe"
$CAKETIN_DLL = Join-Path $LIB_DIR "Cake.Tin\Cake.Tin.dll"
$PACKAGES_CONFIG = Join-Path $LIB_DIR "packages.config"
$Solution = Join-Path $PSScriptRoot $Solution
$BuildExe =  Join-Path $PSScriptRoot $BuildExe

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

# Make sure Lib folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $LIB_DIR)) {
    New-Item -path $LIB_DIR -name logfiles -itemtype directory
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

# Restore Lib from NuGet.
Push-Location
Set-Location $LIB_DIR

# Restore packages
if (Test-Path $PACKAGES_CONFIG)
{
    Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion"
}
# Install just Cake if missing config
else
{
    Invoke-Expression "&`"$NUGET_EXE`" install Cake.Tin -ExcludeVersion -Prerelease -Source https://www.myget.org/F/caketin/api/v2/"
}
Pop-Location
if ($LASTEXITCODE -ne 0)
{
    exit $LASTEXITCODE
}

# Make sure that CakeTin has been installed.
if (!(Test-Path $CAKETIN_DLL)) {
    Throw "Could not find " + $CAKETIN_DLL
}

$zipFile = Join-Path $PSScriptRoot "caketinbuild.zip"
$slnExists = Test-Path $Solution
$zipExists = Test-Path $zipFile

if ($zipExists -and $slnExists) {
    Throw "Found caketinbuild.zip and a build sln. Only one or other should be present($Solution)."
}

if ($zipExists) {
	Write-Host "Extracting zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
	$targetFolder = Join-Path $PSScriptRoot "Build"
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $targetFolder)
}

$slnExists = Test-Path $Solution
if (!($slnExists)) {
    Throw "Unable to find '$Solution'."
}

if ($zipExists) {
    Move-Item $zipFile $targetFolder
}


# Load Cake Tin and build the Build Sln
add-type -path $CAKETIN_DLL
Write-Host "Pre Build: building $Solution, -configuration=`"$Configuration`""
$result = [Cake.Tin.BuildCompiler]::Compile($Solution, "-configuration=`"$Configuration`"" )
Write-Host "Pre-build complete - $result"
if ($result -eq "Success") {
    # Finally, run the actual build 
	$command = "$BuildExe -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseDryRun $UseExperimental"
	Write-Host "Executing: $command"
	Invoke-Expression $command
	exit $LASTEXITCODE
}
else
{
	exit 1
}
#Install-Package Cake.Tin  -Source https://www.myget.org/F/caketin/api/v2 -Version 0.0.1-build-2