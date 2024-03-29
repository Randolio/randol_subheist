local Config = lib.require('config')
local subGunners = {}
local isTimerActive = false
local startTime = 0
local elapsedTime = 0
local tempTimer, formattedTime, deltaTime, hackSpot, subStart, BLOCKING_DOOR, SUB_ALARM

local function drawTime(text, font, x, y, scale, r, g, b, a)
    SetTextFont(font)
    SetTextScale(scale, scale)
    SetTextColour(r, g, b, a)
    SetTextOutline()
    SetTextCentre(2)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function setAmbience(bool)
    if bool then
        while not RequestAmbientAudioBank('SCRIPT/ALARM_KLAXON_03', false) do Wait(0) end
        SUB_ALARM = GetSoundId()
        PlaySoundFromCoord(SUB_ALARM, 'Klaxon_03', Config.MiddlePoint.x, Config.MiddlePoint.y, Config.MiddlePoint.z, 'ALARMS_SOUNDSET', 0, 1.0, 0)
        if Config.EnableShake then
            ShakeGameplayCam('FAMILY5_DRUG_TRIP_SHAKE', 0.2)
        end
    else
        StopSound(SUB_ALARM)
        ReleaseSoundId(SUB_ALARM)
        ReleaseNamedScriptAudioBank('SCRIPT/ALARM_KLAXON_03')
        SUB_ALARM = nil
        if Config.EnableShake then
            StopGameplayCamShaking(true)
        end
    end
end

local function initTeleport(coords)
    local x, y, z, w = coords.x, coords.y, coords.z, coords.w

    RequestCollisionAtCoord(x, y, z)
    NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)

    local sceneLoadTimer = GetGameTimer()
    while not IsNewLoadSceneLoaded() do
        if GetGameTimer() - sceneLoadTimer > 2000 then break end
        Wait(0)
    end

    SetEntityCoords(cache.ped, x, y, z)
    sceneLoadTimer = GetGameTimer()

    while not HasCollisionLoadedAroundEntity(cache.ped) do
        if GetGameTimer() - sceneLoadTimer > 2000 then break end
        Wait(0)
    end

    local foundNewZ, newZ = GetGroundZFor_3dCoord(x, y, z, 0, 0)
    if foundNewZ and newZ > 0 then z = newZ end

    SetEntityCoords(cache.ped, x, y, z)
    SetEntityHeading(cache.ped, w)
    NewLoadSceneStop()
    return true
end

local function toggleBlockingDoor(bool)
    if bool then
        if DoesEntityExist(BLOCKING_DOOR) then return end
        local model = `xm_int_lev_sub_doorr`
        lib.requestModel(model, 5000)
        BLOCKING_DOOR = CreateObject(model, 512.06, 4883.1, -63.59, false, false, false)
        FreezeEntityPosition(BLOCKING_DOOR, true)
        SetEntityAsMissionEntity(BLOCKING_DOOR, true, true)
        SetModelAsNoLongerNeeded(model)
    else
        if DoesEntityExist(BLOCKING_DOOR) then
            DeleteEntity(BLOCKING_DOOR)
            BLOCKING_DOOR = nil
        end
    end
end

local function startTimer()
    if isTimerActive then return end
    startTime = GetGameTimer()
    isTimerActive = true

    CreateThread(function()
        while isTimerActive do
            Wait(0)
            deltaTime = GetGameTimer() - startTime
            formattedTime = ('%.2d:%.2d'):format(math.floor((deltaTime % 3600000) / 60000), math.floor((deltaTime % 60000) / 1000))

            drawTime(('Subheist Timer: %s'):format(formattedTime), 4, 0.5, 0.88, 0.65, 255, 255, 255, 220)
        end
        tempTimer = formattedTime
        deltaTime = nil
        formattedTime = nil
        startTime = 0
        elapsedTime = 0
    end)
    
    setAmbience(true)
end

local function deleteAngryDudes()
    for i = 1, #subGunners do
        if DoesEntityExist(subGunners[i]) then
            DeleteEntity(subGunners[i])
        end
    end
end

local function createAngryDudes()
    local model = `s_m_m_pilot_02`
    lib.requestModel(model, 2000)

    for i = 1, #Config.AggroPeds do
        local coords = Config.AggroPeds[i]
        local subPeds = CreatePed(24, model, coords.x, coords.y, coords.z, coords.w, false, false)
        SetEntityAsMissionEntity(subPeds, true, true)
        SetPedRelationshipGroupHash(subPeds, `HATES_PLAYER`)
        SetPedCanRagdoll(subPeds, false)
        SetPedAccuracy(subPeds, Config.PedAccuracy)
        SetEntityMaxHealth(subPeds, Config.PedHealth)
        SetEntityHealth(subPeds, Config.PedHealth)
        SetPedCombatAttributes(subPeds, 46, true)
        SetPedDropsWeaponsWhenDead(subPeds, false)
        SetPedFleeAttributes(subPeds, 0, false)
        GiveWeaponToPed(subPeds, Config.PedWeapon, 999, false, false)
        SetCanAttackFriendly(subPeds, false, true)
        SetPedSuffersCriticalHits(subPeds, false)
        TaskCombatPed(subPeds, cache.ped, 0, 16)
        SetPedCombatMovement(subPeds, 1)
        SetPedCombatAbility(subPeds, 2)
        SetPedAsCop(subPeds, true)
        subGunners[#subGunners + 1] = subPeds
    end

    SetModelAsNoLongerNeeded(model)
    exports['qb-target']:AddCircleZone('hackSpot', vec3(hackSpot.x, hackSpot.y, hackSpot.z), 0.6,{
        name = 'hackSpot', 
        debugPoly = false, 
        useZ=true, 
    }, { options = {
        { 
            icon = 'fa-solid fa-server', 
            label = 'Hack',
            action = exitSubmarine,
        },}, 
        distance = 1.5 
    })
end

local function resetEverything()
    isTimerActive = false
    deleteAngryDudes()
    if hackSpot then
        exports['qb-target']:RemoveZone('hackSpot')
        hackSpot = nil
    end
    toggleBlockingDoor(false)
    setAmbience(false)
    LocalPlayer.state.heistActive = false
end

local function enterSubmarine()
    LocalPlayer.state.heistActive = true
    DoScreenFadeOut(500) while not IsScreenFadedOut() do Wait(10) end
    initTeleport(Config.SubmarineSpawn)
    toggleBlockingDoor(true)
    createAngryDudes()
    DoScreenFadeIn(1000)
    startTimer()
end

local function spawnPed()
    if DoesEntityExist(START_PED) then return end

    lib.requestModel(Config.Ped.model, 1000)
    START_PED = CreatePed(0, Config.Ped.model, Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z-1.0, Config.Ped.coords.w, false, false)
    SetEntityAsMissionEntity(START_PED)
    SetPedFleeAttributes(START_PED, 0, 0)
    SetBlockingOfNonTemporaryEvents(START_PED, true)
    SetEntityInvincible(START_PED, true)
    FreezeEntityPosition(START_PED, true)
    TaskStartScenarioInPlace(START_PED, Config.Ped.scenario, 0, false)
    SetModelAsNoLongerNeeded(Config.Ped.model)

    exports['qb-target']:AddTargetEntity(START_PED, { 
        options = {
            {
                num = 1,
                icon = 'fa-solid fa-medal',
                label = 'View Leaderboard',
                action = function()
                    local leaderBoard = {} 
                    local data = lib.callback.await('randol_subheist:server:getBoard', false)
                    for k, v in pairs(data) do
                        leaderBoard[#leaderBoard + 1] = {
                            title = ('#%s - %s'):format(k, v.name),
                            icon = 'fa-solid fa-medal',
                            description = ('Time: %s'):format(v.record),
                        }
                    end
                    lib.registerContext({ id = 'heist_ldb', title = 'Leaderboard', options = leaderBoard })
                    lib.showContext('heist_ldb')
                end,
            },
            {
                num = 2,
                icon = 'fa-solid fa-person-rifle',
                label = 'Start Heist',
                action = function()
                    local success, spot = lib.callback.await('randol_subheist:server:canStart', false)
                    if not success then return end
                    hackSpot = spot
                    enterSubmarine()
                end,
                canInteract = function()
                    return not LocalPlayer.state.heistActive
                end,
            },
        }, 
        distance = 1.5, 
    })
end

local function yeetPed()
    if not DoesEntityExist(START_PED) then return end
    exports['qb-target']:RemoveTargetEntity(START_PED, {'View Leaderboard', 'Start Heist'})
    DeleteEntity(START_PED)
    START_PED = nil
end

local function createStartPoint()
    subStart = lib.points.new({
        coords = vec3(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z),
        distance = 50,
        onEnter = spawnPed,
        onExit = yeetPed,
    })
end

local function handleDeath()
    while not isPlyDead() do Wait(500) end
    resetEverything()
    tempTimer = nil
    DoScreenFadeOut(100) while not IsScreenFadedOut() do Wait(10) end
    local canLeave = lib.callback.await('randol_subheist:server:exitSubmarine', false, false, false)
    if canLeave then
        initTeleport(Config.FailedPosition)
        DoNotification('You were incapacitated and bundled out of the submarine.', 'error', 5000)
        DoScreenFadeIn(1000)
    end
end

function exitSubmarine()
    if not LocalPlayer.state.heistActive then return end

    exports['qb-target']:RemoveZone('hackSpot')
    hackSpot = nil

    local success, position, message

    exports['ps-ui']:Scrambler(function(result)
        success = result
    end, Config.HackType, Config.HackSeconds, 0)

    -- Depending on how your minigame gets called above, you'll have to adjust. A different example is bl_ui.
    -- You'd switch the above export to: success = exports.bl_ui:CircleProgress(circles, speed)

    while success == nil do -- This is a scuffy way to support the way different minigames get called due to yielding and the way I'm formatting this. Leave this here.
        Wait(100)
    end

    resetEverything()
    Wait(100)
    position = success and Config.SuccessPosition or Config.FailedPosition
    message = success and ('You made it out of the submarine. Time: %s'):format(tempTimer) or 'You failed the hack.'

    DoScreenFadeOut(100) while not IsScreenFadedOut() do Wait(10) end
    local canLeave = lib.callback.await('randol_subheist:server:exitSubmarine', false, success, tempTimer)

    if canLeave then
        initTeleport(position)
        tempTimer = nil
        Wait(2000)
        DoNotification(message, success and 'success' or 'error', 5000)
        DoScreenFadeIn(500)
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
        SetPedToRagdollWithFall(cache.ped, 3500, 4500, 1, GetEntityForwardVector(cache.ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    end
end

function OnPlayerLoaded()
    SetTimeout(2000, function()
        createStartPoint()
    end)
end

function OnPlayerUnload()
    yeetPed()
    if subStart then subStart:remove() subStart = nil end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        OnPlayerUnload()
    end
end)

AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim, attacker, victimDied, weapon = data[1], data[2], data[4], data[7]
        if not IsPedAPlayer(victim) then return end
        if victimDied and NetworkGetPlayerIndexFromPed(victim) == cache.playerId and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim)) and LocalPlayer.state.heistActive then
            handleDeath()
        end
    end
end)

-- This is for people who might crash/quit during the heist. If they spawn back in, they'll be immediately teleported out.
local middlePoint = lib.points.new({
    coords = vec3(Config.MiddlePoint.x, Config.MiddlePoint.y, Config.MiddlePoint.z),
    distance = 80,
    onEnter = function()
        if LocalPlayer.state.heistActive then return end
        initTeleport(Config.FailedPosition)
        DoNotification('You were inside the submarine whilst not actively attempting the heist so you were moved.', 'error', 5000)
    end,
})

lib.onCache('ped', function(newPed) -- To fix an exploit where if your ped changes (/reloadskin or /refreshskin) etc, they'd stop combatting you.
    if newPed then
        if not LocalPlayer.state.heistActive then return end
        if subGunners and next(subGunners) then
            for i = 1, #subGunners do
                if not IsEntityDead(subGunners[i]) then
                    TaskCombatPed(subGunners[i], newPed, 0, 16)
                end
            end
        end
    end
end)
