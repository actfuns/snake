module(..., package.seeall)
function main()
    local newReward = require("huodong.totalcharge.new_reward")
    local oldReward = require("huodong.totalcharge.old_reward")
    local thirdreward = require("huodong.totalcharge.third_reward")
    local s = table.dump(newReward, "NEWREWARD") .. table.dump(oldReward, "OLDREWARD") .. table.dump(thirdreward, "THIRDREWARD")
    SaveToFile("accumcharge", s)
end