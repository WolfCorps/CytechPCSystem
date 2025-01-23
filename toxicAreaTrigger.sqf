
// Setup
// Place a area trigger (The toxic zone activates if the players FEET! Are inside the area)
// Give it a variable name (like OS1_ToxicZone1)
// Set activation based on whether it should be on at mission start
// On = Any Player
// Off = None
// Repeatable Yes
// Server Only No
// Trigger Expression: 
// thisTrigger call ded_fnc_toxicAreaTriggerCheck;
// Interval: 5 seconds (Or how often you want to apply damage)

// To activate toxic zone in script (The first part, is only needed if you initially created the trigger as Off in Eden):
// OS1_ToxicZone1 setTriggerActivation ["ANYPLAYER", "PRESENT", true]; OS1_ToxicZone1 enableSimulation true;
// To deactivate zone: 
// OS1_ToxicZone1 enableSimulation false;


ded_fnc_toxicAreaTriggerCheck = {
diag_log "TriggerCheck";
	params ["_trigger"];
	
	if (player inArea _trigger) then {
		[guy, 0.1] call ace_medical_fnc_adjustPainLevel;
		[player, 0.2, "head", "burn"] call ace_medical_fnc_addDamageToUnit;
	};
};