# Portal App

## Supabase Godot Employee Portal Scaffold

This scaffold gives the project a clean Godot-side backend layer for the employee portal schema.

## Files

Copy these folders into your Godot project:

- `data/supabase/`
- `data/models/`
- `data/repositories/`
- `ui/screens/auth/`

## Required autoloads

Add these in **Project > Project Settings > Globals > Autoload**:

| Name | Path |
|---|---|
| `SupabaseClient` | `res://data/supabase/supabase_client.gd` |
| `ProfileRepository` | `res://data/repositories/profile_repository.gd` |
| `OrganizationRepository` | `res://data/repositories/organization_repository.gd` |

Keep your existing `ToastManager` autoload.

## Required Project Settings

Add these custom settings in **Project Settings > General > Advanced Settings enabled**:

| Setting | Value |
|---|---|
| `application/supabase/url` | Your Supabase project URL |
| `application/supabase/publishable_key` | Your Supabase publishable key, or legacy anon key |

Never put a Supabase secret key or service_role key in the Godot client.

## Minimal startup flow

1. Run the SQL migration in Supabase.
2. Configure the project URL and publishable key.
3. Add the autoloads.
4. Create a scene with an `AuthScreen` node, or attach `ui/screens/auth/auth_screen.gd` to a `Control`.
5. Sign up or sign in.
6. After first login, call `OrganizationRepository.create_organization("Your Company")` to create the first workspace.

## Example usage

```gdscript
func _ready() -> void:
	var profile_result: SupabaseResult = await ProfileRepository.fetch_current_profile()
	if profile_result.ok:
		var profile: Profile = profile_result.data
		print(profile.display_name)

	var org_result: SupabaseResult = await OrganizationRepository.list_my_organizations()
	if org_result.ok:
		var organizations: Array[Organization] = org_result.data
		print(organizations.size())
```
