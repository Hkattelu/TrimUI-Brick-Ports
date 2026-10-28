# First controlled gameplay on the Brick

On October 24, 2026, private Ruffle run
`graphics-20261024-234445-16615` reached the actual main menu, intro, first sewer
dungeon, attack tutorial, and a successful attack against the practice target on
the TrimUI Brick. This is a bounded gameplay milestone, not a completed port.

The remaining-gate statements below describe that run. Later work verified the
[owned quit chord](../brick/DDD-EXIT.md) and prepared an
[AMF save-reference fix](../runtime/ruffle-amf/README.md); the fix still needs a
Brick save/reload check. See the [current status](../../README.md) for the latest
launcher, controls and deferred-audio boundaries.

The run used the silent diagnostic SWF with SHA-256
`242fc26d5253c2bb91d3919bb9b0fc77788e1505917b912a6f1ba4719160f392`.
It includes the private offline startup change, existing keyboard-menu support,
and the silent logo timer. No Steam client was used on the Brick. The purchased
game and all generated movies remain private.

## Observed result

The main-menu capture shows the game's artwork and its existing selection
highlight on the first option. The dungeon captures show the player, practice
target, HUD, attack prompt, damage feedback, and cooldown tutorial. A later frame
shows gameplay again after the tutorial overlay closes. Both the lead tester and
the author of this note inspected the five actual captures listed below.

During the controlled input run, Start mapped to Enter and Select mapped to
Escape produced the expected transitions. The right shoulder triggered an
attack: the subsequent frame shows damage and the cooldown tutorial. This is
evidence of a delivered input and visible game response, not a claim about
latency, combat feel, or reliable repeated attacks.

The D-pad remained unresolved in this run. Down did not move the main-menu
highlight, and Right did not trigger the attack that the right shoulder did.
Input mapping was under investigation; the captures do not establish a game-code
fault or validate the remaining buttons. Blocking, full tutorial completion,
world-map navigation, and a complete dungeon were not tested.

The private log records Starling initialization, intro cutscene events, and
`START_DUNGEON`. The 180-second harness ended with exit code 143, as expected for
its timed termination. Cleanup evidence reports `westonMountReleased=yes`.
This timed exit does not validate a player-controlled quit or save persistence.

## Private evidence

These files are retained outside the source repository in
`ddd-port-work/device-test/`. Only their names and SHA-256 values are recorded
here; the images contain purchased game content and are not package contents.

| Capture | What was inspected | SHA-256 |
| --- | --- | --- |
| `ddd-gameplay-menu.jpg` | Main menu with selection highlight | `bf82bf33970ce68a7f2c772f40af8d9f3bfdedd3807fa8739e4406a27d3b537d` |
| `ddd-first-dungeon-view.jpg` | First dungeon entry and HUD | `c617012076b650a8a23dd360a59c0c08405b2073ed26f4948f669006b3bdf303` |
| `ddd-attack-tutorial.jpg` | Player, target, and attack tutorial overlay | `3164611139d5bc74e62f4ec208486e8eb2442dfd8f7b2fe1f42a7121f814fbc7` |
| `ddd-attack-result.jpg` | Damage feedback and cooldown tutorial after attack | `8acf53d6f0c6b91c6595143b773ffaae0a4ce3acd0d88234ad2086e6ecbc7a86` |
| `ddd-combat-continued.jpg` | Gameplay view after the overlay closed | `6605dcbb3edd5735a4aa0e5fd282e9756a91718a9b20bd005a56de3a724dea07` |

Associated private records are `ddd-gameplay-visual-run.txt`,
`ddd-gameplay-visual-ruffle.log`, `ddd-gameplay-launch.log`, and
`ddd-gameplay-visual-cleanup.txt`. The run record identifies the device directory
ending in `game-runs/graphics-20261024-234445-16615`; the launch log records the
same movie hash above.

## Remaining gates at the end of the first run

Audio was deliberately unavailable in this diagnostic and remains unfixed.
Save/reload behavior and the controller quit shortcut were not validated.
The D-pad mapping, remaining controls, later world-map keyboard restrictions,
and normal player launcher still need work. No full gameplay quality review,
separate final cleanup pass, or user acceptance is claimed. This evidence does
not establish distribution rights or PortMaster acceptance.

## Subsequent reload check

Run `graphics-20261024-235107-21628` reused a separate copy of this run's save
directory with the keyboard-menu movie and the audio recovery experiment. The
lead inspected a restored dungeon, a downward floor transition from D-pad Down,
and a further right-shoulder attack. D-pad delivery therefore works in at least
that case; menu navigation and input latency still need focused checks.

The reload also logged AMF3 object-reference errors. Inspection found references
to empty dictionaries/vectors shared between top-level save properties. Ruffle
resets its deserialization reference map for each property, so the restored
scalar/dungeon state does not establish reliable progression saves. The original
completed run's save files remain unchanged for diagnosis. Audio listening and
the quit shortcut were still unverified when the timed run ended and released
its private Weston mount.
