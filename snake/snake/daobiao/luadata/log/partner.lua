-- ./excel/log/partner.xlsx
return {

    ["exp"] = {
        explain = "获得经验",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["exp_add"] = {["id"] = "exp_add", ["desc"] = "增加经验"}, ["exp_now"] = {["id"] = "exp_now", ["desc"] = "当前经验"}, ["exp_old"] = {["id"] = "exp_old", ["desc"] = "原经验"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["grade_now"] = {["id"] = "grade_now", ["desc"] = "当前等级"}, ["grade_old"] = {["id"] = "grade_old", ["desc"] = "原等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "伙伴sid"}},
        subtype = "exp",
    },

    ["add_partner"] = {
        explain = "招募伙伴",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "消耗数量"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner_sid"] = {["id"] = "partner_sid", ["desc"] = "伙伴sid"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["sid"] = {["id"] = "sid", ["desc"] = "物品消耗"}, ["silver"] = {["id"] = "silver", ["desc"] = "银币消耗"}},
        subtype = "add_partner",
    },

    ["quality_partner"] = {
        explain = "伙伴进阶",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner_sid"] = {["id"] = "partner_sid", ["desc"] = "伙伴sid"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["quality_add"] = {["id"] = "quality_add", ["desc"] = "增加品质"}, ["quality_now"] = {["id"] = "quality_now", ["desc"] = "现品质"}, ["quality_old"] = {["id"] = "quality_old", ["desc"] = "原品质"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver"] = {["id"] = "silver", ["desc"] = "银币消耗"}},
        subtype = "quality_partner",
    },

    ["upper_partner"] = {
        explain = "伙伴突破",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner_sid"] = {["id"] = "partner_sid", ["desc"] = "伙伴sid"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["upper_add"] = {["id"] = "upper_add", ["desc"] = "突破等级"}, ["upper_now"] = {["id"] = "upper_now", ["desc"] = "现突破等级"}, ["upper_old"] = {["id"] = "upper_old", ["desc"] = "原突破等级"}},
        subtype = "upper_partner",
    },

    ["skill_upgrade"] = {
        explain = "技能升级",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["cost"] = {["id"] = "cost", ["desc"] = "道具消耗"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["lv_now"] = {["id"] = "lv_now", ["desc"] = "现等级"}, ["lv_old"] = {["id"] = "lv_old", ["desc"] = "原等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner_sid"] = {["id"] = "partner_sid", ["desc"] = "伙伴sid"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["skill"] = {["id"] = "skill", ["desc"] = "技能编号"}},
        subtype = "skill_upgrade",
    },

    ["equip_partner"] = {
        explain = "伙伴装备",
        log_format = {["apply"] = {["id"] = "apply", ["desc"] = "装备属性"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["partner_sid"] = {["id"] = "partner_sid", ["desc"] = "伙伴sid"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["pos"] = {["id"] = "pos", ["desc"] = "装备位置"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "equip_partner",
    },

}
