--import module

local global = require "global"
local skynet = require "skynet"
local res = require "base.res"

local datactrl = import(lualib_path("public.datactrl"))
local titledefines = import(service_path("title.titledefines"))


function NewTitle(iPid, iTid, create_time, name)
    local o = CTitle:New(iPid, iTid, create_time, name)
    o:Init()
    return o
end

function CheckTitleExpire(iPid, iTid)
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(iPid)
    if not oPlayer then return end
    
    local oTitle = oPlayer.m_oTitleCtrl:GetTitleByTid(iTid)
    if oTitle then
        oTitle:_DoExpire()
    end
end

CTitle = {}
CTitle.__index = CTitle
inherit(CTitle, datactrl.CDataCtrl)

function CTitle:New(iPid, iTid, create_time, name)
    local o = super(CTitle).New(self, {iTid = iTid, iPid=iPid})
    o:SetData("name", name)
    o:SetData("create_time", create_time or get_time())
    o:SetData("use_time", 0)
    return o
end

function CTitle:Init()
    self:Setup()
end

function CTitle:Release()
    super(CTitle).Release(self)
end

function CTitle:Setup()
    -- 称谓失效相关处理
    self:CheckTimeCb()
end

function CTitle:CheckTimeCb()
    self:_CheckExpire()
end

function CTitle:_CheckExpire()
    if self:IsForever() then return end
    
    self:DelTimeCb("_CheckExpire")
    local iLeftTime = self:GetExpireTime()
    iLeftTime = math.max(1, iLeftTime)
    if iLeftTime > 1 * 24 * 3600 then return end

    local iTid = self:TitleID()
    local iPid = self:GetPid()
    local f = function ()
        CheckTitleExpire(iPid, iTid)
    end
    self:AddTimeCb("_CheckExpire", iLeftTime * 1000, f)
end

function CTitle:_DoExpire()
    if is_release(self) then
        return
    end
    local oWorldMgr = global.oWorldMgr
    local oPlayer = oWorldMgr:GetOnlinePlayerByPid(self:GetPid())
    if oPlayer then
        self:SendExpireMail()
        oPlayer:RemoveTitles({self:TitleID()})
    end
end

function CTitle:SendExpireMail()
    local oMailMgr = global.oMailMgr
    local oNotifyMgr = global.oNotifyMgr
    local mData, name = oMailMgr:GetMailInfo(2003)
    if not mData then return end

    local mInfo = table_copy(mData)
    local oToolMgr = global.oToolMgr
    mInfo.context = oToolMgr:FormatColorString(mInfo.context, {title=self:GetShowName()})
    oMailMgr:SendMail(0, name, self:GetPid(), mInfo, 0)
end

-- function CTitle:GetTitleData()
--     local mData = res["daobiao"]["title"]["title"][self:TitleID()]
--     assert(mData,string.format("CTitle GetTitleData err: %d", self:TitleID()))
--     return mData
-- end

function CTitle:TitleID()
    return self:GetInfo("iTid")
end

function CTitle:GetPid()
    return self:GetInfo("iPid")
end

function CTitle:Save()
    local mData = {}
    mData.titleid = self:TitleID()
    mData.name  =  self:GetData("name")
    mData.create_time = self:GetData("create_time")
    mData.use_time = self:GetData("use_time")
    return mData
end

function CTitle:Load(mData)
    self:SetData("name", mData.name)
    self:SetData("create_time", mData.create_time)
    self:SetData("use_time", mData.use_time)
end

function CTitle:GetName()
    return self:GetData("name", self:GetConfigData()["name"])
end

function CTitle:GetShowName()
    return self:GetName()
end

function CTitle:SetName(name)
    self:SetData("name", name)
end

function CTitle:GetUseTime()
    return self:GetData("use_time")
end

function CTitle:SetUseTime()
    self:SetData("use_time", get_time())
end

function CTitle:GetConfigData()
    local mData = res["daobiao"]["title"]["title"][self:TitleID()]
    assert(mData,string.format("CTitle GetConfigData err: %d", self:TitleID()))
    return mData
end

function CTitle:IsForever()
    return self:GetConfigData()["duration_time"] <= 0
end

function CTitle:GetExpireTime()
    if self:IsForever() then return 0 end
    return self:GetData("create_time") + self:GetConfigData()["duration_time"]  * 60 - get_time()
end

function CTitle:IsExpire()
    if self:IsForever() then
        return false
    end
    return get_time() >= self:GetData("create_time") + self:GetConfigData()["duration_time"]  * 60
end

function CTitle:IsShow()
    return self:GetConfigData()["show"] > 0
end

function CTitle:GetShow()
    return self:GetConfigData()["show"]
end

function CTitle:IsEffect()
    return self:GetConfigData()["effect"] == 1 
end

function CTitle:IsInChat()
    return self:GetConfigData()["in_chat"] == 1 
end

function CTitle:GetAttr(attr)
    return 0
end

function CTitle:TitleEffect(oPlayer)
    if not self:IsEffect() then return end
    
    local sFormat = self:GetConfigData()["effect_props"]
    if #sFormat <= 0 then return {} end
    for sAttr,iValue in pairs(formula_string(sFormat, {})) do
        oPlayer.m_oTitleMgr:AddApply(sAttr, self:TitleID(), iValue)
    end
end

function CTitle:TitleUnEffect(oPlayer)
    oPlayer.m_oTitleMgr:RemoveSource(self:TitleID())
end

function CTitle:PackTitleInfo()
    local mNet = {}
    mNet.tid = self:TitleID()
    mNet.name = self:GetShowName()
    mNet.achieve_time = self:GetData("create_time")
    mNet.left_time = self:GetExpireTime()
    mNet.use_time = self:GetUseTime()
    return mNet
end

function CTitle:GetTitleInfo()
    local mNet = {}
    mNet.tid = self:TitleID()
    mNet.name = self:GetShowName()
    mNet.achieve_time = self:GetData("create_time")
    return mNet
end
