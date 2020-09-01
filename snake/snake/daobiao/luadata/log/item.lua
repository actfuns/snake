-- ./excel/log/item.xlsx
return {

    ["add_item"] = {
        explain = "获得物品",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "装备sid"}, ["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_item",
    },

    ["add_items"] = {
        explain = "获得多个物品",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["items"] = {["id"] = "items", ["desc"] = "装备sid&amount"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_items",
    },

    ["sub_item"] = {
        explain = "扣除物品",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "装备sid"}, ["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reason"] = {["id"] = "reason", ["desc"] = "原因"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "sub_item",
    },

    ["openbox"] = {
        explain = "开宝箱",
        log_format = {["box"] = {["id"] = "box", ["desc"] = "宝箱sid"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["costs"] = {["id"] = "costs", ["desc"] = "消耗物品"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "openbox",
    },

    ["with_store"] = {
        explain = "存仓库",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品sid"}, ["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "with_store",
    },

    ["with_draw"] = {
        explain = "从仓库中取",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品sid"}, ["iteminfo"] = {["id"] = "iteminfo", ["desc"] = "物品信息"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "with_draw",
    },

    ["wenshi_make"] = {
        explain = "纹饰合成",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wenshi_make",
    },

    ["wenshi_combine"] = {
        explain = "纹饰融合",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["flag"] = {["id"] = "flag", ["desc"] = "是否成功"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wenshi_combine",
    },

    ["wenshi_wash"] = {
        explain = "纹饰洗练",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["goldcoin"] = {["id"] = "goldcoin", ["desc"] = "元宝"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "物品"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wenshi_wash",
    },

}
