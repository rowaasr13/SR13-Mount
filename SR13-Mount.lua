local a_name, a_env = ...

-- [AUTOLOCAL START]
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetInstanceInfo = GetInstanceInfo
local GetMountIDs = C_MountJournal.GetMountIDs
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID
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

local globalFavoriteFlying = {
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
}

local prio = {}

local name = {}
local spellIDs = {}
local mount_types = {}
local player_can_fly

local function Mount(args)
   if not IsMounted() then
      for _, category in pairs(available) do
         wipe(category)
      end
      wipe(prio)

      local mount_ids = GetMountIDs()
      for idx = 1, #mount_ids do
         repeat
            local mountID = mount_ids[idx]
            local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, isFiltered, isCollected, mountID = GetMountInfoByID(mountID)

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
               local tbl = available.slow tbl[#tbl + 1] = mountID
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

         until true
      end

      local have_herbalism
      local prof1, prof2 = GetProfessions()
      if prof1 then
         local _, icon = GetProfessionInfo(prof1)
         if icon == 136246 then have_herbalism = true end
      end
      if not have_herbalism and prof2 then
         local _, icon = GetProfessionInfo(prof2)
         if icon == 136246 then have_herbalism = true end
      end

      local instanceName, instanceType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapID = GetInstanceInfo()

      if args.print then args.print(
         "mounts available " ..
         " G:" .. #available.ground ..
         " F:" .. #available.flying ..
         " S:" .. #available.shop ..
         " W:" .. #available.watergliding ..
         " H:" .. #available.herbalism
      ) end

      if not player_can_fly then
         player_can_fly = IsSpellKnown(90265) or IsSpellKnown(34090) -- Master or Expert Riding, allows flying mounts to actually fly
      end

      local no_fly_zone =
         (not player_can_fly)
         or instanceType == 'pvp'
         or instanceMapID == 1064                                -- Isle of Thunder
         or ((
               instanceMapID == 1642                             -- Zandalar
            or instanceMapID == 1643                             -- Kul Tiras
            or instanceMapID == 1718                             -- Nazjatar
         ) and not IsSpellKnown(278833))                         -- Battle for Azeroth Pathfinder Rank 2
         or (instanceMapID == 2222)                              -- The Shadowlands

      local is_submerged = IsSubmerged()

      if is_submerged then
         if instanceMapID == 0 then
            local uiMapID = C_Map_GetBestMapForUnit("player")
            local is_vashjir = uiMapID >= 201 and uiMapID <= 205 and uiMapID ~= 202 -- 202 is Gilneas
            if is_vashjir then
               prio[#prio + 1] = "vashjir"
            end
         end
      end

      if instanceMapID == 2364 then -- The Shadowlands > The Maw (intro scenario)
         return
      end

      if instanceMapID == 2222 then
         local uiMapID = C_Map_GetBestMapForUnit("player")
         if uiMapID == 1543 then -- The Shadowlands > The Maw
            return
         end
      end

      if instanceType == "pvp" then
         prio[#prio + 1] = "pvp"
         prio[#prio + 1] = "ground"
      end

      if instanceMapID == 1756 then -- The Deaths of Chromie
         prio[#prio + 1] = "flying"
         prio[#prio + 1] = "flying_low_prio"
      end

      if IsInInstance() then
         prio[#prio + 1] = "shop"
      end

      if have_herbalism  then
         prio[#prio + 1] = "herbalism"
      end

      if not no_fly_zone then
         prio[#prio + 1] = "flying"
         prio[#prio + 1] = "flying_low_prio"
      end

      if is_swimming then
         prio[#prio + 1] = "watergliding"
      end

      prio[#prio + 1] = "ground"
      prio[#prio + 1] = "ground_low_prio"
      prio[#prio + 1] = "slow"

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
         if args.print then args.print(format("mount: %s %d/%d %s(%d)", mount_category, pick_idx, mount_count, name[mountID], spellIDs[mountID])) end
         C_MountJournal.SummonByID(mountID)
         return true
      end
   end
end

local a_export = {
   Summon = Mount
}

_G[a_name] = a_export
