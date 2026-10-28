# Rebuilding and replacing runtime components

The open-source runtime and libraries remain modifiable under their respective
licenses. This port adds no restriction on modifying them for your own use or
reverse engineering to debug those modifications. The game itself is supplied
separately by the player and retains its own terms.

Ruffle loads the native libraries dynamically from `portable/lib/` using the
bundled AArch64 glibc loader. Xwayland's EGL library is separate, under
`portable/xwayland-compat/`. An interface-compatible replacement can be copied
over the relevant library. Keep the loader and glibc libraries mutually
compatible if replacing glibc. Use regular files rather than symlinks.

The checksum manifest detects accidental damage. It is editable local data,
with no signature, server approval or secret key. To update it after replacing
an open-source component:

1. Quit DDD and back up the installation and complete `profile/` directory.
2. Build from the accompanying source materials and copy your replacement into
   its original location. Add any new dependencies beneath `portable/`.
3. On a PC with Python 3.9 or later, run the supplied tool:

   ```sh
   python refresh-runtime-manifest.py --root /path/to/deepdungeonsofdoom
   ```

4. Keep a backup of `manifest.sha256`, then replace it with the generated
   `manifest.modified.sha256`. Run the menu entry with `--check`, then launch it
   normally. The new manifest describes your local build; it does not make it
   an officially tested build.

The tool preserves the prepared game checksum and never reads or writes saves.
It refuses linked files, unexpected manifest paths and an existing output.
The replacement check exercises the actual launcher validator: a changed library
fails before refresh and succeeds after explicit refresh, including an added
dependency. It also checks game, save and pending-output protection.

`RUNTIME-SOURCE.md` explains rebuilding Ruffle and the helper libraries. The
source archive includes exact native source packages and their packaging patches,
plus the MPL crate sources and font notices. Distribute that archive alongside
the player ZIP, with equally accessible source download links. The local draft
does not yet provide public downloads; publication waits for the user's review.
