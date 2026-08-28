Backbling = Backbling or {}

local weaponIndex = {}
local vanillaMelee = {
    weapon_bat = true,
    weapon_golfclub = true,
    weapon_poolcue = true,
    weapon_battleaxe = true,
    weapon_crowbar = true,
    weapon_hammer = true,
    weapon_hatchet = true,
    weapon_stone_hatchet = true,
    weapon_wrench = true,
    weapon_nightstick = true,
    weapon_machete = true,
    weapon_knife = true,
    weapon_dagger = true,
    weapon_switchblade = true,
    weapon_bottle = true,
    weapon_flashlight = true,
    weapon_candycane = true,
    weapon_stunrod = true,
}
local vanillaModels = {
    weapon_bat = 'w_me_bat',
    weapon_golfclub = 'w_me_gclub',
    weapon_poolcue = 'w_me_poolcue',
    weapon_battleaxe = 'w_me_battleaxe',
    weapon_crowbar = 'w_me_crowbar',
    weapon_hammer = 'w_me_hammer',
    weapon_hatchet = 'w_me_hatchet',
    weapon_stone_hatchet = 'w_me_stonehatchet',
    weapon_wrench = 'w_me_wrench',
    weapon_nightstick = 'w_me_nightstick',
    weapon_machete = 'w_me_machette_lr',
    weapon_knife = 'w_me_knife_01',
    weapon_dagger = 'w_me_dagger',
    weapon_switchblade = 'w_me_switchblade',
    weapon_bottle = 'w_me_bottle',
    weapon_flashlight = 'w_me_flashlight',
    weapon_candycane = 'w_me_candy_xm3',
    weapon_knuckle = 'w_me_knuckle',
    weapon_stunrod = 'w_me_stunrod_01',
}

local katanaTokens = { 'katana', 'sword', 'ninjato', 'wakizashi', 'longsword' }
local longTokens = { 'weapon_bat', 'golf', 'poolcue', 'pool_cue', 'sledge', 'staff', 'spear', 'lance', 'battleaxe', 'battle_axe' }
local smallTokens = { 'knife', 'dagger', 'switch', 'bottle', 'flashlight', 'shiv', 'bayonet', 'karambit', 'butterfly' }

local function containsToken(name, tokens)
    for i = 1, #tokens do
        if name:find(tokens[i], 1, true) then
            return true
        end
    end
    return false
end

function Backbling.Normalize(name)
    if type(name) ~= 'string' then
        return nil
    end
    name = name:gsub('^%s+', ''):gsub('%s+$', ''):lower()
    if name == '' then
        return nil
    end
    return name
end

function Backbling.IsBlacklisted(name)
    name = Backbling.Normalize(name)
    return name and Config.Blacklist[name] == true
end

function Backbling.GuessPreset(name)
    name = Backbling.Normalize(name) or ''
    if containsToken(name, katanaTokens) then
        return 'katana'
    end
    if containsToken(name, longTokens) then
        return 'long'
    end
    if containsToken(name, smallTokens) then
        return 'small'
    end
    return 'medium'
end

function Backbling.GetEntry(name)
    name = Backbling.Normalize(name)
    if not name then
        return nil, nil
    end
    return weaponIndex[name], name
end

function Backbling.GetModel(name, override)
    if type(override) == 'number' and override ~= 0 then
        return override
    end
    if type(override) == 'string' and override ~= '' then
        return override
    end
    local entry = Backbling.GetEntry(name)
    if entry and type(entry.model) == 'string' and entry.model ~= '' then
        return entry.model
    end
    name = Backbling.Normalize(name)
    return name and vanillaModels[name] or nil
end

function Backbling.GetPreset(name)
    local entry = Backbling.GetEntry(name)
    if entry and entry.preset and Config.Presets[entry.preset] then
        return entry.preset
    end
    return Backbling.GuessPreset(name)
end

function Backbling.GetPriority(name)
    local entry = Backbling.GetEntry(name)
    if entry and tonumber(entry.priority) then
        return entry.priority
    end
    local preset = Config.Presets[Backbling.GetPreset(name)]
    return preset and preset.priority or 50
end

local function nativeIsMelee(name)
    if not IsWeaponValid or not GetWeapontypeGroup then
        return false
    end
    local hash = joaat(name)
    local okValid, valid = pcall(IsWeaponValid, hash)
    if not okValid or not valid then
        return false
    end
    local okGroup, group = pcall(GetWeapontypeGroup, hash)
    return okGroup and group == `GROUP_MELEE`
end

function Backbling.IsTracked(name)
    name = Backbling.Normalize(name)
    if not name or Backbling.IsBlacklisted(name) then
        return false
    end
    local entry = weaponIndex[name]
    if entry then
        return entry.enabled ~= false
    end
    if not Config.AutoMelee then
        return false
    end
    if vanillaMelee[name] then
        return true
    end
    return nativeIsMelee(name)
end

function Backbling.TrackedNames()
    local list = {}
    for name in pairs(weaponIndex) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function Backbling.AssignSlots(weapons)
    table.sort(weapons, function(a, b)
        if a.priority == b.priority then
            return a.name < b.name
        end
        return a.priority < b.priority
    end)

    local used = {}
    local assigned = {}

    for i = 1, #weapons do
        if #assigned >= (Config.MaxVisible or 3) then
            break
        end

        local weapon = weapons[i]
        local entry = Backbling.GetEntry(weapon.name)
        local presetName = weapon.preset or Backbling.GetPreset(weapon.name)
        local preset = Config.Presets[presetName] or Config.Presets.medium
        local preferred = {}

        if entry and entry.slot then
            preferred[1] = entry.slot
        elseif preset.slots then
            for s = 1, #preset.slots do
                preferred[#preferred + 1] = preset.slots[s]
            end
        end

        for s = 1, #Config.SlotOrder do
            preferred[#preferred + 1] = Config.SlotOrder[s]
        end

        local slot
        for s = 1, #preferred do
            local id = preferred[s]
            if id and Config.Slots[id] and not used[id] then
                slot = id
                break
            end
        end

        if slot then
            used[slot] = true
            assigned[#assigned + 1] = {
                name = weapon.name,
                model = weapon.model,
                slot = slot,
                tint = weapon.tint,
                preset = presetName,
            }
        end
    end

    return assigned
end

function Backbling.PackState(assigned, equipped)
    local packed = { w = {}, e = equipped }
    for i = 1, #assigned do
        local w = assigned[i]
        packed.w[i] = {
            n = w.name,
            s = w.slot,
            m = w.model,
            t = w.tint,
            p = w.preset,
        }
    end
    return packed
end

function Backbling.Debug(...)
    if not Config.Debug then
        return
    end
    local parts = { '[dj-backbling]' }
    local args = { ... }
    for i = 1, #args do
        parts[#parts + 1] = tostring(args[i])
    end
    print(table.concat(parts, ' '))
end

for name, data in pairs(Config.Weapons or {}) do
    local key = Backbling.Normalize(name)
    if key then
        weaponIndex[key] = data or {}
    end
end
