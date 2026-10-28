package {
    import flash.display.Sprite;
    import flash.utils.Dictionary;

    // Original regression fixture. No purchased game code or assets.
    public class ConditionGuardProbe extends Sprite {
        private var checks:int = 0;
        private var failures:int = 0;

        public function ConditionGuardProbe() {
            var any:Vector.<*> = new Vector.<*>();
            any.push("beast", 7, null);
            compare("wildcard match", any, "beast", true);
            compare("wildcard miss", any, "undead", false);
            compare("string conversion", any, "7", true);
            compare("null member", any, "null", true);
            var objects:Vector.<Object> = new Vector.<Object>();
            objects.push("beast");
            compare("object vector", objects, "beast", true);
            var strings:Vector.<String> = new Vector.<String>();
            strings.push("beast");
            compare("string vector", strings, "beast", true);
            compare("empty vector", new Vector.<*>(), "beast", false);
            compare("plain object", {monsterDeath:3}, "beast", false);
            compare("array", ["beast"], "beast", false);
            var dictionary:Dictionary = new Dictionary();
            dictionary["kind"] = "beast";
            compare("dictionary", dictionary, "beast", false);
            compare("null", null, "beast", false);
            compare("undefined", undefined, "beast", false);
            compare("number", 7, "7", false);
            compare("string", "beast", "beast", false);
            trace("CONDITION_GUARD_DONE", checks, failures);
        }

        private function compare(label:String, value:*, needle:*, expected:Boolean):void {
            var oldResult:Boolean;
            try { oldResult = typedContains(value, needle); }
            catch (error:Error) { oldResult = false; }
            var newResult:Boolean = guardedContains(value, needle);
            var good:Boolean = oldResult === expected && newResult === expected;
            checks++;
            if (!good) failures++;
            trace("CONDITION_GUARD", label, good ? "PASS" : "FAIL");
        }

        private function typedContains(values:Vector.<*>, needle:*):Boolean {
            for each (var value:* in values) {
                if (String(value) == String(needle)) return true;
            }
            return false;
        }

        private function guardedContains(values:Object, needle:*):Boolean {
            if (!(values is Vector.<*>)) return false;
            for each (var value:* in values) {
                if (String(value) == String(needle)) return true;
            }
            return false;
        }
    }
}
