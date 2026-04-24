class_name AppOrganizationRepository
extends Node

signal organizations_loaded(organizations: Array[Organization])
signal organization_created(organization: Organization)

@export var client_path: NodePath = ^"/root/SupabaseClient"

var cached_organizations: Array[Organization] = []

func create_organization(_name: String, requested_slug: String = "") -> SupabaseResult:
	var client: AppSupabaseClient = _get_client()
	if client == null:
		return SupabaseResult.failure(0, "SupabaseClient autoload was not found.")

	var user_id: String = client.get_user_id()
	if user_id.is_empty():
		return SupabaseResult.failure(401, "Not authenticated.")

	var clean_name: String = _name.strip_edges()
	if clean_name.length() < 2:
		return SupabaseResult.failure(0, "Organization name must be at least 2 characters.")

	var clean_slug: String = requested_slug.strip_edges().to_lower()
	if clean_slug.is_empty():
		clean_slug = Organization.slugify(clean_name)

	var organization: Organization = Organization.new()
	organization.name = clean_name
	organization.slug = clean_slug

	var result: SupabaseResult = await client.insert_row(
		"organizations",
		organization.to_insert_dictionary(user_id)
	)

	if not result.ok:
		return result

	var row: Dictionary = result.first_dictionary()
	if row.is_empty():
		return SupabaseResult.failure(404, "Created organization row was not returned.", result.data, result.raw_body)

	var created: Organization = Organization.from_dictionary(row)
	cached_organizations.append(created)
	organization_created.emit(created)
	return SupabaseResult.success(result.status_code, created, result.raw_body)

func list_my_organizations() -> SupabaseResult:
	var client: AppSupabaseClient = _get_client()
	if client == null:
		return SupabaseResult.failure(0, "SupabaseClient autoload was not found.")

	var result: SupabaseResult = await client.select_rows("organizations", {
		"select": "*",
		"order": "created_at.desc"
	})

	if not result.ok:
		return result

	var output: Array[Organization] = []
	for row_value: Variant in result.as_array():
		if row_value is Dictionary:
			output.append(Organization.from_dictionary(row_value))

	cached_organizations = output
	organizations_loaded.emit(cached_organizations)
	return SupabaseResult.success(result.status_code, cached_organizations, result.raw_body)

func _get_client() -> AppSupabaseClient:
	return get_node_or_null(client_path) as AppSupabaseClient
