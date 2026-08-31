UP.Callbacks = {}

local function consumeRateLimit(source, name)
    local now = GetGameTimer() / 1000.0
    local config = UPConfig.callbackRateLimit
    local playerLimits = UP.rateLimits[source] or {}
    local bucket = playerLimits[name] or { tokens = config.capacity, updatedAt = now }
    local elapsed = math.max(0, now - bucket.updatedAt)

    bucket.tokens = math.min(config.capacity, bucket.tokens + elapsed * config.refillPerSecond)
    bucket.updatedAt = now

    if bucket.tokens < 1 then
        playerLimits[name] = bucket
        UP.rateLimits[source] = playerLimits
        return false
    end

    bucket.tokens = bucket.tokens - 1
    playerLimits[name] = bucket
    UP.rateLimits[source] = playerLimits
    return true
end

function UP.Callbacks.register(name, handler)
    assert(UP.Validation.callbackName(name), 'invalid callback name')
    assert(type(handler) == 'function', 'callback handler must be a function')
    assert(UP.callbacks[name] == nil, ('callback already registered: %s'):format(name))
    UP.callbacks[name] = handler
end

RegisterNetEvent(UPContracts.events.callbackRequest, function(envelope)
    local source = source

    if type(envelope) ~= 'table'
        or envelope.version ~= UPContracts.version
        or not UP.Validation.requestId(envelope.requestId)
        or not UP.Validation.callbackName(envelope.name)
    then
        return
    end

    local player = UP.players[source]
    local handler = UP.callbacks[envelope.name]
    if not player or not handler or not consumeRateLimit(source, envelope.name) then
        return
    end

    local ok, result, handlerError = xpcall(function()
        return handler(source, envelope.payload, player)
    end, debug.traceback)

    if not ok then
        print(('^1[up_core]^7 callback %s failed: %s'):format(envelope.name, result))
        TriggerClientEvent(UPContracts.events.callbackResponse, source, {
            version = UPContracts.version,
            requestId = envelope.requestId,
            ok = false,
            error = 'internal_error'
        })
        return
    end

    if handlerError then
        TriggerClientEvent(UPContracts.events.callbackResponse, source, {
            version = UPContracts.version,
            requestId = envelope.requestId,
            ok = false,
            error = handlerError
        })
        return
    end

    TriggerClientEvent(UPContracts.events.callbackResponse, source, {
        version = UPContracts.version,
        requestId = envelope.requestId,
        ok = true,
        result = result
    })
end)

UP.Callbacks.register('core.get_state', function(_, _, player)
    return {
        loaded = player.loaded,
        passport = player.passport
    }
end)
