local editor = {
    active = false,
    name = nil,
    boneIndex = 1,
    pos = vec3(0.0, 0.0, 0.0),
    rot = vec3(0.0, 0.0, 0.0),
}

local function hasOxLib()
    return GetResourceState('ox_lib') == 'started'
end

local function currentBone()
    local bones = Config.EditorBones or { { id = 24818, label = 'Spine3' } }
    return bones[editor.boneIndex] or bones[1]
end

local function snapshotFromWeapon(name)
    local ped = PlayerPedId()
    local entry = Backbling.GetEntry(name)
    local preset = Backbling.GetPreset(name)
    local slotId = (entry and entry.slot) or ((Config.Presets[preset] and Config.Presets[preset].slots or {})[1]) or 'primary'
    local bone, pos, rot = Backbling.GetPose(name, slotId, preset, ped)
    editor.pos = vec3(pos.x, pos.y, pos.z)
    editor.rot = vec3(rot.x, rot.y, rot.z)
    editor.boneIndex = 1
    local bones = Config.EditorBones or {}
    for i = 1, #bones do
        if bones[i].id == bone then
            editor.boneIndex = i
            break
        end
    end
end

local function applyOverride()
    if not editor.name then
        return
    end
    local bone = currentBone()
    Backbling.EditorOverrides[editor.name] = {
        bone = bone.id,
        pos = editor.pos,
        rot = editor.rot,
    }
    Backbling.ForceLocal[editor.name] = true
    Backbling.RefreshVisual(GetPlayerServerId(PlayerId()))
end

local function snippet()
    local bone = currentBone()
    return ([[    ['%s'] = {
        model = '%s',
        preset = '%s',
        bone = %s,
        pos = vec3(%.3f, %.3f, %.3f),
        rot = vec3(%.2f, %.2f, %.2f),
    },]]):format(
        editor.name,
        Backbling.GetModel(editor.name) or 'CHANGE_ME',
        Backbling.GetPreset(editor.name),
        bone.id,
        editor.pos.x, editor.pos.y, editor.pos.z,
        editor.rot.x, editor.rot.y, editor.rot.z
    )
end

local function copySnippet()
    local text = snippet()
    print('^2[dj-backbling] paste this into Config.Weapons:^7\n' .. text)
    if hasOxLib() then
        pcall(function()
            exports.ox_lib:setClipboard(text)
        end)
        Backbling.Notify('Offsets copied to clipboard and printed in F8.')
    else
        Backbling.Notify('Offsets printed in F8. Paste them into config.lua.')
    end
end

local function hideHelp()
    if hasOxLib() then
        pcall(function()
            exports.ox_lib:hideTextUI()
        end)
    end
end

local function showHelp()
    local bone = currentBone()
    local lines = {
        ('Backbling editor — %s'):format(editor.name),
        ('Bone: %s (%s)'):format(bone.label, bone.id),
        ('Pos  X %.3f  Y %.3f  Z %.3f'):format(editor.pos.x, editor.pos.y, editor.pos.z),
        ('Rot  P %.2f  R %.2f  Y %.2f'):format(editor.rot.x, editor.rot.y, editor.rot.z),
        'Arrows = left/right & off-back | PageUp/Down = up/down',
        'Q/E = yaw | Numpad 8/5 = pitch | Numpad 7/9 = roll',
        'Shift = fine | Ctrl = coarse | [ ] = bone',
        'ENTER = copy offsets | DELETE = reset | F7 = close',
    }

    if hasOxLib() then
        pcall(function()
            exports.ox_lib:showTextUI(table.concat(lines, '\n'), { position = 'right-center' })
        end)
        return
    end

    local y = 0.68
    for i = 1, #lines do
        SetTextFont(4)
        SetTextScale(0.34, 0.34)
        SetTextColour(255, 255, 255, 230)
        SetTextCentre(true)
        SetTextOutline()
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName(lines[i])
        EndTextCommandDisplayText(0.5, y)
        y = y + 0.028
    end
end

local function stopEditor()
    editor.active = false
    hideHelp()
    if editor.name then
        Backbling.EditorOverrides[editor.name] = nil
        Backbling.ForceLocal[editor.name] = nil
        Backbling.RefreshVisual(GetPlayerServerId(PlayerId()))
    end
    editor.name = nil
    Backbling.Notify('Placement editor closed. Restart the resource after pasting offsets.')
end

local function startEditor(name)
    name = Backbling.Normalize(name)
    if not name then
        local carried = Backbling.Inventory.Collect()
        if carried[1] then
            name = carried[1].name
        else
            name = 'weapon_bat'
        end
    end

    if editor.active and editor.name and editor.name ~= name then
        Backbling.EditorOverrides[editor.name] = nil
        Backbling.ForceLocal[editor.name] = nil
    end

    Backbling.EditorOverrides[name] = nil
    editor.active = true
    editor.name = name
    snapshotFromWeapon(name)
    applyOverride()
    Backbling.Notify(('Editing %s. ENTER copies offsets, F7 closes.'):format(name))
end

local function stepAmounts()
    local move = Config.Editor.moveStep or 0.005
    local rot = Config.Editor.rotStep or 1.0
    if IsDisabledControlPressed(0, 21) then
        move = move * 0.2
        rot = rot * 0.2
    elseif IsDisabledControlPressed(0, 36) then
        move = move * 5.0
        rot = rot * 5.0
    end
    return move, rot
end

local function addPos(dx, dy, dz)
    local move = stepAmounts()
    editor.pos = vec3(
        editor.pos.x + dx * move,
        editor.pos.y + dy * move,
        editor.pos.z + dz * move
    )
    applyOverride()
end

local function addRot(dx, dy, dz)
    local _, rot = stepAmounts()
    editor.rot = vec3(
        editor.rot.x + dx * rot,
        editor.rot.y + dy * rot,
        editor.rot.z + dz * rot
    )
    applyOverride()
end

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/backbling', 'Place a melee weapon on your back', {
        { name = 'weapon', help = 'Optional item/weapon name, e.g. weapon_bat' },
    })
    TriggerEvent('chat:addSuggestion', '/backblingrefresh', 'Force-sync backbling from inventory')
end)

CreateThread(function()
    while true do
        if not editor.active then
            Wait(400)
        else
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 10, true)
            DisableControlAction(0, 11, true)
            DisableControlAction(0, 207, true)
            DisableControlAction(0, 208, true)
            DisablePlayerFiring(PlayerPedId(), true)

            if IsDisabledControlPressed(0, 174) then addPos(-1, 0, 0) end
            if IsDisabledControlPressed(0, 175) then addPos(1, 0, 0) end
            if IsDisabledControlPressed(0, 172) then addPos(0, 1, 0) end
            if IsDisabledControlPressed(0, 173) then addPos(0, -1, 0) end
            if IsDisabledControlPressed(0, 10) or IsDisabledControlPressed(0, 208) then addPos(0, 0, 1) end
            if IsDisabledControlPressed(0, 11) or IsDisabledControlPressed(0, 207) then addPos(0, 0, -1) end

            if IsDisabledControlPressed(0, 44) then addRot(0, 0, -1) end
            if IsDisabledControlPressed(0, 38) then addRot(0, 0, 1) end
            if IsDisabledControlPressed(0, 111) then addRot(1, 0, 0) end
            if IsDisabledControlPressed(0, 110) then addRot(-1, 0, 0) end
            if IsDisabledControlPressed(0, 117) then addRot(0, 1, 0) end
            if IsDisabledControlPressed(0, 118) then addRot(0, -1, 0) end
            if IsDisabledControlPressed(0, 108) then addRot(0, 0, -1) end
            if IsDisabledControlPressed(0, 109) then addRot(0, 0, 1) end

            if IsDisabledControlJustPressed(0, 39) then
                editor.boneIndex = editor.boneIndex - 1
                if editor.boneIndex < 1 then
                    editor.boneIndex = #Config.EditorBones
                end
                applyOverride()
            end
            if IsDisabledControlJustPressed(0, 40) then
                editor.boneIndex = editor.boneIndex + 1
                if editor.boneIndex > #Config.EditorBones then
                    editor.boneIndex = 1
                end
                applyOverride()
            end

            if IsDisabledControlJustPressed(0, 191) then
                copySnippet()
            end
            if IsDisabledControlJustPressed(0, 214) then
                snapshotFromWeapon(editor.name)
                applyOverride()
                Backbling.Notify('Offsets reset.')
            end
            if IsDisabledControlJustPressed(0, 168) then
                stopEditor()
            end

            showHelp()
            Wait(0)
        end
    end
end)

RegisterCommand('backbling', function(_, args)
    local sub = args[1] and args[1]:lower() or nil
    if sub == 'copy' and editor.active then
        copySnippet()
        return
    end
    if sub == 'stop' or sub == 'off' or sub == 'close' then
        if editor.active then
            stopEditor()
        end
        return
    end
    if editor.active and not sub then
        stopEditor()
        return
    end
    TriggerServerEvent('dj-backbling:server:tryEdit', args)
end, false)

RegisterNetEvent('dj-backbling:client:startEdit', function(name)
    startEditor(name)
end)

RegisterNetEvent('dj-backbling:client:editDenied', function()
    if editor.active then
        stopEditor()
    end
    Backbling.Notify('You do not have permission to use the placement editor.')
end)

exports('openEditor', startEditor)
exports('closeEditor', function()
    if editor.active then
        stopEditor()
    end
end)
