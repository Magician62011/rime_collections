-- Created by Magician on 2024-10-29 
-- Credit to hchunhui for the initial approach: https://github.com/hchunhui/librime-cloud/
-- Added functionality to save the commit entry to the user dictionary, and switch control.

local json = require("json")
local http = require("simplehttp")
http.TIMEOUT = 0.5

local custom_code = nil 
local save_switch = nil 

local function log_error(info)
	local log_enable = false -- true false
	if log_enable then 
		log.error(info)
	end
end

local function make_url(input, bg, ed)
	return 'https://olime.baidu.com/py?input=' .. input ..
	'&inputtype=py&bg='.. bg .. '&ed='.. ed ..
	'&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end

local function update_dict(env, ctx)
	log_error("function update dict! ")
	-- Memory(engine, schema, name_space)
	env.mem = Memory(env.engine, env.engine.schema, 'translator') -- get dictionary name under name_space for language
	local commit_record = ctx.commit_history:back()
	log_error("commit_record.type: "..tostring(commit_record.type)) -- if get type:'uniquified', means already saved. uniquified by filter component - uniquifier
	log_error("commit_record.text: "..tostring(commit_record.text))
	log_error("custom_code: "..tostring(custom_code))
	-- construct a commit entry
	if commit_record.type == "cloud" then  
		local dict_entry = DictEntry()
		dict_entry.text = commit_record.text
		dict_entry.custom_code = custom_code..' ' -- a space character for constructing user dict key: e.g. Key: 'zhao meng fu \t赵孟頫'
		local result = env.mem:update_userdict(dict_entry, 1, '') 
		--local result = env.mem:update_entry(env.dict_entry, 1, '', env.mem.lang_name)
		log_error("update dict result: "..tostring(result))
	else 
		log_error("no cloud entry to update!")
	end
	log_error("function update dict! end ")
end

-- set up commit_notifier in initialization
local function init(env)
	local ctx = env.engine.context
    ctx.commit_notifier:connect(function()
        log_error("commit notifier detected! ")
        --log_error("env.name_space: "..tostring(env.name_space))
		if custom_code ~= nil and save_switch == true 
		then 
			update_dict(env, ctx)
			custom_code = nil
			save_switch = nil 
		end
	end)
end

local function translator(input, seg, env)
	local cloud_switcher = env.engine.context:get_option("cloud_pinyin") -- check switch state
	if cloud_switcher == true then 
		log_error("baidu cloud pinyin translator: "..input)
		env.engine.context.composition:back().prompt = "    Baidu☁️  按 ' 写入用户词典✍️📙" -- tips , you can comment out this line later
		local comment = " Baidu☁️"  -- " Baidu☁️" or " 写入词典✍️📙"
		
		-- Save Control 
		local save_sign = '\''
		if input:sub(-1,-1) == save_sign then 
			comment  = " 写入词典✍️📙"
			save_switch = true 
			input = input:sub(1,-2)
			log_error("save mode - input new: "..input)
		end 
		
		local url = make_url(input, 0, 5)
		local reply = http.request(url)
		log_error("return url: "..tostring(url))
		local _, j = pcall(json.decode, reply)
		if j.status == "T" and j.result and j.result[1] then
			for i, v in ipairs(j.result[1]) do
				local c = Candidate("cloud", seg.start, seg._end, v[1], comment) 
				c.quality = 3
				if string.gsub(v[3].pinyin, "'", "") == string.sub(input, 1, v[2]) then
					c.preedit = string.gsub(v[3].pinyin, "'", " ")
				end
			yield(c) -- candidate will not be saved to user dictionary on commit

			custom_code = c.preedit -- keep complete code while saving, it will be saved to user dict later
			end
		end
	end 
end

return { init = init, func = translator }



--[[

switches:
  - name: cloud_pinyin
    states: [ 🌈️, ☁️ ]
engine:
  translators:
    - lua_translator@*cloud_pinyin                     # Baidu Cloud Pinyin
__patch:
  key_binder/bindings/+:
    - { when: always, accept: Control+semicolon, toggle: cloud_pinyin }  # switch shortcut key
speller: 
  delimiter: " '" 

--]]