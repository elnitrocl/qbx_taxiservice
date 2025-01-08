local locale = Config.Locale
local taxiVeh, taxiPed = nil, nil
local isTaxiActive = false
local isNearTaxi = false
local taxiBlip = nil -- Blip para el taxi

-- Usar locales para mensajes
local function translate(key)
    return Locales[locale][key]
end

-- Comando para llamar un taxi
RegisterCommand('taxi', function()
    if not isTaxiActive then
        lib.notify({ title = translate('taxi_contact'), description = translate('dispatch_message'), type = 'info' })
        TriggerEvent('fs_taxi:callTaxi')
    else
        lib.notify({ title = translate('driver_busy'), type = 'error' })
    end
end)

-- Manejo de la llamada al taxi
RegisterNetEvent('fs_taxi:callTaxi', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    if playerCoords then
        local spawnDistance = 50.0 -- Distancia donde aparecerá el taxi

        -- Calcular coordenadas cercanas para generar el taxi sobre la calle
        local found, streetCoords, heading = GetClosestVehicleNodeWithHeading(
            playerCoords.x + math.random(-spawnDistance, spawnDistance),
            playerCoords.y + math.random(-spawnDistance, spawnDistance),
            playerCoords.z,
            1, 3.0, 0
        )

        if found then
            print("[DEBUG] Generando taxi en coordenadas de calle:", streetCoords)
            print("[DEBUG] Coordenadas del jugador:", playerCoords)

            -- Enviar coordenadas al servidor
            TriggerServerEvent('fs_taxi:spawnTaxi', streetCoords, playerCoords, heading)
        else
            print("[ERROR] No se encontraron coordenadas válidas en la calle.")
            lib.notify({ title = 'Taxi', description = 'No se pudo encontrar una calle cercana para generar el taxi.', type = 'error' })
        end
    else
        print("[ERROR] No se pudo obtener las coordenadas del jugador.")
    end
end)

-- Manejo de la generación del taxi
RegisterNetEvent('fs_taxi:spawnTaxiClient', function(streetCoords, playerCoords, heading)
    if not streetCoords or not playerCoords then
        print("[ERROR] streetCoords o playerCoords son nil. streetCoords:", streetCoords, "playerCoords:", playerCoords)
        return
    end

    print("[DEBUG] Coordenadas para el taxi recibidas:", streetCoords)
    print("[DEBUG] Coordenadas del jugador recibidas:", playerCoords)

    -- Generar el taxi
    local model = Config.TaxiModel
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    taxiVeh = CreateVehicle(model, streetCoords.x, streetCoords.y, streetCoords.z, heading, true, false)
    SetEntityAsMissionEntity(taxiVeh, true, true)

    -- Crear el conductor
    local driverModel = Config.DriverModel
    RequestModel(driverModel)
    while not HasModelLoaded(driverModel) do
        Wait(0)
    end

    taxiPed = CreatePedInsideVehicle(taxiVeh, 26, driverModel, -1, true, false)
    TaskVehicleDriveToCoord(taxiPed, taxiVeh, playerCoords.x, playerCoords.y, playerCoords.z, 20.0, 0, GetEntityModel(taxiVeh), 786603, 1.0)

    -- Crear el blip para el taxi
    if DoesEntityExist(taxiVeh) then
        taxiBlip = AddBlipForEntity(taxiVeh)
        SetBlipSprite(taxiBlip, 56) -- Icono de taxi
        SetBlipColour(taxiBlip, 5) -- Amarillo
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Taxi")
        EndTextCommandSetBlipName(taxiBlip)

        print("[DEBUG] Taxi y conductor generados correctamente.")
    else
        print("[DEBUG] Taxi NO generado correctamente.")
    end
end)

-- Subida al taxi más fácil
CreateThread(function()
    while true do
        Wait(500)
        if taxiVeh and DoesEntityExist(taxiVeh) then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local taxiCoords = GetEntityCoords(taxiVeh)
            local distance = #(playerCoords - taxiCoords)

            if distance < 5.0 then
                if not isNearTaxi then
                    isNearTaxi = true
                    lib.showTextUI('[E] Subir al taxi')
                end

                if IsControlJustPressed(0, 38) then
                    print("[DEBUG] Subiendo al taxi...")
                    TaskWarpPedIntoVehicle(PlayerPedId(), taxiVeh, 2)
                    TriggerEvent('fs_taxi:startRide')
                    lib.hideTextUI()
                end
            else
                if isNearTaxi then
                    isNearTaxi = false
                    lib.hideTextUI()
                end
            end
        end
    end
end)

-- Menú para seleccionar la velocidad del taxi
RegisterNetEvent('fs_taxi:startRide', function()
    print("[DEBUG] Evento 'fs_taxi:startRide' iniciado.")

    -- Remover el blip del taxi
    if taxiBlip then
        RemoveBlip(taxiBlip)
        taxiBlip = nil
    end

    -- Mostrar el menú para seleccionar velocidad
    lib.registerContext({
        id = 'taxi_speed_menu',
        title = 'Opciones de Velocidad',
        options = {
            {
                title = 'Velocidad Normal (Moderada, respeta semáforos)',
                description = 'El taxi se moverá a velocidad moderada respetando las señales.',
                icon = 'fa-car',
                onSelect = function()
                    print("[DEBUG] Velocidad Normal seleccionada.")
                    TriggerEvent('fs_taxi:beginRide', 30.0, 786603, 1.0) -- Velocidad moderada, respeta semáforos
                end
            },
            {
                title = 'Estoy Apurado (Máxima velocidad, ignora semáforos)',
                description = 'El taxi irá a toda velocidad ignorando las señales.',
                icon = 'fa-car-burst',
                onSelect = function()
                    print("[DEBUG] Estoy Apurado seleccionado.")
                    TriggerEvent('fs_taxi:beginRide', 80.0, 786468, 1.5) -- Velocidad máxima, ignora semáforos
                end
            }
        }
    })

    lib.showContext('taxi_speed_menu') -- Mostrar el menú
end)

-- Lógica para iniciar el viaje con la velocidad y la tarifa seleccionadas
RegisterNetEvent('fs_taxi:beginRide', function(speed, drivingStyle, fareMultiplier)
    print("[DEBUG] Iniciando el viaje con velocidad:", speed, "y estilo de conducción:", drivingStyle)

    local startCoords = GetEntityCoords(taxiVeh) -- Coordenadas iniciales del taxi

    CreateThread(function()
        while true do
            Wait(500)

            -- Validar si el taxi y el conductor existen
            if not taxiVeh or not DoesEntityExist(taxiVeh) or not taxiPed or not DoesEntityExist(taxiPed) then
                print("[DEBUG] Taxi o conductor no válidos. Terminando monitoreo.")
                break
            end

            -- Detectar waypoint
            local blip = GetFirstBlipInfoId(8) -- 8 es el ID para waypoints
            if DoesBlipExist(blip) then
                local coords = GetBlipInfoIdCoord(blip)
                if coords then
                    print("[DEBUG] Waypoint detectado en: ", coords)

                    -- Configurar la conducción
                    TaskVehicleDriveToCoordLongrange(taxiPed, taxiVeh, coords.x, coords.y, coords.z, speed, drivingStyle, 10.0)

                    -- Monitorear llegada al destino
                    while true do
                        Wait(500)
                        local taxiCoords = GetEntityCoords(taxiVeh)
                        local distance = #(vector3(coords.x, coords.y, coords.z) - taxiCoords)

                        -- Comprobar si el jugador sigue en el vehículo
                        if not IsPedInVehicle(PlayerPedId(), taxiVeh, false) then
                            print("[DEBUG] Jugador salió del taxi. Calculando tarifa proporcional.")

                            -- Calcular distancia recorrida
                            local distanceTraveled = GetDistanceBetweenCoords(startCoords, taxiCoords, false)
                            local baseFare = 50 -- Tarifa base
                            local distanceFare = distanceTraveled * 0.5 -- Tarifa por unidad de distancia
                            local totalFare = (baseFare + distanceFare) * fareMultiplier

                            -- Cobrar al jugador
                            TriggerServerEvent('fs_taxi:payFare', math.floor(totalFare))

                            -- Notificar al jugador
                            lib.notify({
                                title = 'Taxi',
                                description = 'Has salido del taxi. Tarifa cobrada: $' .. math.floor(totalFare),
                                type = 'error'
                            })

                            -- Limpiar el taxi y el conductor
                            if DoesEntityExist(taxiPed) then
                                DeleteEntity(taxiPed)
                            end
                            if DoesEntityExist(taxiVeh) then
                                DeleteVehicle(taxiVeh)
                            end

                            taxiVeh = nil
                            taxiPed = nil
                            isTaxiActive = false
                            return
                        end

                        -- Llegada al destino
                        if distance < 5.0 then
                            print("[DEBUG] Taxi llegó al destino.")
                            TaskVehiclePark(taxiPed, taxiVeh, coords.x, coords.y, coords.z, GetEntityHeading(taxiVeh), 0, 20.0, false)
                            Wait(2000)

                            -- Calcular el pago completo
                            local totalDistance = GetDistanceBetweenCoords(startCoords, coords, false)
                            local baseFare = 50 -- Tarifa base
                            local distanceFare = totalDistance * 0.5 -- Tarifa por unidad de distancia
                            local totalFare = (baseFare + distanceFare) * fareMultiplier

                            -- Cobrar al jugador
                            TriggerServerEvent('fs_taxi:payFare', math.floor(totalFare))

                            lib.notify({
                                title = 'Taxi',
                                description = '¡Has llegado a tu destino! Tarifa: $' .. math.floor(totalFare),
                                type = 'success'
                            })

                            -- Forzar al jugador a salir
                            TaskLeaveVehicle(PlayerPedId(), taxiVeh, 0)

                            -- Limpiar el taxi
                            DeleteEntity(taxiPed)
                            DeleteVehicle(taxiVeh)
                            taxiVeh = nil
                            taxiPed = nil
                            isTaxiActive = false
                            return
                        end
                    end
                end
            else
                print("[DEBUG] No hay waypoint marcado.")
                lib.notify({ title = 'Taxi', description = 'No tienes un destino marcado en el mapa.', type = 'error' })
            end
        end
    end)
end)
