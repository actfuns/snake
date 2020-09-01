--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local record = require "public.record"

local gamedefines = import(lualib_path("public.gamedefines"))
local datactrl = import(lualib_path("public.datactrl"))
local titledefines = import(service_path("title.titledefines"))
local loadtitle = import(service_path("title.loadtitle"))


CTitleCtrl = {}
CTitleCtrl.__index = CTitleCtrl
inherit(CTitleCtrl, datactrl.CDataCtrl)

function CTitleCtrl:New(iPid)
    local o = super(CTitleCtrl).New(self,{pid=iPid})
    o.m_mTitles = {}
    return o
end

function CTitleCtrl:Release()
    for _,oTitle in pairs(self.m_mTitles) do
        baseobj_safe_release(oTitle)
    end
    self.m_mTitles = {}
    super(CTitleCtrl).Release(self)
end

function CTitleCtrl:GetPid()
    return self:GetInfo("pid")
end

function CTitleCtrl:Save()
    local mData = {}
    local mTitleData = {}
    for _,oTitle in pairs(self.m_mTitles) do
        table.insert(mTitleData, oTitle:Save())
    end

    mData.title_list = mTitleData
    mData.use_tid = self:GetData("use_tid")
    return mData
end

function CTitleCtrl:Load(mData)
    if not mData then return end

    for _,m in ipairs(mData.title_list) do
        local oTitle = loadtitle.NewTitle(self:GetPid(), m.titleid, m.create_time)
        oTitle:Load(m)
        self.m_mTitles[m.titleid] = oTitle
    end
    self:SetData("use_tid", mData.use_tid)
end

function CTitleCtrl:AddTitle(oPlayer, iTid, create_time, name)
    local oTitle = loadtitle.NewTitle(self:GetPid(), iTid, create_time, name)
    if oTitle:IsExpire() then
        baseobj_delay_release(oTitle)
        local mLogData={
            pid = oPlayer:GetPid(),
            title = iTid,
            }
        record.log_db("title", "failadd",mLogData)
        return
    end

    local mLogData={
        pid = oPlayer:GetPid(),
        title = iTid,
        }
    record.log_db("title", "add",mLogData)

    self:Dirty()
    local oOldTitle = self:GetTitleByTid(iTid)
    if oOldTitle then
        oOldTitle:TitleUnEffect(oPlayer)
        baseobj_delay_release(oOldTitle)
    end

    self:GS2CAddTitleInfo({oTitle})

    local oTitleMgr = global.oTitleMgr
    local sMsg = oTitleMgr:GetText(1004, {title = oTitle:GetName()})
    oPlayer:NotifyMessage(sMsg)
    global.oChatMgr:HandleMsgChat(oPlayer, sMsg)
    self.m_mTitles[iTid] = oTitle

    local oUseTitle = self:GetTitleByTid(self:GetUseTid())
    if oTitle:IsShow() then
        if not oUseTitle or oTitle:GetShow() > oUseTitle:GetShow() then
            self:UseTitle(oPlayer, iTid)
        end
    end
    oTitle:TitleEffect(oPlayer)
    -- self:SynclSumData(oPlayer)
    self:PropPlayerChange(oPlayer)
end

function CTitleCtrl:RemoveTitles(oPlayer, lTitID)
    if self:GetUseTid() > 0 and table_in_list(lTitID, self:GetUseTid()) then
        self:UnUseTitle(oPlayer)
    end
    local mLogData={
        pid = oPlayer:GetPid(),
        title = lTitID,
        }
    record.log_db("title", "del",mLogData)

    for _,i in ipairs(lTitID) do
        local oTitle = self.m_mTitles[i]
        if oTitle then
            oTitle:TitleUnEffect(oPlayer)
            baseobj_delay_release(oTitle)
            self.m_mTitles[i] = nil
        end
    end
    -- self:SynclSumData(oPlayer)
    self:PropPlayerChange(oPlayer)
    self:GS2CDelTitleInfo(lTitID)
    self:Dirty()
end

function CTitleCtrl:SyncTitleName(oPlayer, iTid, name)
    local oTitle = self:GetTitleByTid(iTid)
    if not oTitle then return end

    self:Dirty()
    oTitle:SetName(name)
    if iTid == self:GetUseTid() then
        oPlayer:PropChange("title_info")
        oPlayer:SyncSceneInfo({title_info=oPlayer:PackTitleInfo()})
    end
    oPlayer:Send("GS2CUpdateTitleInfo", {info=oTitle:PackTitleInfo()})
end

function CTitleCtrl:RrefreshTitle(oPlayer, iTid)
    local oTitle = self:GetTitleByTid(iTid)
    if not oTitle then return end

    oPlayer:Send("GS2CUpdateTitleInfo", {info=oTitle:PackTitleInfo()})
end

function CTitleCtrl:GetUseTid()
    return self:GetData("use_tid") or 0
end

function CTitleCtrl:GetTitleByTid(iTid)
    return self.m_mTitles[iTid]
end

function CTitleCtrl:UseTitle(oPlayer, iTid)
    local oTitle = self:GetTitleByTid(iTid)
    if not oTitle then return end

    local oOldTitle = self:GetTitleByTid(self:GetUseTid())
    self:SetData("use_tid", iTid)
    oTitle:SetUseTime()
    -- self:SynclSumData(oPlayer)
    -- if oTitle:IsEffect()  or (oOldTitle and oOldTitle:IsEffect()) then
    --     oPlayer:SecondLevelPropChange()
    -- end

    oPlayer:Send("GS2CUpdateUseTitle",{tid=iTid})
    oPlayer:PropChange("title_info")
    oPlayer:Send("GS2CUpdateTitleInfo", {info=oTitle:PackTitleInfo()})
    oPlayer:SyncSceneInfo({title_info=oPlayer:PackTitleInfo()})
    self:Dirty()
end

function CTitleCtrl:UnUseTitle(oPlayer)
    local oTitle = self:GetTitleByTid(self:GetUseTid())
    self:SetData("use_tid", 0)
    -- self:SynclSumData(oPlayer)
    -- if oTitle and oTitle:IsEffect() then
    --     oPlayer:SecondLevelPropChange()
    -- end

    oPlayer:Send("GS2CUpdateUseTitle",{tid=0})
    oPlayer:PropChange("title_info")
    oPlayer:SyncSceneInfo({title_info={}})
    self:Dirty()
end

function CTitleCtrl:PreLogin(oPlayer, bReEnter)
    if not bReEnter then
        self:SetupTitle(oPlayer)
        -- self:SynclSumData(oPlayer)
        self:PropPlayerChange(oPlayer)
    end
end

function CTitleCtrl:OnLogin(oPlayer, bReEnter)
    local mNet = {}
    for _,oTit in pairs(self.m_mTitles) do
        table.insert(mNet, oTit:PackTitleInfo())
    end
    oPlayer:Send("GS2CTitleInfoList", {infos=mNet})

    local iTid = self:GetUseTid()
    if iTid and iTid > 0 then
        oPlayer:Send("GS2CUpdateUseTitle", {tid=iTid})
    end
end

function CTitleCtrl:SetupTitle(oPlayer)
    for _, oTitle in pairs(self.m_mTitles) do
        oTitle:TitleEffect(oPlayer)
    end
end

function CTitleCtrl:PropPlayerChange(oPlayer)
    for sAttr,_ in pairs(titledefines.ATTRS) do
        oPlayer:AttrPropChange(sAttr)
    end
end

-- function CTitleCtrl:SynclSumData(oPlayer)
--     for sAttr,_ in pairs(titledefines.ATTRS) do
--         oPlayer:SynclSumSet(gamedefines.SUM_DEFINE.MO_TITLE,sAttr,self:GetApply(sAttr))
--     end
-- end

function CTitleCtrl:UnDirty()
    super(CTitleCtrl).UnDirty(self)
    for _, oTitle in pairs(self.m_mTitles) do
        if oTitle:IsDirty() then
            oTitle:UnDirty()
        end
    end
end

function CTitleCtrl:IsDirty()
    local bDirty = super(CTitleCtrl).IsDirty(self)
    if bDirty then return true end

    for _,oTitle in pairs(self.m_mTitles) do
        if oTitle:IsDirty() then return true end
    end
    return false
end

function CTitleCtrl:GS2CAddTitleInfo(oTitles)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    local mNet = {}
    for _,oTit in pairs(oTitles) do
        table.insert(mNet, oTit:PackTitleInfo())
    end
    oPlayer:Send("GS2CAddTitleInfo", {infos=mNet})
end

function CTitleCtrl:GS2CDelTitleInfo(iTitles)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if not oPlayer then return end

    oPlayer:Send("GS2CDelTitleInfo", {tids=iTitles})
end

function CTitleCtrl:GetTitleInfo()
    local oTitle = self:GetTitleByTid(self:GetUseTid())
    if oTitle then
        return oTitle:GetTitleInfo()
    end
end

function CTitleCtrl:GetTitleInfo2Chat()
    local oTitle = self:GetTitleByTid(self:GetUseTid())
    if oTitle and oTitle:IsInChat() then
        return oTitle:GetTitleInfo()
    end
end

function CTitleCtrl:CheckTimeCb()
    for _,oTitle in pairs(self.m_mTitles) do
        oTitle:CheckTimeCb()
    end
end

