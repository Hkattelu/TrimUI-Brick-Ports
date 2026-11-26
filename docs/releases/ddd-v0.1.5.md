# Deep Dungeons of Doom v0.1.5 test build

This build corrects the controller mapping on the RG40XX H running muOS Jacaranda. In v0.1.4, Ruffle rejected the firmware's volume-button entries and fell back to a layout where Select defended and Start attacked. The port now translates the affected profile for Ruffle and passes the original profile to the quit helper.

Back up your profile, then put the unopened player ZIP in PortMaster's active `autoinstall/` folder and open PortMaster. Keep your prepared game and save files when updating. A first installation requires WestonPack 0.2 and the files from your purchased Windows Steam copy. [Download the player ZIP](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases/download/ddd-v0.1.5-test/deepdungeonsofdoom.zip)

## RG40XX H retest

1. Equip a health potion and take damage. On the character stats screen, try X to flip More Info. Note which button actually changes the page. Close stats with Back and press that same button during play. Check whether your health increases and the potion disappears.
2. Tap Select and Start separately in stats. The highlighted entry should stay put. In combat, L should defend and R should attack. Holding Start and pressing Select should still quit.
3. Report the button label and what happened. If anything fails, include `deepdungeonsofdoom/log.txt` and `runtime.log` from that launch. Weston includes device identifiers in its log, so remove those before posting publicly.

A simulated Linux controller reproduced the v0.1.4 failure. With the correction, Gilrs delivered the expected press and release events for twelve controls. A physical RG40XX H retest is pending. The broader firmware checklist is in the [tester guide](https://github.com/Hkattelu/TrimUI-Brick-Ports/releases/download/ddd-v0.1.5-test/TESTER-GUIDE.md).
