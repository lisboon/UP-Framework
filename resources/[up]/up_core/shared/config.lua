UPConfig = {
    contractVersion = 1,
    schemaVersion = 2,
    callbackTimeoutMs = 10000,
    callbackRateLimit = {
        capacity = 12,
        refillPerSecond = 4
    },
    connection = {
        authorizationTtlSeconds = 30
    },
    character = {
        firstNameMinLength = 2,
        firstNameMaxLength = 32,
        lastNameMinLength = 2,
        lastNameMaxLength = 32,
        maxPerAccount = 3,
        minimumAge = 18,
        maximumAge = 90
    },
    spawn = {
        attemptTimeoutMs = 15000,
        providers = {
            spawnmanager = {
                attestation = {
                    mode = 'position',
                    stabilizationMs = 750,
                    tolerance = 5.0
                }
            }
        },
        locations = {
            {
                id = 'airport',
                label = 'Aeroporto Internacional de Los Santos',
                provider = 'spawnmanager',
                coordinates = {
                    x = -1037.72,
                    y = -2737.87,
                    z = 20.17,
                    heading = 329.0
                }
            }
        }
    }
}
