#Requires -Version 7.2
<#
Prepare a private DDD candidate from the supported purchased Windows installation.
The existing source helpers perform every adaptation. This command does not run
the game, prepare a runtime, install on a device, or establish playability.
Keep the output private: it contains the purchased game and AIR bytecode.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GameFile,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('Legacy','AcceptedMenus','StashActions','OfflineMenus')][string]$Candidate = 'OfflineMenus'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (!$IsWindows) { throw 'This candidate preparer requires Windows and PowerShell 7.2 or later.' }

function Get-OrdinaryFullPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    if ($full -notmatch '^[A-Za-z]:\\' -or $full.Substring(2).Contains(':')) {
        throw 'Use ordinary local Windows filesystem paths, without alternate data streams.'
    }
    foreach ($part in $full.Substring(3).Split('\')) {
        if ($part -match '[. ]$') { throw 'Path components must not end in a dot or space.' }
    }
    return $full.TrimEnd('\')
}
function Assert-NoReparse([string]$Path) {
    for ($ancestor = $Path; $ancestor; $ancestor = Split-Path -Parent $ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Use ordinary paths without junctions or symbolic links, including input and source paths.'
        }
    }
}
function Test-Within([string]$Path, [string]$Directory) {
    return $Path.Equals($Directory, [StringComparison]::OrdinalIgnoreCase) -or
        $Path.StartsWith($Directory.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}
function Get-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-CanonicalSourceSha([string]$Path) {
    # Only CRLF is normalized to LF. Strict UTF-8 decoding rejects invalid text;
    # all other characters, including a BOM if present, remain significant.
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $text = $utf8.GetString([IO.File]::ReadAllBytes($Path)).Replace("`r`n", "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($text))).ToLowerInvariant()
}
function Write-NewJson([string]$Path, $Value) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Value | ConvertTo-Json -Depth 8) + "`n")
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$game = Get-OrdinaryFullPath $GameFile
$output = Get-OrdinaryFullPath $OutputDirectory
$package = Get-OrdinaryFullPath $PSScriptRoot
$install = Split-Path -Parent $game
foreach ($path in @($game, $output, $package, $PSCommandPath)) { Assert-NoReparse $path }
$gameItem = Get-Item -LiteralPath $game
if ($gameItem.PSIsContainer -or $gameItem.Extension -ine '.swf') { throw 'GameFile must be the purchased original SWF.' }
if (Test-Path -LiteralPath $output) { throw 'OutputDirectory must be a fresh directory that does not exist.' }
if (!(Test-Path -LiteralPath (Split-Path -Parent $output) -PathType Container)) {
    throw 'The private output parent directory must already exist.'
}
$repository = Get-OrdinaryFullPath (Join-Path $package '../..')
$protectedSource = if (Test-Path -LiteralPath (Join-Path $repository '.git')) { $repository } else { $package }
if ((Test-Within $output $protectedSource) -or (Test-Within $output $package)) {
    throw 'Private output must be outside the source repository or extracted package.'
}
if (Test-Within $output $install) { throw 'Private output must be outside the original game installation.' }
$originalHash = '595142a1136f286e1d76913722b46bf7dd207a5a326fe174170feab90325b4e0'
if ((Get-Sha $game) -cne $originalHash) { throw 'Unrecognized purchased SWF revision; no candidate was prepared.' }

# Fixed chain: name, helper, input parameter, canonical source hash, raw output hash.
$chain = @(
    @('offline','Prepare-OfflineProbe.ps1','GameFile','b86461a17c1dee4ddc5564d8a65e4c4446d85587ed9ec618a4419910bc5da7e3','f50cc4a7e2539b661dc0243377dd8e73617248dde9a4026a550b5be4655bc7d5'),
    @('keyboard-menu','Prepare-KeyboardMenuProbe.ps1','OfflineGameFile','6c493f8640931985851aa3251e3c062654985656b81266238d8e9f0375fb4518','c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7'),
    @('world-map','Prepare-WorldMapButtonsProbe.ps1','KeyboardMenuGameFile','746959ae570e99181e56b73e3f4a398c419eeebb6ec7d935265a7b2611b24b47','28ebdbb520af0613eec692e38c6778b56ce214eaa29ee79187f05bbb461268b5'),
    @('shop-extras','Prepare-ShopExtrasButtonsProbe.ps1','WorldMapGameFile','09d17e7cf4444fab5009155bb9847b70ab20460007798dcceabded76cf6e7523','8fe3cbdee3b93524805bc458d29d24461a6867062e7f4d2fade4ff6b8c755908'),
    @('stash','Prepare-StashButtonsProbe.ps1','ShopExtrasGameFile','0321a579f04e3171f59230698e3c237f0b431ada3a8960fcd0dd69ee6318f4a6','0af8d5d86f306469096a65ba9b43c6e93e47d9337c7826a524790dcb306518d9'),
    @('dungeon-shop','Prepare-DungeonShopButtonsProbe.ps1','StashGameFile','06c9ecad77817d50903d6125f01b6bb3137ff7e8cf74bbe510d1d7d2ca8ef6ea','9a139d21c82e8da6227022d88c87e4afb35183b611d95a1b80573c965406ecd8'),
    @('stash-focus','Prepare-StashFocusProbe.ps1','DungeonShopGameFile','82d6f812aeee918f48f43790a8aad7acadba60a41392a891eb5762dcb1d9bf02','aaca5f5967b41348e116036764a93152921b1c0c321098ef14fc047672631b98'),
    @('local-back','Prepare-LocalBackProbe.ps1','PrivateGameFile','8c49d0028f9ae8bcf0f00a45c31f1d5d73a7663843bfef00355fe792208625c5','6965ee58aedd765408f76c4ccc74f1c5a794c7d8a77d8e3608480fae02b87ce2'),
    @('up-wrap','Prepare-MenuUpWrapProbe.ps1','PrivateGameFile','55f1bfcd7844e4ff6783dbaa468866e90fea3a3a972e787b14f71da59c24b924','dfe37c79e17dc386cba90c7047b208d9a761b8ea173f7a59a4948934d52f1907'),
    @('silent-logo','Prepare-SilentLogoProbe.ps1','KeyboardMenuGameFile','5bbd2d22f7aa1e2ff2325e9b1ee3fce407aefbd8a71f32268c600664658baa4b','27a38d47c908fa03c384f448e8807a9bc75e4f69e731898d4e749a13e394c824'),
    @('encyclopedia-back','Prepare-EncyclopediaBackProbe.ps1','PrivateGameFile','62b8d3092daf426a5a1c29a0f6f2cb5dda72c8234f17e67ff76d604ec41e510b','a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7'),
    @('startup-save','Prepare-StartupSaveProbe.ps1','PrivateGameFile','b6826476be56847c2295440c980c24a064f352d8dc6f46e1274a8b8df8c9466b','c06c703c96cb1a3af5f006f2cb68a11f0d2d31118e5bb4cbd71d6b2951409f8e'),
    @('stash-discard','Prepare-StashDiscardProbe.ps1','FocusGameFile','c2b6ceae47b1012987290d1ceb8068eab4ac3d71021352092132e45db1b35947','7406fc2cb24c5b2faf218797b1d6fcc6690fb8522c6f0bc7daf63853ad141d05')
)
if ($Candidate -ne 'Legacy') {
    $chain += ,@('attack-condition-guard','Prepare-AttackConditionGuard.ps1','PrivateGameFile','4cdeab5be90ba006031a30d38a31cb513658e1239e1d61c1279e2138e428bb16','8952b8ca7b5da2be30c18d6eab2bf33c757a9528d17e6bf6270a6413253c551e')
    $chain += ,@('altar-buttons','Prepare-AltarButtons.ps1','PrivateGameFile','8ba0a7ef083cd7fe744cc59d6b5ce1a05de50ca62fed2d84b8ed261c12087f5d','0dbeb95bea2ad0d64cfb6617a79ff210c15a13183d17e05fc88bcde573fe0b91')
}
if ($Candidate -in @('StashActions','OfflineMenus')) {
    $chain += ,@('stash-actions','Prepare-StashActions.ps1','PrivateGameFile','52d28dd6cc1cf7ee65966f038bc640ab1cb24f8a2f482b73eb8d55322fd782aa','df2b4af61a382e112eab5fd7e02db17f562325068621b6bb598fa0e9e9029804')
}
if ($Candidate -eq 'OfflineMenus') {
    $chain += ,@('offline-extras','Prepare-OfflineExtras.ps1','PrivateGameFile','c0f37427594e8b1811d6653c7c1fcc8a1173f8d3c9c545e53b0269a48caeeefa','a2700be5d4bdc8c7cd2a9443024af2795b4fd40bc13eede4ce3abef25c876d44')
}
$helperPins = @([pscustomobject]@{
    path = 'Prepare-AirLibraryProbe.ps1'; canonicalSha256 = '79a21e17dc15a4b7b17beacc1f6a8dd06d317387ee22cf1f1a41e80a267b19c8'; rawSha256 = ''
})
foreach ($step in $chain) {
    $helperPins += [pscustomobject]@{ path = 'diagnostics/offline/' + $step[1]; canonicalSha256 = $step[3]; rawSha256 = '' }
}
foreach ($pin in $helperPins) {
    $path = Join-Path $package $pin.path
    Assert-NoReparse $path
    if ((Get-CanonicalSourceSha $path) -cne $pin.canonicalSha256) { throw "Source helper differs from the reviewed version: $($pin.path)" }
    $pin.rawSha256 = Get-Sha $path
}

# Inventory only the files the pinned AIR helper will read, in manifest order.
# Its own parser/preloader remains responsible for all game-bytecode adaptation.
$manifest = Join-Path $install 'META-INF/AIR/application.xml'
Assert-NoReparse $manifest
$sourceInputs = @([pscustomobject]@{ path = $game; sha256 = $originalHash })
$sourceInputs += [pscustomobject]@{ path = $manifest; sha256 = Get-Sha $manifest }
$settings = [Xml.XmlReaderSettings]::new()
$settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
$settings.XmlResolver = $null
$reader = [Xml.XmlReader]::Create($manifest, $settings)
try { $application = [Xml.XmlDocument]::new(); $application.Load($reader) } finally { $reader.Dispose() }
$namespaces = [Xml.XmlNamespaceManager]::new($application.NameTable)
$namespaces.AddNamespace('air', $application.DocumentElement.NamespaceURI)
$extensions = $application.SelectNodes('/air:application/air:extensions/air:extensionID', $namespaces)
if (!$extensions.Count) { throw 'The purchased application manifest has no AIR extensions.' }
foreach ($extension in $extensions) {
    $id = $extension.InnerText
    if ($id -notmatch '^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$') { throw 'Unexpected AIR extension identifier.' }
    $libraryRoot = Join-Path $install "META-INF/AIR/extensions/$id/META-INF/ANE"
    $library = Join-Path $libraryRoot 'Windows-x86/library.swf'
    Assert-NoReparse $library
    if (!(Test-Path -LiteralPath $library -PathType Leaf)) { $library = Join-Path $libraryRoot 'default/library.swf' }
    Assert-NoReparse $library
    $sourceInputs += [pscustomobject]@{ path = $library; sha256 = Get-Sha $library }
}

$started = [DateTimeOffset]::Now
$completed = [Collections.Generic.List[object]]::new()
$phase = 'create-output'
New-Item -ItemType Directory -Path $output -ErrorAction Stop | Out-Null
try {
    $stepsDirectory = Join-Path $output 'steps'
    New-Item -ItemType Directory -Path $stepsDirectory -ErrorAction Stop | Out-Null
    $current = $game
    $currentHash = $originalHash
    $number = 0
    foreach ($step in $chain) {
        $number++
        $phase = $step[0]
        $relative = 'steps/{0:D2}-{1}.swf' -f $number, $phase
        $next = Join-Path $output $relative
        $helper = Join-Path $package ('diagnostics/offline/' + $step[1])
        foreach ($path in @($output, $current, $helper)) { Assert-NoReparse $path }
        if ((Get-CanonicalSourceSha $helper) -cne $step[3] -or (Get-Sha $helper) -cne $helperPins[$number].rawSha256 -or (Get-Sha $current) -cne $currentHash) { throw 'A source helper or intermediate changed before use.' }
        if ($number -eq 1 -and (Get-Sha (Join-Path $package 'Prepare-AirLibraryProbe.ps1')) -cne $helperPins[0].rawSha256) { throw 'The AIR helper changed before use.' }
        $arguments = @('-NoLogo','-NoProfile','-NonInteractive','-File',$helper,('-' + $step[2]),$current,'-OutputFile',$next)
        # Fresh processes avoid reusing previously loaded Add-Type implementations.
        & (Join-Path $PSHOME 'pwsh.exe') @arguments 1> ($next + '.stdout.txt') 2> ($next + '.stderr.txt')
        if ($LASTEXITCODE -ne 0) { throw "Preparation step failed: $phase. Private step logs were retained." }
        if ((Get-Sha $current) -cne $currentHash -or (Get-Sha $next) -cne $step[4]) { throw "Unexpected input or output bytes at step: $phase" }
        $report = Get-Content -LiteralPath ($next + '.json') -Raw | ConvertFrom-Json
        if ($report.inputSha256 -ine $currentHash -or $report.outputSha256 -ine $step[4] -or $report.inputUnchanged -ne $true) { throw "Unexpected step report: $phase" }
        $completed.Add([pscustomobject]@{
            step = $phase; file = $relative; sha256 = $step[4]; bytes = (Get-Item -LiteralPath $next).Length
            report = $relative + '.json'; reportSha256 = Get-Sha ($next + '.json')
        })
        $current = $next
        $currentHash = $step[4]
    }
    $phase = 'verify-sources'
    foreach ($source in $sourceInputs) {
        Assert-NoReparse $source.path
        if ((Get-Sha $source.path) -cne $source.sha256) { throw 'A purchased source input changed during preparation.' }
    }
    foreach ($pin in $helperPins) {
        $path = Join-Path $package $pin.path
        Assert-NoReparse $path
        if ((Get-CanonicalSourceSha $path) -cne $pin.canonicalSha256 -or (Get-Sha $path) -cne $pin.rawSha256) { throw 'A source helper changed during preparation.' }
    }
    $phase = 'publish-private-candidate'
    Assert-NoReparse $output
    $candidatePath = Join-Path $output 'ddd.swf'
    [IO.File]::Copy($current, $candidatePath, $false)
    if ((Get-Sha $candidatePath) -cne $chain[-1][4]) { throw 'Final candidate copy failed verification.' }
    Write-NewJson (Join-Path $output 'preparation.json') ([ordered]@{
        status = 'private-candidate-prepared'; startedAt = $started.ToString('o'); finishedAt = [DateTimeOffset]::Now.ToString('o')
        candidate = 'ddd.swf'; candidateVariant = $Candidate; candidateSha256 = $currentHash; candidateBytes = (Get-Item -LiteralPath $candidatePath).Length
        candidateEvidence = $(switch ($Candidate) {
            'OfflineMenus' {'Adds disabled Trophies/Hi-score buttons to StashActions. Muted copied-profile Brick checks verified focus, navigation, Missions and Back with portable runtime 29735ea9...; human feedback on this menu change is pending.'}
            'Legacy' {'Historical movie; predates the accepted combat and menu fixes.'}
            'AcceptedMenus' {'Movie used with runtime 4db2a603... in accepted combat/audio/menu playtests; full-game coverage is not established.'}
            'StashActions' {'Stash actions, transfers, equipment swap, discard, full-chest handling and save/reload passed copied-profile Brick checks with runtime 4db2a603...; installed for private play. Human stash feedback and full-game coverage are not established.'}
        })
        originalUnchanged = $true; sourceInputs = $sourceInputs; helpers = $helperPins; steps = $completed.ToArray()
        helperDigestRule = 'Strict UTF-8 source text with CRLF normalized to LF only; game and asset digests are raw bytes.'
        preparerSha256 = Get-Sha $PSCommandPath; platform = 'Windows'; powershell = $PSVersionTable.PSVersion.ToString()
        privateGameContent = $true; runtimePrepared = $false; installed = $false; runtimeValidated = $false
        limitations = @('Candidate preparation only; this command does not run or validate gameplay.',
            'Generated movies and game-derived reports must remain private.',
            'A compatible runtime, device installation, human playtesting and PortMaster acceptance are separate work.')
    })
    $sumLines = foreach ($file in (Get-ChildItem -LiteralPath $output -File -Recurse | Sort-Object FullName)) {
        Assert-NoReparse $file.FullName
        '{0}  {1}' -f (Get-Sha $file.FullName), ([IO.Path]::GetRelativePath($output, $file.FullName).Replace('\','/'))
    }
    $sumStream = [IO.File]::Open((Join-Path $output 'SHA256SUMS'), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $sumBytes = [Text.UTF8Encoding]::new($false).GetBytes(($sumLines -join "`n") + "`n")
        $sumStream.Write($sumBytes, 0, $sumBytes.Length)
    } finally { $sumStream.Dispose() }
    Write-Output "Prepared private candidate: $candidatePath"
    Write-Output "SHA256: $currentHash"
} catch {
    $failure = $_
    Write-NewJson (Join-Path $output 'failure.json') ([ordered]@{
        status = 'failed'; phase = $phase; completedSteps = $completed.ToArray(); error = $failure.Exception.Message
        privateGameContent = $true; runtimeValidated = $false
    })
    throw $failure
}
