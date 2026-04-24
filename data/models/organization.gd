@tool
class_name Organization
extends Resource

@export var id: String = "":
	set(value):
		id = value.strip_edges()
		emit_changed()

@export var name: String = "":
	set(value):
		name = value.strip_edges()
		emit_changed()

@export var slug: String = "":
	set(value):
		slug = value.strip_edges().to_lower()
		emit_changed()

@export var created_by: String = ""
@export var created_at: String = ""
@export var updated_at: String = ""

func is_valid() -> bool:
	return not id.is_empty() and not name.is_empty() and not slug.is_empty()

func to_insert_dictionary(creator_user_id: String) -> Dictionary:
	return {
		"name": name.strip_edges(),
		"slug": slug.strip_edges().to_lower(),
		"created_by": creator_user_id.strip_edges()
	}

static func from_dictionary(payload: Dictionary) -> Organization:
	var organization: Organization = Organization.new()
	organization.id = _read_string(payload, "id")
	organization.name = _read_string(payload, "name")
	organization.slug = _read_string(payload, "slug")
	organization.created_by = _read_string(payload, "created_by")
	organization.created_at = _read_string(payload, "created_at")
	organization.updated_at = _read_string(payload, "updated_at")
	return organization

static func slugify(value: String) -> String:
	var lower_value: String = value.strip_edges().to_lower()
	var output: String = ""
	var previous_was_dash: bool = false

	for index: int in range(lower_value.length()):
		var character: String = lower_value[index]
		var allowed: bool = (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		if allowed:
			output += character
			previous_was_dash = false
		elif not previous_was_dash:
			output += "-"
			previous_was_dash = true

	output = output.strip_edges().trim_prefix("-").trim_suffix("-")
	while output.length() < 3:
		output += "0"

	if output.length() > 63:
		output = output.substr(0, 63).trim_suffix("-")

	return output

static func _read_string(payload: Dictionary, key: String, fallback: String = "") -> String:
	var value: Variant = payload.get(key, fallback)
	if value == null:
		return fallback
	return String(value).strip_edges()
