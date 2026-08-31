UP.Identifiers = {}

local providers = {
    license2 = { priority = 1, authoritative = true },
    license = { priority = 2, authoritative = true },
    fivem = { priority = 3, authoritative = true },
    steam = { priority = 4, authoritative = false },
    discord = { priority = 5, authoritative = false }
}

function UP.Identifiers.collect(source)
    local result = {}
    local seen = {}

    for _, raw in ipairs(GetPlayerIdentifiers(source)) do
        local kind, value = raw:match('^([^:]+):(.+)$')
        local provider = providers[kind]
        local key = kind and value and (kind .. ':' .. value) or nil
        if provider and not seen[key] then
            seen[key] = true
            result[#result + 1] = {
                kind = kind,
                value = value,
                priority = provider.priority,
                authoritative = provider.authoritative
            }
        end
    end

    table.sort(result, function(left, right)
        return left.priority < right.priority
    end)
    return result
end

function UP.Identifiers.primary(identifiers)
    for _, identifier in ipairs(identifiers) do
        if identifier.kind == 'license2' or identifier.kind == 'license' then
            return identifier
        end
    end
    return nil
end

function UP.Identifiers.providers(identifiers)
    local result = {}
    for _, identifier in ipairs(identifiers) do
        result[#result + 1] = identifier.kind
    end
    return result
end
