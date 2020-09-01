local global = require "global"
local res = require "base.res"
local datactrl = import(lualib_path("public.datactrl"))
local  record = import(lualib_path("public.record"))
local gamedb = import(lualib_path("public.gamedb"))

function NewHotTopic(...)
    return CHotTopic:New(...)
end

CHotTopic = {}
CHotTopic.__index = CHotTopic
CHotTopic.m_sTempName = "热门公告"
inherit(CHotTopic, datactrl.CDataCtrl)

function CHotTopic:New()
    local o = super(CHotTopic).New(self)
    o:Init()
    return o
end

function CHotTopic:Init()
    self.m_lHDList = {}
    self.m_mHD2Pri = {}
end

function CHotTopic:OnLogin(oPlayer, bReEnter)
    if not global.oToolMgr:IsSysOpen("HOTTOPIC", oPlayer, true) then
        return
    end
    self:CheckFirstLogin(oPlayer)
end

function CHotTopic:CheckFirstLogin(oPlayer)
    if  oPlayer:IsFirstLogin() then
        self:GS2CHotTopicList(oPlayer)
    end
end

function CHotTopic:GS2CHotTopicList(oPlayer)
    local mNet = {}
    mNet["hd_list"] = {}
    for _, mHD in ipairs(self.m_lHDList) do
        if mHD.sname ~= "collect" then
            local iHD = self:GetHDSname2Id(mHD.sname)
            table.insert(mNet["hd_list"], { hd_id = iHD})
        end
    end
    oPlayer:Send("GS2CHotTopicList", mNet)
end

function CHotTopic:NewHour(mNow)
    mNow = mNow or get_timetbl()
    if mNow.date.hour == 5 then
        self:NewDay(mNow)
    end
end

function CHotTopic:NewDay(mNow)
    self:RollHDBar()
end

function CHotTopic:GetConfig()
    return res['daobiao']["hdhottopic"]["config"]
end

function CHotTopic:GetHDConfig(id)
    return res["daobiao"]['hdhottopic']["config"][id]
end

function CHotTopic:GetHDSname2Id(sHuodongName)
    local mSname2Id = res["daobiao"]["hdhottopic"]["sname2id"]
    return mSname2Id[sHuodongName]
end

function CHotTopic:Register(sHuodongName)
    self:InsertNewHD(sHuodongName)
end

function CHotTopic:UnRegister(sHuodongName)
    self:RemoveOldHD(sHuodongName)
end

function CHotTopic:InsertNewHD(sHuodongName)
    if self.m_mHD2Pri[sHuodongName] then return end
    local iHD = self:GetHDSname2Id(sHuodongName)
    if not iHD then
        record.warnning("%s no config in hdhottopic.config", sHuodongName)
        return
    end
    local mHDconfig = self:GetHDConfig(iHD)
    local iInsertPos = #self.m_lHDList + 1
    for index, mHD in ipairs(self.m_lHDList) do
        if mHDconfig.priority < mHD.priority then
            iInsertPos = index
            break
        end
    end
    table.insert(self.m_lHDList, iInsertPos, {sname = sHuodongName, priority = mHDconfig.priority})
    self.m_mHD2Pri[sHuodongName] = mHDconfig.priority
end

function CHotTopic:RemoveOldHD(sHuodongName)
    if not self.m_mHD2Pri[sHuodongName] then return end
    for index, mHD in ipairs(self.m_lHDList) do
        if sHuodongName == mHD.sname then
            table.remove(self.m_lHDList, index)
            break
        end
    end
    self.m_mHD2Pri[sHuodongName] = nil
end

function CHotTopic:RollHDBar()
    if not next(self.m_lHDList) then return end
    local mConfig = self:GetConfig()
    local iPriority = self.m_lHDList[#self.m_lHDList].priority + 1
    local mRollEnd = table.remove(self.m_lHDList, 1)
    mRollEnd.priority = iPriority
    table.insert(self.m_lHDList, mRollEnd)
    self.m_mHD2Pri[mRollEnd.sname] = mRollEnd.priority
end

function CHotTopic:OnServerStartEnd()
    local mConfig = self:GetConfig()
    local oHuodongMgr = global.oHuodongMgr
    for _, mData in pairs(mConfig) do
        local oHuodong = oHuodongMgr:GetHuodong(mData.sname)
        if oHuodong and oHuodong:IsHuodongOpen() then
            if not self.m_mHD2Pri[mData.sname] then
                table.insert(self.m_lHDList, {sname = mData.sname, priority = mData.priority})
                self.m_mHD2Pri[mData.sname] = mData.priority
            end
        end
    end
    local Func = function(a, b)
        return a.priority < b.priority
    end
    table.sort(self.m_lHDList, Func)
end

function CHotTopic:TestOp(iFlag, mArgs)
    local pid = mArgs[#mArgs]
    local oMaster = global.oWorldMgr:GetOnlinePlayerByPid(pid)
    if iFlag == 100 then
        global.oChatMgr:HandleMsgChat(oMaster, [[
100 - hottopicop 100 帮助信息
101 - 注册活动（hottopicop 101 { id = 1001}
(可查看huodong/hottopic/hottopic.xlsx))
102 - 取消注册 (hottopicop 102 1001)
103 - 刷天 
104 - 清空玩家首登记录
106 - 清空所有注册活动
107 - 主动发送活动列表
108 - 打印列表
109 - 重新初始化列表
            ]])
    elseif iFlag == 101 then
        local id = mArgs.id
        local mConfig = self:GetHDConfig(id)
        if not mConfig then return end
        local sName = mConfig.sname
        self:Register(sName)
    elseif iFlag == 102 then
        local id = mArgs.id
        local mConfig = self:GetHDConfig(id)
        if not mConfig then return end
        local sName = mConfig.sname
        self:UnRegister(sName)
    elseif iFlag == 103 then
        self:NewDay()
    elseif iFlag == 104 then
        oMaster.m_oTodayMorning:Set("today_first_login", 1)
    elseif iFlag == 106 then
        self.m_lHDList = {}
        self.m_mHD2Pri = {}
        self:Dirty()
    elseif iFlag == 107 then
        self:GS2CHotTopicList(oMaster)
    elseif iFlag == 108 then
        local sMsg = ""
        for _, mHD in ipairs(self.m_lHDList) do
            local id = self:GetHDSname2Id(mHD.sname)
            local mConfig = self:GetHDConfig(id)
            sMsg = sMsg .. mConfig.name .. "\n"
        end
        global.oChatMgr:HandleMsgChat(oMaster,sMsg)
    elseif iFlag == 109 then
        self.m_lHDList = {}
        self.m_mHD2Pri = {}
        self:OnServerStartEnd()
    end
end
