package {
    import flash.display.Sprite;
    import flash.net.SharedObject;
    import flash.utils.Dictionary;

    // Original synthetic regression fixture. Contains no purchased game data.
    public class AmfReferenceProbe extends Sprite {
        public function AmfReferenceProbe() {
            var store:SharedObject = SharedObject.getLocal("originalAmfReferenceProbe");
            if (store.data.hasOwnProperty("phase")) {
                if (store.data.phase !== 1) {
                    trace("AMF_REFS_UNEXPECTED_PHASE");
                    return;
                }
                var firstDictionary:* = store.data.dictionary;
                var secondDictionary:* = store.data.dictionaryAlias;
                var dictionaries:Boolean = firstDictionary is Dictionary &&
                    secondDictionary is Dictionary &&
                    firstDictionary["sentinel"] === 73 &&
                    secondDictionary["sentinel"] === 73;
                check("dictionaryValues", dictionaries);
                check("dictionaryIdentity", dictionaries && firstDictionary === secondDictionary);

                var firstVector:* = store.data.vector;
                var secondVector:* = store.data.vectorAlias;
                var vectors:Boolean = firstVector is Vector.<Object> &&
                    secondVector is Vector.<Object> &&
                    firstVector.length === 1 && secondVector.length === 1 &&
                    firstVector[0] === "reference-probe" &&
                    secondVector[0] === "reference-probe";
                check("vectorValues", vectors);
                check("vectorIdentity", vectors && firstVector === secondVector);

                var nested:* = store.data.withinRoot;
                var withinRoot:Boolean = nested != null && nested.first != null &&
                    nested.second != null && nested.first["sentinel"] === 19 &&
                    nested.second["sentinel"] === 19 &&
                    nested.first === nested.second;
                check("withinRootControl", withinRoot);
                trace("AMF_REFS_READ_DONE");
                return;
            }

            var dictionary:Dictionary = new Dictionary();
            dictionary["sentinel"] = 73;
            var vector:Vector.<Object> = new Vector.<Object>();
            vector.push("reference-probe");
            var inside:Dictionary = new Dictionary();
            inside["sentinel"] = 19;
            store.data.dictionary = dictionary;
            store.data.dictionaryAlias = dictionary;
            store.data.vector = vector;
            store.data.vectorAlias = vector;
            store.data.withinRoot = {first:inside, second:inside};
            store.data.phase = 1;
            trace("AMF_REFS_WRITE", store.flush());
        }

        private function check(label:String, result:Boolean):void {
            trace("AMF_REFS_CHECK", label, result ? "PASS" : "FAIL");
        }
    }
}
