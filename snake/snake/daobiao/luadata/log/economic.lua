-- ./excel/log/economic.xlsx
return {

    ["store_buy"] = {
        explain = "npc商城购买",
        log_format = {["buy"] = {["id"] = "buy", ["desc"] = "购买道具信息"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗货币信息"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "store_buy",
    },

    ["summon_buy"] = {
        explain = "宠物购买",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "宠物数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver"] = {["id"] = "silver", ["desc"] = "花费银币"}, ["summon"] = {["id"] = "summon", ["desc"] = "宠物类型"}},
        subtype = "summon_buy",
    },

    ["exchange_gold"] = {
        explain = "元宝兑换金币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["gold"] = {["id"] = "gold", ["desc"] = "金币"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "兑换元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "exchange_gold",
    },

    ["exchange_silver"] = {
        explain = "元宝兑换银币",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "兑换元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver"] = {["id"] = "silver", ["desc"] = "银币"}},
        subtype = "exchange_silver",
    },

    ["guild_buy"] = {
        explain = "商会购买",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["guild_amount"] = {["id"] = "guild_amount", ["desc"] = "当前数量"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["price_now"] = {["id"] = "price_now", ["desc"] = "当前价格"}, ["price_old"] = {["id"] = "price_old", ["desc"] = "原价格"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "道具id"}},
        subtype = "guild_buy",
    },

    ["guild_sell"] = {
        explain = "商会出售",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["guild_amount"] = {["id"] = "guild_amount", ["desc"] = "商会存货数量"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["price_now"] = {["id"] = "price_now", ["desc"] = "当前价格"}, ["price_old"] = {["id"] = "price_old", ["desc"] = "原价格"}, ["sell_amount"] = {["id"] = "sell_amount", ["desc"] = "数量"}, ["sell_price"] = {["id"] = "sell_price", ["desc"] = "出售价格"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "道具id"}},
        subtype = "guild_sell",
    },

    ["stall_upsize"] = {
        explain = "摆摊扩容",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "消耗金币"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["size_now"] = {["id"] = "size_now", ["desc"] = "现摊位大小"}, ["size_old"] = {["id"] = "size_old", ["desc"] = "原摊位大小"}},
        subtype = "stall_upsize",
    },

    ["stall_upitem"] = {
        explain = "摆摊上架",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "上架位置"}, ["price"] = {["id"] = "price", ["desc"] = "摆摊价格"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "道具id"}, ["taxfee"] = {["id"] = "taxfee", ["desc"] = "税"}},
        subtype = "stall_upitem",
    },

    ["stall_downitem"] = {
        explain = "摆摊下架",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "下架位置"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "道具id"}},
        subtype = "stall_downitem",
    },

    ["stall_withdraw"] = {
        explain = "摆摊取现",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos_list"] = {["id"] = "pos_list", ["desc"] = "取现位置"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["total"] = {["id"] = "total", ["desc"] = "取现总额"}},
        subtype = "stall_withdraw",
    },

    ["stall_buy"] = {
        explain = "摆摊购买",
        log_format = {["buy_amount"] = {["id"] = "buy_amount", ["desc"] = "数量"}, ["buy_cost"] = {["id"] = "buy_cost", ["desc"] = "购买消耗"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["query_id"] = {["id"] = "query_id", ["desc"] = "道具id"}, ["sell_owner"] = {["id"] = "sell_owner", ["desc"] = "出售人"}, ["sell_pos"] = {["id"] = "sell_pos", ["desc"] = "物品位置"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "stall_buy",
    },

    ["quick_buy_item"] = {
        explain = "便捷购买",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "消耗元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "道具id"}},
        subtype = "quick_buy_item",
    },

}
