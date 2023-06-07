--RE Engine Console Script by alphaZomega
--Adds an interactive lua REPL / Console to REFramework
--June 26, 2022

--if true then return end
--EMV local functions and tables:
local EMV = require("EMV Engine")

local GameObject = EMV.GameObject
local kb_state = EMV.kb_state
local mouse_state = EMV.mouse_state
local orderedPairs = EMV.orderedPairs
local is_valid_obj = EMV.is_valid_obj
local split = EMV.split
local Split = EMV.Split
local vector_to_table = EMV.vector_to_table
local read_imgui_element = EMV.read_imgui_element
local read_imgui_pairs_table = EMV.read_imgui_pairs_table
local check_key_released = EMV.check_key_released
local merge_indexed_tables = EMV.merge_indexed_tables
local merge_tables = EMV.merge_tables
local get_table_size = EMV.get_table_size
local make_obj = EMV.make_obj
local to_obj = EMV.to_obj
local try, out
local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
local reverse_table = EMV.reverse_table
local get_GameObject = EMV.get_GameObject

local do_multiline = false

--EMV Global shortcut functions, for use in the Console
_G.read_bytes = EMV.read_bytes
_G.to_obj = EMV.to_obj
_G.mkobj = EMV.make_obj
_G.handle_obj = EMV.handle_obj
_G.search = EMV.search
_G.sort_components = EMV.sort_components
_G.sort = EMV.sort
_G.qsort = EMV.qsort
_G.closest = EMV.closest
_G.create_resource = EMV.create_resource 
_G.calln = EMV.calln
_G.find = EMV.find
_G.findc = EMV.findc
_G.findtdm = EMV.findtdm
_G.clone = EMV.clone
_G.merge_indexed_tables = EMV.merge_indexed_tables
_G.merge_tables = EMV.merge_tables
_G.orderedPairs = EMV.orderedPairs
_G.get_table_size = EMV.get_table_size
_G.isArray = EMV.isArray
_G.random = EMV.random
_G.random_range = EMV.random_range
--_G.lua_get_system_array = EMV.lua_get_system_array
_G.jsonify_table = EMV.jsonify_table
_G.get_folders = EMV.get_folders
_G.log_value = EMV.log_value
_G.read_bytes = EMV.read_bytes
_G.obj_to_json = EMV.obj_to_json
_G.is_valid_obj = EMV.is_valid_obj
_G.searchf = EMV.searchf
_G.create_gameobj = EMV.create_gameobj
SettingsCache.deferred_console = true

local toks
local cached_command_text = {}
local command_metadata = {}
local force_autocomplete

local function get_args(args)
	local result = {}
	for i, arg in pairs(args) do 
		if not pcall(function()
			result[i] = sdk.to_managed_object(arg) or sdk.to_int64(arg) or tostring(arg)
		end) then
			result[i] = sdk.to_int64(arg) or tostring(arg)
		end
	end
	return result
end

function quick_hook(typename, methodname, pre_func, ret_func)
	local typedef = sdk.find_type_definition(typename)
	local method = typedef and typedef:get_method(methodname)
	if method then 
		local name = methodname:match("(.+)%(") or methodname
		sdk.hook(method,
			pre_func or function(args)
				_G[name.."_args"] = get_args(args)
			end,
			ret_func or function(retval)
				return retval
			end
		)
		return "Global Variable: " .. name.."_args"
	end
end

--RE2, RE3
local cheats = {
	["god"] = table.pack({ comp="HitPointController", method="set_NoDamage", get_method="get_NoDamage"}),
	["God"] = table.pack({ comp="HitPointController", method="set_Invincible", get_method="get_Invincible"}),
	["hp"] = table.pack({ comp="HitPointController", args_method="set_CurrentHitPoint"}),
	--["noclip"] = table.pack({ comp="CharacterController", method="set_Enabled", active=false }, { comp="GroundFixer", method="set_Enabled", active=false }),
}

if isRE8 then 
	cheats.god = table.pack(
		{ comp="PlayerUpdaterBase", sub_obj="get_characterCore", field="isEnableDead"}
	)
	cheats.God = table.pack(
		{ comp="PlayerUpdaterBase", sub_obj="get_characterCore", field="isEnableDead"},
		--{ comp="PlayerUpdater", sub_obj="get_characterCore", field="IsEnableDamageReaction"}, 
		{ comp="PlayerUpdaterBase", sub_obj="get_characterCore", field="IsEnableDamage"}
	)
end

--Exectutes a string command input, dividing it up into separate sub-commands:
local run_command = function(input)
	input = input:gsub(" +$", "")
	local cht_part =  input:match("^(.+) ")
	local splitted = (cht_part and cheats[cht_part] and EMV.split(input, " ")) or {}
	if cheats[splitted[1] or input] then 
		local active
		for i, cheat in ipairs(cheats[splitted[1] or input]) do
			local player = EMV.get_player(true) 
			local component = player.components_named[cheat.comp]
			if component and cheat.sub_obj then 
				component = component:call(cheat.sub_obj)
			end
			if component then 
				if cheat.args_method and tonumber(splitted[2]) then
					return component:call(cheat.args_method, tonumber(splitted[2]))
				end
				if cheat.get_method then 
					cheat.active = active or not not ((cheat.field and component:get_field(cheat.field)) or (cheat.method and component:call(cheat.get_method)))
					if cheat.field then
						component:set_field(cheat.field, not cheat.active)
						cheat.active = not component:get_field(cheat.field)
					else
						component:call(cheat.method, not cheat.active)
						--re.msg("Called method " .. cheat.method .. " " .. tostring(not cheat.active))
						cheat.active = not component:call(cheat.get_method)
					end
					active = active or cheat.active
				end
			end
		end
		return active ~= nil and tostring(active)
	elseif input == "clear" then 
		if History.first_history_idx == #History.history_idx + 1 then 
			re.msg("Cleared")
			History.history, History.history_idx, History.history_metadata, History.first_history_idx = {}, {}, {}, 2
		else
			History.first_history_idx = #History.history_idx + 2
		end
		input = ""
	elseif input == "transforms"  then 
		EMV.get_transforms()
	elseif input == "folders" then
		EMV.get_all_folders()
	elseif input:sub(1,1) == "/" then
		input = "search(\"" .. input:sub(2) .. "\")"
	elseif input == "go" and go and is_valid_obj(go.xform) then
		go = GameObject:new_GrabObject{xform=go.xform}
	end
	return EMV.run_command(input)
end 

--Displays the History.history of past console commands and their results as a table:
local function show_history(do_minimal, new_first_history_idx)
	
	if next(History.history) then
		
		if SettingsCache.use_child_windows or do_minimal then 
			imgui.set_next_window_size({800, 600}, 0)
			imgui.begin_child_window(nil, false, 0)
			if not do_minimal then 
				if imgui.button("Enter") then 
					force_command = true
				end
				imgui.same_line()
				imgui.push_id(1337)
					if imgui.button(" ") then 
						force_autocomplete = true
					end 
				imgui.pop_id()
				imgui.same_line()
				if do_multiline then
					changed, command = imgui.input_text_multiline(" ", command)
				else
					changed, command = imgui.input_text(" ", command)
				end
				
				if imgui.begin_popup_context_item("Ctx") then
					if imgui.menu_item(do_multiline and "Single-line" or "Multi-line") then 
						do_multiline = not do_multiline
					end 
					imgui.end_popup() 
				end
			end
			if History.first_history_idx ~= #History.history_idx + 1 then
				imgui.begin_rect()
				imgui.text("History: 																																		 																																		 																																		\n")
			end
		end
		
		for i = new_first_history_idx or (do_minimal and (#History.history_idx)) or History.first_history_idx, #History.history_idx do 
			
			local cmd = History.history_idx[i]
			local result = History.history[cmd][1]
			local converted_result = History.history[cmd][2] or result
			
			if imgui.tree_node(cmd)  then
				
				local stringresult = tostring(result)
				History.history_metadata[i] = History.history_metadata[i] or {}
				--if History.history_metadata[i] ~= nil then
					local clean_cmd = cmd:gsub(" +$", "")
					local do_run_again = imgui.button_w_hotkey("Run Again", clean_cmd, {command=clean_cmd}, nil, {__cmd_name=clean_cmd}) or History.history_metadata[i].keep_running 
					--local do_run_again = (imgui.button("Run Again") or History.history_metadata[i].keep_running)
					
					imgui.same_line()
					changed, History.history_metadata[i].keep_running  = imgui.checkbox("Keep Running", History.history_metadata[i].keep_running )
					
					if changed or do_run_again then 
						local out = run_command(cmd)
						History.history[cmd] = table.pack(out or tostring(out), tostring(out):find("::vector") and vector_to_table(out))
					end
					
					update_lists_once = do_run_again and cmd or nil --"update_lists_once" updates console commands when "Run Again" is pressed
				--end
				read_imgui_element(result, nil, nil, cmd)
				imgui.tree_pop()
			end
		end 
		
		if not history_input_this_frame and (History.history_idx and #History.history_idx > 0 and kb_state.released[via.hid.KeyboardKey.Up] or kb_state.released[via.hid.KeyboardKey.Down]) then   -- 
			if kb_state.released[via.hid.KeyboardKey.Up] then
				if History.history_idx[History.current_history_idx - 1] then 
					History.current_history_idx = History.current_history_idx - 1
				else History.current_history_idx = #History.history_idx + 1 end
			elseif kb_state.released[via.hid.KeyboardKey.Down] then
				if History.history_idx[History.current_history_idx + 1] then 
					History.current_history_idx = History.current_history_idx + 1
				else History.current_history_idx = 0 end
			end
			command = History.history_idx[History.current_history_idx]
			if command then 
				--command = string.gsub(History.history_idx[History.current_history_idx], '[ \t]+%f[\r\n%z]', '') --remove tailing spaces
				command = command:gsub(" +$", "")
			end 
			history_input_this_frame = true
		end
		
		if SettingsCache.use_child_windows or do_minimal then 		
			if History.first_history_idx ~= #History.history_idx + 1 then
				imgui.new_line()
				imgui.end_rect(3)
				imgui.text("Output: \n" .. logv(History.command_output, nil, 1))
			end
			imgui.end_child_window()
		end
	end
	
	if not do_minimal then 
		if imgui.button("Enter") then 
			force_command = true
		end
		imgui.same_line()
		imgui.push_id(1234)
			if imgui.button(" ") then 
				force_autocomplete = true
			end 
		imgui.pop_id()
		imgui.same_line()
		
		if do_multiline then
			changed, command = imgui.input_text_multiline(" ", command)
		else
			changed, command = imgui.input_text(" ", command)
		end
		
		if imgui.begin_popup_context_item("ctx") then
			if imgui.menu_item(do_multiline and "Single-line" or "Multi-line") then 
				do_multiline = not do_multiline
			end 
			imgui.end_popup() 
		end
		
		if not SettingsCache.use_child_windows then 
			--imgui.text(History.command_output)
			pcall(function()
				imgui.text(logv(History.command_output, nil, 1))
			end)
		end
	end
	
	return #History.history_idx+1
end

--Miniature version of the console input window with a text box and show_history():
local mini_console = function(managed_object, key)
	
	key = key or managed_object
	typedef = managed_object:get_type_definition()
	command_metadata[key] = command_metadata[key] or {} 
	
	if tmp ~= managed_object then 
		if imgui.button("Assign to Console Var: tmp") then
			tmp = managed_object
			if tmp and sdk.is_managed_object(tmp)  then 
				tmp = tmp:add_ref()
				EMV.create_REMgdObj(tmp, true)
				command = (command == "") and string.format("tmp = 0x%x", tmp:get_address())
			else
				command = "tmp"
			end
			command_metadata[key].active = true
			force_command = true
		end
	end
	
	if typedef:is_a("via.Component") and (tmp ~= managed_object  and (not imgui.same_line())) and imgui.button("Find all " .. typedef:get_full_name() .. "s") then 
		command = "find(\"" .. typedef:get_full_name() .. "\")"
		command_metadata[key].active = true
		force_command = true
	end
	
	if imgui.button("Enter") then 
		force_command = true
		command_metadata[key].active = true
	end
	
	imgui.same_line()
	imgui.push_id(77777)
		if imgui.button(" ") then 
			force_autocomplete = true
		end 
	imgui.pop_id() 
	imgui.same_line()
	changed, command = imgui.input_text("Mini Console", command)
	if changed then 
		command_metadata[key].timer = uptime 
	end
	
	if kb_state.down[via.hid.KeyboardKey.Return] and (command ~= "" and command_metadata[key].timer and ((uptime - command_metadata[key].timer) < 5)) then 
		command_metadata[key].timer = nil
		command_metadata[key].active = true
		force_command = true
	end
	
	imgui.same_line()
	changed, command_metadata[key].active = imgui.checkbox("Show History", command_metadata[key].active)
	
	if (changed or force_command) and command_metadata[key].active then 
		imgui.set_next_window_size({800, 600}, 0)
		force_command = "expand"
	end
	
	if command_metadata[key].active then 
		imgui.begin_rect()
			local start_max_history_idx = show_history(true, command_metadata[key].start_history_idx)
			command_metadata[key].start_history_idx = command_metadata[key].start_history_idx or start_max_history_idx
		imgui.end_rect(0)
	else
		command_metadata[key].start_history_idx = nil
	end
end

EMV.static_funcs.mini_console = mini_console

--Auto-completes the inputted command:
local function autocomplete()
	
	if force_autocomplete or check_key_released(via.hid.KeyboardKey.Tab) then --------------------------------------------------------------autocomplete
		
		force_autocomplete = nil
		local function purify_key(key, only_remove_params)
			local m = key:match("^.+{(.+)}")
			m = m and m:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%[", "%%["):gsub("%]", "%%]")
			key = (m and m:find(", ")) and key:gsub(m, "") or key --detect comma
			if only_remove_params then return key end
			return key:gsub("[%(%){} :%.]", "")
		end
		local cmd = command
		local og_cmd = command
		local wide_split = split(purify_key(command, true), "%)}", true)
		local split_spaces = wide_split[1] and Split(wide_split[1], " ") or {}
		local split_ending_parens = wide_split[2]
		while split_spaces[#split_spaces] == "" do split_spaces[#split_spaces] = nil end
		if split_spaces[2] then cmd = split_spaces[#split_spaces] end
		local matches = {}
		local gsub_cmd = purify_key(og_cmd)
		local empty = false and (split_spaces[1] == nil) and (cmd == "") or cached_command_text[gsub_cmd] and (cached_command_text[gsub_cmd] == "~")
		local cached_command = (empty and "~") or (cmd:sub(-1):find("[%.:]") and cached_command_text[gsub_cmd .. "~"]) or cached_command_text[gsub_cmd] or cmd --substitute tilde for invalid character
		local empty = empty or og_cmd == "~"
		local split_cmd = split(cached_command, "%.:")
		local test_cmd = cached_command
		local ends_in_decimal = cached_command:sub(-1):find("[%.:]")
		local ends_in_colon_or_has_this = cached_command:sub(-1):find(":")
		local found_term = split_cmd[#split_cmd-1] and cached_command:find(split_cmd[#split_cmd-1])
		ends_in_colon_or_has_this = ends_in_colon_or_has_this or (found_term and cached_command:find(":",  found_term + 1))
		local special_split = split(og_cmd, "%.:")
		local special_split = special_split[2] and og_cmd:sub(-(special_split[#special_split]:len()+1), -1) --extract the last part of the original command including decimal/colon before it
		if special_split and not split_cmd[1] == "sdk" and (special_split:find("%.") and special_split:find("%(")) and not special_split:find(":") then 
			ends_in_colon_or_has_this = true
		else
			special_split = nil
		end
		local globals = merge_tables({}, _G)
		
		local function check_sub_table(key, value, level, key_prefix, is_metadata_func)
			
			local this_lvl_str, next_lvl_str = split_cmd[level], split_cmd[level+1]
			local this_lvl_str_no_regex = (this_lvl_str and this_lvl_str:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%[", "%%["):gsub("%]", "%%]")) or this_lvl_str
			key_prefix = key_prefix or ""
			
			if key and type(key) == "string" and ((ends_in_decimal and not this_lvl_str) or (empty or (this_lvl_str and key:find(this_lvl_str_no_regex) == 1))) then
				
				if (not next_lvl_str and not ends_in_decimal) or (ends_in_decimal and not this_lvl_str) then

					if type(value) == "function" then
						local has_this = ends_in_colon_or_has_this or (is_metadata_func) and not (key:find("__") == 1)
						local new_key = ((level > 1) and (key_prefix .. ((has_this and ":") or ".")) or "") .. key .. (is_metadata_func and "{ " or "( ")
						if is_metadata_func then 
							local method = is_metadata_func
							if method then 
								local names = method:get_param_names()
								local types = method:get_param_types()
								for i, name in ipairs(names) do 
									--leave the end comma because it doesnt matter in dicts and it needs it to tell if string is purified of special characters:
									new_key = new_key .. types[i]:get_name() .. "_" .. name .. "," .. ((i ~= #names and " ") or "") 
								end
							end
							new_key = new_key .. " }"
						else
							new_key = new_key .. " )"
						end
						matches[new_key] = value
					elseif not ends_in_colon_or_has_this and type(key) ~= "number" then
						if key:find("%.") then 
							matches[key_prefix .. "[\"" .. key .. "\"]"] = value
						else
							matches[((level > 1) and (key_prefix .. ".") or "") .. key] = value
						end
					end
					
				elseif (type(value) == "table" or type(value) == "userdata") then
					local next_key_prefix = (level > 1 and (key_prefix .. "." .. key)) or key
					local elems = (type(value) == "table" and pcall(function() pairs(value) end) and value) or {} 
					local try, mt_copy = pcall(merge_tables, {}, getmetatable(value) or {})
					local try, elems2 = try and pcall(merge_tables, mt_copy, elems)
					local tostring_val = tostring(value)
					elems = merge_tables({}, (try and elems2) or elems) --DONT merge metatable into real table
					if (tostring_val:find("REManaged") or tostring_val:find("RETransf") or tostring_val:find("ValueType") or tostring_val:find("SystemArray")) then --create REMgdObj class
						if not metadata[value] then EMV.create_REMgdObj(value, true) end
						elems = merge_tables(elems, metadata[value] or {})
					end
					for k, v in pairs(elems) do
						check_sub_table(k, v, level+1, next_key_prefix, metadata[value] and metadata[value]._.methods[k])
					end
				end
			end
		end
		
		for key, value in pairs(globals) do --check each part of command
			--if type(key) == "string" and (((type(value) == "userdata" or type(value) == "table" or type(value) == "function" or type(value) == "boolean") and not key:find("[:%*%.]"))) then 
			if type(key) == "string" and not key:find("[:%*%.]") then 
				check_sub_table(key, value, 1)
			end
		end
		
		if next(matches) then 
			local idx, counter = 1, 1
			local pure_key, pure_og_key = purify_key(cmd), purify_key(command)
			local indexed_matches = {}
			for key, value in orderedPairs(matches) do 
				table.insert(indexed_matches, key)
				if pure_key == purify_key(key) or (key == command) then
					if special_split then --if a method was previously matched with a `.`, try again with a `:`
						idx = counter
					else
						idx = counter + 1
					end
				end
				counter = counter + 1
			end
			test_cmd = indexed_matches[idx]  or indexed_matches[1]
		end
		
		cmd = test_cmd
		if split_spaces[2] and not history_key then 
			local reassembled_cmd = split_spaces[1]
			for i=2, #split_spaces - 1 do
				reassembled_cmd = reassembled_cmd .. " "  .. split_spaces[i]
			end
			command = reassembled_cmd .. " " .. cmd
		else
			command = cmd
		end
		
		if og_cmd:find("%(  %)") or purify_key(og_cmd, true):find("{ *}") then split_ending_parens = split_ending_parens:sub(3, -1) end
		command = command .. ((split_spaces[2] and split_ending_parens) and (" " .. split_ending_parens) or "")
		if og_cmd ~= command then 
			cached_command_text = {}
			cached_command_text[purify_key(command)] = cached_command
		end
	end -- /end autocomplete
end

local function dump_history()
	if SettingsCache.load_json then 
		local history_cmds_only = {}
		local new_history_idx = {}
		local used_cmds = {}
		local diff = 0
		for i, cmd in ipairs(reverse_table(History.history_idx or {})) do 
			local clean_cmd = cmd:gsub(" +$", "")
			if not used_cmds[clean_cmd] then
				used_cmds[clean_cmd] = true
				table.insert(new_history_idx, 1, clean_cmd)
				history_cmds_only[clean_cmd] = " "
			else
				diff = diff + 1
			end
		end
		local new_first_history_idx = History.first_history_idx - diff
		if new_first_history_idx < 1 then new_first_history_idx = 1 end
		local History = {history=history_cmds_only, history_idx=new_history_idx, current_history_idx=History.current_history_idx - diff, first_history_idx=History.first_history_idx - diff} 
		json.dump_file("Console\\History.json",  EMV.jsonify_table(History))
	end
end

--Main console display function:
function show_console_window()
	
	if (imgui.begin_window("Console", true, SettingsCache.transparent_bg and 128 or 0) == false) then 
		SettingsCache.show_console = false 
	end
		
		autocomplete()
		show_history()
		
		if (check_key_released(via.hid.KeyboardKey.Return) or force_command) and command ~= "" then
			cached_command_text = {}
			local out
			--[[if SettingsCache.deferred_console then
				History.history[command] = {}
				deferred_calls[scene] = {lua_func=run_command, args=command, delayed_global_key=History.history[command][1]}
				table.insert(History.history_idx, command)
				History.history_metadata[#History.history_idx] = { keep_running=false }
				goto finish
			end]]
			
			out = run_command(command)
			--out = out.output or 
			if noexcept == false then 
				out = "ERROR: " .. out
			end
			History.command_output = out or tostring(out)
			if History.first_history_idx < #History.history_idx - 100 then --limit of 100 command history shown
				if SettingsCache.load_json then 
					table.remove(History.history_idx, 1)
				else
					History.first_history_idx = #History.history_idx - 100
				end
			end
			while History.history[command] ~= nil do 
				command = command .. " " --add tailing spaces to command so it can exist as a separate key in the commands dictionary
			end 
			if command ~= "" then
				History.history[command] = table.pack(out, tostring(out):find(":vector") and vector_to_table(out)) 
				table.insert(History.history_idx, command)
				
				if not tostring(out):find("ERROR")  then 
					History.history_metadata[#History.history_idx] = { keep_running=false }
					local call_offs = command:find(":call")
					
					--[[if call_offs then  --hook maker
						local func_name = command:sub(call_offs + 7, command:find("\"", call_offs + 7)-1)
						local object_str = command:sub(1, call_offs - 1); 
						if object_str:find("%s[^%s]*$") then 
							object_str = object_str:sub(object_str:find("%s[^%s]*$"), -1)
						end
						--re.msg(object_str .. " " .. func_name)
						local noexcept, test = pcall(load("return " .. object_str)) --grab command's result
						if noexcept and sdk.is_managed_object(test) then 
							local method_def = test:get_type_definition():get_method(func_name)
							if method_def then 
								--local hook_string = "sdk.hook(sdk.find_type_definition(\"" .. test:get_type_definition():get_full_name() .. "\"):get_method(\"" .. func_name .. "\"), " .. hooked_funcs[] .. ", on_post_generic_hook)"
								History.history_metadata[#History.history_idx].hook_data = { exclusive_hook=false, hook_str=hook_string, count=0, addr=test, fn_name=func_name, obj=obj }
							end
						end
					end]]
				end
				dump_history()
			end
			::finish::
			command = ""
			History.current_history_idx = #History.history_idx + 1
		end
	imgui.end_window()
end

folderTree = nil

local function generateFolderTree(pathName, static_class)
	folderTree = folderTree or {}
	local ftree = folderTree
    local parts = {}
    for part in pathName:gmatch("[^\\]+") do
        table.insert(parts, part)
    end
	for i, part in ipairs(parts) do
		if not ftree[part] then
			if part:find("%.") then 
				table.insert(ftree, part)
				break
			else
				ftree[part] = {}
			end
		end
		ftree = ftree[part]
	end
end

local function show_console_settings()
	if imgui.tree_node("Console Settings") then
		if imgui.button(SettingsCache.show_console and "Hide Console" or "Spawn Console") then 
			SettingsCache.show_console = not SettingsCache.show_console
		end
		local was_changed
		changed, SettingsCache.max_element_size = imgui.drag_int("Elements Per Grouping", SettingsCache.max_element_size, 1, 10, 1000); was_changed = was_changed or changed
		changed, SettingsCache.use_child_windows = imgui.checkbox("Use Child Window", SettingsCache.use_child_windows); was_changed = was_changed or changed
		changed, SettingsCache.transparent_bg = imgui.checkbox("Transparent background", SettingsCache.transparent_bg); was_changed = was_changed or changed
		changed, SettingsCache.always_update_lists = imgui.checkbox("Always Update Lists", SettingsCache.always_update_lists); was_changed = was_changed or changed 
		changed, SettingsCache.show_editable_tables = imgui.checkbox("Editable Tables", SettingsCache.show_editable_tables); was_changed = was_changed or changed 
		if isDMC then
			changed, SettingsCache.add_DMC5_names = imgui.checkbox("Add Character Names", SettingsCache.add_DMC5_names); was_changed = was_changed or changed 
		end
		--changed, SettingsCache.deferred_console = imgui.checkbox("Deferred Console", SettingsCache.deferred_console); was_changed = was_changed or changed 
		if imgui.button("Clear History") then 
			history, history_idx, history_metadata, first_history_idx = {}, {}, {}, 1
			history, SettingsCache.history_idx, SettingsCache.history_metadata, SettingsCache.first_history_idx = {}, {}, {}, 1
		end
		
		imgui.same_line() 
		if imgui.button("Reset Settings") then 
			SettingsCache = merge_tables({}, EMV.default_SettingsCache)
			changed = true
		end
		
		if was_changed then
			EMV.dump_settings()
			dump_history()
		end
		
		if (next(world_positions) or next(shown_transforms)) and not imgui.same_line() and imgui.button("Clear Shown Transforms") then
			for xform, obj in pairs(shown_transforms) do 
				obj.display_transform = nil
			end
			for m_obj, sub_tbl in pairs(world_positions) do 
				if m_obj._ then m_obj._.world_positions = nil end
			end
			world_positions = {}
			shown_transforms = {}
			old_deferred_calls = {}
		end
		
		if imgui.tree_node("Global Variables") then 
			read_imgui_element(_G, nil, "_G")
			imgui.tree_pop()
		end
		imgui.tree_pop()
	end
end

--On frame -------------------------------------------------------------------------------------------------------------------------------------------
re.on_frame(function()

	if not toks then 
		History = EMV.jsonify_table(json.load_file("Console\\History.json") or {}, true)
		History.history = History.history or {}
		History.history_idx = History.history_idx or {}
		History.history_metadata =  History.history_metadata or {}
		History.current_history_idx = History.current_history_idx or 1
		History.first_history_idx = #History.history_idx + 1
		History.command_output = History.command_output or " "
		History.current_directory = History.current_directory or ""
		for i, path in ipairs(fs.glob(".*")) do
			generateFolderTree(path)
		end
	end
	
	toks = math.floor(os.clock()*100)
	
	if reframework:is_drawing_ui() and SettingsCache.show_console then
		show_console_window()
		force_command = nil
	end
end)

re.on_draw_ui(function()
	show_console_settings()
end)

re.on_script_reset(function()
	EMV.dump_settings()
	dump_history()
end)

return {
	autocomplete = autocomplete,
	show_history = show_history,
	mini_console = mini_console,
	show_console_window = show_console_window,
}


