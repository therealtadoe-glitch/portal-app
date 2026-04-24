@tool
class_name Uid
extends RefCounted

static var _rng: RandomNumberGenerator = _create_rng()

static func _create_rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng

static func generate_uuid_v7() -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(16)

	var timestamp_ms: int = int(Time.get_unix_time_from_system() * 1000.0)

	bytes[0] = (timestamp_ms >> 40) & 0xFF
	bytes[1] = (timestamp_ms >> 32) & 0xFF
	bytes[2] = (timestamp_ms >> 24) & 0xFF
	bytes[3] = (timestamp_ms >> 16) & 0xFF
	bytes[4] = (timestamp_ms >> 8) & 0xFF
	bytes[5] = timestamp_ms & 0xFF

	for index: int in range(6, 16):
		bytes[index] = _rng.randi_range(0, 255)

	bytes[6] = (bytes[6] & 0x0F) | 0x70
	bytes[8] = (bytes[8] & 0x3F) | 0x80

	return _format_uuid(bytes)

static func generate_uuid_v4() -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(16)

	for index: int in range(16):
		bytes[index] = _rng.randi_range(0, 255)

	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80

	return _format_uuid(bytes)

static func assign_if_missing(resource: Resource, property_name: StringName = &"uid", use_uuid_v7: bool = true) -> String:
	if resource == null:
		return ""

	if not _has_string_property(resource, property_name):
		push_warning("ResourceUid.assign_if_missing: Resource does not contain a String property named '%s'." % String(property_name))
		return ""

	var current_value: Variant = resource.get(property_name)
	var current_uid: String = String(current_value).strip_edges()

	if not current_uid.is_empty():
		if String(current_value) != current_uid:
			resource.set(property_name, current_uid)
			resource.emit_changed()
		return current_uid

	var new_uid: String = generate_uuid_v7() if use_uuid_v7 else generate_uuid_v4()
	resource.set(property_name, new_uid)
	resource.emit_changed()
	return new_uid

static func regenerate(resource: Resource, property_name: StringName = &"uid", use_uuid_v7: bool = true) -> String:
	if resource == null:
		return ""

	if not _has_string_property(resource, property_name):
		push_warning("ResourceUid.regenerate: Resource does not contain a String property named '%s'." % String(property_name))
		return ""

	var new_uid: String = generate_uuid_v7() if use_uuid_v7 else generate_uuid_v4()
	resource.set(property_name, new_uid)
	resource.emit_changed()
	return new_uid

static func has_uid(resource: Resource, property_name: StringName = &"uid") -> bool:
	if resource == null:
		return false

	if not _has_string_property(resource, property_name):
		return false

	return not String(resource.get(property_name)).strip_edges().is_empty()

static func validate_uid(uid: String, allow_v4: bool = true, allow_v7: bool = true) -> bool:
	var value: String = uid.strip_edges().to_lower()
	if value.length() != 36:
		return false

	if value[8] != "-" or value[13] != "-" or value[18] != "-" or value[23] != "-":
		return false

	var compact: String = value.replace("-", "")
	if compact.length() != 32:
		return false

	for char_index: int in range(compact.length()):
		var char_value: String = compact[char_index]
		if not ((char_value >= "0" and char_value <= "9") or (char_value >= "a" and char_value <= "f")):
			return false

	var version: String = value[14]
	if version == "4":
		return allow_v4
	if version == "7":
		return allow_v7

	return false

static func _has_string_property(target: Object, property_name: StringName) -> bool:
	for property_info: Dictionary in target.get_property_list():
		var info_name: Variant = property_info.get("name", "")
		var info_type: int = int(property_info.get("type", TYPE_NIL))
		if StringName(String(info_name)) == property_name and info_type == TYPE_STRING:
			return true
	return false

static func _format_uuid(bytes: PackedByteArray) -> String:
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]
