# Private keyboard menu probe

The purchased PC build already handles Enter on its title screen. Its shared
`ButtonMenu` class also contains Up/Down/Enter navigation, but enables that code
and its selection highlight only for the OUYA platform. The PC main and pause
menus therefore cannot be assumed to work from keyboard mapping alone.

`Prepare-KeyboardMenuProbe.ps1` accepts only the exact private offline probe with
SHA-256 `f50cc4a7e2539b661dc0243377dd8e73617248dde9a4026a550b5be4655bc7d5`.
It creates a separate private movie and a JSON provenance report:

```powershell
./Prepare-KeyboardMenuProbe.ps1 -OfflineGameFile C:/private/ddd-offline.swf -OutputFile C:/private/ddd-keyboard-menu.swf
```

The helper replaces two four-byte `ifne` instructions with `pop; pop; nop; nop`.
Both forms consume the two platform-comparison operands. The replacement falls
through into the existing menu code. Method sizes, later instruction addresses,
remaining branch targets, and all other movie bytes remain unchanged.

| Method | Instruction offset | Private input file offset | Before | After |
| --- | ---: | ---: | --- | --- |
| ButtonMenu constructor (4533) | 105 | 28525728 | `14 42 00 00` | `29 29 02 02` |
| ButtonMenu.step (4538) | 12 | 28526472 | `14 00 01 00` | `29 29 02 02` |

The constructor change adds the existing highlight. The step change enables the
existing selection and callback handling. Global platform identity stays PC;
mouse event handlers and the offline bootstrap remain unchanged. This does not
enable every possible controller interface or alter any game assets.

Static inspection established these keyboard actions in `KeyboardInput.call`:

| Key and AS3 keycode | Existing action |
| --- | --- |
| Enter (13) | Continue; title screen and enabled menu selection |
| Left (37), A (65) | Defend; left choice; HP upgrade |
| Right (39), D (68) | Attack; loot; right choice; agility upgrade; shrine/portal |
| Down (40), S (83) | Down navigation; magic upgrade |
| Up (38), W (87) | Up navigation; attack upgrade |
| Space (32) | Use item; statistics page actions |
| C (67) | Open statistics |
| Escape (27) | Home/back; pause menu resumes on back |

`SplashScreen.step` checks Continue without an OUYA platform gate. An Enter press
during the opening fade advances that fade; another press after it finishes opens
the main menu. The title's pointer handler uses touch-began and the same transition.
`MainMenu.step` calls `ButtonMenu.step`, and `PauseMenu.step` handles back or calls
that same menu step.

The input hash, both surrounding comparisons, and both branch byte sequences are
checked before writing. The helper verifies exactly eight changed bytes and
restores them in memory to recover the entire input hash. It refuses existing
outputs, unknown inputs, source/package output locations, and reparse-point paths.

The prepared candidate has SHA-256
`c92867d7cdf6e86652562889d46641b4ff228feae042ce4b6cb8ca57161d4ce7`.
Both input and output are 28,620,575 bytes. PowerShell parsing, four refusal checks
(existing output, unknown input, source output, and wrong extension), and FFDec
reparsing of both modified methods passed. FFDec confirms the replacement
instructions at the original addresses and unchanged method stack limits.

This is a mechanically checked compatibility candidate. Bounded Brick runs reached
the startup logos, but audio faults prevented progression to the menus. Direct
gamepad discovery now works; navigation and the menu highlight remain unverified.
See [controller and audio findings](CONTROLLER-AUDIO.md). The menu highlight needs
a rendered review and a separate cleanup pass; key mappings do not prove input feel.
Keep the generated SWF private because it contains the purchased game. Only this
original helper source and these functional notes belong in the source package.
