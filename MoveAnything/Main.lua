local A = MoveAnything;
local ADDON, L, LF, Print, Trim = A.ADDON, A.L, A.LF, A.Print, A.Trim;
local AddCustom, GetFrame, IsHidden, SetHidden, ResetEntry = A.AddCustom, A.GetFrame, A.IsHidden, A.SetHidden, A.ResetEntry;
local RefreshPositions, ApplyPending, ManagePositions, SelectProfile = A.RefreshPositions, A.ApplyPending, A.ManagePositions, A.SelectProfile;
local StartMoving, StopAll, Pick, FrameUnderCursor, ToggleWindow = A.StartMoving, A.StopAll, A.Pick, A.FrameUnderCursor, A.ToggleWindow;
local ListProfiles, CopyProfile, DeleteProfile = A.ListProfiles, A.CopyProfile, A.DeleteProfile;

-- Start-up, the game menu's Edit Mode, the key bindings and the slash commands.

function MoveAnything_Toggle() ToggleWindow(); end

function MoveAnything_RefreshPositions()
	RefreshPositions();
	ManagePositions();
end

function MoveAnything_MoveFrameUnderCursor()
	local f = FrameUnderCursor();
	if ( f ) then StartMoving(f:GetName()); else Print(L("There is no named frame under the cursor.")); end
end

function MoveAnything_Pick() Pick(); end

-- For other addons and old macros.
function MoveAnything_Move(name) return StartMoving(name); end

function A.RefreshBindingLabels()
	BINDING_HEADER_MOVEANYTHING = L("MoveAnything!");
	BINDING_NAME_MOVEANYTHING_TOGGLE = L("Open or close MoveAnything!");
	BINDING_NAME_MOVEANYTHING_UNDERCURSOR = L("Move the frame under the cursor");
	BINDING_NAME_MOVEANYTHING_PICK = L("Pick a frame to move");
	BINDING_NAME_MOVEANYTHING_REFRESH = L("Put the moved frames back in place");
end
A.RefreshBindingLabels();

-- The game menu has an Edit Mode button with nothing behind it: it opens MoveAnything!.
local function HookEditMode()
	local b = getglobal("BenillaGameMenuButtonEditMode");
	if ( not b or b.MA_hooked ) then return; end
	b.MA_hooked = true;
	b:Enable();
	b:SetScript("OnClick", function()
		PlaySound("igMainMenuOption");
		HideUIPanel(GameMenuFrame);
		ToggleWindow();
	end);
	A.Tip(b, "MoveAnything!", "Moves, scales and hides the parts of the interface.");
	local onShow = GameMenuFrame:GetScript("OnShow");
	GameMenuFrame:SetScript("OnShow", function()
		if ( onShow ) then onShow(); end
		b:Enable();
	end);
end

SLASH_MOVEANYTHING1 = "/move";
SLASH_MOVEANYTHING2 = "/moveanything";
SLASH_UNMOVEANYTHING1 = "/unmove";
SLASH_MOVEANYTHINGLIST1 = "/movelist";
SLASH_MOVEANYTHINGCOPY1 = "/movecopy";
SLASH_MOVEANYTHINGDELETE1 = "/movedelete";
SLASH_MOVEANYTHINGDELETE2 = "/movedel";

local ApplyKey;

do
	-- The game's Key Bindings page does not show addon bindings, so /move key sets one.
	function ApplyKey()
		local key = A.db and A.db.settings.key;
		if ( key and SetBinding ) then SetBinding(key, "MOVEANYTHING_TOGGLE"); end
	end

	local function SetKey(key)
		if ( key == "" ) then
			if ( A.db.settings.key ) then
				Print(LF("The key for MoveAnything! is %s.", A.db.settings.key));
			else
				Print(L("MoveAnything! has no key. Type /move key <key> to set one. Example: /move key F7."));
			end
			return;
		end
		if ( A.db.settings.key and SetBinding ) then SetBinding(A.db.settings.key); end
		if ( key == "NONE" ) then
			A.db.settings.key = nil;
			Print(L("MoveAnything! has no key now."));
			return;
		end
		local old = GetBindingAction and GetBindingAction(key);
		A.db.settings.key = key;
		ApplyKey();
		if ( old and old ~= "" and old ~= "MOVEANYTHING_TOGGLE" ) then
			Print(LF("The key %s opens MoveAnything! now. It no longer does %s.", key, getglobal("BINDING_NAME_" .. old) or old));
		else
			Print(LF("The key %s opens MoveAnything! now.", key));
		end
	end

	local function Help()
		Print(L("Type /move to open or close the window. Type /move FrameName to move a frame by its name. Type /move pick to pick a frame on the screen. Type /move hide FrameName to hide or show a frame. Type /move done to stop moving all frames. Type /unmove FrameName to put a frame back where the game puts it. Type /move key <key> to set a key for the window. Type /movelist to see the saved layouts, /movecopy Name to copy one and /movedelete Name to delete one."));
	end

	SlashCmdList["MOVEANYTHING"] = function(msg)
		if ( not A.profile ) then return; end
		msg = Trim(msg);
		local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.-)$");
		cmd = string.lower(cmd or "");
		if ( msg == "" ) then
			ToggleWindow();
		elseif ( cmd == "help" or cmd == "?" ) then
			Help();
		elseif ( cmd == "key" ) then
			SetKey(string.upper(rest));
		elseif ( cmd == "lang" ) then
			if ( A.SetLanguage(string.lower(rest)) ) then
				Print(LF("Language set to %s.", A.LanguageLabel()));
			else
				Print(L("Unknown language. Use /move lang auto, en, pl, cs, de, pt, es, fr, ro, tr, ru, uk, zh, ja or ko."));
			end
		elseif ( cmd == "pick" ) then
			Pick();
		elseif ( cmd == "done" ) then
			StopAll();
		elseif ( cmd == "refresh" ) then
			MoveAnything_RefreshPositions();
		elseif ( cmd == "hide" and rest ~= "" ) then
			if ( A.IsProtected(rest) ) then
				Print(LF("The frame \"%s\" is protected.", rest));
			elseif ( AddCustom(rest) and GetFrame(rest) ) then
				SetHidden(rest, not IsHidden(rest));
			else
				Print(LF("There is no frame \"%s\". Frame names are case-sensitive.", rest));
			end
		elseif ( cmd == "reset" and rest ~= "" ) then
			ResetEntry(rest);
		else
			StartMoving(msg);
		end
	end;

	SlashCmdList["UNMOVEANYTHING"] = function(msg)
		msg = Trim(msg);
		if ( msg == "" ) then Help(); return; end
		ResetEntry(msg);
	end;

	SlashCmdList["MOVEANYTHINGLIST"] = function()
		if ( A.profile ) then ListProfiles(); end
	end;

	SlashCmdList["MOVEANYTHINGCOPY"] = function(msg)
		msg = Trim(msg);
		if ( not A.profile ) then return; end
		if ( msg == "" ) then Print(L("Type /movecopy Name. /movelist shows the names.")); return; end
		CopyProfile(msg);
	end;

	SlashCmdList["MOVEANYTHINGDELETE"] = function(msg)
		msg = Trim(msg);
		if ( not A.profile ) then return; end
		if ( msg == "" ) then Print(L("Type /movedelete Name. /movelist shows the names.")); return; end
		DeleteProfile(msg);
	end;
end

local function Init()
	if ( A.db ) then return; end
	if ( type(MoveAnythingDB) ~= "table" ) then MoveAnythingDB = {}; end
	A.db = MoveAnythingDB;
	A.db.profiles = A.db.profiles or {};
	A.db.mode = A.db.mode or {};
	A.db.custom = A.db.custom or {};
	A.db.settings = A.db.settings or {};
	-- A chosen language applies now; Automatic is checked once at startup (below).
	local language = A.db.settings.language;
	if ( language and language ~= "auto" ) then A.RefreshLanguage(true); end
	for name in pairs(A.db.custom) do if ( not AddCustom(name) ) then A.db.custom[name]=nil; end end
end

A.events = CreateFrame("Frame");
A.events:RegisterEvent("ADDON_LOADED");
A.events:RegisterEvent("PLAYER_ENTERING_WORLD");

do
	-- Lay the layout out again each second for a while after the world loads: frames the game
	-- builds late, and stock code that places things right after the load.
	local settleUntil, settleWait = 0, 0;
	local languageDone = false;

	A.events:SetScript("OnEvent", function()
		if ( event == "ADDON_LOADED" ) then
			if ( arg1 == ADDON ) then Init(); end
			if ( A.profile ) then ApplyPending(); end
		elseif ( event == "PLAYER_ENTERING_WORLD" ) then
			Init();
			-- Check the language once at startup, not every 5 seconds.
			if ( not languageDone ) then
				languageDone = true;
				A.RefreshLanguage(true);
			end
			if ( not A.profile ) then SelectProfile(); end
			RefreshPositions();
			HookEditMode();
			ApplyKey();
			settleUntil = GetTime() + 10;
		end
	end);

	A.events:SetScript("OnUpdate", function()
		if ( settleUntil == 0 ) then return; end
		settleWait = settleWait - arg1;
		if ( settleWait > 0 ) then return; end
		settleWait = 1;
		if ( GetTime() > settleUntil ) then
			settleUntil = 0;
			return;
		end
		if ( A.profile ) then RefreshPositions(); end
	end);
end
