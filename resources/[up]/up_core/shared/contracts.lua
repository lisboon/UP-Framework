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
---@field phase 'account_ready'|'character_selected'|'spawning'|'spawned'
---@field spawnAttemptId string?
---@field spawnLocationId string?
---@field pendingSpawnLocationId string?
---@field spawnAttestation table?
---@field spawnCompletionPending boolean?

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
        characterSelected = 'up:character:selected:v1',
        characterReady = 'up:character:ready:v1',
        spawnAuthorized = 'up:spawn:authorized:v1',
        spawnFailed = 'up:spawn:failed:v1',
        spawnCompleted = 'up:spawn:completed:v1',
        playerSpawned = 'up:player:spawned:v1',
        callbackRequest = 'up:callback:request:v1',
        callbackResponse = 'up:callback:response:v1'
    }
}
