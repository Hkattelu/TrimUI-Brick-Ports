# RG34xxSP / Knulli input investigation

October 29, 2026. Community report from real_draxd: the game starts on Knulli
Gladiator II on an RG34xxSP, but input does not work. The supplied `log.txt`
identifies Westonwrap 0.2.7.1, a 720×480 display and the Anbernic RG34XX-SP
controller. The separate Ruffle `runtime.log` was not supplied.

## Confirmed launcher defect

The log expands `GPTOKEYB` to the legacy helper with `-1`, while `GPTOKEYB2`
names the newer helper and its firmware-provided interpose preload. The old
launcher invoked `$GPTOKEYB ruffle -x`. Legacy gptokeyb accepts the literal
argument `xbox360`; it silently ignores `-x`. The process can run as a quit helper
without creating a virtual controller. The earlier Brick path happened to use
native Gilrs input successfully.

Verified against official source:

- [gptokeyb 5b1284e](https://github.com/PortsMaster/gptokeyb/blob/5b1284e1502548d476aa38e5979b0a8f48cb7b94/src/gptokeyb.cpp), argument parsing and device creation.
- [gptokeyb2 647b46f](https://github.com/PortsMaster/gptokeyb2/blob/647b46f4c49ea7d379fc67126bbfe2910d83e2d9/src/main.c), `-x` parsing and fake Xbox setup.
- [PortMaster's legacy helper documentation](https://portmaster.games/gptokeyb-documentation.html).

## Correction in v0.1.1

Knulli uses `$GPTOKEYB2 ruffle -x`, preserving the complete firmware command,
including its preload and quit flags. If GPTOKEYB2 is absent, it uses
`$GPTOKEYB ruffle xbox360`. Other firmware keeps the working native-input path.

`CRUSTY_BLOCK_INPUT=1` is set in `run-game.sh` for the virtual-pad route, after
Weston has started. The helper must still see the physical controller, and
Weston must still see its input devices. The shipped Weston 0.2.7.1 wrapper
preloads `libcrusty.so` before Ruffle starts. Inspection of that library's
constructor, `open`/`open64` hooks and `inputblock_open` shows that the filter
admits `Microsoft X-Box 360 pad` and fake keyboard devices while rejecting the
original physical controller. Native mode explicitly disables this filter.
This binary inspection is not an ARM execution test.

The existing 256 KiB runtime log now includes Gilrs initialization messages and
Ruffle application warnings. It does not enable per-frame or per-button logging.

## Focused validation

The isolated Linux fixture creates a uinput controller with the reported SDL
GUID and mapping. Its kernel button layout is synthetic; it does not reproduce
the RG34xxSP kernel driver, permissions, firmware SDL build or graphics stack.
The official helper sources above were compiled for x86-64 against SDL 2.26.
The receiver uses Gilrs 0.11.2 / gilrs-core 0.6.8, matching the shipped runtime.

| Case | Result |
| --- | --- |
| Legacy helper with the original `-x` argument | No virtual pad created; reproduced the launcher defect. |
| Legacy helper with `xbox360` | Virtual pad created; all expected button edges delivered. |
| New helper with `-x` and its interpose library | Virtual pad created; all expected button edges delivered. |
| Direct Gilrs with the reported SDL mapping | Events delivered on the synthetic controller; no mapping-parser failure reproduced. |
| Launcher fixture | Firmware selection, overrides, complete helper commands, child-only filter setting, save preservation and cleanup passed. |

For each corrected helper route, the receiver saw one press and one release for
each D-pad direction, each face button, and L/R. Five additional rapid confirm
taps also arrived: 15 presses and 15 releases total. Both physical and virtual
devices were visible in this host test; only virtual-device events were counted.
Duplicate suppression was checked through launcher environment tests and the
shipped filter's implementation, not through this host event count.

The actual player ZIP is separately checked for pinned binary hashes, archive
contents, corresponding sources and preservation of game data, settings and saves.
The Ruffle binary and prepared game are unchanged from v0.1.0.

## Tester follow-up

Later on October 29, the tester confirmed that v0.1.1 fixed the controls. Their
new `runtime.log` shows the virtual Xbox controller connected. The original
native Gilrs failure remains unexplained; this report validates the alternate
input route on the RG34xxSP. The tester also reported missing audio, investigated
separately in [audio compatibility](AUDIO-COMPATIBILITY.md).

For reports from other devices, check menu navigation, confirm/back, single taps
versus held buttons, L/R in combat, Exit Game, Start+Select and save/reload. If input fails, retain
both `log.txt` and `runtime.log` from the same launch. For virtual-controller mode,
the launcher log should say `DDD input: SDL virtual Xbox controller`; the runtime
log should identify that pad or explain why controller initialization failed.
The native route is logged as `DDD input: direct controller (Gilrs)`.
