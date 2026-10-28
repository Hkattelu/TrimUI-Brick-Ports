#Requires -Version 7.0
<# Prepare a private Windows64 AIR test from caller-supplied files. Fetches nothing.
   Original game code, ActionScript libraries and Steam checks remain unchanged.
   See diagnostics/README.md for the optional observer and compatibility limits. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OriginalGameDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$FreSteamWorksAne,
    [Parameter(Mandatory)][string]$SteamApi64File,
    [string]$WindowHintFile,
    [string]$ObserverDll
)
$ErrorActionPreference='Stop'
function Assert-Hash([string]$Path,[string]$Expected) {
    if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Expected){throw "Unrecognized file revision: $Path"}
}
function Assert-PE64([string]$Path) {
    $reader=[IO.BinaryReader]::new([IO.File]::OpenRead($Path))
    try {
        if($reader.ReadUInt16() -ne 0x5a4d){throw "Expected an MZ executable: $Path"}
        $reader.BaseStream.Position=0x3c; $offset=$reader.ReadUInt32()
        if($offset+26 -gt $reader.BaseStream.Length){throw "Invalid PE offset: $Path"}
        $reader.BaseStream.Position=$offset
        if($reader.ReadUInt32() -ne 0x4550 -or $reader.ReadUInt16() -ne 0x8664){throw "Expected x64 PE: $Path"}
        $reader.BaseStream.Position=$offset+24
        if($reader.ReadUInt16() -ne 0x20b){throw "Expected PE32+: $Path"}
    } finally {$reader.Dispose()}
}
function Assert-NoReparseAncestor([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor) {
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Use a path without junctions or symbolic links: $Path"
        }
    }
}
$original=(Get-Item -LiteralPath $OriginalGameDirectory).FullName.TrimEnd('\','/')
$output=[IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repository=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$PSScriptRoot.TrimEnd('\','/')}
if(-not (Test-Path -LiteralPath $original -PathType Container)){throw 'OriginalGameDirectory must be a directory.'}
Assert-NoReparseAncestor $original
Assert-NoReparseAncestor $output
foreach($protected in @($original,$repository)) {
    if($output -ieq $protected -or $output.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Output must be outside both the original installation and this repository.'
    }
}
if(Test-Path -LiteralPath $output) {
    if(-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count){throw 'Output must be a new or empty private directory.'}
}
$sourceFiles=@(Get-ChildItem -LiteralPath $original -Force -Recurse)
if($sourceFiles | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }){throw 'Original game contains a junction or symbolic link; copy ordinary files first.'}
$gameName='ddd-0.1-SNAPSHOT.swf'
$originalHash='595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0'
$windowHash='309bd8f8a9512444d5786437a4746b81ac0b28b8f2c6c9e2bb8ed2094e5397cf'
$aneHash='c2bab9541bc827e2d53b17ebd4fa8da7ec24bd461a63f36e086c47746140baec'
$steamHash='eb17909a76668cf9ae0b92a618a34a50f6c73d3a6787cb4dd8ce36a8b10bfb75'
$nativeHash='8639c6321eaab84fac982a0208e182471dc40aaa4a6eb5d14516c1762381562f'
Assert-Hash (Join-Path $original $gameName) $originalHash
Assert-Hash $FreSteamWorksAne $aneHash
# This exact locally supplied Valve DLL was checked for all 11 required exports.
Assert-Hash $SteamApi64File $steamHash
Assert-PE64 $SteamApi64File
if($WindowHintFile){Assert-Hash $WindowHintFile $windowHash}
if($ObserverDll){Assert-PE64 $ObserverDll}
$aneRelative='META-INF/AIR/extensions/com.amanitadesign.steam.FRESteamWorks/META-INF/ANE'
$sourceAne=Join-Path $original $aneRelative
$descriptor=[xml](Get-Content -LiteralPath (Join-Path $sourceAne 'extension.xml') -Raw)
if($descriptor.extension.id -ne 'com.amanitadesign.steam.FRESteamWorks'){throw 'Unexpected native extension ID.'}
$platforms=$descriptor.extension.platforms
$platform32=@($platforms.platform | Where-Object name -eq 'Windows-x86')
if($platform32.Count -ne 1 -or @($platforms.platform | Where-Object name -eq 'Windows-x86-64').Count){throw 'Expected an original extension with one Windows-x86 platform and no Windows-x86-64 platform.'}
if(-not (Test-Path -LiteralPath (Join-Path $sourceAne 'Windows-x86/library.swf'))){throw 'Original extension library is missing.'}
$libraries=@($sourceFiles | Where-Object { -not $_.PSIsContainer -and $_.Name -eq 'library.swf' } | ForEach-Object {
    [pscustomobject]@{relative=[IO.Path]::GetRelativePath($original,$_.FullName); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$archive=[IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $FreSteamWorksAne).FullName)
try {
    $entry=$archive.GetEntry('META-INF/ANE/Windows-x86-64/FRESteamWorks-64.dll')
    if(-not $entry){throw 'Pinned ANE is missing its Windows64 native library.'}
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    Get-ChildItem -LiteralPath $original -Force | Copy-Item -Destination $output -Recurse
    $targetAne=Join-Path $output $aneRelative
    $platform64=Join-Path $targetAne 'Windows-x86-64'
    New-Item -ItemType Directory -Path $platform64 | Out-Null
    $nativePath=Join-Path $platform64 'FRESteamWorks-64.dll'
    $inputStream=$entry.Open(); $outputStream=[IO.File]::Open($nativePath,[IO.FileMode]::CreateNew)
    try {$inputStream.CopyTo($outputStream)} finally {$inputStream.Dispose(); $outputStream.Dispose()}
    Assert-Hash $nativePath $nativeHash
    Assert-PE64 $nativePath
    Copy-Item -LiteralPath (Join-Path $sourceAne 'Windows-x86/library.swf') -Destination $platform64
    $newPlatform=$platform32[0].CloneNode($true)
    $newPlatform.SetAttribute('name','Windows-x86-64')
    $newPlatform.applicationDeployment.nativeLibrary='FRESteamWorks-64.dll'
    [void]$platforms.AppendChild($newPlatform)
    $descriptor.Save((Join-Path $targetAne 'extension.xml'))
    Copy-Item -LiteralPath $SteamApi64File -Destination (Join-Path $output 'steam_api64.dll')
    if($WindowHintFile){Copy-Item -LiteralPath $WindowHintFile -Destination (Join-Path $output $gameName) -Force}
    if($ObserverDll) {
        Copy-Item -LiteralPath $nativePath -Destination (Join-Path $platform64 'FRESteamWorks-original-64.dll')
        Copy-Item -LiteralPath $ObserverDll -Destination $nativePath -Force
    }
} finally {$archive.Dispose()}
foreach($library in $libraries) {
    Assert-Hash (Join-Path $original $library.relative) $library.sha256
    Assert-Hash (Join-Path $output $library.relative) $library.sha256
}
Assert-Hash (Join-Path $platform64 'library.swf') (Get-FileHash -LiteralPath (Join-Path $sourceAne 'Windows-x86/library.swf') -Algorithm SHA256).Hash
Assert-Hash (Join-Path $original $gameName) $originalHash
Assert-Hash (Join-Path $output $gameName) $(if($WindowHintFile){$windowHash}else{$originalHash})
Assert-Hash (Join-Path $output 'steam_api64.dll') $steamHash
[ordered]@{privateGameContent=$true;originalGameUnchanged=$true;originalLibrariesPreserved=$libraries.Count;aneSha256=$aneHash;nativeDllSha256=$nativeHash;steamApi64Sha256=$steamHash;windowHintApplied=[bool]$WindowHintFile;observerApplied=[bool]$ObserverDll;runtimeValidated=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $output 'native-probe.json')
Write-Output "Prepared private native Steam probe: $output"
