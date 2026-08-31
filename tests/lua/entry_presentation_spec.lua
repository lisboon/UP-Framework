UPEntryContracts = {
    version = 1,
    events = { entered = 'entered', left = 'left' }
}

UPEntryConfig = {
    presentation = {
        model = 'mp_m_freemode_01',
        modelTimeoutMs = 5000,
        timecycle = 'test_filter',
        timecycleStrength = 0.35,
        ped = { x = 1.0, y = 2.0, z = 3.0, heading = 180.0 },
        camera = { x = 4.0, y = 5.0, z = 6.0, fov = 34.0 }
    }
}

local netHandlers = {}
local handlers = {}
local calls = { rendered = {}, deleted = {} }
local entityExists = {}
local camExists = {}

function RegisterNetEvent(name, handler) netHandlers[name] = handler end
function AddEventHandler(name, handler) handlers[name] = handler end
function GetCurrentResourceName() return 'up_entry' end
function CreateThread(callback) callback() end
function GetHashKey() return 100 end
function RequestModel(model) calls.requestedModel = model end
function HasModelLoaded() return true end
function GetGameTimer() return 0 end
function Wait() end
function SetFocusPosAndVel(x, y, z) calls.focus = { x, y, z } end
function RequestCollisionAtCoord(x, y, z) calls.collision = { x, y, z } end
function CreatePed() entityExists[10] = true return 10 end
function SetModelAsNoLongerNeeded(model) calls.releasedModel = model end
function FreezeEntityPosition(entity, value) calls.frozen = { entity, value } end
function SetEntityInvincible(entity, value) calls.invincible = { entity, value } end
function SetBlockingOfNonTemporaryEvents() end
function SetPedCanRagdoll() end
function CreateCam() camExists[20] = true return 20 end
function SetCamCoord(_, x, y, z) calls.camCoord = { x, y, z } end
function SetCamFov(_, fov) calls.fov = fov end
function SetCamParams(_, x, y, z, pitch, _, heading, fov, duration) calls.camParams = { x, y, z, pitch, heading, fov, duration } end
function PointCamAtEntity(_, entity) calls.pointedAt = entity end
function PointCamAtCoord(_, x, y, z) calls.pointedAtCoord = { x, y, z } end
function SetCamActive(_, active) calls.camActive = active end
function SetTimecycleModifier(value) calls.timecycle = value end
function SetTimecycleModifierStrength(value) calls.timecycleStrength = value end
function RenderScriptCams(active) calls.rendered[#calls.rendered + 1] = active end
function DoesCamExist(cam) return camExists[cam] == true end
function DestroyCam(cam) camExists[cam] = nil end
function DoesEntityExist(entity) return entityExists[entity] == true end
function DeleteEntity(entity) entityExists[entity] = nil calls.deleted[#calls.deleted + 1] = entity end
function ClearFocus() calls.focusCleared = true end
function ClearTimecycleModifier() calls.timecycleCleared = true end
function SetEntityAlpha(_, alpha) calls.alpha = alpha end
function SetEntityHeading(_, heading) calls.heading = heading end
function ResetEntityAlpha() calls.alphaReset = true end
function DoScreenFadeOut(duration) calls.fadeOut = duration end
function DoScreenFadeIn(duration) calls.fadeIn = duration end

dofile('resources/[up]/up_entry/client/presentation.lua')

netHandlers.entered({ version = 1 })
assert(calls.requestedModel == 100)
assert(calls.focus[1] == 1.0 and calls.collision[3] == 3.0)
assert(calls.pointedAt == 10 and calls.fov == 34.0)
assert(calls.timecycle == 'test_filter' and calls.timecycleStrength == 0.35)
assert(calls.rendered[#calls.rendered] == true)

assert(UPEntryPresentation.preview(1000) == true)
assert(calls.heading == 180.0 and calls.alphaReset == true)
assert(UPEntryPresentation.preview(0) == false)

local location = { id = 'airport', coordinates = { x = 10.0, y = 20.0, z = 30.0, heading = 90.0 } }
assert(UPEntryPresentation.previewLocation(location, false) == true)
assert(calls.camParams[1] == 10.0 and calls.camParams[3] == 270.0 and calls.camParams[7] == 900)
assert(calls.pointedAtCoord[2] == 20.0)
assert(UPEntryPresentation.commitLocation(location) == true and calls.fadeOut == 350)
assert(UPEntryPresentation.resumeLocation() == true and calls.fadeIn == 450)

netHandlers.left({ version = 1 })
assert(entityExists[10] == nil and camExists[20] == nil)
assert(calls.rendered[#calls.rendered] == false)
assert(calls.focusCleared == true and calls.timecycleCleared == true)

netHandlers.entered({ version = 1 })
handlers.onClientResourceStop('up_entry')
assert(entityExists[10] == nil and camExists[20] == nil)
