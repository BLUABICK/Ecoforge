extends SyntaxHighlighter
const Registry = preload("res://scripts/console_command_registry.gd")
const COMMAND_COLOR := Color("79d9f2")
const ERROR_COLOR := Color("ff8185")
const ARGUMENT_COLOR := Color("e2cf9e")
const STRING_COLOR := Color("9cddb0")
const NUMBER_COLOR := Color("edb377")
const DEFAULT_COLOR := Color("d4dee4")
var registry: RefCounted

func token_color(span: Dictionary, index: int) -> Color:
	if index == 0:
		return COMMAND_COLOR if registry != null and registry.has_command(span.value) else ERROR_COLOR
	if String(span.value).to_lower() in ["true", "false"] and not span.quoted:
		return Color("c4aff5")
	if span.quoted:
		return STRING_COLOR
	if String(span.value).is_valid_float():
		return NUMBER_COLOR
	return ARGUMENT_COLOR

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var parsed := Registry.tokenize(get_text_edit().get_line(line))
	var colors := {}
	for index in parsed.spans.size():
		var span: Dictionary = parsed.spans[index]
		colors[span.start] = {"color": token_color(span, index)}
		colors[span.end] = {"color": DEFAULT_COLOR}
	return colors
