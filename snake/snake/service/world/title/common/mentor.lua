local global = require "global"
local skynet = require "skynet"
local res = require "base.res"
local titleobj = import(service_path("title.titleobj"))


function NewTitle(iPid, iTid, create_time, name)
    local o = CTitle:New(iPid, iTid, create_time, name)
    o:Init()
    return o
end


CTitle = {}
CTitle.__index = CTitle
inherit(CTitle, titleobj.CTitle)

function CTitle:TitleEffect(oPlayer)
    if self.m_iRewarded then return end
    
    self:Dirty() 
    self.m_iRewarded = 1
    oPlayer:AddPoint(1)
    oPlayer.m_oBaseCtrl:GS2CPointPlanInfoList()
end

function CTitle:TitleUnEffect(oPlayer)
    --
end

function CTitle:Save()
    local mData = super(CTitle).Save(self)
    mData.rewarded = self.m_iRewarded
    return mData
end

function CTitle:Load(mData)
    if not mData then return end

    super(CTitle).Load(self, mData)
    self.m_iRewarded = mData.rewarded
end


