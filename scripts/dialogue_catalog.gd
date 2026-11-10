extends RefCounted
## Replaceable prototype dialogue content; no story text in checkout/inventory logic.
static func for_context(_history: Dictionary, flags: Dictionary, night: int = 1) -> Dictionary:
	var lines := PackedStringArray(["Evening. Long shift?", "Just these, please. Thank you."])
	if night == 5:
		lines = PackedStringArray(["Just these, please. Is the roadwork holding up the deliveries?", "I always stop here on my way through Redwater."])
	elif night == 6:
		lines = PackedStringArray(["Evening, Mike. The usual, please.", "Didn't they move the bus stop behind the station last year?"])
	var choices: Array[Dictionary] = []
	var followup := StringName("call_followup_night_%d" % night)
	var followup_seen := range(2,night+1).any(func(number): return flags.get(StringName("call_followup_night_%d" % number),false))
	if night >= 2 and not followup_seen:
		if flags.get(&"asked_about_call",false):
			return {"lines":PackedStringArray(["You were asking about the phone call.","The number you wrote down belongs to this shop. I thought you should know."]),"choices":choices,"seen_flag":followup}
		if flags.get(&"denied_call",false):
			return {"lines":PackedStringArray(["You said nobody answered the phone.","That's strange. Someone told me to come back tonight."]),"choices":choices,"seen_flag":followup}
	if night == 1 and flags.get(&"presented_night_1_main",false) and not flags.get(&"asked_about_call",false) and not flags.get(&"denied_call",false):
		lines = PackedStringArray(["You answered the phone earlier, didn't you?", "I thought I heard you say 03:17."])
		choices.assign([{"text":"Which phone call?","flag":&"asked_about_call","reply":"Maybe I have the wrong place. Sorry."},{"text":"I haven't answered a call.","flag":&"denied_call","reply":"No? Then I must have misheard."}])
	return {"lines":lines,"choices":choices,"routine":choices.is_empty()}
