class_name SupabaseResult
extends RefCounted

var ok: bool = false
var status_code: int = 0
var data: Variant = null
var error_message: String = ""
var raw_body: String = ""


static func success(response_status_code: int, response_data: Variant = null, response_raw_body: String = "") -> SupabaseResult:
	var result: SupabaseResult = SupabaseResult.new()
	result.ok = true
	result.status_code = response_status_code
	result.data = response_data
	result.raw_body = response_raw_body
	return result


static func failure(response_status_code: int, message: String, response_data: Variant = null, response_raw_body: String = "") -> SupabaseResult:
	var result: SupabaseResult = SupabaseResult.new()
	result.ok = false
	result.status_code = response_status_code
	result.error_message = message.strip_edges()
	result.data = response_data
	result.raw_body = response_raw_body
	return result


func as_dictionary() -> Dictionary:
	if data is Dictionary:
		return data
	return {}


func as_array() -> Array:
	if data is Array:
		return data
	return []


func first_dictionary() -> Dictionary:
	var rows: Array = as_array()
	if rows.is_empty():
		return {}

	var first_item: Variant = rows[0]
	if first_item is Dictionary:
		return first_item

	return {}


func to_debug_string() -> String:
	if ok:
		return "HTTP %d OK" % status_code
	if error_message.is_empty():
		return "HTTP %d failed" % status_code
	return "HTTP %d: %s" % [status_code, error_message]


func _to_string() -> String:
	return to_debug_string()
