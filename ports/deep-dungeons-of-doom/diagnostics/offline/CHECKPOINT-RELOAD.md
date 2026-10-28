# Early dungeon checkpoint and reload

Two native Brick runs on October 25, 2026 exercised an ordinary floor transition,
saved it, and reloaded that exact profile. Both used the silent Encyclopedia Back
movie `a308ea6466305b6e9a553387f67c8f8b317edf0d0fa57f09bb47a1e0b537f3f7`
and pipeline-cache runtime `b381ea2275a9b9b720115cf7620965036227001e2fbc2761bc9084700f8ffd70`.
The newer batching runtime was not involved. Each run entered through NX's Ports
wrapper with the existing parent launcher and a 240-second deadline.

A fresh Down moved from the restored empty Sewer entry into the first encounter.
The attack tutorial appeared. Escape did not open Pause while that tutorial was
active. No attack, dungeon abandonment or profile rollback was used in this
check. The second run reloaded the empty safe room and made another ordinary
Down transition. The lead inspected both transitions, the settled tutorial and
the final NX return on the Brick framebuffer.

Each snapshot was copied privately. Its checksums matched live-profile checksums
read before and after the copy. The entire profile immediately before relaunch was
byte-identical to the first post-transition checkpoint.

| Disk snapshot | Current / maximum / added floors | Dungeon time | Selected bank |
| --- | --- | --- | --- |
| First startup | 0 / 0 / 0 | 0 seconds | 1 |
| First normal Down | 1 / 1 / 1 | 39.65 seconds | 0 |
| Reload startup | 0 / 0 / 0 | 0 seconds | 0 |
| Normal Down after reload | 1 / 1 / 1 | 92.45 seconds | 1 |

The last checkpoint retained the earlier elapsed time and added 52.8 seconds.
The native save timestamps between reload startup and that checkpoint differ
by 52.883 seconds. Across all snapshots, slot timestamps matched the selected
bank without fallback. All player values remained unchanged, including Crusader,
HP9 and MP3. All 156 object records and 32 reference aliases, including 11 crossing
top-level fields, remained consistent. Carried item and equipment slots were empty.

The zeroed startup snapshot remains a limitation. The original game creates and
adds the dungeon before restoring its saved runtime state; its initial onAdded
save therefore precedes that restoration. It also reconstructs an earlier safe
room. These runs verify elapsed-time restoration followed by a normal save;
they do not establish safe repeated quit/relaunch without another floor move,
nonempty inventory persistence, later progression or physical control feel.

Both owned runtimes were stopped with the guarded TERM helper before their
deadline. Game and parent each returned 143. Exact ordinary movie/runtime/launcher
hashes were restored, with all 461 manifest entries passing. Owned display
processes, paths and mounts were absent, and NX returned. No AVM2 exception or
panic matched the retained logs; existing font, locale and deferred-audio
diagnostics remain. The candidate is still separate from the ordinary installation.

Private run identifiers are `run-20261025-172209-4712` and
`run-20261025-172719-21695`. Game files, saves, screenshots and raw logs remain
outside the public source archive.
