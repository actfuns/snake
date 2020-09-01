local global = require "global"
local extend = require "base.extend"

local firstboutskillaction = import(service_path("action/firstboutskill"))
local gamedefines = import(lualib_path("public.gamedefines"))

local ACTION_ID = 100007

function NewWarAction(...)
    local o = CWarAction:New(...)
    o.m_iActionID = 100007
    return o
end

CWarAction = {}
CWarAction.__index = CWarAction
inherit(CWarAction, firstboutskillaction.CWarAction)

function CWarAction:DoAction(mInfo)
    local oWar = self:GetWar()
    local mSpeekData = mInfo.speek or {}
    mInfo.speek_enable = false

    local iCamp = 2
    local lMonster = oWar:GetWarriorList(iCamp)
    for _,oWarrior in ipairs(lMonster) do
        local iType = oWarrior:GetData("type")
        if iType == 10001 then -- 大师兄
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                CallNewMonster10001(oAction)
            end)
            oWarrior:AddFunction("OnAttacked",ACTION_ID,function (oAction,oAttack,oPerform,iDamage,mArgs)
                OnAttacked10001(oAction,oAttack,oPerform,iDamage,mArgs)
            end)
        elseif iType == 10004 then --剑道真意
            oWarrior:AddFunction("CalMagAttack",ACTION_ID,function (oAttack, oVictim, oPerform)
                return CalMagAttack10004(oAttack, oVictim, oPerform)
            end)
            oWarrior:AddFunction("CalPhyAttack",ACTION_ID,function (oAttack, oVictim, oPerform)
                return CalPhyAttack10004(oAttack, oVictim, oPerform)
            end)
        elseif iType == 10008 then -- 渊记
            oWarrior:AddFunction("OnBeforeAct",ACTION_ID,function (oAction)
                OnBeforeAct10008(oAction)
            end)
            oWarrior:AddFunction("OnImmuneDamage",ACTION_ID,function (oVictim,oAttack, oPerform,iDamage)
                OnImmuneDamage10008(oVictim,oAttack, oPerform,iDamage)
            end)
        elseif iType== 10009 then -- 剑道真意
            oWarrior.m_oBuffMgr:AddBuff(201, 99, {bForce=true})
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10009(oAction)
            end)
        elseif iType == 10010 then --真诀
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10010(oWarrior,mCmd)
                return cmd
            end)
        elseif iType== 10011 then -- 真意
            oWarrior.m_oBuffMgr:AddBuff(201, 99, {bForce=true})
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10011(oWarrior,mCmd)
                return cmd
            end)
        elseif iType == 10106 then --时未寒
            oWarrior:AddFunction("OnDead", ACTION_ID, function (oVictim, oAttack)
                OnDead10106(oVictim, oAttack)
            end)
        elseif iType == 10124 then --箭灵4
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10124(oWarrior,mCmd)
                return cmd
            end)
        elseif iType == 10120 then --后羿
            oWarrior:AddFunction("OnDead", ACTION_ID, function (oVictim, oAttack)
                OnDead10120(oVictim, oAttack)
            end)
        elseif iType == 10130 then --时未寒
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10130(oWarrior,mCmd)
                return cmd
            end)
        elseif iType == 10045 then --命运
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10045(oWarrior,mCmd)
                return cmd
            end)
        elseif iType == 10060 then--白素贞
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10060(oWarrior,mCmd)
                return cmd
            end)
        elseif iType == 10088 then --恩因果
            oWarrior:AddFunction("OnAttacked",ACTION_ID,function (oAction,oAttack,oPerform,iDamage,mArgs)
                OnAttacked10088(oAction,oAttack,oPerform,iDamage,mArgs)
            end)
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10088(oAction)
            end)
        elseif iType == 10089 then --怨因果
            oWarrior:AddFunction("OnAttacked",ACTION_ID,function (oAction,oAttack,oPerform,iDamage,mArgs)
                OnAttacked10089(oAction,oAttack,oPerform,iDamage,mArgs)
            end)
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10089(oAction)
            end)
        elseif iType == 10062 then 
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10062(oWarrior,mCmd)
                return cmd
            end)
            oWarrior:AddFunction("OnBoutEnd",ACTION_ID,function (oAction)
                OnBoutEnd10062(oAction)
            end)
        elseif iType == 10083 then
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10083(oWarrior,mCmd)
                return cmd
            end)
        end
    end
end

function CallNewMonster10001(oAction)
    if oAction:IsDead() then return end
    local mFriend = oAction:GetFriendList()
    local iCutCnt = 0
    if #mFriend>=4 then
        return
    end
    local oWar = oAction:GetWar()
    local oPerform = oAction:GetPerform(4277)
    if oPerform then
        oPerform:PerformOnce(oAction,{})
    end
    
    local mAllMonsterInfo = oAction:GetData("all_monster", {})
    local iMonster = 10003
    if next(mAllMonsterInfo) then
        for i = 1,3 do
            local mMonster = table_copy(mAllMonsterInfo[iMonster]) 
            local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
        end
    end
end

function OnAttacked10001(oVictim,oAttack,oPerform,iDamage,mArgs)
    if oPerform then
        return
    end
    mArgs = mArgs or {}
    if mArgs.bNotBack or mArgs.hit_back then 
        return 
    end
    if iDamage<=0 then 
        return 
    end
    global.oActionMgr:WarNormalAttack(oVictim, oAttack, {bNotBack=true,hit_back=true})
end


function CalMagAttack10004(oAttack, oVictim, oPerform)
    local iExtraValue = 0
    if oAttack:IsDead() then
        return iExtraValue
    end
    local iHP = oAttack:GetHp()
    local iMaxHP = oAttack:GetMaxHp()
    if iHP<iMaxHP*3/10 then
        --print("CalMagAttack10004")
        iExtraValue = math.floor(oAttack:GetBaseAttr("mag_attack") * 0.5)
    end
    return iExtraValue
end

function CalPhyAttack10004(oAttack, oVictim, oPerform)
    local iExtraValue = 0
    if oAttack:IsDead() then
        return iExtraValue
    end
    local iHP = oAttack:GetHp()
    local iMaxHP = oAttack:GetMaxHp()
    if iHP<iMaxHP*3/10 then
        --print("CalPhyAttack10004")
        iExtraValue = math.floor(oAttack:GetBaseAttr("phy_attack") * 0.5)
    end
    return iExtraValue
end

function OnBeforeAct10008(oAction)
    local oWar = oAction:GetWar()
    if not oWar then return end
    if oAction:IsDead() then return end
    local mFriend = oAction:GetFriendList()
    if #mFriend<=0 then
        return
    end
    local lDelWarrior = {}
    for _ , oWarrior in ipairs(mFriend) do
        if oWarrior:GetData("type") == 10010 then --真诀
            table.insert(lDelWarrior,oWarrior)
        end
    end
    if #lDelWarrior <= 0 then
        --print("OnBeforeAct10008-1",oAction:GetName())
        return
    end
    --print("OnBeforeAct10008-2",oAction:GetName())
    local oDelWarrior = extend.Random.random_choice(lDelWarrior)
    local oPerform = oAction:GetPerform(4279)
    if oPerform then
        oPerform:PerformOnce(oAction,{oDelWarrior})
    end
    
    oWar:KickOutWarrior(oDelWarrior,0)
    local oPerform = oAction:GetPerform(3022) 
    if oPerform then
        if not oPerform.m_iFloor then
            oPerform.m_iFloor = 0
        end
        oPerform.m_iFloor  = oPerform.m_iFloor +1
        local mCmd = {
            war_id = oAction:GetWarId(),
            wid = oAction:GetWid(),
            content = "参阅真诀，我的一剑西来又提升了一重",
        }
        oWar:SendAll("GS2CWarriorSpeek", mCmd)
    end
end

function OnImmuneDamage10008(oVictim,oAttack, oPerform,iDamage)
    local mFriend = oVictim:GetFriendList()
    for _,oWarrior in ipairs(mFriend) do
        if oWarrior.m_oBuffMgr:HasBuff(201) then
            oVictim:SetBoutArgs("immune_damage", true)
            --print("OnImmuneDamage10008",oVictim:GetName())
            break
        end
    end
    return iDamage
end

function ChangeCmd10011(oAction,mCmd)
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "skill" then
        return mCmd
    end
    if mCmdData.skill_id ~= 1404 then
        return mCmd
    end
    if oAction.m_oBuffMgr:HasBuff(127) then
        local iPerform = 1405
        local oPerform = oAction:GetPerform(iPerform)
        local mNewCmd = {}
        if oPerform then
            --print("ChangeCmd10011-1",oAction:GetName())
            mNewCmd.cmd = "skill"
            mNewCmd.data = {}
            mNewCmd.data.action_wlist = mCmdData.action_wlist
            mNewCmd.data.skill_id = iPerform
            mNewCmd.data.select_wlist={}
            table.insert(mNewCmd.data.select_wlist,oPerform:ChooseAITarget(oAction))
            return mNewCmd
        else
            local lVictim = oAction:GetEnemyList()
            if #lVictim >0 then
                --print("ChangeCmd10011-2",oAction:GetName())
                local oVictim = extend.Random.random_choice(lVictim)
                mNewCmd.cmd = "normal_attack"
                mNewCmd.data = {}
                mNewCmd.data.action_wlist = mCmdData.action_wlist
                mNewCmd.data.select_wid = oVictim:GetWid()
                return mNewCmd
            else
                --print("ChangeCmd10011-3",oAction:GetName())
                return mCmd
            end
        end
    end
end

function OnBoutEnd10009(oAction)
    if oAction:IsDead() then return end
    local mFriend = oAction:GetFriendList()
    local bCallMonster = false
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetData("type") == 10008 then
            local oPerform = oWarrior:GetPerform(3022) 
            if oPerform then
                local iFloor = oPerform.m_iFloor or 0
                if iFloor <4 then
                    bCallMonster =  true
                    break
                end
            end
        end
    end
    if not bCallMonster then
        --print("OnBoutEnd10009-1")
        return
    end
    --print("OnBoutEnd10009-2")
    local oPerform = oAction:GetPerform(4278)
    if oPerform then
        oPerform:PerformOnce(oAction,{})
    end
    local oWar = oAction:GetWar()
    local mAllMonsterInfo = oAction:GetData("all_monster", {})
    if mAllMonsterInfo[10010] then
        local mMonster = table_deep_copy(mAllMonsterInfo[10010]) 
        local oWarrior = oWar:AddNpcWarrior(2, mMonster, nil, 0, true)
        if oWarrior then
            local mTime = global.oActionMgr:GetNormalAttackTime(oAction)
            oWar:AddAnimationTime(mTime[1])
            oWarrior:AddFunction("ChangeCmd", ACTION_ID, function (oWarrior,mCmd)
                local cmd = ChangeCmd10010(oWarrior,mCmd)
                return cmd
            end)
        end
    end

end

function ChangeCmd10010(oAction,mCmd)
    local cmd = {}
    cmd.cmd = "defense"
    return cmd
end

function OnDead10106(oVictim,oAttack)
    if not oVictim or not oVictim:IsDead()  then
        return
    end
    local mFriend = oVictim:GetFriendList()
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetPerform(4263) and not oWarrior.m_oBuffMgr:HasBuff(221) and not oWarrior.m_oBuffMgr:HasBuff(207) then
            DoSpeek(oWarrior,"报仇！报仇！报仇！")
            oWarrior.m_oBuffMgr:AddBuff(221,99,{})
        elseif  oWarrior:GetPerform(4259) and not oWarrior.m_oBuffMgr:HasBuff(220)  and not oWarrior.m_oBuffMgr:HasBuff(207) then
            DoSpeek(oWarrior,"报仇！报仇！报仇！")
            oWarrior.m_oBuffMgr:AddBuff(220,99,{})
        end
    end
end


function DoSpeek(oWarrior, sContent,iFlag)
    if oWarrior:IsDead() then
        return
    end
    local oWar = oWarrior:GetWar()
    if not oWar then
        return
    end
    local mCmd = {
        war_id = oWarrior:GetWarId(),
        wid = oWarrior:GetWid(),
        content = sContent,
        flag = iFlag,
    }
    oWar:SendAll("GS2CWarriorSpeek", mCmd)
end

function ChangeCmd10124(oAction,mCmd)
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "skill" then
        return mCmd
    end
    if mCmdData.skill_id ~= 1402 then
        return mCmd
    end
    local mFriend  = oAction:GetFriendList()
    for _,oWarrior in ipairs(mFriend) do
        if oWarrior:GetName() == "杏黄旗" then
            local mNewCmd = {}
            mNewCmd.cmd = "skill"
            mNewCmd.data = {}
            mNewCmd.data.skill_id = 1041
            return mNewCmd
        end
    end
    return mCmd
end

function OnDead10120(oVictim,oAttack)
    if not oVictim or not oVictim:IsDead()  then
        return
    end
    local mFriend = oVictim:GetFriendList()
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetPerform(4263) and not oWarrior.m_oBuffMgr:HasBuff(221)  and not oWarrior.m_oBuffMgr:HasBuff(207) then
            DoSpeek(oWarrior,"报仇！报仇！报仇！")
            oWarrior.m_oBuffMgr:AddBuff(221,99,{})
        elseif  oWarrior:GetPerform(4259) and not oWarrior.m_oBuffMgr:HasBuff(220) and not oWarrior.m_oBuffMgr:HasBuff(207)  then
            DoSpeek(oWarrior,"报仇！报仇！报仇！")
            oWarrior.m_oBuffMgr:AddBuff(220,99,{})
        end
    end
end

function ChangeCmd10130(oAction,mCmd)
    if math.random(100)>50 then
        return mCmd
    end
    local cmd = {}
    cmd.cmd = "defense"
    return cmd
end

function ChangeCmd10045(oAction,mCmd)
    for _,oWarrior in ipairs(oAction:GetFriendList(true)) do
        if oWarrior:IsDead() and oWarrior:GetPerform(3014) then
            local mNewCmd = {}
            mNewCmd.cmd = "skill"
            mNewCmd.data = {}
            mNewCmd.data.skill_id = 4270
            return mNewCmd
        end
    end
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "skill" then
        return mCmd
    end
    if mCmdData.skill_id == 1402 then
        local mFriend  = oAction:GetFriendList()
        for _,oWarrior in ipairs(mFriend) do
            if oWarrior:GetName() == "杏黄旗" then
                local mNewCmd = {}
                mNewCmd.cmd = "skill"
                mNewCmd.data = {}
                mNewCmd.data.skill_id = 1404
                return mNewCmd
            end
        end
    elseif mCmdData.skill_id == 4270 then
        local mNewCmd = {}
        mNewCmd.cmd = "normal_attack"
        mNewCmd.data = {}
        return mNewCmd 
    end
    return mCmd
end

function ChangeCmd10060(oAction,mCmd)
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "skill" then
        return mCmd
    end
    local iHP = oAction:GetHp()
    local iMaxHP = oAction:GetMaxHp()
    if iHP<iMaxHP/2  and oAction:GetPerform(4271) then
        local mNewCmd = {}
        mNewCmd.cmd = "skill"
        mNewCmd.data = {}
        mNewCmd.data.skill_id = 4271
        return mNewCmd
    end
    if mCmdData.skill_id == 4271 and iHP>iMaxHP/2 then
        local mNewCmd = {}
        mNewCmd.cmd = "normal_attack"
        mNewCmd.data = {}
        return mNewCmd 
    end
end

function OnAttacked10088(oAction,oAttack,oPerform,iDamage,mArgs)
    if iDamage<=0 then return end
    DoSpeek(oAction,"前世受你恩惠，今生偿还",1)
    local oActionMgr = global.oActionMgr
    local mEnemy = oAction:GetEnemyList()
    for _,oWarrior in pairs(mEnemy) do
        local iHP = math.floor(oWarrior:GetMaxHp()/20)
        if iHP > 0 then
            oActionMgr:DoAddHp(oWarrior,iHP)
        end
    end
end

function OnBoutEnd10088(oAction)
    --print("OnBoutEnd10088")
    oAction:SetExtData("escape_ratio",100)
    global.oActionMgr:WarEscape(oAction)
end

function OnAttacked10089(oAction,oAttack,oPerform,iDamage,mArgs)
    if iDamage<=0 then return end
    --print("OnAttacked10089")
    DoSpeek(oAction,"因果循环，今生偿还",1)
end

function OnBoutEnd10089(oAction)
    --print("OnBoutEnd10089")
    oAction:SetExtData("escape_ratio",100)
    global.oActionMgr:WarEscape(oAction)
end

function ChangeCmd10062(oAction,mCmd)
    if oAction:GetPerform(4274) and oAction:GetPerform(4271) then
        local mNewCmd = {}
        mNewCmd.cmd = "skill"
        mNewCmd.data = {}
        local mFriend = oAction:GetFriendList()
        for _,oWarrior in ipairs(mFriend) do
            if oWarrior ~= oAction then
                mNewCmd.data.skill_id = 4274
                --print("ChangeCmd10062-4274")
                return mNewCmd
            end
        end
        mNewCmd.data.skill_id = 4271
        --print("ChangeCmd10062-4271")
        return mNewCmd
    end
    return mCmd
end

function OnBoutEnd10062(oAction)
    local oWar = oAction:GetWar()
    if not oWar then
        return
    end
    if oWar.m_iBout == 1 then
        DoSpeek(oAction,"五感全失者将会被我们吞噬")
        --print("OnBoutEnd10062")
    end
end

function ChangeCmd10083(oAction,mCmd)
    local oWar = oAction:GetWar()
    if not oWar then 
        return mCmd 
    end
    local sCmd = mCmd.cmd
    local mCmdData = mCmd.data
    if sCmd ~= "skill" then
        return mCmd
    end
    if mCmdData.skill_id~=1402 then
        return mCmd
    end
    local mFriend = oAction:GetFriendList()
    for _,oWarrior in pairs(mFriend) do
        if oWarrior:GetName() == "杏黄旗" then
            if oAction:GetPerform(1401) then
                local mNewCmd = {}
                mNewCmd.cmd = "skill"
                mNewCmd.data = {}
                mNewCmd.data.skill_id = 1401
                --print("ChangeCmd10083-1")
                return mNewCmd
            else
                --print("ChangeCmd10083-2")
                local mNewCmd = {}
                mNewCmd.cmd = "normal_attack"
                mNewCmd.data = {}
                return mNewCmd
            end
        end
    end
    return mCmd
end