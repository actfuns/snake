-- ./excel/log/item.xlsx
return {

    ["fuhun"] = {
        explain = "附魂",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "装备sid"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_shenhun"] = {["id"] = "new_shenhun", ["desc"] = "新神魂"}, ["old_shenhun"] = {["id"] = "old_shenhun", ["desc"] = "原神魂"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "fuhun",
    },

    ["wash"] = {
        explain = "洗练替换",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "装备sid"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_attach_attr"] = {["id"] = "new_attach_attr", ["desc"] = "新附加属性"}, ["new_se"] = {["id"] = "new_se", ["desc"] = "新特效技能"}, ["old_attach_attr"] = {["id"] = "old_attach_attr", ["desc"] = "原附加属性"}, ["old_se"] = {["id"] = "old_se", ["desc"] = "原特效技能"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "wash",
    },

    ["strength"] = {
        explain = "强化",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["fail_cnt"] = {["id"] = "fail_cnt", ["desc"] = "连续失败次数"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["level"] = {["id"] = "level", ["desc"] = "强化等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "部位"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["succ"] = {["id"] = "succ", ["desc"] = "成功"}},
        subtype = "strength",
    },

    ["break"] = {
        explain = "突破",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["level"] = {["id"] = "level", ["desc"] = "突破等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "部位"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "break",
    },

    ["add_hunshi"] = {
        explain = "镶嵌魂石",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["equip"] = {["id"] = "equip", ["desc"] = "装备"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "魂石"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "部位"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "add_hunshi",
    },

    ["del_hunshi"] = {
        explain = "卸下魂石",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["equip"] = {["id"] = "equip", ["desc"] = "装备"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["item"] = {["id"] = "item", ["desc"] = "魂石"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "部位"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "del_hunshi",
    },

}
