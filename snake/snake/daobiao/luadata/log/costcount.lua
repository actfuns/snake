-- ./excel/log/costcount.xlsx
return {

    ["rest_gold"] = {
        explain = "金币剩余",
        log_format = {["grade"] = {["id"] = "grade", ["desc"] = "等级段"}, ["server"] = {["id"] = "server", ["desc"] = "服务器编号"}, ["value"] = {["id"] = "value", ["desc"] = "值"}},
        subtype = "rest_gold",
    },

    ["rest_silver"] = {
        explain = "银币剩余",
        log_format = {["grade"] = {["id"] = "grade", ["desc"] = "等级段"}, ["server"] = {["id"] = "server", ["desc"] = "服务器编号"}, ["value"] = {["id"] = "value", ["desc"] = "值"}},
        subtype = "rest_silver",
    },

    ["rest_goldcoin"] = {
        explain = "元宝剩余",
        log_format = {["grade"] = {["id"] = "grade", ["desc"] = "等级段"}, ["server"] = {["id"] = "server", ["desc"] = "服务器编号"}, ["value"] = {["id"] = "value", ["desc"] = "值"}},
        subtype = "rest_goldcoin",
    },

}
