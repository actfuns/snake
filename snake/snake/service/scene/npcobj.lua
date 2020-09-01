local global = require "global"
local skynet = require "skynet"
local interactive = require "base.interactive"
local net = require "base.net"
local geometry = require "base.geometry"
local playersend = require "base.playersend"

local gamedefines = import(lualib_path("public.gamedefines"))
local CEntity = import(service_path("entityobj")).CEntity
local loadmoveai = import(service_path("moveai.loadmoveai"))

function NewNpcEntity(...)
    return CNpcEntity:New(...)
end


BlockHelperFunc = {}

function BlockHelperFunc.name(oEntity)
    return oEntity:GetName()
end

function BlockHelperFunc.model_info(oEntity)
    return oEntity:GetModelInfo()
end

function BlockHelperFunc.war_tag(oEntity)
    return oEntity:GetWarTag()
end

function BlockHelperFunc.xunluoid(oEntity)
    return oEntity:GetXunLuoID()
end

function BlockHelperFunc.title(oEntity)
    return oEntity:GetTitle()
end

function BlockHelperFunc.action(oEntity)
    return oEntity:GetActionInfo()
end

CNpcEntity = {}
CNpcEntity.__index = CNpcEntity
inherit(CNpcEntity, CEntity)

function CNpcEntity:New(iEid)
    local o = super(CNpcEntity).New(self, iEid)
    o.m_iType = gamedefines.SCENE_ENTITY_TYPE.NPC_TYPE
    o.m_oMoveAI = nil
    return o
end

function CNpcEntity:MonsterFlag()
    if self:GetData("class_type") == "global" then
        return false
    end
    return true
end

function CNpcEntity:EnterWar()
    self:SetData("war_tag",1)
    self:BlockChange("war_tag")
end

function CNpcEntity:LeaveWar()
    self:SetData("war_tag",0)
    self:BlockChange("war_tag")
end

function CNpcEntity:GetAoiInfo()
    local mBlockInfo = self:BlockInfo()
    local mModelInfo = mBlockInfo.model_info or {}
    if mModelInfo.horse_height then
        mModelInfo.horse_height = nil
    end
    local m = {
        npctype = self:GetData("npctype"),
        func_group = self:GetData("func_group"),
        npcid = self:GetData("npcid"),
        pos_info = self:GetGeometryPosInfo(),
        block = mBlockInfo,
    }
    return m
end

function CNpcEntity:BlockInfo(m)
    local mRet = {}
    if not m then
        m = BlockHelperFunc
    end
    for k, _ in pairs(m) do
        local f = assert(BlockHelperFunc[k], string.format("BlockInfo fail f get %s", k))
        mRet[k] = f(self)
    end
    return net.Mask("base.NpcAoiBlock", mRet)
end

function CNpcEntity:BlockChange(...)
    local l = table.pack(...)
    self:SetAoiChange(l)
end

function CNpcEntity:ClientBlockChange(m)
    local mBlock = self:BlockInfo(m)
    self:SendAoi("GS2CSyncAoi", {
        scene_id = self:GetSceneId(),
        eid = self:GetEid(),
        type = self:Type(),
        aoi_npc_block = mBlock,
    })
end

function CNpcEntity:SyncInfo(mArgs)
    if mArgs.name then
        self:SetData("name", mArgs.name)
        self:BlockChange("name")
    end
    if mArgs.model_info then
        self:SetData("model_info", mArgs.model_info)
        self:BlockChange("model_info")
    end
    if mArgs.title then
        self.m_sTitle = mArgs.title
        self:BlockChange("title")
    end
end

function CNpcEntity:SyncPos(mPos)
    self:SendAoi("GS2CSyncPos", {
        scene_id = self:GetSceneId(),
        eid = self:GetEid(),
        pos_info = gamedefines.CoverPos(mPos)
    })

    self:SetPos({
        x = mPos.x,
        y = mPos.y,
        face_x = mPos.face_x,
        face_y = mPos.face_y,
    })
    self:SetSpeed(gamedefines.SPEED_MOVE)
end

function CNpcEntity:GetXunLuoID()
    return self.m_iXunLuoID
end

function CNpcEntity:GetTitle()
    return self.m_sTitle
end

function CNpcEntity:InitMoveAI()
    local mMoveAIInfo = self:GetData("moveai_info")
    if mMoveAIInfo then
        local oMoveAI = loadmoveai.NewMoveAI(mMoveAIInfo.aitype)
        oMoveAI:Init(self, mMoveAIInfo.aiargs)
        self.m_oMoveAI = oMoveAI
    end
end

function CNpcEntity:InitTitle(sTitle)
    self.m_sTitle = sTitle
end

function CNpcEntity:Release()
    if self.m_oMoveAI then
        local oMoveAI = self.m_oMoveAI
        oMoveAI:Release()
        self.m_oMoveAI = nil
    end
    super(CNpcEntity).Release(self)
end

function CNpcEntity:PackEnterAoiInfo()
    return playersend.PackData("GS2CEnterAoi",{
            scene_id = self:GetSceneId(),
            eid = self:GetEid(),
            type = self:Type(),
            aoi_npc = self:GetAoiInfo(),
        })
end
