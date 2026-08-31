UP = rawget(_G, 'UP') or {}

UP.players = UP.players or {}
UP.callbacks = UP.callbacks or {}
UP.rateLimits = UP.rateLimits or {}
UP.characterMutations = UP.characterMutations or {}
UP.ready = false

local function requireDatabase()
    local state = GetResourceState('oxmysql')
    if state ~= 'started' then
        error(('oxmysql must be started before up_core (state=%s)'):format(state))
    end
end

local function verifySchema()
    local migration = MySQL.scalar.await(
        'SELECT MAX(version) FROM up_core_schema_migrations'
    )

    if migration == nil then
        error('UP database is not migrated; run upctl doctor and apply migrations')
    end

    if tonumber(migration) < UPConfig.schemaVersion then
        error(('UP schema version is unsupported: %s'):format(migration))
    end
end

MySQL.ready(function()
    requireDatabase()
    verifySchema()
    UP.ready = true
    print(('^2[up_core]^7 ready (contract v%s, schema v%s)'):format(
        UPContracts.version,
        UPConfig.schemaVersion
    ))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    UP.ready = false
    UP.players = {}
    UP.rateLimits = {}
    UP.characterMutations = {}
end)
