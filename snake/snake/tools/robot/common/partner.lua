require("tableop")

local partner = {}

partner.GS2CLoginPartner = function(self, args)
    local lPartner = args.partners or {}
    self.m_mPartner = self.m_mPartner or {}
    for _, mPartner in pairs(lPartner) do
        self.m_mPartner[mPartner.id] = mPartner
    end

    if table_count(lPartner) < 1 then
        self:sleep(math.random(8, 10))
        print ("添加伙伴, 设置阵容")
        self:run_cmd("C2GSGMCmd", {cmd="init_robot_partner"})
    end
end

partner.GS2CAddPartner = function(self, args)
    if not args.partner then return end
    self.m_mPartner = self.m_mPartner or {}
    self.m_mPartner[args.partner.id] = args.partner
end

partner.GS2CAllLineupInfo = function(self, args)
    local iCurrLineup = args.curr_lineup or 1
    local mInfo = args.info or {}
    local mData = mInfo[iCurrLineup] or {}
    if not mData.pos_list or table_count(mData.pos_list) < 1 then
        if table_count(self.m_mPartner) < 1 then return end
        local lPartner = table_key_list(self.m_mPartner)
        local mNet = {fmt_id=1, lineup=iCurrLineup, pos_list=lPartner}
        self:run_cmd("C2GSSetPartnerPosInfo", mNet)
    end
end

return partner
