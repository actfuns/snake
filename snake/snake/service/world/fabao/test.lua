--import module
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"

function TestOp(oPlayer, iFlag , mArgs)
    local oNotifyMgr = global.oNotifyMgr
    local oChatMgr=global.oChatMgr
    local pid = oPlayer:GetPid()
    mArgs = mArgs or {}
    if type(mArgs) ~=  "table" then
        oNotifyMgr:Notify(pid,"参数格式不合法,格式：fabaoop 参数 {参数,参数,...}")
        return
    end
    local mCommand={
        "100 指令查看",
    }
    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
        oNotifyMgr:Notify(pid,"请看消息频道咨询指令")
    elseif iFlag == 200 then
        local mFaBao = oPlayer.m_oFaBaoCtrl.m_mFaBao
        print("amount = ",table_count(mFaBao))
        for id,fabaoobj in pairs(mFaBao) do
            local skobj = fabaoobj:GetJXSkill()
            print(fabaoobj:ID(),fabaoobj:Fid(),fabaoobj:Level(),fabaoobj:EquipPos(),fabaoobj:Exp(),fabaoobj:GetXianLing(),fabaoobj.m_mPromote,skobj:IsOpen(),skobj:Level(),skobj:Exp())
        end
        print(oPlayer.m_oFaBaoCtrl.m_mEquipFaBao)
    elseif iFlag == 201 then -- fabaoop 201 {op=2,fabao=1}
        global.oFaBaoMgr:ComBineFaBao(oPlayer,mArgs.op,mArgs.fabao)
    elseif iFlag == 202 then
        global.oFaBaoMgr:WieldFaBao(oPlayer,mArgs.id)
    elseif iFlag == 203 then
        global.oFaBaoMgr:UnWieldFaBao(oPlayer,mArgs.id)
    elseif iFlag == 204 then
        global.oFaBaoMgr:DeComposeFaBao(oPlayer,mArgs.id)
    elseif iFlag == 205 then
        local mFaBao = {}
        for id,fabaoobj in pairs(oPlayer.m_oFaBaoCtrl.m_mFaBao) do
            table.insert(mFaBao,fabaoobj)
        end
        for _,fabaoobj in ipairs(mFaBao) do
            oPlayer.m_oFaBaoCtrl:RemoveFaBao(fabaoobj:ID(),"gm")
        end
        oPlayer.m_oFaBaoCtrl.m_mEquipFaBao = {}
    elseif iFlag == 206 then
        global.oFaBaoMgr:UpGradeFaBao(oPlayer,mArgs.id)
    elseif iFlag == 207 then -- fabaoop 207 {id=,op=,attr=magic}
        global.oFaBaoMgr:XianLingFaBao(oPlayer,mArgs.id,mArgs.op,mArgs.attr)
    elseif iFlag == 208 then
        global.oFaBaoMgr:JueXingFaBao(oPlayer,mArgs.id)
    elseif iFlag == 209 then
        global.oFaBaoMgr:JueXingUpGradeFaBao(oPlayer,mArgs.id)
    elseif iFlag == 210 then
        global.oFaBaoMgr:JueXingHunFaBao(oPlayer,mArgs.id,mArgs.hun)
    end
end