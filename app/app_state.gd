class_name AppState
extends Resource


var profile: Profile:
	set(value):
		profile = value
		emit_changed()
		changed.emit()

var organizations: Array[Organization] = []:
	set(value):
		organizations = value.duplicate()
		emit_changed()
		changed.emit()

var current_organization: Organization:
	set(value):
		current_organization = value
		emit_changed()
		changed.emit()


func clear() -> void:
	profile = null
	organizations = []
	current_organization = null
	emit_changed()
	changed.emit()


func has_profile() -> bool:
	return profile != null and profile.is_valid()


func has_workspace() -> bool:
	return current_organization != null and current_organization.is_valid()


func set_organizations(value: Array[Organization]) -> void:
	organizations = value.duplicate()
	if organizations.is_empty():
		current_organization = null
	elif current_organization == null or not _contains_organization(current_organization.id):
		current_organization = organizations[0]
	emit_changed()
	changed.emit()


func select_organization_by_id(organization_id: String) -> bool:
	var clean_id: String = organization_id.strip_edges()
	if clean_id.is_empty():
		return false

	for organization: Organization in organizations:
		if organization != null and organization.id == clean_id:
			current_organization = organization
			emit_changed()
			changed.emit()
			return true

	return false


func select_first_organization() -> bool:
	if organizations.is_empty():
		current_organization = null
		emit_changed()
		changed.emit()
		return false

	current_organization = organizations[0]
	emit_changed()
	changed.emit()
	return true


func _contains_organization(organization_id: String) -> bool:
	for organization: Organization in organizations:
		if organization != null and organization.id == organization_id:
			return true
	return false
