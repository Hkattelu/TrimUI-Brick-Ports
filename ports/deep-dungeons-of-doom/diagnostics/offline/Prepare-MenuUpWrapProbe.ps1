#Requires -Version 7.0
<# Prepare a private diagnostic candidate; does not install, launch or modify its input. #>
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
$expectedInput=(Get-FileHash -LiteralPath $inputPath).Hash.ToLowerInvariant()
$variant=switch($expectedInput){
    '6965ee58aedd765408f76c4ccc74f1c5a794c7d8a77d8e3608480fae02b87ce2' { [pscustomobject]@{name='local-back';extra=0;output='dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907'} }
    '776f7569add97f1507e47e593a415e174334d1976a52e54ce8c7208cc1873b79' { [pscustomobject]@{name='discard-local-back';extra=218;output='1cee961e1aee97345a9547ac0e55d03ad4ba6a6033b594e76ec1bfb5d24301da'} }
    default {throw 'Unrecognized input; use an exact preserved LocalBack candidate.'}
}
if(-not ('DDDMenuUpWrapProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDMenuUpWrapProbe {
    const int Code=28526499,TagHeader=27931471,TagLengthField=27931473;
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static void Require(byte[] b,int at,string hex){byte[] x=Convert.FromHexString(hex);Need(at>=0&&at<=b.Length-x.Length,"Guard outside file");for(int i=0;i<x.Length;i++)Need(b[at+i]==x[i],"Instruction guard at "+at);}
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static byte[] Splice(byte[] b,int at,int oldLength,byte[] replacement){byte[] r=new byte[b.Length-oldLength+replacement.Length];Array.Copy(b,0,r,0,at);Array.Copy(replacement,0,r,at,replacement.Length);Array.Copy(b,at+oldLength,r,at+replacement.Length,b.Length-at-oldLength);return r;}
    static void Container(byte[] b,int code,int extra){
        int at=8+(5+4*(b[8]>>3)+7)/8+4;
        while(at<b.Length){int header=at;ushort h=BitConverter.ToUInt16(b,at);at+=2;int n=h&63;if(n==63){n=checked((int)BitConverter.ToUInt32(b,at));at+=4;}Need(n>=0&&at<=b.Length-n,"Invalid tag");if(code>=at&&code<at+n){Need(header==TagHeader&&(h>>6)==82&&at==TagHeader+6&&n==672594+extra&&code+273<at+n,"Unexpected DoABC container");return;}at+=n;}
        throw new InvalidDataException("Method outside expected DoABC tag");
    }
    public static string Prepare(string inputPath,string outputPath,string expected,string expectedOutput,int extra){
        Need(extra==0||extra==218,"Unsupported predecessor size");
        byte[] input=File.ReadAllBytes(inputPath);Need(Hash(input)==expected,"Input changed before preparation");
        Need(input.Length==28620662+extra&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");
        int code=Code+extra;Container(input,code,extra);
        Require(input,code-8,"ba23070308099102");
        Require(input,code+98,"12110000d02ad566dc1b93d6d1d261dc1b08020801");
        Require(input,code+272,"470000");
        // Add the option count before the existing decrement and uint write.
        // The original modulo, Down branch and callback order remain intact.
        byte[] addition=Convert.FromHexString("d066d51b66bb14a0");
        byte[] result=Splice(input,code+108,0,addition);
        result[code-2]=0x99; // Method code length: 273 -> 281, same U30 width.
        result[code+99]=25; // Existing Up-false branch skips eight added bytes.
        Set32(result,4,result.Length);Set32(result,TagLengthField,672602+extra);
        Need(result.Length==input.Length+8&&Hash(result)==expectedOutput,"Unexpected candidate bytes");
        byte[] recovered=Splice(result,code+108,8,Array.Empty<byte>());
        recovered[code-2]=0x91;recovered[code+99]=17;
        Set32(recovered,4,input.Length);Set32(recovered,TagLengthField,672594+extra);
        Need(Hash(recovered)==expected,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==expected,"Input changed during preparation");
        using(var f=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))f.Write(result,0,result.Length);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDMenuUpWrapProbe]::Prepare($inputPath,$outputPath,$expectedInput,$variant.output,$variant.extra)
$report=[ordered]@{
    sourceVariant=$variant.name;inputSha256=$expectedInput;outputSha256=$outputHash;inputUnchanged=$true
    inputBytes=28620662+$variant.extra;outputBytes=28620670+$variant.extra;growthBytes=8;wholeInputRecovered=$true
    methods=@(4538);oldCodeLengths=@(273);newCodeLengths=@(281)
    scope='Keep Up wrapping to the last ButtonMenu option before storing an unsigned selection'
    downAndCallbackOrderUnchanged=$true;emptyFieldsBehaviorUnchanged=$true;otherMethodBodiesUnchanged=$true
    methodHeadersUnchangedExceptCodeLength=$true;constantPoolsUnchanged=$true
    saveAndConfirmationMethodsUnchanged=$true;globalKeyboardAndLauncherUnchanged=$true;gameTextUnchanged=$true
    privateGameContent=$true;selectedForDevice=$false;runtimeValidated=$false;visuallyValidated=$false;inputValidated=$false
    limitations=@('Native Up-wrap validation pending','Does not fix delayed native key release or catch-up repeats observed during a 161 ms Down tap','Does not validate other menu adaptations or physical input feel')
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.UTF8Encoding]::new($false).GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes,0,$reportBytes.Length)}finally{$reportStream.Dispose()}
Write-Output "Prepared private menu Up-wrap candidate: $outputPath"
Write-Output "SHA256 $outputHash"
