#Requires -Version 7.0
<# Prepare a private diagnostic candidate; does not install, launch or modify its input. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PrivateGameFile,
      [Parameter(Mandatory)][string]$OutputFile)
$ErrorActionPreference='Stop'
function Assert-OrdinaryPath([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        $item=Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$inputPath=(Get-Item -LiteralPath $PrivateGameFile).FullName
$outputPath=[IO.Path]::GetFullPath($OutputFile)
Assert-OrdinaryPath $inputPath
Assert-OrdinaryPath $outputPath
Assert-OrdinaryPath ($outputPath+'.json')
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $packageRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$packageRoot}
if($outputPath -ieq $protectedSource -or $outputPath.StartsWith($protectedSource+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
if([IO.Path]::GetExtension($outputPath) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if(!(Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)){throw 'Create the private output directory first.'}
foreach($path in @($outputPath,($outputPath+'.json'))){if(Test-Path -LiteralPath $path){throw 'Output or report already exists.'}}
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$variant=switch($expectedInput){
    'dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907' { [pscustomobject]@{name='up-wrap';silentLogo=$false;output='1c69ba3ab597452348ab44ee5d372c1ba7689dd91d8aff8091364703f6e07233'} }
    '27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824' { [pscustomobject]@{name='silent-logo-up-wrap';silentLogo=$true;output='a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7'} }
    default {throw 'Unrecognized input; use the exact preserved normal or silent-logo Up-wrap candidate.'}
}
if(-not ('DDDEncyclopediaBackProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDEncyclopediaBackProbe {
    const int Getter=28233106,TagHeader=27931471,TagLengthField=27931473;
    const string OldCode="d030d0b2c301110d0000d0b2bc0111050000d0b2c501482648";
    const string NewCode="d030d0b2c30111150000d0b2bc01110d0000d0b2c50111050000d0b2c701482648";
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static void Require(byte[] b,int at,string hex){byte[] x=Convert.FromHexString(hex);Need(at>=0&&at<=b.Length-x.Length,"Guard outside file");for(int i=0;i<x.Length;i++)Need(b[at+i]==x[i],"Instruction guard at "+at);}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static byte[] Splice(byte[] b,int at,int oldLength,byte[] replacement){byte[] r=new byte[b.Length-oldLength+replacement.Length];Array.Copy(b,0,r,0,at);Array.Copy(replacement,0,r,at,replacement.Length);Array.Copy(b,at+oldLength,r,at+replacement.Length,b.Length-at-oldLength);return r;}
    static byte[] WithLength(string hex){byte[] code=Convert.FromHexString(hex);Need(code.Length<128,"Single-byte code length");byte[] b=new byte[code.Length+1];b[0]=(byte)code.Length;Array.Copy(code,0,b,1,code.Length);return b;}
    static void Container(byte[] b){
        int at=8+(5+4*(b[8]>>3)+7)/8+4;
        while(at<b.Length){
            Need(at<=b.Length-2,"Truncated tag header");int header=at;ushort h=BitConverter.ToUInt16(b,at);at+=2;int n=h&63;
            if(n==63){Need(at<=b.Length-4,"Truncated long tag header");n=checked((int)BitConverter.ToUInt32(b,at));at+=4;}
            Need(n>=0&&at<=b.Length-n,"Invalid tag");
            if(Getter>=at&&Getter<at+n){Need(header==TagHeader&&(h>>6)==82&&at==TagHeader+6&&n==672602&&Getter+25<at+n,"Unexpected DoABC container");return;}
            at+=n;
        }
        throw new InvalidDataException("Getter outside expected DoABC tag");
    }
    public static string Prepare(string inputPath,string outputPath,string expected,string expectedOutput){
        Need((expected=="dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907"&&expectedOutput=="1c69ba3ab597452348ab44ee5d372c1ba7689dd91d8aff8091364703f6e07233")||
             (expected=="27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824"&&expectedOutput=="a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7"),"Unsupported input/output pair");
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==expected,"Input changed before preparation");
        Need(input.Length==28620670&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");Container(input);
        Require(input,Getter-7,"f2010101090a19");Require(input,Getter,OldCode);Require(input,Getter+25,"0000");
        // Add Encyclopedia to the existing Stash/WorldMap/MapShop predicate.
        // All short-circuit branches target pushtrue; max stack stays one.
        byte[] result=Splice(input,Getter-1,26,WithLength(NewCode));
        Set32(result,4,result.Length);Set32(result,TagLengthField,672610);
        Need(result.Length==28620678&&Hash(result)==expectedOutput,"Unexpected candidate bytes");
        byte[] recovered=Splice(result,Getter-1,34,WithLength(OldCode));
        Set32(recovered,4,input.Length);Set32(recovered,TagLengthField,672602);
        Need(Hash(recovered)==expected,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==expected,"Input changed during preparation");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDEncyclopediaBackProbe]::Prepare($inputPath,$outputPath,$expectedInput,$variant.output)
$report=[ordered]@{
    sourceVariant=$variant.name;inputSha256=$expectedInput;outputSha256=$outputHash;inputUnchanged=$true
    inputBytes=28620670;outputBytes=28620678;growthBytes=8;wholeInputRecovered=$true
    methods=@(242);oldCodeLengths=@(25);newCodeLengths=@(33)
    scope='Let Encyclopedia use its existing local Back handler and supplied return scene'
    addedSceneType='com.bossa.ddd.encyclopedia.Encyclopedia';existingThreeScenePredicatesUnchanged=$true
    explicitHomeOverridesUnchanged=$true;otherInheritedSceneFallback=$false
    otherMethodBodiesUnchanged=$true;methodHeadersUnchangedExceptCodeLength=$true;constantPoolsUnchanged=$true
    saveAndConfirmationMethodsUnchanged=$true;globalKeyboardAndLauncherUnchanged=$true;gameTextUnchanged=$true
    silentLogoStatusPreserved=$true;silentLogo=$variant.silentLogo
    privateGameContent=$true;selectedForDevice=$false;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Native Encyclopedia Back validation pending','Pause-origin and MainMenu-origin returns require separate native checks','Does not validate save persistence, physical input feel or existing work after the Back callback')
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes,0,$reportBytes.Length)}finally{$reportStream.Dispose()}
Write-Output "Prepared private Encyclopedia Back candidate: $outputPath"
Write-Output "SHA256 $outputHash"
