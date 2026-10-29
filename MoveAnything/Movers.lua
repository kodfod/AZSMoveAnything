local A = MoveAnything;
local L, LF, Print, WHITE, BACKDROP = A.L, A.LF, A.Print, A.WHITE, A.BACKDROP;
local MIN_SCALE, MAX_SCALE, MIN_SIZE = A.MIN_SCALE, A.MAX_SCALE, A.MIN_SIZE;
local UIScale, Clamp, EffScale, ScaleOf = A.UIScale, A.Clamp, A.EffScale, A.ScaleOf;
local Opt, HasLayout, Tidy, Lock, LockScale, LockSize, Unlock, ApplyLayout = A.Opt, A.HasLayout, A.Tidy, A.Lock, A.LockScale, A.LockSize, A.Unlock, A.ApplyLayout;
local AddCustom, DropCustom, GetFrame, ApplyEntry, ResetEntry, BuildGroup = A.AddCustom, A.DropCustom, A.GetFrame, A.ApplyEntry, A.ResetEntry, A.BuildGroup;

-- Movers: the overlay laid over a frame while it is moved. Drag it to move, drag an edge handle
-- to scale (Alt: width / height), right-click to finish, Shift-right-click for a clear view.
-- Arrow keys nudge while the cursor is on it (Shift: 10), Escape finishes.

local HANDLES = {
	TOP = "TOP", BOTTOM = "BOTTOM", LEFT = "LEFT", RIGHT = "RIGHT", CORNER = "BOTTOMRIGHT",
};

local pool = {};

local function UpdateOptions()
	if ( A.UpdateOptions ) then A.UpdateOptions(); end
end

local function PaintMover(m)
	if ( m.clear ) then
		m:SetBackdropColor(0, 0, 0, 0);
		m:SetBackdropBorderColor(1, 1, 1, 0.25);
		m.label:Hide();
		m.hint:Hide();
	else
		m:SetBackdropColor(0.1, 0.75, 0.1, 0.35);
		if ( A.current == m.name ) then
			m:SetBackdropBorderColor(1, 0.82, 0, 1);
		else
			m:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8);
		end
		m.label:Show();
		m.hint:Show();
	end
end

local function SetCurrent(name)
	A.current = name;
	for _, m in pairs(A.movers) do PaintMover(m); end
end

local function ToggleClear(m)
	m.clear = not m.clear;
	PaintMover(m);
end

-- Lay the mover over its frame, in UIParent's units. Its bottom left is always the frame's, so
-- an overlay drawn bigger than the frame (minW / minH) still saves the right place.
local function SyncMover(m)
	local f, e = m.target, m.entry;
	local l, b = f:GetLeft(), f:GetBottom();
	local w, h = f:GetWidth() or 0, f:GetHeight() or 0;
	if ( not l or not b ) then return; end
	local k = EffScale(f) / UIScale();
	m:ClearAllPoints();
	m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l * k, b * k);
	m:SetWidth(math.max(w * k, (e.minW or 0) * k, MIN_SIZE));
	m:SetHeight(math.max(h * k, (e.minH or 0) * k, MIN_SIZE));
end

-- Save the frame where the mover now is and put it there.
local function StoreFromMover(m)
	local f = m.target;
	if ( not f ) then return; end
	local l, b = m:GetLeft(), m:GetBottom();
	if ( not l ) then return; end
	local o = Opt(m.name, true);
	local k = UIScale() / EffScale(f);
	o.x, o.y = l * k, b * k;
	ApplyEntry(m.name);
end

local function SetMoverRect(m, l, b, w, h)
	m:ClearAllPoints();
	m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b);
	if ( w ) then m:SetWidth(w); m:SetHeight(h); end
end

local function StartSizing(m, edge)
	SetCurrent(m.name);
	local f = m.target;
	m.sizing = {
		edge = edge, l = m:GetLeft(), b = m:GetBottom(), w = m:GetWidth(), h = m:GetHeight(),
		scale = ScaleOf(f), wh = m.entry.wh or IsAltKeyDown() or not f.SetScale,
	};
end

local function StopSizing(m)
	if ( not m.sizing ) then return; end
	m.sizing = nil;
	StoreFromMover(m);
end

-- Follow the cursor with the dragged edge; the opposite edge stays put. Scaling keeps the
-- frame's shape, so the other side grows with it.
local function DoSize(m)
	local s, f = m.sizing, m.target;
	local ui = UIScale();
	local cx, cy = GetCursorPosition();
	cx, cy = cx / ui, cy / ui;
	local l, b, w, h = s.l, s.b, s.w, s.h;
	local r, t = l + w, b + h;
	local e = s.edge;
	local nw, nh = w, h;
	if ( e == "RIGHT" or e == "CORNER" ) then nw = cx - l; elseif ( e == "LEFT" ) then nw = r - cx; end
	if ( e == "TOP" ) then nh = cy - b; elseif ( e == "BOTTOM" or e == "CORNER" ) then nh = t - cy; end
	nw, nh = math.max(nw, MIN_SIZE), math.max(nh, MIN_SIZE);
	local o = Opt(m.name, true);
	Lock(f);
	if ( s.wh ) then
		LockSize(f);
		local k = ui / EffScale(f);
		if ( e ~= "TOP" and e ~= "BOTTOM" ) then o.w = nw * k; f.MA_SetWidth(f, o.w); else nw = w; end
		if ( e ~= "LEFT" and e ~= "RIGHT" ) then o.h = nh * k; f.MA_SetHeight(f, o.h); else nh = h; end
	else
		local factor;
		if ( e == "LEFT" or e == "RIGHT" ) then
			factor = nw / w;
		elseif ( e == "TOP" or e == "BOTTOM" ) then
			factor = nh / h;
		else
			factor = math.max(nw / w, nh / h);
		end
		local scale = Clamp(s.scale * factor, MIN_SCALE, MAX_SCALE);
		factor = scale / s.scale;
		nw, nh = w * factor, h * factor;
		o.scale = scale;
		LockScale(f);
		f.MA_SetScale(f, scale);
	end
	local nl = (e == "LEFT") and (r - nw) or l;
	local nb = (e == "TOP") and b or (t - nh);
	SetMoverRect(m, nl, nb, nw, nh);
	StoreFromMover(m);
end

local StopMoving, Nudge;

local function MoverKey(m, key)
	if ( key == "ESCAPE" ) then
		StopMoving(m.name);
		return;
	end
	local step = IsShiftKeyDown() and 10 or 1;
	if ( key == "UP" ) then Nudge(m.name, 0, step);
	elseif ( key == "DOWN" ) then Nudge(m.name, 0, -step);
	elseif ( key == "LEFT" ) then Nudge(m.name, -step, 0);
	elseif ( key == "RIGHT" ) then Nudge(m.name, step, 0);
	end
end

local function NewMover()
	local m = CreateFrame("Frame", nil, UIParent);
	m:SetFrameStrata("FULLSCREEN");
	m:EnableMouse(true);
	m:SetMovable(true);
	-- Not held on the screen: some frames stand partly past its edge on purpose (the player
	-- frame's empty left side), and a held overlay would push them in as soon as it is laid on.
	m:RegisterForDrag("LeftButton");
	m:SetBackdrop(BACKDROP);
	m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	A.RegisterFont(m.label, 12);
	m.label:SetPoint("CENTER", m, "CENTER", 0, 6);
	m.hint = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	m.hint:SetPoint("TOP", m.label, "BOTTOM", 0, -2);
	A.BindText(m.hint, "Drag to move. Right-click when done.", 10);
	m.hint:SetWidth(300); m.hint:SetHeight(30);

	m.handles = {};
	for edge, point in pairs(HANDLES) do
		local hb = CreateFrame("Button", nil, m);
		hb:SetWidth(10);
		hb:SetHeight(10);
		hb:SetPoint(point, m, point, 0, 0);
		hb:SetFrameLevel(m:GetFrameLevel() + 3);
		hb:EnableMouse(true);
		local tex = hb:CreateTexture(nil, "OVERLAY");
		tex:SetAllPoints(hb);
		tex:SetTexture(WHITE);
		tex:SetVertexColor(1, 0.82, 0, 0.9);
		hb.edge = edge;
		hb:SetScript("OnMouseDown", function()
			if ( arg1 == "LeftButton" ) then StartSizing(this:GetParent(), this.edge); end
		end);
		hb:SetScript("OnMouseUp", function()
			if ( arg1 == "RightButton" and IsShiftKeyDown() ) then
				ToggleClear(this:GetParent());
			else
				StopSizing(this:GetParent());
			end
		end);
		A.Tip(hb, "Drag to scale", "Hold Alt while you drag to change the width or the height.");
		m.handles[edge] = hb;
	end

	m:SetScript("OnDragStart", function()
		if ( this.sizing ) then return; end
		SetCurrent(this.name);
		this:StartMoving();
		this.dragging = true;
	end);
	m:SetScript("OnDragStop", function()
		this:StopMovingOrSizing();
		this.dragging = nil;
		StoreFromMover(this);
	end);
	m:SetScript("OnMouseDown", function() SetCurrent(this.name); end);
	m:SetScript("OnMouseUp", function()
		if ( arg1 == "RightButton" ) then
			if ( IsShiftKeyDown() ) then ToggleClear(this); else StopMoving(this.name); end
		end
	end);
	m:SetScript("OnUpdate", function()
		if ( this.sizing ) then
			-- This client has no IsMouseButtonDown: the handle's OnMouseUp ends the sizing.
			if ( not IsMouseButtonDown or IsMouseButtonDown("LeftButton") ) then
				DoSize(this);
			else
				StopSizing(this);
			end
		elseif ( this.dragging ) then
			StoreFromMover(this);
		end
	end);
	m:SetScript("OnEnter", function() if ( this.EnableKeyboard ) then this:EnableKeyboard(true); end end);
	m:SetScript("OnLeave", function() if ( this.EnableKeyboard ) then this:EnableKeyboard(false); end end);
	m:SetScript("OnKeyDown", function() MoverKey(this, arg1); end);
	m:SetScript("OnHide", function()
		this.sizing, this.dragging = nil, nil;
		if ( this.EnableKeyboard ) then this:EnableKeyboard(false); end
	end);
	return m;
end

local function StartMoving(name)
	if ( A.IsProtected(name) ) then
		Print(LF("The frame \"%s\" is protected.", tostring(name)));
		return;
	end
	if ( A.movers[name] ) then
		SetCurrent(name);
		return true;
	end
	if ( not A.profile ) then return; end
	local e = A.byName[name] or AddCustom(name);
	if ( e.kind == "hud" or e.kind == "sep" ) then return; end
	if ( e.kind == "group" ) then
		if ( e.pair and A.byName[e.pair] and (A.byName[e.pair].built or Opt(e.pair)) ) then
			ResetEntry(e.pair);
		end
		if ( not BuildGroup(e) ) then
			Print(LF("%s: none of its buttons are there.", e.label));
			return;
		end
	end
	local f = GetFrame(name);
	if ( not f ) then
		Print(LF("There is no frame \"%s\". Frame names are case-sensitive.", name));
		if ( e.custom and not Opt(name) ) then DropCustom(name); end
		return;
	end
	if ( e.beforeMove ) then e.beforeMove(e, f); end
	A.SetFallbackSize(f, e);
	Lock(f);
	-- A frame that has no place on screen yet starts in the middle.
	if ( not f:GetLeft() or not f:GetBottom() ) then
		local o = Opt(name, true);
		local k = UIScale() / EffScale(f);
		o.x = (UIParent:GetWidth() - (f:GetWidth() or 0)) / 2 * k;
		o.y = (UIParent:GetHeight() - (f:GetHeight() or 0)) / 2 * k;
		ApplyLayout(f, o);
	end
	local m = table.remove(pool) or NewMover();
	m.name, m.target, m.entry, m.clear = name, f, e, nil;
	m.label:SetText(e.label or name);
	for _, hb in pairs(m.handles) do
		if ( e.noScale and not e.wh ) then hb:Hide(); else hb:Show(); end
	end
	SyncMover(m);
	m:Show();
	A.movers[name] = m;
	table.insert(A.order, name);
	-- A button row is laid out as soon as it's gathered: keep it so.
	if ( e.kind == "group" ) then StoreFromMover(m); end
	SetCurrent(name);
	UpdateOptions();
	return true;
end

function StopMoving(name)
	local m = A.movers[name];
	if ( not m ) then return; end
	m:Hide();
	m.target, m.entry = nil, nil;
	table.insert(pool, m);
	A.movers[name] = nil;
	for i, n in ipairs(A.order) do
		if ( n == name ) then table.remove(A.order, i); break; end
	end
	Tidy(name);
	-- Taken but never changed: give it its own methods back.
	if ( not HasLayout(Opt(name)) ) then
		local f = GetFrame(name);
		local e = A.byName[name];
		if ( f and not (e and e.kind == "group") ) then Unlock(f); end
	end
	if ( A.current == name ) then A.current = A.order[table.getn(A.order)]; end
	SetCurrent(A.current);
	UpdateOptions();
end

local function ToggleMoving(name)
	if ( A.movers[name] ) then StopMoving(name); else StartMoving(name); end
end

local function StopAll()
	local names = {};
	for name in pairs(A.movers) do table.insert(names, name); end
	for _, name in ipairs(names) do StopMoving(name); end
end

-- Move the frame being moved by a step (the arrow keys on its overlay).
function Nudge(name, dx, dy)
	local m = A.movers[name or A.current or ""];
	if ( not m ) then return; end
	SetMoverRect(m, m:GetLeft() + dx, m:GetBottom() + dy);
	StoreFromMover(m);
end

A.SetCurrent = SetCurrent;
A.StoreFromMover = StoreFromMover;
A.StartMoving = StartMoving;
A.StopMoving = StopMoving;
A.ToggleMoving = ToggleMoving;
A.StopAll = StopAll;
A.Nudge = Nudge;
