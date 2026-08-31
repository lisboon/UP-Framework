local isOpen = false
local isReady = false
local spawnLocations = {}

local function sendUiMessage(action, payload)
    SendNUIMessage({
        version = UPEntryContracts.uiVersion,
        action = action,
        payload = payload or {}
    })
end

local function showEntry()
    isOpen = true
    if isReady then
        SetNuiFocus(true, true)
        sendUiMessage('entry/open')
    end
end

local function hideEntry(reason)
    if not isOpen then return false end
    isOpen = false
    SetNuiFocus(false, false)
    sendUiMessage('entry/close', { reason = reason })
    return true
end

local function validEnvelope(envelope)
    return type(envelope) == 'table' and envelope.version == UPEntryContracts.uiVersion
end

local function coreCallback(name, payload, reply)
    if not isOpen then
        reply({ ok = false, error = 'entry_not_open', version = UPEntryContracts.uiVersion })
        return
    end

    local called, result, err = pcall(function()
        return exports.up_core:TriggerCallback(name, payload or {})
    end)
    if not called then
        reply({ ok = false, error = 'core_unavailable', version = UPEntryContracts.uiVersion })
        return
    end

    reply({
        ok = result ~= nil,
        result = result,
        error = err,
        version = UPEntryContracts.uiVersion
    })
end

RegisterNetEvent(UPEntryContracts.events.entered, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    showEntry()
end)

RegisterNetEvent(UPEntryContracts.events.left, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    hideEntry(envelope.reason)
end)

RegisterNUICallback('entry/ready', function(envelope, reply)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.uiVersion then
        reply({ ok = false, error = 'unsupported_version' })
        return
    end

    isReady = true
    if isOpen then
        SetNuiFocus(true, true)
        sendUiMessage('entry/open')
    end
    reply({ ok = true, version = UPEntryContracts.uiVersion })
end)

RegisterNUICallback('characters/load', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end
    coreCallback('characters.bootstrap', {}, reply)
end)

RegisterNUICallback('characters/create', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end
    coreCallback('characters.create', envelope.payload, reply)
end)

RegisterNUICallback('characters/delete', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end
    coreCallback('characters.delete', envelope.payload, reply)
end)

RegisterNUICallback('characters/select', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end

    coreCallback('characters.select', envelope.payload, reply)
end)

RegisterNUICallback('characters/preview', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end

    local passport = envelope.payload and tonumber(envelope.payload.passport)
    local ok = UPEntryPresentation and UPEntryPresentation.preview(passport)
    reply({ ok = ok == true, result = ok == true, error = ok and nil or 'preview_unavailable', version = UPEntryContracts.uiVersion })
end)

RegisterNUICallback('spawns/load', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end

    coreCallback('spawns.list', {}, function(response)
        if not response.ok or type(response.result) ~= 'table' then
            reply(response)
            return
        end

        spawnLocations = {}
        local public = {}
        for index, location in ipairs(response.result) do
            if type(location) == 'table' and type(location.id) == 'string' and type(location.label) == 'string' then
                spawnLocations[location.id] = location
                public[#public + 1] = { id = location.id, label = location.label }
            end
        end

        if public[1] then UPEntryPresentation.previewLocation(spawnLocations[public[1].id], true) end
        reply({ ok = true, result = public, version = UPEntryContracts.uiVersion })
    end)
end)

RegisterNUICallback('spawns/preview', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end

    local location = envelope.payload and spawnLocations[envelope.payload.locationId]
    local ok = location and UPEntryPresentation.previewLocation(location, false)
    reply({ ok = ok == true, result = ok == true, error = ok and nil or 'spawn_location_invalid', version = UPEntryContracts.uiVersion })
end)

RegisterNUICallback('spawns/select', function(envelope, reply)
    if not validEnvelope(envelope) then
        reply({ ok = false, error = 'unsupported_version', version = UPEntryContracts.uiVersion })
        return
    end

    local locationId = envelope.payload and envelope.payload.locationId
    local location = spawnLocations[locationId]
    if not location or not UPEntryPresentation.commitLocation(location) then
        reply({ ok = false, error = 'spawn_location_invalid', version = UPEntryContracts.uiVersion })
        return
    end

    coreCallback('spawns.select', { locationId = locationId }, function(response)
        if response.ok then
            SetNuiFocus(false, false)
        else
            UPEntryPresentation.resumeLocation()
        end
        reply(response)
    end)
end)

RegisterNetEvent(UPEntryContracts.coreEvents.spawnFailed, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    UPEntryPresentation.resumeLocation()
    SetNuiFocus(true, true)
    sendUiMessage('spawn/failed', { reason = envelope.reason })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isOpen = false
    isReady = false
    spawnLocations = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ version = UPEntryContracts.uiVersion, action = 'entry/close', payload = {} })
end)
