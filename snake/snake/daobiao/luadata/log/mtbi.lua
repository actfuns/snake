-- ./excel/log/mtbi.xlsx
return {

    ["base"] = {
        explain = "基本",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "base",
    },

    ["online"] = {
        explain = "在线数据",
        log_format = {{["id"] = "server", ["desc"] = "大区ID"}, {["id"] = "count", ["desc"] = "人数"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "platform", ["desc"] = "平台"}},
        subtype = "online",
    },

    ["register"] = {
        explain = "注册数据",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道ID"}, {["id"] = "subchannel", ["desc"] = "子渠道ID"}, {["id"] = "server", ["desc"] = "大区ID"}, {["id"] = "time", ["desc"] = "注册时间"}, {["id"] = "ip", ["desc"] = "注册IP"}, {["id"] = "udid", ["desc"] = "设备ID"}, {["id"] = "platform", ["desc"] = "平台"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "register",
    },

    ["recharge"] = {
        explain = "充值数据",
        log_format = {{["id"] = "order", ["desc"] = "订单ID"}, {["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "type", ["desc"] = "充值类型"}, {["id"] = "amount", ["desc"] = "充值金额"}, {["id"] = "time", ["desc"] = "充值时间"}, {["id"] = "server", ["desc"] = "大区ID"}, {["id"] = "channel", ["desc"] = "渠道ID"}, {["id"] = "subchannel", ["desc"] = "子渠道ID"}, {["id"] = "grade", ["desc"] = "充值等级"}, {["id"] = "ip", ["desc"] = "充值IP"}, {["id"] = "udid", ["desc"] = "设备ID"}, {["id"] = "platform", ["desc"] = "平台"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "recharge",
    },

    ["login"] = {
        explain = "登陆数据",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道ID"}, {["id"] = "subchannel", ["desc"] = "子渠道ID"}, {["id"] = "server", ["desc"] = "大区ID"}, {["id"] = "time", ["desc"] = "注册时间"}, {["id"] = "grade", ["desc"] = "等级"}, {["id"] = "duration", ["desc"] = "在线时长"}, {["id"] = "ip", ["desc"] = "注册IP"}, {["id"] = "udid", ["desc"] = "设备ID"}, {["id"] = "platform", ["desc"] = "平台"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "login",
    },

    ["loginin"] = {
        explain = "登入数据",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道ID"}, {["id"] = "subchannel", ["desc"] = "子渠道ID"}, {["id"] = "server", ["desc"] = "大区ID"}, {["id"] = "time", ["desc"] = "注册时间"}, {["id"] = "grade", ["desc"] = "等级"}, {["id"] = "duration", ["desc"] = "在线时长"}, {["id"] = "ip", ["desc"] = "注册IP"}, {["id"] = "udid", ["desc"] = "设备ID"}, {["id"] = "platform", ["desc"] = "平台"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "loginin",
    },

    ["energy"] = {
        explain = "活力消耗",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "val", ["desc"] = "消耗值"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "energy",
    },

    ["rename"] = {
        explain = "改名",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "old_name", ["desc"] = "原名字"}, {["id"] = "new_name", ["desc"] = "新名字"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "rename",
    },

    ["dianzan"] = {
        explain = "点赞",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "target", ["desc"] = "点赞目标"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "dianzan",
    },

    ["send_card"] = {
        explain = "名片发送",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "send_card",
    },

    ["player_wash"] = {
        explain = "角色洗点",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "isall", ["desc"] = "是否全部"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "player_wash",
    },

    ["active_skill"] = {
        explain = "主动技能",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "skid", ["desc"] = "技能id"}, {["id"] = "optype", ["desc"] = "操作类型"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "skpoint", ["desc"] = "技能点"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "active_skill",
    },

    ["passive_skill"] = {
        explain = "被动技能",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "skid", ["desc"] = "技能id"}, {["id"] = "optype", ["desc"] = "操作类型"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "goldcoin", ["desc"] = "快捷元宝"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "passive_skill",
    },

    ["cultivate_skill"] = {
        explain = "修炼技能",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "skid", ["desc"] = "技能id"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "cultivate_skill",
    },

    ["org_skill"] = {
        explain = "炼制（帮派技能）",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "optype", ["desc"] = "炼制类型"}, {["id"] = "cenergy", ["desc"] = "消耗活力"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "gitem", ["desc"] = "获得物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "org_skill",
    },

    ["org_skill_sj"] = {
        explain = "帮派技能升级",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "optype", ["desc"] = "炼制类型"}, {["id"] = "coffer", ["desc"] = "消耗帮贡"}, {["id"] = "currency", ["desc"] = "消耗银币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "org_skill_sj",
    },

    ["equip_qh"] = {
        explain = "装备强化",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "success", ["desc"] = "是否成功"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "equip_qh",
    },

    ["equip_tp"] = {
        explain = "装备突破",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "equip_tp",
    },

    ["equip_xl"] = {
        explain = "装备洗练",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "equip_xl",
    },

    ["equip_fh"] = {
        explain = "装备附魂",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "citem", ["desc"] = "消耗物品"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "equip_fh",
    },

    ["bag_kgz"] = {
        explain = "开背包格子",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "bag_kgz",
    },

    ["cangku"] = {
        explain = "开仓库",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "cangku",
    },

    ["shop"] = {
        explain = "商城购买（商店）",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "shop", ["desc"] = "商店ID"}, {["id"] = "item", ["desc"] = "购买物品"}, {["id"] = "num", ["desc"] = "购买数量"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "shop",
    },

    ["stall_buy"] = {
        explain = "摆摊购买",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "item", ["desc"] = "购买物品"}, {["id"] = "num", ["desc"] = "购买数量"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "stall_buy",
    },

    ["stall_sell"] = {
        explain = "摆摊出售",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "item", ["desc"] = "物品"}, {["id"] = "num", ["desc"] = "数量"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "stall_sell",
    },

    ["stall_kgz"] = {
        explain = "解锁摆摊格子",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "stall_kgz",
    },

    ["guild_buy"] = {
        explain = "商会购买",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "item", ["desc"] = "物品"}, {["id"] = "num", ["desc"] = "数量"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "guild_buy",
    },

    ["friend"] = {
        explain = "好友系统",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "optype", ["desc"] = "操作"}, {["id"] = "targetid", ["desc"] = "目标pid"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "friend",
    },

    ["chat"] = {
        explain = "聊天系统",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "chat_channel", ["desc"] = "频道"}, {["id"] = "cenergy", ["desc"] = "消耗活力"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "chat",
    },

    ["silver"] = {
        explain = "银币流水",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "val", ["desc"] = "变化值"}, {["id"] = "old_val", ["desc"] = "原有值"}, {["id"] = "now_val", ["desc"] = "当前值"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "silver",
    },

    ["gold"] = {
        explain = "金币流水",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "val", ["desc"] = "变化值"}, {["id"] = "old_val", ["desc"] = "原有值"}, {["id"] = "now_val", ["desc"] = "当前值"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "gold",
    },

    ["goldcoin"] = {
        explain = "元宝流水",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "val", ["desc"] = "变化值"}, {["id"] = "old_val", ["desc"] = "原有值"}, {["id"] = "now_val", ["desc"] = "当前值"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "goldcoin",
    },

    ["rpgoldcoin"] = {
        explain = "代元宝流水",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "val", ["desc"] = "变化值"}, {["id"] = "old_val", ["desc"] = "原有值"}, {["id"] = "now_val", ["desc"] = "当前值"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "rpgoldcoin",
    },

    ["item"] = {
        explain = "道具明细记录",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "reason", ["desc"] = "原因"}, {["id"] = "itemid", ["desc"] = "物品id"}, {["id"] = "num", ["desc"] = "数量"}, {["id"] = "optype", ["desc"] = "进出标记"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "item",
    },

    ["summon_exp_book"] = {
        explain = "宠物使用经验丹",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "sname", ["desc"] = "宠物名称"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "old_grade", ["desc"] = "原等级"}, {["id"] = "now_grade", ["desc"] = "当前等级"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_exp_book",
    },

    ["summon_lift_book"] = {
        explain = "宠物使用寿命丹",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "sname", ["desc"] = "宠物名称"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "old_life", ["desc"] = "原寿命"}, {["id"] = "now_life", ["desc"] = "当前寿命"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_lift_book",
    },

    ["summon_reset_ql"] = {
        explain = "宠物潜力重置",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "sname", ["desc"] = "宠物名称"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "optype", ["desc"] = "操作类型"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_reset_ql",
    },

    ["summon_wash"] = {
        explain = "宠物洗点",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "sname", ["desc"] = "宠物名称"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_wash",
    },

    ["summon_combine"] = {
        explain = "宠物合成",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "targetsid", ["desc"] = "合成宠物ID"}, {["id"] = "sid1", ["desc"] = "宠物1"}, {["id"] = "sid2", ["desc"] = "宠物2"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_combine",
    },

    ["summon_skill"] = {
        explain = "宠物技能",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "optype", ["desc"] = "操作类型"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_skill",
    },

    ["summon_py"] = {
        explain = "宠物培养",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "tracno", ["desc"] = "宠物ID"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "summon_py",
    },

    ["partner_zm"] = {
        explain = "伙伴招募",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "partner", ["desc"] = "伙伴id"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "currency", ["desc"] = "消耗货币"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "partner_zm",
    },

    ["partner_sj"] = {
        explain = "伙伴升级",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "partner", ["desc"] = "伙伴id"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "partner_sj",
    },

    ["partner_jj"] = {
        explain = "伙伴进阶",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "partner", ["desc"] = "伙伴id"}, {["id"] = "star", ["desc"] = "星级"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "partner_jj",
    },

    ["fmt_xx"] = {
        explain = "学习阵法",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "fmt", ["desc"] = "阵法类型"}, {["id"] = "citem", ["desc"] = "使用物品"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "fmt_xx",
    },

    ["fmt_set"] = {
        explain = "设置阵法",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "fmt", ["desc"] = "阵法类型"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "fmt_set",
    },

    ["ride_add"] = {
        explain = "获得坐骑",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "ride", ["desc"] = "获得坐骑"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "ride_add",
    },

    ["ride_sj"] = {
        explain = "坐骑升级",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "old_level", ["desc"] = "原等级"}, {["id"] = "new_level", ["desc"] = "新等级"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "ride_sj",
    },

    ["behavior"] = {
        explain = "新手10分钟",
        log_format = {{["id"] = "account_id", ["desc"] = "账号ID"}, {["id"] = "role_id", ["desc"] = "角色ID"}, {["id"] = "app_channel", ["desc"] = "渠道"}, {["id"] = "sub_channel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "udid", ["desc"] = "设备ID"}, {["id"] = "behavior_type", ["desc"] = "行为类型"}, {["id"] = "behavior_name", ["desc"] = "行为名称"}, {["id"] = "behavior_status", ["desc"] = "行为状态"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "behavior",
    },

    ["colorsys"] = {
        explain = "染色系统",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "color", ["desc"] = "颜色"}, {["id"] = "szid", ["desc"] = "时装id"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "colorsys",
    },

    ["shizhuang"] = {
        explain = "时装",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "szid", ["desc"] = "时装id"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "shizhuang",
    },

    ["yunying"] = {
        explain = "运营活动",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "hdid", ["desc"] = "系统"}, {["id"] = "hdname", ["desc"] = "系统名字"}, {["id"] = "grade", ["desc"] = "等级"}, {["id"] = "info", ["desc"] = "信息"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "yunying",
    },

    ["huodong"] = {
        explain = "日常活动",
        log_format = {{["id"] = "account", ["desc"] = "账号ID"}, {["id"] = "pid", ["desc"] = "角色ID"}, {["id"] = "channel", ["desc"] = "渠道"}, {["id"] = "subchannel", ["desc"] = "子渠道"}, {["id"] = "server", ["desc"] = "大区"}, {["id"] = "ip", ["desc"] = "IP"}, {["id"] = "address", ["desc"] = "地区"}, {["id"] = "time", ["desc"] = "时间"}, {["id"] = "hdid", ["desc"] = "系统"}, {["id"] = "hdname", ["desc"] = "系统名字"}, {["id"] = "grade", ["desc"] = "等级"}, {["id"] = "info", ["desc"] = "信息"}, {["id"] = "born_server", ["desc"] = "初始服务器"}},
        subtype = "huodong",
    },

}
