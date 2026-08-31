UP.Permissions = {}

function UP.Permissions.has(source, permission)
    if type(permission) ~= 'string' or permission == '' then return false end

    if IsPlayerAceAllowed(source, permission) then return true end

    local player = UP.players[source]
    if not player or not player.characterId then return false end

    local count = MySQL.scalar.await([[
        SELECT COUNT(*)
          FROM up_core_character_roles cr
          JOIN up_core_role_permissions rp ON rp.role_name = cr.role_name
         WHERE cr.character_id = ? AND rp.permission = ?
    ]], { player.characterId, permission })

    return tonumber(count) > 0
end
