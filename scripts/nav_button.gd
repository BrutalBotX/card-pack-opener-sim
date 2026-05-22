extends Button
class_name NavButton

# --- COLORS ---
const NORMAL_COLOR  := Color("#4CC9F0")
const HOVER_COLOR   := Color("#72DDF7")
const PRESSED_COLOR := Color("#38B6DB")
const BORDER_COLOR  := Color("#FFFFFF")
const TEXT_COLOR    := Color("#FFFFFF")

func _ready() -> void:
	# Button size
	custom_minimum_size = Vector2(330, 50)

	# Text styling
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_hover_color", TEXT_COLOR)
	add_theme_color_override("font_pressed_color", TEXT_COLOR)

	# Create styles
	var normal_style = _make_style(NORMAL_COLOR, BORDER_COLOR, 4)
	var hover_style = _make_style(HOVER_COLOR, Color("#EAFBFF"), 5)
	var pressed_style = _make_style(PRESSED_COLOR, BORDER_COLOR, 4)

	# Apply styles
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", hover_style)

	# Cursor
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# NOTE: I removed the animation signal connections here.

func _make_style(bg_color: Color, border_color: Color, border_size: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.border_width_left = border_size
	style.border_width_top = border_size
	style.border_width_right = border_size
	style.border_width_bottom = border_size
	style.border_color = border_color
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

# All _on_mouse_entered, _on_mouse_exited, and _on_button_up 
# functions have been removed as they are no longer needed.
