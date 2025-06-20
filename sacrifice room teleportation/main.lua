local mod = RegisterMod('Sacrifice Room Teleportation', 1)
local json = require('json')
local game = Game()

mod.onGameStartHasRun = false

mod.seed = nil
mod.stage = nil
mod.collectible = nil
mod.spawnStairs = false
mod.rng = RNG()
mod.rngShiftIdx = 35

mod.eidDescriptions = { '', '', '', '', '', '', '', '', '', '', '', '' }

mod.state = {}
mod.state.giveDreamCatcher = REPENTOGON == nil
mod.state.spoilTeleport = false
mod.state.openClosetWithKeyPieces = false
mod.state.transformKeyPiecesToKnifePieces = false
mod.state.stages = { -- 0-10
  darkRoom = 10,
  chest = 10,
  theVoid = 2,
  corpseII = 0,
  home = 0,
  sheol = 0,
  cathedral = 0,
  depthsII = 0,
  mausoleumII = 0,
  wombII = 0,
  hush = 0, -- ???
  basementI = 0,
  basementI_d4 = 0,
  basementI_genesis = 0,
  basementI_deathCert = 0,
  preAscent = 0,
}

function mod:onGameStart()
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      for _, v in ipairs({ 'giveDreamCatcher', 'spoilTeleport', 'openClosetWithKeyPieces', 'transformKeyPiecesToKnifePieces' }) do
        if type(state[v]) == 'boolean' then
          mod.state[v] = state[v]
        end
      end
      if type(state.stages) == 'table' then
        for _, v in ipairs({ 'darkRoom', 'chest', 'theVoid', 'corpseII', 'home', 'sheol', 'cathedral', 'depthsII', 'mausoleumII', 'wombII', 'hush', 'basementI', 'basementI_d4', 'basementI_genesis', 'basementI_deathCert', 'preAscent' }) do
          if math.type(state.stages[v]) == 'integer' and state.stages[v] >= 0 and state.stages[v] <= 10 then
            mod.state.stages[v] = state.stages[v]
          end
        end
      end
    end
  end
  
  mod.onGameStartHasRun = true
  mod:onNewRoom()
end

function mod:onGameExit()
  mod:save()
  mod:seedRng()
  mod.seed = nil
  mod.stage = nil
  mod.collectible = nil
  mod.spawnStairs = false
  mod.onGameStartHasRun = false
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onPreLevelSelect(stage, stageType)
  if not mod.onGameStartHasRun then
    return
  end
  
  if game:IsGreedMode() then
    return
  end
  
  if stage == LevelStage.STAGE6 and stageType == StageType.STAGETYPE_ORIGINAL then -- dark room
    return mod:goToNewStage(true)
  end
end

function mod:onNewRoom()
  if not mod.onGameStartHasRun then
    return
  end
  
  if game:IsGreedMode() then
    return
  end
  
  local level = game:GetLevel()
  local room = level:GetCurrentRoom()
  local roomDesc = level:GetCurrentRoomDesc()
  local stage = level:GetStage()
  local currentDimension = mod:getCurrentDimension()
  
  mod:updateEid()
  
  if mod.seed then
    if stage == LevelStage.STAGE6 and not level:IsAltStage() and -- dark room
       level:GetCurrentRoomIndex() == level:GetStartingRoomIndex() and room:IsFirstVisit() and currentDimension == 0
    then
      mod:goToNewStage(false)
    end
    
    mod.seed = nil
    mod.stage = nil
  end
  
  if mod.state.openClosetWithKeyPieces then
    -- home
    if stage == LevelStage.STAGE8 and roomDesc.GridIndex == 95 and currentDimension == 0 and mod:hasBothKeyPieces() then
      level:MakeRedRoomDoor(roomDesc.GridIndex, DoorSlot.LEFT0)
      local door = room:GetDoor(DoorSlot.LEFT0)
      if door then
        -- door_house.anm2 (door_closet_red.png) doesn't include key animations
        local sprite = door:GetSprite()
        door:SetVariant(DoorVariant.DOOR_LOCKED_KEYFAMILIAR)
        sprite:Load('gfx/grid/door_01_normaldoor.anm2', false)
        sprite:ReplaceSpritesheet(0, 'gfx/grid/door_00_reddoor.png') -- background
        sprite:ReplaceSpritesheet(1, 'gfx/grid/door_00_reddoor.png') -- door1
        sprite:ReplaceSpritesheet(2, 'gfx/grid/door_00_reddoor.png') -- door2
        sprite:ReplaceSpritesheet(3, 'gfx/grid/door_00_reddoor.png') -- frame
        sprite:ReplaceSpritesheet(4, 'gfx/grid/door_00_reddoor.png') -- key
        sprite:LoadGraphics()
        sprite:Play('KeyClosed')
        door.OpenAnimation = 'GoldenKeyOpen'
      end
    end
  end
  
  if mod.state.transformKeyPiecesToKnifePieces then
    -- mausoleum ii/xl
    if (stage == LevelStage.STAGE3_2 or (mod:isCurseOfTheLabyrinth() and stage == LevelStage.STAGE3_1)) and mod:isRepentanceStageType() and
       roomDesc.SafeGridIndex == level:GetRooms():Get(level:GetLastBossRoomListIndex()).SafeGridIndex and room:IsFirstVisit() and currentDimension == 0 and
       not game:GetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED) and
       not game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT) and
       not game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
    then
      mod:transformKeyPiecesToKnifePieces()
    end
  end
  
  if mod.spawnStairs then
    if stage == LevelStage.STAGE1_1 and not mod:isRepentanceStageType() and
       room:GetType() == RoomType.ROOM_ISAACS and roomDesc.GridIndex == GridRooms.ROOM_DEVIL_IDX and roomDesc.Data.Subtype == 99 and
       not game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
    then
      for _, v in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, 0, false, false)) do
        v:Remove()
        Isaac.GridSpawn(GridEntityType.GRID_STAIRS, 3, v.Position, true)
      end
    end
    
    mod.spawnStairs = false
  end
end

-- this needs to happen a frame after onNewRoom
function mod:onUpdate()
  if game:IsGreedMode() then
    return
  end
  
  if mod.collectible then
    if mod.collectible == CollectibleType.COLLECTIBLE_D4 then
      for i = 0, game:GetNumPlayers() - 1 do
        local player = game:GetPlayer(i)
        player:UseActiveItem(mod.collectible, 0, -1, 0) -- repentogon: player:RerollAllCollectibles
      end
      if REPENTOGON then
        ItemOverlay.Show(Giantbook.D4, 3, nil)
      end
    elseif mod.collectible == CollectibleType.COLLECTIBLE_GENESIS then
      local player = game:GetPlayer(0)
      player:UseActiveItem(mod.collectible, 0, -1, 0)
      mod.spawnStairs = true
    elseif mod.collectible == CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE then
      local player = game:GetPlayer(0)
      player:UseActiveItem(mod.collectible, 0, -1, 0)
    end
    
    mod.collectible = nil
  end
end

-- unfortunately game:StartStageTransition crashes randomly
-- we'll use the normal transition to the dark room, then switch to a new stage in the new level
-- dream catcher can make the level transition show the correct stage
-- level:SetStage + 'forget me now' seems to get overriden by the teleport to the dark room
function mod:onPlayerUpdate(player)
  if not game:IsGreedMode() and game:IsPaused() and not mod.seed then
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local stage = level:GetStage()
    local sprite = player:GetSprite()
    
    if room:GetType() == RoomType.ROOM_SACRIFICE then
      local isCoopBaby = player:GetBabySkin() ~= BabySubType.BABY_UNASSIGNED
      if (not isCoopBaby and sprite:IsPlaying('TeleportUp')) or
         (    isCoopBaby and sprite:IsPlaying('Hit')) -- baby's don't teleport for whatever reason
      then
        if mod:hasSpikesGte(player.Position, 12) then
          -- adding dream catcher from here doesn't work correctly
          mod.seed = room:GetSpawnSeed() -- GetAwardSeed, GetDecorationSeed
          mod.stage = mod:isRepentanceStageType() and stage + 1 or stage
        end
      end
    end
  end
end

-- filtered to ENTITY_PLAYER
function mod:onEntityTakeDmg(entity, amount, dmgFlags, source, countdown)
  if not mod.state.giveDreamCatcher then
    return
  end
  
  if not game:IsGreedMode() then
    local room = game:GetRoom()
    
    -- source.Type == EntityType.ENTITY_NULL and source.Variant == GridEntityType.GRID_SPIKES
    if room:GetType() == RoomType.ROOM_SACRIFICE and dmgFlags & DamageFlag.DAMAGE_SPIKES == DamageFlag.DAMAGE_SPIKES then
      local player = entity:ToPlayer()
      local playerPosition = player.Position
      if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B then
        playerPosition = player:GetOtherTwin().Position -- PLAYER_THESOUL_B
      end
      if player:GetBabySkin() ~= BabySubType.BABY_UNASSIGNED then
        player = game:GetPlayer(0) -- need a non-baby to give dream catcher to
      end
      
      if mod:hasSpikesGte(playerPosition, 12 - 1) then
        if not player:HasCollectible(CollectibleType.COLLECTIBLE_DREAM_CATCHER, true) then
          -- add dream catcher before the paused teleport animation happens
          player:AddCollectible(CollectibleType.COLLECTIBLE_DREAM_CATCHER, 0, true, nil, 0)
        end
      end
    end
  end
end

function mod:hasSpikesGte(pos, num)
  local room = game:GetRoom()
  local gridIdx = room:GetGridIndex(pos)
  
  local x = 1
  local y = room:GetGridWidth()
  
  -- very simple algorithm to check current index plus 8 surrounding indexes
  -- sometimes you seem to get pushed slightly off the spike index
  -- there should only ever be one spike in a sacrifice room
  for _, v in ipairs({
                       0,      -- center
                       -x,     -- left
                       x,      -- right
                       -y,     -- up
                       y,      -- down
                       -x - y, -- top-left
                       x - y,  -- top-right
                       -x + y, -- bottom-left
                       x + y,  -- bottom-right
                    })
  do
    local gridEntity = room:GetGridEntity(gridIdx + v)
    if gridEntity and gridEntity:GetType() == GridEntityType.GRID_SPIKES and gridEntity.VarData >= num then
      return true
    end
  end
  
  return false
end

function mod:goToNewStage(doReturn)
  if mod.seed then
    local stage = nil
    local stageType = nil
    local stageName = mod:getRandomStage(mod.seed)
    local rng = RNG()
    rng:SetSeed(mod.seed, mod.rngShiftIdx)
    
    if stageName == 'chest' then
      stage = LevelStage.STAGE6
      stageType = StageType.STAGETYPE_WOTL
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'theVoid' then
      stage = LevelStage.STAGE7
      stageType = StageType.STAGETYPE_ORIGINAL
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'corpseII' then
      stage = LevelStage.STAGE4_2
      stageType = StageType.STAGETYPE_REPENTANCE
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage + 1, mod.stage)
    elseif stageName == 'home' then
      stage = LevelStage.STAGE8
      stageType = StageType.STAGETYPE_ORIGINAL
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'sheol' then
      stage = LevelStage.STAGE5
      stageType = StageType.STAGETYPE_ORIGINAL
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'cathedral' then
      stage = LevelStage.STAGE5
      stageType = StageType.STAGETYPE_WOTL
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'depthsII' then
      stage = LevelStage.STAGE3_2
      stageType = { StageType.STAGETYPE_ORIGINAL, StageType.STAGETYPE_WOTL, StageType.STAGETYPE_AFTERBIRTH }
      game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'mausoleumII' then
      stage = LevelStage.STAGE3_2
      stageType = { StageType.STAGETYPE_REPENTANCE, StageType.STAGETYPE_REPENTANCE_B }
      game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage + 1, mod.stage)
    elseif stageName == 'wombII' then
      stage = LevelStage.STAGE4_2
      stageType = { StageType.STAGETYPE_ORIGINAL, StageType.STAGETYPE_WOTL, StageType.STAGETYPE_AFTERBIRTH }
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'hush' then
      stage = LevelStage.STAGE4_3
      stageType = StageType.STAGETYPE_ORIGINAL
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage, mod.stage)
    elseif stageName == 'basementI' or stageName == 'basementI_d4' or stageName == 'basementI_genesis' or stageName == 'basementI_deathCert' then
      stage = LevelStage.STAGE1_1
      stageType = { StageType.STAGETYPE_ORIGINAL, StageType.STAGETYPE_WOTL, StageType.STAGETYPE_AFTERBIRTH }
      game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage, mod.stage)
      
      if stageName == 'basementI_d4' then
        mod.collectible = CollectibleType.COLLECTIBLE_D4
      elseif stageName == 'basementI_genesis' then
        mod.collectible = CollectibleType.COLLECTIBLE_GENESIS
      elseif stageName == 'basementI_deathCert' then
        mod.collectible = CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE
      end
    elseif stageName == 'preAscent' then
      stage = LevelStage.STAGE3_2
      stageType = { StageType.STAGETYPE_REPENTANCE, StageType.STAGETYPE_REPENTANCE_B }
      game:SetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED, false)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH_INIT, true)
      game:SetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH, false)
      game:SetStateFlag(GameStateFlag.STATE_HEAVEN_PATH, false)
      mod:forgetStageSeeds(stage + 1, mod.stage)
    end
    
    mod.seed = nil
    mod.stage = nil
    
    if stage and stageType then
      if type(stageType) == 'table' then
        stageType = stageType[rng:RandomInt(#stageType) + 1]
      end
      
      if doReturn then
        return { stage, stageType }
      end
      
      local stageTypeMap = {
        [StageType.STAGETYPE_ORIGINAL]     = '',
        [StageType.STAGETYPE_WOTL]         = 'a',
        [StageType.STAGETYPE_AFTERBIRTH]   = 'b',
        [StageType.STAGETYPE_REPENTANCE]   = 'c',
        [StageType.STAGETYPE_REPENTANCE_B] = 'd',
      }
      Isaac.ExecuteCommand('stage ' .. stage .. stageTypeMap[stageType])
    end
  end
end

function mod:getRandomStage(seed)
  local function sortStages(a, b)
    return a.name < b.name
  end
  
  local weightedStages = {}
  local totalWeight = 0
  
  for k, v in pairs(mod.state.stages) do
    table.insert(weightedStages, { name = k, weight = v })
    totalWeight = totalWeight + v
  end
  
  table.sort(weightedStages, sortStages)
  
  if totalWeight > 0 then
    local rng = RNG()
    rng:SetSeed(seed, mod.rngShiftIdx)
    local rand = rng:RandomInt(totalWeight) + 1
    for _, v in ipairs(weightedStages) do
      rand = rand - v.weight
      if rand <= 0 then
        return v.name
      end
    end
  end
  
  return nil
end

function mod:hasBothKeyPieces()
  local hasKeyPiece1 = false
  local hasKeyPiece2 = false
  
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1, false) then
      hasKeyPiece1 = true
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2, false) then
      hasKeyPiece2 = true
    end
  end
  
  return hasKeyPiece1 and hasKeyPiece2
end

function mod:transformKeyPiecesToKnifePieces()
  if not mod:hasBothKeyPieces() then
    return
  end
  
  local hasKnifePiece1 = false
  local hasKnifePiece2 = false
  
  for i = 0, game:GetNumPlayers() - 1 do
    local player = game:GetPlayer(i)
    if player:HasCollectible(CollectibleType.COLLECTIBLE_KNIFE_PIECE_1, false) then
      hasKnifePiece1 = true
    end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_KNIFE_PIECE_2, false) then
      hasKnifePiece2 = true
    end
  end
  
  if not (hasKnifePiece1 and hasKnifePiece2) then
    for i = 0, game:GetNumPlayers() - 1 do
      local player = game:GetPlayer(i)
      if not hasKnifePiece1 and player:HasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1, false) then
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1, false, nil, true)
        player:AddCollectible(CollectibleType.COLLECTIBLE_KNIFE_PIECE_1, 0, true, nil, 0)
        hasKnifePiece1 = true
      end
      if not hasKnifePiece2 and player:HasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2, false) then
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2, false, nil, true)
        player:AddCollectible(CollectibleType.COLLECTIBLE_KNIFE_PIECE_2, 0, true, nil, 0)
        hasKnifePiece2 = true
      end
    end
    
    -- make the new knife look like the key, at least until you quit/continue
    local knives = Isaac.FindByType(EntityType.ENTITY_FAMILIAR, FamiliarVariant.KNIFE_FULL, -1, false, false)
    if #knives > 0 then
      local sprite = knives[1]:GetSprite()
      sprite:Load('gfx/003.028_full key.anm2', true)
    end
  end
end

function mod:isRepentanceStageType()
  local level = game:GetLevel()
  local stageType = level:GetStageType()
  
  return stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B
end

function mod:isCurseOfTheLabyrinth()
  local level = game:GetLevel()
  local curses = level:GetCurses()
  local curse = LevelCurse.CURSE_OF_LABYRINTH
  
  return curses & curse == curse
end

function mod:getCurrentDimension()
  local level = game:GetLevel()
  return mod:getDimension(level:GetCurrentRoomDesc())
end

function mod:getDimension(roomDesc)
  local level = game:GetLevel()
  local ptrHash = GetPtrHash(roomDesc)
  
  -- 0: main dimension
  -- 1: secondary dimension, used by downpour mirror dimension and mines escape sequence
  -- 2: death certificate dimension
  for i = 0, 2 do
    if ptrHash == GetPtrHash(level:GetRoomByIdx(roomDesc.SafeGridIndex, i)) then
      return i
    end
  end
  
  return -1
end

function mod:forgetStageSeeds(s1, s2)
  local seeds = game:GetSeeds()
  
  for i = s1, s2 do
    seeds:ForgetStageSeed(i)
  end
end

function mod:updateEid()
  if EID and not game:IsGreedMode() then
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    
    if room:GetType() == RoomType.ROOM_SACRIFICE then
      for subType = 1, 12 do
        -- english only for now
        local description = ''
        
        -- in the dark room, you'll just be teleported back to the starting room so there's no override
        if mod.state.spoilTeleport and not (level:GetStage() == LevelStage.STAGE6 and not level:IsAltStage()) then
          local stageName = mod:getRandomStage(room:GetSpawnSeed())
          if stageName == 'chest' then
            description = description .. '#{{12}} Teleportation override: Chest / ??? ({{BlueBabySmall}})' -- GoldenChest
          elseif stageName == 'theVoid' then
            description = description .. '#{{12}} Teleportation override: The Void / Delirium ({{DeliriumSmall}})'
          elseif stageName == 'corpseII' then
            description = description .. '#{{12}} Teleportation override: Corpse II / Mother ({{MotherSmall}})'
          elseif stageName == 'home' then
            description = description .. '#{{12}} Teleportation override: Home / The Beast ({{BeastSmall}})' -- IsaacsRoom
          elseif stageName == 'sheol' then
            description = description .. '#{{12}} Teleportation override: Sheol / Satan ({{SatanSmall}})'
          elseif stageName == 'cathedral' then
            description = description .. '#{{12}} Teleportation override: Cathedral / Isaac ({{IsaacSmall}})'
          elseif stageName == 'depthsII' then
            description = description .. '#{{12}} Teleportation override: Depths II / Mom ({{MomBossSmall}})'
          elseif stageName == 'mausoleumII' then
            description = description .. '#{{12}} Teleportation override: Mausoleum II / Mom ({{MomBossSmall}})'
          elseif stageName == 'wombII' then
            description = description .. '#{{12}} Teleportation override: Womb II / Mom\'s Heart ({{MomsHeartSmall}})'
          elseif stageName == 'hush' then
            description = description .. '#{{12}} Teleportation override: ??? / Hush ({{HushSmall}})'
          elseif stageName == 'basementI' then
            description = description .. '#{{12}} Teleportation override: Basement I / Restart ({{Collectible636}})' -- r key
          elseif stageName == 'basementI_d4' then
            description = description .. '#{{12}} Teleportation override: Basement I / Restart ({{Collectible636}}+{{Collectible284}})' -- r key + d4
          elseif stageName == 'basementI_genesis' then
            description = description .. '#{{12}} Teleportation override: Basement I / Restart ({{Collectible636}}+{{Collectible622}})' -- r key + genesis
          elseif stageName == 'basementI_deathCert' then
            description = description .. '#{{12}} Teleportation override: Basement I / Restart ({{Collectible636}}+{{Collectible628}})' -- r key + death certificate
          elseif stageName == 'preAscent' then
            description = description .. '#{{12}} Teleportation override: Mausoleum II / Dad\'s Note ({{Collectible668}})' -- dad's note
          elseif stageName == 'darkRoom' then
            description = description .. '#{{12}} Teleportation override: Dark Room / The Lamb ({{TheLambSmall}})' -- RedChest
          end
        end
        
        if subType == 12 and mod.state.giveDreamCatcher then
          description = description .. '#{{Collectible566}} Gives Dream Catcher' -- dream catcher
        end
        
        mod.eidDescriptions[subType] = description
      end
    end
  end
end

function mod:setupEid()
  EID:addDescriptionModifier(mod.Name, function(descObj)
    local room = game:GetRoom()
    return not game:IsGreedMode() and room:GetType() == RoomType.ROOM_SACRIFICE and descObj.ObjType == -999 and descObj.ObjVariant == GridEntityType.GRID_SPIKES and
           not (descObj.Name == 'Heart Sacrifice Room' or descObj.Name == 'Sheep Sacrifice Room' or descObj.Name == 'Crown Sacrifice Room') -- Sacrifice Room Rework
  end, function(descObj)
    local subType = math.max(1, math.min(descObj.ObjSubType, 12))
    EID:appendToDescription(descObj, mod.eidDescriptions[subType])
    return descObj
  end)
end

function mod:seedRng()
  repeat
    local rand = Random() -- 0 to 2^32
    if rand > 0 then      -- if this is 0, it causes a crash later on
      mod.rng:SetSeed(rand, mod.rngShiftIdx)
    end
  until(rand > 0)
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  local category = 'Sac Room Teleport'
  for _, v in ipairs({ 'Stages', 'Advanced' }) do
    ModConfigMenu.RemoveSubcategory(category, v)
  end
  ModConfigMenu.AddSetting(
    category,
    'Stages',
    {
      Type = ModConfigMenu.OptionType.NUMBER,
      CurrentSetting = function()
        return 2
      end,
      Minimum = 1,
      Maximum = 3,
      Display = function()
        return 'Reset'
      end,
      OnChange = function(n)
        if n == 1 then
          for k, _ in pairs(mod.state.stages) do
            mod.state.stages[k] = 0
          end
        else -- 3
          for k, _ in pairs(mod.state.stages) do
            if k == 'darkRoom' or k == 'chest' then
              mod.state.stages[k] = 10
            elseif k == 'theVoid' then
              mod.state.stages[k] = 2
            else
              mod.state.stages[k] = 0
            end
          end
        end
        mod:updateEid()
        mod:save()
      end,
      Info = { 'Reset values to their defaults: select / right', 'Clear the values below: left' }
    }
  )
  ModConfigMenu.AddSetting(
    category,
    'Stages',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return false
      end,
      Display = function()
        return 'Randomize'
      end,
      OnChange = function(b)
        for k, _ in pairs(mod.state.stages) do
          mod.state.stages[k] = mod.rng:RandomInt(11)
        end
        mod:updateEid()
        mod:save()
      end,
      Info = { 'Randomize the values below' }
    }
  )
  ModConfigMenu.AddSpace(category, 'Stages')
  for _, v in ipairs({
                       { name = 'Basement I / Restart'       , field = 'basementI' },
                       { name = 'Basement I / R + D4'        , field = 'basementI_d4' },
                       { name = 'Basement I / R + Genesis'   , field = 'basementI_genesis' },
                       { name = 'Basement I / R + Death Cert', field = 'basementI_deathCert' },
                       { name = 'Depths II / Mom'            , field = 'depthsII' },
                       { name = 'Mausoleum II / Mom'         , field = 'mausoleumII' },
                       { name = 'Mausoleum II / Dad\'s Note' , field = 'preAscent' },
                       { name = 'Womb II / Mom\'s Heart'     , field = 'wombII' },
                       { name = 'Corpse II / Mother'         , field = 'corpseII' },
                       { name = '??? / Hush'                 , field = 'hush' },
                       { name = 'Sheol / Satan'              , field = 'sheol' },
                       { name = 'Cathedral / Isaac'          , field = 'cathedral' },
                       { name = 'Dark Room / The Lamb'       , field = 'darkRoom' },
                       { name = 'Chest / ???'                , field = 'chest' },
                       { name = 'The Void / Delirium'        , field = 'theVoid' },
                       { name = 'Home / The Beast'           , field = 'home' },
                    })
  do
    ModConfigMenu.AddSetting(
      category,
      'Stages',
      {
        Type = ModConfigMenu.OptionType.SCROLL,
        CurrentSetting = function()
          return mod.state.stages[v.field]
        end,
        Display = function()
          return v.name .. ' : $scroll' .. mod.state.stages[v.field]
        end,
        OnChange = function(n)
          mod.state.stages[v.field] = n
          mod:updateEid()
          mod:save()
        end,
        Info = { 'Choose relative weights', 'for random teleportation' }
      }
    )
  end
  for i, v in ipairs({
                       { question = 'Give dream catcher on 12th spike hit?'  , field = 'giveDreamCatcher'               , info = { 'Dream catcher forces the correct', 'stage transition animation to play' } },
                       { question = 'Spoil teleportation destination?'       , field = 'spoilTeleport'                  , info = { 'Requires external item descriptions' } },
                       { question = 'Open closet in home with key pieces?'   , field = 'openClosetWithKeyPieces'        , info = { 'Provides an alt way to open', 'the red room closet @ home' } },
                       { question = 'Transform key pieces into knife pieces?', field = 'transformKeyPiecesToKnifePieces', info = { 'Happens when you first enter', 'the mom boss fight in Mausoleum II' } },
                    })
  do
    if i ~= 1 then
      ModConfigMenu.AddSpace(category, 'Advanced')
    end
    ModConfigMenu.AddText(category, 'Advanced', v.question)
    ModConfigMenu.AddSetting(
      category,
      'Advanced',
      {
        Type = ModConfigMenu.OptionType.BOOLEAN,
        CurrentSetting = function()
          return mod.state[v.field]
        end,
        Display = function()
          return (mod.state[v.field] and 'yes' or 'no')
        end,
        OnChange = function(b)
          mod.state[v.field] = b
          mod:updateEid()
          mod:save()
        end,
        Info = v.info
      }
    )
  end
end
-- end ModConfigMenu --

mod:seedRng()
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
if REPENTOGON then
  mod:AddCallback(ModCallbacks.MC_PRE_LEVEL_SELECT, mod.onPreLevelSelect)
end
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.onNewRoom)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.onPlayerUpdate)
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, mod.onEntityTakeDmg, EntityType.ENTITY_PLAYER)

if EID then
  mod:setupEid()
end
if ModConfigMenu then
  mod:setupModConfigMenu()
end