module(..., package.seeall)
function main()
    local d1 = require("reward.fuyuanbox_itemreward")
    local d2 = require("huodong.fuyuanbox.des")
    local d3 = require("huodong.fuyuanbox.config")

    
    local s = table.dump(d1, "FUYUAN_REWARD") .. "\n" ..  table.dump(d2, "TEXT_DES") .. "\n" ..  table.dump(d3, "CONFIG")
    SaveToFile("fuyuanbox", s)
end