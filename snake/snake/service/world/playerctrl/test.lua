--import module
local global = require "global"
local extend = require "base.extend"
local res = require "base.res"
local interactive = require "base.interactive"
local loadskill = import(service_path("skill.loadskill"))

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
        "101 设置玩家等级\nplayerop 101 {grade = 60}",
        "102 设置测试评分\nplayerop 102 {score = 60}",
        "103 查看开发者Mac\nplayerop 103",
        "104 清除活跃度100奖励标记\nplayerop 104",
        "201 查看玩家评分分布\nplayerop 201",
        "202 查看指定装备评分(bag=1表示背包道具)\nplayerop 202 {pos = 1,bag = 1}",
        "203 查看指引评分\nplayerop 203",
        "204 查看优化后评分\nplayerop 204",
        "205 各装备综合属性\nplayerop 205",
        "206 清除副本进度数据\nplayerop 206",
        "301 设置双倍点数\nplayerop 301 {point = 点数}",
        "400-500排行榜指令",
        "401 推送玩家评分去排行榜\nplayerop 401",
        "402 排行榜刷天\nplayerop 402",
        "403 排行榜刷凌晨5点\nplayerop 403",
        "404 推送角色评分去排行榜\nplayerop 404",
        "405 推送宠物评分去排行榜\nplayerop 405",
        "406 清除排行榜\nplayerop 406 {idx = 编号}",
        "408 推送玩家评分去门派排行榜\nplayerop 408",
        "501 临时背包清除\nplayerop 501",
        "502 清除回收系统道具\nplayerop 502",
        "503 清除回收系统宠物\nplayerop 503",
        "510 清除玩家自身染色和时装\nplayerop 510",
        "511 清除玩家宠物的染色和时装\nplayerop 511",
        "602 清除成长进度\nplayerop 602",
        "603 设置回收标记\nplayerop 603",
        "701 增加神器经验\nplayerop 701 {exp=10000}",
        "702 增加神器强化经验\nplayerop 702 {exp=10000}",
        "703 增加器灵技能(level=0)表示取消sk为空表示清空技能\nplayerop 703 {sk=1001, level=1}",
    }

    if iFlag == 100 then
        for idx=#mCommand,1,-1 do
            oChatMgr:HandleMsgChat(oPlayer,mCommand[idx])
        end
    elseif iFlag == 101 then  --playerop 101 {grade=60}
        if not mArgs.grade then
            oNotifyMgr:Notify(pid,"指令格式错误")
            return
        end
        local iGrade = mArgs.grade
        local mUpGrade = res["daobiao"]["upgrade"]
        if not mUpGrade[iGrade] then
            oNotifyMgr:Notify(pid,"配表无次等级")
            return
        end
        local mRoleInitProp = res["daobiao"]["roleprop"][1]
        for sAttr , iValue in pairs(mRoleInitProp) do
            oPlayer.m_oBaseCtrl:SetData(sAttr,iValue)
        end
        local iAddExp = 0
        for grade,mInfo in pairs(mUpGrade) do
            iAddExp = iAddExp + mInfo.player_exp
            if grade == iGrade then 
                break
            end
        end
        oPlayer.m_oActiveCtrl:SetData("exp",iAddExp)
        oPlayer.m_oBaseCtrl:SetData("point_plan", {})
        oPlayer.m_oBaseCtrl:SetData("selected_point_plan", 1)
        oPlayer:CheckUpGrade()
        oPlayer:PropChange("exp")
        oNotifyMgr:Notify(pid,"等级设置成功")
    elseif iFlag == 102 then
        local iScore = mArgs.score
        if not iScore then
            oPlayer.m_TestScore = nil
            oNotifyMgr:Notify(pid,"清除测试评分")
        else
            oPlayer.m_TestScore = iScore
            oNotifyMgr:Notify(pid,string.format("设置测试评分：%s",iScore))
        end
    elseif iFlag == 103 then
        local sMac1 = oPlayer:GetMac()
        local sMac2 = oPlayer:GetTrueMac()
        local sMsg = string.format("Mac全称：%s\n局部Mac：%s",sMac1,sMac2)
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 104 then
        oPlayer.m_oTodayMorning:Delete("schedule_reward_six")
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 105 then
        local iMaxScore = oPlayer:Query("max_score", 0)
        local sMsg = string.format("历史最大综合积分: %d", iMaxScore)
        oNotifyMgr:Notify(pid, sMsg)
    elseif iFlag == 201 then --playerop 201
        local sMsg = ""
        sMsg = sMsg .. string.format("基本评分+等级=%s\n",30 +oPlayer:GetGrade()*30)
        sMsg = sMsg .. string.format("强化大师=%s\n",oPlayer.m_oEquipMgr:GetStrengthenMasterScore())
        sMsg = sMsg .. string.format("技能=%s\n",oPlayer.m_oSkillCtrl:GetScore())
        sMsg = sMsg .. string.format("装备=%s\n",oPlayer.m_oEquipMgr:GetScore(true))
        sMsg = sMsg .. string.format("阵法=%s\n",oPlayer.m_oBaseCtrl.m_oFmtMgr:GetScore())
        sMsg = sMsg .. string.format("护主=%s\n",oPlayer.m_oPartnerCtrl:GetScoreByHuZu())
        sMsg = sMsg .. string.format("宠物=%s\n",oPlayer.m_oSummonCtrl:GetScore(true))
        sMsg = sMsg .. string.format("伙伴=%s\n",oPlayer.m_oPartnerCtrl:GetScore(true))
        sMsg = sMsg .. string.format("坐骑=%s(最高:%s 技能:%s　等級:%s) \n",oPlayer.m_oRideCtrl:GetScore(),oPlayer.m_oRideCtrl:GetRideScore(),oPlayer.m_oRideCtrl:GetSkillScore(),oPlayer.m_oRideCtrl:GetGradeScore())
        sMsg = sMsg .. string.format("徽章=%s\n",oPlayer.m_oTouxianCtrl:GetScore())
        sMsg = sMsg .. string.format("总评分=%s\n\n",oPlayer:GetScore())
        sMsg = sMsg .. string.format("技能分布\n%s",oPlayer.m_oSkillCtrl:GetScoreDebug())
        
        oChatMgr:HandleMsgChat(oPlayer,sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 202 then
        local pos = mArgs.pos
        local bag = mArgs.bag
        if pos then 
            --
        elseif bag then
            pos = 100 + bag
        else
            oNotifyMgr:Notify(pid,"参数格式不合法")
            return
        end
        local itemobj = oPlayer.m_oItemCtrl:GetItem(pos) 
        if not itemobj then
            oNotifyMgr:Notify(pid,"此格子无道具")
            return
        end
        if itemobj.m_ItemType ~= "equip" then
            oNotifyMgr:Notify(pid,"此道具非装备")
            return
        end
        local sMsg = string.format("装备名字:%s\n",itemobj:Name())
        sMsg = sMsg .. string.format("特效=%s\n",itemobj:GetScoreBySE())
        sMsg = sMsg .. string.format("特技=%s\n",itemobj:GetScoreBySK())
        sMsg = sMsg .. string.format("基础=%s\n",itemobj:GetScoreByBasic())
        sMsg = sMsg .. string.format("神魂=%s\n",itemobj:GetScoreBySH())
        sMsg = sMsg .. string.format("附加=%s\n",itemobj:GetScoreByAttach())
        sMsg = sMsg .. string.format("魂石=%s\n",itemobj:GetScoreByHunShi())
        if pos< 100 then
            sMsg = sMsg .. string.format("强化=%s\n",oPlayer.m_oEquipMgr:GetStrengthenPosScore(itemobj:EquipPos()))
        end
        sMsg = sMsg .. string.format("总评分=%s\n\n",itemobj:GetScore())
        sMsg = sMsg .. string.format("")
        local sBasicAttr = "基础属性=\n"
        local mBasicAttr = itemobj:GetBaseAttrs()
        if next(mBasicAttr) then
            for sAttr,iValue in pairs(mBasicAttr) do
                sBasicAttr = sBasicAttr .. string.format("%s=%s\n",sAttr,iValue)
            end
            sMsg = sMsg .. sBasicAttr
        end

        local sAttchAttr = "附加属性=\n"
        local mAttchAttr = itemobj:GetAttachAttrs()
        if next(mAttchAttr) then
            for sAttr,iValue in pairs(mAttchAttr) do
                sAttchAttr = sAttchAttr .. string.format("%s=%s\n",sAttr,iValue)
            end
            sMsg = sMsg .. sAttchAttr
        end

        local sShenhunAttr = "神魂属性=\n"
        local mShenhunAttr = itemobj:GetShenHunAttrs()
        if next(mShenhunAttr) then
            for sAttr,iValue in pairs(mShenhunAttr) do
                sShenhunAttr = sShenhunAttr .. string.format("%s=%s\n",sAttr,iValue)
            end
            sMsg = sMsg .. sShenhunAttr
        end

        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 203 then
        local mScore = oPlayer.m_oSkillCtrl:GetScore2()
        local sMsg = "指引\n"
        sMsg = sMsg .. string.format("招式技能=%s\n",mScore[1][1])
        sMsg = sMsg .. string.format("心法技能=%s\n",mScore[2][1])
        sMsg = sMsg .. string.format("修炼技能=%s\n",mScore[3][1])
        sMsg = sMsg .. string.format("帮派技能=%s\n",mScore[4][1])
        sMsg = sMsg .. string.format("装备升级=%s\n",oPlayer.m_oEquipMgr:GetScore())
        sMsg = sMsg .. string.format("装备强化=%s\n",oPlayer.m_oEquipMgr:GetScoreByStrength())
        sMsg = sMsg .. string.format("装备附魂=%s\n",oPlayer.m_oEquipMgr:GetScoreBySH())
        sMsg = sMsg .. string.format("伙伴培养=%s\n",oPlayer.m_oPartnerCtrl:GetScore())
        sMsg = sMsg .. string.format("宠物培养=%s\n",oPlayer.m_oSummonCtrl:GetScore())
        sMsg = sMsg .. string.format("徽章升级=%s\n",oPlayer.m_oTouxianCtrl:GetScore())
        sMsg = sMsg .. string.format("坐骑培养=%s\n",oPlayer.m_oRideCtrl:GetScore())
        sMsg = sMsg .. string.format("魂石升级=%s\n",oPlayer.m_oEquipMgr:GetScoreByHunShi())
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 204 then
        local sMsg = ""
        sMsg = sMsg .. string.format("基本评分+等级=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "base"))
        sMsg = sMsg .. string.format("强化大师=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "strength"))
        sMsg = sMsg .. string.format("技能=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "skill"))
        sMsg = sMsg .. string.format("装备=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "equip"))
        sMsg = sMsg .. string.format("阵法=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "fmt"))
        sMsg = sMsg .. string.format("护主=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "huzhu"))
        sMsg = sMsg .. string.format("宠物=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "summonctrl"))
        sMsg = sMsg .. string.format("伙伴=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "partnerctrl"))
        sMsg = sMsg .. string.format("坐骑=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "ridectrl"))
        sMsg = sMsg .. string.format("徽章=%s\n",global.oScoreCache:GetScoreByKey(oPlayer, "touxian"))
        sMsg = sMsg .. string.format("总评分=%s\n\n",oPlayer:GetScore())
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 205 then
        local mPosAttrs = oPlayer.m_oEquipMgr.m_mApply
        local mPosRatioAttrs = oPlayer.m_oEquipMgr.m_mRatioApply
        local lAttrs = list_combine(table_key_list(mPosAttrs), table_key_list(mPosRatioAttrs))
        local sMsg = "各装备综合属性：\n"
        for _, sAttr in pairs(lAttrs) do
            local mAttrs = mPosAttrs[sAttr]
            local mRatioAttrs = mPosRatioAttrs[sAttr]
            sMsg = sMsg .. sAttr .. ":\n"
            for iPos, iValue in pairs(mAttrs or {}) do
                sMsg = sMsg .. "  装备" .. iPos .. ":" .. iValue .. ",\n"
            end
            for iPos, iValue in pairs(mRatioAttrs or {}) do
                sMsg = sMsg .. "  装备" .. iPos .. ":" .. iValue .. ",\n"
            end
        end
        oChatMgr:HandleMsgChat(oPlayer, sMsg)
        oPlayer:NotifyMessage(sMsg)
        oNotifyMgr:Notify(pid,"查看消息频道")
    elseif iFlag == 206 then
        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oTodayMorning.m_mKeepList) do
            if string.find(sKey,"^fuben_reward") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oTodayMorning:Delete(sKey)
        end

        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oWeekMorning.m_mKeepList) do
            if string.find(sKey,"^fuben_reward") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oWeekMorning:Delete(sKey)
        end

        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oTodayMorning.m_mKeepList) do
            if string.find(sKey,"^fuben_step") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oTodayMorning:Delete(sKey)
        end

        local lDel = {}
        for sKey,iDay in pairs(oPlayer.m_oWeekMorning.m_mKeepList) do
            if string.find(sKey,"^fuben_step") then
                table.insert(lDel,sKey)
            end
        end
        for _,sKey in ipairs(lDel) do
            oPlayer.m_oWeekMorning:Delete(sKey)
        end


        local oTeam = oPlayer:HasTeam()
        if oTeam then
            oTeam.m_oFubenSure.m_mSure={}
        end
        oNotifyMgr:Notify(pid,"成功清除")
    elseif iFlag == 301 then
        local iPoint = mArgs.point or 0
        oPlayer.m_oBaseCtrl:AddDoublePoint(iPoint)
        oPlayer.m_oBaseCtrl:RefreshDoublePoint()
        local oState = oPlayer.m_oStateCtrl:GetState(1004)
        if oState then
            oState:Refresh(pid)
        end
        oNotifyMgr:Notify(pid,"设置成功")
    elseif iFlag == 401 then
        oPlayer:PushPlayerScoreRank(oPlayer)
        oNotifyMgr:Notify(pid,"推送成功")
    elseif iFlag == 402 then
        local iHour = mArgs.hour or 0
        global.oRankMgr:NewHour(get_daytime({anchor = iHour}))
        oNotifyMgr:Notify(pid,"刷时成功")
    elseif iFlag == 403 then
        interactive.Send(".rank", "rank", "NewHour5", {})
        oNotifyMgr:Notify(pid,"5点刷时成功")
    elseif iFlag == 404 then
        oPlayer:PushRoleScoreRank(oPlayer)
        oNotifyMgr:Notify(pid,"推送成功")
    elseif iFlag == 405 then
        oPlayer:PushSumScoreRank(oPlayer)
        oNotifyMgr:Notify(pid,"推送成功")
    elseif iFlag == 406 then 
        local idx = mArgs.idx
        local Forward = import(service_path("netcmd.rank"))
        local mData =  {}
        mData.idx = idx
        Forward.CleanRank(oPlayer,mData)
        oNotifyMgr:Notify(pid,"清除指定排行榜成功")
    elseif iFlag == 407 then 
        global.oRankMgr:MergeFinish()
    elseif iFlag == 408 then
        global.oRankMgr:PushDataToSchoolScoreRank(oPlayer, oPlayer:GetScore())
        oNotifyMgr:Notify(pid,"推送成功")
    elseif iFlag == 501 then
        oPlayer.m_mTempItemCtrl:ClearAllItem()
        oNotifyMgr:Notify(pid,"临时背包清除成功")
    elseif iFlag == 502 then
        oPlayer.m_mRecoveryCtrl:ClearAllItem()
        oNotifyMgr:Notify(pid,"成功清除回收系统道具")
    elseif iFlag == 503 then
        oPlayer.m_mRecoveryCtrl:ClearAllSum()
        oNotifyMgr:Notify(pid,"成功清除回收系统宠物")
    elseif iFlag == 510 then
        local waiguan =  import(service_path("playerctrl.baseobj.waiguan"))
        waiguan.CleanAll(oPlayer)
        oNotifyMgr:Notify(pid,"成功清除玩家自身染色和时装")
    elseif iFlag == 511 then
        local waiguan = import(service_path("summon.waiguan"))
        waiguan.CleanAll(oPlayer)
        oNotifyMgr:Notify(pid,"成功清除玩家宠物的染色和时装")
    elseif iFlag == 602 then
        oPlayer.m_oBaseCtrl.m_oGrow:ClearAll()
        oNotifyMgr:Notify(pid,"清除成功")
    elseif iFlag == 603 then
        local bIngoreRecovery = mArgs.delete
        if not bIngoreRecovery then
            oPlayer.m_bIngoreRecovery = true 
            oNotifyMgr:Notify(pid,"设置成功")
        else
            oPlayer.m_bIngoreRecovery = false 
            oNotifyMgr:Notify(pid,"清除成功")
        end
    elseif iFlag == 604 then
        local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(mArgs.skill)
        if not oSKill then return end
        oSKill:Learn(oPlayer)
    elseif iFlag == 605 then
        local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(mArgs.skill)
        if not oSKill then return end
        oSKill:Reset(oPlayer)
    elseif iFlag == 606 then
        local oSKill = oPlayer.m_oSkillCtrl:GetFuZhuanSkillById(mArgs.skill)
        if not oSKill then return end
        oSKill:Product(oPlayer)
    elseif iFlag == 701 then
        oPlayer.m_oArtifactCtrl:AddExp(mArgs.exp, "gm")
    elseif iFlag == 702 then 
        oPlayer.m_oArtifactCtrl:AddStrengthExp(mArgs.exp, "gm")
    elseif iFlag == 703 then
        local iSkill = mArgs.sk
        local iLevel = mArgs.level
        local iSpirit = oPlayer.m_oArtifactCtrl:GetFightSpirit()
        if not iSpirit or iSpirit <= 0 then return end

        local oSpirit = oPlayer.m_oArtifactCtrl:GetSpiritById(iSpirit)
        if not oSpirit then return end

        oSpirit:Dirty()
        if not iSkill then
            for iSkill, oSkill in pairs(oSpirit.m_mSkill) do
                oSkill:SkillUnEffect(oPlayer)
            end
            oSpirit.m_mSkill = {}
        else
            if oSpirit.m_mSkill[iSkill] and iLevel == 0 then
                oSpirit.m_mSkill[iSkill]:SkillUnEffect(oPlayer)
                oSpirit.m_mSkill[iSkill] = nil
            elseif not oSpirit.m_mSkill[iSkill] then
                local oSkill = loadskill.NewSkill(iSkill)
                oSpirit.m_mSkill[iSkill] = oSkill
            end
        end
        oPlayer.m_oArtifactCtrl:SpiritSkillEffect()
        oPlayer.m_oArtifactCtrl:RefreshOneSpirit(iSpirit)
    end
    oNotifyMgr:Notify(pid,"指令执行完毕")
end
