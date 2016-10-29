local tools = require("lib.tools")
local aries = require("index")({name="test2",timeout=1,isDebug = false, ctx={a=1}})
local aries2 = require("index")({name="test3",timeout=1,isDebug = false, ctx={a=1}})

aries.startTag="{{"
aries.endTag="}}"

aries2.startTag="{{"
aries2.endTag="}}"

local html1, err = aries:render(
    tools.rfile("tpl/" .. aries.name .. ".yc")
)

print(err or html1)
local html, err1 = aries2:render(
    tools.rfile("tpl/" .. aries2.name .. ".yc")
)
print(err1 or html)