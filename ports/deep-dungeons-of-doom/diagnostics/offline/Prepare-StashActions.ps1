#Requires -Version 7.0
<# Prepare the private stash action-menu candidate; never install or change a save. #>
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
if(-not ('DDDStashActions' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDStashActions {
    const string InputHash="0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91";
    const string OutputHash="df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804";
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static byte[] Part(byte[] b,int at,int length){byte[] r=new byte[length];Array.Copy(b,at,r,0,length);return r;}
    static byte[] Join(byte[] a,byte[] b){byte[] r=new byte[a.Length+b.Length];a.CopyTo(r,0);b.CopyTo(r,a.Length);return r;}
    static byte[] Splice(byte[] b,int at,int length,byte[] replacement){
        byte[] r=new byte[b.Length-length+replacement.Length];
        Array.Copy(b,0,r,0,at);replacement.CopyTo(r,at);
        Array.Copy(b,at+length,r,at+replacement.Length,b.Length-at-length);return r;
    }
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static void Set24(byte[] b,int at,int value){for(int i=0;i<3;i++)b[at+i]=(byte)(value>>(8*i));}
    public static string Prepare(string inputPath,string outputPath){
        byte[] input=File.ReadAllBytes(inputPath);
        Need(Hash(input)==InputHash,"Unrecognized input; use the accepted skill-tree candidate");
        Need(input.Length==28620982&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");
        Need(BitConverter.ToUInt32(input,27931473)==672914,"Unexpected ABC length");
        int[] ids={4903,4909,4910,4931},positions={28557997,28559087,28559146,28562016},lengths={461,50,4,424},prefixes={213,49,0,322};
        string[] headers={"a72607020a0ccd03","ad2605010a0b32","ae2601010a0b04","c3260704090aa803"},newHeaders={"a72607020a0cff01","ad2605040a0ba303","ae2601010a0b09","c3260704090ae902"},oldHashes={"b0a3232b6fc5acb113a4ef37d71061628ac89b73de0dae9e3f5dfb59d7e20f04","3b6020311d2759f37965f17ad0f1ba0add30995609ed1171245b1bc1797c69b0","d585616625656f7803c9407d288dca461830151e2b66e2009440e239c604ef48","0f07a576d9df8ce533a20829acf717f076061d2390593860f3848a1c210aef5c"},newHashes={"f8a8f35a494767f0470157c85659f6d7cab320868648bb817e203c44d8b72b5e","44a4552f6b7a5b0a44d88a85951242279231c1df9ca51d46655feda5ec6ec03b","f879f9a1d1f8d674ab8be1f86e658202e7b9005957d4988c3d8544f534f5a5a5","bb346647cb2291a53cc8dd60f9ded62c9cab4f7921a256aaf8c8772c01e1c221"};
        // New control instructions only; original navigation/animation prefixes
        // are copied from the hash-verified user-supplied movie.
        string[] tails={"60a90b607266be29469e29011110000060a90b607266b229469e290112090000d0d066ad1e4fb31e0147","d046aa030011680100d06692032405145d0000d0240346870301b2a50e12500100d0240446870301b2a50e12420100d0240346870301d5606ed166ef02d166f0024202d7d32761fa02d324012404a361f8026203620166a70261a7026203620166a80261a802d0d34f82030110010100d0669203240614f70000d066f802240114ed0000d0240546870301b26e12e00000d0240346870301b2a50e12d20000d0240446870301b2a50e12c40000d0240346870301d5d0240446870301d6d0240546870301d760a90b607266b329469e2901119c000060a90b607266c22946a229011134000060a90b607266c42946a229011124000060a90b607266c32946a22901112c000060a90b607266c52946a22901111c0000102c00006203620166a70261a7026203620166a80261a802101400006203620266a70261a7026203620266a80261a80260a90b607266b229469e2901121c0000d366a702d166a70213050000d210010000d1601f66f826264fcb020247","d030d046aa03009648","60a90b607266be29469e29011110000060a90b607266b229469e290112060000d0d14fcb1e0147"};
        byte[][] before=new byte[4][],after=new byte[4][];
        for(int i=0;i<4;i++){
            byte[] header=Convert.FromHexString(headers[i]);
            Need(Convert.ToHexString(Part(input,positions[i],header.Length)).Equals(headers[i],StringComparison.OrdinalIgnoreCase),"Method header guard");
            byte[] code=Part(input,positions[i]+header.Length,lengths[i]);
            Need(Hash(code)==oldHashes[i],"Original method hash");before[i]=Join(header,code);
            byte[] edited=Join(Part(code,0,prefixes[i]),Convert.FromHexString(tails[i]));
            if(ids[i]==4903||ids[i]==4931){
                int alpha=ids[i]==4903?18:6,emptyBranch=ids[i]==4903?209:318;
                // Replace the pulse with a steady quarter-opacity highlight.
                Array.Fill(edited,(byte)0x02,alpha,30);
                Convert.FromHexString("24012404a3").CopyTo(edited,alpha);
                Set24(edited,emptyBranch+1,edited.Length-1-(emptyBranch+4));
            }
            Need(Hash(edited)==newHashes[i],"Prepared method hash");
            after[i]=Join(Convert.FromHexString(newHeaders[i]),edited);
        }
        byte[] result=input;
        for(int i=3;i>=0;i--)result=Splice(result,positions[i],before[i].Length,after[i]);
        Set32(result,4,result.Length);Set32(result,27931473,673020);
        Need(result.Length==28621088&&Hash(result)==OutputHash,"Unexpected candidate bytes");
        byte[] reverse=result;
        for(int i=0;i<4;i++)reverse=Splice(reverse,positions[i],after[i].Length,before[i]);
        Set32(reverse,4,input.Length);Set32(reverse,27931473,672914);
        Need(Hash(reverse)==InputHash,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==InputHash,"Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDStashActions]::Prepare($inputPath,$outputPath)
$report=[ordered]@{
    inputSha256='0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91'
    outputSha256=$outputHash;inputUnchanged=$true;wholeInputRecovered=$true
    methods=@(4903,4909,4910,4931);inputBytes=28620982;outputBytes=28621088
    controls=@{arrows='Select item or visible action';continue='Inspect, then choose Move or Discard';openStats='Inspect';useItem='Switch inventory/chest';back='Close the current panel'}
    nativeActionCallbacksUnchanged=$true;saveMethodsUnchanged=$true
    gameTextAndArtUnchanged=$true;combatAndAudioUnchanged=$true;privateGameContent=$true
    limitation='Prepared PC candidate only. Native action dispatch, rendered review, transfer/discard and save/reload remain unverified while the Brick is disconnected.'
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.Encoding]::UTF8.GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes)}finally{$reportStream.Dispose()}
Write-Output "Prepared private stash candidate: $outputHash"
