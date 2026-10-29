-- MoveAnything!: moves, scales and hides any frame of the interface.
-- Based on MoveAnything! vJ.11000.2 (Skrag, Jason), rebuilt for Azeroth Survivors' 1.12 client.
-- This file holds the constants and the small helpers the other files share.

MoveAnything = {};
local A = MoveAnything;

local ADDON = "MoveAnything";
local WHITE = "Interface\\Buttons\\WHITE8X8";
local MIN_SCALE, MAX_SCALE = 0.25, 4;
local MIN_SIZE = 8;
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
	FULLSCREEN_DIALOG = 7, TOOLTIP = 8 };

local GOLD = { 1, 0.82, 0 };
local GREEN = { 0.4, 1, 0.4 };
local GREY = { 0.55, 0.55, 0.55 };
local TEXT = { 1, 1, 1 };

local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
};

-- The state every file shares.
A.entries = {};    -- the window's list, in order: { kind = "frame"|"dummy"|"group"|"hud"|"sep", ... }
A.byName = {};     -- name -> entry, the player's own frames too
A.specials = {};   -- name -> what makes an entry more than a plain frame (Spots.lua)
A.movers = {};     -- name -> the overlay on it
A.order = {};      -- names being moved, oldest first
A.current = nil;   -- the one last clicked (gold rim on its overlay)
A.pending = {};    -- names with saved settings whose frame doesn't exist yet
A.db = nil;        -- MoveAnythingDB
A.profile = nil;   -- the layout in use: name -> { x, y, scale, w, h, hidden }
A.profileKey = nil;

local function L(text)
	local custom, strings = MoveAnything_Custom, MoveAnything_Strings;
	local base = (strings and strings[text]) or text;
	local locale = MoveAnything_Locales and MoveAnything_Locales[A.language or "en"];
	-- User overrides still win, but an invalid placeholder must not break a UI callback.
	if ( custom and A.ValidTranslation and A.ValidTranslation(base, custom[text]) ) then return custom[text]; end
	return (locale and locale[text]) or base;
end

-- Commands, saved layouts and the picker share this check. Object identity also
-- catches aliases such as MyRoot = UIParent, which a name-only blacklist misses.
local function IsProtected(name, frame)
	if ( type(name) ~= "string" or name == "" ) then return true; end
	frame = frame or getglobal(name);
	if ( frame and (frame == UIParent or frame == WorldFrame or frame == GlueParent) ) then return true; end
	if ( name == "UIParent" or name == "WorldFrame" or name == "GlueParent" or
		name == "GameMenuFrame" or name == "BenillaOptionsFrame" ) then return true; end
	return string.find(name, "^MoveAnything") and not A.specials[name];
end

local function LF(key, a, b, c, d)
	local ok, text = pcall(string.format, L(key), a, b, c, d);
	if ( ok ) then return text; end
	return string.format(key, a, b, c, d);
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. L("MoveAnything") .. ":|r " .. msg);
end

local function Noop() end
local function UIScale() return UIParent:GetEffectiveScale(); end
local function Clamp(v, lo, hi) if ( v < lo ) then return lo; elseif ( v > hi ) then return hi; end return v; end
local function Trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")); end

-- Textures (the gryphons) have no scale of their own: they take their frame's.
local function EffScale(f)
	if ( f.GetEffectiveScale ) then return f:GetEffectiveScale(); end
	local p = f.GetParent and f:GetParent();
	return p and EffScale(p) or UIScale();
end

local function ScaleOf(f)
	return f.GetScale and f:GetScale() or 1;
end

-- A frame's real method, whether or not MoveAnything shadowed it (Layout.lua).
local function Raw(f, method)
	return f["MA_" .. method] or f[method];
end

local function DeepCopy(t)
	if ( type(t) ~= "table" ) then return t; end
	local c = {};
	for k, v in pairs(t) do c[k] = DeepCopy(v); end
	return c;
end

local function Tip(frame, title, line)
	frame:SetScript("OnEnter", function()
		local tip = A.HelpTooltip();
		tip:SetOwner(this, "ANCHOR_RIGHT");
		tip:SetText(L(title));
		if ( line ) then tip:AddLine(L(line), 1, 1, 1, 1); end
		A.StyleTooltip(tip); tip:Show();
	end);
	frame:SetScript("OnLeave", function() A.HideHelpTooltip(); end);
end

-- A stock button. It needs a name: the template looks its textures up by its name.
local function Button(name, parent, text, w, h)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate");
	b:SetWidth(w);
	b:SetHeight(h or 22);
	A.BindText(b, text, 11);
	return b;
end

A.ADDON = ADDON;
A.WHITE = WHITE;
A.MIN_SCALE = MIN_SCALE;
A.MAX_SCALE = MAX_SCALE;
A.MIN_SIZE = MIN_SIZE;
A.STRATA = STRATA;
A.GOLD = GOLD;
A.GREEN = GREEN;
A.GREY = GREY;
A.TEXT = TEXT;
A.BACKDROP = BACKDROP;
A.L = L;
A.IsProtected = IsProtected;
A.LF = LF;
A.Print = Print;
A.Noop = Noop;
A.UIScale = UIScale;
A.Clamp = Clamp;
A.Trim = Trim;
A.EffScale = EffScale;
A.ScaleOf = ScaleOf;
A.Raw = Raw;
A.DeepCopy = DeepCopy;
A.Tip = Tip;
A.Button = Button;
