module(..., package.seeall)
function main()
    local d1 = require("system.warconfig.GRID_POS_MAP")
    local d2 = require("system.warconfig.BOSS_POS_MAP")
    --local d3 = require("system.warconfig.GRID_POS_KEY")
    local d3 = require("system.warconfig.Others")
    local d4 = require("system.warconfig.NEIGHBOR_POS")

    -- 手动添加空表，防止报错
    local gridPosKey = "GRID_POS_KEY = {}"

    local dNeighbor = {}
    for i,dPosCfg in ipairs(d4) do
    	dNeighbor[dPosCfg.id] = {}
    	for _,iPos in ipairs(dPosCfg.poslist) do
    	 	dNeighbor[i][iPos] = true
    	end 
    end

    local s = table.dump(d1, "GRID_POS_MAP") .. "\n" .. table.dump(d2, "BOSS_POS_MAP") .. "\n" .. gridPosKey .. "\n" .. table.dump(d3, "Others").. "\n" .. table.dump(dNeighbor, "NEIGHBOR_POS")
    SaveToFile("lineup", s)
end