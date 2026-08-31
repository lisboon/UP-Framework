local isOpen = false
local isReady = false

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

    coreCallback('characters.select', envelope.payload, function(response)
        if response.ok then SetNuiFocus(false, false) end
        reply(response)
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isOpen = false
    isReady = false
    SetNuiFocus(false, false)
    SendNUIMessage({ version = UPEntryContracts.uiVersion, action = 'entry/close', payload = {} })
end)
