# Community testing

This is an experimental ARM64 port using Ruffle and WestonPack 0.2. Each tester
needs their own purchased Windows game files and Windows PowerShell 7.2 or later
for preparation. The package declares glibc 2.31 as its minimum. An Android phone
does not establish compatibility with the Linux firmware used by PortMaster.

The original TrimUI Brick with NX Redux is the only tested hardware/firmware
combination. The current movie disables unavailable Steam Trophies and Hi-score
buttons. Local Missions remains available. Other firmware support is unproven.

## Before sending a build

Discuss the offline startup adaptation with maintainers in
[#testing-threads](https://discord.com/channels/1122861252088172575/1122885073507733625).
Keep their policy answer with the testing thread. Ask which combinations and
results they require before accepting a submission, including older firmware
whose system libraries may not meet the declared minimum.

Supply the player ZIP, corresponding source ZIP, preparation instructions and
checksums together. Do not send a prepared SWF, purchased AIR libraries, game
music, player profile or the private development directory. The preparation tools
are inside the player ZIP. No game purchase is needed merely to volunteer, but
actual gameplay testing requires the tester's own supported files.

## Installation and normal play

1. Record the device model, firmware/version, PortMaster version and native
   resolution. If known, also record the GPU backend, especially ROCKNIX's
   Panfrost versus libmali. Do not guess it.
2. Back up an existing DDD installation and profile before replacing anything.
   Use a fresh installation for initial compatibility testing. Follow the
   included player guide to prepare the purchased game on the PC.
3. Put only the player `deepdungeonsofdoom.zip` in your firmware's
   `PortMaster/autoinstall/` folder and open PortMaster to install it. The source
   archive is for developers and must not go in autoinstall. Install WestonPack
   0.2 through PortMaster. Use the firmware's normal Ports
   launcher. For manual ZIP installation, ask the firmware's maintainers for its
   correct Ports location; NX uses a different hidden layout. Do not copy our
   private NX Tools wrapper to other firmware.
4. Play normally. Check title startup, combat and attacks, floor transitions,
   the bonus screen, music/effects, and responsive controls. Report when a hitch
   or audio fault occurs and whether it improves after the first occurrence.
5. Browse the skill tree, stash, Encyclopedia and Options. Check the Honor menu:
   Trophies and Hi-score should be dimmed and skipped; unlocked Missions and
   Back should work. Use a spare profile for purchases, discards or other
   changes you would not want on your normal save. Do not reset a real save.
6. Quit through Exit Game, relaunch, and confirm progress/settings survived.
   Separately check Start+Select. Confirm return to the firmware menu and that
   another game still launches normally.

There is no timed test or required campaign completion. Note anything you did
not test. If startup fails, stop and report it rather than repeatedly reinstalling.

## Reply in the testing thread

Include:

- Device, firmware/version, PortMaster version, native resolution and GPU backend
  if known.
- Candidate ZIP checksum and game-preparation outcome. Do not attach the game.
- Startup, controls, combat/transitions, audio, menus, save/reload and both quit
  methods: passed, failed or not tested for each.
- The first failure, steps to reproduce it and whether it happens every time.
- A screenshot or short clip if useful. Review `log.txt` and `runtime.log` for
  personal paths before attaching them. Do not post saves publicly.

Record confirmed results in TESTING-MATRIX.md with the tested revision. Prioritize
ROCKNIX (libmali and Panfrost), muOS, dArkOS, Knulli and AmberELEC, covering
640×480 and a higher resolution such as 1280×720; add 720×720 where available.
Track failures as well as passes. Architecture alone is not a successful test.

## Submission sequence

The [official packaging guide](https://portmaster.games/packaging.html#testing-requirements)
requires documented community testing before a PR. After policy guidance and
testing, prepare a feature branch containing only `ports/deepdungeonsofdoom/`,
publish corresponding source links with any binary, and open a draft PR against
PortsMaster/PortMaster-New. Link the testing thread and record limitations. Keep
follow-up fixes on that PR. A draft PR is public and is not maintainer acceptance.
