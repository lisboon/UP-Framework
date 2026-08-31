UP.Identifiers = {}

local accepted = {
    license = 1,
    license2 = 2,
    fivem = 3,
    discord = 4,
    steam = 5
}

function UP.Identifiers.collect(source)
    local result = {}

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        local kind, value = identifier:match('^([^:]+):(.+)$')
        if kind and value and accepted[kind] then
            result[#result + 1] = {
                kind = kind,
                value = value,
                priority = accepted[kind]
            }
        end
    end

    table.sort(result, function(left, right)
        return left.priority < right.priority
    end)

    return result
end

function UP.Identifiers.primary(source)
    local identifiers = UP.Identifiers.collect(source)
    for _, identifier in ipairs(identifiers) do
        if identifier.kind == 'license' or identifier.kind == 'license2' then
            return identifier
        end
    end

    return nil
end
