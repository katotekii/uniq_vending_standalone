local oxinv = GetResourceState("ox_inventory")
local qbinv = GetResourceState("qb-inventory")
local psinv = GetResourceState("ps-inventory")
local qsinv = GetResourceState("qs-inventory")
local core = GetResourceState("core_inventory")

function GetPath()
    if oxinv then
        return 'nui://ox_inventory/web/images/%s.png'
    elseif qbinv then
        return'nui://qb-inventory/html/images/%s.png'
    elseif psinv then
        return 'nui://ps-inventory/html/images/%s.png'
    elseif qsinv then
        return 'nui://qs-inventory/html/images/%s.png'
    elseif core then
        return 'nui://core_inventory/html/img/%s.png'
    end
end

--[[
    if you use something else then add it, urls are also suported, if you use esx default inventory then you have some issues
        local path = path/%s.png
        %s = item name
        return = path
]]

return GetPath()