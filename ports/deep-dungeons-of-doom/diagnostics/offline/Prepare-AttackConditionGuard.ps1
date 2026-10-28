#Requires -Version 7.0
<# Prepare a private compatibility candidate; never install it or change a save. #>
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
if(-not ('DDDAttackConditionGuard' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDAttackConditionGuard {
    const string InputHash="7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05";
    const string OutputHash="8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e";
    const int Signature=28153686,Body=28461646,Code=Body+7,TagLength=27931473;
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static void Require(byte[] b,int at,string hex){byte[] x=Convert.FromHexString(hex);Need(at>=0&&at<=b.Length-x.Length,"Guard outside file");for(int i=0;i<x.Length;i++)Need(b[at+i]==x[i],"Instruction guard at "+at);}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static byte[] Splice(byte[] b,int at,int oldLength,byte[] replacement){byte[] r=new byte[b.Length-oldLength+replacement.Length];Array.Copy(b,0,r,0,at);Array.Copy(replacement,0,r,at,replacement.Length);Array.Copy(b,at+oldLength,r,at+replacement.Length,b.Length-at-oldLength);return r;}
    public static string Prepare(string inputPath,string outputPath){
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==InputHash,"Unrecognized input; use the preserved accepted play movie");
        Need(input.Length==28620963&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");
        Need(BitConverter.ToUInt32(input,TagLength)==672895,"Unexpected ABC length");
        Require(input,Signature,"ad01");Require(input,Body,"d61a030603043ad030");
        byte[] code=new byte[58];Array.Copy(input,Code,code,0,code.Length);
        Need(Hash(code)=="efdd6fd5b331f06305c9fbccb77c1d979e55d243a4d5086b4279d207887f21a2","Unexpected original membership loop");
        // Original vector inputs execute the byte-identical loop. Invalid values
        // return the same false result as the former caught TypeError path.
        byte[] guard=Convert.FromHexString("d1b2ad01110200002748");
        byte[] result=Splice(input,Code+2,0,guard);
        result[Code-1]=68;
        result=Splice(result,Signature,2,new byte[]{32});
        Set32(result,4,result.Length);Set32(result,TagLength,672904);
        Need(result.Length==input.Length+9&&Hash(result)==OutputHash,"Unexpected candidate bytes");
        byte[] recovered=Splice(result,Signature,1,Convert.FromHexString("ad01"));
        recovered=Splice(recovered,Code+2,guard.Length,Array.Empty<byte>());
        recovered[Code-1]=58;Set32(recovered,4,input.Length);Set32(recovered,TagLength,672895);
        Need(Hash(recovered)==InputHash,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==InputHash,"Input changed during preparation");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDAttackConditionGuard]::Prepare($inputPath,$outputPath)
$report=[ordered]@{
    inputSha256='7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05';outputSha256=$outputHash
    inputUnchanged=$true;wholeInputRecovered=$true;growthBytes=9;method=3414
    change='Guard malformed historical membership-condition values before typed vector coercion'
    originalVectorLoopUnchanged=$true;combatAndAnimationTimingUnchanged=$true;gameTextUnchanged=$true
    saveFilesTouched=$false;privateGameContent=$true;selectedForDevice=$false
    limitations=@('Does not reconstruct invalid historical achievement values','Does not establish physical attack feel','Use separate runtime and rendered validation before installation')
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$stream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$stream.Write($reportBytes,0,$reportBytes.Length)}finally{$stream.Dispose()}
Write-Output "Prepared private attack condition candidate: $outputPath"
Write-Output "SHA256 $outputHash"
