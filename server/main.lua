local lastSync = {}
local STATE_KEY = 'djBackbling'

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function detectInventory()
    if Config.Inventory and Config.Inventory ~= 'auto' then
        return Config.Inventory
    end
    if resourceStarted('ox_inventory') then
        return 'ox'
    end
    if resourceStarted('qs-inventory') then
        return 'qs'
    end
    if resourceStarted('qb-inventory') or resourceStarted('ps-inventory') or resourceStarted('lj-inventory') then
        return 'qb'
    end
    if resourceStarted('es_extended') then
        return 'esx'
    end
    return 'native'
end

local function validName(name)
    name = Backbling.Normalize(name)
    if not name or #name > 64 or not name:match('^[%w_]+$') then
        return nil
    end
    return name
end

local function validModel(model)
    if type(model) == 'number' and model ~= 0 then
        return model
    end
    if type(model) == 'string' and #model <= 64 and model:match('^[%w_%-]+$') then
        return model
    end
end

local function toWeaponList(raw)
    local list, seen = {}, {}
    if type(raw) ~= 'table' then
        return list
    end

    for _, item in pairs(raw) do
        local name
        local model
        local tint
        if type(item) == 'string' then
            name = validName(item)
        elseif type(item) == 'table' then
            name = validName(item.name or item.n)
            model = validModel(item.model or item.m)
            tint = tonumber(item.tint or item.t)
        end

        if name and not seen[name] and Backbling.IsTracked(name) then
            seen[name] = true
            list[#list + 1] = {
                name = name,
                model = Backbling.GetModel(name, model),
                tint = tint,
                preset = Backbling.GetPreset(name),
                priority = Backbling.GetPriority(name),
            }
        end
    end

    return list
end

local function fromOx(src)
    local ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(src)
    end)
    if not ok or type(items) ~= 'table' then
        return nil
    end

    local raw = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name and (item.count or 1) > 0 then
            raw[#raw + 1] = {
                name = item.name,
                model = item.metadata and item.metadata[Config.ModelMetadataKey or 'model'],
                tint = item.metadata and item.metadata.tint,
            }
        end
    end
    return toWeaponList(raw)
end

local function fromQb(src)
    local items
    if resourceStarted('qb-core') then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok and core then
            local player = core.Functions.GetPlayer(src)
            items = player and player.PlayerData and player.PlayerData.items
        end
    elseif resourceStarted('qbx_core') then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)
        if ok and player then
            items = player.PlayerData and player.PlayerData.items
        end
    end

    if type(items) == 'string' then
        items = json.decode(items)
    end
    if type(items) ~= 'table' then
        return nil
    end

    local raw = {}
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name then
            local amount = item.amount or item.count or item.quantity or 1
            if amount > 0 then
                local info = item.info or item.metadata or {}
                raw[#raw + 1] = {
                    name = item.name,
                    model = info[Config.ModelMetadataKey or 'model'],
                    tint = info.tint,
                }
            end
        end
    end
    return toWeaponList(raw)
end

local function fromEsx(src)
    if not resourceStarted('es_extended') then
        return nil
    end
    local ok, ESX = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)
    if not ok or not ESX then
        return nil
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then
        return nil
    end

    local raw = {}
    local loadout = xPlayer.getLoadout and xPlayer.getLoadout() or {}
    for i = 1, #loadout do
        if loadout[i] and loadout[i].name then
            raw[#raw + 1] = { name = loadout[i].name }
        end
    end
    local inventory = xPlayer.getInventory and xPlayer.getInventory() or {}
    for _, item in pairs(inventory) do
        if type(item) == 'table' and item.name and (item.count or item.amount or 0) > 0 then
            raw[#raw + 1] = { name = item.name }
        end
    end
    return toWeaponList(raw)
end

local function collectServer(src)
    local kind = detectInventory()
    if kind == 'ox' then
        return fromOx(src)
    end
    if kind == 'qb' or kind == 'qs' then
        return fromQb(src)
    end
    if kind == 'esx' then
        return fromEsx(src)
    end
    return nil
end

local function apply(src, weapons, equipped)
    equipped = validName(equipped)
    local assigned = Backbling.AssignSlots(weapons)
    Player(src).state:set(STATE_KEY, Backbling.PackState(assigned, equipped), true)
    Backbling.Debug('sync', src, json.encode(assigned), equipped)
end

RegisterNetEvent('dj-backbling:server:sync', function(weapons, equipped)
    local src = source
    if not src or src == 0 then
        return
    end

    local now = GetGameTimer()
    if lastSync[src] and (now - lastSync[src]) < 80 then
        return
    end
    lastSync[src] = now

    local serverList = collectServer(src)
    local clientList = toWeaponList(weapons)

    -- Prefer a successful server inventory scan, including an empty result.
    -- Fall back to the client list only when the inventory API is not ready yet.
    local list = serverList or clientList

    apply(src, list, equipped)
end)

RegisterNetEvent('dj-backbling:server:tryEdit', function(args)
    local src = source
    local allowed = Config.Editor and Config.Editor.enabled and (
        Config.Editor.allowEveryone or IsPlayerAceAllowed(src, Config.Editor.ace or 'backbling.editor')
    )

    if not allowed then
        TriggerClientEvent('dj-backbling:client:editDenied', src)
        return
    end

    local name
    if type(args) == 'table' and args[1] then
        name = table.concat(args, '_')
    elseif type(args) == 'string' then
        name = args
    end
    TriggerClientEvent('dj-backbling:client:startEdit', src, name)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastSync[src] = nil
    Player(src).state:set(STATE_KEY, nil, true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    for _, id in ipairs(GetPlayers()) do
        Player(tonumber(id)).state:set(STATE_KEY, nil, true)
    end
end)

-- ox_inventory hooks keep the backbling in lockstep with item moves.
CreateThread(function()
    Wait(500)
    if not resourceStarted('ox_inventory') then
        return
    end
    pcall(function()
        exports.ox_inventory:registerHook('swapItems', function(payload)
            local src = payload and payload.source
            if src then
                SetTimeout(75, function()
                    local list = fromOx(src)
                    if list then
                        local equipped = Player(src).state[STATE_KEY]
                        apply(src, list, equipped and equipped.e)
                    end
                end)
            end
        end)
    end)
end)

exports('refresh', function(src)
    src = src or source
    if not src then
        return
    end
    local list = collectServer(src) or {}
    apply(src, list, Player(src).state[STATE_KEY] and Player(src).state[STATE_KEY].e)
end)
