UPConfig = {
    contractVersion = 1,
    schemaVersion = 2,
    callbackTimeoutMs = 10000,
    callbackRateLimit = {
        capacity = 12,
        refillPerSecond = 4
    },
    character = {
        firstNameMinLength = 2,
        firstNameMaxLength = 32,
        lastNameMinLength = 2,
        lastNameMaxLength = 32,
        maxPerAccount = 3,
        minimumAge = 18,
        maximumAge = 90
    }
}
