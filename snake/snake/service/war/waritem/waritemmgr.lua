
local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))
local wardefines = import(service_path("fight/wardefines"))

function NewWarItemMgr(...)
    local o = CWarItemMgr:New(...)
    return o
end

CWarItemMgr = {}
CWarItemMgr.__index = CWarItemMgr
inherit(CWarItemMgr, logic_base_cls())

function CWarItemMgr:New()
    local o = super(CWarItemMgr).New(self)
    o.m_lWarItemList = {}
    return o
end

function CWarItemMgr:NewWarItem(iWarItemId)
    local sPath = string.format("waritem/i%s",iWarItemId)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("NewWarItem err:%d,%s",iWarItemId,sPath))
    local oWarItem = oModule.NewWarItem(iWarItemId)
    return oWarItem
end

function CWarItemMgr:GetWarItem(iWarItemId)
    local oWarItem = self.m_lWarItemList[iWarItemId]
    if oWarItem then
        return oWarItem
    end
    assert(iWarItemId,string.format("GetWarItem err:%s",iWarItemId))
    local oWarItem = self:NewWarItem(iWarItemId)
    self.m_lWarItemList[iWarItemId] = oWarItem
    return oWarItem
end
