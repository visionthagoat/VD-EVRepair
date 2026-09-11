RegisterNetEvent('vd-evrepair:server:consumeKit', function()
    local src = source

    if not Config.ConsumeOnSuccess then return end

    local count = exports.ox_inventory:GetItemCount(src, Config.ItemName)
    if not count or count < 1 then
        return
    end

    exports.ox_inventory:RemoveItem(src, Config.ItemName, 1)
end)
