-- Created by Magician on 2024-10-16 
-- Inspired by rime-english https://github.com/sdadonkey/rime-english

local cands = {}  -- temp table

-- control log error 
local function log_error(info)
	local log_enable = false -- true false
	if log_enable then 
		log.error(info)
	end
end

-- wildcard method
-- e.g. \ab*c -> \ab.*c.*   at least '\a' return results 
local function wildcard_limited_filter(input, env)
	local config = env.engine.schema.config
	local context = env.engine.context
	local segment = context.composition:back()
	local tag = config:get_string("latex_input/tag") or 'latex'
	--local prefix = config:get_string("latex_input/prefix")
	--local prefix_len = prefix and string.len(prefix) or 0
	local suffix = config:get_string("latex_input/suffix")
	local suffix_len = suffix and string.len(suffix) or 0

	local tag_check = segment:has_tag(tag) and true or false 

	if tag_check == true and string.len(context.input) > 1 then  
	-- if tag_check == true then  
		local wildcard = config:get_string("latex_input/wildcard") or '*'
		local input_string = env.engine.context.input	
		log_error("input_string:"..input_string)
		--if prefix~=nil and input_string:sub(1,prefix_len) == prefix then input_string = input_string:sub(1+prefix_len) end
		if suffix~=nil and input_string:sub(-1,-suffix_len) == suffix then input_string = input_string:sub(1,-(1+suffix_len)) end
		log_error("input_string_new: "..input_string)
		local pattern = input_string:gsub(wildcard, ".*"):gsub("([%-%+%[%]%(%)])", "%%%1")	--create pattern that repalce custom wildcard to lua wildcard ".*"
		log_error("pattern: "..pattern)
		local newcand = {start = context:get_preedit().sel_start, _end = context:get_preedit().sel_end}
		
		-- keep updating temp table until the wildcard appears 
		-- make sure the chars before wildcard enter the translator and return enough pre-results
		if string.match(input_string, "^.*"..wildcard..".*$") 
		then  
		else
			cands ={}		-- truncate temp table before update
			for cand in input:iter() do	 
				table.insert(cands, 
								{text = cand.text,
								comment = cand.comment,
								index = #cands}
							) 
			end
			log_error("loaded dict entries #cands: "..tostring(#cands))
		end
		-- filter the pre-results with pattern to obtain final candidates
		for _, cand in pairs(cands) do
			if string.match(cand.comment, pattern) then  
			--- Candidate(type, start, end, text, comment)
			newcand = Candidate(input_string, newcand.start, newcand._end, cand.text, cand.comment)
			yield(newcand)
			end
		end
	-- no tag , keep intact
	else 
		cands = {}
		for cand in input:iter() do	
			yield(cand)
		end
	end
end

-- powerful fuzzy search method
-- e.g. \abc -> \.*a.*b.*c.*
local function fuzzy_search_filter(input, env)
	local config = env.engine.schema.config
	local context = env.engine.context
	local segment = context.composition:back()
	local tag = config:get_string("latex_input/tag") or 'latex'
	-- local prefix = config:get_string("latex_input/prefix")
	-- local prefix_len = prefix and string.len(prefix) or 0
	local suffix = config:get_string("latex_input/suffix")
	local suffix_len = suffix and string.len(suffix) or 0
	local newcand = {start = context:get_preedit().sel_start, _end = context:get_preedit().sel_end}
	
	local tag_check = segment:has_tag(tag) and true or false 
	
	if tag_check == true then 
		if context.input == '\\' then 
			cands = {}
			for cand in input:iter() do	 -- load whole dict to temp table
				table.insert(cands, {text = cand.text,
									comment = cand.comment,		-- cand commnet actually is the dict entry code return by reverse_lookup_filter 
									index = #cands}) 
			end
			log_error("loaded whole dict #cands: "..tostring(#cands)) 
			local symbols = {'¡¢', '\\', '£Ü'}
			for _, cand in ipairs(symbols) do
				newcand = Candidate('', newcand.start, newcand._end, cand ,'') -- don`t affect candidates of single '\'
				yield(newcand)
			end
		else 
			local input_string = context.input	 
			log_error("input_string:"..input_string)
			--if prefix~=nil and input_string:sub(1,prefix_len) == prefix then input_string = input_string:sub(1+prefix_len) end
			if suffix~=nil and input_string:sub(-1,-suffix_len) == suffix then input_string = input_string:sub(1,-(1+suffix_len)) end
			log_error("input_string_new: "..input_string)
			--local pattern = input_string:gsub(".", "%0.*")	--e.g. \abc -> \.*a.*b.*c.*
			local pattern = input_string:gsub(".", "%0.*"):gsub("([%-%+%[%]%(%)])", "%%%1") -- escaping special characters
			log_error("pattern: "..pattern)
			-- return candidates that match the pattern
			for _, cand in pairs(cands) do
				if string.match(cand.comment, pattern) then  
					--- Candidate(type, start, end, text, comment)
					newcand = Candidate('', newcand.start, newcand._end, cand.text, cand.comment)
					yield(newcand)
				end
			end
		end
	else 
		cands = {} 
		for cand in input:iter() do	
			yield(cand)
		end
	end 
	
end

-- powerful fuzzy search method with wildcard
-- e.g. \*ab*c -> \.*ab.*c.*
local function wildcard_search_filter(input, env)
	local config = env.engine.schema.config
	local context = env.engine.context
	local segment = context.composition:back()
	local tag = config:get_string("latex_input/tag") or 'latex'
	-- local prefix = config:get_string("latex_input/prefix")
	-- local prefix_len = prefix and string.len(prefix) or 0
	local suffix = config:get_string("latex_input/suffix")
	local suffix_len = suffix and string.len(suffix) or 0
	local newcand = {start = context:get_preedit().sel_start, _end = context:get_preedit().sel_end}
	
	local tag_check = segment:has_tag(tag) and true or false 
	
	if tag_check == true then 
		if context.input == '\\' then 
			cands = {}
			for cand in input:iter() do	 -- load whole dict to temp table
				table.insert(cands, {text = cand.text,
									comment = cand.comment,		-- cand commnet actually is the dict entry code return by reverse_lookup_filter 
									index = #cands}) 
			end
			log_error("loaded whole dict #cands: "..tostring(#cands)) 
			local symbols = {'¡¢', '\\', '£Ü'}
			for _, cand in ipairs(symbols) do
				newcand = Candidate('', newcand.start, newcand._end, cand ,'') -- don`t affect candidates of single '\'
				yield(newcand)
			end
		else 
			local wildcard = config:get_string("latex_input/wildcard") or '*'
			local input_string = context.input
			log_error("input_string:"..input_string)
			--if prefix~=nil and input_string:sub(1,prefix_len) == prefix then input_string = input_string:sub(1+prefix_len) end
			if suffix~=nil and input_string:sub(-1,-suffix_len) == suffix then input_string = input_string:sub(1,-(1+suffix_len)) end
			log_error("input_string_new: "..input_string)
			-- local pattern = input_string:gsub(wildcard, ".*")	-- e.g. \*ab*c -> \.*ab.*c.*
			local pattern = input_string:gsub(wildcard, ".*"):gsub("([%-%+%[%]%(%)])", "%%%1") -- escaping special characters
			log_error("pattern: "..pattern)
			-- return candidates that match the pattern
			for _, cand in pairs(cands) do
				if string.match(cand.comment, pattern) then  
					--- Candidate(type, start, end, text, comment)
					newcand = Candidate('', newcand.start, newcand._end, cand.text, cand.comment)
					yield(newcand)
				end
			end
		end
	else 
		cands = {} 
		for cand in input:iter() do	
			yield(cand)
		end
	end 
end


--return wildcard_search_filter
return {
  wildcard_limited = { func = wildcard_limited_filter },
  fuzzy_search    = { func = fuzzy_search_filter },
  wildcard_search = { func = wildcard_search_filter }
}


--[[
xxx.schema.yaml:
engine:
  translators:
    - table_translator@latex_input   
    - reverse_lookup_translator@latex_input       # make tips work, no other effects
  filters:
    - reverse_lookup_filter@latex_reverse_lookup  # return code as comment
    # - lua_filter@*latex*wildcard_limited        # \ab*c  -> \ab.*c.*  at least '\a' return results 
    # - lua_filter@*latex*fuzzy_search            # \abc   -> \.*a.*b.*c.*
    - lua_filter@*latex*wildcard_search           # \*ab*c -> \.*ab.*c.*

speller:
  delimiter: "'" 				# make sure table_translator suffix in delimiter

latex_input:
  tag: latex
  dictionary: latex
  prefix: "\\"      # for reverse_lookup_translator@latex_input
  tips: "[LaTeX]"   # for reverse_lookup_translator@latex_input
  suffix: "'"       # for lua script
  wildcard: "*"     # for lua script

latex_reverse_lookup:
  tags: [ latex ]
  dictionary: latex
  overwrite_comment: true
  
recognizer:
  patterns: 
    latex: "^\\\\[<>a-zA-Z0-9^_*()\\[\\]+-]*'?$" 
  
]]--