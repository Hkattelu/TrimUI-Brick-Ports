# Path to a PortMaster release

The current contribution candidate is under `portmaster/portable/`. It uses firmware core libraries, SDL and EGL, with WestonPack supplied separately. Players prepare their own purchased Windows game files; no Steam client is needed on the handheld. The player archive contains no purchased game or player profile.

The local portable player ZIP is 17,005,986 bytes, SHA256 `4e304fd5e670569d93bce37b604a9144b3b7b4d7e29da9ff590f5636a6a9cb3f`. It contains 641 entries, eight ELF files, three native packages and 540 flat license files. The separate source ZIP is 21,502,782 bytes, SHA256 `0ccb49f29b1f9f0f1a474bcf734563ea56da1f3b68b5792cf1f6fed0831628f6`. It contains 52 files, including three native source packages and eight locked crates. All source archive hashes and 1,006 notice sections were verified.

Actual archive checks passed, including private-content exclusion and preservation of the game, profile, backups and settings during updates. Save-import checks passed for both runtime identities, and launcher fixtures passed. The upstream reader and packager matched all 641 files with zero errors and one generic warning for the internal run-game.sh helper.

The candidate uses the same `29735ea9...` runtime and helpers as the silent Brick tests. Those checks covered menu, Adventure, input, Exit and a forced audio underrun on the original Brick with NX Redux. After the NX staging correction described below, Himan confirmed ordinary startup, reported that the portable build feels even better than before, and said all buttons seem to work. This is user acceptance of playability and controls on that device, with a subjective performance improvement. The latest feedback did not separately describe audio quality or save/reload. The earlier `9df2b904...` installation and its original profile remain preserved.

The older launcher and archives bundled core libraries and are historical evidence, not the current portable route. See [host validation](portmaster/HOST-VALIDATION.md) and the [testing matrix](portmaster/TESTING-MATRIX.md) for scope.

## Current menu revision

The October 28 movie `a2700be5...` disables unavailable Trophies and Hi-score buttons. Its muted Brick checks preserved local Missions and the real save. Human play acceptance above covers the predecessor `df2b4af6...`. The latest archive also adds the developer thank-you requested by the packaging guide; its runtime and game preparation are unchanged from the installed menu fix.

## Remaining work

- Test other relevant firmware, devices and resolutions. The original Brick/NX Redux ordinary-play check passed; keep specific audio and save/reload results distinct from the general playtest feedback.
- Assess the offline bootstrap change against PortMaster's explicit prohibition on DRM bypass and Steam-emulation tooling. The change removes the exit on failed Steam initialization while leaving the successful-initialization ownership branch unchanged. This description does not establish policy acceptance or a legal conclusion.
- Review the draft with Himan, and establish corresponding source links alongside any later approved binary. Maintainer review and catalogue acceptance remain open.

Use the [community testing guide](portmaster/TESTER-GUIDE.md) to recruit volunteers and collect reproducible reports. The merged Fancy Pants AIR/SWF port is relevant precedent, but DDD still needs its own policy answer. Ask in the official Discord testing channel before arranging build distribution. After documented community testing and Himan's review, prepare a draft PR containing only this port, with corresponding source links beside the binary.

No pull request, upload or publication has occurred. The local archives remain unpublished.

The earlier portable candidate was installed separately for ordinary-play review. Tools → DDD PortMaster Test now points to that candidate, which received a verified copy of the latest profile. The first user launch exited immediately because the private NX installer used the wrong layout. After correcting it, the normal Tools entry reached the main menu, accepted injected A-button input and returned to NX via Start+Select in a silent disposable-profile check. Both profiles were unchanged by that diagnostic run. Himan then played the normal candidate and confirmed the improved behavior above. The candidate profile may now contain newer progress and must be backed up before any future installation change. The matrix and updated contents record were copied to the isolated installation before this playtest; the local source records now include the human result.
