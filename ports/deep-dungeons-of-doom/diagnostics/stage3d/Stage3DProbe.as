package {
    import flash.display.Sprite;
    import flash.display.Stage3D;
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProfile;
    import flash.display3D.Context3DRenderMode;
    import flash.events.ErrorEvent;
    import flash.events.Event;

    public class Stage3DProbe extends Sprite {
        private var display:Stage3D;
        private var context:Context3D;
        private var firstPresent:Boolean = true;

        public function Stage3DProbe() {
            trace("STAGE3D_DOCUMENT_CREATED");
            if (stage) {
                requestContext();
            } else {
                addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            }
        }

        private function onAddedToStage(event:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
            requestContext();
        }

        private function requestContext():void {
            trace("STAGE3D_STAGE_READY");
            try {
                display = stage.stage3Ds[0];
                display.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
                display.addEventListener(ErrorEvent.ERROR, onContextError);
                trace("STAGE3D_REQUEST auto baseline");
                display.requestContext3D(Context3DRenderMode.AUTO, Context3DProfile.BASELINE);
                trace("STAGE3D_REQUEST_RETURNED");
            } catch (error:Error) {
                trace("STAGE3D_REQUEST_ERROR " + error.errorID + " " + error.message);
            }
        }

        private function onContextCreated(event:Event):void {
            trace("STAGE3D_CONTEXT_CREATED");
            try {
                context = display.context3D;
                context.configureBackBuffer(550, 400, 0, false);
                trace("STAGE3D_CONFIGURED 550x400 aa=0 depthStencil=false");
                firstPresent = true;
                onFrame(null);
                if (!firstPresent) {
                    addEventListener(Event.ENTER_FRAME, onFrame);
                }
            } catch (error:Error) {
                trace("STAGE3D_CONFIGURE_ERROR " + error.errorID + " " + error.message);
            }
        }

        private function onContextError(event:ErrorEvent):void {
            trace("STAGE3D_CONTEXT_ERROR " + event.errorID + " " + event.text);
        }

        private function onFrame(event:Event):void {
            try {
                context.clear(0.0625, 0.75, 0.1875, 1.0);
                context.present();
                if (firstPresent) {
                    firstPresent = false;
                    trace("STAGE3D_FIRST_PRESENT green");
                }
            } catch (error:Error) {
                removeEventListener(Event.ENTER_FRAME, onFrame);
                trace("STAGE3D_PRESENT_ERROR " + error.errorID + " " + error.message);
            }
        }
    }
}
