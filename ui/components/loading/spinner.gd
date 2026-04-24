@tool
extends Control
class_name LoadingSpinner

signal animation_looped

const _GLOW_NODE_NAME: StringName = "_GlowLayer"

#region SHADER_CODE

const _GLOW_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 arc_center = vec2(48.0, 48.0);
uniform float radius = 28.0;
uniform float line_width = 4.0;

uniform float start_angle = 0.0;
uniform float arc_length = 2.2;

uniform vec4 primary_color : source_color = vec4(0.40, 0.99, 0.42, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.12, 0.65, 0.29, 1.0);
uniform vec4 glow_color : source_color = vec4(0.43, 1.0, 0.58, 1.0);

uniform float overall_opacity = 1.0;
uniform float glow_opacity = 0.18;
uniform float tail_fade = 0.95;

uniform float outer_glow_size = 16.0;
uniform float inner_glow_size = 10.0;
uniform float outer_glow_strength = 1.0;
uniform float inner_glow_strength = 0.65;
uniform float glow_falloff = 2.8;

uniform float angular_softness = 0.06;
uniform vec2 rect_size = vec2(96.0, 96.0);
uniform float head_cap_radius = 2.0;

float angle_mod(float a) {
	return mod(a + TAU, TAU);
}

float angle_delta_ccw(float from_angle, float to_angle) {
	return mod(to_angle - from_angle + TAU, TAU);
}

void fragment() {
	vec2 pos = UV * rect_size;
	vec2 to_pixel = pos - arc_center;

	float dist = length(to_pixel);
	float pixel_angle = angle_mod(atan(to_pixel.y, to_pixel.x));
	float delta = angle_delta_ccw(start_angle, pixel_angle);

	float safe_arc = max(arc_length, 0.0001);
	float t = clamp(delta / safe_arc, 0.0, 1.0);

	float inside_arc = step(delta, safe_arc);
	float tail_soft = smoothstep(0.0, angular_softness, delta);

	float half_line = line_width * 0.5;
	float radial_delta = dist - radius;
	float abs_radial_delta = abs(radial_delta);

	float ring_mask = inside_arc * tail_soft;

	float outer_profile = 0.0;
	if (outer_glow_size > 0.0) {
		float outer_range = half_line + outer_glow_size;
		outer_profile = 1.0 - smoothstep(half_line, outer_range, abs_radial_delta);
		outer_profile *= step(0.0, radial_delta);
		outer_profile = pow(max(outer_profile, 0.0), glow_falloff) * outer_glow_strength;
	}

	float inner_profile = 0.0;
	if (inner_glow_size > 0.0) {
		float inner_range = half_line + inner_glow_size;
		inner_profile = 1.0 - smoothstep(half_line, inner_range, abs_radial_delta);
		inner_profile *= step(radial_delta, 0.0);
		inner_profile = pow(max(inner_profile, 0.0), glow_falloff) * inner_glow_strength;
	}

	float ring_glow = max(outer_profile, inner_profile) * ring_mask;

	float end_angle = start_angle + safe_arc;
	vec2 head_center = arc_center + vec2(cos(end_angle), sin(end_angle)) * radius;
	float head_dist = distance(pos, head_center);

	float head_outer = 0.0;
	if (outer_glow_size > 0.0) {
		float outer_cap_range = head_cap_radius + outer_glow_size;
		head_outer = 1.0 - smoothstep(head_cap_radius, outer_cap_range, head_dist);
		head_outer = pow(max(head_outer, 0.0), glow_falloff) * outer_glow_strength;
	}

	float head_inner = 0.0;
	if (inner_glow_size > 0.0) {
		float inner_cap_radius = max(head_cap_radius - inner_glow_size, 0.0);
		head_inner = 1.0 - smoothstep(inner_cap_radius, head_cap_radius, head_dist);
		head_inner = pow(max(head_inner, 0.0), glow_falloff) * inner_glow_strength;
	}

	float head_glow = max(head_outer, head_inner);

	float glow_profile = max(ring_glow, head_glow);
	float fade = mix(1.0 - tail_fade, 1.0, t);

	vec4 arc_blend = mix(primary_color, secondary_color, pow(t, 0.8));
	vec4 final_color = mix(arc_blend, glow_color, 0.72);

	float alpha = glow_profile * glow_opacity * overall_opacity * fade;
	COLOR = vec4(final_color.rgb, alpha);
}
"""
#endregion

@export_group("Colors")
@export_color_no_alpha var primary_color: Color = Color("3ca1fe"):
	set(value):
		primary_color = value
		_refresh_visuals()
@export var secondary_color: Color = Color("3461fd"):
	set(value):
		secondary_color = value
		_refresh_visuals()
@export var track_color: Color = Color("FFFF"):
	set(value):
		track_color = value
		_refresh_visuals()
@export var glow_color: Color = Color("3461fd"):
	set(value):
		glow_color = value
		_refresh_visuals()

@export_group("Transparency")
@export_range(0.0, 1.0, 0.01) var overall_opacity: float = 1.0:
	set(value):
		overall_opacity = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01) var track_opacity: float = 0.18:
	set(value):
		track_opacity = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01) var glow_opacity: float = 0.4:
	set(value):
		glow_opacity = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01) var center_dot_opacity: float = 0.95:
	set(value):
		center_dot_opacity = value
		_refresh_visuals()

@export_group("Layout")
@export_range(24.0, 512.0, 0.01, "prefer_slider", "or_greater") var indicator_size: float = 62.45:
	set(value):
		indicator_size = value
		custom_minimum_size = Vector2.ONE * indicator_size
		_refresh_visuals()
@export_range(0.15, 0.95, 0.01, "prefer_slider", "or_less", "or_greater") var radius_ratio: float = 0.93:
	set(value):
		radius_ratio = value
		_refresh_visuals()
@export_range(0.5, 32.0, 0.01, "or_less", "or_greater", "prefer_slider") var line_width: float = 2.47:
	set(value):
		line_width = value
		_refresh_visuals()
@export_range(0.0, 64.0, 0.01) var padding: float = 0.0:
	set(value):
		padding = value
		_refresh_visuals()

@export_group("Line Taper")
@export var use_line_taper: bool = true:
	set(value):
		use_line_taper = value
		_refresh_visuals()
@export_range(0.01, 1.0, 0.01, "prefer_slider") var tail_width_ratio: float = 0.43:
	set(value):
		tail_width_ratio = value
		_refresh_visuals()
@export_range(0.1, 4.0, 0.01) var taper_curve: float = 1.9:
	set(value):
		taper_curve = value
		_refresh_visuals()
@export var round_head_cap: bool = true:
	set(value):
		round_head_cap = value
		_refresh_visuals()
@export var round_tail_cap: bool = true:
	set(value):
		round_tail_cap = value
		_refresh_visuals()

@export_group("Glow")
@export var show_glow: bool = true:
	set(value):
		show_glow = value
		_refresh_visuals()
@export_range(0.0, 64.0, 0.01, "prefer_slider") var outer_glow_size: float = 10.27:
	set(value):
		outer_glow_size = value
		_refresh_visuals()
@export_range(0.0, 64.0, 0.01, "prefer_slider") var inner_glow_size: float = 5.55:
	set(value):
		inner_glow_size = value
		_refresh_visuals()
@export_range(0.01, 8.0, 0.01) var glow_falloff: float = 3.36:
	set(value):
		glow_falloff = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01) var outer_glow_strength: float = 1.0:
	set(value):
		outer_glow_strength = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01) var inner_glow_strength: float = 0.65:
	set(value):
		inner_glow_strength = value
		_refresh_visuals()
@export_range(0.001, 0.5, 0.001, "prefer_slider") var angular_softness: float = 0.5:
	set(value):
		angular_softness = value
		_refresh_visuals()

@export_group("Animation")
@export var playing: bool = true:
	set(value):
		playing = value
		set_process(playing or Engine.is_editor_hint())
		_refresh_visuals()
@export_range(1.0, 340.0, 0.01, "prefer_slider", "or_greater") var arc_length_degrees: float = 254.04:
	set(value):
		arc_length_degrees = value
		_refresh_visuals()
@export_range(0.1, 10.0, 0.01) var rotation_speed: float = 1.15:
	set(value):
		rotation_speed = value
		_refresh_visuals()
@export_range(0.0, 1.0, 0.01, "or_greater", "prefer_slider") var tail_fade: float = 0.95:
	set(value):
		tail_fade = value
		_refresh_visuals()
@export var use_pulse: bool = true:
	set(value):
		use_pulse = value
		_refresh_visuals()
@export_range(0.1, 8.0, 0.01) var pulse_speed: float = 0.55:
	set(value):
		pulse_speed = value
		_refresh_visuals()
@export_range(0.0, 0.35, 0.01) var pulse_amount: float = 0.015:
	set(value):
		pulse_amount = value
		_refresh_visuals()

@export_group("Extras")
@export var show_track: bool = false:
	set(value):
		show_track = value
		_refresh_visuals()
@export var show_head_dot: bool = true:
	set(value):
		show_head_dot = value
		_refresh_visuals()
@export var show_center_dot: bool = false:
	set(value):
		show_center_dot = value
		_refresh_visuals()
@export var clip_to_safe_bounds: bool = true:
	set(value):
		clip_to_safe_bounds = value
		_refresh_visuals()

@export_group("Editor")
@export var editor_preview_when_stopped: bool = true:
	set(value):
		editor_preview_when_stopped = value
		_refresh_visuals()

@export_group("Quality")
@export_range(16, 160, 1, "or_greater", "or_less") var arc_segments: int = 40:
	set(value):
		arc_segments = value
		_refresh_visuals()

var _time: float = 0.0
var _last_cycle_index: int = 0
var _glow_layer: ColorRect
var _glow_shader_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * indicator_size

	_ensure_internal_nodes()
	_sync_glow_rect()
	_sync_glow_shader()

	set_process(playing or Engine.is_editor_hint())
	_refresh_visuals()

func _enter_tree() -> void:
	_ensure_internal_nodes()
	_sync_glow_rect()
	_sync_glow_shader()


func _exit_tree() -> void:
	_glow_layer = null
	_glow_shader_material = null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_sync_glow_rect()
			_sync_glow_shader()
			queue_redraw()

		NOTIFICATION_THEME_CHANGED:
			_refresh_visuals()

		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree():
				_refresh_visuals()


func _process(delta: float) -> void:
	#if Engine.is_editor_hint():
		#return
	var should_animate: bool = playing or (Engine.is_editor_hint() and editor_preview_when_stopped)
	if not should_animate:
		return

	_time += delta

	var cycle_progress: float = (_time * rotation_speed) / TAU
	var cycle_index: int = int(floor(cycle_progress))

	if cycle_index != _last_cycle_index:
		_last_cycle_index = cycle_index
		animation_looped.emit()

	_sync_glow_shader()
	queue_redraw()

# ========================
# INTERNAL NODES
# ========================

func _ensure_internal_nodes() -> void:
	if _glow_layer != null and is_instance_valid(_glow_layer):
		if _glow_shader_material == null or not is_instance_valid(_glow_shader_material):
			_assign_glow_material()
		return

	var existing: Node = get_node_or_null(NodePath(_GLOW_NODE_NAME))

	if existing is ColorRect:
		_glow_layer = existing as ColorRect
	else:
		_glow_layer = ColorRect.new()
		_glow_layer.name = _GLOW_NODE_NAME
		_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow_layer.color = Color.WHITE
		_glow_layer.show_behind_parent = true
		_glow_layer.z_index = -1

		add_child(_glow_layer, false, Node.INTERNAL_MODE_BACK)

	_sync_glow_rect()
	_assign_glow_material()


func _assign_glow_material() -> void:
	if _glow_layer == null or not is_instance_valid(_glow_layer):
		return

	var shader: Shader = Shader.new()
	shader.code = _GLOW_SHADER_CODE

	_glow_shader_material = ShaderMaterial.new()
	_glow_shader_material.shader = shader
	_glow_layer.material = _glow_shader_material


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()

	if show_glow and outer_glow_size <= 0.0 and inner_glow_size <= 0.0:
		warnings.append("Glow is enabled, but both glow sizes are zero.")

	if radius_ratio > 0.9 and (outer_glow_size > 20.0 or padding < 4.0):
		warnings.append("High radius_ratio with large glow may clip inside tight layouts.")

	if line_width <= 1.0 and tail_width_ratio < 0.1:
		warnings.append("Very thin line_width plus low tail_width_ratio may make the tail visually disappear.")

	return warnings


func _draw() -> void:
	var _rect: Rect2 = _get__rect()
	var center: Vector2 = size * 0.5
	var radius: float = _get_current_radius(_rect)
	var start_angle: float = _get_start_angle()
	var arc_length: float = deg_to_rad(arc_length_degrees)
	var end_angle: float = start_angle + arc_length

	if show_track:
		var track: Color = track_color
		track.a *= overall_opacity * track_opacity
		draw_arc(center, radius, 0.0, TAU, maxi(arc_segments, 96), track, line_width, true)

	_draw_gradient_tapered_arc(center, radius, start_angle, end_angle)

	if round_head_cap:
		var head_pos: Vector2 = center + Vector2.RIGHT.rotated(end_angle) * radius
		var head_color: Color = secondary_color
		head_color.a *= overall_opacity
		draw_circle(head_pos, maxf(_width_at(1.0) * 0.5, 1.0), head_color)

	if round_tail_cap:
		var tail_pos: Vector2 = center + Vector2.RIGHT.rotated(start_angle) * radius
		var tail_color: Color = primary_color
		tail_color.a *= overall_opacity * maxf(1.0 - tail_fade, 0.0)
		draw_circle(tail_pos, maxf(_width_at(0.0) * 0.5, 1.0), tail_color)

	if show_head_dot:
		var head_dot_pos: Vector2 = center + Vector2.RIGHT.rotated(end_angle) * radius
		var head_dot_color: Color = secondary_color
		head_dot_color.a *= overall_opacity
		draw_circle(head_dot_pos, maxf(_width_at(1.0) * 0.5, 1.0), head_dot_color)


func _draw_gradient_tapered_arc(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var segments: int = maxi(arc_segments, 8)
	var total_angle: float = end_angle - start_angle

	for i: int in range(segments):
		var from_t: float = float(i) / float(segments)
		var to_t: float = float(i + 1) / float(segments)
		var a0: float = start_angle + total_angle * from_t
		var a1: float = start_angle + total_angle * to_t

		var fade: float = lerpf(1.0 - tail_fade, 1.0, to_t)

		var c: Color = primary_color.lerp(secondary_color, ease(to_t, 0.8))
		c.a *= overall_opacity * fade

		var width: float = _width_at(to_t)
		draw_arc(center, radius, a0, a1, 4, c, width, true)


func _width_at(t: float) -> float:
	var min_width: float = maxf(line_width * tail_width_ratio, 0.001)
	var max_width: float = maxf(line_width, min_width)

	if not use_line_taper:
		return max_width

	return lerpf(min_width, max_width, ease(clampf(t, 0.0, 1.0), taper_curve))


func _max_visual_extent() -> float:
	return maxf(
		line_width * 0.5 + outer_glow_size,
		line_width * 0.5
	)


func _get_minimum_size() -> Vector2:
	return Vector2.ONE * indicator_size


# ========================
# FIXED LAYOUT (CRITICAL)
# ========================

func _sync_glow_rect() -> void:
	if _glow_layer == null or not is_instance_valid(_glow_layer):
		return

	_glow_layer.anchor_left = 0.0
	_glow_layer.anchor_top = 0.0
	_glow_layer.anchor_right = 1.0
	_glow_layer.anchor_bottom = 1.0

	_glow_layer.offset_left = 0.0
	_glow_layer.offset_top = 0.0
	_glow_layer.offset_right = 0.0
	_glow_layer.offset_bottom = 0.0

	_glow_layer.visible = show_glow and glow_opacity > 0.001


func _refresh_visuals() -> void:
	if not is_inside_tree():
		return

	custom_minimum_size = Vector2.ONE * indicator_size

	_ensure_internal_nodes()
	_sync_glow_rect()
	_sync_glow_shader()

	update_configuration_warnings()
	queue_redraw()

func _sync_glow_shader() -> void:
	if _glow_shader_material == null or not is_instance_valid(_glow_shader_material):
		return

	var _rect: Rect2 = _get__rect()
	var center: Vector2 = size * 0.5
	var radius: float = _get_current_radius(_rect)
	var start_angle: float = _get_start_angle()

	_glow_layer.visible = show_glow and glow_opacity > 0.001

	_glow_shader_material.set_shader_parameter("arc_center", center)
	_glow_shader_material.set_shader_parameter("radius", radius)
	_glow_shader_material.set_shader_parameter("line_width", line_width)
	_glow_shader_material.set_shader_parameter("start_angle", start_angle)
	_glow_shader_material.set_shader_parameter("arc_length", deg_to_rad(arc_length_degrees))
	_glow_shader_material.set_shader_parameter("primary_color", primary_color)
	_glow_shader_material.set_shader_parameter("secondary_color", secondary_color)
	_glow_shader_material.set_shader_parameter("glow_color", glow_color)
	_glow_shader_material.set_shader_parameter("overall_opacity", overall_opacity)
	_glow_shader_material.set_shader_parameter("glow_opacity", glow_opacity)
	_glow_shader_material.set_shader_parameter("tail_fade", tail_fade)
	_glow_shader_material.set_shader_parameter("outer_glow_size", outer_glow_size)
	_glow_shader_material.set_shader_parameter("inner_glow_size", inner_glow_size)
	_glow_shader_material.set_shader_parameter("outer_glow_strength", outer_glow_strength)
	_glow_shader_material.set_shader_parameter("inner_glow_strength", inner_glow_strength)
	_glow_shader_material.set_shader_parameter("glow_falloff", glow_falloff)
	_glow_shader_material.set_shader_parameter("angular_softness", angular_softness)
	_glow_shader_material.set_shader_parameter("rect_size", size)
	_glow_shader_material.set_shader_parameter("head_cap_radius", maxf(_width_at(1.0) * 0.5, 1.0))


func _get__rect() -> Rect2:
	var _rect: Rect2 = Rect2(Vector2.ZERO, size)
	if clip_to_safe_bounds:
		_rect = _rect.grow(-padding)
	return _rect


func _get_current_radius(_rect: Rect2) -> float:
	var max_radius: float = minf(_rect.size.x, _rect.size.y) * 0.5
	max_radius = maxf(max_radius - _max_visual_extent(), 1.0)
	return maxf(max_radius * radius_ratio * _get_pulse_scale(), 1.0)


func _get_pulse_scale() -> float:
	if not use_pulse:
		return 1.0
	return 1.0 + sin(_time * pulse_speed * TAU) * pulse_amount


func _get_start_angle() -> float:
	return _time * rotation_speed * TAU - deg_to_rad(90.0)
