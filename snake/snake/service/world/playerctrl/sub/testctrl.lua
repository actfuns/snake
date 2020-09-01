-- 内服角色测试用控制流标记
local testdefines = import(service_path("defines/testdefines"))
local datactrl = import(lualib_path("public.datactrl"))

CTestCtrl = {}
CTestCtrl.__index = CTestCtrl
inherit(CTestCtrl, datactrl.CDataCtrl)

function CTestCtrl:New()
    local o = super(CTestCtrl).New(self)
    o.m_mTester = {}
    return o
end

function CTestCtrl:Save()
    if is_production_env() then
        return nil
    end
    local mData = {}
    if next(self.m_mTester) then
        mData.tester = self.m_mTester
    end
    if next(mData) then
        return mData
    end
end

function CTestCtrl:Load(mData)
    if not mData then
        return
    end
    if is_production_env() then
        return
    end
    self.m_mTester = mData.tester or {}
end

function CTestCtrl:OnLogin(oPlayer, bReEnter)
    if is_production_env() then
        return
    end
    oPlayer:SyncTesterKeys()
end

function CTestCtrl:GetTesterKey(sKey)
    if is_production_env() then
        return
    end
    return self.m_mTester[sKey]
end

function CTestCtrl:SetTesterKey(sKey)
    if is_production_env() then
        return
    end
    self:Dirty()
    self.m_mTester[sKey] = 1
end

function CTestCtrl:DelTesterKey(sKey)
    self:Dirty()
    self.m_mTester[sKey] = nil
end

function CTestCtrl:ClearTesterKeys()
    if is_production_env() then
        return
    end
    self:Dirty()
    self.m_mTester = {}
end

function CTestCtrl:GetTesterAllKeys()
    return table_key_list(self.m_mTester)
end
