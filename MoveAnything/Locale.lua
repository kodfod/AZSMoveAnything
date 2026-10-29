local A = MoveAnything;

-- Only addon-owned text uses these fonts. Native game font objects are not changed.
A.languages = {
	{ "auto", "Automatic" }, { "en", "English" }, { "pl", "Polski" }, { "cs", "Čeština" },
	{ "de", "Deutsch" }, { "pt", "Português (Brasil)" }, { "es", "Español" }, { "fr", "Français" },
	{ "ro", "Română" }, { "tr", "Türkçe" }, { "ru", "Русский" }, { "uk", "Українська" },
	{ "zh", "简体中文" }, { "ja", "日本語" }, { "ko", "한국어" },
};
local aliases = { enUS="en", enGB="en", plPL="pl", csCZ="cs", deDE="de", ptBR="pt", esES="es",
	esMX="es", frFR="fr", roRO="ro", trTR="tr", ruRU="ru", ukUA="uk", zhCN="zh", jaJP="ja", koKR="ko" };
local fonts, bindings = {}, {};
local function Signature(text)
	local tokens = {};
	text = string.gsub(text, "%%%%", "");
	for token in string.gfind(text, "%%[-+ #0]*%d*%.?%d*[cdeEfgGiouXxqs]") do table.insert(tokens, token); end
	local remainder = string.gsub(text, "%%[-+ #0]*%d*%.?%d*[cdeEfgGiouXxqs]", "");
	if ( string.find(remainder, "%%") ) then return nil; end
	return table.concat(tokens, "|");
end
function A.ValidTranslation(base, value)
	if ( type(value) ~= "string" or value == "" ) then return false; end
	local signature = Signature(base);
	return signature ~= nil and signature == Signature(value);
end
function A.FontPath()
	local code = A.language;
	local suffix = (code == "zh" or code == "ja" or code == "ko") and "-" .. code .. ".otf" or ".ttf";
	return "Interface\\AddOns\\MoveAnything\\media\\MoveAnythingSans" .. suffix;
end
local function ApplyFont(region, size)
	if ( region.GetFontString ) then region = region:GetFontString(); end
	if ( region and region.SetFont ) then
		local old, oldSize, flags;
		if ( region.GetFont ) then old, oldSize, flags = region:GetFont(); end
		region:SetFont(A.FontPath(), size or oldSize or 12, flags);
	end
end
function A.RegisterFont(region, size)
	if ( not region ) then return; end
	table.insert(fonts, { region=region, size=size }); ApplyFont(region, size);
end
function A.BindText(region, key, size)
	table.insert(bindings, { region=region, key=key });
	A.RegisterFont(region, size); region:SetText(A.L(key));
end
function A.LanguageLabel()
	local code = A.db and A.db.settings.language or "auto";
	if ( not code or code == "auto" ) then return A.L("Automatic"); end
	for _, entry in ipairs(A.languages) do if ( entry[1] == code ) then return entry[2]; end end
	return A.L("Automatic");
end

-- GetLocale can stay enUS while AZS is translated. A private, hidden tooltip probes
-- three native spell names; the class resolves the English/Turkish overlap.
local function DetectLanguage()
	local probes = MoveAnything_LanguageProbes;
	local candidates;
	if ( not A.languageTip ) then
		A.languageTip = CreateFrame("GameTooltip", "MoveAnythingLanguageTooltip", UIParent, "GameTooltipTemplate");
	end
	local tip = A.languageTip;
	if ( tip.SetHyperlink and tip.ClearLines ) then
		for _, probe in ipairs({ {133,"fireball"}, {116,"frostbolt"}, {686,"shadow_bolt"} }) do
			tip:SetOwner(UIParent, "ANCHOR_NONE"); tip:ClearLines();
			local ok = pcall(function() tip:SetHyperlink("enchant:" .. probe[1]); end);
			local fs = getglobal("MoveAnythingLanguageTooltipTextLeft1");
			local name = ok and fs and fs:GetText(); tip:Hide();
			if ( name and name ~= "" ) then
				local matches, count, single = {}, 0, nil;
				for code, entries in pairs(probes) do
					if ( entries["ability." .. probe[2] .. ".name"] == name and (not candidates or candidates[code]) ) then
						matches[code]=true; count=count+1; single=code;
					end
				end
				if ( count == 1 ) then return single; end
				if ( count > 0 ) then candidates=matches; end
			end
		end
	end
	local class = UnitClass and UnitClass("player");
	local count, single = 0, nil;
	for code, entries in pairs(probes) do
		if ( not candidates or candidates[code] ) then
			for key, value in pairs(entries) do
				if ( string.find(key,"^class%.") and value==class ) then count=count+1; single=code; end
			end
		end
	end
	if ( count == 1 ) then return single; end
	local fallback = aliases[GetLocale and GetLocale() or "enUS"] or "en";
	return (not candidates or candidates[fallback]) and fallback or "en";
end
function A.RefreshLanguage(force)
	local setting = A.db and A.db.settings.language;
	local code = (setting and setting ~= "auto" and (setting=="en" or MoveAnything_Locales[setting])) and setting or DetectLanguage();
	if ( code == A.language and not force ) then return; end
	A.language=code;
	A.HideHelpTooltip();
	for _, entry in ipairs(fonts) do ApplyFont(entry.region, entry.size); end
	for _, entry in ipairs(bindings) do entry.region:SetText(A.L(entry.key)); end
	for _, entry in ipairs(A.entries) do if ( entry.labelKey ) then entry.label=A.L(entry.labelKey); end end
	for _, mover in pairs(A.movers) do mover.label:SetText(mover.entry.label or mover.name); end
	if ( A.UpdateOptions ) then A.UpdateOptions(); end
	if ( A.RefreshBindingLabels ) then A.RefreshBindingLabels(); end
end
function A.SetLanguage(code)
	if ( code~="auto" and code~="en" and not MoveAnything_Locales[code] ) then return false; end
	A.db.settings.language=code; A.RefreshLanguage(true); return true;
end
function A.CycleLanguage()
	local current = A.db.settings.language or "auto";
	local nextIndex = 1;
	for i, entry in ipairs(A.languages) do if ( entry[1]==current ) then nextIndex=i+1; end end
	if ( nextIndex>table.getn(A.languages) ) then nextIndex=1; end
	A.SetLanguage(A.languages[nextIndex][1]);
end

-- A dedicated help tooltip avoids changing the game's shared tooltip fonts.
function A.HelpTooltip()
	if ( not A.helpTip ) then A.helpTip=CreateFrame("GameTooltip", "MoveAnythingHelpTooltip", UIParent, "GameTooltipTemplate"); end
	return A.helpTip;
end
function A.StyleTooltip(tip)
	if ( tip.GetRegions ) then
		local regions={tip:GetRegions()};
		for _, region in ipairs(regions) do if ( region.GetObjectType and region:GetObjectType()=="FontString" ) then ApplyFont(region); end end
	end
end
function A.HideHelpTooltip() if ( A.helpTip ) then A.helpTip:Hide(); end end
