package {
    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.Sprite;
    import flash.display.Stage3D;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.display3D.Context3D;
    import flash.display3D.IndexBuffer3D;
    import flash.display3D.Program3D;
    import flash.display3D.VertexBuffer3D;
    import flash.display3D.textures.Texture;
    import flash.events.ErrorEvent;
    import flash.events.Event;
    import flash.geom.Rectangle;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    // Original, finite, single-context rendering fixture. No assets, input,
    // storage, network, audio, timers, game imports or automatic process exit.
    // The external owned runner must impose its normal time limit.
    public class BatchingProbe extends Sprite {
        private var display:Stage3D;
        private var context:Context3D;
        private var colorProgram:Program3D;
        private var textureProgram:Program3D;
        private var fullVertices:VertexBuffer3D;
        private var quadIndices:IndexBuffer3D;
        private var cards:Array = [];
        private var failures:int = 0;
        private var checks:int = 0;
        private var started:Boolean = false;

        public function BatchingProbe() {
            trace("BATCH_FIXTURE_DOCUMENT version=2 single_context=true");
            if (stage) requestContext();
            else addEventListener(Event.ADDED_TO_STAGE, onAdded);
        }

        private function onAdded(event:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, onAdded);
            requestContext();
        }

        private function requestContext():void {
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            display = stage.stage3Ds[0];
            display.addEventListener(Event.CONTEXT3D_CREATE, onContext);
            display.addEventListener(ErrorEvent.ERROR, onContextError);
            display.requestContext3D("auto", "baseline");
        }

        private function onContextError(event:ErrorEvent):void {
            trace("BATCH_FIXTURE_ERROR context " + event.errorID + " " + event.text);
            label("Context creation failed; see trace", 10, 10, 520);
        }

        private function onContext(event:Event):void {
            if (started) {
                trace("BATCH_FIXTURE_ERROR unexpected_context_recreation");
                return;
            }
            started = true;
            try {
                context = display.context3D;
                trace("BATCH_FIXTURE_CONTEXT " + context.driverInfo);
                // Avoid enableErrorChecking: a diagnostic GPU wait here could
                // conceal the ordering hazard being tested.
                context.configureBackBuffer(64, 64, 0, false);
                colorProgram = context.createProgram();
                colorProgram.upload(vertexShader(), fragmentShader(false));
                textureProgram = context.createProgram();
                textureProgram.upload(vertexShader(), fragmentShader(true));
                fullVertices = makeVertices(quad(-1, 1), 4);
                quadIndices = context.createIndexBuffer(6);
                quadIndices.uploadFromVector(indices(0), 0, 6);
                context.setCulling("none");
                context.setBlendFactors("one", "zero");
                context.setDepthTest(false, "always");

                snapshotGate();
                uniformGate();
                vertexGate();
                indexGate();
                textureUploadGate();
                renderTextureGate();
                scissorResetGate();
                blendGate();
                bindingGate();
                vertexBindingGate();
                clearGate();
                shaderGate();
                reconfigureGate();
                showResults();
                trace("BATCH_FIXTURE_DONE checks=" + checks + " failures=" + failures
                    + " aa4=requested_not_verified");
            } catch (error:Error) {
                failures++;
                trace("BATCH_FIXTURE_ERROR " + error.errorID + " " + error.message);
                trace(error.getStackTrace());
                showResults();
                label("Fixture stopped; see trace", 10, 375, 520);
            }
        }

        private function snapshotGate():void {
            trace("BATCH_GATE_BEGIN snapshot");
            beginColor();
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            var saved:BitmapData = capture(64, 64);
            // No saved pixels are read or uploaded before this later draw.
            color(0, 0, 1);
            context.drawTriangles(quadIndices, 0, 2);
            var later:BitmapData = capture(64, 64);
            context.present();
            trace("BATCH_GATE_AFTER_PRESENT snapshot");
            pixel("snapshot.old", saved, 32, 32, 0xffff0000);
            pixel("snapshot.later", later, 32, 32, 0xff0000ff);
            card("1: saved A", saved);
            card("1: later B", later);
        }

        private function uniformGate():void {
            trace("BATCH_GATE_BEGIN uniform");
            beginColor();
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("2: uniform");
        }

        private function vertexGate():void {
            trace("BATCH_GATE_BEGIN vertex");
            beginColor();
            var vertices:VertexBuffer3D = makeVertices(quad(-1, 0), 4);
            bind(vertices);
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            // Same GPU buffer, changed positions after the first draw.
            vertices.uploadFromVector(quad(0, 1), 0, 4);
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("2: vertex");
        }

        private function indexGate():void {
            trace("BATCH_GATE_BEGIN index");
            beginColor();
            var vertices:VertexBuffer3D = makeVertices(quad(-1, 0).concat(quad(0, 1)), 8);
            bind(vertices);
            var changing:IndexBuffer3D = context.createIndexBuffer(6);
            changing.uploadFromVector(indices(0), 0, 6);
            color(1, 0, 0);
            context.drawTriangles(changing, 0, 2);
            // Same six index elements, now selecting the right-hand vertices.
            changing.uploadFromVector(indices(4), 0, 6);
            color(0, 1, 0);
            context.drawTriangles(changing, 0, 2);
            finishPair("2: index");
        }

        private function textureUploadGate():void {
            trace("BATCH_GATE_BEGIN texture_upload");
            beginColor();
            context.setProgram(textureProgram);
            var texture:Texture = context.createTexture(2, 2, "bgra", false);
            // These are original CPU-authored input pixels, never a readback.
            var pixels:BitmapData = new BitmapData(2, 2, false, 0xff0000);
            texture.uploadFromBitmapData(pixels);
            context.setTextureAt(0, texture);
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            context.drawTriangles(quadIndices, 0, 2);
            pixels.fillRect(new Rectangle(0, 0, 2, 2), 0xff00ff00);
            texture.uploadFromBitmapData(pixels);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("2: texture");
        }

        private function renderTextureGate():void {
            trace("BATCH_GATE_BEGIN render_texture aa=0");
            var target:Texture = context.createTexture(64, 64, "bgra", true);
            context.setTextureAt(0, null);
            context.setRenderToTexture(target, false, 0);
            context.setScissorRectangle(null);
            context.setProgram(colorProgram);
            bind(fullVertices);
            context.clear(0, 0, 0, 1);
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setRenderToBackBuffer();
            context.setScissorRectangle(null);
            context.clear(0, 0, 1, 1);
            context.setProgram(textureProgram);
            context.setTextureAt(0, target);
            context.drawTriangles(quadIndices, 0, 2);
            // No present/readback occurs between target draws and sampling it.
            finishPair("3: target");
        }

        private function scissorResetGate():void {
            trace("BATCH_GATE_BEGIN scissor_reset");
            beginColor();
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setScissorRectangle(null);
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishExpected("5: scissor", 0xff00ff00, 0xff00ff00);
        }

        private function blendGate():void {
            trace("BATCH_GATE_BEGIN blend_pipeline");
            beginColor();
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setBlendFactors("one", "one");
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishExpected("5: blend", 0xffff0000, 0xffffff00);
            context.setBlendFactors("one", "zero");
        }

        private function bindingGate():void {
            trace("BATCH_GATE_BEGIN texture_binding");
            beginColor();
            var red:Texture = solidTexture(0xff0000);
            var green:Texture = solidTexture(0x00ff00);
            context.setProgram(textureProgram);
            context.setTextureAt(0, red);
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            context.drawTriangles(quadIndices, 0, 2);
            context.setTextureAt(0, green);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("5: binding");
        }

        private function vertexBindingGate():void {
            trace("BATCH_GATE_BEGIN vertex_binding");
            beginColor();
            var left:VertexBuffer3D = makeVertices(quad(-1, 0), 4);
            var right:VertexBuffer3D = makeVertices(quad(0, 1), 4);
            bind(left);
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            bind(right);
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("5: vertices");
        }

        private function clearGate():void {
            trace("BATCH_GATE_BEGIN clear_boundary");
            beginColor();
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.clear(0, 0, 1, 1);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            finishExpected("5: clear", 0xff0000ff, 0xff00ff00);
        }

        private function shaderGate():void {
            trace("BATCH_GATE_BEGIN shader_pipeline");
            beginColor();
            var green:Texture = solidTexture(0x00ff00);
            context.setScissorRectangle(new Rectangle(0, 0, 32, 64));
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            context.setProgram(textureProgram);
            context.setTextureAt(0, green);
            context.setScissorRectangle(new Rectangle(32, 0, 32, 64));
            context.drawTriangles(quadIndices, 0, 2);
            finishPair("5: shader");
        }

        private function solidTexture(rgb:uint):Texture {
            var texture:Texture = context.createTexture(2, 2, "bgra", false);
            texture.uploadFromBitmapData(new BitmapData(2, 2, false, rgb));
            return texture;
        }

        private function finishExpected(name:String, left:uint, right:uint):void {
            context.setScissorRectangle(null);
            var saved:BitmapData = capture(64, 64);
            context.present();
            pixel(name + ".left", saved, 16, 32, left);
            pixel(name + ".right", saved, 48, 32, right);
            card(name, saved);
        }

        private function reconfigureGate():void {
            trace("BATCH_GATE_BEGIN reconfigure backbuffer_aa_requested=4");
            context.configureBackBuffer(64, 64, 4, false);
            beginColor();
            color(1, 0, 0);
            context.drawTriangles(quadIndices, 0, 2);
            var saved:BitmapData = capture(64, 64);
            color(0, 0, 1);
            context.drawTriangles(quadIndices, 0, 2);
            // No saved BitmapData read occurs before this pending draw and
            // reconfiguration. The prior buffers can now be replaced.
            context.configureBackBuffer(80, 48, 0, false);
            beginColor();
            color(0, 1, 0);
            context.drawTriangles(quadIndices, 0, 2);
            var replacement:BitmapData = capture(80, 48);
            context.present();
            trace("BATCH_GATE_AFTER_RECONFIGURE_AND_PRESENT reconfigure");
            pixel("reconfigure.old", saved, 32, 32, 0xffff0000);
            pixel("reconfigure.new", replacement, 40, 24, 0xff00ff00);
            card("4: AA4 saved", saved);
            card("4: resized", replacement);
        }

        private function beginColor():void {
            context.setRenderToBackBuffer();
            context.setScissorRectangle(null);
            context.setTextureAt(0, null);
            context.setProgram(colorProgram);
            bind(fullVertices);
            context.clear(0, 0, 0, 1);
        }

        private function finishPair(name:String):void {
            context.setScissorRectangle(null);
            var saved:BitmapData = capture(64, 64);
            context.present();
            trace("BATCH_GATE_AFTER_PRESENT " + name);
            pixel(name + ".left", saved, 16, 32, 0xffff0000);
            pixel(name + ".right", saved, 48, 32, 0xff00ff00);
            card(name, saved);
        }

        // Only queues a GPU readback. Never inspect, draw, clone or upload the
        // result here: its first CPU read must remain after the tested barrier.
        private function capture(width:int, height:int):BitmapData {
            var result:BitmapData = new BitmapData(width, height, true, 0xff808080);
            context.drawToBitmapData(result);
            return result;
        }

        private function pixel(name:String, bitmap:BitmapData, x:int, y:int, expected:uint):void {
            var actual:uint = bitmap.getPixel32(x, y);
            var pass:Boolean = actual == expected;
            checks++;
            if (!pass) failures++;
            trace("BATCH_PIXEL " + name + " x=" + x + " y=" + y
                + " expected=" + hex(expected) + " actual=" + hex(actual)
                + " result=" + (pass ? "PASS" : "FAIL"));
        }

        private function card(name:String, bitmap:BitmapData):void {
            cards.push({name:name, bitmap:bitmap});
        }

        private function showResults():void {
            graphics.beginFill(0x202020);
            graphics.drawRect(0, 0, 550, 400);
            graphics.endFill();
            label("Stage3D ordering: " + checks + " checks, " + failures + " failures", 10, 8, 530);
            label("AA4 requested; actual sample count not verified", 10, 31, 530);
            for (var i:int = 0; i < cards.length; i++) {
                var x:int = 10 + (i % 5) * 108;
                var y:int = 55 + int(i / 5) * 103;
                label(cards[i].name, x, y, 105);
                var view:Bitmap = new Bitmap(cards[i].bitmap);
                view.x = x;
                view.y = y + 25;
                addChild(view);
            }
            label("A: red. B: blue. Upload/target pairs: red | green.", 10, 375, 530);
        }

        private function label(text:String, x:int, y:int, width:int):void {
            var field:TextField = new TextField();
            field.defaultTextFormat = new TextFormat("_sans", 14, 0xffffff);
            field.text = text;
            field.selectable = false;
            field.mouseEnabled = false;
            field.x = x;
            field.y = y;
            field.width = width;
            field.height = 23;
            addChild(field);
        }

        private function color(r:Number, g:Number, b:Number):void {
            context.setProgramConstantsFromVector("fragment", 0, Vector.<Number>([r, g, b, 1]), 1);
        }

        private function bind(vertices:VertexBuffer3D):void {
            context.setVertexBufferAt(0, vertices, 0, "float4");
            context.setVertexBufferAt(1, vertices, 4, "float2");
        }

        private function makeVertices(data:Vector.<Number>, count:int):VertexBuffer3D {
            var vertices:VertexBuffer3D = context.createVertexBuffer(count, 6);
            vertices.uploadFromVector(data, 0, count);
            return vertices;
        }

        private function quad(left:Number, right:Number):Vector.<Number> {
            return Vector.<Number>([
                left, 1, 0, 1, 0, 0, right, 1, 0, 1, 1, 0,
                left, -1, 0, 1, 0, 1, right, -1, 0, 1, 1, 1
            ]);
        }

        private function indices(base:uint):Vector.<uint> {
            return Vector.<uint>([base, base + 1, base + 2, base + 2, base + 1, base + 3]);
        }

        private function hex(value:uint):String {
            var result:String = value.toString(16);
            while (result.length < 8) result = "0" + result;
            return result;
        }

        // Tiny original AGAL1 writer: only mov and tex. Register and operand
        // encoding follows render/naga-agal/src/types.rs in the reviewed runtime.
        private function shaderHeader(fragment:Boolean):ByteArray {
            var bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            bytes.writeByte(0xa0);
            bytes.writeUnsignedInt(1);
            bytes.writeByte(0xa1);
            bytes.writeByte(fragment ? 1 : 0);
            return bytes;
        }

        private function move(bytes:ByteArray, destinationType:uint, sourceType:uint, sourceIndex:uint):void {
            bytes.writeUnsignedInt(0);
            bytes.writeUnsignedInt((destinationType << 24) | 0x000f0000);
            bytes.writeUnsignedInt(0xe4000000 | sourceIndex);
            bytes.writeUnsignedInt(sourceType);
            bytes.writeUnsignedInt(0);
            bytes.writeUnsignedInt(0);
        }

        private function vertexShader():ByteArray {
            var bytes:ByteArray = shaderHeader(false);
            move(bytes, 3, 0, 0); // mov op, va0
            move(bytes, 4, 0, 1); // mov v0, va1
            bytes.position = 0;
            return bytes;
        }

        private function fragmentShader(texture:Boolean):ByteArray {
            var bytes:ByteArray = shaderHeader(true);
            if (texture) {
                bytes.writeUnsignedInt(0x28); // tex oc, v0, fs0
                bytes.writeUnsignedInt(0x030f0000);
                bytes.writeUnsignedInt(0xe4000000);
                bytes.writeUnsignedInt(4);
                bytes.writeUnsignedInt(0);
                bytes.writeUnsignedInt(5); // 2D, clamp, nearest, no mipmaps
            } else {
                move(bytes, 3, 1, 0); // mov oc, fc0
            }
            bytes.position = 0;
            return bytes;
        }
    }
}
