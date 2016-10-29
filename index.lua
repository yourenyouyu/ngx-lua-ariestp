local tools = require("lib.tools")

function getInclude(str)
    return tools.rfile("tpl/" .. str .. ".yc")
end

local superAries = {
    name = "aries",
    startTag = "<%",
    endTag = "%>",
    timeout = -1,
    isDebug = true,
    getInclude = getInclude,
	includes = {},
    ctx = {}
}
--[[
    @desc
        render File function
    @params
        filePath    @type string
    @return
        result      @type string
        err         @type error
 ]]
function superAries.renderFile(self,filePath)
    self:render(strpath)
    return self.name
end

--[[
    @desc
        render template function
    @params
        templateStr @type string
    @return
        result      @type string
        err         @type error
 ]]
function superAries.render(self, str)
    local util = require("lib.util")()
    local result = nil
    local bool, errMsg = pcall(function()
        local code = util.packTpl(self, str)
        result = util.compile(self, code)
    end)

    if not bool then
        if isDebug then
            local line, realErr= errMsg:match(":(%d+):(.*)")
            local innerLine, innerErrMsg = realErr:match(":(%d+):(.*)")
            -- 自定义错误时  会进入此分支
            if not innerErrMsg then
                return nil, string.format("%s %s %s","lua-ariestp>>util.lua", line, realErr)
            end

            local errSource = {}
            for i, chunk in pairs(util.sourceMap) do
                -- print(chunk.sourceLine, chunk.includesStr, chunk.innerLine, chunk.lineContent)
                if chunk.finalLine == tonumber(innerLine) then
                    table.insert(errSource, chunk)
                end
            end
            if errSource[1] and errSource[#errSource] then
                local errInSameline = (errSource[1].innerLine ~= errSource[#errSource].innerLine) or (errSource[1].includesStr ~= errSource[#errSource].includesStr)
                if errInSameline then
                    return nil, string.format("(%s:%s) or (%s:%s) have error %s", errSource[1].lineTrack, errSource[1].innerLine, errSource[#errSource].lineTrack, errSource[#errSource].innerLine, innerErrMsg)
                end
            end

            if errSource[1] then
                return nil, string.format("%s：%s have error %s", errSource[1].lineTrack, errSource[1].innerLine, innerErrMsg)
            end
        end
        return nil, errMsg
    end
    return result , nil
end

--需要实现
function superAries.minify(self,rootPath)
    return rootPath
end



local function new(options)
    -- 此处先覆盖 后面 在实现追加
    local options = options and options or {}
    local aries =  options
    return setmetatable(aries,{__index=superAries})
end

return new