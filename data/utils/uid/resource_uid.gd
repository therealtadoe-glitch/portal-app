@tool
class_name ResourceUid
extends Resource

@export var uid: String = ""

func _init() -> void:
	_ensure_uid()

func _get_property_list() -> Array[Dictionary]:
	_ensure_uid()
	return []

func _validate_property(property: Dictionary) -> void:
	if property.name == "uid":
		property.usage |= PROPERTY_USAGE_READ_ONLY

func _ensure_uid() -> void:
	if uid.is_empty():
		uid = Uid.generate_uuid_v7()
