local cfg = module("cfg/player_state")
local log_config = module("servercfg/cfg_webhooks")
local lang = vRP.lang

-- client -> server events
AddEventHandler("vRP:playerSpawn", function(user_id, source, first_spawn)
    Debug.pbegin("playerSpawned_player_state")
    local player = source
    local data = vRP.getUserDataTable(user_id)
    local tmpdata = vRP.getUserTmpTable(user_id)
    local playername = GetPlayerName(player)
    webhook = log_config.spawnlog
    if webhook ~= nil then
        if webhook ~= 'none' then
            PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({username = "Dunko vRP Logs", embeds = {{["color"] = "15158332", ["title"] = playername .. ' Has Spawned In The Server', ["description"] = 'His Perm-ID: **' .. user_id .. '\n** His Source Id: **' .. player .. '**', ["footer"] = {["text"] = "Time - "..os.date("%x %X %p"),}}}}), { ["Content-Type"] = "application/json" })
        end
    end


    if first_spawn then -- first spawn
        -- cascade load customization then weapons
        if data.customization == nil then
            data.customization = cfg.default_customization
        end

        if data.position == nil and cfg.spawn_enabled then
            local x = cfg.spawn_position[1] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            local y = cfg.spawn_position[2] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            local z = cfg.spawn_position[3] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            data.position = {
                x = x,
                y = y,
                z = z
            }
        end

        if data.position ~= nil then -- teleport to saved pos
            vRPclient.teleport(source, {data.position.x, data.position.y, data.position.z})
        end

        if data.customization ~= nil then
            vRPclient.setCustomization(source, {data.customization},
                function() -- delayed weapons/health, because model respawn
                    if data.weapons ~= nil then -- load saved weapons
                        vRPclient.giveWeapons(source, {data.weapons, true})

                        if data.health ~= nil then -- set health
                            vRPclient.setHealth(source, {data.health})
                            SetTimeout(5000, function() -- check coma, kill if in coma
                                vRPclient.isInComa(player, {}, function(in_coma)
                                    vRPclient.killComa(player, {})
                                end)
                            end)
                        end
                        
                        if data.armour ~= nil then
                            vRPclient.setArmour(source, {data.armour})
                        end
                    end
                end)
        else
            if data.weapons ~= nil then -- load saved weapons
                vRPclient.giveWeapons(source, {data.weapons, true})
            end

            if data.health ~= nil then
                vRPclient.setHealth(source, {data.health})
            end
        end

        -- notify last login
        SetTimeout(15000, function()
            vRPclient.notify(player, {lang.common.welcome({tmpdata.last_login})})
        end)
    else -- not first spawn (player died), don't load weapons, empty wallet, empty inventory
        vRP.setHunger(user_id, 0)
        vRP.setThirst(user_id, 0)

        if cfg.clear_phone_directory_on_death then
            data.phone_directory = {} -- clear phone directory after death
        end

        if cfg.lose_aptitudes_on_death then
            data.gaptitudes = {} -- clear aptitudes after death
        end

        if vRPConfig.LoseItemsOnDeath then 
            vRP.clearInventory(user_id) 
        end
        
        vRP.setMoney(user_id, 0)

        -- disable handcuff
        vRPclient.setHandcuffed(player, {false})

        if cfg.spawn_enabled then -- respawn (CREATED SPAWN_DEATH)
            local x = cfg.spawn_death[1] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            local y = cfg.spawn_death[2] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            local z = cfg.spawn_death[3] + math.random() * cfg.spawn_radius * 2 - cfg.spawn_radius
            data.position = {
                x = x,
                y = y,
                z = z
            }
            vRPclient.teleport(source, {x, y, z})
        end

        -- load character customization
        if data.customization ~= nil then
            vRPclient.setCustomization(source, {data.customization})
        end
    end
    Debug.pend()
end)

-- updates

function tvRP.updatePos(x, y, z)
    local user_id = vRP.getUserId(source)
    if user_id ~= nil then
        local data = vRP.getUserDataTable(user_id)
        local tmp = vRP.getUserTmpTable(user_id)
        if data ~= nil and (tmp == nil or tmp.home_stype == nil) then -- don't save position if inside home slot
            data.position = {
                x = tonumber(x),
                y = tonumber(y),
                z = tonumber(z)
            }
        end
    end
end

function tvRP.updateWeapons(weapons)
    local user_id = vRP.getUserId(source)
    if user_id ~= nil then
        local data = vRP.getUserDataTable(user_id)
        if data ~= nil then
            data.weapons = weapons
        end
    end
end

function tvRP.updateCustomization(customization)
    local user_id = vRP.getUserId(source)
    if user_id ~= nil then
        local data = vRP.getUserDataTable(user_id)
        if data ~= nil then
            data.customization = customization
        end
    end
end

function tvRP.updateHealth(health)
    local user_id = vRP.getUserId(source)
    if user_id ~= nil then
        local data = vRP.getUserDataTable(user_id)
        if data ~= nil then
            data.health = health
        end
    end
end

function tvRP.updateArmour(armour)
    local user_id = vRP.getUserId(source)
    if user_id ~= nil then
        local data = vRP.getUserDataTable(user_id)
        if data ~= nil then
            data.armour = armour
        end
    end
end

local isStoring = {}
function tvRP.StoreWeaponsDead()
    local player = source 
    local user_id = vRP.getUserId(player)
	vRPclient.getWeapons(player,{},function(weapons)
        if not isStoring[player] then
            isStoring[player] = true
            vRPclient.giveWeapons(player,{{},true}, function(removedwep)
                for k,v in pairs(weapons) do
                    vRP.giveInventoryItem(user_id, "wbody|"..k, 1, true)
                    if v.ammo > 0 then
                        vRP.giveInventoryItem(user_id, "wammo|"..k, v.ammo, true)
                    end
                end
                vRPclient.notify(player,{"~g~Weapons Stored"})
                SetTimeout(10000,function()
                    isStoring[player] = nil 
                end)
            end)
        else
            vRPclient.notify(player,{"~o~Your weapons are already being stored hmm..."})
        end
	end)
end