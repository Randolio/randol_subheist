if not lib.checkDependency('ND_Core', '2.0.0') then return end

local NDCore = exports['ND_Core']

function GetPlayer(id)
    return NDCore:getPlayer(id)
end

function GetCharacterId(Player)
    return Player.id
end

function GetCharacterName(Player)
    return Player.fullname
end

function AddMoney(Player, moneyType, amount)
    Player.addMoney(moneyType, amount)
end

function itemCount(Player, item, amount)
    return exports.ox_inventory:GetItemCount(Player.source, item)
end

function AddItem(Player, item, amount)
    exports.ox_inventory:AddItem(Player.source, item, amount)
end

function DoNotification(src, text, nType)
    TriggerClientEvent('ox_lib:notify', src, { type = nType, description = text })
end