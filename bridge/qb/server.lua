if not IsQBCore() then return end

local QBCore = exports['qb-core']:GetCoreObject()

function GetAllPlayers()
    return QBCore.Functions.GetQBPlayers()
end

function GetPlayerFromId(id)
    return QBCore.Functions.GetPlayer(id)
end

function GetJobs()
    return QBCore.Shared.Jobs
end

function GetJob(id)
    local Player = QBCore.Functions.GetPlayer(id)

    if Player then
        return Player.PlayerData.job.name, Player.PlayerData.job.grade.level
    end
end

function GetIdentifier(id)
    local Player = QBCore.Functions.GetPlayer(id)
    
    if Player then
        return Player.PlayerData.citizenid
    end

    return false
end


function CanAfford(source, price)
	local Player = QBCore.Functions.GetPlayer(source)

	if Player then
		return Player.Functions.RemoveMoney('cash', price)
	end
end


function GetInvItems(source)
    return QBCore.Functions.GetPlayer(source).PlayerData.items
end

function RemoveItem(source, name, count)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player then
        Player.Functions.RemoveItem(name, count)
    end
end

function AddItem(source, name, count)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player then
        Player.Functions.AddItem(name, count)
    end
end


function AddMoney(source, amount)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player then
        Player.Functions.AddMoney('cash', amount)
    end
end

function RemoveMoney(source, amount)
    local Player = QBCore.Functions.GetPlayer(source)

    if Player then
        Player.Functions.RemoveMoney('cash', amount)
    end
end

function GetItemLabel(name)
    return QBCore.Shared.Items[name].label
end