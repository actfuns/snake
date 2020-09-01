--import module

local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local res = require "base.res"
local extend = require "base/extend"

local gamedefines = import(lualib_path("public.gamedefines"))
local analy = import(lualib_path("public.dataanaly"))
local analylog = import(lualib_path("public.analylog"))

local tremove = table.remove
local tinsert = table.insert

function NewChatMgr(...)
    return CChatMgr:New(...)
end

CChatMgr = {}
CChatMgr.__index = CChatMgr
inherit(CChatMgr,logic_base_cls())

function CChatMgr:New()
    local o = super(CChatMgr).New(self)
    o.m_iNotice = 0
    o:_HandleBroadCastNotice()
    o.m_lChuanYin = {}
    o.m_mHistory = {}
    return o
end

function CChatMgr:HandlePlayerChat(oPlayer, iType, sMsg, iForbid)
    local iPid = oPlayer:GetPid()
    local iBanTime = oPlayer.m_oActiveCtrl:GetBanChatTime()
    if iBanTime > 0 then
        self:_HandlePlayerChat2(oPlayer, iType, sMsg)
        -- local oToolMgr = global.oToolMgr
        -- local sHour, sMin, sSec = oToolMgr:FormatTime2BanChat(iBanTime)
        -- local sMsg = oToolMgr:FormatColorString("禁言中(#HH:#MM:#SS)", {HH=sHour, MM=sMin, SS=sSec})
        -- oPlayer:NotifyMessage(sMsg)
    else
        self:RequestCheckChat(iPid, iType, sMsg, iForbid, function (mData)
            local oPlayer = global.oWorldMgr:GetOnlinePlayerByPid(iPid)
            if mData.code == 1 then
                self:_HandlePlayerChat2(oPlayer, iType, sMsg)
            else
                self:_HandlePlayerChat(oPlayer, iType, sMsg)
            end
        end)
    end
end

function CChatMgr:_HandlePlayerChat(oPlayer, iType, sMsg)
    if not oPlayer then return end

    local iBanTime = oPlayer.m_oActiveCtrl:GetBanChatTime()
    if iBanTime > 0 then return end

    local oChatMgr = global.oChatMgr
    if iType == gamedefines.CHANNEL_TYPE.WORLD_TYPE then
        self:HandleWorldChat(oPlayer, sMsg)
    elseif iType == gamedefines.CHANNEL_TYPE.TEAM_TYPE then
        self:HandleTeamChat(oPlayer, sMsg)
    elseif iType == gamedefines.CHANNEL_TYPE.CURRENT_TYPE then
        self:HandleCurrentChat(oPlayer, sMsg)
    elseif iType == gamedefines.CHANNEL_TYPE.ORG_TYPE then
        self:HandleOrgChat(oPlayer, sMsg)
    end
end

function CChatMgr:_HandlePlayerChat2(oPlayer, iType, sMsg)
    if not oPlayer then return end

    oPlayer:Send("GS2CChat", {
        type = iType,
        cmd = sMsg,
        role_info = oPlayer:PackRole2Chat(),   
    })
end

function CChatMgr:HandleWorldChat(oPlayer, sMsg)
    local oToolMgr = global.oToolMgr

    sMsg = trim(sMsg)
    if string.len(sMsg) == 0 then return end

    local mChat = res["daobiao"]["chatconfig"][gamedefines.CHANNEL_TYPE.WORLD_TYPE]
    assert(mChat, string.format("CChatMgr:HandleWorldChat:chat config not exist"))

    local iSayTime = oPlayer.m_oActiveCtrl:GetData("world_chat", 0)
    local iGradeLimit = formula_string(mChat["grade_limit"], {lv = oPlayer:GetGrade()})
    local iChatGap = formula_string(mChat["talk_gap"], {lv = oPlayer:GetGrade()})
    local iCostEnergy = formula_string(mChat["energy_cost"], {lv = oPlayer:GetGrade()})
    if oPlayer:GetGrade() < iGradeLimit then
        oPlayer:NotifyMessage(self:GetTextData(1001, {amount = iGradeLimit}))
        return
    end

    local iRemainTime = iSayTime + iChatGap - get_time()
    if iRemainTime > 0 then
        oPlayer:NotifyMessage(self:GetTextData(1002, {amount = iRemainTime}))
        return
    end

    if oPlayer:GetEnergy() < iCostEnergy then
        oPlayer:NotifyMessage(self:GetTextData(1003, {amount = iCostEnergy}))
        return
    end

    oPlayer:AddEnergy(-iCostEnergy, "聊天", {cancel_tip=true, cancel_chat=true})
    oPlayer:NotifyMessage(oToolMgr:FormatColorString("世界发言成功扣除#amount活力", {amount = iCostEnergy}))
    oPlayer.m_oActiveCtrl:SetData("world_chat", get_time())
    self:SendMsg2World(sMsg, oPlayer)

    self:LogAnalyInfo(oPlayer, gamedefines.CHANNEL_TYPE.WORLD_TYPE, sMsg)
    -- self:PushChatMsg(oPlayer, gamedefines.CHANNEL_TYPE.WORLD_TYPE, sMsg)
    analylog.LogSystemInfo(oPlayer, "world_chat", nil, {})
    return true
end

function CChatMgr:SendMsg2World(sMsg, oPlayer)
    local mRoleInfo = {pid = 0}
    if oPlayer then
        mRoleInfo = oPlayer:PackRole2Chat()
        self:SetChatHistroy(sMsg, mRoleInfo, gamedefines.CHANNEL_TYPE.WORLD_TYPE)
    end
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendWorldChat(sMsg, mRoleInfo)
end

function CChatMgr:HandleSysChat(sMsg, iTag, iHorse)
    iTag = iTag or gamedefines.SYS_CHANNEL_TAG.NOTICE_TAG
    iHorse = iHorse or 0
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendSysChat(sMsg, iTag, iHorse)
end

function CChatMgr:HandleTeamChat(oPlayer, sMsg,  bSys)
    sMsg = trim(sMsg)
    if string.len(sMsg) == 0 then return end

    if not oPlayer:TeamID() then return end

    local mChat = res["daobiao"]["chatconfig"][gamedefines.CHANNEL_TYPE.TEAM_TYPE]
    assert(mChat, string.format("CChatMgr:HandleTeamChat:chat config not exist"))

    if not bSys then
        local iSayTime = oPlayer.m_oActiveCtrl:GetData("team_chat", 0)
        local iGradeLimit = formula_string(mChat.grade_limit, {})
        local iChatGap = formula_string(mChat.talk_gap, {})
        if oPlayer:GetGrade() < iGradeLimit then
            oPlayer:NotifyMessage(self:GetTextData(1004, {amount = iGradeLimit}))
            return
        end

        local iRemainTime = iSayTime + iChatGap - get_time()
        if iRemainTime > 0 then
            oPlayer:NotifyMessage(self:GetTextData(1005, {amount = iRemainTime}))
            return
        end
        oPlayer.m_oActiveCtrl:SetData("team_chat", get_time())
        self:SendMsg2Team(sMsg, oPlayer:TeamID(), oPlayer)

        self:LogAnalyInfo(oPlayer, gamedefines.CHANNEL_TYPE.TEAM_TYPE, sMsg)
        -- self:PushChatMsg(oPlayer, gamedefines.CHANNEL_TYPE.TEAM_TYPE, sMsg)
        analylog.LogSystemInfo(oPlayer, "team_chat", nil, {})
    else
        self:SendMsg2Team(sMsg, oPlayer:TeamID())
    end
end

function CChatMgr:SendMsg2Team(sMsg, iTeamID, oPlayer)
    local mRoleInfo = {pid = 0}                                 --系统
    if oPlayer then
        mRoleInfo = oPlayer:PackRole2Chat()
        self:SetChatHistroy(sMsg, mRoleInfo, gamedefines.CHANNEL_TYPE.TEAM_TYPE, iTeamID)
    end

    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendTeamChat(sMsg, iTeamID, mRoleInfo)
end

function CChatMgr:HandleCurrentChat(oPlayer, sMsg, bSys)
    --后面还有观战聊天
    sMsg = trim(sMsg)
    if string.len(sMsg) == 0 then return end

    local mChat = res["daobiao"]["chatconfig"][gamedefines.CHANNEL_TYPE.CURRENT_TYPE]
    assert(mChat, string.format("CChatMgr:HandleCurrentChat:chat config not exist"))

    if not bSys then
        local iSayTime = oPlayer.m_oActiveCtrl:GetData("current_chat", 0)
        local iGradeLimit = formula_string(mChat.grade_limit, {})
        local iChatGap = formula_string(mChat.talk_gap, {})
        if oPlayer:GetGrade() < iGradeLimit then
            oPlayer:NotifyMessage(self:GetTextData(1006, {amount = iGradeLimit}))
            return
        end

        local iRemainTime = iSayTime + iChatGap - get_time()
        if iRemainTime > 0 then
            oPlayer:NotifyMessage(self:GetTextData(1007, {amount = iRemainTime}))
            return
        end
        oPlayer.m_oActiveCtrl:SetData("current_chat", get_time())

        self:LogAnalyInfo(oPlayer, gamedefines.CHANNEL_TYPE.CURRENT_TYPE, sMsg)
        -- self:PushChatMsg(oPlayer, gamedefines.CHANNEL_TYPE.CURRENT_TYPE, sMsg)
    end

    --战斗/观战
    local oWar = oPlayer.m_oActiveCtrl:GetNowWar()
    if oWar then
        self:SendMsg2War(oPlayer, oWar, sMsg, gamedefines.CHANNEL_TYPE.CURRENT_TYPE)
        return true
    end

    --非战斗
    local oSceneMgr = global.oSceneMgr
    local oScene = oPlayer.m_oActiveCtrl:GetNowScene()
    if oScene then
        self:SendMsg2Scene(oPlayer, oScene, sMsg, gamedefines.CHANNEL_TYPE.CURRENT_TYPE)
        return true
    end
end

function CChatMgr:SendMsg2War(oPlayer, oWar, sMsg, iType)
    local mNet = {
        role_info = oPlayer:PackRole2Chat(),
        type = iType,
        cmd = sMsg,
    }
    oWar:SendCurrentChat(oPlayer, mNet)
end

function CChatMgr:SendMsg2Scene(oPlayer, oScene, sMsg, iType)
    local mRoleInfo
    local pid 
    if oPlayer then
        mRoleInfo = oPlayer:PackRole2Chat()
        pid = oPlayer:GetPid()
    else
        mRoleInfo = {pid = 0}
        pid = 0
    end
    
    local mNet = {
        type = iType,
        cmd = sMsg,
        role_info = mRoleInfo,
    }
    oScene:SendCurrentChat(pid, mNet)
end

--消息频道
function CChatMgr:HandleMsgChat(oPlayer, sMsg)
    local iType = gamedefines.CHANNEL_TYPE.MSG_TYPE
    if oPlayer then
        oPlayer:Send("GS2CConsumeMsg", {type = iType, content = sMsg})
    end
end

function CChatMgr:SendNotifyAndMessage(oPlayer, sMsg)
    self:HandleMsgChat(oPlayer, sMsg)
    global.oNotifyMgr:Notify(oPlayer:GetPid(), sMsg)
end

--传音
function CChatMgr:HandleChuanYin(oPlayer, iType, sMsg)
    local mData = res["daobiao"]["chuanyin"][iType]
    assert(mData, string.format(" CChatMgr:HandleChuanYin not exist! type_id:%d", iType))

    local oToolMgr = global.oToolMgr
    if not oToolMgr:IsSysOpen("CHUAN_YIN", oPlayer) then return end

    if #self.m_lChuanYin >= 10 then
        oPlayer:NotifyMessage(self:GetTextData(1016))
        return
    end

    local iItem, iCnt, iGoldCoin = mData["cost_item"], mData["cost_num"], 0
    if iCnt <= 0 then return end

    local iHasCnt = oPlayer:GetItemAmount(iItem)
    if iHasCnt < iCnt then
        local mItem = global.oItemLoader:GetItemData(iItem)
        if not mItem then return end

        iGoldCoin = mItem["buyPrice"] * (iCnt - iHasCnt)
        if iGoldCoin <= 0 then return end

        if not oPlayer:ValidGoldCoin(iGoldCoin) then
            oPlayer:NotifyMessage("物品不足")
            return
        end
        iCnt = iHasCnt
    end

    if iGoldCoin > 0 then
        oPlayer:ResumeGoldCoin(iGoldCoin, "千里传音")
    end
    if iCnt > 0 then
        oPlayer:RemoveItemAmount(iItem, iCnt, "千里传音")
    end

    self:SendChuanYin(iType, sMsg, oPlayer)
    oPlayer:NotifyMessage(self:GetTextData(1017))
end

function CChatMgr:SendChuanYin(iType, sMsg, oPlayer)
    table.insert(self.m_lChuanYin, {iType, sMsg, oPlayer:PackRole2Chat()})
    if #self.m_lChuanYin <= 1 then
        local f
        f = function (bFirst)
            self:DelTimeCb("_SendChuanYin")
            self:AddTimeCb("_SendChuanYin", 5 * 1000, f)
            self:_SendChuanYin(bFirst)
        end
        f(true)
    end
end

function CChatMgr:_SendChuanYin(bFirst)
    if not bFirst and #self.m_lChuanYin > 0 then
        table.remove(self.m_lChuanYin, 1)
    end

    if #self.m_lChuanYin <= 0 then
        self:DelTimeCb("_SendChuanYin")
        return
    end

    local iType, sMsg, mRole = table.unpack(self.m_lChuanYin[1])
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendChuanYin(iType, sMsg, mRole)
end

--自动播放公告
function CChatMgr:_HandleBroadCastNotice()
    local f1
    f1 = function()
        self:BroadCastNotice()
        self:DelTimeCb("_HandleBroadCastNotice")
        self:AddTimeCb("_HandleBroadCastNotice", 5 * 60 * 1000, f1)
    end
    f1()
end

function CChatMgr:BroadCastNotice()
    local mData = res["daobiao"]["gonggao"]
    local lNoticeID = table_key_list(mData)
    local iMinID = math.min(table.unpack(lNoticeID))
    local iMaxID =math.max(table.unpack(lNoticeID))

    if self.m_iNotice < iMinID or self.m_iNotice > iMaxID then
        self.m_iNotice = iMinID
    end

    local mNotice = mData[self.m_iNotice]
    assert(mNotice, string.format("HandleNotice config not exist,id:%d", self.m_iNotice))

    self.m_iNotice = self.m_iNotice + 1
    self:HandleSysChat(mNotice["content"], gamedefines.SYS_CHANNEL_TAG.NOTICE_TAG, mNotice["horse_race"])
end

function CChatMgr:HandleOrgChat(oPlayer, sMsg,  bSys)
    sMsg = trim(sMsg)
    local oOrg = oPlayer:GetOrg()
    if string.len(sMsg) == 0 or not oOrg then return end

    local mChat = res["daobiao"]["chatconfig"][gamedefines.CHANNEL_TYPE.ORG_TYPE]
    assert(mChat, string.format("CChatMgr:HandleOrgChat:chat config not exist, id"))

    if not bSys then
        local iSayTime = oPlayer.m_oActiveCtrl:GetData("org_chat", 0)
        local iGradeLimit = formula_string(mChat.grade_limit, {})
        local iChatGap = formula_string(mChat.talk_gap, {})
        if oPlayer:GetGrade() < iGradeLimit then
            oPlayer:NotifyMessage(self:GetTextData(1009, {amount = iGradeLimit}))
            return
        end

        local iRemainTime = iSayTime + iChatGap - get_time()
        if iRemainTime > 0 then
            oPlayer:NotifyMessage(self:GetTextData(1010, {amount = iRemainTime}))
            return
        end

        local oMem = oOrg:GetMemberFromAll(oPlayer:GetPid())
        -- if not oMem return end
        local iBanTime = oMem:GetChatBanLeftTime()
        if iBanTime > 0 then
            local oOrgMgr = global.oOrgMgr
            local oToolMgr = global.oToolMgr
            local sHour, sMin = oToolMgr:FormatTime2BanChat(iBanTime)
            oPlayer:NotifyMessage(oOrgMgr:GetOrgText(1138, {HH=sHour, MM=sMin}))
            return
        end

        oPlayer.m_oActiveCtrl:SetData("org_chat", get_time())
        oPlayer:MarkGrow(6)
        self:SendMsg2Org(sMsg, oPlayer:GetOrgID(), oPlayer)
        self:LogAnalyInfo(oPlayer, gamedefines.CHANNEL_TYPE.ORG_TYPE, sMsg)
        -- self:PushChatMsg(oPlayer, gamedefines.CHANNEL_TYPE.ORG_TYPE, sMsg)
        
        analylog.LogSystemInfo(oPlayer, "org_chat", nil, {})
        return true
    else
        self:SendMsg2Org(sMsg, oPlayer:GetOrgID())
        return true
    end
end

function CChatMgr:SendMsg2Org(sMsg, iOrgID, oPlayer)
    local mRoleInfo = {pid = 0}                                 --系统
    if oPlayer then
        mRoleInfo = oPlayer:PackRole2OrgChat()
        self:SetChatHistroy(sMsg, mRoleInfo, gamedefines.CHANNEL_TYPE.ORG_TYPE, iOrgID)
    end

    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendOrgChat(sMsg, iOrgID, mRoleInfo)
end

function CChatMgr:GetTextData(iText, mData)
    local oToolMgr = global.oToolMgr
    local sMsg = oToolMgr:GetTextData(iText, {"chattext"})
    if mData then
        sMsg = oToolMgr:FormatColorString(sMsg, mData)
    end
    return sMsg
end

-- 帮派弹幕
function CChatMgr:HandleOrgBulletBarrage(oPlayer, sMsg)
    local oOrg = oPlayer:GetOrg()
    if not oOrg then return end
    local iShape = 11098
    local iAmount = 1
    if oPlayer:GetItemAmount(iShape) < iAmount then
        return
    end
    oPlayer:RemoveItemAmount(iShape,iAmount,"帮派弹幕")

    self:SendOrgBulletBarrage(oPlayer,sMsg)
end

function CChatMgr:SendOrgBulletBarrage(oPlayer, sMsg)
    local oNotifyMgr = global.oNotifyMgr
    oNotifyMgr:SendOrgBulletBarrage(sMsg,oPlayer:GetOrgID(),oPlayer:GetName())
end

function CChatMgr:BanChat(oPlayer, iTime)
    oPlayer.m_oActiveCtrl:SetBanChat(iTime)
end

function CChatMgr:HandleMatchTeamChat(oPlayer, sMsg, iChannel, iMinGrade, iMaxGrade, iMatch)
    if not oPlayer:HasTeam() then return end
    local bSuccess =false
    if iChannel == gamedefines.CHANNEL_TYPE.WORLD_TYPE then
        bSuccess = self:HandleWorldChat(oPlayer, sMsg)
    elseif iChannel == gamedefines.CHANNEL_TYPE.TEAM_TYPE then
        local mArgs = {}
        mArgs.include = {oPlayer:GetPid()}
        global.oNotifyMgr:SendPubTeamMsg(sMsg, oPlayer:PackRole2Chat(), mArgs)
        bSuccess = true
    elseif iChannel == gamedefines.CHANNEL_TYPE.CURRENT_TYPE then
        bSuccess = self:HandleCurrentChat(oPlayer, sMsg)
    elseif iChannel == gamedefines.CHANNEL_TYPE.ORG_TYPE then
        bSuccess = self:HandleOrgChat(oPlayer, sMsg)
    end
    if bSuccess then
        local sText = global.oToolMgr:GetTextData(1128,{"team"})
        global.oNotifyMgr:Notify(oPlayer:GetPid(),sText)
    end
end

function CChatMgr:LogAnalyInfo(oPlayer, iChannel, sMsg, iTarget)
    local mLog = oPlayer:BaseAnalyInfo()
    local oNowScene = oPlayer:GetNowScene()
    if oNowScene then
        mLog["map_id"] = oNowScene:MapId()    
    end
    mLog["chat_channel"] = iChannel
    mLog["target_role_id"] = iTarget or 0
    mLog["content"] = sMsg
    analy.log_data("chat", mLog)
end

function CChatMgr:GetChuanwenMsg(iMsgId)
    local mChuanwen = res["daobiao"]["chuanwen"][iMsgId]
    if mChuanwen then
        return mChuanwen.content, mChuanwen.horse_race
    end
end

function CChatMgr:PushChatMsg(oPlayer, iChannel, sMsg)
    -- if not oPlayer then return end

    -- interactive.Send(".chat", "common", "HandleChatMsg", {
    --     channel = iChannel,
    --     pid = oPlayer:GetPid(),
    --     msg = sMsg,
    -- })    
end

function CChatMgr:RequestCheckChat(iPid, iChannel, sMsg, iForbid, endfunc)
    local mInfo = {
        channel = iChannel,
        pid = iPid,
        msg = sMsg,
        forbid = iForbid,
    }
    interactive.Request(".chat", "common", "CheckChatMsg", mInfo, function (mRecord, mData)
        endfunc(mData)
    end)    
end

function CChatMgr:OnLogin(oPlayer, bReEnter)
    interactive.Send(".chat", "common", "OnLogin", {
        pid = oPlayer:GetPid(),
        re_enter = bReEnter,
    })
    self:DealLoginChatInfo(oPlayer, bReEnter)
end

function CChatMgr:DealLoginChatInfo(oPlayer, bReEnter)
    local mNet = {
        world_chat = self:GetChatHistory(gamedefines.CHANNEL_TYPE.WORLD_TYPE) or {},
    }
    local iOrgId = oPlayer:GetOrgID()
    if iOrgId and iOrgId ~= 0 then
        mNet.org_chat = self:GetChatHistory(gamedefines.CHANNEL_TYPE.ORG_TYPE, iOrgId) or {}
    end
    local iTeamId = oPlayer:TeamID()
    if iTeamId then
        mNet.team_chat = self:GetChatHistory(gamedefines.CHANNEL_TYPE.TEAM_TYPE, iTeamId) or {}
    end
    oPlayer:Send("GS2CChatHistory", mNet)
end

function CChatMgr:SetChatHistroy(sMsg, mRoleInfo, iType, iSubId)
    local mData = {
        type = iType,
        cmd = sMsg,
        role_info = mRoleInfo,
    }
    self.m_mHistory[iType] = self.m_mHistory[iType] or {}
    local lRecord = self.m_mHistory[iType]
    if iSubId then
        lRecord = lRecord[iSubId] or {}
    end
    if #lRecord >= 50 then
        tremove(lRecord, 1)
    end
    tinsert(lRecord, mData)
    if iSubId then
        self.m_mHistory[iType][iSubId] = lRecord
    else
        self.m_mHistory[iType] = lRecord
    end
end

function CChatMgr:GetChatHistory(iType, iSubId)
    local mType = self.m_mHistory[iType]
    if iSubId and mType then
        return mType[iSubId]
    end
    return mType
end