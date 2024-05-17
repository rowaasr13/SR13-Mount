local a_name, a_env = ...

-- [AUTOLOCAL START]
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetInstanceInfo = GetInstanceInfo
local GetMountIDs = C_MountJournal.GetMountIDs
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID
local IsAdvancedFlyableArea = IsAdvancedFlyableArea
local IsInInstance = IsInInstance
local IsMounted = IsMounted
local IsSpellKnown = IsSpellKnown
local IsSubmerged = IsSubmerged
local UnitLevel = UnitLevel
local _G = _G
local format = string.format
local pairs = pairs
local print = print
local random = random
local type = type
local wipe = wipe
-- [AUTOLOCAL END]

local low_prio_mount = {
   [ 32243] = 1, -- Tawny Wind Rider
   [ 32244] = 1, -- Blue Wind Rider
   [ 32245] = 1, -- Green Wind Rider
   [ 32246] = 1, -- Red Wind Rider
   [ 32295] = 1, -- Swift Green Wind Rider
   [ 32296] = 1, -- Swift Yellow Wind Rider
   [ 32297] = 1, -- Swift Purple Wind Rider
   [ 59791] = 1, -- Wooly Mammoth (Alliance)
   [ 59793] = 1, -- Wooly Mammoth (Horde)
   [ 61230] = 1, -- Armored Blue Wind Rider
   [ 88748] = 1, -- Brown Riding Camel
   [ 88749] = 1, -- Tan Riding Camel
   [102346] = 1, -- Swift Forest Strider
   [102350] = 1, -- Swift Lovebird
   [130086] = 1, -- Brown Riding Goat
   [130137] = 1, -- White Riding Goat
   [130138] = 1, -- Black Riding Goat
}

local available = {
   ground          = {},
   ground_low_prio = {},
   pvp             = {},
   shop            = {},
   herbalism       = {},
   flying          = {},
   flying_low_prio = {},
   watergliding    = {},
   vashjir         = {},
   slow            = {},
   shadowlands_the_maw = {},
   dragonriding    = {},
   underwater      = {},
}

local prio = {}

local name = {}
local spellIDs = {}
local mount_types = {}
local player_can_fly
local player_true_maw_walker
local player_can_fly_in_shadowlands
local herbalism_local_name

local function IsPlayerTrueMawWalker()
   if player_true_maw_walker then return true end

   player_true_maw_walker = C_QuestLog.IsQuestFlaggedCompleted(63994) -- Who is the Maw Walker? (https://www.wowhead.com/quest=63994)
   return player_true_maw_walker
end

local function PlayerCanFlyInShadowlands()
   if player_can_fly_in_shadowlands then return true end

   player_can_fly_in_shadowlands = C_QuestLog.IsQuestFlaggedCompleted(63893) -- "Shadowlands Flying" spell (https://www.wowhead.com/spell=352177) marks this quest as complete
   return player_can_fly_in_shadowlands
end

local shadowlands_flying_uimapid = { [1525] --[[Revendreth]] = true, [1533] --[[Bastion]] = true, [1536] --[[Maldraxxus]] = true, [1565] --[[Ardenwald]] = true }

local function ClassicFlyingEnabled(instanceType, instanceMapID)
   if instanceType == 'pvp' then return end
   if instanceMapID ==  974 then return end -- Darkmoon Faire
   if instanceMapID == 1064 then return end -- Isle of Thunder

   if not player_can_fly then
      -- Master/Expert/Artisan Riding, allows flying mounts to actually fly
      player_can_fly = IsSpellKnown(90265) or IsSpellKnown(34090) or IsSpellKnown(34091)
   end
   if not player_can_fly then return end

   if instanceMapID == 2222 then -- The Shadowlands
      if not PlayerCanFlyInShadowlands() then return end
      return shadowlands_flying_uimapid[C_Map_GetBestMapForUnit("player")]
   end

   if instanceMapID == 2444 or instanceMapID == 2454 then -- Dragon Isles + Zaralek Cavern
      local _, _, _, completed = GetAchievementInfo(19307) -- Dragon Isles Pathfinder
      return completed
   end

   return true
end

local function ScanMounts()
   for _, category in pairs(available) do
      wipe(category)
   end

   local mount_ids = GetMountIDs()
   for idx = 1, #mount_ids do
      repeat
         local mountID = mount_ids[idx]
         local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID, isForDragonriding = GetMountInfoByID(mountID)

         if not isUsable then break end

         name[mountID] = creatureName
         spellIDs[mountID] = spellID

         -- no need to retrieve mount type more than once
         local mount_type = mount_types[spellID]
         if not mount_type then
            local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = GetMountInfoExtraByID(mountID)

            mount_type = mountType
            mount_types[spellID] = mount_type
         end

         if spellID == 179244 or spellID == 179245 then
            local prefix = "slow"
            local tbl = available[prefix] tbl[#tbl + 1] = mountID
            break
         end

         if spellID == 228919 then -- Darkwater Skate -- use type 254 instead?
            local prefix = "underwater"
            local tbl = available[prefix] tbl[#tbl + 1] = mountID
            break
         end

         if spellID == 367826 then break end -- Siege Turtle, only increases swim speed

         if isForDragonriding then
            local prefix = "dragonriding"
            local tbl = available[prefix] tbl[#tbl + 1] = mountID
            break
         end

         local prefix = "ground"
         if low_prio_mount[spellID] then
            local tbl = available[prefix .. "_low_prio"] tbl[#tbl + 1] = mountID
         else
            local tbl = available[prefix] tbl[#tbl + 1] = mountID
         end

         if mount_type == 248 then
            local prefix = "flying"
            if low_prio_mount[spellID] then
               local tbl = available[prefix .. "_low_prio"] tbl[#tbl + 1] = mountID
            else
               local tbl = available[prefix] tbl[#tbl + 1] = mountID
            end
         end

         if mount_type == 269 then
            local tbl = available.watergliding tbl[#tbl + 1] = mountID
         end

         if spellID == 61425 or spellID == 61447 then
            local tbl = available.shop tbl[#tbl + 1] = mountID
         end

         if spellID == 75207 then
            local tbl = available.vashjir tbl[#tbl + 1] = mountID
         end

         if spellID == 134359 then
            local tbl = available.herbalism tbl[#tbl + 1] = mountID
         end

         if spellID == 87090 or spellID == 87091 then
            local tbl = available.pvp tbl[#tbl + 1] = mountID
         end

         if spellID == 344578 then
            local tbl = available.shadowlands_the_maw tbl[#tbl + 1] = mountID
         end

      until true
   end
end

local function PlayerHasHerbalism()
   if (herbalism_local_name == nil or herbalism_local_name == '') then
      local herbalism_skill_line_id = C_TradeSkillUI.GetProfessionSkillLineID(Enum.Profession.Herbalism)
      if herbalism_skill_line_id then herbalism_local_name = C_TradeSkillUI.GetTradeSkillDisplayName(herbalism_skill_line_id) end
      if herbalism_local_name == '' then herbalism_local_name = nil end
   end

   local prof1, prof2 = GetProfessions()
   if prof1 then
      local name, icon = GetProfessionInfo(prof1)
      if icon == 4620675 then return true end
      if name and herbalism_local_name and name == herbalism_local_name then return true end
   end
   if not has_herbalism and prof2 then
      local name, icon = GetProfessionInfo(prof2)
      if icon == 4620675 then return true end
      if name and herbalism_local_name and name == herbalism_local_name then return true end
   end
end

local function Mount(args)
   local alt_mode
   local is_alt_mode_on = args.is_alt_mode_on
   if is_alt_mode_on then alt_mode = is_alt_mode_on() end

   if not IsMounted() then
      wipe(prio)

      ScanMounts()

      local has_herbalism = (#available.herbalism > 0) and PlayerHasHerbalism()

      local instanceName, instanceType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID = GetInstanceInfo()

      if args.print then
         local uiMapID = C_Map_GetBestMapForUnit("player")
         args.print(
            "mounts available " ..
            " G:" .. #available.ground ..
            " F:" .. #available.flying ..
            " S:" .. #available.shop ..
            " W:" .. #available.watergliding ..
            " H:" .. #available.herbalism ..
            " D:" .. #available.dragonriding ..
            " instance (" .. instanceMapID .. ">" .. (uiMapID or "nil") .. ") " .. instanceName
         )
      end

      local classic_flying_enabled = ClassicFlyingEnabled(instanceType, instanceMapID)

      local is_submerged = IsSubmerged()

      if is_submerged then
         if instanceMapID == 0 then
            local uiMapID = C_Map_GetBestMapForUnit("player")
            local is_vashjir = uiMapID >= 201 and uiMapID <= 205 and uiMapID ~= 202 -- 202 is Gilneas
            if is_vashjir then
               prio[#prio + 1] = "vashjir"
               prio[#prio + 1] = "underwater"
            end
         end
         if alt_mode then
            prio[#prio + 1] = "underwater"
         end
      end

      if IsAdvancedFlyableArea() and not alt_mode then
         prio[#prio + 1] = "dragonriding"
      end

      if instanceType == "pvp" then
         prio[#prio + 1] = "pvp"
         prio[#prio + 1] = "ground"
      end

      if instanceMapID == 1756 then -- The Deaths of Chromie
         prio[#prio + 1] = "flying"
         prio[#prio + 1] = "flying_low_prio"
      end

      if not alt_mode and IsInInstance() then
         prio[#prio + 1] = "shop"
      end

      if has_herbalism then
         prio[#prio + 1] = "herbalism"
      end

      if classic_flying_enabled then
         prio[#prio + 1] = "flying"
         prio[#prio + 1] = "flying_low_prio"
      end

      if IsAdvancedFlyableArea() and alt_mode then
         prio[#prio + 1] = "dragonriding"
      end

      if is_swimming then
         prio[#prio + 1] = "watergliding"
      end

      prio[#prio + 1] = "ground"
      prio[#prio + 1] = "ground_low_prio"
      prio[#prio + 1] = "slow"

      if instanceMapID == 2364 then -- The Shadowlands > The Maw (intro scenario)
         if not IsPlayerTrueMawWalker() then
            wipe(prio)
            prio[1] = "shadowlands_the_maw"
         end
      end

      if instanceMapID == 2222 then
         local uiMapID = C_Map_GetBestMapForUnit("player")
         if
            uiMapID == 1543 -- The Shadowlands > The Maw
            or uiMapID == 1961 -- The Shadowlands > Korthia
         then
            if not IsPlayerTrueMawWalker() then
               wipe(prio)
               prio[1] = "shadowlands_the_maw"
            end
         end
      end

      local mount_category, mount_count, pick_idx, mountID
      for idx = 1, #prio do
         mount_category = prio[idx]
         local mount_list = available[mount_category]
         mount_count = #mount_list
         if mount_count > 0 then
            pick_idx = random(mount_count)
            mountID = mount_list[pick_idx]
            break
         end
      end

      if mountID then
         if args.print then args.print(format("mount: %s %s %d/%d %s(%d)", (alt_mode and "alt " or ""), mount_category, pick_idx, mount_count, name[mountID], spellIDs[mountID])) end
         C_MountJournal.SummonByID(mountID)
         return true
      end
   end
end

local a_export = {
   Summon = Mount
}

_G[a_name] = a_export
