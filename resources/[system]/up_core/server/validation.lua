UP.Validation = {}

local function isInteger(value)
    return type(value) == 'number' and value == math.floor(value)
end

function UP.Validation.string(value, minLength, maxLength)
    if type(value) ~= 'string' then return false end
    local length = #value
    return length >= minLength and length <= maxLength
end

function UP.Validation.requestId(value)
    if not UP.Validation.string(value, 8, 64) then return false end
    return value:match('^[%w%-%_]+$') ~= nil
end

function UP.Validation.passport(value)
    return isInteger(value) and value > 0 and value < 9007199254740991
end

function UP.Validation.amount(value)
    return isInteger(value) and value > 0 and value <= 1000000000
end

function UP.Validation.callbackName(value)
    if not UP.Validation.string(value, 3, 64) then return false end
    return value:match('^[a-z][a-z0-9_%.:]+$') ~= nil
end
