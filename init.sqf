

// NO EDIT BELOW HERE

#define OS_DEBUGCONSOLE 0
#define OS_FREEZEUNFREEZE 0

ded_CytechOSInstances = createHashMap;
ded_CytechOSGeneration = hashValue diag_tickTime;

// Create a new OS (This must be executed on every player's machine
ded_fnc_CreateOS = {
	params ["_osName", "_screenVariableName", "_keyboardVariableName"];
	
	diag_log ["create", _this];

	private _osData = ded_CytechOSInstances getOrDefault [_osName, createHashMap, true];
	
	_osData set ["name", _osName];
	_osData set ["screen", (missionNamespace getVariable _screenVariableName)];
	_osData set ["keyboard", (missionNamespace getVariable _keyboardVariableName)];
	_osData set ["stateInfo", "{}"];
	_osData set ["stateHandlers", []];
	_osData set ["powered", false];

	(_osData get "keyboard") addAction ["Open Controls", {
	
		(_this select 3) params ["_osData"];
	
		private _display = (findDisplay 46) createDisplay "RscCytechDisplayControl";
		_display setVariable ["osData", _osData];
		
		private _ctrl = (_display displayCtrl 1337);
#if OS_DEBUGCONSOLE
		_ctrl ctrlWebBrowserAction ["OpenDevConsole"];	
		[_ctrl] spawn {Sleep 1; (_this#0) ctrlWebBrowserAction ["LoadFile", "CytechUI\index.html"];};
#else
		_ctrl ctrlWebBrowserAction ["LoadFile", "CytechUI\index.html"];
#endif
		
		_ctrl ctrlAddEventHandler ["JSDialog", {
			params ["_ctrl", "_isConfirmDialog", "_message"];
			
			private _display = ctrlParent _ctrl;
			private _osData = _display getVariable "osData";
			
			[_osData get "name", _message] call ded_fnc_OnJSAlert;
			true; // We need to tell it that we handled the "dialog", by returning true or false.
		}];
		
		// Wait for the browser to actually be loaded
		_ctrl ctrlAddEventHandler ["PageLoaded", {
			params ["_ctrl"];
			
			private _display = ctrlParent _ctrl;
			private _osData = _display getVariable "osData";
			
			diag_log ["PageLoaded", _osData get "name", diag_frameNo];
			
			_ctrl ctrlWebBrowserAction ["ExecJS", format ["UIUpdateState(%1)", _osData get "stateInfo"]];
		}];

	}, _osData, 1.5, true, true, "", format["ded_CytechOSInstances get '%1' get 'powered'", _osName]];
	
	
#if OS_FREEZEUNFREEZE
	(_osData get "keyboard") addAction ["Freeze", {
		(_this select 3) params ["_osData"];
		
		private _ctrl = _osData getOrDefault ["ctrl", controlNull];
		if (!isNull _ctrl) then {
			// UI is open, tell it about new state
			_ctrl ctrlWebBrowserAction ["StopBrowser"];
			
			[(ctrlParent _ctrl) getVariable "ded_p2"] call CBA_fnc_removePerFrameHandler;
			(ctrlParent _ctrl) setVariable ["ded_p2", -1];
		};	
	}, _osData, 1.5, true, true, "", format["ded_CytechOSInstances get '%1' get 'powered'", _osName]];
	
	(_osData get "keyboard") addAction ["UnFreeze", {
		(_this select 3) params ["_osData"];
		
		private _ctrl = _osData getOrDefault ["ctrl", controlNull];
		if (!isNull _ctrl) then {
			// UI is open, tell it about new state
			_ctrl ctrlWebBrowserAction ["OpenDevConsole"];
			_ctrl ctrlWebBrowserAction ["ResumeBrowser"]; // This will trigger the "PageLoaded" eventhandler again, which will fill in our state
			
			(ctrlParent _ctrl) setVariable ["ded_p2", -2]; // Pretend we have a eventhandler, so that the PageLoad doesn't add it back. We will add it manually once the page is stable
			
			_ctrl setVariable ["lastDraw", diag_frameNo];
			_ctrl ctrlAddEventHandler ["Draw", {
				params ["_ctrl"];
				_ctrl setVariable ["lastDraw", diag_frameNo]; // Remember when the last draw happened
			}];
			
			[{
				// Wait until the last draw, was more than 60 frames ago. So we wait until the image is "stable"
				(((_this select 0) getVariable "lastDraw") + 60) < diag_frameNo
				//#TODO handle the control becoming null because the UI was closed
			}, 
			{
				// No draw for 60 frames, its probably stable, resume updating the ui2tex
				private _display = ctrlParent (_this select 0);
				private _p2 = [{displayUpdate (_this#0)}, 0.1, _display] call CBA_fnc_addPerFrameHandler;
				_display setVariable ["ded_p2", _p2];
			}, [_ctrl]] call CBA_fnc_waitUntilAndExecute;
			
		};
	}, _osData, 1.5, true, true, "", format["ded_CytechOSInstances get '%1' get 'powered'", _osName]];
#endif // OS_FREEZEUNFREEZE
	
};

ded_fnc_SetOSPowerOn = {
	params ["_osName"];
	
	private _osData = ded_CytechOSInstances get _osName;
	_osData set ["powered", true];
	
	(_osData get "screen") setObjectTexture [0, format["#(rgb,2048,1024,1)ui(RscCytechDisplay,%1_%s)", _osName, ded_CytechOSGeneration]];
};

// Internal function
ded_fnc_SetOSState = {
	params ["_osName", "_newState"];
	
	_osData = ded_CytechOSInstances getOrDefault [_osName, createHashMap, true];
	
	_osData set ["stateInfo", _newState];
	
	private _ctrl = _osData getOrDefault ["ctrl", controlNull];
	if (!isNull _ctrl) then {
		// UI is open, tell it about new state
		_ctrl ctrlWebBrowserAction ["ExecJS", format ["UIUpdateState(%1)", _osData get "stateInfo"]];
	};
	
	private _stateMap = fromJson _newState;

	{ _stateMap call _x; } forEach (_osData getOrDefault ["stateHandlers", []]);
};

ded_fnc_OnJSAlert = {
	params ["_osName", "_content"];

	// Tell everyone about new state. Including ourselves, because this is only possible on interactive UI
	if ((_content select [0,5]) == "state") then {
		[_osName, _content select [5]] remoteExec ["ded_fnc_SetOSState", 0];	
	};
};

// Only for ui2tex variant
ded_fnc_OSDisplayLoad = {
	diag_log ["load", _this, diag_frameNo];
	params ["_display", "_osName"];
	
	_osName = _osName select [0, _osName find "_"];
	
	private _osData = ded_CytechOSInstances getOrDefault [_osName, createHashMap, true];
	_display setVariable ["osData", _osData];
	
	private _ctrl = (_display displayCtrl 1337);
	_osData set ["ctrl", _ctrl];
	
#if OS_DEBUGCONSOLE
	_ctrl ctrlWebBrowserAction ["OpenDevConsole"];	
	[_ctrl] spawn {Sleep 1; (_this#0) ctrlWebBrowserAction ["LoadFile", "CytechUI\index.html"];};
#else
	_ctrl ctrlWebBrowserAction ["LoadFile", "CytechUI\index.html"];
#endif
	
	_ctrl ctrlAddEventHandler ["JSDialog", {
		params ["_ctrl", "_isConfirmDialog", "_message"];
		
		private _display = ctrlParent _ctrl;
		private _osData = _display getVariable "osData";
		
		[_osData get "name", _message] call ded_fnc_OnJSAlert;
		true; // We need to tell it that we handled the "dialog", by returning true or false.
	}];

	_ctrl ctrlAddEventHandler ["PageLoaded", {
		params ["_ctrl"];
		
		private _display = ctrlParent _ctrl;
		private _osData = _display getVariable "osData";
		
		diag_log ["PageLoaded", _osData get "name", diag_frameNo, _ctrl];

		_ctrl ctrlWebBrowserAction ["ExecJS", format ["UIUpdateState(%1)", _osData get "stateInfo"]];

		// Regular updating
		if ((_display getVariable ["ded_p2", -1]) isEqualTo -1) then {
			private _p2 = [{displayUpdate (_this#0)}, 0.1, _display] call CBA_fnc_addPerFrameHandler;
			_display setVariable ["ded_p2", _p2];
		};
	}];
	
	_display displayAddEventHandler ["Unload", {
		params ["_display", "_exitCode"];
		[_display getVariable "ded_p2"] call CBA_fnc_removePerFrameHandler;
	}];
};

// NO EDIT ABOVE HERE



// Register all OS's, each one is a separate computer, with separate screen and keyboard objects
// Keyboard can be the same object as the screen, which will make the screen be the input device (like a touch screen)
// First parameter is the name of the OS, which is referenced again to turn power on and handle state changes

["OS1", "Display_1_Screen", "Display_1_Keyboard"] call ded_fnc_CreateOS;
// Turn on the power, must be done once. Cannot be turned off again.
// !Important! The system will only actually boot, if its in view of atleast on player. Only if the screen is visible!
["OS1"] call ded_fnc_SetOSPowerOn;

// Register eventhandlers for the OS.
// Eventhandlers are called globally, on all players
// The first call to the eventhandler, will be after bootup ("page" member will be set to "mainsystems")

(ded_CytechOSInstances get "OS1" get "stateHandlers") pushBack {
	params ["_newState"];
	
	// Something about this OS's state changed
	private _sys1IsEnabled = _newState getOrDefault ["sys1", false];
	private _sys2IsEnabled = _newState getOrDefault ["sys2", false];
	private _sys3IsEnabled = _newState getOrDefault ["sys3", false];
	private _sys4IsEnabled = _newState getOrDefault ["sys4", false];
	
	// Do something with the system states, in this case color some indicators
	
	private _colorOn = "#(argb,8,8,3)color(0,1,0,1,co)";
	private _colorOff = "#(argb,8,8,3)color(1,0,0,1,co)";
	
	indicator1 setObjectTexture [0, [_colorOff, _colorOn] select _sys1IsEnabled];
	indicator2 setObjectTexture [0, [_colorOff, _colorOn] select _sys2IsEnabled];
	indicator3 setObjectTexture [0, [_colorOff, _colorOn] select _sys3IsEnabled];
	indicator4 setObjectTexture [0, [_colorOff, _colorOn] select _sys4IsEnabled];
	
	// System 3 on OS1, controls the toxic zone trigger example
	OS1_ToxicZone1 enableSimulation !_sys3IsEnabled;
	
	diag_log ["newState", _newState];
};


// Second OS example, it controls different indicators
["OS2", "Display_1_Screen_1", "Display_1_Keyboard_1"] call ded_fnc_CreateOS;
["OS2"] call ded_fnc_SetOSPowerOn;
(ded_CytechOSInstances get "OS2" get "stateHandlers") pushBack {
	params ["_newState"];
	
	// Something about this OS's state changed
	private _sys1IsEnabled = _newState getOrDefault ["sys1", false];
	private _sys2IsEnabled = _newState getOrDefault ["sys2", false];
	private _sys3IsEnabled = _newState getOrDefault ["sys3", false];
	private _sys4IsEnabled = _newState getOrDefault ["sys4", false];
	
	// Do something with the system states, in this case color some indicators
	
	private _colorOn = "#(argb,8,8,3)color(0.5,0.5,0,1,co)";
	private _colorOff = "#(argb,8,8,3)color(0,0,1,1,co)";
	
	indicator1_1 setObjectTexture [0, [_colorOff, _colorOn] select _sys1IsEnabled];
	indicator2_1 setObjectTexture [0, [_colorOff, _colorOn] select _sys2IsEnabled];
	indicator3_1 setObjectTexture [0, [_colorOff, _colorOn] select _sys3IsEnabled];
	indicator4_1 setObjectTexture [0, [_colorOff, _colorOn] select _sys4IsEnabled];
	
	diag_log ["newState", _newState];
};


[] execVM "toxicAreaTrigger.sqf";