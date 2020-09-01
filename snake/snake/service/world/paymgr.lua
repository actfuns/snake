-- import module

local global = require "global"
local res = require "base.res"
local cjson = require "cjson"
local record = require "public.record"
local router = require "base.router"
local serverdefines = require "public.serverdefines"

local serverinfo = import(lualib_path("public.serverinfo"))
local analy = import(lualib_path("public.dataanaly"))

function NewPayMgr(...)
    return CPayMgr:New(...)
end

function NewPayCb(...)
    return CPayCb:New(...)
end

CPayMgr = {}
CPayMgr.__index = CPayMgr
inherit(CPayMgr, logic_base_cls())

function CPayMgr:New()
    local o = super(CPayMgr).New(self)
    o.m_oPayCb = NewPayCb()
    return o
end

function CPayMgr:GetCallBackUrl()
    return string.format("https://%s/demisdkcb/paycb", serverinfo.get_cs_domain())
end

function CPayMgr:TryPay(oPlayer, sProductKey, iAmount, sPayWay, bIsDemi)
    if not serverinfo.get_cs_domain() then
        record.warning("try pay error: no callback url")
        return
    end
    if not is_gs_server() then
        record.warning("not gs couldn't pay")
        return
    end
    local mData = assert(res["daobiao"]["pay"][sProductKey], string.format("error product key %s %s", oPlayer:GetPid(),sProductKey))
    local sProductName = mData["name"]
    local sProductDesc = mData["desc"]
    local iValue = mData["value"]
    local iTotValue = iValue * iAmount

    local mExt = {
        account = oPlayer:GetAccount()
    }
    local mRequest = {
        appId = global.oDemiSdk:GetAppId(),
        p = oPlayer:GetChannel(),
        uid = oPlayer:GetChannelUuid(),
        roleId = oPlayer:GetPid(),
        serverId = get_server_id(oPlayer:GetBornServerKey()),
        productId = sProductKey,
        productName = sProductName,
        productDesc = sProductDesc,
        amount = iAmount,
        cent = iTotValue,
        ext = cjson.encode(mExt),
        callbackURL = self:GetCallBackUrl(),  -- 回调地址
        imei = oPlayer:GetIMEI(),  -- IMEI号，获取不到传设备编号
        mac = oPlayer:GetMac(),   -- 机器mac地址
        platform = oPlayer:GetPlatform(),  -- 0:未知，1:安卓，2:越狱ios,3:非越狱ios 4.windows
        accountType = 6,  -- 0:未知,1:手机帐号,2:邮件帐号,3:设备登录, 4:QQ登录,5:微信登录，6:自由账号
        age = 20,
        brand = oPlayer:GetDevice(), -- 机型：如 MI2S
        country = "",  -- 国家，不传默认中国
        province = "",
        gender = 1,  -- 玩家性别 1:男,0:女
        language = "",
        netType = 0,  -- 网络类型 0:未知,1:wifi, 2:2g, 3:3g, 4:4g, 5:other
        operators = 0,  -- 运营商，0:未知,1:电信, 2:移动, 3:联通, 4:网通
        osVersion = oPlayer:GetClientOs(),  -- 操作系统版本
        resolution = "",  -- 分辨率
        currencyType = "",  -- 货币类型，不传默认人民币cny
        roleClass = oPlayer:GetSchool(),
        roleRace = oPlayer:GetRace(),
        grade = oPlayer:GetGrade(),
        payWay = sPayWay,  -- 支付方式或者渠道
        ip = oPlayer:GetIP(),
        is_demi = bIsDemi,
    }

    router.Send("cs", string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT)), "common", "TryPay", {
        request = mRequest,
        req_server = get_server_tag()
    })
end

function CPayMgr:TryPayCb(pid, mInfo)
    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if not oPlayer then
        return
    end
    oPlayer:Send("GS2CPayInfo", {
        order_id = tostring(mInfo.order_id),
        product_key = mInfo.product_key,
        product_amount = mInfo.product_amount,
        product_value = mInfo.product_value,
        callback_url = mInfo.callback_url
    })
end

function CPayMgr:PaySuccessedCb(iPid, lInfos)
    global.oWorldMgr:LoadPrivacy(iPid, function (o)
        self:_PaySuccessedCb1(o, lInfos)
    end)
end

function CPayMgr:_PaySuccessedCb1(o, lInfos)
    if not o then
        return
    end

    local iPid = o:GetPid()
    local lOrderIds = {}
    for _, mOrders in ipairs(lInfos) do
        local iOrderId = mOrders.orderid
        if not o:IsDealedOrder(iOrderId) then
            local br, m = safe_call(self.DealSucceedOrder, self, iPid, mOrders)
            if br then
                o:AddDealedOrder(iOrderId)
                table.insert(lOrderIds, iOrderId)
                safe_call(self.PaySuccessLog, self, iPid, mOrders)
            end
        else
            table.insert(lOrderIds, iOrderId)
        end
    end

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        o:AddSaveMerge(oPlayer)
    end
    if lOrderIds and next(lOrderIds) then
        router.Send("cs", string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT)), "common", "MarkOrderAsDealed", {
            orderids=lOrderIds,
        })
    end
end

function CPayMgr:DealSucceedOrder(iPid, mOrders)
    local sProductKey = mOrders.product_key
    local iAmount = tonumber(mOrders.product_amount)

    local mData = assert(res["daobiao"]["pay"][sProductKey], string.format("deal order error product key %s", sProductKey))
    local sFunc = mData["func"]
    local lArgs = mData["args"]
    local func = assert(self.m_oPayCb[sFunc], string.format("deal order error func %s", sFunc))
    func(self.m_oPayCb, iPid, iAmount, lArgs, sProductKey)
end

function CPayMgr:DealUntreatedOrder(oPlayer)
    router.Send("cs", string.format(".pay%s", math.random(1, PAY_SERVICE_COUNT)), "common", "DealUntreatedOrder", {
        pid=oPlayer:GetPid(),
        server=get_server_tag()
    })
end

function CPayMgr:PaySuccessLog(iPid, mOrders)
    safe_call(self.AnalyPayLog, self, iPid, mOrders)
end

-- 数据中心log
function CPayMgr:AnalyPayLog(iPid, mOrders)
    local mAnalyLog = {}
    mAnalyLog["recharge_num"] = mOrders["amount"] or 1
    mAnalyLog["product_id"] = mOrders["product_key"]
    mAnalyLog["product_cnt"] = mOrders["product_amount"]
    mAnalyLog["order_id"] = mOrders["orderid"]

    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        mAnalyLog = table_combine(mAnalyLog, oPlayer:BaseAnalyInfo())
        analy.log_data("Recharge_1", mAnalyLog)
    else
        oWorldMgr:LoadProfile(iPid, function (oProfile)
            if oProfile then
                mAnalyLog = table_combine(mAnalyLog, oProfile:BaseAnalyInfo())
                analy.log_data("Recharge_1", mAnalyLog)
            end
        end)
    end
end

function CPayMgr:ClientQrpayScan(iPid, sTransferInfo)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oPlayer:Send("GS2CQrpayScan", {transfer_info = sTransferInfo})
    end
end

CPayCb = {}
CPayCb.__index = CPayCb
inherit(CPayCb, logic_base_cls())

function CPayCb:New()
    local o = super(CPayCb).New(self)
    return o
end

function CPayCb:pay_for_gold(iPid, iAmount, lArgs, sProductKey)
    local oHuodong = global.oHuodongMgr:GetHuodong("charge")
    assert(oHuodong, "ERROR not charge object")

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oHuodong:PayForGold(oPlayer, table.unpack(lArgs), sProductKey)
    else
        global.oPubMgr:OnlineExecute(iPid, "PayForGold", {iAmount, lArgs, sProductKey})
    end
end

function CPayCb:pay_for_huodong_charge(iPid, iAmount, lArgs, sProductKey)
    local oHuodong = global.oHuodongMgr:GetHuodong("charge")
    assert(oHuodong, "ERROR not charge object")

    local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
    if oPlayer then
        oHuodong:OnCharge(oPlayer, iAmount, table.unpack(lArgs), sProductKey)
    else
        global.oPubMgr:OnlineExecute(iPid, "PayForHuodongCharge", {iAmount, lArgs, sProductKey})
    end
end
