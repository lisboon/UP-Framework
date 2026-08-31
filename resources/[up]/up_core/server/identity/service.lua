UP.Identity = {}

local function accountSets(matches)
    local all = {}
    local authoritative = {}
    for _, match in ipairs(matches) do
        all[match.accountId] = true
        if match.authoritative then authoritative[match.accountId] = true end
    end
    return all, authoritative
end

local function count(set)
    local total, only = 0, nil
    for value in pairs(set) do
        total = total + 1
        only = value
    end
    return total, only
end

local function reject(matches, identifiers, reason)
    pcall(UP.IdentityRepository.auditConflict, matches, identifiers, reason)
    return nil, reason
end

local function attachIdentifiers(account, identifiers)
    local executed, attached = pcall(UP.IdentityRepository.attach, account.id, identifiers)
    if executed and attached then return account end

    local verified, refreshed = pcall(UP.IdentityRepository.findAssociations, identifiers)
    if verified then
        for _, match in ipairs(refreshed) do
            if match.accountId ~= account.id then
                return reject(refreshed, identifiers, 'identity_conflict')
            end
        end
    end
    return nil, 'identity_attach_failed'
end

function UP.Identity.resolve(source)
    local identifiers = UP.Identifiers.collect(source)
    local primary = UP.Identifiers.primary(identifiers)
    if not primary then return nil, 'missing_license_identifier' end

    local matches = UP.IdentityRepository.findAssociations(identifiers)
    local allAccounts, authoritativeAccounts = accountSets(matches)
    local allCount, onlyAccountId = count(allAccounts)
    local authoritativeCount = count(authoritativeAccounts)

    if allCount > 1 or authoritativeCount > 1 then
        return reject(matches, identifiers, 'identity_conflict')
    end
    if allCount == 1 and authoritativeCount == 0 then
        return reject(matches, identifiers, 'identity_verification_required')
    end

    local account
    if onlyAccountId then
        account = UP.IdentityRepository.findAccount(onlyAccountId)
    else
        account = UP.IdentityRepository.createAccount(primary)
        if not account then
            matches = UP.IdentityRepository.findAssociations(identifiers)
            allAccounts, authoritativeAccounts = accountSets(matches)
            allCount, onlyAccountId = count(allAccounts)
            authoritativeCount = count(authoritativeAccounts)
            if allCount ~= 1 or authoritativeCount ~= 1 then
                return reject(matches, identifiers, 'account_create_failed')
            end
            account = UP.IdentityRepository.findAccount(onlyAccountId)
        end
    end

    if not account then return nil, 'account_not_found' end
    return attachIdentifiers(account, identifiers)
end
