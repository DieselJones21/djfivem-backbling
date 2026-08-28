local STATE_KEY = 'djBackbling'
local cache = {}
local localHidden = false
local lastSyncJson
local syncPending = false

Backbling.EditorOverrides = Backbling.EditorOverrides or {}
Backbling.ForceLocal = Backbling.ForceLocal or {}

local function notify(message)
    if GetResourceState('ox_lib') == 'started' then
        pcall(function()
            exports.ox_lib:notify({ title = 'Backbling', description = message, type = 'inform' })
        end)
        return
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

Backbling.Notify = notify

local function toHash(model)
    if type(model) == 'number' then
        return model
    end
    if type(model) == 'string' and model ~= '' then
        return joaat(model)
    end
end

local function loadModel(model)
    local hash = toHash(model)
    if not hash or hash == 0 then
        return
    end
    if HasModelLoaded(hash) then
        return hash
    end

    local looksValid = IsModelValid(hash) or IsModelInCdimage(hash)
    RequestModel(hash)
    -- Addon stream ydrs often fail IsModelInCdimage until requested; give them time.
    local timeout = GetGameTimer() + (looksValid and 5000 or 2500)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then
            Backbling.Debug('model timed out', model)
            return
        end
        Wait(10)
    end
    return hash
end

local function resolveModel(name, packedModel)
    name = Backbling.Normalize(name) or name
    local short = type(name) == 'string' and name:gsub('^weapon_', '') or name
    local weaponModel = GetWeapontypeModel(joaat(name))
    local candidates = {
        packedModel,
        Backbling.GetModel(name),
        short,
        weaponModel,
        short and ('w_me_' .. short) or nil,
        name,
    }

    local tried = {}
    for i = 1, #candidates do
        local model = candidates[i]
        local hash = toHash(model)
        if hash and hash ~= 0 and not tried[hash] then
            tried[hash] = true
            local loaded = loadModel(model)
            if loaded then
                return loaded
            end
        end
    end
end

local function isFemale(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function addVec(a, b)
    if not b then
        return a
    end
    return vec3(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Backbling.GetPose(name, slotId, presetName, ped)
    local override = Backbling.EditorOverrides[name]
    if override and override.pos and override.rot then
        return override.bone or 24818, override.pos, override.rot
    end

    local entry = Backbling.GetEntry(name)
    local slot = Config.Slots[slotId] or Config.Slots.primary
    local preset = Config.Presets[presetName or Backbling.GetPreset(name)] or Config.Presets.medium

    -- Full overrides from config / the editor are exact poses. Do not add gender offsets again.
    if entry and entry.pos and entry.rot then
        local bone = entry.bone or slot.bone
        local pos = entry.pos
        local rot = entry.rot
        if isFemale(ped) and entry.female then
            if entry.female.pos then
                pos = addVec(pos, entry.female.pos)
            end
            if entry.female.rot then
                rot = addVec(rot, entry.female.rot)
            end
        end
        return bone, pos, rot
    end

    local bone = (entry and entry.bone) or slot.bone
    local pos = addVec(slot.pos, preset.extraPos)
    local rot = addVec(slot.rot, preset.extraRot)

    if entry and entry.extraPos then
        pos = addVec(pos, entry.extraPos)
    end
    if entry and entry.extraRot then
        rot = addVec(rot, entry.extraRot)
    end
    if isFemale(ped) then
        pos = addVec(pos, Config.FemaleOffset)
        if entry and entry.female and entry.female.pos then
            pos = addVec(pos, entry.female.pos)
        end
        if entry and entry.female and entry.female.rot then
            rot = addVec(rot, entry.female.rot)
        end
    end

    return bone, pos, rot
end

local function deleteObject(entity)
    if entity and DoesEntityExist(entity) then
        DetachEntity(entity, true, false)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteObject(entity)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end

local function destroyPlayer(serverId)
    local entry = cache[serverId]
    if not entry then
        return
    end
    for _, obj in pairs(entry.objects) do
        deleteObject(obj.entity)
    end
    cache[serverId] = nil
end

local function poseEquals(a, b)
    if not a or not b then
        return false
    end
    return a.bone == b.bone
        and math.abs(a.pos.x - b.pos.x) < 0.0001
        and math.abs(a.pos.y - b.pos.y) < 0.0001
        and math.abs(a.pos.z - b.pos.z) < 0.0001
        and math.abs(a.rot.x - b.rot.x) < 0.0001
        and math.abs(a.rot.y - b.rot.y) < 0.0001
        and math.abs(a.rot.z - b.rot.z) < 0.0001
end

local function attachWeapon(ped, weapon)
    local hash = resolveModel(weapon.name, weapon.model)
    if not hash then
        Backbling.Debug('could not load model for', weapon.name, weapon.model)
        return
    end

    local bone, pos, rot = Backbling.GetPose(weapon.name, weapon.slot, weapon.preset, ped)
    local coords = GetEntityCoords(ped)
    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    if not entity or entity == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, false, false)
    pcall(SetEntityCompletelyDisableCollision, entity, true, false)
    pcall(SetCanClimbOnEntity, entity, false)
    FreezeEntityPosition(entity, true)
    SetEntityLodDist(entity, math.floor((Config.RenderDistance or 42.0) + 25.0))
    pcall(SetEntityRecordsCollisions, entity, false)
    SetEntityInvincible(entity, true)

    if weapon.tint and SetObjectTextureVariation then
        pcall(SetObjectTextureVariation, entity, weapon.tint)
    end

    local boneIndex = GetPedBoneIndex(ped, bone)
    AttachEntityToEntity(entity, ped, boneIndex, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(hash)

    return {
        entity = entity,
        name = weapon.name,
        model = hash,
        bone = bone,
        pos = pos,
        rot = rot,
        slot = weapon.slot,
    }
end

local function shouldHidePed(ped, isLocal)
    if localHidden and isLocal then
        return true
    end
    if not DoesEntityExist(ped) then
        return true
    end
    if not IsEntityVisible(ped) then
        return true
    end
    if Config.HideWhenDead and (IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped)) then
        return true
    end
    if Config.HideInVehicle and IsPedInAnyVehicle(ped, false) then
        return true
    end
    if isLocal and Config.HideInFirstPerson and GetFollowPedCamViewMode() == 4 then
        if not next(Backbling.ForceLocal) then
            return true
        end
    end
    if IsCutscenePlaying() then
        return true
    end
    return false
end

local function desiredWeapons(packed, ped, isLocal)
    local list = {}
    if type(packed) == 'table' and type(packed.w) == 'table' then
        for i = 1, #packed.w do
            local w = packed.w[i]
            local name = Backbling.Normalize(w.n or w.name)
            if name and name ~= packed.e then
                list[#list + 1] = {
                    name = name,
                    model = w.m or w.model,
                    slot = w.s or w.slot,
                    tint = w.t or w.tint,
                    preset = w.p or w.preset,
                }
            end
        end
    end

    if isLocal then
        for name in pairs(Backbling.ForceLocal) do
            local exists = false
            for i = 1, #list do
                if list[i].name == name then
                    exists = true
                    break
                end
            end
            if not exists then
                list[#list + 1] = {
                    name = name,
                    model = Backbling.GetModel(name),
                    slot = (Backbling.GetEntry(name) and Backbling.GetEntry(name).slot) or 'primary',
                    preset = Backbling.GetPreset(name),
                }
            end
        end
    end

    return list
end

local function applyPlayer(serverId, ped, packed, isLocal)
    cache[serverId] = cache[serverId] or { objects = {}, desired = packed }

    local entry = cache[serverId]
    entry.desired = packed
    entry.ped = ped

    if shouldHidePed(ped, isLocal) then
        for slot, obj in pairs(entry.objects) do
            deleteObject(obj.entity)
            entry.objects[slot] = nil
        end
        return
    end

    local wanted = desiredWeapons(packed, ped, isLocal)
    local keep = {}

    for i = 1, #wanted do
        local weapon = wanted[i]
        local slot = weapon.slot or ('auto' .. i)
        keep[slot] = true
        local bone, pos, rot = Backbling.GetPose(weapon.name, weapon.slot, weapon.preset, ped)
        local current = entry.objects[slot]
        local pose = { bone = bone, pos = pos, rot = rot }
        local exists = current and current.name == weapon.name and DoesEntityExist(current.entity)

        if exists and poseEquals(current, pose) and IsEntityAttachedToEntity(current.entity, ped) then
            local alpha = GetEntityAlpha(ped)
            if GetEntityAlpha(current.entity) ~= alpha then
                SetEntityAlpha(current.entity, alpha, false)
            end
        elseif exists then
            local boneIndex = GetPedBoneIndex(ped, bone)
            AttachEntityToEntity(current.entity, ped, boneIndex, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, false, false, false, false, 2, true)
            current.bone, current.pos, current.rot = bone, pos, rot
        else
            if current then
                deleteObject(current.entity)
            end
            entry.objects[slot] = attachWeapon(ped, weapon)
        end
    end

    for slot, obj in pairs(entry.objects) do
        if not keep[slot] then
            deleteObject(obj.entity)
            entry.objects[slot] = nil
        end
    end
end

local function playerFromServerId(serverId)
    if serverId == GetPlayerServerId(PlayerId()) then
        return PlayerId(), true
    end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then
        return nil, false
    end
    return player, false
end

function Backbling.RefreshVisual(serverId)
    local player, isLocal = playerFromServerId(serverId)
    if not player then
        destroyPlayer(serverId)
        return
    end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then
        destroyPlayer(serverId)
        return
    end

    local packed
    if cache[serverId] then
        packed = cache[serverId].desired
    end
    if isLocal then
        packed = LocalPlayer.state[STATE_KEY] or packed
    else
        packed = Player(serverId).state[STATE_KEY] or packed
    end

    local myCoords = GetEntityCoords(PlayerPedId())
    if #(myCoords - GetEntityCoords(ped)) > (Config.RenderDistance or 42.0) then
        local entry = cache[serverId]
        if entry then
            for slot, obj in pairs(entry.objects) do
                deleteObject(obj.entity)
                entry.objects[slot] = nil
            end
            entry.desired = packed
        else
            cache[serverId] = { objects = {}, desired = packed }
        end
        return
    end

    applyPlayer(serverId, ped, packed, isLocal)
end

local function requestSync()
    if syncPending then
        return
    end
    syncPending = true
    SetTimeout(Config.UpdateDebounce or 150, function()
        syncPending = false
        local weapons = Backbling.Inventory.Collect()
        local equipped = Backbling.Inventory.GetEquipped()
        local names = {}
        for i = 1, #weapons do
            names[i] = weapons[i].name
        end
        local encoded = table.concat(names, ',') .. '|' .. tostring(equipped or '')
        if encoded == lastSyncJson then
            return
        end
        lastSyncJson = encoded
        TriggerServerEvent('dj-backbling:server:sync', weapons, equipped)
    end)
end

Backbling.RequestSync = requestSync

AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _key, value)
    local player = GetPlayerFromStateBagName(bagName)
    if not player or player == 0 then
        return
    end
    local serverId = GetPlayerServerId(player)
    if value == nil then
        destroyPlayer(serverId)
        return
    end
    cache[serverId] = cache[serverId] or { objects = {} }
    cache[serverId].desired = value
    Backbling.RefreshVisual(serverId)
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(200)
    end
    Wait(500)
    Backbling.DetectInventory()
    Backbling.Inventory.Watch(requestSync)
    requestSync()

    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        local packed = Player(serverId).state[STATE_KEY]
        if packed then
            cache[serverId] = cache[serverId] or { objects = {} }
            cache[serverId].desired = packed
            Backbling.RefreshVisual(serverId)
        end
    end
end)

CreateThread(function()
    while true do
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local myServerId = GetPlayerServerId(PlayerId())

        Backbling.RefreshVisual(myServerId)

        for serverId, entry in pairs(cache) do
            if serverId ~= myServerId then
                local player = GetPlayerFromServerId(serverId)
                if player == -1 then
                    destroyPlayer(serverId)
                else
                    local ped = GetPlayerPed(player)
                    if DoesEntityExist(ped) and #(myCoords - GetEntityCoords(ped)) <= (Config.RenderDistance or 42.0) + 8.0 then
                        if entry.ped ~= ped then
                            for _, obj in pairs(entry.objects) do
                                deleteObject(obj.entity)
                            end
                            entry.objects = {}
                        end
                        Backbling.RefreshVisual(serverId)
                    else
                        for slot, obj in pairs(entry.objects) do
                            deleteObject(obj.entity)
                            entry.objects[slot] = nil
                        end
                    end
                end
            end
        end

        Wait(650)
    end
end)

CreateThread(function()
    local interval = tonumber(Config.SafetyRefresh) or 5000
    while true do
        Wait(interval)
        lastSyncJson = nil
        requestSync()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    for serverId in pairs(cache) do
        destroyPlayer(serverId)
    end
end)

RegisterNetEvent('dj-backbling:client:notify', function(message)
    notify(message)
end)

exports('setVisible', function(visible)
    localHidden = not visible
    Backbling.RefreshVisual(GetPlayerServerId(PlayerId()))
end)

exports('isVisible', function()
    return not localHidden
end)

exports('refresh', function()
    lastSyncJson = nil
    requestSync()
end)

exports('getWeapons', function()
    local packed = LocalPlayer.state[STATE_KEY]
    return packed and packed.w or {}
end)

RegisterNetEvent('dj-backbling:client:setVisible', function(visible)
    localHidden = not visible
    Backbling.RefreshVisual(GetPlayerServerId(PlayerId()))
end)

RegisterCommand('backblingrefresh', function()
    lastSyncJson = nil
    requestSync()
    notify('Backbling refreshed.')
end, false)
