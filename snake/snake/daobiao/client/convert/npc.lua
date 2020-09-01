module(..., package.seeall)
function main()
	local newTable = {}
	local oriTable = nil

	local npcName = {"dialog_npc", "global_npc", "temp_npc"}
	for _,v in ipairs(npcName) do
		oriTable = require("npc." .. v)
		newTable[string.upper(v)] = oriTable
	end

	local school = require("npc.school_npc")
	local npcgroup = require("npc.npcgroup")
	local npcpatrol = require("npc.npcpatrol")
	local menuoption = require("npc.menu_option")

    -- 这里需要做npc来源的区分
    local dNpctalklist = {}
    dNpctalklist["huodong.fengyao"] = {}
    dNpctalklist["huodong.moneytree"] = {}
    local dDialogue = {}
    dDialogue["huodong.fengyao"] = {}
    dDialogue["huodong.moneytree"] = {}

    local npctalklist1 = require("huodong.fengyao.dialog_fengyao")
    local dialogue1 = require("huodong.fengyao.desc_fengyao")
    local npctalklist2 = require("huodong.moneytree.dialog_moneytree")
    local dialogue2 = require("huodong.moneytree.desc_moneytree")
    for k,v in pairs(npctalklist1) do
        dNpctalklist["huodong.fengyao"][k] = v
    end
    for k,v in pairs(dialogue1) do
        dDialogue["huodong.fengyao"][k] = v
    end
    for k,v in pairs(npctalklist2) do
        dNpctalklist["huodong.moneytree"][k] = v
    end
    for k,v in pairs(dialogue2) do
        dDialogue["huodong.moneytree"][k] = v
    end
    local sealnpcmap = require("huodong.fengyao.npcmap")

	local s = table.dump(newTable, "NPC") .. "\n" .. table.dump(school, "SCHOOL") .. "\n" .. table.dump(npcgroup, "NPCGROUP") .. "\n" .. table.dump(npcpatrol, "NPCPATROL") 
	.. "\n" .. table.dump(dNpctalklist, "NPCTALKLIST") .. "\n" .. table.dump(dDialogue, "DIALOGUELIST") .. "\n" .. table.dump(sealnpcmap, "SEALNPCMAP") .. "\n" .. table.dump(menuoption, "MENUOPTION")
	SaveToFile("npc", s)
end
