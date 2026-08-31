UP = {
    Identifiers = {},
    IdentityRepository = {}
}

local identifiers
local matches
local createdAccount
local attached = true
local attachConflict = false
local auditedReason

function UP.Identifiers.collect()
    return identifiers
end

function UP.Identifiers.primary(values)
    for _, identifier in ipairs(values) do
        if identifier.kind == 'license2' or identifier.kind == 'license' then return identifier end
    end
end

function UP.IdentityRepository.findAssociations()
    return matches
end

function UP.IdentityRepository.findAccount(accountId)
    return { id = accountId, status = 'active' }
end

function UP.IdentityRepository.createAccount()
    return createdAccount
end

function UP.IdentityRepository.attach()
    if attachConflict then
        matches = { { accountId = 'account-2', authoritative = true } }
    end
    return attached
end

function UP.IdentityRepository.auditConflict(_, _, reason)
    auditedReason = reason
end

dofile('resources/[up]/up_core/server/identity/service.lua')

local function authoritative(kind, value)
    return { kind = kind, value = value, authoritative = true }
end

local function auxiliary(kind, value)
    return { kind = kind, value = value, authoritative = false }
end

identifiers = { authoritative('license2', 'license-2'), auxiliary('discord', 'discord-1') }
matches = {}
createdAccount = { id = 'account-new', status = 'active' }
local account = assert(UP.Identity.resolve(1))
assert(account.id == 'account-new')

matches = {
    { accountId = 'account-1', authoritative = true },
    { accountId = 'account-1', authoritative = false }
}
createdAccount = nil
account = assert(UP.Identity.resolve(1))
assert(account.id == 'account-1')

matches = {
    { accountId = 'account-1', authoritative = true },
    { accountId = 'account-2', authoritative = false }
}
local rejected, err = UP.Identity.resolve(1)
assert(rejected == nil and err == 'identity_conflict')
assert(auditedReason == 'identity_conflict')

matches = { { accountId = 'account-1', authoritative = false } }
rejected, err = UP.Identity.resolve(1)
assert(rejected == nil and err == 'identity_verification_required')

matches = { { accountId = 'account-1', authoritative = true } }
attached = false
auditedReason = nil
rejected, err = UP.Identity.resolve(1)
assert(rejected == nil and err == 'identity_attach_failed')
assert(auditedReason == nil)

matches = { { accountId = 'account-1', authoritative = true } }
attachConflict = true
rejected, err = UP.Identity.resolve(1)
assert(rejected == nil and err == 'identity_conflict')
assert(auditedReason == 'identity_conflict')

identifiers = { authoritative('fivem', '12345') }
matches = {}
attached = true
attachConflict = false
rejected, err = UP.Identity.resolve(1)
assert(rejected == nil and err == 'missing_license_identifier')
