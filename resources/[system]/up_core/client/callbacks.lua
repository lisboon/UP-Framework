local pending = {}
local sequence = 0

local function nextRequestId()
    sequence = sequence + 1
    return ('%s-%s-%s'):format(GetPlayerServerId(PlayerId()), GetGameTimer(), sequence)
end

RegisterNetEvent(UPContracts.events.callbackResponse, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPContracts.version then return end

    local deferred = pending[envelope.requestId]
    if not deferred then return end

    pending[envelope.requestId] = nil
    deferred:resolve(envelope)
end)

local function triggerCallback(name, payload)
    local requestId = nextRequestId()
    local deferred = promise.new()
    pending[requestId] = deferred

    TriggerServerEvent(UPContracts.events.callbackRequest, {
        version = UPContracts.version,
        requestId = requestId,
        name = name,
        payload = payload
    })

    SetTimeout(UPConfig.callbackTimeoutMs, function()
        if pending[requestId] then
            pending[requestId] = nil
            deferred:resolve({ ok = false, error = 'timeout' })
        end
    end)

    local response = Citizen.Await(deferred)
    if not response.ok then return nil, response.error end
    return response.result, nil
end

exports('TriggerCallback', triggerCallback)
