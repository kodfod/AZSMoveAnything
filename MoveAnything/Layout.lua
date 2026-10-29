local A = MoveAnything;
local ScaleOf, Raw = A.ScaleOf, A.Raw;

-- How a frame is held: the first time it is moved, its SetPoint / ClearAllPoints / SetAllPoints
-- (and SetScale, SetWidth, SetHeight once those are changed) are shadowed on the frame itself by
-- blockers, so the stock code (UIParent_ManageFramePositions and the like) can't put it back. The
-- real methods stay on the frame as MA_SetPoint and so on. A moved frame is anchored by its
-- BOTTOMLEFT to UIParent's, in its own scale, so it no longer follows its old parent around.
-- Hiding works the same way: Show is shadowed, so the frame stays hidden whatever shows it.

-- A later addon can wrap our blocker. On release, leave that newer wrapper in
-- place and make its captured blocker forward to the previous implementation.
-- Replacing only methods that still equal our wrapper prevents lost hooks;
-- deactivating the captured wrapper prevents a preserved hook from staying blocked.
local function Shadow(f, method)
	f.MA_hooks = f.MA_hooks or {};
	local hook = { active = true, previous = f[method] };
	if ( method == "SetPoint" ) then
		hook.wrapper = function(self, p, rel, rp, x, y)
			if ( not hook.active ) then return hook.previous(self, p, rel, rp, x, y); end
		end;
	elseif ( method == "ClearAllPoints" ) then
		hook.wrapper = function(self)
			if ( not hook.active ) then return hook.previous(self); end
		end;
	else
		hook.wrapper = function(self, value)
			if ( not hook.active ) then return hook.previous(self, value); end
		end;
	end
	f.MA_hooks[method] = hook;
	f[method] = hook.wrapper;
end

local function Release(f, method)
	local hook = f.MA_hooks and f.MA_hooks[method];
	if ( not hook ) then return; end
	hook.active = false;
	if ( f[method] == hook.wrapper ) then f[method] = hook.previous; end
	f.MA_hooks[method] = nil;
end

-- A frame's saved settings in the layout in use; `create` makes them.
local function Opt(name, create)
	local o = A.profile and A.profile[name];
	if ( not o and create and A.profile ) then
		o = {};
		A.profile[name] = o;
	end
	return o;
end

local function HasLayout(o)
	return o and (o.x or o.scale or o.w or o.h) and true;
end

-- Drop a settings table with nothing left in it.
local function Tidy(name)
	local o = Opt(name);
	if ( o and not HasLayout(o) and not o.hidden ) then
		A.profile[name] = nil;
	end
end

local function Lock(f)
	if ( A.IsProtected(f:GetName(), f) ) then return false; end
	if ( f.MA_locked ) then return true; end
	f.MA_locked = true;
	local orig = { scale = ScaleOf(f), w = f:GetWidth(), h = f:GetHeight(), points = {} };
	local n = f.GetNumPoints and f:GetNumPoints() or 0;
	for i = 1, n do
		local p, rel, rp, x, y = f:GetPoint(i);
		if ( p ) then
			table.insert(orig.points, { p, rel, rp, x, y });
		end
	end
	f.MA_orig = orig;
	f.MA_SetPoint, f.MA_ClearAllPoints, f.MA_SetAllPoints = f.SetPoint, f.ClearAllPoints, f.SetAllPoints;
	Shadow(f, "SetPoint"); Shadow(f, "ClearAllPoints"); Shadow(f, "SetAllPoints");
	-- The client's own layout cache must not put it somewhere else at the next load.
	if ( f.IsUserPlaced and f:IsUserPlaced() and f.SetUserPlaced ) then
		f:SetUserPlaced(false);
	end
	return true;
end

local function LockScale(f)
	if ( f.MA_SetScale ) then return; end
	f.MA_SetScale = f.SetScale;
	Shadow(f, "SetScale");
end

local function LockSize(f)
	if ( f.MA_SetWidth ) then return; end
	f.MA_SetWidth, f.MA_SetHeight = f.SetWidth, f.SetHeight;
	Shadow(f, "SetWidth"); Shadow(f, "SetHeight");
end

-- Back where and how big it was when MoveAnything first took it.
local function Restore(f)
	local o = f.MA_orig;
	if ( not o ) then return; end
	if ( f.MA_SetScale and o.scale ) then f.MA_SetScale(f, o.scale); end
	if ( f.MA_SetWidth ) then
		if ( o.w and o.w > 0 ) then f.MA_SetWidth(f, o.w); end
		if ( o.h and o.h > 0 ) then f.MA_SetHeight(f, o.h); end
	end
	if ( table.getn(o.points) > 0 ) then
		Raw(f, "ClearAllPoints")(f);
		for _, p in ipairs(o.points) do
			Raw(f, "SetPoint")(f, p[1], p[2] or f:GetParent() or UIParent, p[3], p[4], p[5]);
		end
	end
end

local function Unlock(f)
	if ( not f.MA_locked ) then return; end
	for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetAllPoints", "SetScale", "SetWidth", "SetHeight" }) do Release(f, method); end
	f.MA_SetPoint, f.MA_ClearAllPoints, f.MA_SetAllPoints = nil, nil, nil;
	f.MA_SetScale, f.MA_SetWidth, f.MA_SetHeight, f.MA_hooks = nil, nil, nil, nil;
	f.MA_locked, f.MA_orig, f.MA_sized = nil, nil, nil;
end

local function ApplyLayout(f, o)
	if ( not Lock(f) ) then return; end
	if ( o.scale ) then
		LockScale(f);
		f.MA_SetScale(f, o.scale);
	end
	if ( o.w or o.h ) then
		LockSize(f);
		if ( o.w ) then f.MA_SetWidth(f, o.w); end
		if ( o.h ) then f.MA_SetHeight(f, o.h); end
	end
	if ( o.x and o.y ) then
		-- A frame sized by two anchors would lose its size with them: give it its size outright
		-- (a hidden one may report none: then the size its entry gives, MA_fallbackW / H).
		if ( not f.MA_sized and table.getn(f.MA_orig.points) > 1 ) then
			f.MA_sized = true;
			local w = (f.MA_orig.w > 0) and f.MA_orig.w or f.MA_fallbackW;
			local h = (f.MA_orig.h > 0) and f.MA_orig.h or f.MA_fallbackH;
			if ( not o.w and w ) then Raw(f, "SetWidth")(f, w); end
			if ( not o.h and h ) then Raw(f, "SetHeight")(f, h); end
		end
		f.MA_ClearAllPoints(f);
		f.MA_SetPoint(f, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", o.x, o.y);
	end
end

local function HideFrame(f)
	if ( A.IsProtected(f:GetName(), f) ) then return; end
	if ( f.MA_hidden ) then return; end
	f.MA_hidden = true;
	f.MA_wantShown = f:IsShown();
	f.MA_Show, f.MA_Hide = f.Show, f.Hide;
	local hook = { active = true, show = f.Show, hide = f.Hide };
	hook.showWrapper = function(self)
		if ( hook.active ) then self.MA_wantShown = 1; else return hook.show(self); end
	end;
	hook.hideWrapper = function(self)
		if ( hook.active ) then self.MA_wantShown = nil; else return hook.hide(self); end
	end;
	f.MA_visibility = hook;
	f.Show, f.Hide = hook.showWrapper, hook.hideWrapper;
	f.MA_Hide(f);
end

local function ShowFrame(f)
	if ( not f.MA_hidden ) then return; end
	local hook = f.MA_visibility;
	hook.active = false;
	if ( f.Show == hook.showWrapper ) then f.Show = hook.show; end
	if ( f.Hide == hook.hideWrapper ) then f.Hide = hook.hide; end
	f.MA_visibility = nil;
	f.MA_Show, f.MA_Hide, f.MA_hidden = nil, nil, nil;
	if ( f.MA_wantShown ) then f:Show(); end
	f.MA_wantShown = nil;
end

local function ManagePositions()
	if ( UIParent_ManageFramePositions ) then pcall(UIParent_ManageFramePositions); end
end

-- Call fname's original, with pre run before it and post after it.
local function Hook(fname, pre, post)
	local orig = getglobal(fname);
	if ( type(orig) ~= "function" ) then return; end
	setglobal(fname, function(a1, a2, a3, a4, a5, a6)
		if ( pre ) then pre(a1, a2, a3, a4, a5, a6); end
		local r1, r2, r3 = orig(a1, a2, a3, a4, a5, a6);
		if ( post ) then post(a1, a2, a3, a4, a5, a6); end
		return r1, r2, r3;
	end);
end

A.Opt = Opt;
A.HasLayout = HasLayout;
A.Tidy = Tidy;
A.Lock = Lock;
A.LockScale = LockScale;
A.LockSize = LockSize;
A.Restore = Restore;
A.Unlock = Unlock;
A.ApplyLayout = ApplyLayout;
A.HideFrame = HideFrame;
A.ShowFrame = ShowFrame;
A.ManagePositions = ManagePositions;
A.Hook = Hook;
