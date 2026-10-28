package {
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.utils.getDefinitionByName;

    // Original soundless fixture. No game data or artwork is used.
    public class NativeExitProbe extends Sprite {
        private var frames:int = 0;

        public function NativeExitProbe() {
            addEventListener(Event.ENTER_FRAME, onFrame);
        }

        private function onFrame(event:Event):void {
            frames++;
            if (frames == 1) {
                trace("NATIVE_EXIT_READY");
            } else if (frames == 2) {
                var appClass:Object = getDefinitionByName("flash.desktop.NativeApplication");
                var app:Object = appClass.nativeApplication;
                app.addEventListener("exiting", onUnexpectedExiting);
                trace("NATIVE_EXIT_REQUEST");
                app.exit(0);
                trace("NATIVE_EXIT_RETURN");
            } else {
                trace("NATIVE_EXIT_STILL_RUNNING");
            }
        }

        private function onUnexpectedExiting(event:Event):void {
            trace("NATIVE_EXIT_UNEXPECTED_EXITING_EVENT");
        }
    }
}
