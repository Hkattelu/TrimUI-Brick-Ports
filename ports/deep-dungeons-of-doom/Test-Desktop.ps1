#Requires -Version 7.0
<#
Tests a user-supplied, unchanged Deep Dungeons of Doom SWF in upstream Ruffle.
This is a compatibility probe, not a working port or a Steam replacement.
Downloads only the open-source runtime. Never copies or patches game content.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameFile,
    [string]$WorkDirectory = (Join-Path $PSScriptRoot '.work'),
    [switch]$PrepareOnly,
    [switch]$Interactive,
    [ValidateRange(1, 60)][int]$SmokeSeconds = 15
)
$ErrorActionPreference = 'Stop'
$game = (Get-Item -LiteralPath $GameFile).FullName
if ([IO.Path]::GetExtension($game) -ine '.swf') { throw 'GameFile must be a SWF from your own game installation.' }
$work = [IO.Path]::GetFullPath($WorkDirectory)
$runtime = Join-Path $work 'runtime/nightly-2026-10-24'
$archive = Join-Path $work 'ruffle-nightly-2026_10_24-windows-x86_64.zip'
$expected = '561d147e4973e717a8b803e604e64289ecad7398c5ab15419567bbd1bccc9866'
$url = 'https://github.com/ruffle-rs/ruffle/releases/download/nightly-2026-10-24/ruffle-nightly-2026_10_24-windows-x86_64.zip'
$exe = Join-Path $runtime 'ruffle.exe'
New-Item -ItemType Directory -Force -Path $work | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri $url -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $expected) {
    throw 'Ruffle download checksum mismatch. No executable was launched.'
}
# Refresh the portable executable from the verified archive on each invocation.
Expand-Archive -LiteralPath $archive -DestinationPath $runtime -Force
$runId = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$run = Join-Path $work "runs/$runId"
New-Item -ItemType Directory -Force -Path $run | Out-Null
$beforeHash = (Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash.ToLowerInvariant()
$arguments = @(
    '--player-runtime', 'air',
    '--config', (Join-Path $run 'config'),
    '--cache-directory', (Join-Path $run 'cache'),
    '--save-directory', (Join-Path $work 'saves'),
    '--storage', 'disk',
    '--width', '1024', '--height', '768',
    '--tcp-connections', 'deny', '--open-url-mode', 'deny',
    '--filesystem-access-mode', 'deny',
    '-B', 'left-trigger=left', '-B', 'right-trigger=right',
    '-B', 'd-pad-up=up', '-B', 'd-pad-down=down',
    '-B', 'd-pad-left=left', '-B', 'd-pad-right=right',
    '-B', 'south=return', '-B', 'east=escape',
    '-B', 'west=space', '-B', 'north=c',
    '-B', 'start=return', '-B', 'select=escape'
)
if (!$Interactive) { $arguments += @('--volume', '0') }
$arguments += $game
$record = [ordered]@{
    runtime = 'Ruffle nightly-2026-10-24'
    runtimeArchiveSha256 = $expected
    gameSha256 = $beforeHash
    arguments = $arguments
    preparedOnly = [bool]$PrepareOnly
    interactive = [bool]$Interactive
    status = 'prepared'
}
$recordPath = Join-Path $run 'result.json'
if ($PrepareOnly) {
    $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $recordPath
    Write-Output "Prepared: $run"
    return
}
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $exe
$info.UseShellExecute = $false
$info.WorkingDirectory = Split-Path -Parent $game
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.Environment['RUST_LOG'] = 'info'
$info.Environment['RUST_LOG_STYLE'] = 'never'
if (!$Interactive) {
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.CreateNoWindow = $true
}
foreach ($arg in $arguments) { $info.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::Start($info)
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
try {
    if ($Interactive) { $process.WaitForExit() }
    elseif (!$process.WaitForExit($SmokeSeconds * 1000)) {
        $record.status = 'smoke-time-limit'
        [void]$process.CloseMainWindow()
        if (!$process.WaitForExit(3000)) { $process.Kill(); $process.WaitForExit() }
    }
    $record.exitCode = $process.ExitCode
    if ($record.status -eq 'prepared') { $record.status = 'exited' }
} finally {
    # Only the process started above is ever stopped; unrelated games stay open.
    if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $run 'stdout.log')
    $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $run 'stderr.log')
    $record.gameUnchanged = ((Get-FileHash -LiteralPath $game -Algorithm SHA256).Hash -ieq $beforeHash)
    $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $recordPath
    $process.Dispose()
}
Write-Output "Probe finished: $run"
Write-Output 'A running process or zero exit code does not establish playability. Inspect the logs and game.'
