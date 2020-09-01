-- ./excel/log/pay.xlsx
return {

    ["payerror"] = {
        explain = "支付失败日志",
        log_format = {["cbdata"] = {["id"] = "cbdata", ["desc"] = "回调数据"}, ["order_id"] = {["id"] = "order_id", ["desc"] = "订单号"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["request"] = {["id"] = "request", ["desc"] = "请求信息"}, ["server"] = {["id"] = "server", ["desc"] = "所在服务器"}, ["type"] = {["id"] = "type", ["desc"] = "错误类型"}},
        subtype = "payerror",
    },

    ["backendpay"] = {
        explain = "后台充值",
        log_format = {["amount"] = {["id"] = "amount", ["desc"] = "数量"}, ["pid"] = {["id"] = "pid", ["desc"] = "玩家id"}, ["productkey"] = {["id"] = "productkey", ["desc"] = "付费项"}, ["type"] = {["id"] = "type", ["desc"] = "充值类型"}},
        subtype = "backendpay",
    },

}
