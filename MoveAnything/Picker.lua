local A = MoveAnything;
local L, Print, STRATA, BACKDROP, MIN_SIZE = A.L, A.Print, A.STRATA, A.BACKDROP, A.MIN_SIZE;
local UIScale, Clamp, EffScale, StartMoving = A.UIScale, A.Clamp, A.EffScale, A.StartMoving;

-- Finding frames: the one under the cursor, and the picker that outlines what it would take.

local function Ignored(f)
	local name = f:GetName();
	return not name or A.IsProtected(name, f) or string.find(name, "^MoveAnything");
end

-- Every named, visible frame under the cursor, topmost first.
local function FramesUnderCursor()
	local list = {};
	if ( not EnumerateFrames ) then return list; end
	local cx, cy = GetCursorPosition();
	local screen = UIParent:GetWidth() * UIParent:GetHeight() * UIScale() * UIScale();
	local f = EnumerateFrames();
	while ( f ) do
		if ( f:IsVisible() and not Ignored(f) ) then
			local l, b = f:GetLeft(), f:GetBottom();
			if ( l and b ) then
				local s = EffScale(f);
				local w, h = (f:GetWidth() or 0) * s, (f:GetHeight() or 0) * s;
				l, b = l * s, b * s;
				local area = w * h;
				if ( area > 0 and area < screen * 0.8 and cx >= l and cx <= l + w and cy >= b and cy <= b + h ) then
					table.insert(list, { f = f, area = area, strata = STRATA[f:GetFrameStrata() or "MEDIUM"] or 3,
						level = f:GetFrameLevel() or 0 });
				end
			end
		end
		f = EnumerateFrames(f);
	end
	table.sort(list, function(a, b)
		if ( a.strata ~= b.strata ) then return a.strata > b.strata; end
		if ( a.level ~= b.level ) then return a.level > b.level; end
		return a.area < b.area;
	end);
	for i, v in ipairs(list) do list[i] = v.f; end
	return list;
end

local function FrameUnderCursor()
	local f = GetMouseFocus and GetMouseFocus();
	while ( f and Ignored(f) ) do
		f = f.GetParent and f:GetParent();
	end
	if ( not f ) then
		f = FramesUnderCursor()[1];
	end
	return f;
end

local picker = CreateFrame("Frame", "MoveAnythingPicker", UIParent);
picker:SetAllPoints(UIParent);
picker:SetFrameStrata("TOOLTIP");
picker:EnableMouse(true);
picker:EnableMouseWheel(true);
picker:Hide();
picker.box = CreateFrame("Frame", nil, picker);
picker.box:SetBackdrop(BACKDROP);
picker.box:SetBackdropColor(0.2, 0.5, 1, 0.25);
picker.box:SetBackdropBorderColor(0.3, 0.7, 1, 1);
picker.name = picker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
A.RegisterFont(picker.name, 15);
picker.name:SetPoint("BOTTOM", picker.box, "TOP", 0, 4);
picker.help = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
picker.help:SetPoint("TOP", picker, "TOP", 0, -90);
A.BindText(picker.help, "Pick a frame. Left-click moves it. The mouse wheel picks the frame under it. Right-click or Escape stops.", 12);
picker.help:SetWidth(600); picker.help:SetHeight(60);
picker.index, picker.wait = 1, 0;

local function PickerUpdate()
	picker.list = FramesUnderCursor();
	local n = table.getn(picker.list);
	picker.index = Clamp(picker.index, 1, math.max(n, 1));
	local f = picker.list[picker.index];
	if ( not f ) then
		picker.box:Hide();
		picker.name:SetText("");
		return;
	end
	local k = EffScale(f) / UIScale();
	picker.box:ClearAllPoints();
	picker.box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", f:GetLeft() * k, f:GetBottom() * k);
	picker.box:SetWidth(math.max(f:GetWidth() * k, MIN_SIZE));
	picker.box:SetHeight(math.max(f:GetHeight() * k, MIN_SIZE));
	picker.box:Show();
	local text = f:GetName();
	if ( n > 1 ) then text = text .. "  (" .. picker.index .. "/" .. n .. ")"; end
	picker.name:SetText(text);
end

picker:SetScript("OnUpdate", function()
	picker.wait = picker.wait - arg1;
	if ( picker.wait > 0 ) then return; end
	picker.wait = 0.1;
	PickerUpdate();
end);
picker:SetScript("OnMouseWheel", function()
	picker.index = picker.index - arg1;
	PickerUpdate();
end);
picker:SetScript("OnMouseUp", function()
	local f = picker.list and picker.list[picker.index];
	picker:Hide();
	if ( arg1 == "LeftButton" and f ) then StartMoving(f:GetName()); end
end);
picker:SetScript("OnKeyDown", function()
	if ( arg1 == "ESCAPE" ) then picker:Hide(); end
end);
picker:SetScript("OnShow", function()
	picker.index, picker.wait, picker.list = 1, 0, nil;
	if ( this.EnableKeyboard ) then this:EnableKeyboard(true); end
end);
picker:SetScript("OnHide", function()
	if ( this.EnableKeyboard ) then this:EnableKeyboard(false); end
end);

local function Pick()
	if ( not EnumerateFrames ) then
		Print(L("This client cannot list its frames. Type /move FrameName instead."));
		return;
	end
	if ( picker:IsShown() ) then picker:Hide(); else picker:Show(); end
end

A.FramesUnderCursor = FramesUnderCursor;
A.FrameUnderCursor = FrameUnderCursor;
A.Pick = Pick;
