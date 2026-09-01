UPEntryConfig = {
    bucketBase = 100000,
    bucketLockdownMode = 'strict',
    populationEnabled = false,
    stateRecovery = {
        enabled = true,
        retryDelaysMs = { 0, 250, 750, 1750 }
    },
    presentation = {
        model = 'mp_m_freemode_01',
        modelTimeoutMs = 5000,
        timecycle = 'MP_corona_tournament',
        timecycleStrength = 0.35,
        ped = {
            x = 402.86,
            y = -996.41,
            z = -99.0,
            heading = 180.0
        },
        camera = {
            x = 402.86,
            y = -999.15,
            z = -98.35,
            fov = 34.0
        }
    }
}
