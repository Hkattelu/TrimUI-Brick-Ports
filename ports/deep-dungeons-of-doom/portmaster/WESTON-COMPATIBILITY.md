# Standard WestonPack on the original Brick

The package supports these two verified WestonPack 0.2 images:

| Image | SHA256 |
| --- | --- |
| PortMaster catalogue 0.2.7.1 | `0bccaeebc11296bb1fe4278c9677cb82965c5a04bcd63745fa09d78228bc1a93` |
| NX Redux 0.2.8 Preview 1 | `4c929287617b1276b5cbffcd188eea77aa979a2a84524fd222d03ed3d408c82b` |

WestonPack is obtained separately through PortMaster. The DDD archive does not
redistribute it. The catalogue image lacks NX's `cm_compat/libEGL.so.1`; DDD supplies
that dependency under `portable/xwayland-compat/` for Xwayland only.

`fetch-weston-egl.py` obtains `libegl1` version `1.3.2-1~ubuntu0.20.04.2` from the
official Ubuntu arm64 archive. Its library is byte-identical to NX's copy:
`af6b268d80f2b940dbef0df080b51a927ac8ec41d06626eea4151a189e6b75a7`.
The original copyright notice is retained. The source archive includes the exact
libglvnd source tarball, Ubuntu packaging changes, source descriptor and index
evidence. The collector checks binary/source hashes through HTTPS InRelease and
package indexes; it does not independently verify OpenPGP signatures.

On October 27, 2026, the standard image ran through the normal NX Ports runner in
an isolated installation using Ruffle `9df2b904...`. Menu input, Adventure loading
and Exit were exercised. Process maps confirmed the packaged EGL library and the
shutdown proxy were loaded. Runtime and launcher both returned 0, the Weston mount
was released, and rendered cleanup showed NX again. The shared NX runtime and
human profile were unchanged. This silent check does not certify audio quality,
combat feel, other hardware or other firmware.
