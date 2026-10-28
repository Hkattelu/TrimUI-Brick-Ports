#Requires -Version 7.0
<# Prepare the private skill-tree button adaptation; never install or change a save. #>
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
if(-not ('DDDAltarButtons' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Security.Cryptography;
public static class DDDAltarButtons {
    const string InputHash="8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e";
    const string OutputHash="0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91";
    const int TagLength=27931473;
    static string Hash(byte[] b){return Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();}
    static void Need(bool test,string why){if(!test)throw new InvalidDataException(why);}
    static byte[] Part(byte[] b,int at,int length){byte[] r=new byte[length];Array.Copy(b,at,r,0,length);return r;}
    static byte[] Join(byte[] a,byte[] b){byte[] r=new byte[a.Length+b.Length];a.CopyTo(r,0);b.CopyTo(r,a.Length);return r;}
    static void Patch(byte[] b,int at,string oldHex,string newHex){
        byte[] oldBytes=Convert.FromHexString(oldHex),newBytes=Convert.FromHexString(newHex);
        Need(oldBytes.Length==newBytes.Length,"Fixed-width edit");
        Need(at>=0&&at<=b.Length-oldBytes.Length,"Edit bounds");
        for(int i=0;i<oldBytes.Length;i++)Need(b[at+i]==oldBytes[i],"Instruction guard at "+at);
        newBytes.CopyTo(b,at);
    }
    static void Set32(byte[] b,int at,int value){for(int i=0;i<4;i++)b[at+i]=(byte)(value>>(8*i));}
    static void Set24(byte[] b,int at,int value){for(int i=0;i<3;i++)b[at+i]=(byte)(value>>(8*i));}
    static int Read24(byte[] b,int at){int value=b[at]|b[at+1]<<8|b[at+2]<<16;return (value&0x800000)==0?value:value|unchecked((int)0xff000000);}
    static int Mapped(int at){return at+(at>=64?1:0)+(at>=100?1:0);}
    static byte[] Splice(byte[] b,int at,int length,byte[] replacement){
        byte[] r=new byte[b.Length-length+replacement.Length];
        Array.Copy(b,0,r,0,at);replacement.CopyTo(r,at);
        Array.Copy(b,at+length,r,at+replacement.Length,b.Length-at-length);return r;
    }
    public static string Prepare(string inputPath,string outputPath){
        byte[] input=File.ReadAllBytes(inputPath);
        Need(Hash(input)==InputHash,"Unrecognized input; use the preserved accepted attack-fix movie");
        Need(input.Length==28620972&&input[0]=='F'&&input[1]=='W'&&input[2]=='S'&&BitConverter.ToUInt32(input,4)==input.Length,"Unexpected SWF header");
        Need(BitConverter.ToUInt32(input,TagLength)==672904,"Unexpected ABC length");
        int[] positions={28233123,28589082,28589715,28593636};
        int[] lengths={33,623,467,188};
        string[] headers={"f2010101090a21","a42a04120809ef04","a52a06070809d303","cb2a03010809bc01"};
        string[] oldHashes={"ebfa495c536511e62d9ff52ab3da435de2a008a49672535cdc59140c1cabe980","0f4427a5ec2ebd91818bc2d385f630cb915e88fd68a20a6f99a70e31a7dff439","94a8431feed6d97745dd5f8a2704a4a980b6c46e63396bd70d6a1286268ee791","b148d35e2004461071925b44684b8dbdd82ea85b08b8db616db094025c760b46"};
        string[] newHashes={"09ed133eec8a02e8e977fc00f31e048ef3004bc18c66e4b9d8f8a6a44fe6efc1","3b8237fb65081a0bb902eba47cd652b1d5bfc511a8d0675367f7dbe077cf5b4e","e1f908bc2e9d8262e84db355e160b45801896a34d4a40324cdd90e865f515b50","86142a926bb5227fac6c724f1fe8773524565214b653d20e021893cc5a1be6b2"};
        byte[][] before=new byte[4][],after=new byte[4][];
        for(int i=0;i<4;i++){
            byte[] header=Convert.FromHexString(headers[i]);
            Need(Convert.ToHexString(Part(input,positions[i],header.Length)).Equals(headers[i],StringComparison.OrdinalIgnoreCase),"Method header guard");
            byte[] oldCode=Part(input,positions[i]+header.Length,lengths[i]);
            Need(Hash(oldCode)==oldHashes[i],"Original method hash");
            before[i]=Join(header,oldCode);byte[] code=(byte[])oldCode.Clone();
            if(i==0){
                // Retain Stash/WorldMap/MapShop/Encyclopedia and add Altar.
                code=Convert.FromHexString("d030d0b2c301111d0000d0b2bc0111150000d0b2c501110d0000d0b2c70111050000d0b2cc01482648");
                header[header.Length-1]=41;
            }else if(i==1){
                // Enable the existing initial skill selection; consume both comparison operands.
                Patch(code,584,"14120000","29290202");
            }else if(i==2){
                // Enable input unless the HUD has opened a modal this same update.
                // hasSubScene is a method: call it, rather than testing its function object.
                Patch(code,129,"60026692226002669022143b0100","d066e62046aa0300113d01000202");
                // Stats leaves the existing skill scroll target intact.
                Patch(code,150,"11040100","11300100");
            }else{
                Patch(code,47,"66f922","66b229"); // Buy: fresh Continue.
                Patch(code,83,"66cb29","66b229"); // Activate: fresh Continue.
                Patch(code,105,"66c929","66ba29"); // Cycle career: Use Item.
                Patch(code,108,"46a22901","469e2901"); // Fresh press, no repeat.
                Patch(code,161,"66cc29","66be29"); // Character stats: Open Stats.
                byte[] expanded=new byte[code.Length+2];int target=0;
                for(int p=0;p<code.Length;p++){if(p==64||p==100)expanded[target++]=0x47;expanded[target++]=code[p];}
                // False branches skip the inserted return; successful actions consume this HUD update.
                foreach(int branch in new int[]{24,37,55,73,91,112,127,143,168}){
                    Need(oldCode[branch]==0x10||oldCode[branch]==0x11||oldCode[branch]==0x12,"Branch opcode");
                    int destination=branch+4+Read24(oldCode,branch+1);
                    Set24(expanded,Mapped(branch)+1,Mapped(destination)-(Mapped(branch)+4));
                }
                code=expanded;header[header.Length-2]=0xbe;
            }
            Need(Hash(code)==newHashes[i],"Prepared method hash");after[i]=Join(header,code);
        }
        byte[] result=input;
        for(int i=3;i>=0;i--)result=Splice(result,positions[i],before[i].Length,after[i]);
        Set32(result,4,result.Length);Set32(result,TagLength,672914);
        Need(result.Length==28620982&&Hash(result)==OutputHash,"Unexpected candidate bytes");
        byte[] reverse=result;
        for(int i=0;i<4;i++)reverse=Splice(reverse,positions[i],after[i].Length,before[i]);
        Set32(reverse,4,input.Length);Set32(reverse,TagLength,672904);
        Need(Hash(reverse)==InputHash,"Whole-file reverse recovery failed");
        Need(Hash(File.ReadAllBytes(inputPath))==InputHash,"Input changed during preparation");
        using(var stream=new FileStream(outputPath,FileMode.CreateNew,FileAccess.Write))stream.Write(result);
        return Hash(result);
    }
}
'@
}
$outputHash=[DDDAltarButtons]::Prepare($inputPath,$outputPath)
$report=[ordered]@{
    inputSha256='8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e'
    outputSha256=$outputHash;inputUnchanged=$true;wholeInputRecovered=$true
    methods=@(242,5412,5413,5451);inputBytes=28620972;outputBytes=28620982
    controls=@{arrows='Select skill';continue='Buy or activate';useItem='Cycle unlocked careers';openStats='Show career stats';back='Close stats or return to map'}
    globalKeyboardUnchanged=$true;globalPlatformUnchanged=$true;combatUnchanged=$true
    gameTextUnchanged=$true;saveMethodsUnchanged=$true;privateGameContent=$true
    limitation='Preparation and structural verification only. Hardware navigation, transactions, modal routing and save reload require separate checks.'
}|ConvertTo-Json -Depth 5
$reportBytes=[Text.Encoding]::UTF8.GetBytes($report+[Environment]::NewLine)
$reportStream=[IO.File]::Open($outputPath+'.json',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write)
try{$reportStream.Write($reportBytes)}finally{$reportStream.Dispose()}
Write-Output "Prepared private skill-tree candidate: $outputHash"
