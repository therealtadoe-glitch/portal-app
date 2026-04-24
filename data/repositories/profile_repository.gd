class_name AppProfileRepository
extends Node

signal profile_loaded(profile: Profile)
signal profile_updated(profile: Profile)

@export var client_path: NodePath = ^"/root/SupabaseClient"

var cached_profile: Profile

func fetch_current_profile() -> SupabaseResult:
	var client: AppSupabaseClient = _get_client()
	if client == null:
		return SupabaseResult.failure(0, "SupabaseClient autoload was not found.")

	var user_id: String = client.get_user_id()
	if user_id.is_empty():
		return SupabaseResult.failure(401, "Not authenticated.")

	var result: SupabaseResult = await client.select_rows("profiles", {
		"select": "*",
		"id": "eq.%s" % user_id,
		"limit": "1"
	})

	if not result.ok:
		return result

	var row: Dictionary = result.first_dictionary()
	if row.is_empty():
		return SupabaseResult.failure(404, "Profile row was not found.", result.data, result.raw_body)

	cached_profile = Profile.from_dictionary(row)
	profile_loaded.emit(cached_profile)
	return SupabaseResult.success(result.status_code, cached_profile, result.raw_body)

func update_current_profile(profile: Profile) -> SupabaseResult:
	if profile == null:
		return SupabaseResult.failure(0, "Profile cannot be null.")

	var client: AppSupabaseClient = _get_client()
	if client == null:
		return SupabaseResult.failure(0, "SupabaseClient autoload was not found.")

	var user_id: String = client.get_user_id()
	if user_id.is_empty():
		return SupabaseResult.failure(401, "Not authenticated.")

	var result: SupabaseResult = await client.update_rows(
		"profiles",
		{"id": "eq.%s" % user_id},
		profile.to_update_dictionary()
	)

	if not result.ok:
		return result

	var row: Dictionary = result.first_dictionary()
	if row.is_empty():
		return SupabaseResult.failure(404, "Updated profile row was not returned.", result.data, result.raw_body)

	cached_profile = Profile.from_dictionary(row)
	profile_updated.emit(cached_profile)
	return SupabaseResult.success(result.status_code, cached_profile, result.raw_body)

func _get_client() -> AppSupabaseClient:
	return get_node_or_null(client_path) as AppSupabaseClient
