extends RefCounted
## Optional fragments are independently mundane; no explanatory lore vocabulary.
const ENTRIES = {
	&"accident": {"title":"Local report — late-night collision","lines":["A driver reported that a second vehicle appeared in an empty lane. No camera covered the junction.","Emergency services recorded the call at 03:17."]},
	&"map": {"title":"Readers' letters — the missing road","lines":["Residents disagree about a lane beside the service station. Several recall using it for years.","The council map contains no road at that location."]},
	&"missing": {"title":"Missing resident returns","lines":["A resident reported missing on Tuesday returned to work on Wednesday.","He says he never left. He remembers speaking to his neighbours outside a bakery; they say that corner has always been a car park."]},
	&"depot_ledger": {"title":"Depot ledger","lines":["Redwood Service — regular collection route.","The oldest receipt is dated years before Mike's first shift. The signature is illegible."]},
	&"redwater": {"title":"Archived notice","lines":["Redwater Service: access remains open during maintenance.","The address matches this station. Someone has crossed out the town name in pencil."]}
}
const FIRST_NIGHT = {&"accident":1,&"map":2,&"missing":3,&"depot_ledger":4,&"redwater":5}
static func eligible(flags: Dictionary) -> bool:
	var found := 0
	for id in ENTRIES:
		if flags.get(StringName("clue_"+String(id)),false): found += 1
	return float(found)/ENTRIES.size() >= 0.7
