local A = MoveAnything;
local L, Print, specials = A.L, A.Print, A.specials;
local Opt, HasLayout, Tidy, Restore, Unlock, ApplyLayout = A.Opt, A.HasLayout, A.Tidy, A.Restore, A.Unlock, A.ApplyLayout;
local HideFrame, ShowFrame, ManagePositions, BuildGroup, UnbuildGroup = A.HideFrame, A.ShowFrame, A.ManagePositions, A.BuildGroup, A.UnbuildGroup;

-- The list of movable things, and putting each where the layout in use says.

local function UpdateOptions()
	if ( A.UpdateOptions ) then A.UpdateOptions(); end
end

local function AddEntry(e)
	table.insert(A.entries, e);
	if ( e.name ) then A.byName[e.name] = e; end
	return e;
end

for _, def in ipairs(A.FRAME_LIST) do
	if ( def.sep ) then
		AddEntry({ kind = "sep", labelKey = def.sep, label = L(def.sep) });
	elseif ( def.hud ) then
		AddEntry({ kind = "hud", name = "hud:" .. def.hud, part = def.hud, labelKey = def[1], label = L(def[1]) });
	else
		local e = { kind = "frame", name = def[1], labelKey = def[2], label = L(def[2]) };
		-- Every flag the list gives (noScale, noHide, wh, minW, minH, widthOf).
		for k, v in pairs(def) do
			if ( type(k) == "string" ) then e[k] = v; end
		end
		local s = specials[def[1]];
		if ( s ) then
			for k, v in pairs(s) do e[k] = v; end
		end
		AddEntry(e);
	end
end

-- A frame the player named or picked: it joins the list under "Your frames".
local function AddCustom(name)
	if ( A.IsProtected(name) ) then return; end
	local e = A.byName[name];
	if ( e ) then return e; end
	e = { kind = "frame", name = name, label = name, custom = true };
	A.byName[name] = e;
	if ( A.db ) then A.db.custom[name] = true; end
	return e;
end

local function DropCustom(name)
	if ( A.db ) then A.db.custom[name] = nil; end
	A.byName[name] = nil;
end

local function CustomNames()
	local t = {};
	if ( A.db ) then
		for name in pairs(A.db.custom) do table.insert(t, name); end
	end
	table.sort(t);
	return t;
end

local function GetFrame(name)
	if ( A.IsProtected(name) ) then return; end
	local e = A.byName[name];
	if ( e and e.kind == "hud" ) then return; end
	if ( e and e.kind == "group" ) then return e.frame; end
	local f = getglobal(name);
	if ( type(f) == "table" and f.GetObjectType and f.SetPoint ) then return f; end
end

-- Whether the client has it: a stock frame missing here is left out of the list.
local function Exists(e)
	if ( e.kind == "hud" ) then return AZS_SetHudShown ~= nil; end
	if ( e.kind == "group" ) then return getglobal(e.buttons[1]) ~= nil; end
	if ( e.kind == "sep" ) then return true; end
	return GetFrame(e.name) ~= nil;
end

-- The size to give a frame that reports none (the hidden chat input box), from its entry.
local function SetFallbackSize(f, e)
	if ( not e or not (e.minW or e.widthOf) ) then return; end
	local ref = e.widthOf and getglobal(e.widthOf);
	local w = ref and ref:GetWidth();
	f.MA_fallbackW = (w and w > 0) and w or e.minW;
	f.MA_fallbackH = e.minH;
end

local function IsMoved(name) return HasLayout(Opt(name)); end
local function IsHidden(name) local o = Opt(name); return o and o.hidden; end
local function IsMoving(name) return A.movers[name] and true; end

-- Put one frame where its settings say. False when its frame doesn't exist (yet).
local function ApplyEntry(name)
	-- A stale or hand-edited saved profile must not bypass the command guard.
	if ( A.IsProtected(name) ) then return true; end
	local o = Opt(name);
	if ( not o ) then return true; end
	local e = A.byName[name];
	if ( not e and A.db and A.db.custom[name] ) then e = AddCustom(name); end
	if ( e and e.kind == "hud" ) then return true; end
	if ( e and e.kind == "group" ) then
		if ( e.pair and A.byName[e.pair] and A.byName[e.pair].built ) then return true; end
		if ( not BuildGroup(e) ) then return false; end
	end
	local f = GetFrame(name);
	if ( not f ) then return false; end
	SetFallbackSize(f, e);
	if ( HasLayout(o) ) then ApplyLayout(f, o); end
	if ( o.hidden ) then HideFrame(f); end
	if ( e and e.onApply ) then e.onApply(e, f); end
	return true;
end

local function RefreshPositions()
	if ( not A.profile ) then return; end
	A.pending = {};
	for name in pairs(A.profile) do
		if ( not ApplyEntry(name) ) then A.pending[name] = true; end
	end
end

local function ApplyPending()
	local left = false;
	for name in pairs(A.pending) do
		if ( ApplyEntry(name) ) then A.pending[name] = nil; else left = true; end
	end
	return left;
end

-- Hand a frame back as the game had it. keep: leave its saved settings (switching layouts).
local function ResetEntry(name, keep)
	if ( A.movers[name] ) then A.StopMoving(name); end
	local e = A.byName[name];
	if ( e and e.kind == "hud" ) then return; end
	if ( e and e.kind == "group" ) then
		UnbuildGroup(e);
	else
		local f = GetFrame(name);
		if ( f ) then
			ShowFrame(f);
			Restore(f);
			Unlock(f);
		end
	end
	if ( not keep and A.profile ) then
		A.profile[name] = nil;
		if ( e and e.custom ) then DropCustom(name); end
	end
	if ( e and e.onReset ) then e.onReset(e); end
	if ( e and e.onApply ) then e.onApply(e); end
	ManagePositions();
	UpdateOptions();
end

-- Every name the layout in use touches, and every frame being moved.
local function TouchedNames()
	local names = {};
	for name in pairs(A.profile) do table.insert(names, name); end
	for name in pairs(A.movers) do table.insert(names, name); end
	return names;
end

local function ResetAll()
	for _, name in ipairs(TouchedNames()) do ResetEntry(name); end
	for name in pairs(A.db.custom) do A.byName[name] = nil; end
	A.db.custom = {};
	Print(L("Every frame is back where the game puts it."));
	UpdateOptions();
end

local function SetHidden(name, hidden)
	local e = A.byName[name];
	if ( not e or e.noHide or e.kind == "hud" ) then return; end
	local o = Opt(name, true);
	o.hidden = hidden and true or nil;
	if ( hidden ) then
		ApplyEntry(name);
	else
		local f = GetFrame(name);
		if ( f ) then ShowFrame(f); end
		Tidy(name);
		if ( e.kind == "group" and not IsMoved(name) and not A.movers[name] ) then
			UnbuildGroup(e);
		end
	end
	UpdateOptions();
end

-- The game's own HUD parts.
local function IsHudHidden(part)
	return AZS_IsHudShown and not AZS_IsHudShown(part);
end

local function SetHudHidden(part, hidden)
	if ( AZS_SetHudShown ) then AZS_SetHudShown(part, not hidden); end
	UpdateOptions();
end

A.AddCustom = AddCustom;
A.DropCustom = DropCustom;
A.CustomNames = CustomNames;
A.SetFallbackSize = SetFallbackSize;
A.GetFrame = GetFrame;
A.Exists = Exists;
A.IsMoved = IsMoved;
A.IsHidden = IsHidden;
A.IsMoving = IsMoving;
A.ApplyEntry = ApplyEntry;
A.RefreshPositions = RefreshPositions;
A.ApplyPending = ApplyPending;
A.ResetEntry = ResetEntry;
A.TouchedNames = TouchedNames;
A.ResetAll = ResetAll;
A.SetHidden = SetHidden;
A.IsHudHidden = IsHudHidden;
A.SetHudHidden = SetHudHidden;
