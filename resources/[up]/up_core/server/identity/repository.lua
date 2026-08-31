UP.IdentityRepository = {}

function UP.IdentityRepository.findAssociations(identifiers)
    local matches = {}
    for _, identifier in ipairs(identifiers) do
        local association = MySQL.single.await([[
            SELECT ai.account_id AS accountId, a.status
              FROM up_core_account_identifiers ai
              JOIN up_core_accounts a ON a.id = ai.account_id
             WHERE ai.provider = ? AND ai.identifier = ?
             LIMIT 1
        ]], { identifier.kind, identifier.value })

        if association then
            association.kind = identifier.kind
            association.authoritative = identifier.authoritative
            matches[#matches + 1] = association
        end
    end
    return matches
end

function UP.IdentityRepository.findAccount(accountId)
    return MySQL.single.await(
        'SELECT id, status FROM up_core_accounts WHERE id = ? LIMIT 1',
        { accountId }
    )
end

function UP.IdentityRepository.createAccount(primary)
    local accountId = MySQL.scalar.await('SELECT UUID()')
    local created = MySQL.transaction.await({
        {
            query = 'INSERT INTO up_core_accounts (id, status) VALUES (?, ?)',
            values = { accountId, 'active' }
        },
        {
            query = 'INSERT INTO up_core_account_identifiers (account_id, provider, identifier) VALUES (?, ?, ?)',
            values = { accountId, primary.kind, primary.value }
        }
    })

    if not created then return nil end
    return { id = accountId, status = 'active' }
end

function UP.IdentityRepository.attach(accountId, identifiers)
    local queries = {}
    for _, identifier in ipairs(identifiers) do
        queries[#queries + 1] = {
            query = [[
            INSERT INTO up_core_account_identifiers (account_id, provider, identifier)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE
                account_id = IF(account_id = VALUES(account_id), account_id, NULL),
                last_seen_at = CURRENT_TIMESTAMP(6)
            ]],
            values = { accountId, identifier.kind, identifier.value }
        }
    end
    return MySQL.transaction.await(queries) == true
end

function UP.IdentityRepository.auditConflict(matches, identifiers, reason)
    local accountIds = {}
    local unique = {}
    for _, match in ipairs(matches) do
        if not unique[match.accountId] then
            unique[match.accountId] = true
            accountIds[#accountIds + 1] = match.accountId
        end
    end

    MySQL.insert.await([[
        INSERT INTO up_core_audit_log (action, subject_type, metadata)
        VALUES ('identity.conflict', 'account', ?)
    ]], {
        json.encode({
            reason = reason,
            providers = UP.Identifiers.providers(identifiers),
            matchedAccountIds = accountIds
        })
    })
end
