---@class UPMoneyTransaction
---@field idempotencyKey string
---@field debitAccount string
---@field creditAccount string
---@field amount integer
---@field reason string
---@field metadata table<string, unknown>?

---@class UPPlayerState
---@field source integer
---@field accountId string
---@field characterId string?
---@field passport integer?
---@field loaded boolean

---@class UPCallbackEnvelope
---@field version integer
---@field requestId string
---@field name string
---@field payload unknown

UPContracts = {
    version = 1,
    events = {
        playerLoaded = 'up:player:loaded:v1',
        playerUnloaded = 'up:player:unloaded:v1',
        characterCreated = 'up:character:created:v1',
        characterDeleted = 'up:character:deleted:v1',
        characterActivated = 'up:character:activated:v1',
        characterReady = 'up:character:ready:v1',
        callbackRequest = 'up:callback:request:v1',
        callbackResponse = 'up:callback:response:v1'
    }
}
