local addonName, addon = ...
LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceConsole-3.0')

-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
local minimapButtonCreated = false

local function createMinimapButton(iconPath)
   if minimapButtonCreated then return end
   local prettyName = "Whee Remaining"
   local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
      type = "data source",
      text = prettyName,
      icon = iconPath,
      OnClick = function(self, btn)
         addon:displayWheeTimers()
      end,
      OnTooltipShow = function(tooltip)
         if not tooltip or not tooltip.AddLine then return end
         tooltip:AddLine(prettyName)
      end,
   })
   local icon = LibStub("LibDBIcon-1.0", true)
   icon:Register(addonName, miniButton, buffTimersDB)
   minimapButtonCreated = true
end

-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

-- deepcopy from http://lua-users.org/wiki/CopyTable

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


-- https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

-- initialize can be called at any event

-- keys for persistent data
local playerNameKey
local realmNameKey

local function initialize()
   -- init all our data structures
   playerNameKey, realmNameKey = UnitFullName("player")
   if not playerNameKey or not realmNameKey then return end

   if not buffTimersDB then
      buffTimersDB = {}
   end

   -- scrub old first generation data
   if buffTimersDB.players then buffTimersDB.players = nil end

   -- new structure is buffTimersDB.realms[realmNameKey].players[playerNameKey]

   if not buffTimersDB.realms then
      buffTimersDB.realms = {}
   end
   if not buffTimersDB.realms[realmNameKey] then
      buffTimersDB.realms[realmNameKey] = {}
   end
   if not buffTimersDB.realms[realmNameKey].players then
      buffTimersDB.realms[realmNameKey].players = {}
   end
   if not buffTimersDB.realms[realmNameKey].players[playerNameKey] then
      buffTimersDB.realms[realmNameKey].players[playerNameKey] = {}
   end

   createMinimapButton("Interface\\Icons\\spell_misc_emotionhappy")
end

local function displayTime(time)
  local days = floor(time/86400)
  local hours = floor(mod(time, 86400)/3600)
  local minutes = floor(mod(time,3600)/60)
  local seconds = floor(mod(time,60))
  return format("%d:%02d:%02d:%02d",days,hours,minutes,seconds)
end

local function saveBuffs()
   -- iterate over buffs and save them to our persistent DB
   local playerBuffs = {}
   local now = GetTime()
   AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraData)
      local auraDataCopy = deepcopy(auraData)
      if auraData.duration > 0 then
         auraDataCopy.remaining = auraData.expirationTime - now
      end
      playerBuffs[auraDataCopy.spellId] = auraDataCopy
   end, true)
   buffTimersDB.realms[realmNameKey].players[playerNameKey] = playerBuffs
end

function addon:displayBuffTimers()
   saveBuffs()
   local now = GetTime()
   AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraData)
      if auraData.duration > 0 then
         local remaining = auraData.expirationTime - now
         addon:Print(displayTime(remaining), "/", displayTime(auraData.duration), auraData.name)
      end
   end, true)
end

local function eventHandler(self, event, ...)
   if InCombatLockdown() then return end -- don't query buffs in combat
   if "UNIT_AURA" == event then
      saveBuffs()
   end
end

function addon:OnEnable()
   initialize() -- OnInitialize is too early, realm from UnitFullName doesn't exist yet
   addon.eventFrame = CreateFrame("Frame")
   addon.eventFrame:SetScript("OnEvent", eventHandler)
   addon.eventFrame:RegisterEvent("UNIT_AURA")
   local version = C_AddOns.GetAddOnMetadata(addonName, "Version") -- from TOC file
   addon:Print("Version " .. version)
end

function buffTimers_OnAddonCompartmentClick(addonName, mouseButton, button)
   displayBuffTimers()
end

SLASH_BUFFTIMERS1="/bufftimers"
SlashCmdList["BUFFTIMERS"] = function(msg)
   addon:displayBuffTimers()
end

function addon:displayWheeTimers()
   local count = 0
   -- display sorted by time left
   local timesLeft = {}
   local noTimeLeft = {} -- known chars with no buff
   local noTimeLeftCount = 0
   for realm, realmStuff in pairs(buffTimersDB.realms) do
      for player, buffs in pairs(realmStuff.players) do
         local char = player .. " - " .. realm
         if buffs and buffs[46668] then
            timesLeft[buffs[46668].remaining] = char
            count = count + 1
         else
            noTimeLeft[char] = 0
            noTimeLeftCount = noTimeLeftCount + 1
         end
      end
   end
   if 0 == count then
      addon:Print("No WHEE! buff on any character") 
   else
      for time, char in spairs(timesLeft) do
         -- the WHEE! buff only lasts an hour so trim the day and hour fields from the time display
         addon:Print(string.sub(displayTime(time), 6) .. " " .. char)
      end
      if noTimeLeftCount > 0 then
         addon:Print("Characters with no buff:")
         local prefix = " "
         for char, _ in spairs(noTimeLeft) do
            addon:Print(prefix .. char)
         end
      end
   end
end

SLASH_WHEETIMERS1="/wheetimers"
SlashCmdList["WHEETIMERS"] = function(msg)
   addon:displayWheeTimers()
end

SLASH_WT1="/wt"
SlashCmdList["WT"] = function(msg)
   addon:displayWheeTimers()
end
