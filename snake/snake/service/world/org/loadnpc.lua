local global = require "global"
local extend = require "base.extend"

function GetPath(npctype)
    if global.oDerivedFileMgr:ExistFile("org", "npc", "n"..npctype) then
        return string.format("org/npc/n%d", npctype)
    end
    return string.format("org/orgnpc")
end

function NewOrgNpc(npctype, orgid)
    local sPath = GetPath(npctype)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("Load Org Npc Module:%d",npctype))
    return oModule.NewOrgNpc(npctype, orgid)
end
