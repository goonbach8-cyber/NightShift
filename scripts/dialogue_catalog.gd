extends RefCounted
## Replaceable prototype dialogue content; no story text in checkout/inventory logic.
static func for_context(history: Dictionary, flags: Dictionary) -> Dictionary:
	var lines := PackedStringArray(["Evening. Long shift?", "Just these, please. Thank you."])
	var choices: Array[Dictionary] = []
	if not history.is_empty() and not flags.get(&"asked_about_call",false) and not flags.get(&"denied_call",false):
		lines = PackedStringArray(["You answered the phone earlier, didn't you?", "I thought I heard you say 03:17."])
		choices.assign([{"text":"Which phone call?","flag":&"asked_about_call","reply":"Maybe I have the wrong place. Sorry."},{"text":"I haven't answered a call.","flag":&"denied_call","reply":"No? Then I must have misheard."}])
	return {"lines":lines,"choices":choices}
