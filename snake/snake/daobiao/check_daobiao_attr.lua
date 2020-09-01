
local  fLua, fOut= ...


local function checkDaoBiao(rFile, wFile)
    -- body
    local rf = io.open(rFile, "r") 
    local data = rf:read("*a")
    rf:close()
    -- local data = 'return {[101] = {content = "进入战斗", id = 101,} , [102] = {content = "还是算了",id = 102,} } '
    local fun = load(data)
    local mData = fun()
    for k,v in pairs(mData) do
        mData = v
        break 
     end
    local  outPuts = {}
    for k,v in pairs(mData) do
        if string.lower(k) ~= k then
            table.insert(outPuts, k)
        end    	
    end
    if #outPuts  > 0 then
        local wf = io.open(wFile, "a")
        local sOut = ""
        for k,v in pairs(outPuts) do
        	sOut = string.format("%s %s", sOut, v)
        end
        wf:write(string.format("check warning:%s %s\n", rFile, sOut))
        wf:close()
        print(string.format("check warning:%s %s\n", rFile, sOut))
    end
    
end

checkDaoBiao(fLua, fOut)
