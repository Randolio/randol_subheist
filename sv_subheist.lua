local Server = lib.require('sv_config')
local onCooldown = {}
local dbRecords = {}
local players = {}

local function setBucket(src, bool)
    local bucket = bool and src or 0
    Player(src).state:set('instance', bucket, true)
    SetPlayerRoutingBucket(src, bucket)
end

local function sortTable(tbl)
    table.sort(tbl, function(a, b)
        local aMinutes, aSeconds = a.record:match('(%d+):(%d+)')
        local bMinutes, bSeconds = b.record:match('(%d+):(%d+)')
        
        aMinutes, aSeconds, bMinutes, bSeconds = tonumber(aMinutes), tonumber(aSeconds), tonumber(bMinutes), tonumber(bSeconds)
        
        return (aMinutes == bMinutes and aSeconds < bSeconds) or aMinutes < bMinutes
    end)
end

local function individualCooldown(src, cid)
    setBucket(src, true)
    onCooldown[cid] = true
    SetTimeout(Server.PlayerCooldown * 60000, function()
        onCooldown[cid] = nil
    end)
end

local function hasBlacklistedWeapon(player)
    for i = 1, #Server.BlacklistedGuns do
        local gun = Server.BlacklistedGuns[i]
        if itemCount(player, gun) > 0 then
            return true
        end
    end
    return false
end

local function updateRecord(mins, secs, name)
    for _, data in ipairs(dbRecords) do
        if data.name == name then
            local minutes, seconds = tonumber(mins) or 0, tonumber(secs) or 0
            data.record = ('%02d:%02d'):format(minutes, seconds)
            break
        end
    end
    sortTable(dbRecords)
end

local function setRecord(source, timer)
    local src = source
    local player = GetPlayer(src)
    local cid = GetCharacterId(player)
    local name = GetCharacterName(player)
    
    local minutes, seconds = string.match(timer, '(%d+):(%d+)')
    
    if minutes and seconds then
        minutes = tonumber(minutes)
        seconds = tonumber(seconds)
        
        local formattedSeconds = ('%02d'):format(seconds)
        
        local result = MySQL.query.await('SELECT * FROM subheist WHERE citizenid = ?', {cid})
        
        if not result[1] then 
            MySQL.insert.await('INSERT INTO subheist (citizenid, name, minutes, seconds) VALUES (?, ?, ?, ?)', {cid, name, minutes, formattedSeconds})
            local minutes = tonumber(minutes) or 0
            local seconds = tonumber(formattedSeconds) or 0
            local totalSeconds = minutes * 60 + seconds
            dbRecords[#dbRecords + 1] = { name = name, record = ('%02d:%02d'):format(minutes, seconds) }
            Wait(100)
            sortTable(dbRecords)
        else
            local existingMinutes = tonumber(result[1].minutes)
            local existingSeconds = tonumber(result[1].seconds)
            
            if minutes < existingMinutes or (minutes == existingMinutes and seconds < existingSeconds) then
                MySQL.update.await('UPDATE subheist SET minutes = ?, seconds = ? WHERE citizenid = ?', {minutes, formattedSeconds, cid})
                updateRecord(minutes, formattedSeconds, name)
            end
        end
    end
end

local function getMyRecord(cid)
    for _, data in ipairs(dbRecords) do
        if data.cid == cid then
            return true, data.record
        end
    end
    return false
end

lib.callback.register('randol_subheist:server:getBoard', function(source)
    local leaderboard = {}
    if dbRecords and next(dbRecords) then
        local numRecords = math.min(#dbRecords, 5)
        for i = 1, numRecords do
            leaderboard[#leaderboard+1] = { 
                name = dbRecords[i].name, 
                record = dbRecords[i].record, 
            }
        end
        sortTable(leaderboard)
    end
    return leaderboard
end)

lib.callback.register('randol_subheist:server:canStart', function(source)
    local src = source
    local player = GetPlayer(src)
    local cid = GetCharacterId(player)

    if not player or players[src] then return false end

    if onCooldown[cid] then
        DoNotification(src, 'You recently hit a submarine heist. You must wait a little while.', 'error')
        return false
    end

    if hasBlacklistedWeapon(player) then
        DoNotification(src, 'You have forbidden weapons on you.', 'error')
        return false
    end

    players[src] = true
    individualCooldown(src, cid)

    return true, Server.HackLocation
end)

lib.callback.register('randol_subheist:server:exitSubmarine', function(source, success, timer)
    if not players[source] then return false end

    local src = source
    local player = GetPlayer(src)
    
    if not player then return false end

    if success and timer then
        local pos = GetEntityCoords(GetPlayerPed(src))
        if #(pos - Server.HackLocation) > 5.0 then return false end
        setRecord(src, timer)
        Server.GiveRewards(player, src)
    end

    setBucket(src, false)
    players[src] = nil
    return true
end)

lib.addCommand('subrecord', {
    help = 'Get your sub heist record.',
}, function(source, args)
    local src = source
    local player = GetPlayer(src)
    local cid = GetCharacterId(player)
    local found, record = getMyRecord(cid)
    if not found then
        return DoNotification(src, 'Cannot find a record time for you.', 'error')
    end
    DoNotification(src, ('Personal Record: %s'):format(record))
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    MySQL.query([=[
        CREATE TABLE IF NOT EXISTS `subheist` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(255) NOT NULL COLLATE 'utf8mb3_general_ci',
            `name` VARCHAR(255) NOT NULL COLLATE 'utf8mb3_general_ci',
            `minutes` INT(11) NOT NULL,
            `seconds` VARCHAR(2) NOT NULL COLLATE 'utf8mb3_general_ci',
            PRIMARY KEY (`id`) USING BTREE
        ) COLLATE='utf8mb3_general_ci' ENGINE=InnoDB AUTO_INCREMENT=5
    ;]=])
    Wait(2000)
    local result = MySQL.query.await('SELECT * FROM subheist')
    if result then
        for _, v in ipairs(result) do
            local minutes = tonumber(v.minutes) or 0
            local seconds = tonumber(v.seconds) or 0
            dbRecords[#dbRecords + 1] = {
                name = v.name,
                cid = v.citizenid,
                record = ('%02d:%02d'):format(minutes, seconds),
            }
        end
        sortTable(dbRecords)
    end
end)