# AMF3 save-writer reference accounting

A later-game save failed to load on both the accepted runtime and the initial
Exit Game candidate. Its active-skill reference pointed into achievement data.
The original file was retained unchanged before investigation.

The AMF3 writer in `rust-flash-lso` emitted every array and ordinary object
inline, but its reference cache only counted distinct contents. Equal inline
containers therefore occupied more slots in the file than in that cache. It
also omitted numeric vectors, dates, byte arrays and XML from the count. Later
vector or Dictionary references could point at unrelated data.

`inline-object-references.patch` records every emitted inline object. It preserves
the existing value-based deduplication for object vectors and Dictionaries; it
does not claim to fix every AMF object-identity limitation. The reader and game
content are unchanged.

Apply the patch within the `flash-lso` crate from upstream commit
`61b717248aae853a4f5d8a103eba704268d286c8`. Its MIT license is included. The local
Ruffle candidate vendors that source under `core/vendor/flash-lso` and selects it
through a Cargo patch. Runtime checkpoint
`ddb9a7c16792378837d95d62ee69927015882c6f` includes this fix and the AIR quit fix.

## Validation

`ddd_inline_references.rs` is an original regression with no game content. Put it
in the crate's `tests` folder and run `cargo test --test ddd_inline_references`.
The unchanged dependency fails both reference checks after inline containers;
the control without preceding containers passes. The patched dependency passes
all three. Ruffle's existing cross-root shared-object regression and the new AIR
quit regression also pass against the rebuilt headless runtime.

For the frozen player backup, replaying the old writer's cache recovered fourteen
shifted references. A separate verifier fed that recovered copy through the old
writer and reproduced all 6,501 original bytes exactly. Recovery changed fifteen
reference bytes and no other bytes. This is evidence for that specific backup,
not a general save-repair guarantee. Player saves and recovery copies are private
and are not included here.

The recovered copy reached the main menu on the Brick with the Exit-only runtime.
Its normal menu exit passed after the separate Crusty shutdown fix. The writer
fix's ARM build is blocked by host disk space, so its native execution and
repeated save/reload checks remain pending. The accepted runtime pins have not
yet been promoted to this candidate.
