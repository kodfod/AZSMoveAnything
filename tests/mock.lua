-- Geometry-aware legacy FrameXML mock. No game files or saved games are touched.
NOW=100;objects={};SlashCmdList={};UISpecialFrames={};messages={};writes=0
TOOLTIP_LANGUAGE=nil;TEST_NAME="Tester";TEST_CLASS="WARRIOR";CURSOR_X=100;CURSOR_Y=100;HUD={}
local M={}
local function invoke(f,script,a)
 local prevThis,prevArg=this,arg1;this=f;arg1=a
 if f.scripts[script] then f.scripts[script]() end
 this=prevThis;arg1=prevArg
end
function M:GetName() return self.name end
function M:GetObjectType() return self.kind end
function M:GetParent() return self.parent end
function M:SetParent(p) self.parent=p end
function M:SetScript(k,f) self.scripts[k]=f end
function M:GetScript(k) return self.scripts[k] end
function M:RegisterEvent(k) self.events[k]=true end
function M:GetWidth() return self.width or 100 end
function M:GetHeight() return self.height or 30 end
function M:SetWidth(n) self.width=n end
function M:SetHeight(n) self.height=n end
function M:GetScale() return self.scale or 1 end
function M:SetScale(n) self.scale=n;writes=writes+1 end
function M:GetEffectiveScale() return self:GetScale()*(self.parent and self.parent:GetEffectiveScale() or 1) end
function M:GetNumPoints() return table.getn(self.points) end
function M:GetPoint(i) if self.points[i or 1] then return unpack(self.points[i or 1]) end end
function M:SetPoint(p,rel,rp,x,y)
 if type(rel)=="string" then rel=getglobal(rel) end
 table.insert(self.points,{p,rel,rp,x or 0,y or 0});writes=writes+1
end
function M:ClearAllPoints() self.points={} end
function M:GetCenter()
 if self==UIParent then return self:GetWidth()/2,self:GetHeight()/2 end
 if self.noGeometry then return nil end
 local point=self.points[1]
 if not point then return self.cx or 0,self.cy or 0 end
 local rel=point[2] or self.parent or UIParent
 local rx,ry=rel:GetCenter();if not rx then return nil end
 local factors={CENTER={0,0},TOPLEFT={-.5,.5},TOPRIGHT={.5,.5},BOTTOMLEFT={-.5,-.5},BOTTOMRIGHT={.5,-.5},LEFT={-.5,0},RIGHT={.5,0},TOP={0,.5},BOTTOM={0,-.5}}
 local a=factors[point[1]] or factors.CENTER;local b=factors[point[3]] or factors.CENTER
 local ratio=rel:GetEffectiveScale()/self:GetEffectiveScale()
 return (rx+b[1]*rel:GetWidth())*ratio+point[4]-a[1]*self:GetWidth(),(ry+b[2]*rel:GetHeight())*ratio+point[5]-a[2]*self:GetHeight()
end
function M:Show() local old=self.shown;self.shown=true;if not old then invoke(self,"OnShow") end end
function M:Hide() local old=self.shown;self.shown=false;if old then invoke(self,"OnHide") end end
function M:IsShown() return self.shown end
function M:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function M:SetText(s) local changed=self.text~=s;self.text=s;if changed then invoke(self,"OnTextChanged") end end
function M:GetText() return self.text or "" end
function M:SetFont(path,size) self.font=path;self.fontSize=size;return true end
function M:GetFont() return self.font or "Fonts\\FRIZQT__.TTF",self.fontSize or 12,"" end
function M:GetFontString()
 if self.kind=="FontString" or self.kind=="EditBox" then return self end
 if not self.fontString then self.fontString=self:CreateFontString(nil);self.fontString.text=self.text end
 return self.fontString
end
function M:GetStringWidth() return string.len(self:GetText())*(self.fontSize or 12)*.5 end
function M:Enable() self.enabled=true end
function M:Disable() self.enabled=false end
function M:StartMoving() self.moving=true end
function M:StopMovingOrSizing() self.moving=false end
function M:SetFocus() self.focus=true end
function M:ClearFocus() self.focus=false end
function M:ClearLines()
 local line=self.name and getglobal(self.name.."TextLeft1")
 if line then line:SetText("") end
 self.lines={}
end
function M:SetHyperlink(link)
 if TOOLTIP_LANGUAGE then
  local key=link=="enchant:133" and "fireball" or link=="enchant:116" and "frostbolt" or "shadow_bolt"
  local line=getglobal(self.name.."TextLeft1") or CreateFrame("FontString",self.name.."TextLeft1",self)
  line:SetText(MoveAnything_LanguageProbes[TOOLTIP_LANGUAGE]["ability."..key..".name"])
 end
end
for _,k in ipairs({"SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetHighlightTexture","SetPointDummy","SetTextColor","SetJustifyH","SetJustifyV","SetTextInsets","SetAutoFocus","SetMaxLetters","EnableMouse","SetMovable","SetClampedToScreen","RegisterForDrag","RegisterForClicks","SetOwner","EnableMouseWheel","EnableKeyboard","SetToplevel","SetTexture","SetVertexColor"}) do M[k]=function() end end
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,scripts={},events={},points={},shown=true,template=template},{__index=M})
 if name then _G[name]=f end
 if name and template=="UICheckButtonTemplate" then CreateFrame("FontString",name.."Text",f) end
 table.insert(objects,f);return f
end
function M:CreateFontString(name) return CreateFrame("FontString",name,self) end
function M:CreateTexture(name) return CreateFrame("Texture",name,self) end
function M:SetAllPoints(relative)
 self:ClearAllPoints();self:SetPoint("TOPLEFT",relative or self.parent,"TOPLEFT",0,0)
 self:SetPoint("BOTTOMRIGHT",relative or self.parent,"BOTTOMRIGHT",0,0)
end
function M:GetLeft() local x=self:GetCenter();return x and x-self:GetWidth()/2 end
function M:GetBottom() local x,y=self:GetCenter();return y and y-self:GetHeight()/2 end
function M:GetTop() local x,y=self:GetCenter();return y and y+self:GetHeight()/2 end
function M:SetFrameLevel(n) self.level=n end
function M:GetFrameLevel() return self.level or 1 end
function M:SetFrameStrata(s) self.strata=s end
function M:GetFrameStrata() return self.strata or "MEDIUM" end
function M:SetChecked(on) self.checked=on end
function M:GetChecked() return self.checked end
function M:GetRegions()
 local list={};for _,f in ipairs(objects) do if f.parent==self and (f.kind=="FontString" or f.kind=="Texture") then table.insert(list,f) end end
 return unpack(list)
end
function M:AddLine(text) local f=self:CreateFontString(nil);f:SetText(text) end
function M:SetUserPlaced(on) self.userPlaced=on end
function M:IsUserPlaced() return self.userPlaced end
function M:SetValue(n) self.value=n end
function M:GetValue() return self.value or 0 end
function getglobal(name) return _G[name] end
function setglobal(name,value) _G[name]=value end
UIParent=CreateFrame("Frame","UIParent");UIParent.width=1920;UIParent.height=1080;UIParent.cx=960;UIParent.cy=540
WorldFrame=CreateFrame("Frame","WorldFrame",UIParent)
DEFAULT_CHAT_FRAME={AddMessage=function(self,text) table.insert(messages,text) end}
GameTooltip=CreateFrame("GameTooltip","GameTooltip",UIParent)
GameMenuFrame=CreateFrame("Frame","GameMenuFrame",UIParent)
BenillaGameMenuButtonEditMode=CreateFrame("Button","BenillaGameMenuButtonEditMode",GameMenuFrame)
function GetTime() return NOW end
function GetLocale() return "enUS" end
function UnitClass()
 if TOOLTIP_LANGUAGE then return MoveAnything_LanguageProbes[TOOLTIP_LANGUAGE]["class.warrior.name"],TEST_CLASS end
 return "Warrior",TEST_CLASS
end
function UnitName() return TEST_NAME end
function IsShiftKeyDown() return SHIFT end
function fire(ev,name) event=ev;arg1=name;this=MoveAnything.events;this.scripts.OnEvent() end
function tick(dt) NOW=NOW+dt;arg1=dt;this=MoveAnything.events;this.scripts.OnUpdate() end
function click(f) invoke(f,"OnClick") end
function drag(f) invoke(f,"OnDragStart") end
function drop(f) invoke(f,"OnDragStop") end
function close(f) f:Hide() end
function near(a,b) assert(math.abs(a-b)<.00001,tostring(a).." != "..tostring(b)) end
function target(name,parent)
 local f=CreateFrame("Frame",name,parent or UIParent)
 f:SetWidth(180);f:SetHeight(60);f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-40)
 return f
end
PlayerFrame=target("PlayerFrame");TargetFrame=target("TargetFrame");TargetFrame:Hide()
MinimapCluster=target("MinimapCluster");MainMenuBar=target("MainMenuBar")
ChatFrame1=target("ChatFrame1");BuffFrame=target("BuffFrame")
-- These APIs must never be called by an interface arrangement addon.
for _,name in ipairs({"SetCVar","SendChatMessage","SendAddonMessage","CastSpellByName","PickupAction","PlaceAction","ReloadUI"}) do
 _G[name]=function() error("Unexpected game/network write: "..name) end
end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset(f) return f.offset or 0 end
function FauxScrollFrame_OnVerticalScroll(height,update) update() end
function AZS_SetHudShown(part,on) HUD[part]=on end
function AZS_IsHudShown(part) return HUD[part]~=false end
function MouseIsOver() return false end
function GetMouseFocus() return FOCUS end
function GetCursorPosition() return CURSOR_X,CURSOR_Y end
function EnumerateFrames(previous)
 local found=not previous
 for _,f in ipairs(objects) do
  if found and f.kind~="FontString" and f.kind~="Texture" then return f end
  if f==previous then found=true end
 end
end
function PlaySound() end
function HideUIPanel(f) f:Hide() end
function UIParent_ManageFramePositions() end
function SetBinding(key,action) BINDING_KEY=key;BINDING_ACTION=action end
function GetBindingAction() return "" end
