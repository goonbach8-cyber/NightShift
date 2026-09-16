extends Node
signal changed
var active: bool = false
var completed: bool = false
var lines: PackedStringArray = []
var choices: Array[Dictionary] = []
var index: int = 0
var owner_id: int = 0
var flags: Dictionary = {}

func begin(speaker_id: int, text_lines: PackedStringArray, answers: Array[Dictionary], story_flags: Dictionary) -> bool:
	if active or text_lines.is_empty(): return false
	owner_id = speaker_id
	lines = text_lines
	choices = answers
	flags = story_flags
	index = 0
	completed = false
	active = true
	changed.emit()
	return true

func advance() -> void:
	if not active: return
	if index+1 < lines.size():
		index += 1
	elif choices.is_empty():
		close(true)
	changed.emit()

func choose(choice: int) -> void:
	if not active or index != lines.size()-1 or choice < 0 or choice >= choices.size(): return
	var answer: Dictionary = choices[choice]
	if answer.has("flag"): flags[StringName(answer.flag)] = true
	lines = PackedStringArray([String(answer.get("reply","Good night."))])
	choices = []
	index = 0
	changed.emit()

func close(was_completed: bool = false) -> void:
	completed = was_completed
	active = false
	owner_id = 0
	changed.emit()

func display_text() -> String:
	if not active: return "[F] Talk to customer"
	var text := lines[index]
	if index == lines.size()-1 and not choices.is_empty():
		for i in choices.size(): text += "\n[%d] %s" % [i+1,choices[i].text]
	else:
		text += "\n[Space] Continue"
	return text
