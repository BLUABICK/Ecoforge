extends RefCounted
## Explicit command registry: no evaluation of arbitrary GDScript.
var commands: Dictionary = {}

func register_command(command: String, handler: Callable, description: String, min_args: int = 0, max_args: int = 0, usage: String = "") -> void:
	commands[command.to_lower()] = {"handler": handler, "description": description, "min_args": min_args, "max_args": max_args, "usage": usage if not usage.is_empty() else command}

func has_command(command: String) -> bool:
	return commands.has(command.to_lower())

func execute(line: String) -> Dictionary:
	var parsed := tokenize(line)
	if not parsed.error.is_empty():
		return {"ok": false, "message": parsed.error}
	var tokens: PackedStringArray = parsed.tokens
	if tokens.is_empty():
		return {"ok": true, "message": ""}
	var command := tokens[0].to_lower()
	if not has_command(command):
		return {"ok": false, "message": "Неизвестная команда: %s" % tokens[0]}
	var entry: Dictionary = commands[command]
	var args := tokens.slice(1)
	if args.size() < entry.min_args or (entry.max_args >= 0 and args.size() > entry.max_args):
		return {"ok": false, "message": "Использование: %s" % entry.usage}
	return entry.handler.call(args)

## Shared tokenizer for execution and highlighting. Supports quoted arguments and escapes.
static func tokenize(line: String) -> Dictionary:
	var tokens := PackedStringArray()
	var spans: Array[Dictionary] = []
	var index := 0
	var error := ""
	while index < line.length():
		if line[index] in [" ", "\t", "\r", "\n"]:
			index += 1
			continue
		var start := index
		var value := ""
		var quote := ""
		var quoted := false
		while index < line.length():
			var character := line[index]
			if character == "\\" and index + 1 < line.length():
				index += 1
				value += line[index]
			elif not quote.is_empty():
				if character == quote:
					quote = ""
				else:
					value += character
			elif character in ["\"", "'"]:
				quote = character
				quoted = true
			elif character in [" ", "\t", "\r", "\n"]:
				break
			else:
				value += character
			index += 1
		if not quote.is_empty():
			error = "Незакрытая кавычка в аргументе."
		tokens.append(value)
		spans.append({"start": start, "end": index, "value": value, "quoted": quoted})
	return {"tokens": tokens, "spans": spans, "error": error}
