-- ./excel/log/mail.xlsx
return {

    ["add_mail"] = {
        explain = "添加邮件",
        log_format = {["attach"] = {["id"] = "attach", ["desc"] = "附件"}, ["mail_time"] = {["id"] = "mail_time", ["desc"] = "邮件时间"}, ["mail_title"] = {["id"] = "mail_title", ["desc"] = "邮件标题"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "add_mail",
    },

    ["del_mail"] = {
        explain = "删除邮件",
        log_format = {["mail_time"] = {["id"] = "mail_time", ["desc"] = "邮件时间"}, ["mail_title"] = {["id"] = "mail_title", ["desc"] = "邮件标题"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}},
        subtype = "del_mail",
    },

    ["rec_mail"] = {
        explain = "领取附件",
        log_format = {["attach"] = {["id"] = "attach", ["desc"] = "附件"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["grade"] = {["id"] = "grade", ["desc"] = "等级"}, ["mail_time"] = {["id"] = "mail_time", ["desc"] = "邮件时间"}, ["mail_title"] = {["id"] = "mail_title", ["desc"] = "邮件标题"}, ["name"] = {["id"] = "name", ["desc"] = "玩家名字"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["show_id"] = {["id"] = "show_id", ["desc"] = "显示id"}},
        subtype = "rec_mail",
    },

}
