module(..., package.seeall)
function main()
    local wuxunShop = require("economic.shop.wuxun")
    local jjcpointShop = require("economic.shop.jjcpoint")
    local leaderShop = require("economic.shop.leaderpoint")
    local xiayiShop = require("economic.shop.xiayipoint")
    local summonpoint = require("economic.shop.summonpoint")
    local chumopoint = require("economic.shop.chumopoint")
    local shopDict = {}
    shopDict[101] = wuxunShop
    shopDict[102] = jjcpointShop
    shopDict[103] = leaderShop
    shopDict[104] = xiayiShop
    shopDict[105] = summonpoint
    shopDict[106] = chumopoint

    local s = table.dump(shopDict, "SHOP")
    SaveToFile("score", s)
end