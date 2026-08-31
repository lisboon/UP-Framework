UP = {
    Players = {},
    CharacterRepository = {},
    characterMutations = {}
}
UPContracts = {
    events = {
        characterCreated = 'created',
        characterDeleted = 'deleted'
    }
}

local player = { accountId = 'account-1', characterId = nil, passport = nil }
local emitted = {}
local selectedId

function UP.Players.get()
    return player
end

function UP.Players.activateCharacter(_, passport)
    return true, { passport = passport, characterId = 'character-1' }
end

function UP.CharacterRepository.listActive()
    return {
        {
            passport = 1000,
            firstName = 'Ana',
            lastName = 'Silva',
            birthDate = '2000-02-29',
            createdAt = 'created-at',
            updatedAt = 'updated-at',
            lastSelectedAt = nil
        }
    }
end

function UP.CharacterRepository.create(_, data)
    return {
        id = 'character-1',
        passport = 1000,
        firstName = data.firstName,
        lastName = data.lastName,
        birthDate = data.birthDate,
        createdAt = 'created-at',
        updatedAt = 'updated-at'
    }
end

function UP.CharacterRepository.findActive(_, passport)
    return { id = 'character-1', passport = passport }
end

function UP.CharacterRepository.softDelete()
    return true
end

function UP.CharacterRepository.markSelected(characterId)
    selectedId = characterId
    return 1
end

function TriggerEvent(name, _, payload)
    emitted[#emitted + 1] = { name = name, payload = payload }
end

dofile('resources/[up]/up_core/shared/config.lua')
dofile('resources/[up]/up_core/server/core/validation.lua')
dofile('resources/[up]/up_core/server/characters/service.lua')

local characters = assert(UP.Characters.list(1))
assert(#characters == 1)
assert(characters[1].updatedAt == 'updated-at')

local created = assert(UP.Characters.create(1, {
    firstName = ' Ana ',
    lastName = 'Silva',
    birthDate = '2000-02-29'
}))
assert(created.firstName == 'Ana')
assert(emitted[#emitted].name == 'created')

player.characterId = 'active-character'
local blocked, blockedError = UP.Characters.create(1, {
    firstName = 'Ana',
    lastName = 'Silva',
    birthDate = '2000-02-29'
})
assert(blocked == nil and blockedError == 'character_session_active')

player.characterId = nil
assert(UP.Characters.delete(1, 1000))
assert(emitted[#emitted].name == 'deleted')

local selected = assert(UP.Characters.select(1, 1000))
assert(selected.passport == 1000)
assert(selectedId == 'character-1')
