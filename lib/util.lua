function util()
	local tools = require("lib.tools")

	local util = {
		-- sourceMap 为渲染后的文件与源文件的行号对应表
		sourceMap = {}
	}

	--[[
	    @desc
	        将lua代码放置到解释器里面，返回一个函数以备运行代码
	    @params
	        code    	@type string 	-- 拼接好的lua代码字符串
			name		@type string 	-- 所在模板名字
			ctx			@type table		-- 函数执行的上下文
	    @return
			func		@type function
	 ]]
	local function exec(code, name, ctx)
		local name = name or 'aries'

		local func, err
		if setfenv then
			func, err = loadstring(code)
			if func then
				setfenv(func, ctx)
			end
		else
			func, err = load(code, name, 't', ctx)
		end

		if not func then
			error(name .. " have error " .. err, 2)
		end

		return func
	end

	--[[
	    @desc
	        在自定义标签中将除了字母数字之外的特殊字符转义，以做正则拼接之用
	    @params
	        str    		@type string 	-- 用户自定义的标签
	    @return
	        result      @type string 	-- 转义后的字符串
	 ]]
	local function escapetag(str)
		return str:gsub("([^%w])","%%%1")
	end

	--[[
	    @desc
	        将整个模板字符串拆分成对应的块（标识为代码还是文本或为表达式）返回一个迭代器
	    @params
			this		@type table
	        template    @type string
	    @return
	        result      @type function 	-- iterator
	 ]]
	local function splitTpl(this, template)
		if this.startTag == "" then
			this.startTag = "<%"
		end
		if this.endTag == "" then
			this.endTag = "%>"
		end
		local luaCodeReg = escapetag(this.startTag) .. "(.-)" .. escapetag(this.endTag)
		local includeReg = "^"..escapetag(this.startTag) .. " include (.-)" .. escapetag(this.endTag)
		local expressReg = "^"..escapetag(this.startTag) .. "=(.-)" .. escapetag(this.endTag)
		local position = 1

		return function ()
			if not position then
				return nil
			end
			local luaCodeStart, luaCodeEnd, luaCode= template:find(luaCodeReg, position)
			local chunk = {}
			if luaCodeStart == position then
				local includeStart, includeEnd, includeTpl = template:find(includeReg, position)
				local expressStart, expressEnd, express, prefixSpace
				if not includeStart then
					 expressStart, expressEnd, express = template:find(expressReg, position)
				end
				if position > 1 then
					_, _, prefixSpace = template:sub(1, position - 1):find("([\t ]-)$", 1)
				end

				if includeStart then
					chunk.type = "include"
					chunk.text = tools.trim(includeTpl)
					chunk.space = prefixSpace or ""
				elseif expressStart then
					chunk.type = "expression"
					chunk.text = tools.trim(express)
				else
					chunk.type = "code"
					chunk.text = luaCode
				end

				position = luaCodeEnd + 1
				return chunk
			elseif luaCodeStart then
				chunk.type = "text"
				chunk.text =" " .. template:sub(position, luaCodeStart - 1) .. " "
				position = luaCodeStart
				return chunk
			else
				chunk.text = " "..template:sub(position) .. " "
				chunk.type = "text"
				position = nil
				return (#chunk.text > 0) and chunk or nil
			end
		end
	end

	--[[
	    @desc
	        将拆分的对应的语法块中include的内容解析出来
	    @params
			this			@type table
	        template    	@type string 	-- 模板字符串
			includesStr 	@type string 	-- 代表进入到哪一层include的字符串
			lineTrack		@type string 	-- 代表进入到哪一层include的字符串并记下每层行号
	    @return
			finalTplChunks	@type table 	-- 将include里面内容解析后 进行拆分的最后结果
			includes 		@type table 	-- 此模板字符串引入的所有模板（包括相同数据）
	 ]]

	-- sourceLine源码里面的行  finalLine最终渲染的行  includes 里面所有引入的模板名
	local sourceLine, finalLine, includes, finalTplChunks = 1, 1, {}, {}

	local function parseInclude(this, template, includesStr, lineTrack)
		-- 在include 内部的行
		local innerLine = 1
		-- 代表进入到哪一层的include
		local includesStr = includesStr or this.name
		-- 每层引入的模板 并记录下相应的行号
		local lineTrack = lineTrack or this.name
		local includeList = tools.split(tostring(includesStr),">>")
		local includeMap = {}
		for _,v in pairs(includeList) do
			includeMap[v] = true
		end
		table.insert(finalTplChunks, "do")
		for chunk in splitTpl(this, template) do
			if chunk.type == "include" then
				if includeMap[chunk.text] == true then
					error(includesStr.. " can't include same template " .. chunk.text , 2)
				end
				-- 此处用于去重this.includes 里面相同的模板名字
				includes[chunk.text] = true
				local str = this.getInclude(chunk.text)
				str = str:gsub("\n", "\n" .. chunk.space)
				parseInclude(this, str, includesStr..">>"..chunk.text, lineTrack .. "：" .. innerLine .. " >> " .. chunk.text )
			else

				if this.isDebug then

					-- 如果在源文件中 sourceLine 才减去 1 , 防止每次来都多加 1
					if includesStr == this.name then
						sourceLine = sourceLine - 1
					end
					finalLine = finalLine - 1
					innerLine = innerLine - 1

					-- 追加空格是因为 split方法 对于收尾是\n 会少拆分
					local splitMap= tools.split(" ".. chunk.text .. " ","\n")
					for k, v in pairs(splitMap) do
						finalLine = finalLine + 1
						innerLine = innerLine + 1
						-- map 为每一行 与 渲染行 的映射表
						local map = {}
						-- 说明是在源文件中
						if includesStr == this.name then
							sourceLine = sourceLine + 1
							innerLine = sourceLine
						end

						map = {
							sourceLine = sourceLine,
							finalLine = finalLine,
							innerLine = innerLine,
							includesStr = includesStr,
							lineTrack = lineTrack,
							lineContent = v
						}
						table.insert(util.sourceMap,map)
					end

				end

				table.insert(finalTplChunks, chunk)
			end

		end
		table.insert(finalTplChunks, "end")

		return finalTplChunks, includes
	end
	--[[
	    @desc
	        对相应的语法块用函数包装一下，返回包装后的lua代码字符串
	    @params
			this		@type table
	        template    @type string
	    @return
			code		@type string
	 ]]
	function util.packTpl(this, template)
		local aries = "ctx.print"
		local output, includes = parseInclude(this, template)
		for include, _ in pairs(includes) do
			table.insert(this.includes, include)
		end
		-- 保存所有的lua代码
		local packCode = {}
		for i, chunk in ipairs(output) do
			if chunk.type == "expression" then
				table.insert(packCode, aries..'('..chunk.text..')')
			elseif chunk.type == "code" then
				table.insert(packCode, " " .. chunk.text .. " ")
			elseif chunk.type == "text" then
				if chunk.text ~= "" then
					table.insert(packCode, aries..'('.."[=["..string.format("%s", chunk.text).."]=]"..')')
				end
			else
				table.insert(packCode, chunk)
			end
		end
		local code = table.concat(packCode, ' ')
		return code
	end
	-- 调用clone 是防止用户设置coroutine，table等某些字段 污染全局作用域  影响其他渲染
	local whitelist = {
		ipairs = ipairs,
		pairs = pairs,
		coroutine = tools.clone(coroutine),
		type = type,
		string = tools.clone(string),
		table = tools.clone(table),
		math = tools.clone(math),
		os = {
			date = os.date,
			time = os.time
		}
	}

	--[[
	    @desc
	        将lua代码字符串编译执行，返回执行后的内容
	    @params
			this		@type table
	 		code 		@type string 	-- lua代码串
	    @return
			str			@type string
	 ]]

	function util.compile(this, code)
		local result, ctxSon, ctxGrandson = {}, {}, {}
		local function print(text, escape)
			local escape = escape or false
			if not escape then
				table.insert(result, string.format("%s", text))
			else
				table.insert(result, string.format("%q", text))
			end
		end
		local locks = {}
		local function lock(field)
			-- ctxSon[field] = nil
			locks[field] = true
		end

		local function unlock(field)
			locks[field] = false
			-- ctxSon[field] = nil
		end

		this.ctx.print = print
		this.ctx.yield = coroutine.yield -- 防止用户写coroutine.yield = nil 导致死循环无法检测 所以将其存为ctx的属性 使之无法更改
		this.ctx.lock = lock
		this.ctx.unlock = unlock
		local strid = tools.guid("")
		if this.timeout > 0 then
			code = "coroutine.create = nil " .. code
			code = code:gsub("(['\"])(.-)%1", function(t1, t2)
			    return t1 .. t2:gsub('end', ('☯♔' .. strid)):gsub('repeat', ('㊥♔' .. strid)) .. t1
			end):gsub("(%[[=]*%[)(.-)(%][=]*%])", function(t1, t2, t3)
			    return t1 .. t2:gsub('end', ('☯♔' .. strid)):gsub('repeat', ('㊥♔' .. strid)) .. t3
			end)
			code = code:gsub("end","ctx.yield%(%) end"):gsub("repeat","repeat ctx.yield%(%) ")
			code = code:gsub(('☯♔' .. strid), 'end'):gsub(('㊥♔' .. strid), 'repeat')
		else
			whitelist.coroutine = coroutine
		end
		setmetatable(ctxSon, {
	       	__index = this.ctx
	    })

		setmetatable(ctxGrandson, {
		__newindex = function (t,k,v)
			if this.ctx[k] ~= nil  then
				error("ctx.".. k .." is exists", 2)
			elseif locks[k] == true then
				error(k .. " is locked", 2)
			else
				ctxSon[k] = v
			end
	   	end,
	   	__index = ctxSon
	   	})
		local ctx = setmetatable(whitelist, { __index = {ctx=ctxGrandson}})

		local func = exec(code, this.name, ctx)
		local coroutineFunc = function()
			local co = coroutine.create(func)
			local start = os.time()
			local ok,errMsg = coroutine.resume(co)
			if not ok then
				error(errMsg, 2)
			end
			while true do
				if (this.timeout > 0) and (os.time() - start > this.timeout) then
					error(" render this tmplate is timeout ", 2)
					break
				elseif coroutine.status(co) == "dead" then
					break
				else
					local ok,errMsg = coroutine.resume(co)
					if not ok then
						error(errMsg, 2)
					end
				end
			end
		end
		local ok, err = pcall(coroutineFunc)
		if not ok then
			error(this.name .. " have error " .. err, 2)
		end

		return table.concat(result, "")
	end

	return util

end
return util