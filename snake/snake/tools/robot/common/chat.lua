require("tableop")
require("stringop")
local res = require("data")

local chat = {}

local function ChooseText()
    local lHuodong = table_key_list(res["huodong"])
    local sHuodong = lHuodong[math.random(#lHuodong)]
    local mText = res["huodong"][sHuodong]["text"]
    local lChat = table_key_list(mText)
    if #lChat <= 0 then
        return "哎呦，不知道说什么好了"
    end
    local sMsg = mText[lChat[math.random(#lChat)]].content
    return split_string(split_string(sMsg, "\\")[1], "\n")[1]
end

chat.GS2CUpdateStrengthenInfo = function(self, args)
    self:fork(function()
        while 1 do
            self:sleep(math.random(30))
            local msg = ChooseText()
            local channel = math.random(2) < 2 and 4 or 1
            self:run_cmd("C2GSGMCmd", {
                cmd = string.format([[channelchat %d "%s"]], channel, msg)
            })
        end
    end)
end

return chat
