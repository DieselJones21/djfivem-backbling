Backbling.Inventory = {}

local inventoryType
local QBCore
local ESX

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

function Backbling.DetectInventory()
    if Config.Inventory and Config.Inventory ~= 'auto' then
        inventoryType = Config.Inventory
        return inventoryType
    end

    if resourceStarted('ox_inventory') then
        inventoryType = 'ox'
    elseif resourceStarted('qs-inventory') then
        inventoryType = 'qs'
    elseif resourceStarted('qb-inventory') or resourceStarted('ps-inventory') or resourceStarted('lj-inventory') or resourceStarted('origen_inventory') then
        inventoryType = 'qb'
    elseif resourceStarted('es_extended') then
        inventoryType = 'esx'
    else
        inventoryType = 'native'
    end

    return inventoryType
end

local function pushUnique(list, seen, name, model, tint)
    name = Backbling.Normalize(name)
    if not name or seen[name] or not Backbling.IsTracked(name) then
        return
    end

    local entryModel = Backbling.GetModel(name, model)
    seen[name] = true
    list[#list + 1] = {
        name = name,
        model = entryModel,
        tint = tonumber(tint),
        preset = Backbling.GetPreset(name),
        priority = Backbling.GetPriority(name),
    }
end

local function metadataModel(meta)
    if type(meta) ~= 'table' then
        return nil
    end
    local key = Config.ModelMetadataKey or 'model'
    local value = meta[key]
    if type(value) == 'string' and value ~= '' then
        return value
    end
    return nil
end

local function collectOx()
    local list, seen = {}, {}
    local ok, items = pcall(function()
        return exports.ox_inventory:GetPlayerItems()
    end)

    if ok and type(items) == 'table' then
        for _, item in pairs(items) do
            if type(item) == 'table' and item.name and (item.count or item.amount or 1) > 0 then
                pushUnique(list, seen, item.name, metadataModel(item.metadata), item.metadata and item.metadata.tint)
            end
        end
        return list
    end

    local names = Backbling.TrackedNames()
    if #names == 0 then
        return list
    end

    local searched
    ok, searched = pcall(function()
        return exports.ox_inventory:Search('count', names)
    end)
    if ok and type(searched) == 'table' then
        for name, count in pairs(searched) do
            if tonumber(count) and count > 0 then
                pushUnique(list, seen, name)
            end
        end
    end

    return list
end

local function collectQbItems(items)
    local list, seen = {}, {}
    if type(items) ~= 'table' then
        return list
    end
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name then
            local amount = item.count or item.amount or item.quantity or 1
            if amount > 0 then
                local info = item.info or item.metadata
                pushUnique(list, seen, item.name, metadataModel(info), info and (info.tint or info.quality))
            end
        end
    end
    return list
end

local function collectQb()
    if not QBCore then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok then
            QBCore = core
        end
    end

    local data = QBCore and QBCore.Functions.GetPlayerData() or {}
    return collectQbItems(data.items)
end

local function collectQs()
    local ok, items = pcall(function()
        if exports['qs-inventory'] and exports['qs-inventory'].getUserInventory then
            return exports['qs-inventory']:getUserInventory()
        end
        return nil
    end)
    if ok and type(items) == 'table' then
        return collectQbItems(items)
    end
    return collectQb()
end

local function collectEsx()
    local list, seen = {}, {}
    if not ESX then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok then
            ESX = obj
        end
    end

    local data = ESX and ESX.GetPlayerData and ESX.GetPlayerData() or {}
    if type(data.loadout) == 'table' then
        for i = 1, #data.loadout do
            local weapon = data.loadout[i]
            if type(weapon) == 'table' then
                pushUnique(list, seen, weapon.name)
            end
        end
    end
    if type(data.inventory) == 'table' then
        for _, item in pairs(data.inventory) do
            if type(item) == 'table' and (item.count or item.amount or 0) > 0 then
                pushUnique(list, seen, item.name)
            end
        end
    end
    return list
end

local function collectNative()
    local list, seen = {}, {}
    local ped = PlayerPedId()
    local names = Backbling.TrackedNames()

    local function consider(name)
        name = Backbling.Normalize(name)
        if not name then
            return
        end
        local hash = joaat(name)
        if HasPedGotWeapon(ped, hash, false) then
            local weaponModel = GetWeapontypeModel(hash)
            pushUnique(list, seen, name, (weaponModel and weaponModel ~= 0) and weaponModel or nil)
        end
    end

    for i = 1, #names do
        consider(names[i])
    end

    if Config.AutoMelee then
        -- Known vanilla melee plus anything already in config.
        local extras = {
            'weapon_bat', 'weapon_golfclub', 'weapon_poolcue', 'weapon_battleaxe',
            'weapon_crowbar', 'weapon_hammer', 'weapon_hatchet', 'weapon_stone_hatchet',
            'weapon_wrench', 'weapon_nightstick', 'weapon_machete', 'weapon_knife',
            'weapon_dagger', 'weapon_switchblade', 'weapon_bottle', 'weapon_flashlight',
            'weapon_candycane',
        }
        for i = 1, #extras do
            consider(extras[i])
        end
    end

    return list
end

function Backbling.Inventory.Collect()
    inventoryType = inventoryType or Backbling.DetectInventory()

    if inventoryType == 'ox' then
        return collectOx()
    elseif inventoryType == 'qb' then
        return collectQb()
    elseif inventoryType == 'qs' then
        return collectQs()
    elseif inventoryType == 'esx' then
        return collectEsx()
    end

    return collectNative()
end

function Backbling.Inventory.GetEquipped()
    inventoryType = inventoryType or Backbling.DetectInventory()
    local ped = PlayerPedId()

    if inventoryType == 'ox' then
        local ok, weapon = pcall(function()
            return exports.ox_inventory:getCurrentWeapon()
        end)
        if ok and type(weapon) == 'table' and weapon.name then
            return Backbling.Normalize(weapon.name)
        end
    end

    local _, hash = GetCurrentPedWeapon(ped, true)
    if not hash or hash == 0 or hash == `WEAPON_UNARMED` then
        return nil
    end

    -- Prefer a tracked name whose hash matches the current weapon.
    local names = Backbling.TrackedNames()
    for i = 1, #names do
        if joaat(names[i]) == hash then
            return names[i]
        end
    end

    return nil
end

function Backbling.Inventory.Type()
    return inventoryType or Backbling.DetectInventory()
end

function Backbling.Inventory.Watch(onChange)
    inventoryType = Backbling.DetectInventory()
    Backbling.Debug('inventory adapter:', inventoryType)

    local function fire()
        onChange()
    end

    if inventoryType == 'ox' then
        AddEventHandler('ox_inventory:updateInventory', fire)
        AddEventHandler('ox_inventory:currentWeapon', fire)
        RegisterNetEvent('ox_inventory:setPlayerInventory', fire)
    elseif inventoryType == 'qb' or inventoryType == 'qs' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', fire)
        RegisterNetEvent('QBCore:Player:SetPlayerData', fire)
        RegisterNetEvent('weapons:client:SetCurrentWeapon', fire)
        RegisterNetEvent('qb-weapons:client:SetCurrentWeapon', fire)
        RegisterNetEvent('inventory:client:UpdatePlayerInventory', fire)
        RegisterNetEvent('ps-inventory:client:updateInventory', fire)
        RegisterNetEvent('qs-inventory:client:updateInventory', fire)
    elseif inventoryType == 'esx' then
        RegisterNetEvent('esx:playerLoaded', fire)
        RegisterNetEvent('esx:addInventoryItem', fire)
        RegisterNetEvent('esx:removeInventoryItem', fire)
        RegisterNetEvent('esx:addWeapon', fire)
        RegisterNetEvent('esx:removeWeapon', fire)
        RegisterNetEvent('esx:setLoadout', fire)
    end

    -- Native draw/holster still matters for every adapter.
    CreateThread(function()
        local lastHash
        while true do
            local _, hash = GetCurrentPedWeapon(PlayerPedId(), true)
            if hash ~= lastHash then
                lastHash = hash
                fire()
            end
            Wait(inventoryType == 'native' and 400 or 700)
        end
    end)

    AddEventHandler('playerSpawned', fire)
    RegisterNetEvent('hospital:client:Revive', fire)
    RegisterNetEvent('esx_ambulancejob:revive', fire)
end
