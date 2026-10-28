use flash_lso::read::Reader;
use flash_lso::types::{AMFVersion, Element, Lso, ObjectId, Value};
use std::rc::Rc;

fn check_prefix(prefix: Vec<Value>) {
    let mut body: Vec<Element> = prefix.into_iter().enumerate()
        .map(|(i,v)| Element::new(format!("prefix{i}"), Rc::new(v))).collect();
    let vector = Rc::new(Value::VectorObject(ObjectId::INVALID,
        vec![Rc::new(Value::String("selected-power".into()))], String::new(), false));
    let dictionary = Rc::new(Value::Dictionary(ObjectId::INVALID,
        vec![(Rc::new(Value::String("power".into())), vector.clone())], false));
    let at = body.len();
    body.push(Element::new("vector", vector.clone()));
    body.push(Element::new("dictionary", dictionary.clone()));
    body.push(Element::new("vectorAgain", vector));
    body.push(Element::new("dictionaryAgain", dictionary));
    let mut lso = Lso::new(body, "original-writer-probe", AMFVersion::AMF3);
    let bytes = flash_lso::write::write_to_bytes(&mut lso).unwrap();
    let decoded = Reader::default().parse(&bytes).unwrap();
    let vector_id = match decoded.body[at].value.as_ref() {
        Value::VectorObject(id, values, _, _) => {
            assert_eq!(values[0].as_ref(), &Value::String("selected-power".into()));
            *id
        }
        other => panic!("Expected first vector, got {other:?}"),
    };
    let dictionary_id = match decoded.body[at+1].value.as_ref() {
        Value::Dictionary(id, values, _) => {
            assert_eq!(values[0].1.as_ref(), &Value::Amf3ObjectReference(vector_id));
            *id
        }
        other => panic!("Expected first dictionary, got {other:?}"),
    };
    assert_eq!(decoded.body[at+2].value.as_ref(), &Value::Amf3ObjectReference(vector_id));
    assert_eq!(decoded.body[at+3].value.as_ref(), &Value::Amf3ObjectReference(dictionary_id));
}

#[test]
fn references_after_equal_inline_containers() {
    let empty = Value::ECMAArray(ObjectId::INVALID, vec![], vec![], 0);
    let object = Value::Object(ObjectId::INVALID, vec![], None);
    check_prefix(vec![empty.clone(), empty, object.clone(), object]);
}

#[test]
fn references_after_inline_scalar_containers() {
    check_prefix(vec![Value::VectorInt(vec![1], false),
        Value::VectorUInt(vec![2], true), Value::VectorDouble(vec![3.0], false),
        Value::Date(1234.0, None), Value::ByteArray(vec![1,2,3]),
        Value::XML("<original/>".into(), true)]);
}

#[test]
fn references_without_prefix_control() { check_prefix(vec![]); }
