return {
    BlacklistedGuns = { -- Weapons a player is not allowed to use. It will search their inventory for these weapons so make sure you add them correctly.
        'WEAPON_SNIPERRIFLE',
        'WEAPON_HEAVYSNIPER',
    },
    PlayerCooldown = 60, -- minutes before a individual player can attempt another submarine heist.
    HackLocation = vec3(515.79, 4835.66, -68.99),
    GiveRewards = function(player, src)
        if not player then return end
        -- Example reward
        local rnd = math.random(15000, 25000)
        AddMoney(player, 'cash', rnd)
        DoNotification(src, ('You were rewarded $%s for completing the submarine heist.'):format(rnd), 'success', 5000)
    end,
}
