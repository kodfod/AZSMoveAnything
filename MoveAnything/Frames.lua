local A = MoveAnything;
local L = A.L;

-- The frames the window lists before any the player adds.
-- { "FrameName", "Label" }, a { sep = "Heading" } between groups, and { hud = "part" } for the
-- parts of the game's own HUD, which the game draws outside the Lua UI: they can only be shown
-- or hidden (AZS_SetHudShown), never moved.
-- Names that start with MoveAnything are the addon's own stand-ins (tooltip spot, button rows)
-- from Spots.lua. A stock frame that this client does not have is left out of the list, and so
-- are the stock frames the game never uses (mail, tracking, durability, combo points, breath,
-- loot rolls, bags, loot and merchant windows, pet and stance bars, extra action bars, casting bar).
-- Flags: noScale (no resize handles), noHide (no Hide box), wh (handles change width/height),
-- minW / minH (the overlay is drawn at least this big, for frames with no size of their own),
-- widthOf (the frame to take the width of when the frame reports none).
local FRAME_LIST = {
	{ sep = "Unit frames" },
	{ "PlayerFrame", "Player" },
	{ "TargetFrame", "Target" },
	{ "PetFrame", "Pet" },
	{ "PartyMemberFrame1", "Party member 1" },
	{ "PartyMemberFrame2", "Party member 2" },
	{ "PartyMemberFrame3", "Party member 3" },
	{ "PartyMemberFrame4", "Party member 4" },

	{ sep = "Main bar" },
	{ "MainMenuBar", "Main bar (whole)" },
	{ "MainMenuBarArtFrame", "Main bar art and buttons" },
	{ "MainMenuExpBar", "Experience bar" },
	{ "MainMenuBarMaxLevelBar", "Max level bar" },
	{ "MainMenuBarLeftEndCap", "Left gryphon", noScale = true },
	{ "MainMenuBarRightEndCap", "Right gryphon", noScale = true },

	{ sep = "Button rows" },
	{ "MoveAnythingActionBar", "Spell buttons" },
	{ "MoveAnythingActionBarV", "Spell buttons (vertical)" },
	{ "MoveAnythingMicroBar", "Character and talent buttons" },
	{ "MoveAnythingMicroBarV", "Character and talent buttons (vertical)" },

	{ sep = "Minimap" },
	{ "MinimapCluster", "Minimap" },
	{ "MinimapZoneTextButton", "Minimap zone text" },
	{ "MinimapZoomIn", "Minimap zoom in" },
	{ "MinimapZoomOut", "Minimap zoom out" },
	{ "GameTimeFrame", "Day and night clock" },

	{ sep = "Screen" },
	{ "BuffFrame", "Buffs" },
	{ "TemporaryEnchantFrame", "Weapon buffs" },
	{ "MoveAnythingTooltip", "Tooltip", noScale = true, noHide = true },
	{ "FramerateLabel", "Framerate", noScale = true },
	{ "UIErrorsFrame", "Error messages" },
	{ "StaticPopup1", "Popup dialog" },
	-- Hidden until you press Enter, and sized by its anchors to the chat window: it only
	-- moves, and its overlay is drawn at least this big so there is something to grab.
	{ "ChatFrameEditBox", "Chat input box", noScale = true, noHide = true, minW = 256, minH = 32, widthOf = "ChatFrame1" },

	{ sep = "Windows" },
	{ "CharacterFrame", "Character" },

	{ sep = "Game HUD (show or hide only)" },
	{ hud = "clock", "Run clock and next boss" },
	{ hud = "bosses", "Boss and guardian bars" },
	{ hud = "tally", "Kills and gold" },
	{ hud = "build", "Spell and jewelry rows" },
	{ hud = "banners", "Messages in the middle of the screen" },
	{ hud = "loot", "Boss loot notice" },
	{ hud = "meter", "Damage meter" },
	{ hud = "levels", "Level Up! button" },
	{ hud = "flag", "Minimap lair flag" },
};

A.FRAME_LIST = FRAME_LIST;
