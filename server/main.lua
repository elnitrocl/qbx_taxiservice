RegisterNetEvent('fs_taxi:spawnTaxi', function(spawnCoords, playerCoords)
    print("[DEBUG] spawnCoords recibidas en el servidor:", spawnCoords)
    print("[DEBUG] playerCoords recibidas en el servidor:", playerCoords)

    if spawnCoords and playerCoords then
        TriggerClientEvent('fs_taxi:spawnTaxiClient', source, spawnCoords, playerCoords)
    else
        print("[ERROR] spawnCoords o playerCoords son nil en el servidor.")
    end
end)