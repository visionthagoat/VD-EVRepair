Config = {}

-- ox_inventory item used for electric vehicle repairs.
Config.ItemName = 'ev_repair_kit'

-- Vehicle must be this close when the kit is first used.
Config.MaxVehicleDistance = 4.0

-- Once the wrench is equipped, the player can walk around the vehicle but
-- cannot wander farther than this distance from it.
Config.MaxWalkDistance = 9.0

-- How close the player must be to the calculated rear service point before
-- ENTER can begin the repair.
Config.RearInteractionDistance = 1.8

-- Extra distance behind the model's rear-most bound. Increase this slightly
-- if a custom vehicle's rear interaction point feels too close to the bumper.
Config.RearExtraOffset = 0.35
Config.RearZOffset = 0.0

-- Repair time in milliseconds.
Config.RepairDuration = 10000

-- Target health after a successful repair.
-- 1.00 = 100%, 0.85 = 85%, 0.50 = 50%.
-- The kit will never LOWER a vehicle that is already healthier than this value.
Config.RepairPercentage = 1.00

-- When true, visible dents/body deformation are actually repaired too.
-- GTA does not support a clean percentage-based visual dent repair, so visible
-- bodywork is restored fully while RepairPercentage controls mechanical health.
Config.RepairVisualDamage = true

-- If true, the kit is removed only after a successful repair.
Config.ConsumeOnSuccess = true

-- Keep this false unless you want the EV kit to repair every vehicle.
Config.AllowAllVehicles = false

-- Repair animation used after ENTER is pressed at the rear of the vehicle.
Config.RepairAnimation = {
    dict = 'mini@repair',
    clip = 'fixing_a_ped'
}

-- Small adjustable hand wrench carried in the right hand while walking to the back of the EV.
-- IMPORTANT: prop_tool_spanner01 can appear as the large red pipe wrench on some builds.
-- prop_tool_adjspanner is the smaller silver adjustable wrench.
Config.RepairTool = {
    model = 'prop_tool_adjspanner',
    bone = 57005, -- right hand
    pos = vec3(0.11, 0.02, -0.02),
    rot = vec3(-95.0, 5.0, 5.0)
}

-- Electric/custom EV model allowlist.
Config.ElectricVehicles = {
    -- Add custom EV spawn names here, for example:
    -- 'your_custom_ev',

    -- GTA electric vehicles / useful defaults
    'airtug',
    'buffalo5',
    'caddy',
    'caddy2',
    'caddy3',
    'coureur',
    'cyclone',
    'cyclone2',
    'imorgon',
    'inductor',
    'iwagen',
    'khamelion',
    'minitank',
    'neon',
    'omnisegt',
    'powersurge',
    'raiden',
    'rcbandito',
    'surge',
    'tezeract',
    'virtue',
    'vivanite',
    'voltic',
    'voltic2'
}
