#Requires -Version 7.0
<# Disable unsupported service buttons in the private movie; never change a save. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PrivateGameFile,
      [Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $PrivateGameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $inputPath
Assert-OrdinaryPath $outputPath
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $packageRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$packageRoot}
if($outputPath -ieq $protectedSource -or $outputPath.StartsWith($protectedSource+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)){throw 'Create the private output directory first.'}
foreach($path in @($outputPath,($outputPath+'.json'))){if(Test-Path -LiteralPath $path){throw 'Output or report already exists.'}}
if(-not ('DDDOfflineExtras' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDOfflineExtras {
    const string InputHash="df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804";
    const string OutputHash="a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44";
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string message){if(!test)throw new InvalidDataException(message);}
    public static string Prepare(string inputPath,string outputPath){
        byte[] input=File.ReadAllBytes(inputPath);
        Need(Hash(input)==InputHash,"Unrecognized input; use the StashActions candidate");
        Need(input.Length==28621088&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'
            &&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");
        const int at=28538891;
        byte[] before=Convert.FromHexString("6002669222600266902229290202");
        // ExtrasScreen constructor, before initial focus: trophies.enabled=false;
        // highScore.enabled=false. Existing navigation skips disabled buttons.
        // Replace the already-neutralized platform comparison, preserving width.
        byte[] after=Convert.FromHexString("62072761f31a62082761f31a0202");
        Need(before.Length==after.Length,"Fixed-width edit");
        for(int n=0;n<before.Length;n++)Need(input[at+n]==before[n],"Constructor instruction guard");
        byte[] result=(byte[])input.Clone();after.CopyTo(result,at);
        Need(Hash(result)==OutputHash,"Unexpected candidate bytes");
        byte[] reverse=(byte[])result.Clone();before.CopyTo(reverse,at);
        Need(Hash(reverse)==InputHash,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==InputHash,"Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDOfflineExtras]::Prepare($inputPath,$outputPath)
$report=[ordered]@{
    inputSha256='df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804'
    outputSha256=$outputHash; inputUnchanged=$true; wholeInputRecovered=$true
    methods=@(4677); inputBytes=28621088; outputBytes=28621088
    disabledButtons=@('Trophies','Hi-score'); localMissionsUnchanged=$true
    gameTextUnchanged=$true; saveMethodsUnchanged=$true; privateGameContent=$true
    limitation='Preparation only. This command does not run the game or establish hardware support.'
}|ConvertTo-Json -Depth 5
$stream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$stream.Write([Text.Encoding]::UTF8.GetBytes($report+[Environment]::NewLine))}finally{$stream.Dispose()}
Write-Output "Prepared private offline-menu candidate: $outputHash"
