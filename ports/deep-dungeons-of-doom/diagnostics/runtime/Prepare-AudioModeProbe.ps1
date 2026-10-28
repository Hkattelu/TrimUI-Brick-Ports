#Requires -Version 7.0
<#
Prepends an original-source AudioPlaybackMode enum to a private window-hint
probe. Every byte of the input body is retained. This output contains purchased
game content and must never be redistributed. The enum uses the documented AIR
ambient/media/voice constants; desktop audio modes have no functional difference.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameFile,
    [Parameter(Mandatory)][string]$EnumLibraryFile,
    [Parameter(Mandatory)][string]$OutputFile
)
$ErrorActionPreference='Stop'
function Assert-NoReparseAncestor([string]$Path) {
    for($ancestor=$Path;$ancestor;$ancestor=Split-Path -Parent $ancestor){
        if((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            throw 'Use ordinary private paths without junctions or symbolic links.'
        }
    }
}
$game=(Get-Item -LiteralPath $GameFile).FullName
$library=(Get-Item -LiteralPath $EnumLibraryFile).FullName
$output=[IO.Path]::GetFullPath($OutputFile)
Assert-NoReparseAncestor $game
Assert-NoReparseAncestor $library
Assert-NoReparseAncestor $output
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')).TrimEnd('\','/')
$repoCandidate=[IO.Path]::GetFullPath((Join-Path $sourceRoot '../..')).TrimEnd('\','/')
$protectedSource=if(Test-Path -LiteralPath (Join-Path $repoCandidate '.git')){$repoCandidate}else{$sourceRoot}
if($output -ieq $protectedSource -or $output.StartsWith($protectedSource+'\',[StringComparison]::OrdinalIgnoreCase)){
    throw 'Private game output must be outside the source repository or extracted package.'
}
$expectedGame='309bd8f8a9512444d5786437a4746b81ac0b28b8f2c6c9e2bb8ed2094e5397cf'
$expectedLibrary='c6ea5e877c562fb5b2ea89229484c93455902b9f55d4da8845efeaa9326633d2'
if((Get-FileHash -LiteralPath $game).Hash -ine $expectedGame){throw 'Expected the exact verified window-hint probe.'}
if((Get-FileHash -LiteralPath $library).Hash -ine $expectedLibrary){throw 'Expected the exact original-source AudioPlaybackMode library.'}
if([IO.Path]::GetExtension($output) -ine '.swf'){throw 'Output must retain the private .swf extension.'}
if((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath ($output+'.json'))){throw 'Output or report exists; choose a new private path.'}
$inputDirectory=(Split-Path -Parent $game).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if($output.StartsWith($inputDirectory,[StringComparison]::OrdinalIgnoreCase)){throw 'Use a separate private output directory.'}
if(-not ('DDDAudioModeProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
public static class DDDAudioModeProbe {
    public sealed class Tag {public int Offset,Size,Type;}
    static List<Tag> Tags(byte[] b) {
        if(b.Length<12 || b[0]!='F' || b[1]!='W' || b[2]!='S' || BitConverter.ToUInt32(b,4)!=b.Length)
            throw new InvalidDataException("Expected a complete uncompressed SWF");
        int p=8+(5+4*(b[8]>>3)+7)/8+4;
        var tags=new List<Tag>();bool ended=false;
        while(p<b.Length){
            int start=p;if(p+2>b.Length)throw new InvalidDataException("Truncated tag");
            int h=BitConverter.ToUInt16(b,p);p+=2;int n=h&63;
            if(n==63){if(p+4>b.Length)throw new InvalidDataException("Truncated size");n=checked((int)BitConverter.ToUInt32(b,p));p+=4;}
            if((long)p+n>b.Length)throw new InvalidDataException("Tag exceeds input");
            tags.Add(new Tag{Offset=start,Size=p+n-start,Type=h>>6});p+=n;
            if((h>>6)==0){if(n!=0 || p!=b.Length)throw new InvalidDataException("Invalid end tag");ended=true;}
        }
        if(!ended)throw new InvalidDataException("Missing end tag");return tags;
    }
    public static int[] Prepare(string game,string library,string output){
        byte[] input=File.ReadAllBytes(game),lib=File.ReadAllBytes(library);
        Tag main=Tags(input).Single(t=>t.Type==82),extra=Tags(lib).Single(t=>t.Type==82);
        byte[] result=new byte[input.Length+extra.Size];
        Buffer.BlockCopy(input,0,result,0,main.Offset);
        Buffer.BlockCopy(lib,extra.Offset,result,main.Offset,extra.Size);
        Buffer.BlockCopy(input,main.Offset,result,main.Offset+extra.Size,input.Length-main.Offset);
        Buffer.BlockCopy(BitConverter.GetBytes((uint)result.Length),0,result,4,4);
        // Removing the inserted tag and restoring the eight-byte header must
        // reproduce the entire input file, not just its executable instructions.
        byte[] restored=new byte[input.Length];
        Buffer.BlockCopy(result,0,restored,0,main.Offset);
        Buffer.BlockCopy(result,main.Offset+extra.Size,restored,main.Offset,input.Length-main.Offset);
        Buffer.BlockCopy(input,0,restored,0,8);
        if(!restored.SequenceEqual(input))throw new InvalidDataException("Input preservation failed");
        if(Tags(result).Count(t=>t.Type==82)!=2)throw new InvalidDataException("Unexpected output ABC count");
        using(var stream=new FileStream(output,FileMode.CreateNew,FileAccess.Write))stream.Write(result,0,result.Length);
        return new[]{main.Offset,extra.Size};
    }
}
'@
}
$insertion=[DDDAudioModeProbe]::Prepare($game,$library,$output)
if((Get-FileHash -LiteralPath $game).Hash -ine $expectedGame -or (Get-FileHash -LiteralPath $library).Hash -ine $expectedLibrary){throw 'Input changed during preparation.'}
[ordered]@{
    inputSha256=$expectedGame;enumLibrarySha256=$expectedLibrary
    outputSha256=(Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()
    insertedTagFileOffset=$insertion[0];insertedTagBytes=$insertion[1]
    originalBodyPreserved=$true;removingInsertionRestoresInputExactly=$true
    inputUnchanged=$true;steamAndEntitlementInstructionsUnchanged=$true
    compatibilityClasses=@('flash.media.AudioPlaybackMode')
    constants=[ordered]@{AMBIENT='ambient';MEDIA='media';VOICE='voice'}
    privateGameContent=$true;runtimeValidated=$false
}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath ($output+'.json')
Write-Warning 'Private derived game content: do not distribute the SWF.'
Write-Output $output
