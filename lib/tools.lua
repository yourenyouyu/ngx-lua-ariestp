-- tools 文件提供一些公共类库
local tools = {

}

function tools.split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
    	if s ~= 1 or cap ~= "" then
	 		table.insert(t,cap)
      	end
      	last_end = e+1
      	s, e, cap = str:find(fpat, last_end)
   	end
   	if last_end <= #str then
    	cap = str:sub(last_end)
      	table.insert(t, cap)
    end
    return t
end

function tools.ltrim(str)
    return string.gsub(str, "^[ \t\r]+", "")
end

function tools.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function tools.guid(pr)
    math.randomseed(os.time())
    local links, tb, gs = { [8] = true, [12] = true, [16] = true, [20] = true }, {}, {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"}
    for i = 1, 32 do
        local link = ""
        if links[i] ~= nil then
            link = pr
        end
        table.insert(tb, gs[math.random(1, 16)] .. link)
    end
    return table.concat(tb)
end

function tools.clone (t) -- deep-copy a table
if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = clone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

function tools.rfile(path)
    local file = io.open(path, "r")
    local data = file:read("*a")
    file:close();
    return data
end

return tools