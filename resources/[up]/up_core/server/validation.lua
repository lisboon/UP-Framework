UP.Validation = {}

local function isInteger(value)
    return type(value) == 'number' and value == math.floor(value)
end

function UP.Validation.string(value, minLength, maxLength)
    if type(value) ~= 'string' then return false end
    local length = utf8.len(value)
    if not length then return false end
    return length >= minLength and length <= maxLength
end

function UP.Validation.characterName(value, minLength, maxLength)
    if not UP.Validation.string(value, minLength, maxLength) then return nil end

    local normalized = value:match('^%s*(.-)%s*$'):gsub('%s+', ' ')
    if not UP.Validation.string(normalized, minLength, maxLength) then return nil end

    for _, codepoint in utf8.codes(normalized) do
        local asciiLetter = (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
        local separator = codepoint == 32 or codepoint == 39 or codepoint == 45
        local latinLetter = codepoint >= 192 and codepoint <= 687
        if not asciiLetter and not separator and not latinLetter then return nil end
    end

    return normalized
end

function UP.Validation.birthDate(value, minimumAge, maximumAge)
    if type(value) ~= 'string' then return false end

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or month < 1 or month > 12 then return false end

    local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
    if leap then monthDays[2] = 29 end
    if day < 1 or day > monthDays[month] then return false end

    local now = os.date('!*t')
    local age = now.year - year
    if now.month < month or (now.month == month and now.day < day) then age = age - 1 end
    return age >= minimumAge and age <= maximumAge
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
