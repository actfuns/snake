local global = require "global"

local extend = require "base.extend"

-- 可以考虑下以后是否将globalnpc分成单独的一个目录
-- local NpcDir = {
--     ["func"] = {5001,5200},
--     ["idle"] = {5201,5400},
-- }
-- function GetDir(npcid)
--     for sDir,mNpc in pairs(NpcDir) do
--         local iStart,iEnd = table.unpack(mNpc)
--         if iStart <= npcid and npcid <= iEnd then
--             return sDir
--         end
--     end
-- end

function GetPath(npctype)
    if global.oDerivedFileMgr:ExistFile("npc", "npcs", "n"..npctype) then
        return string.format("npc/npcs/n%d", npctype)
    end
    return string.format("npc/npcobj")
end

function NewNpc(npctype)
    local sPath = GetPath(npctype)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("Load Npc Module:%d",npctype))
    return oModule.NewNpc(npctype)
end

function NewGlobalNpc(npctype)
    local sPath = GetPath(npctype)
    local oModule = import(service_path(sPath))
    assert(oModule,string.format("Load Npc Module:%d",npctype))
    return oModule.NewGlobalNpc(npctype)
end
