-- ./excel/log/task.xlsx
return {

    ["add_task"] = {
        explain = "接任务",
        log_format = {["back_data"] = {["id"] = "back_data", ["desc"] = "恢复任务数据"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "add_task",
    },

    ["remove_task"] = {
        explain = "删任务",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["is_done"] = {["id"] = "is_done", ["desc"] = "是否完成"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "remove_task",
    },

    ["reward"] = {
        explain = "任务领奖",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["owner"] = {["id"] = "owner", ["desc"] = "任务属主"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "reward",
    },

    ["promote_chapter"] = {
        explain = "主线章节推进",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_chapter"] = {["id"] = "new_chapter", ["desc"] = "新章号"}, ["new_section"] = {["id"] = "new_section", ["desc"] = "新节号"}, ["old_chapter"] = {["id"] = "old_chapter", ["desc"] = "旧章号"}, ["old_section"] = {["id"] = "old_section", ["desc"] = "旧节号"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "promote_chapter",
    },

    ["gain_chapter_piece"] = {
        explain = "获得主线章节碎片",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["chapter"] = {["id"] = "chapter", ["desc"] = "章节"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_piece"] = {["id"] = "new_piece", ["desc"] = "新碎片"}, ["now_pieces"] = {["id"] = "now_pieces", ["desc"] = "章节全部碎片"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "gain_chapter_piece",
    },

    ["reward_chapter"] = {
        explain = "领取主线章节奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["chapter"] = {["id"] = "chapter", ["desc"] = "章节"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "reward_chapter",
    },

    ["shimen_done"] = {
        explain = "师门任务完成",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["done_cnt_daily"] = {["id"] = "done_cnt_daily", ["desc"] = "日完成数"}, ["done_cnt_weekly"] = {["id"] = "done_cnt_weekly", ["desc"] = "周完成数"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["ring"] = {["id"] = "ring", ["desc"] = "任务环数"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "shimen_done",
    },

    ["shimen_weekly_reward_done"] = {
        explain = "师门周奖励领取",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "shimen_weekly_reward_done",
    },

    ["yibao_help"] = {
        explain = "异宝协助",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["owner"] = {["id"] = "owner", ["desc"] = "任务属主"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "yibao_help",
    },

    ["yibao_compen_reward"] = {
        explain = "异宝补偿奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["owner"] = {["id"] = "owner", ["desc"] = "任务属主"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "yibao_compen_reward",
    },

    ["yibao_help_cost"] = {
        explain = "异宝协助消耗",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["silver"] = {["id"] = "silver", ["desc"] = "银两"}},
        subtype = "yibao_help_cost",
    },

    ["yibao_help_share_reward"] = {
        explain = "异宝协助奖励共享",
        log_format = {["items"] = {["id"] = "items", ["desc"] = "物品"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "yibao_help_share_reward",
    },

    ["yibao_help_gather_rob_reward"] = {
        explain = "异宝协助交物夺奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["owner"] = {["id"] = "owner", ["desc"] = "任务属主"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "yibao_help_gather_rob_reward",
    },

    ["new_everyday_task"] = {
        explain = "每日必做刷天",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_dayno"] = {["id"] = "new_dayno", ["desc"] = "现在dayno"}, ["old_dayno"] = {["id"] = "old_dayno", ["desc"] = "上次dayno"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskids"] = {["id"] = "taskids", ["desc"] = "新的每日任务id列表"}},
        subtype = "new_everyday_task",
    },

    ["runring_help_share_reward"] = {
        explain = "跑环协助共享奖励",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["owner"] = {["id"] = "owner", ["desc"] = "任务属主"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["reward"] = {["id"] = "reward", ["desc"] = "奖励"}, ["rewardid"] = {["id"] = "rewardid", ["desc"] = "奖励表id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskid"] = {["id"] = "taskid", ["desc"] = "任务id"}},
        subtype = "runring_help_share_reward",
    },

    ["new_xuanshang_task"] = {
        explain = "悬赏刷天",
        log_format = {["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["new_dayno"] = {["id"] = "new_dayno", ["desc"] = "现在dayno"}, ["old_dayno"] = {["id"] = "old_dayno", ["desc"] = "上次dayno"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}, ["taskids"] = {["id"] = "taskids", ["desc"] = "新的每日任务id列表"}},
        subtype = "new_xuanshang_task",
    },

}
