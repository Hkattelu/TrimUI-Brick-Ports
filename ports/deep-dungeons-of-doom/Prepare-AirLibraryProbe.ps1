#Requires -Version 7.0
<#
Local compatibility experiment: prepend ActionScript bytecode from a user's
installed AIR extension libraries before the main movie's existing tags.
The output contains purchased content and must never be distributed.
No original file or bytecode is changed. Native extensions are not emulated.
This probe does not import extension asset tags or execute their native code.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameFile,
    [Parameter(Mandatory)][string]$OutputFile,
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Platform = 'Windows-x86'
)
$ErrorActionPreference = 'Stop'
$inputItem = Get-Item -LiteralPath $GameFile
if ($inputItem.PSIsContainer -or $inputItem.Extension -ine '.swf') { throw 'GameFile must be a SWF file from your own installed game.' }
$game = $inputItem.FullName
$output = [IO.Path]::GetFullPath($OutputFile)
if ([IO.Path]::GetExtension($output) -ine '.swf') { throw 'OutputFile must use the .swf extension so game-content exclusions apply.' }
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath ($output + '.json'))) { throw 'Output or its report already exists; select a new private file.' }
$install = Split-Path -Parent $game
if ($output.StartsWith(($install.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Choose a private output directory outside the original game installation.'
}
$outputParent = Split-Path -Parent $output
if (!(Test-Path -LiteralPath $outputParent -PathType Container)) { throw 'Create the private output directory before preparing the probe.' }
Write-Warning 'The output will contain your purchased game and extension bytecode. Keep it private; share only this script and a reviewed error summary.'
$manifest = Join-Path $install 'META-INF/AIR/application.xml'
$readerSettings = [Xml.XmlReaderSettings]::new()
$readerSettings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$readerSettings.XmlResolver = $null
$reader = [Xml.XmlReader]::Create($manifest, $readerSettings)
try { $app = [Xml.XmlDocument]::new(); $app.Load($reader) } finally { $reader.Dispose() }
$ns = [Xml.XmlNamespaceManager]::new($app.NameTable)
$ns.AddNamespace('air', $app.DocumentElement.NamespaceURI)
$extensionIds = $app.SelectNodes('/air:application/air:extensions/air:extensionID', $ns)
if (!$extensionIds.Count) { throw 'The application manifest has no AIR extensions.' }
$before = (Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash

if (-not ('AirLibraryProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Linq;
public static class AirLibraryProbe {
    public sealed class Movie {
        public byte Version;
        public byte[] Body;
        public int HeaderLength;
        public List<Tag> Tags = new List<Tag>();
    }
    public sealed class Tag {
        public int Code;
        public int Start;
        public int Length;
    }
    public static Movie Read(string path) {
        byte[] file = File.ReadAllBytes(path);
        if (file.Length < 12 || file[1] != 'W' || file[2] != 'S') throw new InvalidDataException("Invalid SWF");
        byte[] body;
        if (file[0] == 'F') body = file.Skip(8).ToArray();
        else if (file[0] == 'C') {
            using (var input = new MemoryStream(file, 8, file.Length - 8))
            using (var z = new ZLibStream(input, CompressionMode.Decompress))
            using (var decoded = new MemoryStream()) { z.CopyTo(decoded); body = decoded.ToArray(); }
        } else throw new InvalidDataException("Only FWS and CWS are supported");
        if ((long)body.Length + 8 != BitConverter.ToUInt32(file, 4)) throw new InvalidDataException("SWF size mismatch");
        if (body.Length < 6) throw new InvalidDataException("Truncated movie header");
        int header = (5 + 4 * (body[0] >> 3) + 7) / 8 + 4;
        if (header > body.Length) throw new InvalidDataException("Movie header exceeds file");
        var m = new Movie { Version = file[3], Body = body, HeaderLength = header };
        int p = header;
        while (p < body.Length) {
            int start = p;
            if (p + 2 > body.Length) throw new InvalidDataException("Truncated tag");
            int packed = BitConverter.ToUInt16(body, p); p += 2;
            int size = packed & 63;
            if (size == 63) {
                if (p + 4 > body.Length) throw new InvalidDataException("Truncated long tag");
                uint n = BitConverter.ToUInt32(body, p); p += 4;
                if (n > int.MaxValue) throw new InvalidDataException("Oversized tag");
                size = (int)n;
            }
            if ((long)p + size > body.Length) throw new InvalidDataException("Tag exceeds movie");
            p += size;
            m.Tags.Add(new Tag { Code = packed >> 6, Start = start, Length = p - start });
        }
        return m;
    }
    public static byte[] AbcTags(Movie movie) {
        using (var stream = new MemoryStream()) {
            foreach (var tag in movie.Tags)
                if (tag.Code == 82 || tag.Code == 72) stream.Write(movie.Body, tag.Start, tag.Length);
            return stream.ToArray();
        }
    }
    public static void Write(string output, Movie main, byte[][] additions) {
        var first = main.Tags.FirstOrDefault(t => t.Code == 82 || t.Code == 72);
        if (first == null) throw new InvalidDataException("Main SWF has no ActionScript bytecode");
        using (var file = new FileStream(output, FileMode.CreateNew, FileAccess.Write))
        using (var writer = new BinaryWriter(file)) {
            long total = 8L + main.Body.Length + additions.Sum(a => (long)a.Length);
            if (total > uint.MaxValue) throw new InvalidDataException("Combined SWF is too large");
            writer.Write(new byte[] { (byte)'F', (byte)'W', (byte)'S', main.Version });
            writer.Write((uint)total);
            writer.Write(main.Body, 0, first.Start);
            foreach (byte[] addition in additions) writer.Write(addition);
            writer.Write(main.Body, first.Start, main.Body.Length - first.Start);
        }
        // Check that removing the inserted span restores every original body byte.
        Movie combined = Read(output);
        int inserted = additions.Sum(a => a.Length);
        byte[] recovered = combined.Body.Take(first.Start).Concat(combined.Body.Skip(first.Start + inserted)).ToArray();
        if (!recovered.SequenceEqual(main.Body)) throw new InvalidDataException("Original byte preservation failed");
    }
}
'@
}
$main = [AirLibraryProbe]::Read($game)
$additions = [Collections.Generic.List[byte[]]]::new()
$libraries = @()
foreach ($element in $extensionIds) {
    $id = $element.InnerText
    if ($id -notmatch '^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$') { throw 'Unexpected extension identifier.' }
    $root = Join-Path $install "META-INF/AIR/extensions/$id"
    $library = Join-Path $root "META-INF/ANE/$Platform/library.swf"
    if (!(Test-Path -LiteralPath $library)) { $library = Join-Path $root 'META-INF/ANE/default/library.swf' }
    if (!(Test-Path -LiteralPath $library)) { throw "No library for extension: $id" }
    $bytes = [AirLibraryProbe]::AbcTags([AirLibraryProbe]::Read($library))
    if (!$bytes.Length) { throw "No ABC bytecode in library: $id" }
    $additions.Add($bytes)
    $libraries += [pscustomobject]@{ id=$id; file=$library; sha256=(Get-FileHash -LiteralPath $library -Algorithm SHA256).Hash; abcTagBytes=$bytes.Length }
}
[AirLibraryProbe]::Write($output, $main, $additions.ToArray())
$unchanged = $before -eq (Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash
if (!$unchanged) { throw 'The input file changed during the probe preparation.' }
$record = [ordered]@{ input=$game; inputSha256=$before; inputUnchanged=$unchanged; originalDecompressedBodyPreserved=$true; output=$output; outputSha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash; platform=$Platform; libraries=$libraries; limitations=@('Private derived game file: do not distribute', 'ABC-only preload: extension assets are not imported', 'Native extension calls are not emulated', 'This preparation step does not run or validate gameplay') }
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($output + '.json')
Write-Output "Prepared private AIR library probe: $output"
Write-Output "Extension libraries: $($libraries.Count). Original source and decompressed tag bytes preserved."
