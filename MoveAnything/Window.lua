local A = MoveAnything;
local L, LF, GOLD, GREEN, GREY, TEXT, Tip, Button = A.L, A.LF, A.GOLD, A.GREEN, A.GREY, A.TEXT, A.Tip, A.Button;
local GetFrame, Exists, IsMoved, IsHidden, IsMoving, CustomNames = A.GetFrame, A.Exists, A.IsMoved, A.IsHidden, A.IsMoving, A.CustomNames;
local ToggleMoving, StopAll, ResetEntry, ResetAll, SetHidden = A.ToggleMoving, A.StopAll, A.ResetEntry, A.ResetAll, A.SetHidden;
local IsHudHidden, SetHudHidden, Pick, FrameUnderCursor = A.IsHudHidden, A.SetHudHidden, A.Pick, A.FrameUnderCursor;
local ProfileKey, LayoutMode, SetLayoutMode, ClassLabel = A.ProfileKey, A.LayoutMode, A.SetLayoutMode, A.ClassLabel;

-- The window: the list of movable frames, with Move, Hide and Reset for each. It is built of
-- the stock 1.12 templates.

local ROWS, ui, Update;

do
	-- Extra room for translated captions; keep this window within smaller screens.
	local W, H = 740, 606;
	local ROW_H = 22;
	local LIST_TOP = -84;
	ROWS = 18;

	ui = {};

	ui.frame = CreateFrame("Frame", "MoveAnythingOptions", UIParent);
	ui.frame:SetWidth(W);
	ui.frame:SetHeight(H);
	ui.frame:SetScale(math.min(1, (UIParent:GetWidth()-24)/W, (UIParent:GetHeight()-24)/H));
	ui.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20);
	ui.frame:SetFrameStrata("FULLSCREEN_DIALOG");
	ui.frame:SetToplevel(true);
	ui.frame:EnableMouse(true);
	ui.frame:EnableMouseWheel(true);
	ui.frame:SetMovable(true);
	ui.frame:SetClampedToScreen(true);
	ui.frame:RegisterForDrag("LeftButton");
	ui.frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	});
	ui.frame:Hide();
	ui.frame:SetScript("OnDragStart", function() this:StartMoving(); end);
	ui.frame:SetScript("OnDragStop", function() this:StopMovingOrSizing(); end);
	if ( UISpecialFrames ) then table.insert(UISpecialFrames, "MoveAnythingOptions"); end

	local header = ui.frame:CreateTexture(nil, "ARTWORK");
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header");
	header:SetWidth(300);
	header:SetHeight(64);
	header:SetPoint("TOP", ui.frame, "TOP", 0, 12);
	local title = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	title:SetPoint("TOP", header, "TOP", 0, -14);
	A.BindText(title, "MoveAnything!", 13);

	local close = CreateFrame("Button", "MoveAnythingOptionsClose", ui.frame, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -6, -6);

	-- The filter box.
	local filterLabel = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	filterLabel:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 26, -40);
	A.BindText(filterLabel, "Filter:", 11);
	ui.search = CreateFrame("EditBox", "MoveAnythingOptionsSearch", ui.frame, "InputBoxTemplate");
	ui.search:SetWidth(170);
	A.RegisterFont(ui.search, 12);
	ui.search:SetHeight(20);
	ui.search:SetPoint("LEFT", filterLabel, "RIGHT", 12, 0);
	if ( ui.search.SetAutoFocus ) then ui.search:SetAutoFocus(false); end
	ui.search:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	ui.search:SetScript("OnEnterPressed", function() this:ClearFocus(); end);
	ui.search:SetScript("OnTextChanged", function() Update(); end);

	ui.profile = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	A.RegisterFont(ui.profile, 11);
	ui.profile:SetWidth(300); ui.profile:SetJustifyH("RIGHT");
	ui.profile:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -30, -44);

	-- The column heads.
	local function Head(text, x, tipTitle, tipLine)
		local b = CreateFrame("Frame", nil, ui.frame);
		b:SetWidth(74);
		b:SetHeight(16);
		b:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", x, -64);
		b:EnableMouse(true);
		local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		fs:SetPoint("LEFT", b, "LEFT", 0, 0);
		A.BindText(fs, text, 10);
		if ( tipTitle ) then Tip(b, tipTitle, tipLine); end
	end
	Head("Frame", 28);
	Head("Move", 446, "Move",
		"Puts an overlay on the frame. Drag the overlay to move the frame. Drag a gold handle to scale it. Hold Alt while you drag a handle to change the width or the height. Right-click when you are done. Shift-right-click hides the overlay so you can see the frame. The arrow keys move the frame while the cursor is on the overlay.");
	Head("Hide", 522, "Hide", "Keeps the frame hidden. The game cannot show it again.");

	ui.scroll = CreateFrame("ScrollFrame", "MoveAnythingOptionsScroll", ui.frame, "FauxScrollFrameTemplate");
	ui.scroll:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 24, LIST_TOP);
	ui.scroll:SetPoint("BOTTOMRIGHT", ui.frame, "TOPRIGHT", -38, LIST_TOP - ROWS * ROW_H);
	ui.scroll:SetScript("OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll(ROW_H, Update);
	end);

	local function Wheel()
		local bar = getglobal("MoveAnythingOptionsScrollScrollBar");
		if ( bar ) then bar:SetValue(bar:GetValue() - arg1 * ROW_H * 3); end
	end
	ui.frame:SetScript("OnMouseWheel", Wheel);

	local function RowTooltip()
		local e = this.entry;
		if ( not e or e.kind == "sep" ) then return; end
		local tip = A.HelpTooltip();
		tip:SetOwner(this, "ANCHOR_RIGHT");
		tip:SetText(e.label or e.name);
		if ( e.kind == "hud" ) then
			tip:AddLine(L("The game draws this part itself. You can hide it, but you cannot move it. This is the same setting as Options > Interface."), 1, 1, 1, 1);
		else
			tip:AddLine(e.name, 0.7, 0.7, 0.7);
			if ( not GetFrame(e.name) and e.kind ~= "group" ) then
				tip:AddLine(L("This frame is not loaded now."), 1, 0.4, 0.4);
			end
		end
		A.StyleTooltip(tip); tip:Show();
	end

	ui.rows = {};
	for i = 1, ROWS do
		local name = "MoveAnythingOptionsRow" .. i;
		local row = CreateFrame("Button", name, ui.frame);
		row:SetWidth(W - 24 - 44);
		row:SetHeight(ROW_H);
		row:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 24, LIST_TOP - (i - 1) * ROW_H);
		row:SetFrameLevel(ui.scroll:GetFrameLevel() + 2);
		row:EnableMouseWheel(true);
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");
		row:SetScript("OnEnter", RowTooltip);
		row:SetScript("OnLeave", function() A.HideHelpTooltip(); end);
		row:SetScript("OnMouseWheel", Wheel);

		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		A.RegisterFont(row.label, 11);
		row.label:SetPoint("LEFT", row, "LEFT", 4, 0);
		row.label:SetWidth(400);
		row.label:SetHeight(18);
		row.label:SetJustifyH("LEFT");

		row.move = CreateFrame("CheckButton", name .. "Move", row, "UICheckButtonTemplate");
		row.move:SetWidth(24);
		row.move:SetHeight(24);
		row.move:SetPoint("LEFT", row, "LEFT", 422, 0);
		row.move:SetScript("OnClick", function()
			local e = this:GetParent().entry;
			if ( e ) then ToggleMoving(e.name); end
			Update();
		end);

		row.hide = CreateFrame("CheckButton", name .. "Hide", row, "UICheckButtonTemplate");
		row.hide:SetWidth(24);
		row.hide:SetHeight(24);
		row.hide:SetPoint("LEFT", row, "LEFT", 498, 0);
		row.hide:SetScript("OnClick", function()
			local e = this:GetParent().entry;
			if ( not e ) then return; end
			local on = this:GetChecked() and true or false;
			if ( e.kind == "hud" ) then SetHudHidden(e.part, on); else SetHidden(e.name, on); end
			Update();
		end);

		row.reset = Button(name .. "Reset", row, "Reset", 90, 20);
		row.reset:SetPoint("LEFT", row, "LEFT", 560, 0);
		row.reset:SetScript("OnClick", function()
			local e = this:GetParent().entry;
			if ( e ) then ResetEntry(e.name); end
		end);

		ui.rows[i] = row;
	end

	-- What's under the cursor (the frame finder), whom the layout is for, and the buttons.
	ui.finder = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	A.RegisterFont(ui.finder, 11);
	ui.finder:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 28, 106);
	ui.finder:SetWidth(W - 56);
	ui.finder:SetJustifyH("LEFT");

	local modeLabel = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	modeLabel:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 28, 68);
	A.BindText(modeLabel, "Layout for:", 11);

	-- Three choices that work as one: all heroes, this class, this hero (name and class).
	ui.modes = {};
	local function Mode(key, x, tipTitle, tipLine)
		local name = "MoveAnythingOptionsMode" .. (key or "Shared");
		local c = CreateFrame("CheckButton", name, ui.frame, "UICheckButtonTemplate");
		c:SetWidth(24);
		c:SetHeight(24);
		c:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", x, 62);
		c.mode, c.text = key, getglobal(name .. "Text");
		A.RegisterFont(c.text, 10); c.text:SetWidth(150); c.text:SetJustifyH("LEFT");
		c:SetScript("OnClick", function() SetLayoutMode(this.mode); Update(); end);
		Tip(c, tipTitle, tipLine);
		table.insert(ui.modes, c);
		return c;
	end
	Mode(nil, 126, "All heroes", "All heroes and classes use one layout.");
	Mode("class", 306, "This class", "All the heroes of this class use one layout. It starts as a copy of the layout in use.");
	Mode("hero", 496, "This hero", "Only this hero uses the layout. A hero is its name and its class, so the same name in another class has its own layout. It starts as a copy of the layout in use.");

	local closeButton = Button("MoveAnythingOptionsDone", ui.frame, "Close", 80);
	closeButton:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -22, 18);
	closeButton:SetScript("OnClick", function() ui.frame:Hide(); end);

	ui.resetAll = Button("MoveAnythingOptionsResetAll", ui.frame, "Reset All", 134);
	ui.resetAll:SetPoint("RIGHT", closeButton, "LEFT", -6, 0);
	ui.resetAll:SetScript("OnClick", function()
		-- Two clicks within three seconds, in place of a popup that would open behind this window.
		if ( this.armed and GetTime() - this.armed < 3 ) then
			this.armed = nil;
			this:SetText(L("Reset All"));
			ResetAll();
		else
			this.armed = GetTime();
			this:SetText(L("Click again"));
		end
	end);
	Tip(ui.resetAll, "Reset All", "Puts all the frames of this layout back where the game puts them. Push two times.");

	local stopAll = Button("MoveAnythingOptionsStopAll", ui.frame, "Done Moving", 130);
	stopAll:SetPoint("RIGHT", ui.resetAll, "LEFT", -6, 0);
	stopAll:SetScript("OnClick", function() StopAll(); end);
	Tip(stopAll, "Done Moving", "Removes the overlays from all the frames that you move.");

	local pick = Button("MoveAnythingOptionsPick", ui.frame, "Pick Frame", 130);
	pick:SetPoint("RIGHT", stopAll, "LEFT", -6, 0);
	pick:SetScript("OnClick", function() Pick(); end);
	Tip(pick, "Pick Frame",
		"Shows the frame under the cursor. Left-click to move it. The mouse wheel picks the frame under it. The frame then shows in the list under \"Your frames\". /move FrameName does the same with the name of a frame.");

	-- On the button row, left of Pick Frame. 160 wide holds the longest label (Portuguese,
	-- "Idioma: Português (Brasil)", about 134 at size 11).
	ui.language = Button("MoveAnythingLanguageButton", ui.frame, "Language", 160);
	ui.language:SetPoint("RIGHT", pick, "LEFT", -6, 0);
	ui.language:SetScript("OnClick", function() A.CycleLanguage(); end);
	Tip(ui.language, "Language", "Choose a language. Applies immediately. Automatic follows the game language.");
end

local function Paint(fs, c) fs:SetTextColor(c[1], c[2], c[3]); end

local function Matches(e, filter)
	if ( filter == "" ) then return true; end
	return string.find(string.lower(e.label or ""), filter, 1, true)
		or (e.name and string.find(string.lower(e.name), filter, 1, true));
end

local CUSTOM_SEP = { kind = "sep", label = L("Your frames") };

local function BuildList()
	CUSTOM_SEP.label = L("Your frames");
	local list = {};
	local filter = string.lower(ui.search:GetText() or "");
	local sep;
	local function Add(e)
		if ( sep ) then table.insert(list, sep); sep = nil; end
		table.insert(list, e);
	end
	for _, e in ipairs(A.entries) do
		if ( e.kind == "sep" ) then
			sep = e;
		elseif ( Exists(e) and Matches(e, filter) ) then
			Add(e);
		end
	end
	sep = CUSTOM_SEP;
	for _, name in ipairs(CustomNames()) do
		local e = A.byName[name];
		if ( e and Matches(e, filter) ) then Add(e); end
	end
	return list;
end

local function FillRow(row, e)
	row.label:SetText(e.label or e.name);
	if ( e.kind == "sep" ) then
		Paint(row.label, GOLD);
		row.move:Hide();
		row.hide:Hide();
		row.reset:Hide();
	elseif ( e.kind == "hud" ) then
		Paint(row.label, TEXT);
		row.move:Hide();
		row.hide:Show();
		row.hide:SetChecked(IsHudHidden(e.part));
		row.reset:Hide();
	else
		local changed = IsMoved(e.name) or IsHidden(e.name);
		if ( not Exists(e) ) then
			Paint(row.label, GREY);
		elseif ( changed ) then
			Paint(row.label, GREEN);
		else
			Paint(row.label, TEXT);
		end
		row.move:Show();
		row.move:SetChecked(IsMoving(e.name));
		if ( e.noHide ) then
			row.hide:Hide();
		else
			row.hide:Show();
			row.hide:SetChecked(IsHidden(e.name));
		end
		row.reset:Show();
		if ( changed or e.custom or IsMoving(e.name) ) then
			row.reset:Enable();
		else
			row.reset:Disable();
		end
	end
end

function Update()
	if ( not ui.frame:IsShown() or not ProfileKey() ) then return; end
	ui.frame:SetScale(math.min(1, (UIParent:GetWidth()-24)/740, (UIParent:GetHeight()-24)/650));
	ui.language:SetText(LF("Language: %s", A.LanguageLabel()));
	ui.resetAll:SetText(L(ui.resetAll.armed and "Click again" or "Reset All"));
	local list = BuildList();
	FauxScrollFrame_Update(ui.scroll, table.getn(list), ROWS, 22);
	local offset = FauxScrollFrame_GetOffset(ui.scroll);
	for i = 1, ROWS do
		local row, e = ui.rows[i], list[i + offset];
		row.entry = e;
		if ( e ) then
			row:Show();
			FillRow(row, e);
		else
			row:Hide();
		end
	end
	local mode = LayoutMode();
	for _, c in ipairs(ui.modes) do
		c:SetChecked(c.mode == mode);
		if ( c.mode == "class" ) then
			c.text:SetText(LF("This class (%s)", ClassLabel()));
		elseif ( c.mode == "hero" ) then
			-- A name can be twenty letters: the layout's name in the top right shows it.
			c.text:SetText(L("This hero"));
		else
			c.text:SetText(L("All heroes"));
		end
	end
	ui.profile:SetText(LF("Layout: %s", ProfileKey()));
end

local function ResetArm()
	ui.resetAll.armed = nil;
	ui.resetAll:SetText(L("Reset All"));
end

ui.frame:SetScript("OnShow", function()
	ui.search:ClearFocus();
	ResetArm();
	Update();
end);

-- The frame finder: the frame under the cursor, by the name that /move takes.
do
	local wait = 0;
	ui.frame:SetScript("OnUpdate", function()
		wait = wait - arg1;
		if ( wait > 0 ) then return; end
		wait = 0.2;
		if ( ui.resetAll.armed and GetTime() - ui.resetAll.armed >= 3 ) then ResetArm(); end
		if ( MouseIsOver and MouseIsOver(ui.frame) ) then
			ui.finder:SetText(L("Under the cursor: this window"));
			return;
		end
		local f = FrameUnderCursor();
		ui.finder:SetText(LF("Under the cursor: %s", f and f:GetName() or "-"));
	end);
end

local function ToggleWindow()
	if ( ui.frame:IsShown() ) then ui.frame:Hide(); else ui.frame:Show(); end
end

A.ui = ui;
A.UpdateOptions = Update;
A.ToggleWindow = ToggleWindow;
