--RE Engine Hooked Method Inspector for REFramework
--v1.00, March 1 2024
--By alphaZomega
--Gives information about method calls in RE Engine games
--Gets the first or final time a method is called during a frame, then caches which module that call was made during and what args it used

local tics = 0
local try = false
local changed = false
local timings = {}
local recalls = {}
local mth_tbls = {}
local update_timings = {"First call per frame", "Last call per frame",}
local hook_method_text = "via.Transform:set_Parent(via.Transform)"
local already_hooked_methods = {}
local options = json.load_file("HookedMethodInspector.json") or {
	prev_hook_idx = 1,
	prev_hooks = {},
}

try, EMV = pcall(require, "EMV Engine")

local module_names = {
	"Initialize",
	"InitializeLog",
	"InitializeGameCore",
	"InitializeStorage",
	"InitializeResourceManager",
	"InitializeScene",
	"InitializeRemoteHost",
	"InitializeVM",
	"InitializeSystemService",
	"InitializeHardwareService",
	"InitializePushNotificationService",
	"InitializeDialog",
	"InitializeShareService",
	"InitializeUserService",
	"InitializeUDS",
	"InitializeModalDialogService",
	"InitializeGlobalUserData",
	"InitializeSteam",
	"InitializeWeGame",
	"InitializeXCloud",
	"InitializeRebe",
	"InitializeBcat",
	"InitializeEffectMemorySettings",
	"InitializeRenderer",
	"InitializeVR",
	"InitializeSpeedTree",
	"InitializeHID",
	"InitializeEffect",
	"InitializeGeometry",
	"InitializeLandscape",
	"InitializeHoudini",
	"InitializeSound",
	"InitializeWwiselib",
	"InitializeSimpleWwise",
	"InitializeWwise",
	"InitializeAudioRender",
	"InitializeGUI",
	"InitializeSpine",
	"InitializeMotion",
	"InitializeBehaviorTree",
	"InitializeAutoPlay",
	"InitializeScenario",
	"InitializeOctree",
	"InitializeAreaMap",
	"InitializeFSM",
	"InitializeNavigation",
	"InitializePointGraph",
	"InitializeFluidFlock",
	"InitializeTimeline",
	"InitializePhysics",
	"InitializeDynamics",
	"InitializeHavok",
	"InitializeBake",
	"InitializeNetwork",
	"InitializePuppet",
	"InitializeVoiceChat",
	"InitializeVivoxlib",
	"InitializeStore",
	"InitializeBrowser",
	"InitializeDevelopSystem",
	"InitializeBehavior",
	"InitializeMovie",
	"InitializeMame",
	"InitializeSkuService",
	"InitializeTelemetry",
	"InitializeHansoft",
	"InitializeNNFC",
	"InitializeMixer",
	"InitializeThreadPool",
	"Setup",
	"SetupJobScheduler",
	"SetupResourceManager",
	"SetupStorage",
	"SetupGlobalUserData",
	"SetupScene",
	"SetupDevelopSystem",
	"SetupUserService",
	"SetupSystemService",
	"SetupHardwareService",
	"SetupPushNotificationService",
	"SetupShareService",
	"SetupModalDialogService",
	"SetupVM",
	"SetupHID",
	"SetupRenderer",
	"SetupEffect",
	"SetupGeometry",
	"SetupLandscape",
	"SetupHoudini",
	"SetupSound",
	"SetupWwiselib",
	"SetupSimpleWwise",
	"SetupWwise",
	"SetupAudioRender",
	"SetupMotion",
	"SetupNavigation",
	"SetupPointGraph",
	"SetupPhysics",
	"SetupDynamics",
	"SetupHavok",
	"SetupMovie",
	"SetupMame",
	"SetupNetwork",
	"SetupPuppet",
	"SetupStore",
	"SetupBrowser",
	"SetupVoiceChat",
	"SetupVivoxlib",
	"SetupSkuService",
	"SetupTelemetry",
	"SetupHansoft",
	"StartApp",
	"SetupOctree",
	"SetupAreaMap",
	"SetupBehaviorTree",
	"SetupFSM",
	"SetupGUI",
	"SetupSpine",
	"SetupSpeedTree",
	"SetupNNFC",
	"Start",
	"StartStorage",
	"StartResourceManager",
	"StartGlobalUserData",
	"StartPhysics",
	"StartDynamics",
	"StartGUI",
	"StartTimeline",
	"StartOctree",
	"StartAreaMap",
	"StartBehaviorTree",
	"StartFSM",
	"StartSound",
	"StartWwise",
	"StartAudioRender",
	"StartScene",
	"StartRebe",
	"StartNetwork",
	"Update",
	"UpdateDialog",
	"UpdateRemoteHost",
	"UpdateStorage",
	"UpdateScene",
	"UpdateDevelopSystem",
	"UpdateWidget",
	"UpdateAutoPlay",
	"UpdateScenario",
	"UpdateCapture",
	"BeginFrameRendering",
	"UpdateVR",
	"UpdateHID",
	"UpdateMotionFrame",
	"BeginDynamics",
	"PreupdateGUI",
	"BeginHavok",
	"UpdateAIMap",
	"CreatePreupdateGroupFSM",
	"CreatePreupdateGroupBehaviorTree",
	"UpdateGlobalUserData",
	"UpdateUDS",
	"UpdateUserService",
	"UpdateSystemService",
	"UpdateHardwareService",
	"UpdatePushNotificationService",
	"UpdateShareService",
	"UpdateSteam",
	"UpdateWeGame",
	"UpdateBcat",
	"UpdateXCloud",
	"UpdateRebe",
	"UpdateNNFC",
	"BeginPhysics",
	"BeginUpdatePrimitive",
	"BeginUpdatePrimitiveGUI",
	"BeginUpdateSpineDraw",
	"UpdatePuppet",
	"UpdateGUI",
	"PreupdateBehavior",
	"PreupdateBehaviorTree",
	"PreupdateFSM",
	"PreupdateTimeline",
	"UpdateBehavior",
	"CreateUpdateGroupBehaviorTree",
	"CreateNavigationChain",
	"CreateUpdateGroupFSM",
	"UpdateTimeline",
	"PreUpdateAreaMap",
	"UpdateOctree",
	"UpdateAreaMap",
	"UpdateBehaviorTree",
	"UpdateTimelineFsm2",
	"UpdateNavigationPrev",
	"UpdateFSM",
	"UpdateMotion",
	"UpdateSpine",
	"EffectCollisionLimit",
	"UpdatePhysicsAfterUpdatePhase",
	"UpdateGeometry",
	"UpdateLandscape",
	"UpdateHoudini",
	"UpdatePhysicsCharacterController",
	"BeginUpdateHavok2",
	"UpdateDynamics",
	"UpdateNavigation",
	"UpdatePointGraph",
	"UpdateFluidFlock",
	"UpdateConstraintsBegin",
	"LateUpdateBehavior",
	"EditUpdateBehavior",
	"LateUpdateSpine",
	"BeginUpdateHavok",
	"BeginUpdateEffect",
	"UpdateConstraintsEnd",
	"UpdatePhysicsAfterLateUpdatePhase",
	"PrerenderGUI",
	"PrepareRendering",
	"UpdateSound",
	"UpdateWwiselib",
	"UpdateSimpleWwise",
	"UpdateWwise",
	"UpdateAudioRender",
	"CreateSelectorGroupFSM",
	"UpdateNetwork",
	"UpdateHavok",
	"EndUpdateHavok",
	"UpdateFSMSelector",
	"UpdateBehaviorTreeSelector",
	"BeforeLockSceneRendering",
	"EndUpdateHavok2",
	"UpdateJointExpression",
	"UpdateBehaviorTreeSelectorLegacy",
	"UpdateEffect",
	"EndUpdateEffect",
	"UpdateWidgetDynamics",
	"LockScene",
	"WaitRendering",
	"EndDynamics",
	"EndPhysics",
	"BeginRendering",
	"UpdateSpeedTree",
	"RenderDynamics",
	"RenderGUI",
	"RenderGeometry",
	"RenderLandscape",
	"RenderHoudini",
	"UpdatePrimitiveGUI",
	"UpdatePrimitive",
	"UpdateSpineDraw",
	"EndUpdatePrimitive",
	"EndUpdatePrimitiveGUI",
	"EndUpdateSpineDraw",
	"GUIPostPrimitiveRender",
	"ShapeRenderer",
	"UpdateMovie",
	"UpdateMame",
	"UpdateTelemetry",
	"UpdateHansoft",
	"DrawWidget",
	"DevelopRenderer",
	"EndRendering",
	"UpdateStore",
	"UpdateBrowser",
	"UpdateVoiceChat",
	"UpdateVivoxlib",
	"UnlockScene",
	"UpdateVM",
	"StepVisualDebugger",
	"WaitForVblank",
	"Terminate",
	"TerminateScene",
	"TerminateRemoteHost",
	"TerminateHansoft",
	"TerminateTelemetry",
	"TerminateMame",
	"TerminateMovie",
	"TerminateSound",
	"TerminateSimpleWwise",
	"TerminateWwise",
	"TerminateWwiselib",
	"TerminateAudioRender",
	"TerminateVoiceChat",
	"TerminateVivoxlib",
	"TerminatePuppet",
	"TerminateNetwork",
	"TerminateStore",
	"TerminateBrowser",
	"TerminateSpine",
	"TerminateGUI",
	"TerminateAreaMap",
	"TerminateOctree",
	"TerminateFluidFlock",
	"TerminateBehaviorTree",
	"TerminateFSM",
	"TerminateNavigation",
	"TerminatePointGraph",
	"TerminateEffect",
	"TerminateGeometry",
	"TerminateLandscape",
	"TerminateHoudini",
	"TerminateRenderer",
	"TerminateHID",
	"TerminateDynamics",
	"TerminatePhysics",
	"TerminateResourceManager",
	"TerminateHavok",
	"TerminateModalDialogService",
	"TerminateShareService",
	"TerminateGlobalUserData",
	"TerminateStorage",
	"TerminateVM",
	"TerminateJobScheduler",
	"Finalize",
	"FinalizeThreadPool",
	"FinalizeHansoft",
	"FinalizeTelemetry",
	"FinalizeMame",
	"FinalizeMovie",
	"FinalizeBehavior",
	"FinalizeDevelopSystem",
	"FinalizeTimeline",
	"FinalizePuppet",
	"FinalizeNetwork",
	"FinalizeStore",
	"FinalizeBrowser",
	"finalizeAutoPlay",
	"finalizeScenario",
	"FinalizeBehaviorTree",
	"FinalizeFSM",
	"FinalizeNavigation",
	"FinalizePointGraph",
	"FinalizeAreaMap",
	"FinalizeOctree",
	"FinalizeFluidFlock",
	"FinalizeMotion",
	"FinalizeDynamics",
	"FinalizePhysics",
	"FinalizeHavok",
	"FinalizeBake",
	"FinalizeSpine",
	"FinalizeGUI",
	"FinalizeSound",
	"FinalizeWwiselib",
	"FinalizeSimpleWwise",
	"FinalizeWwise",
	"FinalizeAudioRender",
	"FinalizeEffect",
	"FinalizeGeometry",
	"FinalizeSpeedTree",
	"FinalizeLandscape",
	"FinalizeHoudini",
	"FinalizeRenderer",
	"FinalizeHID",
	"FinalizeVR",
	"FinalizeBcat",
	"FinalizeRebe",
	"FinalizeXCloud",
	"FinalizeSteam",
	"FinalizeWeGame",
	"FinalizeNNFC",
	"FinalizeGlobalUserData",
	"FinalizeModalDialogService",
	"FinalizeSkuService",
	"FinalizeUDS",
	"FinalizeUserService",
	"FinalizeShareService",
	"FinalizeSystemService",
	"FinalizeHardwareService",
	"FinalizePushNotificationService",
	"FinalizeScene",
	"FinalizeVM",
	"FinalizeResourceManager",
	"FinalizeRemoteHost",
	"FinalizeStorage",
	"FinalizeDialog",
	"FinalizeMixer",
	"FinalizeGameCore",
}

local function setup_callbacks()
	for i, module_name in ipairs(module_names) do
		timings[i] = {name=module_name}
		
		re.on_pre_application_entry(module_name, function()
			timings[i].entry_time = os.clock()
			timings[i].frame = tics
		end)
		
		re.on_application_entry(module_name, function()
			if recalls[module_name] then
				recalls[module_name]()
			end
		end)
	end
end

local function convert_ptr(arg, td_name)
	local output
	local is_float = td_name and (td_name=="System.Single")
	if not pcall(function()
		local mobj = sdk.to_managed_object(arg)
		output = (mobj and mobj:add_ref()) or (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
	end) then
		output = (is_float and sdk.to_float(arg)) or sdk.to_int64(arg) or tostring(arg)
	end
	if td_name and not is_float and tonumber(output) then
		pcall(function()
			local vt = sdk.to_valuetype(output, td_name)
			if vt and vt.mValue ~= nil then
				output = vt.mValue
			else
				output = vt and (((vt["ToString"] and vt:call("ToString()")) or vt) or vt) or output
			end
		end)
	end
	return output
end

local function get_args(args, typedefs)
	local result = {}
	local mobj_idx
	for i, arg in ipairs(args) do 
		result[i] = convert_ptr(arg, mobj_idx and typedefs[i-mobj_idx])
		mobj_idx = mobj_idx or (typedefs and type(result[i])=="userdata" and i)
	end
	return result
end

local function tooltip(text, do_force)
    if do_force or imgui.is_item_hovered() then
        imgui.set_tooltip(text)
    end
end

local function display_module_table(module_tbl, method_tbl, is_most_recent)
	
	if imgui.tree_node_str_id(is_most_recent and "Recent" or module_tbl.name, module_tbl.fullname) then
		
		if module_tbl.args then
			imgui.indent()
			imgui.begin_rect()
			
			module_tbl.owner = module_tbl.owner and EMV.is_valid_obj(module_tbl.owner) and module_tbl.owner
			
			if module_tbl.owner and imgui.button("Call Again") then
				
				local new_args = {n=0}
				module_tbl.error_txt_recall = nil
				
				for i=module_tbl.owner_idx+1, module_tbl.last_arg_idx do
					new_args.n = new_args.n + 1
					local arg = module_tbl.args[i]
					if type(arg) == "string" and arg:sub(1,1) == "(" then
						local _, vec_ct = arg:gsub(",", "")
						local try, out = pcall(load("return Vector"..(vec_ct+1).."f.new"..arg))
						arg = try and out or arg
					end
					if type(arg) == "userdata" and arg.add_ref and not EMV.is_valid_obj(arg) then
						module_tbl.failed_idx = i
					end
					new_args[new_args.n] = arg
				end
				
				recalls[module_tbl.name] = not module_tbl.failed_idx and function()
					recalls[module_tbl.name] = nil
					debug_args = {method, module_tbl.owner, table.unpack(new_args)}
					try, out = pcall(method.call, method, module_tbl.owner, table.unpack(new_args))
					if not try then
						module_tbl.error_txt_recall = out
					end
				end
			end
			if module_tbl.owner then imgui.same_line() end
			imgui.text("Calls during this module: " .. module_tbl.calls)
			
			if module_tbl.failed_idx then
				imgui.text_colored("ERROR: args["..module_tbl.failed_idx.."] is a broken Managed Object!", 0xFF0000FF)
			elseif module_tbl.error_txt_recall then
				imgui.text_colored(module_tbl.error_txt_recall, 0xFF0000FF)
			end
			
			if is_most_recent then
				changed, method_tbl.pause_most_recent = imgui.checkbox("Pause updating to most recent", method_tbl.pause_most_recent)
			end
			
			if not is_most_recent or method_tbl.pause_most_recent then
				changed, module_tbl.do_update = imgui.checkbox("Keep updating args", module_tbl.do_update)
			end
			
			local owner_idx
			for p, converted_arg in ipairs(module_tbl.args) do
				
				if not owner_idx and type(converted_arg)=="userdata" and converted_arg.get_type_definition and converted_arg:get_type_definition():is_a(method_tbl.method:get_declaring_type()) then
					owner_idx = p
				end
				imgui.text("args["..p.."]:	")
				
				if owner_idx then
					module_tbl.owner = module_tbl.owner or converted_arg
					module_tbl.owner_idx = owner_idx
					imgui.same_line()
					local param_type = method_tbl.param_typenames[p-owner_idx]
					local text = ((p==owner_idx and method_tbl.my_typename)) or param_type
					imgui.text_colored(text, (owner_idx==p and 0xFFAAFFFF) or (param_type and 0xFFE0853D) or 0xFFFFFFFF)
					if param_type then
						imgui.same_line()
						imgui.text_colored(method_tbl.param_names[p-owner_idx], 0xFFFFFFAA)
						module_tbl.last_arg_idx = p
					end
				end
				
				imgui.indent()
				EMV.read_imgui_element(converted_arg, nil, nil, "")
				imgui.unindent()
			end
			
			if method_tbl.retval_typename then
				imgui.text("Returns:	")
				imgui.same_line()
				imgui.text_colored(method_tbl.retval_typename, 0xFFE0853D)
				imgui.indent()
				EMV.read_imgui_element(module_tbl.retval, nil, nil, "")
				imgui.unindent()
			end
			
			imgui.end_rect(1)
			imgui.unindent()
		end
		imgui.tree_pop()
	end
end

re.on_frame(function()
	tics = tics + 1
	
	for name, method_tbl in pairs(mth_tbls) do
		for i, timing_tbl in ipairs(timings) do
			if timing_tbl.entry_time and timing_tbl.frame == method_tbl.frame and timing_tbl.entry_time >= method_tbl.timing then
				local tbl = method_tbl.module_tables[i-1] or {
					name = timings[i-1].name, 
					do_update = true,
					calls = 0,
				}
				method_tbl.module_tables[i-1] = tbl
				tbl.timing = method_tbl.timing
				tbl.calls = tbl.calls + 1
				tbl.fullname = tbl.name .. "["..tbl.calls.."]" .. " @ " .. method_tbl.timing
				if method_tbl.enabled and tbl.do_update then
					tbl.args = method_tbl.args
					tbl.retval = method_tbl.retval
				end
				method_tbl.most_recent_module_tbl = not method_tbl.pause_most_recent and tbl or method_tbl.most_recent_module_tbl or tbl
				break
			end
		end
	end
end)

re.on_draw_ui(function()
	
	if imgui.tree_node("Hooked Method Inspector") then
		
		if not EMV then
			imgui.text_colored("EMV Engine not found! Download from\nhttps://github.com/alphazolam/EMV-Engine", 0xFF0000FF)
			imgui.tree_pop()
			return nil
		end
		
		imgui.begin_rect()
		imgui.begin_rect()
		
		local submitted = imgui.button("Hook Method")
		tooltip("Analyze this method")
		imgui.same_line()
		imgui.set_next_item_width(2000)
		changed, hook_method_text = imgui.input_text("Method", hook_method_text)
		
		local removed = imgui.button("Clear Method")
		tooltip("Remove this method from the script's method history")
		imgui.same_line()
		imgui.set_next_item_width(2000)
		options.prev_hooks = options.prev_hooks or {}
		changed, options.prev_hook_idx = imgui.combo("Previous Methods", options.prev_hook_idx, options.prev_hooks)
		tooltip("Previously analyzed methods")
		
		if changed then
			hook_method_text = options.prev_hooks[options.prev_hook_idx]
		end
		
		if removed then
			table.remove(options.prev_hooks, options.prev_hook_idx)
			table.sort(options.prev_hooks)
			json.dump_file("HookedMethodInspector.json", options)
		end
		
		if submitted then
			
			local function parse_method_text(text)
				if not text:find("find_type_definition") then
					if text:find(":") then
						return "sdk.find_type_definition(\""..text:match("(.+).-%:").."\"):get_method(\""..text:match(".+%:(.+)").."\")"
					else
						return "sdk.find_type_definition(\""..(text:match("(.+)%..+%(.+") or text:match("(.+)%..+")).."\"):get_method(\""..(text:match(".+%.(.+%(.+)") or text:match(".+%.(.+)")).."\")"
					end
				end
				return text
			end
			
			local method_txt = parse_method_text(hook_method_text)
			hook_method_text = hook_method_text:gsub("%(%)", "")
			if not hook_method_text:find("sdk%.") then hook_method_text = hook_method_text:gsub(":", ".") end
			
			try, method = pcall(load("return "..method_txt))
			
			if method and method.get_declaring_type and not already_hooked_methods[method] then
				already_hooked_methods[method] = true
				
				if not next(timings) then
					setup_callbacks()
				end
				
				local parsed_hook_text = hook_method_text:find("sdk%.") and (hook_method_text:match("\"(.-)\"") .. "." .. hook_method_text:match(".+\"(.-)\"")) or hook_method_text
				local old_hook_text = false
				for i, prev_hook in ipairs(options.prev_hooks) do 
					old_hook_text = old_hook_text or (((prev_hook == parsed_hook_text) or parsed_hook_text:find(prev_hook) or prev_hook:find(parsed_hook_text)) and prev_hook)
				end
				if not old_hook_text then
					table.insert(options.prev_hooks, parsed_hook_text)
					table.sort(options.prev_hooks)
				else
					method_txt = parse_method_text(old_hook_text)
				end
				json.dump_file("HookedMethodInspector.json", options)
				
				local owner_type_text = method_txt:match("ion%((.+)%):g")
				local method_name_text = method_txt:match("get_method%((.+)%)")
				local name = (owner_type_text .. "." .. method_name_text):gsub("\"", "")
				local ret_type = method:get_return_type()
				
				mth_tbls[name] = {
					call_count = 0,
					method=method, 
					enabled=true, 
					module_tables={},
					param_names = method:get_param_names(),
					param_types = method:get_param_types(),
					param_typenames = {},
					param_valuetypes = {},
					my_typename = method:get_declaring_type():get_full_name(),
					is_static = method:is_static(),
					retval_typename = not ret_type:is_a("System.Void") and ret_type:get_full_name(),
					update_timing = 2,
					by_first_call = false,
					pre_code = "",
					post_code = "",
				}
				
				local tbl = mth_tbls[name]
				tbl.singleton = sdk.get_managed_singleton(tbl.my_typename)
				
				for i, param_type in ipairs(tbl.param_types) do
					local td_name = param_type:get_full_name()
					tbl.param_typenames[i] = td_name
					tbl.param_valuetypes[i] = param_type:is_value_type() and not param_type:is_a("System.Enum") and not td_name:find("System.U?Int") and td_name
				end
				
				tbl.retval_vtypename = tbl.retval_typename and ret_type:is_value_type() and not ret_type:is_a("System.Enum") and not tbl.retval_typename:find("System.U?Int") and tbl.retval_typename
				
				sdk.hook(method, 
					function(args)
						tbl.call_count = tbl.call_count + 1
						if tbl.use_pre_code then
							_G.args = args
							try, output = pcall(load(tbl.pre_code))
							_G.args = nil
							tbl.error_txt_pre = not try and output
							if try and output == 1 then
								return sdk.PreHookResult.SKIP_ORIGINAL
							end
						end
						if not (tbl.by_first_call and tbl.frame == tics) then 
							tbl.frame = tics
							tbl.timing = os.clock()
							if tbl.enabled then
								tbl.raw_args = args
								tbl.args = get_args(args, tbl.param_valuetypes)
							end
						end
					end,
					function(retval)
						if tbl.use_pre_code then 
							
						end
						if tbl.use_post_code then
							_G.retval = retval
							try, output = pcall(load(tbl.post_code))
							_G.retval = nil
							tbl.error_txt_post = not try and ("Error, line " .. (output:match("\"%]:(.+)") or output))
							if try and output ~= nil then
								retval = output
							end
						end
						if tbl.enabled and not (tbl.by_first_call and tbl.frame == tics) then 
							tbl.retval = convert_ptr(retval, tbl.retval_vtypename)
						end
						return retval
					end
				)
			elseif not already_hooked_methods[method] then
				re.msg("Method not found!")
			end
		end
		
		for name, method_tbl in EMV.orderedPairs(mth_tbls) do
			
			if imgui.tree_node(name..(method_tbl.is_static and " [STATIC]" or "")) then
				imgui.begin_rect()
				
				if imgui.tree_node("Method Info") then
					imgui.text(EMV.logv(method_tbl.method))
					imgui.tree_pop()
				end
				
				changed, method_tbl.update_timing = imgui.combo("Update Timing", method_tbl.update_timing, update_timings)
				method_tbl.by_first_call = (method_tbl.update_timing == 1)
				
				changed, method_tbl.enabled = imgui.checkbox("Collect Arguments", method_tbl.enabled)
				
				imgui.same_line()
				local do_clear = imgui.button("Clear")
				
				if imgui.tree_node("Hook Editor") then
					
					changed, method_tbl.use_pre_code = imgui.checkbox("Use pre-function hook", method_tbl.use_pre_code)
					tooltip("You are passed 'args' like a typical pre-hook function")
					imgui.set_next_item_width(1920)
					changed, method_tbl.pre_code = imgui.input_text_multiline("Hook code (Pre-function)", method_tbl.pre_code, 500)
					if changed then method_tbl.use_pre_code = false end
					if method_tbl.error_txt_pre then
						imgui.text_colored(method_tbl.error_txt_pre, 0xFF0000FF)
					end
					
					imgui.text("")
					
					changed, method_tbl.use_post_code = imgui.checkbox("Use post-function hook", method_tbl.use_post_code)
					tooltip("You are passed 'retval' like a typical post-hook function")
					imgui.set_next_item_width(1920)
					changed, method_tbl.post_code = imgui.input_text_multiline("Hook code (Post-function)", method_tbl.post_code, 500)
					if changed then method_tbl.use_post_code = false end
					if method_tbl.error_txt_post then
						imgui.text_colored(method_tbl.error_txt_post, 0xFF0000FF)
					end
					imgui.tree_pop()
				end
				
				if method_tbl.timing then
					
					imgui.text("Calls: " .. method_tbl.call_count)
					imgui.text("Last called: " .. string.format("%.3f", tostring(method_tbl.timing)) .. " (" .. string.format("%.12f", os.clock()-method_tbl.timing) .. " seconds ago)")
					imgui.spacing()
					
					if method_tbl.most_recent_module_tbl then
						imgui.spacing()
						imgui.text_colored("Most recent:", 0xFFAAFFFF)
						display_module_table(method_tbl.most_recent_module_tbl, method_tbl, true)
					end
					
					imgui.text_colored("Calls during modules:", 0xFFAAFFFF)
					
					for i, module_tbl in EMV.orderedPairs(method_tbl.module_tables) do
						display_module_table(module_tbl, method_tbl)
					end
					
					if do_clear then
						method_tbl.timing = nil
						method_tbl.call_count = 0
						method_tbl.module_tables = {}
						method_tbl.most_recent_module_tbl = nil
					end
				else
					imgui.text("Not called yet!")
				end
				
				imgui.end_rect(1)
				imgui.tree_pop()
			end
		end
		
		imgui.text("												v1.00 By alphaZomega")
		imgui.end_rect(0)
		imgui.end_rect(1)
		imgui.tree_pop()
	end
end)