module(..., package.seeall)
function main()
    local onlineGift = require("huodong.onlinegift.online_gift")
    local s = table.dump(onlineGift, "RewardItem")
    SaveToFile("onlinegift", s)
end