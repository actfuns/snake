-- ./excel/log/behavior.xlsx
return {

    ["behavior"] = {
        explain = "玩家行为",
        log_format = {["account"] = {["id"] = "account", ["desc"] = "账号"}, ["channel"] = {["id"] = "channel", ["desc"] = "渠道"}, ["device"] = {["id"] = "device", ["desc"] = "手机型号"}, ["error"] = {["id"] = "error", ["desc"] = "异常类型"}, ["mac"] = {["id"] = "mac", ["desc"] = "设备号"}, ["net"] = {["id"] = "net", ["desc"] = "网络类型"}, ["operate"] = {["id"] = "operate", ["desc"] = "操作步骤"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["platform"] = {["id"] = "platform", ["desc"] = "平台"}, ["time"] = {["id"] = "time", ["desc"] = "操作时间"}},
        subtype = "behavior",
    },

}
