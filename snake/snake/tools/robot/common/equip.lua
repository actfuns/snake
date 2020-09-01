local equip = {}

equip.GS2CEquipLogin = function(self, args)
    self:sleep(math.random(8, 18))
    self:run_cmd("C2GSGMCmd", {cmd="setfuhun 1"})
end

return equip
