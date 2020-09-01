--import module
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"

function TestOP(oPlayer, iFlag , mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local pid = oPlayer:GetPid()
    mArgs = mArgs or {}
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：teamop 参数 {参数,参数,...}")
        return
    end
    local mCommand={
        "100 指令查看",
        "101 设置指定格子道具为绑定\nitemop 101 {pos = 1}"
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
    elseif iFlag == 101 then
        local pos = mArgs.pos
        if not pos then 
            oNotifyMgr:Notify(pid,"参数格式不合法")
            return
        end
        pos = pos+100
        local itemobj = oPlayer.m_oItemCtrl:GetItem(pos) 
        if not itemobj then
            oNotifyMgr:Notify(pid,"此格子无道具")
            return
        end
        itemobj:Bind(pid)
        itemobj:Refresh()
        oNotifyMgr:Notify(pid,"绑定成功")
    elseif iFlag == 102 then
        local iPos = mArgs.pos
        local iLast = mArgs.last
        if not iPos or not iLast then 
            oPlayer:NotifyMessage("参数格式不合法")
            return
        end

        iPos = 100 + iPos
        local oWenShi = oPlayer.m_oItemCtrl:GetItem(iPos)
        if not oWenShi or oWenShi:ItemType() ~= "wenshi" then
            oPlayer:NotifyMessage("纹饰不存在")
            return
        end
        oWenShi:SetData("last", iLast)
        oWenShi:Refresh()
        oPlayer:NotifyMessage("set成功")
    elseif iFlag == 201 then
        local itemobj = oPlayer.m_oItemCtrl:GetItem(101) 
        if not itemobj then
            oNotifyMgr:Notify(pid,"此格子无道具")
            return
        end
        local oEquip = oPlayer.m_oItemCtrl:GetItem(4)
        if not oEquip then
            oNotifyMgr:Notify(pid,"此格子无道具")
            return
        end
        global.oItemHandler:EquipAddHunShi(oPlayer,oEquip:ID(),itemobj:ID(),1)
    end
end