-- ./excel/log/shop.xlsx
return {

    ["buy_good"] = {
        explain = "购买商品",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["good"] = {["id"] = "good", ["desc"] = "商品"}, ["moneytype"] = {["id"] = "moneytype", ["desc"] = "货币类型"}, ["moneyvalue"] = {["id"] = "moneyvalue", ["desc"] = "货币数量"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["shop"] = {["id"] = "shop", ["desc"] = "商店"}},
        subtype = "buy_good",
    },

}
