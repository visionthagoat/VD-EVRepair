local electricHashes = {}
local busy = false

CreateThread(function()
    for _, model in ipairs(Config.ElectricVehicles) do
        electricHashes[joaat(model)] = true
    end
end)

local function notify(description, type)
    lib.notify({
        title = 'Electric Repair Kit',
        description = description,
        type = type or 'inform'
    })
end

local function getClosestVehicle(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, maxDistance, 0, 71)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local distance = #(coords - GetEntityCoords(vehicle))
    if distance > maxDistance then
        return nil
    end

    return vehicle
end

local function isAllowedVehicle(vehicle)
    if Config.AllowAllVehicles then return true end
    return electricHashes[GetEntityModel(vehicle)] == true
end

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + 2000

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function createRepairTool(ped)
    local hash = requestModel(Config.RepairTool.model)
    if not hash then return nil end

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if prop == 0 or not DoesEntityExist(prop) then return nil end

    local bone = GetPedBoneIndex(ped, Config.RepairTool.bone)
    AttachEntityToEntity(
        prop,
        ped,
        bone,
        Config.RepairTool.pos.x, Config.RepairTool.pos.y, Config.RepairTool.pos.z,
        Config.RepairTool.rot.x, Config.RepairTool.rot.y, Config.RepairTool.rot.z,
        true, true, false, true, 1, true
    )

    return prop
end

local function deleteRepairTool(prop)
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
end

local function getRearRepairPoint(vehicle)
    local minDim, _ = GetModelDimensions(GetEntityModel(vehicle))
    local rearOffset = minDim.y - Config.RearExtraOffset
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, rearOffset, Config.RearZOffset)
end

local function repairVehicle(vehicle)
    if not requestControl(vehicle) then
        return false
    end

    local pct = tonumber(Config.RepairPercentage) or 1.0
    pct = math.max(0.0, math.min(1.0, pct))
    local targetHealth = 1000.0 * pct

    -- GTA keeps visual dents/deformation separate from engine/body health.
    -- SetVehicleFixed is needed to actually restore the vehicle's visible bodywork.
    -- We then put the mechanical health back to the configured percentage below.
    if Config.RepairVisualDamage ~= false then
        SetVehicleFixed(vehicle)
        SetVehicleDeformationFixed(vehicle)
    end

    local currentEngine = GetVehicleEngineHealth(vehicle)
    local currentBody = GetVehicleBodyHealth(vehicle)
    local currentTank = GetVehiclePetrolTankHealth(vehicle)

    -- If SetVehicleFixed was used, health is temporarily 1000. Set the mechanical
    -- values to the configured target so RepairPercentage still controls durability.
    if Config.RepairVisualDamage ~= false then
        SetVehicleEngineHealth(vehicle, targetHealth)
        SetVehicleBodyHealth(vehicle, targetHealth)
        SetVehiclePetrolTankHealth(vehicle, targetHealth)
    else
        if currentEngine < targetHealth then
            SetVehicleEngineHealth(vehicle, targetHealth)
        end

        if currentBody < targetHealth then
            SetVehicleBodyHealth(vehicle, targetHealth)
        end

        if currentTank < targetHealth then
            SetVehiclePetrolTankHealth(vehicle, targetHealth)
        end
    end

    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineCanDegrade(vehicle, true)

    for wheel = 0, 7 do
        SetVehicleTyreFixed(vehicle, wheel)
    end

    return true
end

local function waitAtRear(vehicle, tool)
    local textVisible = false
    local lastText = nil

    while busy do
        Wait(0)

        local ped = PlayerPedId()
        if not DoesEntityExist(vehicle) then
            if textVisible then lib.hideTextUI() end
            return false, 'The vehicle is no longer available.'
        end

        if IsPedInAnyVehicle(ped, false) then
            if textVisible then lib.hideTextUI() end
            return false, 'Exit the vehicle to continue the repair.'
        end

        local pedCoords = GetEntityCoords(ped)
        local vehicleCoords = GetEntityCoords(vehicle)
        if #(pedCoords - vehicleCoords) > Config.MaxWalkDistance then
            if textVisible then lib.hideTextUI() end
            return false, 'You moved too far away from the vehicle.'
        end

        local rearPoint = getRearRepairPoint(vehicle)
        local rearDistance = #(pedCoords - rearPoint)
        local atRear = rearDistance <= Config.RearInteractionDistance

        local text
        if atRear then
            text = '[ENTER] Start EV repair  |  [BACKSPACE] Cancel'
        else
            text = 'Take the wrench to the rear of the EV  |  [BACKSPACE] Cancel'
        end

        if text ~= lastText then
            if textVisible then lib.hideTextUI() end
            lib.showTextUI(text, {
                position = 'right-center',
                icon = atRear and 'wrench' or 'car-rear'
            })
            textVisible = true
            lastText = text
        end

        -- Enter / controller A
        if atRear and IsControlJustPressed(0, 191) then
            if textVisible then lib.hideTextUI() end
            return true
        end

        -- Backspace / controller B
        if IsControlJustPressed(0, 177) then
            if textVisible then lib.hideTextUI() end
            return false, 'Repair cancelled.'
        end
    end

    if textVisible then lib.hideTextUI() end
    return false, 'Repair cancelled.'
end

RegisterNetEvent('vd-evrepair:client:useKit', function()
    if busy then return end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return notify('Exit the vehicle before using the repair kit.', 'error')
    end

    local vehicle = getClosestVehicle(Config.MaxVehicleDistance)
    if not vehicle then
        return notify('No vehicle is close enough to repair.', 'error')
    end

    if not isAllowedVehicle(vehicle) then
        return notify('This repair kit is only for electric vehicles.', 'error')
    end

    local choice = lib.alertDialog({
        header = 'EV Repair Kit',
        content = 'This electric vehicle is serviced from the **rear**. Take the wrench to the back of the vehicle, then press **ENTER** when prompted to begin repairing.',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Take Wrench',
            cancel = 'Cancel'
        }
    })

    if choice ~= 'confirm' then return end

    busy = true

    local tool = createRepairTool(ped)
    if not tool then
        busy = false
        return notify('Unable to equip the repair wrench.', 'error')
    end

    notify('Take the wrench to the rear of the vehicle.', 'inform')

    local ready, reason = waitAtRear(vehicle, tool)
    if not ready then
        deleteRepairTool(tool)
        busy = false
        return notify(reason or 'Repair cancelled.', 'error')
    end

    -- Keep the manually attached wrench in hand while ox_lib handles the repair animation.
    local success = lib.progressCircle({
        duration = Config.RepairDuration,
        position = 'bottom',
        label = 'Repairing EV battery and drivetrain...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = Config.RepairAnimation.dict,
            clip = Config.RepairAnimation.clip
        }
    })

    deleteRepairTool(tool)

    if not success then
        busy = false
        return notify('Repair cancelled.', 'error')
    end

    local rearPoint = getRearRepairPoint(vehicle)
    local pedCoords = GetEntityCoords(ped)
    if not DoesEntityExist(vehicle) or #(pedCoords - rearPoint) > (Config.RearInteractionDistance + 1.0) then
        busy = false
        return notify('You are no longer at the rear service area.', 'error')
    end

    if not isAllowedVehicle(vehicle) then
        busy = false
        return notify('This vehicle is not approved for the EV repair kit.', 'error')
    end

    if not repairVehicle(vehicle) then
        busy = false
        return notify('Unable to take control of the vehicle. Try again.', 'error')
    end

    if Config.ConsumeOnSuccess then
        TriggerServerEvent('vd-evrepair:server:consumeKit')
    end

    notify('Electric vehicle repaired.', 'success')
    busy = false
end)
