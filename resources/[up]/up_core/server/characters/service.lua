UP.Characters = {}

local function lockPlayer(source)
    if UP.playerMutations[source] then return false end
    UP.playerMutations[source] = true
    return true
end

local function unlockPlayer(source)
    UP.playerMutations[source] = nil
end

local function publicCharacter(character)
    return {
        passport = tonumber(character.passport),
        firstName = character.firstName,
        lastName = character.lastName,
        birthDate = character.birthDate,
        createdAt = character.createdAt,
        updatedAt = character.updatedAt,
        lastSelectedAt = character.lastSelectedAt
    }
end

function UP.Characters.list(source)
    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end

    local rows = UP.CharacterRepository.listActive(player.accountId)
    local characters = {}
    for index, character in ipairs(rows) do
        characters[index] = publicCharacter(character)
    end
    return characters
end

function UP.Characters.create(source, payload)
    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.characterId then return nil, 'character_session_active' end
    if type(payload) ~= 'table' then return nil, 'invalid_payload' end

    local config = UPConfig.character
    local firstName = UP.Validation.characterName(payload.firstName, config.firstNameMinLength, config.firstNameMaxLength)
    local lastName = UP.Validation.characterName(payload.lastName, config.lastNameMinLength, config.lastNameMaxLength)
    if not firstName or not lastName then return nil, 'invalid_name' end
    if not UP.Validation.birthDate(payload.birthDate, config.minimumAge, config.maximumAge) then
        return nil, 'invalid_birth_date'
    end
    if not lockPlayer(source) then return nil, 'player_busy' end

    local executed, character, err = pcall(UP.CharacterRepository.create, player.accountId, {
        firstName = firstName,
        lastName = lastName,
        birthDate = payload.birthDate
    })
    unlockPlayer(source)
    if not executed then return nil, 'character_create_failed' end
    if not character then return nil, err end

    local result = publicCharacter(character)
    TriggerEvent(UPContracts.events.characterCreated, source, result)
    return result
end

function UP.Characters.delete(source, passport)
    if not UP.Validation.passport(passport) then return nil, 'invalid_passport' end

    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.characterId then return nil, 'character_session_active' end
    if not lockPlayer(source) then return nil, 'player_busy' end

    local queried, character = pcall(UP.CharacterRepository.findActive, player.accountId, passport)
    if not queried or not character then
        unlockPlayer(source)
        return nil, queried and 'character_not_available' or 'character_delete_failed'
    end
    if UP.characterMutations[character.id] then
        unlockPlayer(source)
        return nil, 'character_busy'
    end
    UP.characterMutations[character.id] = true

    local deleted = UP.CharacterRepository.softDelete(player.accountId, character)
    UP.characterMutations[character.id] = nil
    unlockPlayer(source)
    if not deleted then return nil, 'character_delete_failed' end

    TriggerEvent(UPContracts.events.characterDeleted, source, passport)
    return true
end

function UP.Characters.select(source, passport)
    if not UP.Validation.passport(passport) then return nil, 'invalid_passport' end

    local player = UP.Players.get(source)
    if not player then return nil, 'player_not_loaded' end
    if player.characterId then return nil, 'character_session_active' end
    if not lockPlayer(source) then return nil, 'player_busy' end

    local queried, character = pcall(UP.CharacterRepository.findActive, player.accountId, passport)
    if not queried then
        unlockPlayer(source)
        return nil, 'character_select_failed'
    end
    if not character then
        unlockPlayer(source)
        return nil, 'character_not_available'
    end
    if not UP.CharacterRepository.select(player.accountId, character) then
        unlockPlayer(source)
        return nil, 'character_select_failed'
    end

    local activated, result = UP.Players.activateCharacter(source, character)
    unlockPlayer(source)
    if not activated then return nil, result end

    return { passport = result.passport }
end
