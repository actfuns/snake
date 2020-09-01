local global = require "global"
local res = require "base.res"

Commands = {}       --指令函数
Helpers = {}        --帮助信息
Opens = {}          --对外开放

Opens.sendmail = true
Helpers.sendmail = {
    "给自己发邮件",
    "sendmail 导表id 是否系统 物品信息 宠物信息 邮件数量 银币",
    "sendmail 2 1 {{sid='1001(Value=500)',cnt=1},{sid=10002,cnt=2}} {sid=1001,idx=1} 1",
}
function Commands.sendmail(oMaster,idx,iSys,iteminfo, summoninfo, cnt, iSilver)
    local oMailMgr = global.oMailMgr
    local oNotifyMgr = global.oNotifyMgr
    local pid = 0
    local mData, name = oMailMgr:GetMailInfo(idx)
    local mInfo = table_copy(mData)
    if not mData then
        oNotifyMgr:Notify(oMaster:GetPid(), "邮件导表id错误")
        return
    end
    if iSys ~= 1 then
        pid, name = oMaster:GetPid(), oMaster:GetName()
    end
    cnt = cnt or 1
    for i=1,cnt do
        local items = {}
        if iteminfo and next(iteminfo) then
            for _,info in ipairs(iteminfo) do
                -- 1002(Value=%d)
                local oTmpItem = global.oItemLoader:ExtCreate(info["sid"])
                if info["cnt"] then
                    oTmpItem:SetAmount(info["cnt"])
                end
                table.insert(items, oTmpItem)
            end
        end
        local summons = {}
        if summoninfo and next(summoninfo) then
            local res = require "base.res"
            local loadsummon = import(service_path("summon.loadsummon"))
            if not summoninfo["sid"] or not summoninfo["idx"] then
                oNotifyMgr:Notify(oMaster:GetPid(), "宠物信息参数错误")
                return
            end
            local sid = summoninfo["sid"]
            local idx = summoninfo["idx"]
            if not res["daobiao"]["summon"]["fixedproperty"][idx] then
                oNotifyMgr:Notify(oMaster:GetPid(), "宠物固定属性导标id错误")
                return
            end
            local oSummon = loadsummon.CreateFixedPropSummon(sid, idx)
            table.insert(summons, oSummon)
        end
        mInfo.createtime = get_time() - i
        oMailMgr:SendMail(pid, name, oMaster:GetPid(), mInfo, iSilver or 0, items, summons)
    end
    oNotifyMgr:Notify(oMaster:GetPid(), "发送邮件成功")
end

Opens.clearmail = true
Helpers.clearmail = {
    "清空邮箱",
    "clearmail",
    "clearmail",
}
function Commands.clearmail(oMaster)
    local oMailMgr = global.oMailMgr
    oMailMgr:ClearMailBox(oMaster:GetPid())
    oMaster:NotifyMessage("清空邮箱")
end


