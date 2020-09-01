local global = require "global"
local gamedefines = import(lualib_path("public.gamedefines"))
local playersend = require "base.playersend"
local CEntity = import(service_path("entityobj")).CEntity

function NewEffectEntity(...)
    return CEffectEntity:New(...)
end

------------------------------------
CEffectEntity = {}
CEffectEntity.__index = CEffectEntity
inherit(CEffectEntity, CEntity)

function CEffectEntity:New(iEid, iEffId, ...)
    local o = super(CEffectEntity).New(self, iEid, ...)
    o.m_iType = gamedefines.SCENE_ENTITY_TYPE.EFFECT_TYPE
    o.m_iEffectId = iEffId
    return o
end

function CEffectEntity:GetAoiInfo()
    local m = {
        objid = self:GetData("objid"),
        pos_info = self:GetGeometryPosInfo(),
        effect_id = self.m_iEffectId,
    }
    return m
end

function CEffectEntity:PackEnterAoiInfo()
    return playersend.PackData("GS2CEnterAoi",{
            scene_id = self:GetSceneId(),
            eid = self:GetEid(),
            type = self:Type(),
            aoi_effect = self:GetAoiInfo(),
        })
end