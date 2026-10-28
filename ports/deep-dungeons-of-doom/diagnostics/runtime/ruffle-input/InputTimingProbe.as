package {
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.KeyboardEvent;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.utils.getTimer;

    // Original timing fixture; no game content and no automatic input.
    public class InputTimingProbe extends Sprite {
        private var frameNumber:int = 0;
        private var edgeNumber:int = 0;
        private var keys:Object = {};
        private var downAt:Object = {};
        private var heldFrames:Object = {};
        private var watched:Array = [13, 32, 37, 38, 39, 40, 67];
        private var display:TextField = new TextField();
        private var lastEdge:String = "Waiting for input";

        public function InputTimingProbe() {
            if (stage) start();
            else addEventListener(Event.ADDED_TO_STAGE, onAdded);
        }

        private function onAdded(event:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, onAdded);
            start();
        }

        private function start():void {
            stage.scaleMode = "noScale";
            stage.align = "TL";
            display.defaultTextFormat = new TextFormat("_sans", 24, 0xffffff);
            display.background = true;
            display.backgroundColor = 0x102030;
            display.width = 1000;
            display.height = 320;
            display.selectable = false;
            addChild(display);
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onDown);
            stage.addEventListener(KeyboardEvent.KEY_UP, onUp);
            addEventListener(Event.ENTER_FRAME, onFrame);
            trace("INPUT_PROBE_READY", getTimer());
            refresh();
        }

        private function onDown(event:KeyboardEvent):void {
            var code:uint = event.keyCode;
            edgeNumber++;
            if (keys[code] === true) {
                trace("INPUT_REPEAT", edgeNumber, code, frameNumber, getTimer());
            } else {
                keys[code] = true;
                downAt[code] = getTimer();
                heldFrames[code] = 0;
                trace("INPUT_DOWN", edgeNumber, code, frameNumber, downAt[code]);
            }
            lastEdge = "Key down: " + code;
            refresh();
        }

        private function onUp(event:KeyboardEvent):void {
            var code:uint = event.keyCode;
            edgeNumber++;
            trace("INPUT_UP", edgeNumber, code, frameNumber, getTimer(),
                "had_down", keys[code] === true,
                "held_frames", heldFrames[code],
                "held_ms", getTimer() - Number(downAt[code]));
            keys[code] = false;
            lastEdge = "Key up: " + code + "; frames held: " + heldFrames[code];
            refresh();
        }

        private function onFrame(event:Event):void {
            frameNumber++;
            for each (var code:uint in watched) {
                if (keys[code] === true) heldFrames[code]++;
            }
            if (frameNumber % 60 == 0) {
                trace("INPUT_FRAME", frameNumber, getTimer(),
                    "left", keys[37] === true, "right", keys[39] === true);
                refresh();
            }
        }

        private function refresh():void {
            display.text = "Controller timing test\n" +
                "Arrow keys, Enter, Space and C\n" +
                "Frames: " + frameNumber + "   Events: " + edgeNumber + "\n" +
                lastEdge + "\n" +
                "Left held: " + (keys[37] === true) +
                "   Right held: " + (keys[39] === true);
        }
    }
}
