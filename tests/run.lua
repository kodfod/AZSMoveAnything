-- Run from repository root: lua tests/run.lua
dofile("tests/mock.lua")
local toc=assert(io.open("MoveAnything/MoveAnything.toc","r"))
local files={}
for line in toc:lines() do
 local _,_,file=string.find(line,"^([%w_]+%.lua)%s*$")
 if file then table.insert(files,file) end
end
toc:close()
for _,file in ipairs(files) do assert(loadfile("MoveAnything/"..file))() end
fire("ADDON_LOADED","MoveAnything");fire("PLAYER_ENTERING_WORLD")
local A=MoveAnything
assert(A.profile and A.profileKey=="Default")

-- Root guards must hold through commands, direct API calls, aliases and saved data.
for _,name in ipairs({"UIParent","WorldFrame","GlueParent","GameMenuFrame","BenillaOptionsFrame","MoveAnythingOptions","MoveAnythingPicker"}) do
 assert(not A.AddCustom(name));assert(not A.GetFrame(name))
 SlashCmdList.MOVEANYTHING("hide "..name);SlashCmdList.MOVEANYTHING(name)
 assert(UIParent:IsShown() and not A.db.custom[name] and not A.profile[name])
end
AliasForRoot=UIParent;assert(not A.AddCustom("AliasForRoot"))
A.profile.UIParent={hidden=true,x=10,y=10}
A.RefreshPositions();assert(UIParent:IsShown() and not UIParent.MA_locked)
A.profile.UIParent=nil
A.HideFrame(UIParent);assert(UIParent:IsShown());assert(not A.Lock(UIParent))
print("PASS root guards: command, API, picker predicate, aliases and saved profiles")

-- Visibility requests made while hidden must survive restoring native methods.
local f=PlayerFrame
A.AddCustom("PlayerFrame");A.SetHidden("PlayerFrame",true)
assert(not f:IsShown());f:Show();assert(not f:IsShown())
f:Hide();A.SetHidden("PlayerFrame",false);assert(not f:IsShown())
f:Show();A.SetHidden("PlayerFrame",true)
local capturedShow,capturedHide=f.Show,f.Hide
local shows,hides=0,0
local newerShow=function(self) shows=shows+1;return capturedShow(self) end
local newerHide=function(self) hides=hides+1;return capturedHide(self) end
f.Show=newerShow;f.Hide=newerHide
A.SetHidden("PlayerFrame",false)
assert(f.Show==newerShow and f.Hide==newerHide and f:IsShown())
f:Hide();assert(not f:IsShown() and hides==1)
f:Show();assert(f:IsShown() and shows>=2)
print("PASS visibility: native intent and later hooks survive release and remain callable")

-- Every shadowed geometry method can be wrapped by another addon after ours.
A.profile.PlayerFrame={x=100,y=150,scale=1.25,w=220,h=80}
local originalPoint={f:GetPoint(1)};A.ApplyEntry("PlayerFrame")
local later,calls={},{}
for _,method in ipairs({"SetPoint","ClearAllPoints","SetAllPoints","SetScale","SetWidth","SetHeight"}) do
 local previous=f[method];local key=method
 if method=="SetPoint" then
  later[key]=function(self,p,rel,rp,x,y) calls[key]=(calls[key] or 0)+1;return previous(self,p,rel,rp,x,y) end
 elseif method=="ClearAllPoints" then
  later[key]=function(self) calls[key]=(calls[key] or 0)+1;return previous(self) end
 else
  later[key]=function(self,n) calls[key]=(calls[key] or 0)+1;return previous(self,n) end
 end
 f[method]=later[key]
end
A.ResetEntry("PlayerFrame")
for method,wrapper in pairs(later) do assert(f[method]==wrapper,"Lost later hook: "..method) end
f:ClearAllPoints();f:SetPoint("CENTER",UIParent,"CENTER",11,22)
f:SetScale(.9);f:SetWidth(150);f:SetHeight(45)
near(f:GetScale(),.9);near(f:GetWidth(),150);near(f:GetHeight(),45)
local p,rel,rp,x,y=f:GetPoint(1);near(x,11);near(y,22)
f:SetAllPoints(UIParent);assert(f:GetNumPoints()==2)
for method in pairs(later) do assert(calls[method] and calls[method]>=1,"Hook no longer forwards: "..method) end
print("PASS geometry hooks: all six later hooks retain identity and forwarding after reset")

-- Existing handling of dimensions derived from two anchors must not regress.
local sized=target("AnchorSized")
sized:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-20,20)
sized.GetWidth=function(self) return self.fixedW or (self:GetNumPoints()>1 and 600 or 0) end
sized.GetHeight=function(self) return self.fixedH or (self:GetNumPoints()>1 and 200 or 0) end
sized.SetWidth=function(self,n) self.fixedW=n end
sized.SetHeight=function(self,n) self.fixedH=n end
A.AddCustom("AnchorSized");A.profile.AnchorSized={x=50,y=60};A.ApplyEntry("AnchorSized")
near(sized:GetWidth(),600);near(sized:GetHeight(),200)
A.ResetEntry("AnchorSized");assert(sized:GetNumPoints()==2)

-- Inherited scale conversions: the mover's UI coordinates map to target coordinates.
local parent=target("ScaledParent");parent:SetScale(.7)
local child=target("ScaledChild",parent);child:SetScale(.9)
A.AddCustom("ScaledChild");assert(A.StartMoving("ScaledChild"))
local mover=A.movers.ScaledChild
mover:ClearAllPoints();mover:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",200,140)
A.StoreFromMover(mover)
local ratio=child:GetEffectiveScale()/UIParent:GetEffectiveScale()
near(child:GetLeft()*ratio,200);near(child:GetBottom()*ratio,140)
A.StopMoving("ScaledChild")
print("PASS multiple anchors and inherited-scale position conversion")

-- Shared, class and hero layouts copy values rather than aliasing tables.
A.ResetAll();A.profile.PlayerFrame={x=90,y=80};A.ApplyEntry("PlayerFrame")
A.SetLayoutMode("class");assert(A.profileKey=="Class: Warrior")
assert(A.profile.PlayerFrame.x==90)
A.profile.PlayerFrame.x=120;assert(A.db.profiles.Default.PlayerFrame.x==90)
A.SetLayoutMode("hero");assert(A.profileKey=="Hero: Tester (Warrior)")
assert(A.profile.PlayerFrame.x==120)
A.profile.PlayerFrame.x=180;A.SetLayoutMode(nil)
assert(A.profileKey=="Default" and A.profile.PlayerFrame.x==90)
A.CopyProfile("Hero: Tester (Warrior)");assert(A.profile.PlayerFrame.x==180)
assert(A.profile~=A.db.profiles["Hero: Tester (Warrior)"])
A.DeleteProfile("Hero: Tester (Warrior)");assert(not A.db.profiles["Hero: Tester (Warrior)"])
print("PASS shared/class/hero profiles, deep copy and profile deletion")

-- Missing frames are retried after an addon-load event.
A.profile.DelayedFrame={x=20,y=30};A.db.custom.DelayedFrame=true
A.RefreshPositions();assert(A.pending.DelayedFrame)
DelayedFrame=target("DelayedFrame");fire("ADDON_LOADED","LaterAddon")
assert(not A.pending.DelayedFrame and DelayedFrame.MA_locked)
print("PASS deferred frames")

-- Stand-in names must remain editable, including both button-row orientations.
local buttonNames={"ActionButton1","ActionButton2","ActionButton3","ActionButton4","ActionButton5","ActionButton6","ActionButton12"}
for i,name in ipairs(buttonNames) do
 local b=target(name,MainMenuBar);b:SetWidth(36);b:SetHeight(36)
end
assert(A.StartMoving("MoveAnythingActionBar"))
for _,name in ipairs(buttonNames) do assert(getglobal(name):GetParent()==MoveAnythingActionBar) end
assert(A.StartMoving("MoveAnythingActionBarV"))
assert(not A.byName.MoveAnythingActionBar.built)
for _,name in ipairs(buttonNames) do assert(getglobal(name):GetParent()==MoveAnythingActionBarV) end
A.ResetEntry("MoveAnythingActionBarV")
for _,name in ipairs(buttonNames) do
 local b=getglobal(name);assert(b:GetParent()==MainMenuBar and not b.MA_locked)
end
print("PASS horizontal/vertical button groups and original parent restoration")

-- Every language changes both captured captions and dynamically formatted labels.
A.ui.frame:Show()
for _,entry in ipairs(A.languages) do
 local code=entry[1]
 if code~="auto" then
  SlashCmdList.MOVEANYTHING("lang "..code)
  assert(A.language==code and A.db.settings.language==code)
  assert(A.ui.rows[1].label:GetText()==A.L("Unit frames"))
  assert(MoveAnythingOptionsDone:GetText()==A.L("Close"))
  assert(string.find(A.ui.language:GetText(),A.LanguageLabel(),1,true))
  local font=A.ui.rows[1].label:GetFont();assert(font==A.FontPath())
  local editFont=A.ui.search:GetFont();assert(editFont==A.FontPath())
  assert(A.ui.rows[1].label:GetHeight()<=22,"Row text must fit its line")
 end
end
for code in pairs(MoveAnything_LanguageProbes) do
 TOOLTIP_LANGUAGE=code;A.SetLanguage("auto");assert(A.language==code,"Automatic detection failed: "..code)
end
TOOLTIP_LANGUAGE=nil;A.SetLanguage("fr")
assert(not A.SetLanguage("not-a-language"));assert(A.language=="fr")
MoveAnything_Custom={Close="Fermer autrement",["This class (%s)"]="invalid %d"}
A.RefreshLanguage(true)
assert(MoveAnythingOptionsDone:GetText()=="Fermer autrement")
assert(A.L("This class (%s)")~=MoveAnything_Custom["This class (%s)"])
assert(A.ValidTranslation("%.2f %s %%","%.2f %s %%"))
assert(not A.ValidTranslation("%s %d","%d %s"))
assert(not A.ValidTranslation("%s",false))
assert(not A.ValidTranslation("%s","%s %z"))
assert(not A.ValidTranslation("%s","%s %"))
print("PASS 14 languages, live captions/fonts, automatic probes, overrides and placeholders")

-- Translation fonts stay private; regular game tooltips retain their font.
local nativeFont=GameTooltip:GetFont()
local help=A.HelpTooltip();help:AddLine("Test");A.StyleTooltip(help)
assert(GameTooltip:GetFont()==nativeFont)
local helpRegions={help:GetRegions()};assert(helpRegions[1]:GetFont()==A.FontPath())
UIParent.width=800;UIParent.height=600;A.UpdateOptions()
assert(A.ui.frame:GetWidth()*A.ui.frame:GetScale()<=776)
assert(A.ui.frame:GetHeight()*A.ui.frame:GetScale()<=576)
print("PASS scoped tooltip fonts and small-screen panel sizing")
dofile("tests/persistence.lua")
print("ALL TESTS PASSED (FrameXML mock; not an in-game visual test)")
