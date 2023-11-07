local cfg = lib.require('config.config')
local raycast = lib.require('client.raycast')
local Points, Blips = {}, {}
local ImagePath = lib.require('client.imgpath')


local function RemovePoints()
    for k,v in pairs(Points) do
        if v.entity then
            if DoesEntityExist(v.entity) then
                SetEntityAsMissionEntity(v.entity, false, true)
                DeleteEntity(v.entity)
            end
        end

        v:remove()
        Points[k] = nil
    end
end

local function onEnter(point)
    if not point.entity then
        local model = lib.requestModel(point.model)
        if not model then return end

        local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

        SetModelAsNoLongerNeeded(model)
        SetEntityHeading(entity, point.heading)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)

        point.entity = entity
    end
end

local function onExit(point)
    local entity = point.entity

	if entity then
		if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, false, true)
            DeleteEntity(entity)
        end

		point.entity = nil
	end
end

local menu = {
    id = 'uniq_vending:main',
    title = L('context.vending_title'),
    options = {}
}

local function isOwner(owner)
    if type(owner) == 'string' then
        if owner == GetIdentifier() then
            return true
        end
    elseif type(owner) == "table" then
        local job, grade = GetJob()

        if owner[job] and grade >= owner[job] then
            return true
        end
    end

    return false
end

function GenerateMenu(point)
    local options = {
        {
            icon = 'fas fa-shopping-basket',
            title = L('context.access_vending'),
            onSelect = function()
                local shop = lib.callback.await('uniq_vending:GetItems', false, point.label)
                local option = {}

                if table.type(shop) == 'empty' then
                    lib.notify{ description = L('notify.no_items'), type = 'error' }

                    return lib.showContext(menu.id)
                end

                for k,v in pairs(shop) do
                    option[#option + 1] = {
                        title = v.label,
                        icon = cfg.EnableImageIcons and ImagePath:format(k) or '',
                        description = L('context.item_desc'):format(v.price, v.count),
                        onSelect = function()
                            local count = lib.inputDialog('', { { type = 'number', label = L('context.how_much'), max = v.count, min = 1, required = true } })
                            if not count then return end

                            TriggerServerEvent('uniq_vending:buyItem', {
                                shop = point.label,
                                itemName = k,
                                count = count[1]
                            })
                        end
                    }
                end

                lib.registerContext({
                    id = 'uniq_vending:buyItem',
                    title = L('context.item_stock'),
                    options = option
                })

                lib.showContext('uniq_vending:buyItem')
            end,
            distance = 2.0
        }
    }

    if not point.owner or point.owner == false then
        options[#options + 1] = {
            title = L('context.buy_vending'),
            icon = 'fa-solid fa-dollar-sign',
            onSelect = function ()
                local alert = lib.alertDialog({
                    header = L('context.buy_vending'),
                    content = L('alert.buy_vending_confirm'):format(point.price),
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('uniq_vending:buyVending', point.label)
                end
            end
        }
    end

    if isOwner(point.owner) then
        local balancee = lib.callback.await('uniq_vending:getMoneyShop', false, point.label)

        options[#options+1] = {
            title = L('context.sell_vending'),
            icon = 'fa-solid fa-money-bill-trend-up',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = L('context.sell_vending'),
                    content = L('alert.sell_vending_confirm'):format(math.floor(point.price * cfg.SellPertencage)),
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TriggerServerEvent('uniq_vending:sellVending', point.label)
                end
            end
        }

        options[#options + 1] = {
            title = L('context.stock'),
            icon = 'fa-solid fa-box',
            onSelect = function()
                local shop = lib.callback.await('uniq_vending:GetItems', false, point.label)

                local option = {
                    {
                        title = L('context.new_item'),
                        onSelect = function()
                            local inv = lib.callback.await('uniq_vending:GetPlayerInv', false)
                            local items = {}

                            for k,v in pairs(inv) do
                                if not cfg.BlacklistedItems[v.value] then
                                    items[#items + 1] = { label = v.label, value = v.value }
                                end
                            end

                            table.sort(items, function (a, b)
                                return a.label < b.label
                            end)

                            local input = lib.inputDialog('', { { type = 'select', label = L('context.select_item'), options = items, required = true } })
                            if not input then return end

                            local getMax = lib.callback.await('uniq_vending:getMax', false, input[1])

                            local input2 = lib.inputDialog('', {
                                { type = 'number', label = L('context.amount'), description = L('context.max_can_put'):format(getMax), required = true, max = getMax },
                                { type = 'number', label = 'Price', required = true },
                            })

                            if not input2 then return end

                            TriggerServerEvent('uniq_vending:addStockItems', {
                                shop = point.label,
                                itemName = input[1],
                                count = input2[1],
                                price = input2[2]
                            })
                        end
                    }
                }

                for k,v in pairs(shop) do
                    option[#option + 1] = {
                        title = v.label,
                        icon = cfg.EnableImageIcons and ImagePath:format(k) or '',
                        description = L('context.item_desc'):format(v.price, v.count),
                        arrow = true,
                        onSelect = function()
                            lib.registerContext({
                                id = 'uniq_vending:item_edit',
                                title = L('context.edit_item'),
                                options = {
                                    {
                                        title = L('context.rem_item'),
                                        arrow = true,
                                        onSelect = function(args)
                                            local input = lib.inputDialog('', { { type = 'number', label = L('context.amount'), description = L('context.max'):format(v.count), min = 1, max = v.count, required = true } })
                                            if not input then return end

                                            TriggerServerEvent('uniq_vending:removeShopItem', {
                                                shop = point.label,
                                                itemName = k,
                                                count = input[1],
                                            })
                                        end
                                    },
                                    {
                                        title = L('context.update_price'),
                                        arrow = true,
                                        onSelect = function(args)
                                            local input = lib.inputDialog('', { { type = 'number', label = L('context.item_price'), description = L('context.current'):format(v.price), min = 1, required = true } })
                                            if not input then return end

                                            TriggerServerEvent('uniq_vending:updatePrice', {
                                                shop = point.label,
                                                itemName = k,
                                                price = input[1],
                                            })
                                        end
                                    }
                                }
                            })

                            lib.showContext('uniq_vending:item_edit')
                        end
                    }
                end

                lib.registerContext({
                    id = 'uniq_vending:stock',
                    title = L('context.stock'),
                    options = option
                })

                lib.showContext('uniq_vending:stock')
            end
        }

        options[#options + 1] = {
            title = L('context.money'):format(balancee),
            icon = 'fa-solid fa-sack-dollar',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'uniq_vending:shop:balance',
                    title = L('context.handle_balance'),
                    options = {
                        {
                            title = L('context.w_money'),
                            onSelect = function()
                                local input = lib.inputDialog('', { { type = 'number', label = L('context.amount'), description = L('context.max'):format(balancee), max = balancee, min = 1, required = true } })
                                if not input then return end

                                TriggerServerEvent('uniq_vending:withdaw', point.label, input[1])
                            end
                        },
                        {
                            title = L('context.d_money'),
                            onSelect = function()
                                local input = lib.inputDialog('', { { type = 'number', label = L('context.amount'), min = 1, required = true } })
                                if not input then return end

                                TriggerServerEvent('uniq_vending:deposit', point.label, input[1])
                            end
                        }
                    }
                })

                lib.showContext('uniq_vending:shop:balance')
            end
        }
    end

    menu.options = options

    lib.registerContext(menu)

    return lib.showContext(menu.id)
end

local function nearby(point)
    if point.currentDistance < 1.4 then
        if IsControlJustPressed(0, 38) then
            GenerateMenu(point)
        end
    end
end

local textUI = false
CreateThread(function()
    while true do
        local point = lib.points.getClosestPoint()

        if point then
            if point.currentDistance < 1.4 then
                if not textUI then
                    textUI = true
                    lib.showTextUI(L('text_ui.open_vending'))
                end
            else
                if textUI then
                    textUI = false
                    lib.hideTextUI()
                end
            end
        end

        Wait(300)
    end
end)


local function createBlip(data, coords)
    local blip = Blips[#Blips + 1]
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite (blip, data.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale  (blip, data.scale)
    SetBlipColour (blip, data.colour)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.name)
    EndTextCommandSetBlipName(blip)
end

function SetupVendings()
    for k,v in pairs(Blips) do
        RemoveBlip(v)
        Blips[k] = nil
    end
   local data = lib.callback.await('uniq_vending:fetchVendings', false)

    if data then
        for k,v in pairs(data) do
            Points[#Points + 1] = lib.points.new({
                coords = v.coords,
                distance = 15.0,
                onEnter = onEnter,
                nearby = nearby,
                onExit = onExit,
                label = v.name,
                owner = v.owner,
                model = v.obj,
                price = v.price,
                heading = v.heading
            })

            if v.blip then
                createBlip(v.blip, v.coords)
            end
        end
    end
end

RegisterNetEvent('uniq_vending:sync', function(data, clear)
    if source == '' then return end

    for k,v in pairs(Blips) do
        RemoveBlip(v)
        Blips[k] = nil
    end

    if clear then RemovePoints() end

    Wait(200)

    for k,v in pairs(data) do
        Points[#Points + 1] = lib.points.new({
            coords = v.coords,
            distance = 15.0,
            onEnter = onEnter,
            nearby = nearby,
            onExit = onExit,
            label = v.name,
            owner = v.owner,
            model = v.obj,
            price = v.price,
            heading = v.heading
        })

        if v.blip then
            createBlip(v.blip, v.coords)
        end
    end
end)

RegisterNetEvent('uniq_vending:startCreating', function(players)
    if source == '' then return end
    local vending = {}

    local input = lib.inputDialog(L('input.vending_creator'), {
        { type = 'input', label = L('input.vending_label'), required = true, default = cfg.Debug and 'Test' or '' },
        { type = 'number', label = L('input.vending_price'), required = true, min = 1, default = cfg.Debug and 1 },
        { type = 'select', label = L('input.select_object'), required = true, options = cfg.Machines, clearable = true, default = cfg.Debug and cfg.Machines[1].value },
        { type = 'select', label = L('input.owned_type.title'), default = cfg.Debug and 'a', options = {
            { label = L('input.owned_type.a'), value = 'a' },
            { label = L('input.owned_type.b'), value = 'b' },
        }, clearable = true, required = true },
        { type = 'checkbox', label = L('input.blip'), checked = false }
    })

    if not input then return end

    if input[5] then
        local blip = lib.inputDialog('', {
            { type = 'number', label = L('input.blipInput.a'), required = true },
            { type = 'number', label = L('input.blipInput.b'), required = true, precision = true, min = 0 },
            { type = 'number', label = L('input.blipInput.c'), required = true },
            { type = 'input',  label = L('input.blipInput.d'), required = true, default = input[1] },
        })

        if not blip then return end

        vending.blip = {
            sprite = blip[1],
            scale = blip[2],
            colour = blip[3],
            name = blip[4],
        }
    end

    vending.name = input[1]
    vending.price = input[2]
    vending.obj = input[3]

    if input[4] == 'a' then
        table.sort(players, function (a, b)
            return a.id < b.id
        end)

        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.player_owned_label'), description = L('input.player_owned_desc'), options = players, clearable = true }
        })
        
        if not owner then
            vending.owner = false
        else
            vending.owner = owner[1]
        end
        vending.type = 'player'
    elseif input[4] == 'b' then
        local jobs = lib.callback.await('uniq_vending:getJobs', 100)

        table.sort(jobs, function (a, b)
            return a.label < b.label
        end)

        local owner = lib.inputDialog(L('input.vending_creator'), {
            { type = 'select', label = L('input.job_owned_label'), description = L('input.job_owned_desc'), options = jobs, clearable = true }
        }, {allowCancel = false})

        if not owner[1] then
            vending.owner = false
        else
            local grades = lib.callback.await('uniq_vending:getGrades', 100, owner[1])

            table.sort(grades, function (a, b)
                return a.value < b.value
            end)
    
            local grade = lib.inputDialog(L('input.vending_creator'), {
                { type = 'select', label = L('input.chose_grade'), description = L('input.chose_grade_desc'), required = true, options = grades, clearable = true }
            })
    
            if not grade then return end
    
            vending.owner = { [owner[1]] = grade[1] }
        end
        vending.type = 'job'
    end

    lib.showTextUI(table.concat(L('text_ui.help')))
    local heading = 0
    local obj
    local created = false

    lib.requestModel(vending.obj)

    CreateThread(function ()
        while true do
            ---@diagnostic disable-next-line: need-check-nil
            local hit, coords, entity = raycast(100.0)
    
            if not created then
                created = true
                obj = CreateObject(vending.obj , coords.x, coords.y, coords.z, false, false, false)
            end
    
            if IsControlPressed(0, 174) then
                heading += 1.5
            end
    
            if IsControlPressed(0, 175) then
                heading -= 1.5
            end
    
            if IsDisabledControlPressed(0, 176) then
                lib.hideTextUI()
                vending.coords = coords
                vending.heading = GetEntityHeading(obj)
                DeleteObject(obj)
                TriggerServerEvent('uniq_vending:createVending', vending)
                
                break
            end

            local pedPos = GetEntityCoords(cache.ped)
            local distance = #(coords - pedPos)

            if distance >= 3.5 then
                SetEntityCoords(obj, coords.x, coords.y, coords.z)
                SetEntityHeading(obj, heading)
            end


            Wait(0)
        end
    end)

    collectgarbage("collect")
end)


RegisterNetEvent('uniq_vending:client:dellvending', function(data)
    if source == '' then return end

    table.sort(data, function (a, b)
        return a.value < b.value
    end)

    local input = lib.inputDialog('Delete Vending', {
        { type = 'select', label = L('input.job_owned_label'), required = true, clearable = true, options = data }
    })

    if not input then return end

    TriggerServerEvent('uniq_vending:server:dellvending', input[1])
end)


RegisterNetEvent('uniq_vending:selectCurrency', function(payload)
    if source == '' then return end
    local itemNames = {}

    for item, data in pairs(exports.ox_inventory:Items()) do
        if not cfg.CantBeCurrency[data.name] then
            itemNames[#itemNames + 1] = { label = data.label, value = data.name }
        end
    end

    table.sort(itemNames, function (a, b)
        return a.label < b.label
    end)

    local input = lib.inputDialog(payload.fromSlot.label, {
        { type = 'number', label = L('context.item_price_per_one'), required = true, min = 1 },
        { type = 'select', label = L('context.currency'), description = L('context.currency_desc'), clearable = true, options = itemNames }
    }, { allowCancel = false })

    if not input[2] then
        input[2] = 'money'
    end

    TriggerServerEvent('uniq_vending:setData', input[1], input[2], payload)
end)

lib.callback.register('uniq_vending:choseVending', function(options)
    local input = lib.inputDialog('', { { type = 'select', label = 'Chose Vending', required = true, options = options} })
    if not input then return false end

    return input[1]
end)

AddEventHandler('onResourceStop', function(name)
    if name == cache.resource then
        RemovePoints()
        if textUI then
            lib.hideTextUI()
        end
    end
end)
