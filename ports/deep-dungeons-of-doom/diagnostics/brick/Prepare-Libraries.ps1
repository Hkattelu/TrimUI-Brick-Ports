#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($OutputDirectory)
$source = [IO.Path]::GetFullPath($PSScriptRoot)
$protectedRoot = $source
$ancestor = [IO.DirectoryInfo]::new($source)
while ($ancestor) {
    if (Test-Path -LiteralPath (Join-Path $ancestor.FullName '.git')) { $protectedRoot = $ancestor.FullName; break }
    $ancestor = $ancestor.Parent
}
if ($root.StartsWith($protectedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or $root -eq $protectedRoot) {
    throw 'Keep generated dependencies outside the source checkout or extracted package.'
}
if (Test-Path -LiteralPath $root) { throw 'OutputDirectory must not already exist.' }
if (!(Test-Path -LiteralPath $SevenZip -PathType Leaf)) { throw 'Supply an installed 7-Zip executable.' }
$locked = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'packages.lock.json') -Raw | ConvertFrom-Json)
$total = ($locked | Measure-Object bytes -Sum).Sum
if ($locked.Count -ne 20 -or $total -ne 7093412) { throw 'Unexpected dependency manifest.' }
New-Item -ItemType Directory -Path $root,(Join-Path $root 'downloads') | Out-Null
$records = foreach ($entry in $locked) {
    if ($entry.url -notlike 'https://ports.ubuntu.com/ubuntu-ports/pool/*' -or $entry.sha256 -notmatch '^[0-9a-f]{64}$' -or $entry.package -notmatch '^[a-z0-9][a-z0-9+.-]*$') {
        throw 'Invalid pinned dependency metadata.'
    }
    $archive = Join-Path $root ('downloads/' + [IO.Path]::GetFileName(([uri]$entry.url).AbsolutePath))
    Invoke-WebRequest -Uri $entry.url -OutFile $archive
    if ((Get-Item -LiteralPath $archive).Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $entry.sha256) {
        throw "Downloaded dependency does not match the lock: $($entry.package)"
    }
    $parts = Join-Path $root ('parts/' + $entry.package)
    New-Item -ItemType Directory -Path $parts | Out-Null
    & $SevenZip x $archive ('-o' + $parts) -y | Out-Null
    if ($LASTEXITCODE) { throw "Cannot unpack $($entry.package)" }
    $data = @(Get-ChildItem -LiteralPath $parts -Filter 'data.tar.*' -File)
    if ($data.Count -ne 1) { throw "Expected one payload: $($entry.package)" }
    $entry | Add-Member -NotePropertyName dataArchive -NotePropertyValue ('parts/' + $entry.package + '/' + $data[0].Name) -PassThru
    Write-Host "Verified $($entry.package) $($entry.version)"
}
$records | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'packages.json') -Encoding utf8NoBOM
Write-Output "Prepared $total downloaded bytes in $root. Next run assemble_runtime.py --root with this directory."
