--[[
    dj-backbling
    Melee weapons in your inventory appear on your back and stay synced for every player.

    You only need to edit THIS file for normal setup.
    Use /backbling in-game to live-place a weapon, then paste the printed snippet here.
]]

Config = {}

-- 'auto' detects ox_inventory, then qb/ps/lj/qs-inventory, then ESX, then native GTA weapons.
-- Force one of: 'ox' | 'qb' | 'qs' | 'esx' | 'native'
Config.Inventory = 'auto'

-- Vanilla GTA melee (bat, knife, machete, ...) shows automatically using the presets below.
-- Turn this off if you only want the weapons listed in Config.Weapons.
Config.AutoMelee = true

-- Maximum melee props on a player at once (one per slot).
Config.MaxVisible = 3

-- How far away other players' back weapons still render.
Config.RenderDistance = 42.0

-- Hide back weapons while seated in a vehicle (stops seat clipping).
Config.HideInVehicle = true

-- Hide back weapons while dead / downed.
Config.HideWhenDead = true

-- Hide YOUR back weapons in first-person so they don't clip the camera.
-- Other players still see them on you.
Config.HideInFirstPerson = true

-- Extra push off the spine for female freemode peds.
Config.FemaleOffset = vec3(0.0, 0.032, 0.0)

-- Safety rescan while a player is in the world (ms). Inventory events still update instantly.
Config.SafetyRefresh = 5000

-- Debounce burst inventory updates (ms).
Config.UpdateDebounce = 150

-- If ox_inventory (or similar) stores a custom ydr on the item, read it from this metadata key.
Config.ModelMetadataKey = 'model'

-- Debug prints in F8 / server console.
Config.Debug = false

-- Placement editor. Lock this down on a live server with:
--   add_ace group.admin backbling.editor allow
--   add_ace group.admin command.backbling allow
Config.Editor = {
    enabled = true,
    ace = 'backbling.editor',
    allowEveryone = true, -- set false once placements are finished
    moveStep = 0.005,
    rotStep = 1.0,
}

----------------------------------------------------------------
-- Back slots (Fortnite-style stack)
-- Bone 24818 = SKEL_Spine3 (upper back). These values are the base pose;
-- each weapon preset / per-weapon offset is added on top.
----------------------------------------------------------------
Config.SlotOrder = { 'primary', 'secondary', 'tertiary' }

Config.Slots = {
    -- Largest / first long weapon, right of spine, hanging like a backbling.
    primary = {
        bone = 24818,
        pos = vec3(0.175, -0.155, 0.015),
        rot = vec3(0.0, 90.0, 180.0),
    },
    -- Second weapon, mirrored to the left so two bats don't occupy the same space.
    secondary = {
        bone = 24818,
        pos = vec3(-0.145, -0.155, 0.020),
        rot = vec3(0.0, 90.0, 0.0),
    },
    -- Third weapon, slightly lower and more diagonal (knives / shorter melee).
    tertiary = {
        bone = 24818,
        pos = vec3(0.015, -0.175, -0.115),
        rot = vec3(6.0, 78.0, 180.0),
    },
}

----------------------------------------------------------------
-- Shape presets
-- slots     = preferred slot order
-- priority  = lower number wins the best slot (long weapons first)
-- extraPos / extraRot = added on top of the slot pose
----------------------------------------------------------------
Config.Presets = {
    long = {
        slots = { 'primary', 'secondary', 'tertiary' },
        priority = 10,
        extraPos = vec3(0.0, 0.0, 0.0),
        extraRot = vec3(0.0, 0.0, 0.0),
    },
    katana = {
        slots = { 'primary', 'secondary' },
        priority = 12,
        extraPos = vec3(-0.010, -0.010, 0.070),
        extraRot = vec3(12.0, -18.0, 8.0),
    },
    medium = {
        slots = { 'secondary', 'primary', 'tertiary' },
        priority = 20,
        extraPos = vec3(0.0, 0.0, 0.035),
        extraRot = vec3(0.0, 0.0, 0.0),
    },
    small = {
        slots = { 'tertiary', 'secondary', 'primary' },
        priority = 30,
        extraPos = vec3(0.0, 0.010, -0.020),
        extraRot = vec3(0.0, 4.0, 0.0),
    },
}

-- AutoMelee ignores these even if they are GROUP_MELEE.
Config.Blacklist = {
    weapon_unarmed = true,
    weapon_knuckle = true,
    weapon_snowball = true,
}

----------------------------------------------------------------
-- YOUR WEAPONS
--
-- Paste names here (inventory item name OR weapon spawn code).
-- Matching is case-insensitive: WEAPON_BAT == weapon_bat == Weapon_Bat
--
-- Fields (all optional except that the key is the item/weapon name):
--   model    = ydr / prop name. If omitted, vanilla models and GetWeapontypeModel are used.
--   preset   = 'long' | 'medium' | 'small' | 'katana'
--   priority = number (lower = more important slot)
--   slot     = force 'primary' | 'secondary' | 'tertiary'
--   bone, pos, rot = FULL override of the slot pose (use /backbling to get these)
--   enabled  = false to skip
--   female   = { pos = vec3(), rot = vec3() } extra offset for mp_f_freemode_01
--
-- Example after using the editor:
--   ['weapon_bat'] = {
--       model = 'w_me_bat',
--       preset = 'long',
--       bone = 24818,
--       pos = vec3(0.175, -0.155, 0.015),
--       rot = vec3(0.0, 90.0, 180.0),
--   },
----------------------------------------------------------------
Config.Weapons = {
    -- Vanilla melee (safe to delete if you only want custom names)
    ['weapon_bat'] = { model = 'w_me_bat', preset = 'long' },
    ['weapon_golfclub'] = { model = 'w_me_gclub', preset = 'long' },
    ['weapon_poolcue'] = { model = 'w_me_poolcue', preset = 'long' },
    ['weapon_battleaxe'] = { model = 'w_me_battleaxe', preset = 'long' },
    ['weapon_crowbar'] = { model = 'w_me_crowbar', preset = 'medium' },
    ['weapon_hammer'] = { model = 'w_me_hammer', preset = 'medium' },
    ['weapon_hatchet'] = { model = 'w_me_hatchet', preset = 'medium' },
    ['weapon_stone_hatchet'] = { model = 'w_me_stonehatchet', preset = 'medium' },
    ['weapon_wrench'] = { model = 'w_me_wrench', preset = 'medium' },
    ['weapon_nightstick'] = { model = 'w_me_nightstick', preset = 'medium' },
    ['weapon_machete'] = { model = 'w_me_machette_lr', preset = 'medium' },
    ['weapon_knife'] = { model = 'w_me_knife_01', preset = 'small' },
    ['weapon_dagger'] = { model = 'w_me_dagger', preset = 'small' },
    ['weapon_switchblade'] = { model = 'w_me_switchblade', preset = 'small' },
    ['weapon_bottle'] = { model = 'w_me_bottle', preset = 'small' },
    ['weapon_flashlight'] = { model = 'w_me_flashlight', preset = 'small' },
    ['weapon_candycane'] = { model = 'w_me_candy_xm3', preset = 'long' },
    ['weapon_stunrod'] = { model = 'w_me_stunrod_01', preset = 'medium' },

    ----------------------------------------------------------------
    -- Custom melee (inventory item name = weapon spawn code)
    -- Models fall back to GetWeapontypeModel + w_me_<name> if the ydr differs.
    -- Tune any that sit wrong with: /backbling weapon_heartbat
    ----------------------------------------------------------------
    ['WEAPON_FORTNITEPICKAXE'] = { model = 'w_me_fortnitepickaxe', preset = 'long', priority = 8 },
    ['WEAPON_HEARTBAT'] = { model = 'w_me_heartbat', preset = 'long', priority = 10 },
    ['WEAPON_ANGELBAT'] = { model = 'w_me_angelbat', preset = 'long', priority = 10 },
    ['WEAPON_DEVILBAT'] = { model = 'w_me_devilbat', preset = 'long', priority = 10 },
    ['WEAPON_CRAYONBAT'] = { model = 'w_me_crayonbat', preset = 'long', priority = 10 },
    ['WEAPON_BANANABAT'] = { model = 'w_me_bananabat', preset = 'long', priority = 10 },
    ['WEAPON_BROOM'] = { model = 'w_me_broom', preset = 'long', priority = 11 },
    ['WEAPON_RAKE'] = { model = 'w_me_rake', preset = 'long', priority = 11 },
    ['WEAPON_SLURPAXE'] = { model = 'w_me_slurpaxe', preset = 'medium', priority = 16 },
    ['WEAPON_FORK'] = { model = 'w_me_fork', preset = 'small', priority = 32 },
}

-- Bones the /backbling editor can cycle through.
Config.EditorBones = {
    { id = 24818, label = 'Spine3 (upper back)' },
    { id = 24817, label = 'Spine2 (mid back)' },
    { id = 24816, label = 'Spine1 (lower back)' },
    { id = 23553, label = 'Spine0 (root)' },
    { id = 10706, label = 'Right clavicle' },
    { id = 64729, label = 'Left clavicle' },
    { id = 11816, label = 'Pelvis' },
}
