RegisterServerEvent('fs_taxi:payFare', function(distance)
    local src = source
    local fare = math.floor(distance * Config.BaseFare)

    if Config.UseInventory then
        local success = exports.ox_inventory:RemoveItem(src, 'money', fare)
        TriggerClientEvent('fs_taxi:paymentStatus', src, success)
    else
        TriggerClientEvent('fs_taxi:paymentStatus', src, true) -- Pago simulado
    end
end)
