local success, msg = lib.checkDependency('oxmysql', '2.7.3')

if success then
    success, msg = lib.checkDependency('ox_lib', '3.10.0')
end

---@diagnostic disable-next-line: param-type-mismatch
if not success then return warn(msg) end


local cfg = lib.require('config.config')
local Vending = {}

MySQL.ready(function()
    Wait(1000) -- to not fetch old data from sql
    local success, error = pcall(MySQL.scalar.await, 'SELECT 1 FROM `uniq_vending`')

    if not success then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `uniq_vending` (
                `name` varchar(50) DEFAULT NULL,
                `data` longtext DEFAULT NULL,
                `shop` longtext DEFAULT '[]',
                `balance` int(11) DEFAULT 0,
                UNIQUE KEY `name` (`name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])
    end

    Wait(50)

    local result = MySQL.query.await('SELECT * FROM `uniq_vending`')

    if result[1] then
        for k,v in pairs(result) do
            local data = json.decode(v.data)
            local shop = json.decode(v.shop)

            Vending[v.name] = data
            Vending[v.name].shop = shop
            Vending[v.name].balance = v.balance
        end
    end
end)

lib.callback.register('uniq_vending:fetchVendings', function(source)
    return Vending
end)

lib.addCommand('addvending', {
    help = L('commands.addvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}

    local players = GetAllPlayers()
    
    if IsQBCore() then
        for k,v in pairs(players) do
            options[#options + 1] = { label = ('%s | %s'):format(v.PlayerData.name, v.PlayerData.source), value = v.PlayerData.citizenid, id = v.PlayerData.source}
        end
    elseif IsESX() then
        for k,v in pairs(players) do
            options[#options + 1] = { label = ('%s | %s'):format(v.getName(), v.source), value = v.identifier, id = v.source }
        end
    end

    TriggerClientEvent('uniq_vending:startCreating', source, options)
end)


lib.addCommand('dellvending', {
    help = L('commands.dellvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}
    local count = 0

    for k,v in pairs(Vending) do
        count += 1
    end

    if count == 0 then
        return lib.notify(source, { description = L('notify.no_vendings'), type = 'error' })
    end

    for k,v in pairs(Vending) do
        options[#options + 1] = { label = v.name, value = v.name }
    end

    TriggerClientEvent('uniq_vending:client:dellvending', source, options)
end)


lib.addCommand('findvending', {
    help = L('commands.findvending'),
    restricted = 'group.admin'
}, function(source, args, raw)
    if source == 0 then return end
    local options = {}
    local count = 0

    for k,v in pairs(Vending) do
        count += 1
    end

    if count == 0 then
        return lib.notify(source, { description = L('notify.no_vendings'), type = 'error' })
    end

    for k,v in pairs(Vending) do
        options[#options + 1] = { label = v.name, value = v.name }
    end

    local cb = lib.callback.await('uniq_vending:choseVending', source, options)

    if cb then
        if Vending[cb] then
            local coords = Vending[cb].coords
            local ped = GetPlayerPed(source)
            SetEntityCoords(ped, coords.x, coords.y + 1, coords.z, false, false , false, false)
        end
    end
end)

RegisterNetEvent('uniq_vending:server:dellvending', function(shop)
    if Vending[shop] then
        MySQL.query('DELETE FROM `uniq_vending` WHERE `name` = ?', { shop })

        Vending[shop] = nil
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
    end
end)

RegisterNetEvent('uniq_vending:buyVending', function(name)
    local src = source

    if Vending[name] then
        if CanAfford(src, Vending[name].price) then

            if Vending[name].type == 'player' then
                local identifier = GetIdentifier(src)

                Vending[name].owner = identifier
            elseif Vending[name].type == 'job' then
                local job, grade = GetJob(src)

                Vending[name].owner = { [job] = grade }
            end

            MySQL.update('UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', {json.encode(Vending[name], {sort_keys = true}), name})
            TriggerClientEvent('uniq_vending:sync', -1, Vending, true)

            lib.notify(src, { description = L('notify.vending_bought'):format(Vending[name].name, Vending[name].price), type = 'success' })
        else
            lib.notify(src, { description = L('notify.not_enough_money'):format(Vending[name].price), type = 'error' })
        end
    end
end)

RegisterNetEvent('uniq_vending:sellVending', function(name)
    local src = source
    
    if Vending[name] then
        local price = math.floor(Vending[name].price * cfg.SellPertencage)

        exports.ox_inventory:AddItem(src, 'money', price)

        AddItem(src, 'money', price)
        Vending[name].owner = false

        MySQL.update('UPDATE `uniq_vending` SET `data` = ? WHERE `name` = ?', {json.encode(Vending[name], {sort_keys = true}), name})
        TriggerClientEvent('uniq_vending:sync', -1, Vending, true)
        lib.notify(src, { description = L('notify.vending_sold'):format(Vending[name].name, price), type = 'success' })
    end
end)

RegisterNetEvent('uniq_vending:createVending', function(data)
    local src = source

    -- for retards
    MySQL.insert('INSERT INTO `uniq_vending` (name, data, balance) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), balance = VALUES(balance)', { data.name, json.encode(data, {sort_keys = true}), 0 })
    
    lib.notify(src, { description = L('notify.vending_created'):format(data.name, data.price), type = 'success' })

    Vending[data.name] = data

    Vending[data.name].shop = {}
    Vending[data.name].balance = 0

    TriggerClientEvent('uniq_vending:sync', -1, Vending, false)
end)


lib.callback.register('uniq_vending:GetItems', function(source, name)
    if Vending[name] then
        return Vending[name].shop
    end

    return false
end)

lib.callback.register('uniq_vending:GetPlayerInv', function(source)
    local items = GetInvItems(source)
    local options = {}

    for k,v in pairs(items) do
        options[#options + 1] = { label = ('%s | Count: %s'):format(v.label, v.amount or v.count), value = v.name }
    end

    return options
end)


RegisterNetEvent('uniq_vending:addStockItems', function(data)
    local src = source

    if Vending[data.shop] then
        if Vending[data.shop].shop[data.itemName] then
            Vending[data.shop].shop[data.itemName].count += data.count
        else
            Vending[data.shop].shop[data.itemName] = {}
            
            Vending[data.shop].shop[data.itemName].count = data.count
            Vending[data.shop].shop[data.itemName].price = data.price
            Vending[data.shop].shop[data.itemName].label = GetItemLabel(data.itemName)
        end

        RemoveItem(src, data.itemName, data.count)
    end
end)


RegisterNetEvent('uniq_vending:withdaw', function(shop, amount)
    local src = source

    if Vending[shop] then
        if type(Vending[shop].owner) == 'string' then
            if Vending[shop].owner == GetIdentifier(src) then
                Vending[shop].balance -= amount

                AddMoney(src, amount)
            end
        elseif type(Vending[shop].owner) == 'table' then
            local job, grade = GetJob(src)
            
            if Vending[shop].owner[job] and grade >= Vending[shop].owner[job] then
                Vending[shop].balance -= amount

                AddMoney(src, amount)
            end
        end
    end
end)

RegisterNetEvent('uniq_vending:deposit', function(shop, amount)
    local src = source

    if Vending[shop] then
        if type(Vending[shop].owner) == 'string' then
            if Vending[shop].owner == GetIdentifier(src) then
                Vending[shop].balance += amount

                RemoveMoney(src, amount)
            end
        elseif type(Vending[shop].owner) == 'table' then
            local job, grade = GetJob(src)

            if Vending[shop].owner[job] and grade >= Vending[shop].owner[job] then
                Vending[shop].balance += amount

                RemoveMoney(src, amount)
            end
        end
    end
end)

RegisterNetEvent('uniq_vending:buyItem', function(data)
    local src = source

    if Vending[data.shop] then
        local price = Vending[data.shop].shop[data.itemName].price * data.count

        if CanAfford(src, price) then
            Vending[data.shop].shop[data.itemName].count -= data.count

            if Vending[data.shop].shop[data.itemName].count == 0 then
                Vending[data.shop].shop[data.itemName] = nil
            end

            AddItem(src, data.itemName, data.count)
            Vending[data.shop].balance += price
        else
            lib.notify(src, { description = L('notify.not_enough_money_item'), type = 'error' })
        end
    end
end)

lib.callback.register('uniq_vending:getMoneyShop', function(source, shop)
    if Vending[shop] then
        return Vending[shop].balance
    end

    return 0
end)


lib.callback.register('uniq_vending:getMax', function(source, item)
    local items = GetInvItems(source)

    for k,v in pairs(items) do
        if v.name == item then
           return v.count or v.amount
        end
    end
end)

lib.callback.register('uniq_vending:getJobs', function(source)
    local jobs = GetJobs()
    local options = {}

    if IsESX() then
        for k,v in pairs(jobs) do
            if not cfg.BlacklsitedJobs[k] then
                options[#options + 1] = { label = v.label, value = k }
            end
        end
    elseif IsQBCore() then
        for k,v in pairs(jobs) do
            if not cfg.BlacklsitedJobs[k] then
                options[#options + 1] = { label = v.label, value = k }
            end
        end
    end

    return options
end)

lib.callback.register('uniq_vending:getGrades', function(source, job)
    local jobs = GetJobs()
    local options = {}

    if IsESX() then
        for k,v in pairs(jobs[job].grades) do
            options[#options + 1] = { label = v.label, value = v.grade }
        end
    elseif IsQBCore() then
        for k,v in pairs(jobs[job].grades) do
            options[#options + 1] = { label = v.name, value = tonumber(k) }
        end
    end

    return options
end)


RegisterNetEvent('uniq_vending:removeShopItem', function(data)
    local src = source

    if Vending[data.shop] then
        if type(Vending[data.shop].owner) == 'string' then
            if Vending[data.shop].owner == GetIdentifier(src) then
                Vending[data.shop].shop[data.itemName].count -= data.count

                if Vending[data.shop].shop[data.itemName].count == 0 then
                    Vending[data.shop].shop[data.itemName] = nil
                end

                AddItem(src, data.itemName, data.count)
            end
        elseif type(Vending[data.shop].owner) == 'table' then
            local job, grade = GetJob(src)

            if Vending[data.shop].owner[job] and grade >= Vending[data.shop].owner[job] then
                if Vending[data.shop].shop[data.itemName].count == 0 then
                    Vending[data.shop].shop[data.itemName] = nil
                end

                AddItem(src, data.itemName, data.count)
            end
        end
    end
end)


RegisterNetEvent('uniq_vending:updatePrice', function(data)
    local src = source

    if Vending[data.shop] then
        if type(Vending[data.shop].owner) == 'string' then
            if Vending[data.shop].owner == GetIdentifier(src) then
                Vending[data.shop].shop[data.itemName].price = data.price
            end
        elseif type(Vending[data.shop].owner) == 'table' then
            local job, grade = GetJob(src)

            if Vending[data.shop].owner[job] and grade >= Vending[data.shop].owner[job] then
                Vending[data.shop].shop[data.itemName].price = data.price
            end
        end
    end
end)

local function saveDB()
    local insertTable = {}
    if table.type(Vending) == 'empty' then return end

    for k,v in pairs(Vending) do
        insertTable[#insertTable + 1] = { query = 'UPDATE `uniq_vending` SET `shop` = ?, `balance` = ? WHERE `name` = ?', values = { json.encode(v.shop, {sort_keys = true}), v.balance, v.name } }
    end

    MySQL.transaction(insertTable)
end


-- every 5 min
lib.cron.new('*/5 * * * *', function()
    saveDB()
end)

AddEventHandler('playerDropped', function()
	if GetNumPlayerIndices() == 0 then
		saveDB()
	end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
	saveDB()
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end

	saveDB()
end)

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        saveDB()
    end
end)

lib.versionCheck('uniqscripts/uniq_vending_standalone')