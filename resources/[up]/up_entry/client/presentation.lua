UPEntryPresentation = UPEntryPresentation or {}

local scene = UPEntryConfig.presentation
assert(type(scene) == 'table', 'entry presentation config is required')
assert(type(scene.model) == 'string' and scene.model ~= '', 'entry presentation model is required')
assert(type(scene.modelTimeoutMs) == 'number' and scene.modelTimeoutMs > 0, 'entry presentation model timeout must be positive')
assert(type(scene.ped) == 'table' and type(scene.camera) == 'table', 'entry presentation coordinates are required')
assert(type(scene.timecycle) == 'string' and scene.timecycle ~= '', 'entry presentation timecycle is required')
assert(type(scene.timecycleStrength) == 'number' and scene.timecycleStrength >= 0.0 and scene.timecycleStrength <= 1.0, 'entry presentation timecycle strength must be between zero and one')

for _, value in ipairs({ scene.ped.x, scene.ped.y, scene.ped.z, scene.ped.heading, scene.camera.x, scene.camera.y, scene.camera.z, scene.camera.fov }) do
    assert(type(value) == 'number', 'entry presentation coordinates must be numeric')
end

local camera
local previewPed
local generation = 0
local requestedPassport
local activeLocation

local function destroyScene()
    generation = generation + 1
    requestedPassport = nil
    activeLocation = nil

    if camera and DoesCamExist(camera) then
        SetCamActive(camera, false)
        DestroyCam(camera, false)
    end
    camera = nil

    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    previewPed = nil

    RenderScriptCams(false, true, 450, true, true)
    ClearFocus()
    ClearTimecycleModifier()
end

local function applyPreviewIdentity(passport)
    if not previewPed or not DoesEntityExist(previewPed) then return false end
    requestedPassport = passport
    SetEntityAlpha(previewPed, 0, false)
    SetEntityHeading(previewPed, scene.ped.heading)
    ResetEntityAlpha(previewPed)
    return true
end

local function createScene(token)
    local model = GetHashKey(scene.model)
    RequestModel(model)
    local deadline = GetGameTimer() + scene.modelTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if token ~= generation or not HasModelLoaded(model) then return end

    SetFocusPosAndVel(scene.ped.x, scene.ped.y, scene.ped.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(scene.ped.x, scene.ped.y, scene.ped.z)
    previewPed = CreatePed(4, model, scene.ped.x, scene.ped.y, scene.ped.z, scene.ped.heading, false, false)
    SetModelAsNoLongerNeeded(model)
    if not previewPed or previewPed == 0 then return end

    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetPedCanRagdoll(previewPed, false)

    camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camera, scene.camera.x, scene.camera.y, scene.camera.z)
    SetCamFov(camera, scene.camera.fov)
    PointCamAtEntity(camera, previewPed, 0.0, 0.0, 0.62, true)
    SetCamActive(camera, true)
    SetTimecycleModifier(scene.timecycle)
    SetTimecycleModifierStrength(scene.timecycleStrength)
    RenderScriptCams(true, true, 700, true, true)

    if requestedPassport then applyPreviewIdentity(requestedPassport) end
end

function UPEntryPresentation.start()
    destroyScene()
    local token = generation
    CreateThread(function() createScene(token) end)
end

function UPEntryPresentation.preview(passport)
    if not passport or passport < 1 or passport ~= math.floor(passport) then return false end
    requestedPassport = passport
    if not previewPed then return true end
    return applyPreviewIdentity(passport)
end

local function validLocation(location)
    local coordinates = type(location) == 'table' and location.coordinates
    return type(location.id) == 'string'
        and type(coordinates) == 'table'
        and type(coordinates.x) == 'number'
        and type(coordinates.y) == 'number'
        and type(coordinates.z) == 'number'
        and type(coordinates.heading) == 'number'
end

function UPEntryPresentation.previewLocation(location, immediate)
    if not validLocation(location) then return false end
    activeLocation = location
    local coordinates = location.coordinates

    if previewPed and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    previewPed = nil

    if not camera or not DoesCamExist(camera) then camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetFocusPosAndVel(coordinates.x, coordinates.y, coordinates.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(coordinates.x, coordinates.y, coordinates.z)

    local duration = immediate and 0 or 900
    SetCamParams(camera, coordinates.x, coordinates.y, coordinates.z + 240.0, -88.0, 0.0, coordinates.heading, 48.0, duration, 0, 0, 2)
    PointCamAtCoord(camera, coordinates.x, coordinates.y, coordinates.z)
    SetCamActive(camera, true)
    RenderScriptCams(true, true, duration, true, true)
    return true
end

function UPEntryPresentation.commitLocation(location)
    if not validLocation(location) then return false end
    activeLocation = location
    DoScreenFadeOut(350)
    return true
end

function UPEntryPresentation.resumeLocation()
    if not activeLocation then return false end
    UPEntryPresentation.previewLocation(activeLocation, true)
    DoScreenFadeIn(450)
    return true
end

function UPEntryPresentation.stop()
    destroyScene()
end

RegisterNetEvent(UPEntryContracts.events.entered, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    UPEntryPresentation.start()
end)

RegisterNetEvent(UPEntryContracts.events.left, function(envelope)
    if type(envelope) ~= 'table' or envelope.version ~= UPEntryContracts.version then return end
    UPEntryPresentation.stop()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    UPEntryPresentation.stop()
end)
