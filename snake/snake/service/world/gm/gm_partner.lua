local global = require "global"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放


Opens.partnerop = true
Helpers.partnerop = {
    "玩家测试指令",
    "partnerop iFlag mArgs",
    "partnerop 101 ",
}
function Commands.partnerop(oMaster,iFlag,mArgs)
    local partnertest = import(service_path("partner/test"))
    partnertest.TestOP(oMaster,iFlag,mArgs)
end


Opens.addpartner = true
Helpers.addpartner = {
    "添加伙伴",
    "addpartner 导表id",
    "addpartner 10001",
}
function Commands.addpartner(oMaster, sid)
    local oNotifyMgr = global.oNotifyMgr
    local oPartner = oMaster.m_oPartnerCtrl:QueryPartner(sid)
    if oPartner then
        oNotifyMgr:Notify(oMaster:GetPid(), "伙伴已存在")
        return
    end

    local loadpartner = import(service_path("partner/loadpartner"))
    oPartner = loadpartner.CreatePartner(sid, oMaster:GetPid())
    if oPartner then
        oPartner:Setup()
        if not oMaster.m_oPartnerCtrl:AddPartner(oPartner) then
            baseobj_delay_release(oPartner)
        end
    end
end

Opens.addpartnerexp = true
Helpers.addpartnerexp = {
    "添加伙伴经验",
    "addpartnerexp 导表id 经验值",
    "addpartnerexp 10001 100",
}
function Commands.addpartnerexp(oMaster, sid, iVal)
    local oNotifyMgr = global.oNotifyMgr
    local oPartner = oMaster.m_oPartnerCtrl:QueryPartner(sid)
    if not oPartner then
        oNotifyMgr:Notify(oMaster:GetPid(), "伙伴不存在，请先添加")
        return
    end
    oPartner:RewardExp(iVal)
end

Opens.partnerupgrade = true
Helpers.partnerupgrade = {
    "伙伴经验升级",
    "partnerupgrade ipn, val",
    "partnerupgrade 10001,  100",
}
function Commands.partnerupgrade(oMaster, ipn, val)
    if type(ipn) ~= "number"  or type(val) ~= "number" then
        return
    end

    local oNotifyMgr = global.oNotifyMgr

    local oPartner = oMaster.m_oPartnerCtrl:GetPartner(ipn)
    if not oPartner then
        oNotifyMgr:Notify(oMaster:GetPid(), "未拥有此伙伴")
        return
    end

    oPartner:RewardExp(val)
end


function Commands.init_robot_partner(oMaster)
    local loadpartner = import(service_path("partner.loadpartner"))
    oMaster:RewardExp(5056476,"gm", {bEffect = false})
    local lPartners = {10001,10002,10003,10004}
    for _, sid in ipairs(lPartners) do
        local oNewPartner = loadpartner.CreatePartner(sid, oMaster:GetPid())
        oNewPartner:Setup()
        oMaster.m_oPartnerCtrl:AddPartner(oNewPartner)
    end
    oMaster.m_oPartnerCtrl:RefreshAllLineupInfo()
end