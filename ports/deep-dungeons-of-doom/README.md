# Deep Dungeons of Doom on TrimUI Brick

This is a compatibility experiment for a locally supplied, purchased copy of
Deep Dungeons of Doom on the original TrimUI Brick with NX Redux and PortMaster.
The player has accepted combat responsiveness, audio, quick quit, the skill tree,
Encyclopedia and Options after successive private playtests.
Full-game compatibility and clean installation for other players remain unverified.
The selected route uses ARM64 Ruffle and the existing PortMaster display runtime.
It requires no Steam client on the Brick.

## Current status — October 26, 2026

The stash information panel now exposes the game's Move and Discard buttons,
with steady selection feedback. [Native checks](diagnostics/offline/STASH-ACTIONS.md)
passed transfers both ways, equipment swapping, discard cancel/confirm,
full-chest handling and save/reload on a disposable profile. The requested bounded
ordinary-play and separate rendered cleanup passes are complete. The revision is
installed in Tools → DDD Play Test with normal audio and the unchanged human save;
Himan has not yet given feedback on this stash revision.

The installed movie is `df2b4af6...`, using accepted runtime `4db2a603...`.
[Menu coverage](diagnostics/offline/MENU-COVERAGE.md) records the automated checks
and subsequent human acceptance for the earlier `0dbeb95b...` menu movie. The
one-command movie preparer now defaults to the Brick-tested stash revision;
the previous variants remain available for comparisons. Runtime installation
and catalogue packaging remain separate release work. The private-install helper
now supports the accepted runtime and current movie, with normal audio; its new
output still needs installation testing on the Brick.
No PortMaster submission or publication has occurred.

## Earlier compatibility work

The following observations describe earlier builds and are retained as diagnostic
history. Later human acceptance above supersedes their lag, static and quit issues.

The first human playtest used combined movie `7406fc2c...` and runtime
`b381ea22...`. Himan reported: “Everything seems to work great. The only problem
is that its a bit laggy and theres no audio.” The retained run log records Sewer
victory, rewards and the following cutscene. This confirms the scope of that
play session; it does not establish exhaustive menu or later-game coverage.

During 78.782 seconds of combat, 611 update loops averaged 114.303 ms in the
game tick, 5.654 ms in movie composition and 8.066 ms in frontend rendering.
Input polling averaged 0.287 ms and never reached the bounded drain limit.
These are overlapping CPU-side wall times, not presented FPS. The dominant
remaining cost is inside the game tick, which includes Starling's Stage3D work.
That first human build deliberately uses NullAudio after earlier inaudible hardware
tests. These observations guide the next performance and audio diagnosis.

The October 26 follow-up used the constant-ring renderer. Himan reported a clear
improvement and fairly responsive controls, reaching the next dungeon's final
boss, but still found menu and floor transitions choppy and the silence
unsatisfactory. This is partial progress, not acceptance of overall playability.
The final return from the loss screen ended in a confirmed kernel out-of-memory
kill. Ten obsolete diagnostic staging folders occupied about 459 MiB in the
RAM-backed `/tmp`; they have now been copied to the SD card, verified and removed
from RAM. Available memory rose from 272 to 731 MiB. The next play session must
check the transitions and exit again with that avoidable pressure removed.
The next untimed session confirmed audible music and sound through normal
PortMaster routing. Himan finds it much better with audio, but still reports lag,
bursts of static and no visible selection on the dungeon-entry Back/Go buttons.
The log records two ALSA POLLERR errors; their relationship to the static is not
yet established. This remains partial progress, not acceptance of sound quality.

Start+Select did not quit that session: the recorded short Select taps while
Start was held did not meet the helper's 800 ms hold requirement. The session
was recovered by signaling only the verified DDD process. NX returned and all
461 ordinary installation entries passed. A revised press-based chord helper
passes host and native disposable-process checks and a silent ordinary-launcher
check with a copied profile. The guarded short chord returned to NX and restored
all baseline files. The untimed Tools → DDD Play Test candidate now includes it,
with the latest human save backed up and unchanged. Physical use remains to be
confirmed. Home is not currently wired to quit.

A later [selective buffer-barrier experiment](diagnostics/runtime/ruffle-stage3d/SELECTIVE-BARRIERS.md)
passed the native ordering fixture and preserved the rendered title. Most of its
upload-time reduction moved to presentation, leaving only a small total-loop
improvement. It remains separate from the installed player candidate; the lag
report is still open.

The subsequent [merged render-pass experiment](diagnostics/runtime/ruffle-stage3d/MERGED-PASSES.md)
passed an expanded 26-pixel fixture in both modes. A same-binary title comparison
reduced measured main-loop wall time from 33.521 to 26.378 ms, with identical
captured images and clean returns to NX. This supports a normal-play trial;
it does not yet establish smoother combat or fix audio static.
The ordinary-launcher smoke then resumed a copy of the latest dungeon save,
rendered Pause and exited with the short Start+Select chord. NX returned and
all 461 baseline manifest entries were restored. The new renderer is now armed
in the untimed Tools playtest with original audio and the latest human save
preserved. Physical feedback is pending. Ten underruns and one POLLERR in the
muted real-audio smoke provide a lead for the remaining static investigation.

The table below retains the earlier focused checks and their remaining limits.

| Area | Evidence and remaining work |
| --- | --- |
| Rendering | Actual title, main menu and first dungeon inspected on the Brick. Logo color bands correspond to an intentional game effect. |
| Combat and exit | Automated checks defeated the practice dummy, accepted the priest's healing choice and displayed BLOCKED feedback. The subsequent physical playtest completed the Sewer; the player reported lag but no control problem. Holding Start+Select for 800 ms quit an earlier owned run and returned to NX Redux. |
| Button-only menus | The pipeline-cache/Up-wrap candidate passed six short direction taps, wraparound and hold-release checks on Pause and the main menu. The Encyclopedia Back correction returned to Pause and resumed the dungeon; Exit Dungeon cancellation also passed. The latest combined candidate includes these changes and the discard route. Adapted map, shop, extras, stash and discard controls still need their native checks. |
| Saves | The ARM64 runtime passed the save-reference regression. The startup-save correction preserved the 92.45-second checkpoint through two no-movement launches and saved 169.12 seconds after an ordinary floor move. Player values and all 32 reference aliases remained intact. The combined candidate later recorded a normal death and retained completed tutorial flags. These trials used separate profiles and preserved the ordinary save. Nonempty inventory and later progression remain unverified. |
| Normal launcher | The ordinary entry is installed and launched through NX's existing Ports wrapper. The updated quit handling returned the actual termination status 143 on the Brick, restored NX and released owned processes, sockets and the Weston mount. |
| Input performance | Short taps repeated with the older ordinary runtime. A frame probe localized most cost to Starling rendering. The pipeline-cache candidate recorded lower render times and passed focused short-tap checks; disabling the cache restored long render times. Varying CPU limits prevent a precise speedup claim. The human-play build uses this candidate and is still noticeably laggy. |
| Audio | The ordinary follow-up with normal PortMaster routing and standard application volume is audible, confirmed by the user. Music improves play, but intermittent static remains. |

USB reconnected and the isolated ARM save regression passed on October 25.
The combined startup-save/discard build was used for human play with a separate
retained profile and no session timer. Preserve the player's new progress.
Feedback guides the next gameplay and menu checks; further timed combat
automation is stopped. Earned-item persistence and remaining adapted menus
still need review.
Screenshots and clean logs cannot
establish physical control feel, sound quality or full-game compatibility.

## Where to continue

- [Controls and their validation limits](CONTROLS.md)
- [Path to a PortMaster package](PORTMASTER-PLAN.md)
- [Prepare the current game candidate from an owned copy](PREPARE-GAME.md)
- [Private installation preparation](PRIVATE-INSTALL.md)
- [Ordinary launcher and focused checks](launcher/README.md)
- [Verified gameplay milestone](diagnostics/offline/GAMEPLAY-MILESTONE.md)
- [Early checkpoint and reload evidence](diagnostics/offline/CHECKPOINT-RELOAD.md)
- [Startup checkpoint correction and repeated reload checks](diagnostics/offline/STARTUP-SAVE.md)
- [WorldMap button adaptation](diagnostics/offline/WORLD-MAP-BUTTONS.md)
- [Separate shop and extras button candidate](diagnostics/offline/SHOP-EXTRAS-BUTTONS.md)
- [Separate stash button candidate](diagnostics/offline/STASH-BUTTONS.md)
- [Guarded dungeon-shop controls](diagnostics/offline/DUNGEON-SHOP-BUTTONS.md)
- [Stash selection correction](diagnostics/offline/STASH-FOCUS.md)
- [Separate discard confirmation candidate](diagnostics/offline/STASH-DISCARD.md)
- [Encyclopedia Back correction and native check](diagnostics/offline/ENCYCLOPEDIA-BACK.md)
- [Save-reference fix and ARM build](diagnostics/runtime/ruffle-amf/README.md)
- [Separate input timing candidate](diagnostics/runtime/ruffle-input/README.md)
- [Pipeline-cache candidate and native comparison limits](diagnostics/runtime/ruffle-stage3d/README.md)
- [Constant-ring renderer candidate and title comparison](diagnostics/runtime/ruffle-stage3d/CONSTANT-RING.md)
- [Controller and deferred audio findings](diagnostics/offline/CONTROLLER-AUDIO.md)

## Local preparation and source package

The [current candidate preparer](PREPARE-GAME.md) runs the full movie-preparation
chain on Windows with one command, checks every intermediate result and retains
the private outputs. It does not install a runtime or prepare the Brick.

The individual steps remain available for diagnosis. Start with the
[AIR-library preparer](Prepare-AirLibraryProbe.ps1), which reads
the installed manifest and extension libraries from the purchased game. The
[offline startup preparer](diagnostics/offline/README.md),
[ButtonMenu preparer](diagnostics/offline/KEYBOARD-MENU.md) and WorldMap preparer
then make separate, hash-checked private outputs. Each adaptation has a narrow
recorded purpose; none overwrites the original installed movie.

For the combined candidate, follow WorldMap preparation with the shop/extras,
stash, guarded DungeonShop and stash-focus helpers, in that order. Each accepts
only the recorded outputs of its predecessor. Preserve the intermediate files
for comparison. Later Back, Up-wrap, Encyclopedia and startup-save corrections
have their own exact input requirements, documented in the links above. The
discard helper also accepts the startup-save output and reproduces the final
combined movie used for human play. Its adapted menus still need device checks.
The [private installer preparer](PRIVATE-INSTALL.md) now accepts this final movie
with the tested pipeline-cache runtime and reproduces its silent playback and
controller settings. The generated ordinary installation still needs its native
startup/reload check; movie preparation alone does not install it.

The offline adaptation permits the game's existing local achievement/score
fallback when native initialization fails. Its separate ownership-failure branch
is unchanged. The earlier Windows Steam diagnostics are historical compatibility
evidence, not the Brick architecture. Details remain in
[native-extension diagnostics](diagnostics/README.md) and
[runtime experiments](diagnostics/runtime/README.md).

`Prepare-PrivateInstall.ps1` combines a recognized private movie, locally built
ARM64 helpers, a reviewed runtime/dependency report and portable libraries into
a new folder. It writes an integrity manifest and can copy a complete inactive
save profile. It does not contact the Brick. See the private preparation guide
before using it; preparation is not hardware validation.

To build the source archive with PowerShell 7:

```powershell
./Build-Package.ps1 -OutputDirectory C:/private-tests/ddd-source-package
```

The explicit allowlist includes original preparation/launcher code, original
test-fixture sources, identified runtime patches, documentation and license
texts. It excludes game SWFs, game assets, decompiled game code, AIR/Steam
libraries, compiled runtimes, logs and saves. The builder refuses to replace an
existing archive and writes a manifest of its entries and digests.

Keep generated game files and the entire prepared private installation private.
The project's license grants no rights to redistribute the game. This is an
unofficial compatibility project, with no claim of legal clearance or PortMaster
acceptance. The game and its trademarks belong to their respective owners.

The intended eventual route is a bring-your-own-game PortMaster package so other
owners can use the compatibility work. PortMaster documents engines/runners using
original game data in its [porting guide](https://portmaster.games/porting.html).
Its [packaging and testing requirements](https://portmaster.games/packaging.html)
remain future work after Brick compatibility: this source archive is not a
catalog-ready package, and no submission or community acceptance is claimed.

## Pinned foundations

- [Ruffle nightly-2026-10-24](https://github.com/ruffle-rs/ruffle/releases/tag/nightly-2026-10-24), source commit `159d7dbbca40bd475c8693df011b3dbf66213844`.
- [Isolated Brick runtime assembly](diagnostics/brick/README.md), using the existing PortMaster Weston runtime.
- [Earlier Stage3D fixture](diagnostics/stage3d/README.md); its clear-only black frame is distinct from the subsequently rendered DDD gameplay.
- [Buy the game on Steam](https://store.steampowered.com/app/325090/Deep_Dungeons_of_Doom/).
