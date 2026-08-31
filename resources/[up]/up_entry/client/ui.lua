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
    if isReady then sendUiMessage('entry/open') end
end

local function hideEntry(reason)
    if not isOpen then return false end
    isOpen = false
    sendUiMessage('entry/close', { reason = reason })
    return true
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
    if isOpen then sendUiMessage('entry/open') end
    reply({ ok = true, version = UPEntryContracts.uiVersion })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isOpen = false
    isReady = false
    SendNUIMessage({ version = UPEntryContracts.uiVersion, action = 'entry/close', payload = {} })
end)
