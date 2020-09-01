local res = require("data")

local login = {}

login.GS2CHello = function (self, args)
    self:run_cmd("C2GSQueryLogin",{res_file_version={{file_name="achievedata",version=1508158680},{file_name="arenadata",version=1508158680},{file_name="itemdata",version=1508158680}}})
end

login.GS2CQueryLogin = function (self,args)
    self:run_cmd("C2GSLoginAccount", {account = self.account,})
end

login.GS2CLoginAccount = function(self, args)
    local lRole = args.role_list
    if not lRole or not next(lRole) then
        local sName = string.format("DEBUG%s", args.account)
        local iRoleType = math.random(1,2)
        local lSchool = res["roletype"][iRoleType].school
        local iSchool = lSchool[#lSchool]
        self:run_cmd("C2GSCreateRole", {role_type = iRoleType, name = sName, school = iSchool})
    else
        local m = lRole[1]
        self:run_cmd("C2GSLoginRole", {pid = m.pid})
    end
end

login.GS2CCreateRole = function(self, args)
    local m = args.role
    self:run_cmd("C2GSLoginRole", {pid = m.pid})
end

login.GS2CLoginRole = function(self, args)
    self.m_mRoleInfo = args.role or {}
    self.m_iPid = args.pid
    self.m_sAccount = args.account
    self.m_iChannel = 0
    self:run_cmd("C2GSGMCmd", {cmd="choosemap"})
end

return login
