if not IsESX() then return end

local ESX = exports['es_extended']:getSharedObject()

function GetAllPlayers()
    return ESX.GetExtendedPlayers()
end

function GetPlayerFromId(id)
    return ESX.GetPlayerFromId(id)
end

function GetJobs()
    return ESX.GetJobs()
end

function GetJob(id)
    local xPlayer = ESX.GetPlayerFromId(id)

    if xPlayer then
        return xPlayer.job.name, xPlayer.job.grade
    end
end

function GetIdentifier(id)
    local xPlayer = ESX.GetPlayerFromId(id)
    
    if xPlayer then
        return xPlayer.identifier
    end

    return false
end


function CanAfford(source, price)
	local Player = ESX.GetPlayerFromId(source)

	if Player then
		Player.removeMoney(price)
        return true
	end

    return false
end


function GetInvItems(source)
    return ESX.GetPlayerFromId(source).inventory
end

function RemoveItem(source, name, count)
    local Player = ESX.GetPlayerFromId(source)

    if Player then
        Player.removeInventoryItem(name, count)
    end
end

function AddItem(source, name, count)
    local Player = ESX.GetPlayerFromId(source)

    if Player then
        Player.addInventoryItem(name, count)
    end
end


function AddMoney(source, amount)
    local Player = ESX.GetPlayerFromId(source)

    if Player then
        Player.addInventoryItem('money', amount)
    end
end

function RemoveMoney(source, amount)
    local Player = ESX.GetPlayerFromId(source)

    if Player then
        Player.removeMoney(amount)
    end
end

function GetItemLabel(name)
    return ESX.GetItemLabel(name)
end