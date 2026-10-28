# Testing matrix

October 28 first-launch preparation: the native ARM64 helper produced the exact
`a2700be5...` output from copied Windows Steam inputs on the original Brick/NX
Redux, in about 4 seconds. Repeat verification took 0.26 seconds. Missing/wrong
inputs, unsupported existing output, concurrent locking, interrupted temporary
files, input/output symlinks (on tmpfs) and input/save preservation passed in
isolated fixtures. The runtime and resulting game movie are unchanged. This
does not add compatibility evidence for any other device or firmware.

Record actual results before claiming device, firmware or display support. This matrix covers the portable `29735ea9...` runtime. On October 27, 2026, after the NX staging correction, Himan confirmed that it starts normally on the original TrimUI Brick with NX Redux, feels even better than the previous build, and has working buttons. This is ordinary-play acceptance with subjective performance feedback, not an FPS measurement. Audio quality, save/reload and in-game Exit were not separately described in this latest feedback. Earlier acceptance of `9df2b904...` remains evidence for that earlier build.

The October 28 movie `a2700be5...` disables the unavailable Trophies and Hi-score buttons. Muted copied-profile checks on the same Brick/runtime verified their appearance, skipped navigation, local Missions and Back. The settled popup also passed a separate cleanup review. The real save was preserved. This menu change has agent validation; the October 27 human acceptance covers its `df2b4af6...` predecessor.

| Device | Firmware | Resolution | Status |
| --- | --- | --- | --- |
| Original TrimUI Brick | NX Redux | 1024×768 | Ordinary startup, playability and buttons accepted by Himan; feels faster. Silent menu/input/Exit/underrun checks also passed. |
| Not yet available | Rocknix (Wayland/Sway, Panfrost or libmali) | Not tested | Not tested |
| Not yet available | muOS (fbdev, libmali) | Not tested | Not tested |
| Not yet available | dArkOS (kmsdrm, current libmali) | Not tested | Not tested |
| Not yet available | Knulli (kmsdrm, libmali) | Not tested | Not tested |
| Not yet available | AmberELEC (legacy libmali) | Not tested | Not tested |

Only the A133P has hardware evidence. RK3326, RK3566, H700, Snapdragon 865/662 and Amlogic S922X are untested. The recommended 640×480, 1280×720 and 720×720 gameplay checks remain open. Resizing catalogue artwork does not validate gameplay at that resolution.

The contribution candidate still needs tests on the relevant supported firmware and hardware combinations and their native resolutions. Record launch, controls, gameplay, audio, save/reload and Exit results for each combination; do not infer a pass from architecture or display size alone.

The Focal runtime also has silent native checks on the original Brick with NX Redux using both NX and catalogue Weston. Menu, Adventure, Back and Exit were exercised with NX Weston; a forced underrun, menu input and Start+Select were exercised with catalogue Weston. Those silent checks establish mechanical coverage only. The later ordinary-play result is recorded above. Other firmware and hardware remain untested.
