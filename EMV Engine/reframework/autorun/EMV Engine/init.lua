--EMV_Engine by alphaZomega
--Console, imgui and support classes and functions for REFramework
--June 30, 2023

--Global variables --------------------------------------------------------------------------------------------------------------------------
_G["is" .. reframework.get_game_name():sub(1, 3):upper()] = true --sets up the "isRE2", "isRE3" etc boolean
BitStream = require("EMV Engine/Bitstream")

metadata = {}				--Tables used for indexing REManagedObjects, RETransforms, SystemArrays and ValueTypes
metadata_methods = {}		--Cached table of functions, fields, etc ("propdata") for each type definition, indexed by full typedef name
deferred_calls = {}			--Uses managed Objects as keys, each contains a table that says to execute function calls during UpdateMotion
on_frame_calls = {}			--Managed Objects as keys, containing a table that says to execute function calls during on_frame()
Collection = {}
old_deferred_calls = {}		--Cached list of previous deferred calls
held_transforms = {}		--Global list of AnimObjects and GameObjects, indexed by their transforms
touched_gameobjects = {}	--Global list of GrabObjects, indexed by their transforms
G_ordered = {}	--List orders for alphanumerically ordering dictionaries
world_positions = {}		--Tables with managed objects and their functions for specific fields to be displayed as world text
shown_transforms = {}		--GameObjects in here will have their transforms shown as world text
RSCache = {}				--Cached resources (files)
RN = {} 					--Resource names (filenames)
History = {}				--Previous console commands and their results	


--Default Settings:
local default_SettingsCache = {}
SettingsCache = {
	load_json = true,
	exception_methods = {},
	generic_count_methods = {["via.motion.Motion"] = "get_JointCount"},
	typedef_names_to_extensions = {},
	max_element_size = 100,
	use_child_windows = false,
	transparent_bg = false,
	always_update_lists = false,
	affect_children = true,
	show_all_fields = false,
	remember_materials = true,
	show_console = true,
	show_uvars = true,
	detach_collection = false,
	show_editable_tables = false,
	add_DMC5_names = isDMC or false,
	embed_mobj_control_panel = true,
	cache_orderedPairs = false,
	use_pcall = true,
	increments = {},
	objs_to_update = {},
	update_module_idx = 1,
	use_color_bytes = false,
	Collection_data = {
		collection_xforms = {},
		worldmatrix = Matrix4x4f.identity(),
		only_parents = true,
		search_enemies = true,
		enable_component_search = true, 
		enable_exclude_search = true,
		enable_include_search = false,
		case_sensitive = false,
		enabled_new_components = {},
		must_have = {
			checked = true, 
			Component="via.motion.MotionFsm2"
		},
		search_for = {
			"via.physics.CharacterController",
			"via.motion.ActorMotion",
			"via.motion.DummySkeleton",
		},
		included = {
			"[New]"
		},
		excluded = {
			"gimmick",
		},
	}
}

--tmp:call("trigger", )

--Local copies for performance --------------------------------------------------------------------------------------------------------------
local next = next
local ipairs = ipairs
local pairs = pairs

--Local variables ---------------------------------------------------------------------------------------------------------------------------
local uptime = os.clock()
local tics, toks = 0, 0
local changed, was_changed, try, out, value

scene_timer = 0
while scene_timer < 100 and not pcall(function()
	scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
	scene_timer = nil
end) do scene_timer = scene_timer + 1 end
_G.isGNG = not not scene:call("findGameObject(System.String)", "St03_01_BrightnessRTT") or nil

local game_name = (isGNG and "gng") or reframework.get_game_name()

local msg_ids = {}
local saved_mats = {files=fs.glob([[EMV_Engine\\Saved_Materials\\.*.json]]), names_map={}, names_indexed={}} --Collection of auto-applied altered material settings for GameObjects (by name)
local created_resources = {}
local chain_bone_names = {}
local CachedActions = {}
local CachedGlobals  = {}
local Hotkeys = {}
local re3_keys = {}		
local cached_chain_settings = {}
local cached_chain_settings_names = {}
local __temptxt = {}
local bool_to_number = { [true]=1, [false]=0 }
local number_to_bool = { [1]=true, [0]=false }
frozen_joints = {}
--local check_tables = {}

local tds = {
	via_hid_mouse_typedef = sdk.find_type_definition("via.hid.Mouse"),
	via_hid_keyboard_typedef = sdk.find_type_definition("via.hid.Keyboard"),
	guid = sdk.find_type_definition(sdk.game_namespace("GuidExtention")),
	mathex = sdk.find_type_definition(({mhrise="via.MathEx", sf6="via.MathEx", re2="app.MathEx"})[game_name] or sdk.game_namespace("MathEx")),
}

local static_objs = {
	cam = sdk.get_primary_camera(),
	scene_manager = sdk.get_native_singleton("via.SceneManager"),
	playermanager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager")) or sdk.get_managed_singleton("snow.player.PlayerManager"),
	main_view = sdk.call_native_func(scene_manager, sdk.find_type_definition("via.SceneManager"), "get_MainView"),
	via_hid_mouse = sdk.get_native_singleton("via.hid.Mouse"),
	via_hid_keyboard = sdk.get_native_singleton("via.hid.Keyboard"),
	setn = ValueType.new(sdk.find_type_definition("via.behaviortree.SetNodeInfo")),
	spawned_prefabs_folder = scene:call("findFolder", "ModdedTemporaryObjects") or scene:call("findFolder", 
		(isRE4 and "Test") or 
		(isRE2 and "GUI_Rogue") or 
		(isRE3 and "RopewayGrandSceneDevelop") or
		(isSF6 and "EmulatorContent") or 
		(isDMC and "Develop") or 
		(isMHR and "Item_b_000") or 
		(isRE8 and "Debug") or ""
	),
}

--static_objs.spawned_prefabs_folder = scene:call("findFolder", "EmulatorContent") or static_objs.spawned_prefabs_folder --I tire of this

static_objs.setn:call(".ctor")
static_objs.setn:call("set_Fullname", true)

local static_funcs = {
	distance_gameobjs = tds.mathex and tds.mathex:get_method("distance(via.GameObject, via.GameObject)"),
	distance_vectors = tds.mathex and tds.mathex:get_method("distance(via.vec3, via.vec3)"),
	get_chain_method = sdk.find_type_definition("via.Component"):get_method("get_Chain"),
	guid_method = sdk.find_type_definition("via.gui.message"):get_method("get"),
	mk_gameobj = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)"),
	mk_gameobj_w_fld = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)"),
	string_hashing_method = sdk.find_type_definition("via.murmur_hash"):get_method("calc32"),
}

--Convert a float to a byte, meant for colors:
static_funcs.convert_color_float_to_byte = function(flt)
	local int = math.floor(flt * 255 + 0.5)
	if int > 255 then int = 255 end
	return int
end

--Calculate a color adjusted for gamma
static_funcs.calc_color = function(emv_color) 
	return math.floor(255*(static_funcs.convert_color_float_to_byte(emv_color)/255)^(5/11) + 0.5) 
end

local statics = {
	width=1920,
	height=1080,
	tdb_ver=sdk.get_tdb_version(),
}

if (isRE2 or isRE3 or isRE7) and statics.tdb_ver >= 69 then 
	isRT = true --updated games
end

if static_objs.main_view ~= nil then 
	local size = sdk.call_native_func(static_objs.main_view, sdk.find_type_definition("via.SceneView"), "get_Size")
	statics.width = size:get_field("w")
	statics.height = size:get_field("h")
end

misc_vars = {
	tooltip_timers = 0,
	hovered_this_frame = 0,
	update_modules = {
		"PrepareRendering",
		"UpdateMotion",
	},
	skip_props = {
		HashCode = true,
		--Type = true,
		_DeltaTime = true,
		_UpdateCost = true,
		_LateUpdateCost = true,
		_IsInstanceEnable = true,
		
	},
}

local cog_names = { 
	["re2"] = "COG", 
	["re3"] = "COG", 
	["re7"] = "Hip", 
	["re8"] = "Hip", 
	["dmc5"] = "Hip", 
	["mhrise"] = "Cog", 
	["sf6"] = "C_Hip", 
	["re4"] = "Hip", 
}
local mat_types = {
	[1] = "MaterialFloat",
	[4] = "MaterialFloat4",
	[0] = "MaterialBool"
}
local nums_to_xyzw = {
	[0]="x",
	[1]="y",
	[2]="z",
	[3]="w",
}
local typedef_to_function = {
	["System.SByte"] = sdk.create_sbyte,
	["System.Byte"] = sdk.create_sbyte,
	["System.Int16"] = sdk.create_int16,
	["System.UInt16"] = sdk.create_uint16,
	["System.Int32"] = sdk.create_int32,
	["System.UInt32"] = sdk.create_uint32,
	["System.Int64"] = sdk.create_int64,
	["System.UInt64"] = sdk.create_uint64,
	["System.Single"] = sdk.create_single,
	["System.Double"] = sdk.create_double,
	["System.String"] = sdk.create_managed_string,
	["System.Array"] = sdk.create_managed_array,
	["via.ResourceHolder"] = sdk.create_resource,
}

--List of object examples on which to implement REMgdObj class
local REMgdObj_objects = {
	ValueType = ValueType.new(sdk.find_type_definition("via.AABB")),
	--REMgdObj_objects.BehaviorTree = findc("via.motion.MotionFsm2")[1],
	RETransform = scene:call("get_FirstTransform"),
	REManagedObject = scene,
}
if not isRE4 then
	--REMgdObj_objects.SystemArray = sdk.find_type_definition("System.Array"):get_method("CreateInstance"):call(nil, sdk.typeof("via.Transform"), 0):add_ref()
end

--local addresses of important functions and tables defined later:
EMV = {}
local GameObject
local BHVT
local Hotkey
local MoveSequencer
local read_imgui_element
local read_imgui_pairs_table
local show_imgui_mats
local get_mgd_obj_name
local create_REMgdObj
local add_to_REMgdObj
local obj_to_json
local jsonify_table
local get_fields_and_methods
local add_pfb_to_cache
local lua_find_component
local deferred_call
local hashing_method
local clear_object
local get_GameObject

--Table and lua object Functions ----------------------------------------------------------------------------------------------------------------------------
--Insert into an ordered list of strings alphabetically
function table.binsert(t, value, fcomp)
	local fcomp = fcomp or function(a, b) return a < b end
	local iStart, iEnd, iMid, iState =  1, #t, 1, 0
	while iStart <= iEnd do
		iMid = math.floor((iStart + iEnd) / 2)
		if fcomp(value , t[iMid]) then
			iEnd = iMid - 1
			iState = 0
		else
			iStart = iMid + 1
			iState = 1
		end
	end
	local pos = iMid+iState
	table.insert(t, pos, value)
	return pos
end

--Find index where a string would be inserted into an alphabetically-ordered list of strings
--[[function table.bfind(t, value, fcompval, reverse)
	fcompval = fcompval or function(value) return value end
	fcomp = function(a, b) return a < b end
	if reverse then
		fcomp = function(a, b) return a > b end
	end
	local iStart, iEnd, iMid = 1, #t, 1
	while (iStart <= iEnd) do
		iMid = math.floor((iStart + iEnd) / 2)
		local value2 = fcompval(t[iMid])
		if value == value2 then
			return iMid, t[iMid]
		end
		if fcomp(value, value2) then
			iEnd = iMid - 1
		else
			iStart = iMid + 1
		end
	end
end]]

--Get the next value in a table
local nextValue = function(tbl)
	local key, value = next(tbl)
	return value
end

--Test if a lua variable can be indexed
local function can_index(lua_object)
	local mt = getmetatable(lua_object)
	return (mt and (not not mt.__index)) or (not mt and type(lua_object) == "table")
end

--Get a random chance. 1/60th odds would be "if random(60) then"
local function random(ratio)
	if ratio == 1 then return true end
	math.randomseed(math.floor(os.clock()*100))
	return (math.random(1, ratio) == 1)
end

--Get a random number in a range
local function random_range(start, finish)
	if start >= finish then return start end
	math.randomseed(math.floor(os.clock()*100))
	return math.random(start, finish)
end

--Get dictionary size
local function get_table_size(tbl) 
	if type(tbl) ~= "table" then return 0 end
	local i, last_key, first_key = 0
	for k, v in pairs(tbl) do 
		i = i + 1
		first_key = first_key or k
		last_key = k
	end
	return i, first_key, last_key
end

--Test if a table is an array
local function isArray(t)
	local i = 0
	if not t[1] then return false end
	if t["n"] ~= nil then return true end 
	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end
	return true
end

--Remove an element from an ordered table while iterating without upsetting the order/iteration:
local function arrayRemove(tbl, keep_function)
    local j = 1
    for i = 1, #tbl do
		if keep_function(tbl[i]) then
            if (i ~= j) then
                tbl[j] = tbl[i]
                tbl[i] = nil
            end
            j = j + 1
        else
            tbl[i] = nil
        end
    end
    return tbl
end

--Get the arguments from a hooked RE Engine method
local function get_args(args)
	local result = {}
	for i, arg in pairs(args) do 
		if not pcall(function()
			local mobj = sdk.to_managed_object(arg)
			result[i] = (mobj and mobj:add_ref()) or sdk.to_int64(arg) or tostring(arg)
		end) then
			result[i] = sdk.to_int64(arg) or tostring(arg)
		end
	end
	return result
end

--turn std::vector into table
local function vector_to_table(std_vector)
	--if tostring(std_vector):find(":vector<") then 
		local new_table = {}
		for i, element in ipairs(std_vector) do 
			table.insert(new_table, element)
		end
		return new_table
	--end
end

--Append if unique to an indexed table
local function insert_if_unique(tbl_a, item, key)
	if key ~= nil then
		local comparator = item[key]
		for i, element in ipairs(tbl_a) do
			if element[key] == comparator then 
				return
			end
		end
	else
		for i, element in ipairs(tbl_a) do
			if element == item then 
				return
			end
		end
	end
	table.insert(tbl_a, item)
	return true
end

--Merge ordered lists
local function merge_indexed_tables(table_a, table_b, is_vec, no_dupes)
	table_a = table_a or {}
	table_b = table_b or {}
	local insert_method = no_dupes and table.insert or insert_if_unique
	if is_vec then 
		local new_tbl = {} 
		for i, value_a in ipairs(table_a) do insert_method(new_tbl, value_a) end
		for i, value_b in ipairs(table_b) do insert_method(new_tbl, value_b) end
		return new_tbl
	else
		for i, value_b in ipairs(table_b) do insert_method(table_a, value_b) end
		return table_a
	end
end

--Merge hashed dictionaries. table_b will be merged into table_a
local function merge_tables(table_a, table_b, no_overwrite)
	table_a = table_a or {}
	table_b = table_b or {}
	if no_overwrite then 
		for key_b, value_b in pairs(table_b) do 
			if table_a[key_b] == nil then
				table_a[key_b] = value_b 
			end
		end
	else
		for key_b, value_b in pairs(table_b) do table_a[key_b] = value_b end
	end
	return table_a
end

local function deep_copy(tbl, max_layers)
	local loops, loops2 = {}, {}
	local function recurse(sub_tbl, layer)
		local new_tbl = {}
		for key, value in pairs(sub_tbl or {}) do
			if (not max_layers or layer <= max_layers) and type(value) == "table" then
				if not loops[value] then
					loops[value] = merge_tables({}, value)
					loops[value] = recurse(loops[value], layer+1) 
				end
				new_tbl[key] = loops[value]
				--log.debug()
			else
				new_tbl[key] = value
			end
		end
		return new_tbl
	end
	return recurse(tbl, 0)
end

--Reverse a table order
local function reverse_table(t)
	local new_table = {}
	for i =  #t, 1, -1 do 
		table.insert(new_table, t[i])
	end
	return new_table
end

--Find the index of a value in an array
local function find_index(tbl, value, key)
	if key ~= nil then 
		for i, item in ipairs(tbl) do
			if item[key] == value then
				return i
			end
		end
	else
		for i, item in ipairs(tbl) do
			if item == value then
				return i
			end
		end
	end
end

--Check if a name is not unique in a table, and add a number to it if its not
local function resolve_duplicate_names(names_table, name, key)
	if key then 
		local new_names_tbl = {}
		for k, v in pairs(names_table) do 
			new_names_tbl[v[key]] = true
		end
		names_table = new_names_tbl
	end
	local ctr = 0
	local new_name = name
	while names_table[new_name] do 
		ctr = ctr + 1
		new_name = name .. " (" .. string.format("%01d", ctr) .. ")"
	end
	return new_name
end

--[[
-- Run in the console to detect when any component on "player" has been enabled or disabled:
enableds = enableds or {} 
for i, component in ipairs(player.components) do 
	ts_name=component:call("ToString()") or i 
	if enableds[ts_name]==nil then enableds[ts_name]=component:call("get_Enabled") end 
	if enableds[ts_name]~=component:call("get_Enabled") then enableds[ts_name]=component:call("get_Enabled") re.msg("Component "..ts_name.." now "..tostring(enableds[ts_name])) end 
end 
enableds = enableds 
]]

--Sort any table by a given key
local function qsort(tbl, key, ascending)
	if type(tbl)~="table" then return end
	local testkey, test = next(tbl)
	if test and test[key]~=nil then
		local arrayOutput = not isArray(tbl) and {}
		if arrayOutput then 
			for key, value in pairs(tbl) do
				local copy = merge_tables({__key=key}, value)
				table.insert(arrayOutput, copy)
			end
			tbl = arrayOutput
		end
		if ascending then
			if type(tbl[1][key]) == "table" then 
				if isArray(tbl[1][key]) then
					table.sort (tbl, function (obj1, obj2) return #obj1[key] < #obj2[key]  end)
				else
					table.sort (tbl, function (obj1, obj2) return get_table_size(obj1[key]) < get_table_size(obj2[key]) end)
				end
			else
				table.sort (tbl, function (obj1, obj2) return obj1[key] < obj2[key] end)
			end
		else
			if type(test[key]) == "table" then 
				if isArray(test[key]) then 
					table.sort (tbl, function (obj1, obj2) return #obj1[key] > #obj2[key]  end)
				else
					table.sort (tbl, function (obj1, obj2) return get_table_size(obj1[key]) > get_table_size(obj2[key]) end)
				end
			else
				table.sort (tbl, function (obj1, obj2) return obj1[key] > obj2[key] end)
			end
		end
		return tbl
	end
	return tbl, false
end

--orderedPairs for sorting keys alphabetically ----------------------------------------------------------------------------------------------------
local function cmp_multitype(op1, op2)
    local type1, type2 = type(op1), type(op2)
    if type1 ~= type2 then --cmp by type
        return type1 < type2
    elseif type1 == "number" or type1 == "string" then --type2 is equal to type1
        return op1 < op2 --comp by default
    elseif type1 == "boolean" then
        return op1 == true
    else
        return tostring(op1) < tostring(op2) --cmp by address
    end
end

local function __genOrderedIndex( t , do_multitype)
    local orderedIndex = {}
    for key in pairs(t) do
        orderedIndex[#orderedIndex+1] = key
    end
	table.sort( orderedIndex, do_multitype and cmp_multitype )
    return orderedIndex
end

local function orderedNext(t, state)
    local key = nil
    if state == nil then
		local do_multitype = type(state) ~= "string" and type(state) ~= "number"
		if SettingsCache.cache_orderedPairs then 
			if not G_ordered[t] or (t.__orderedIndex and (#t.__orderedIndex ~= get_table_size(t))) then 
				t.__orderedIndex = __genOrderedIndex(t , do_multitype)
				G_ordered[t] = {ords=t.__orderedIndex, open=uptime}
			end
			t.__orderedIndex = G_ordered[t].ords or __genOrderedIndex( t , do_multitype)
		else
			t.__orderedIndex = __genOrderedIndex( t , do_multitype)
		end
        key = t.__orderedIndex[1]
    elseif t.__orderedIndex then
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end
	if key then 
		if t[key]~=nil then 
			return key, t[key] 
		end
		G_ordered[t] = nil
    end
    t.__orderedIndex = nil
    return
end

local function orderedPairs(t)
    return orderedNext, t, nil
end

--Call re.msg without displaying every single frame -----------------------------------------------------------------------------------------
function re.msg_safe(msg, msg_id, frame_limit) 
	re.msgs_this_frame = re.msgs_this_frame or 0
	re.msgs_this_frame = re.msgs_this_frame + 1
	frame_limit = frame_limit or 15
	if re.msgs_this_frame > 10 then
		log.info("Frame " .. tics .. " Exceeded re.msg output: " .. tostring(msg))
	elseif msg_id and (not msg_ids[msg_id] or ((tics == msg_ids[msg_id])) or (frame_limit and ((tics - msg_ids[msg_id]) > frame_limit))) then
		msg_ids[msg_id] = tics
		re.msg(tostring(msg))
	else
		log.info(tostring(msg))
	end
end

--Display if a value is null in imgui, for quick debugging
local function imgui_check_value(value, name, force_show)
	if force_show or value == nil then 
		imgui.same_line()
		imgui.text(name or tostring(value))
	end
end

--Split strings into parts --------------------------------------------------------------------------------------------------------------
--Greedy split method 1
local function split(str, separator, in_half)
	local t = {}
	for split_str in string.gmatch(str, "([^" .. separator .. "]" .. "+" .. ")") do
		table.insert(t, split_str)
		if in_half then 
			table.insert(t, str:sub(split_str:len()+1, -1))
			break 
		end
	end
	return t
end

--Lazy split method 2
local function Split(s, delimiter)
	result = {}
	for match in (s..delimiter):gmatch("(.-)"..delimiter) do
		table.insert(result, match)
	end
	return result
end

--Search transforms utilities and console functions -------------------------------------------------------------------------------------------------------------
local function find(typedef_name, as_components) --find components by type, returned as via.Transforms
	--as_components = nil means return array of xforms
	--as_components = true means return array of components
	--as_components = 1 means return xform-dict of xforms
	--as_components = 2 means return xform-dict of components
	local typeof = sdk.typeof(typedef_name)
	local result
	if typeof then 
		result = scene:call("findComponents(System.Type)", typeof)
		result = result and result.get_elements and result:get_elements() or {}
		if not as_components or as_components==1 or as_components==2 then
			local xforms = {}
			for i, item in ipairs(result) do 
				local xform = get_GameObject(item):call("get_Transform")
				if as_components == 1 then 
					xforms[xform] = xform
				elseif as_components==2 then
					xforms[xform] = result
				else
					table.insert(xforms, xform)
				end
			end
			result = xforms
		end
	end
	return result or {}
end

--Get a method from a typedef name by name
local function findtdm(typedef_name, method_name)
	local td = sdk.find_type_definition(typedef_name)
	return td and td:get_method(method_name)
end

--Find components by type, returned as components
local function findc(typedef_name, gameobj_name)
	local results = find(typedef_name, true)
	if gameobj_name then 
		for i, result in ipairs(results) do 
			if get_GameObject(result, true) == gameobj_name then 
				return result
			end
		end
	end
	return results
end

--Wrapper for converting an address to an object
local function to_obj(object, is_known_obj)
	if is_known_obj or sdk.is_managed_object(object) then 
		return sdk.to_managed_object(sdk.to_ptr(object)) 
	end
end

--Search the global list of all transforms by gameobject name
local function search(search_term, case_sensitive, as_dict)
	local result = scene and scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))
	local search_results = {}
	if result and result.get_elements then 
		local term = not case_sensitive and search_term:lower() or search_term
		for i, element in ipairs(result:get_elements()) do
			local name = not case_sensitive and get_GameObject(element, true):lower() or get_GameObject(element, true)
			if name:find(term) then 
				if as_dict then 
					search_results[element] = element
				else
					table.insert(search_results, element)
				end
			end
		end
	end
	return search_results
end

--Sort the list of all components
local function sort_components(tbl)
	tbl = ((not tbl or (type(tbl) == "string")) and search(tbl)) or tbl
	local ordered_indexes, output = {}, {}
	local cam_gameobj = get_GameObject(static_objs.cam)
	for i=1, #tbl do ordered_indexes[i]=i end
	table.sort (ordered_indexes, function(idx1, idx2)
		return static_funcs.distance_gameobjs:call(nil, tbl[idx1]:call("get_GameObject"), cam_gameobj) < static_funcs.distance_gameobjs:call(nil, tbl[idx2]:call("get_GameObject"), cam_gameobj)
	end)
	for i=1, #ordered_indexes do output[#output+1] = tbl[ ordered_indexes[i] ] end
	return output
end

--Sort a list transforms by distance to a position:
local function sort(tbl, position, optional_max_dist, only_important)
	
	position = position or last_camera_matrix[3] --static_objs.cam:call("get_WorldMatrix")[3]
	if not tbl or type(tbl) == "string" then 
		tbl = search(tbl)
	end
	
	local unsorted_results, ordered_idxes, claimed, final_output, lengths = {}, {}, {}, {}, {}
	for i, element in ipairs(tbl) do
		local gameobj
		if type(element.call) == "function" then --sdk.is_managed_object(element) then
			local td, elem_pos = element:get_type_definition()
			if td:is_a("via.Transform") then
				elem_pos = element:call("get_Position")
			else
				--try, gameobj = pcall(element.call, element, "get_GameObject")
				gameobj = get_GameObject(element)
				elem_pos = gameobj and gameobj:call("get_Transform"):call("get_Position")
			end
			if elem_pos then
				local dist = lengths[elem_pos] or (elem_pos - position):length()
				lengths[elem_pos] = dist
				if not (dist ~= dist) then --if not NaN
					unsorted_results[dist] = unsorted_results[dist] or {}
					table.insert(unsorted_results[dist], i)
				end
			end
		end
	end
	local counter = 0
	for dist, packed_indices in orderedPairs(unsorted_results) do
		for i, index in ipairs(packed_indices) do 
			if not claimed[ tbl[index] ] then
				table.insert(final_output, tbl[index])
				table.insert(ordered_idxes, index)
				claimed[ tbl[index] ] = true
				if optional_max_dist then 
					if dist < optional_max_dist then 
						counter = counter + 1
					end
				end
			end
		end
	end
	return final_output, ordered_idxes, counter
end

--Get the closest transforms to a given position:
local function closest(position)
	local result = scene:call("findComponents(System.Type)", sdk.typeof("via.Transform")):get_elements()
	return result and sort(result, position) or nil
end

--Call a native function:
local function calln(object_name, method_name, args, arg2, arg3)
	if type(args)=="table" then
		return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name, table.unpack(args))
	elseif arg3 ~= nil then
		return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name, args, arg2, arg3)
	elseif arg2 ~= nil then
		return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name, args, arg2)
	elseif args ~= nil then
		return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name, args)
	else
		return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name)
	end
end

--Methods to check if managed objects are valid / usable --------------------------------------------------------------------------------------------------
--Check if a managed object is only kept alive by REFramework:
local function is_only_my_ref(obj)
	if obj:read_qword(0x8) <= 0 then return true end
	--if not obj.get_reference_count or (obj:get_reference_count() <= 0) then return true end
	if (not isRE7 or isRT) and obj:get_type_definition():is_a("via.Component") then
		local gameobject_addr = obj:read_qword(0x10)
		if gameobject_addr == 0 or not sdk.is_managed_object(gameobject_addr) then 
			return true
		end
	end
	return false
end

--Check officially that a managed object is valid:
local function get_valid(obj)
	if (not isRE7 or isRT) then return true end
	return true -- (obj and obj.call and (obj:call("get_Valid") ~= false))
end

--General check that object is usable:
local function is_valid_obj(obj, is_not_vt)
	if type(obj)=="userdata" then 
		if (not is_not_vt and tostring(obj):find("::ValueType")) then 
			return true
		end
		--if type(obj.read_qword)~="function" or obj:read_qword(0x10)==0 then return false end
		return sdk.is_managed_object(obj) and can_index(obj) and not is_only_my_ref(obj)
	end
end

--"get_GameObject" is the #1 internal-exception causing method in the game; this wrapper protects it and cleans up dead GameObjects
get_GameObject = function(component, name_or_xform)
	if component then
		if (type(component.read_qword)=="function") and sdk.is_managed_object(component:read_qword(0x10)) then
			try, out = pcall(component.call, component, "get_GameObject()")
			if try and name_or_xform then
				if name_or_xform==1 then 
					return out:call("get_Transform()")
				end
				return out:call("get_Name()")
			end
			return try and out
		elseif tostring(component):find("sol%.RE") then
			clear_object(component)
		end
	end
end

--Check if an object is outwardly a ValueType or REManagedObject
local function is_obj_or_vt(obj)
	return obj and ((tostring(obj):find("::ValueType") and 1) or is_valid_obj(obj, true))
end

--Console / load() Functions -----------------------------------------------------------------------------------------------------------
--Parses a string into a single executable expression usable by load():
local function parse_command(command)
	local load_string = command
	local hex_idx = load_string:find("0x[%x]") 
	local safety = 0
	while hex_idx and safety < 4 do
		local num_end = load_string:find("[^%x]", hex_idx+2) or (#load_string - 1) + 2
		if num_end - hex_idx > 5 then 
			local address = load_string:sub(hex_idx, num_end)
			if sdk.is_managed_object(tonumber(address)) then 
				load_string = load_string:sub(1, hex_idx - 1) .. "to_obj(" .. address .. ")" .. load_string:sub(num_end, -1)	
			end
		end
		hex_idx = load_string:find("0x[%x]", num_end)
		safety = safety + 1
	end
	if not string.find(command, "^for ") and not string.find(command, "^while ")  and not string.find(command, "end$") then
		if string.find(command, " = ") then 
			local left_side = load_string:sub(1, command:find(" =") - 1)
			local right_side =  load_string:sub(command:find("= ") + 2, -1)
			load_string = left_side .. " = " .. right_side .. "\nreturn ({" .. left_side .. "})" 
		else
			load_string = "return ({" .. load_string .. "})" --parens and braces allow returning multiple results as a table
		end
	end
	return load_string
end

--Exectutes a string command input with load(), dividing it up into separate sub-commands:
local function run_command(input)
	if not input then return end
	local outputs = {}
	local is_multi_command = input:find(";")
	for part in input:gsub("\n%s?", " "):gsub("%s?;%s?", ";"):gmatch("[^%;]+") do
		local command = parse_command(part)
		--log.info("\n" .. command)
		try, out = pcall(load(command))
		if try then 
			if out == nil then 
				out = "nil"
			elseif out[2] == nil then --if it's a table with one result that result becomes the whole output
				out = out[1]
			end
		else
			out = "ERROR: " .. tostring(out)
		end
		table.insert(outputs, (is_multi_command and {name=part, output=out or tostring(out)}) or out or tostring(out))
	end
	return ((outputs[2]~=nil) and outputs or outputs[1])
end

--Shows a floating message over an imgui element when hovered:
function imgui.tooltip(msg, delay)
	delay = delay or 0.5
	if imgui.is_item_hovered() then
		if delay then 
			misc_vars.tooltip_timers = misc_vars.tooltip_timers or uptime 
			misc_vars.hovered_this_frame = tics
		end
		if not delay or not misc_vars.tooltip_timers or ((uptime - misc_vars.tooltip_timers) > delay) then
			imgui.set_tooltip(msg or "")
		end
		
	elseif delay and misc_vars.hovered_this_frame < tics-1 then 
		misc_vars.tooltip_timers = nil 
	end
end

function imgui.tree_node_colored(key, white_text, color_text, color)
	local output = imgui.tree_node_str_id(key or 'a', white_text or "")
	imgui.same_line()
	imgui.text_colored(color_text or "", color or 0xFFE0853D)
	return output
end

function imgui.input_text_colored(white_text, color_text, color, text)
	local changed, value = imgui.input_text(white_text or "", text)
	imgui.same_line()
	imgui.text_colored(color_text or "", color or 0xFFE0853D)
	return changed, value
end

--View a table entry as input_text and change the table -------------------------------------------------------------------------------------------------------
--Returns true if it displayed an editable field, or 1 if the editable field was set
--"check_add_func" is a function that should take a string and return whether it is acceptable as the new value
--"override_same_type_check" allows changing any field to any data type
local function editable_table_field(key, value, owner_tbl, display_name, args)
	args = args or {}
	local override_same_type_check = args.override_same_type_check
	if not key or ((type(key)=="string") and ( (args.skip_underscores and (key:sub(1,2)=="__")) or (not override_same_type_check and (key:sub(1,3)=="___")) ) ) then 
		return
	end
	local output = true	 
	check_add_func = args.check_add_func
	local og_override = override_same_type_check
	local owner_key = owner_tbl or key
	owner_tbl = owner_tbl or _G
	
	if type(value)=="table" then 
		
		if imgui.tree_node_str_id(tostring(key) .. "T", display_name or EMV.ImguiTable.get_element_name(value, key) ) then
			display_name = display_name or key
			local m_tbl = __temptxt[owner_key] or {}
			local subtbl_key = "___" .. key
			
			imgui.push_id(key .. "+")
				imgui.same_line()
				if imgui.button("Add") and (not m_tbl[subtbl_key] or (m_tbl[subtbl_key].___new_value:sub(1,5) ~= "[New]")) then 
					m_tbl[subtbl_key] = m_tbl[subtbl_key] or {}
					m_tbl[subtbl_key].___is_array = isArray(value)
					m_tbl[subtbl_key].___new_key = ((m_tbl[subtbl_key].___is_array or (next(value)==nil)) and #value+1) or "[Key]"
					local same_type
					for k, v in pairs(value) do 
						local value_type = type(v)
						if same_type and same_type~=value_type then
							same_type = nil
							break
						end
						same_type = same_type or value_type
					end
					m_tbl[subtbl_key].___same_type = same_type
					m_tbl[subtbl_key].___new_value = args.new_key or "[New]"
					__temptxt[owner_key] = m_tbl
				end
			imgui.pop_id()
			
			read_imgui_pairs_table(value, key, (m_tbl[subtbl_key] and m_tbl[subtbl_key].___is_array), args) 
			--[[for k, v in orderedPairs(value) do 
				if (type(v)=="table") or is_obj_or_vt(v) or not editable_table_field(k, v, value, (type(k)=="string") and ("\"" .. k .. "\"") or k) then
					read_imgui_element(v, nil, false, k)
				end
			end]]
			
			if m_tbl[subtbl_key] and m_tbl[subtbl_key].___new_value~=nil then
				
				local old_value = value[m_tbl[subtbl_key].___new_key]
				local tmp_key = m_tbl[subtbl_key].___new_key
				
				if editable_table_field("___new_key", m_tbl[subtbl_key].___new_key, m_tbl[subtbl_key], "New Key", {override_same_type_check=true})==1 then 
					
					if (m_tbl[subtbl_key].___new_key == "") or (m_tbl[subtbl_key].___new_key == "nil") then
						if not pcall(function() table.remove(value, m_tbl[subtbl_key].___new_key) end) then
						end
						m_tbl[subtbl_key] = nil
						goto exit
					elseif (type(m_tbl[subtbl_key].___new_key)=="table") and (type(tmp_key)~="table") then --type(tmp_key) ~= type(m_tbl[subtbl_key].___new_key) 
						m_tbl[subtbl_key].___new_key = tmp_key
					end
				end
				
				if editable_table_field("___new_value", m_tbl[subtbl_key].___new_value, m_tbl[subtbl_key], "New Value", {check_add_func=check_add_func, override_same_type_check=m_tbl[subtbl_key].___same_type or "string"}) == 1 then --
					if m_tbl[subtbl_key].___new_value==nil or m_tbl[subtbl_key].___new_value=="" or m_tbl[subtbl_key].___new_value=="nil" then
						if not pcall(function() table.remove(value, m_tbl[subtbl_key].___new_key) end) then
							value[m_tbl[subtbl_key].___new_key] = nil
						end
					else
						if (type(m_tbl[subtbl_key].___new_key)=="number") and m_tbl[subtbl_key].___is_array and old_value ~= nil then 
							--re.msg("Z " .. m_tbl[subtbl_key].___new_value)
							table.insert(value, m_tbl[subtbl_key].___new_key, m_tbl[subtbl_key].___new_value)
						else
							value[m_tbl[subtbl_key].___new_key] = m_tbl[subtbl_key].___new_value
						end
					end
					m_tbl[subtbl_key] = nil
				end
			end
			::exit::
			m_tbl.___tics = tics
			__temptxt[owner_key] = __temptxt[owner_key] and m_tbl
			imgui.tree_pop()
		end
		return output
	elseif type(value) ~= "function" then
		display_name = display_name or key
			
		local m_tbl = __temptxt[owner_key] or {}
		m_tbl[key] = m_tbl[key] or {}
		local m_subtbl = m_tbl[key]
		m_subtbl.is_obj = m_subtbl.is_obj or ((m_subtbl.is_obj==nil) and (tostring(value):find("sol%.RE[TM]")==1)) or false
		m_subtbl.is_res = m_subtbl.is_res or (m_subtbl.is_obj and (m_subtbl.is_res==nil) and value:get_type_definition():get_name():find("ResourceHolder")) or false
		
		local converted_value = (m_subtbl.is_obj and not m_subtbl.is_res and "") or value
		if (not m_subtbl.is_obj or m_subtbl.is_res) and type(value)=="userdata" then 
			converted_value = (jsonify_table({value}))[1]
			if converted_value == nil then 
				return 
			end
		end
		
		if args.always_show and m_subtbl.value==nil then
			m_subtbl.value = value
		end
		
		if m_subtbl.value ~= nil and (args.always_show or (m_subtbl.value ~= nil and m_subtbl.value ~= tostring(converted_value))) then 
			imgui.push_id(key)
				if imgui.button("Set") then
					
					local p_check_add_func = check_add_func and function(input)
						local try, out = pcall(check_add_func, input)
						return not try or out --if it excepts, just bypass it
					end
					
					local tmp = _G.to_load
					local test_load = ({pcall(load("return " .. m_subtbl.value))})
					
					if test_load[1] and test_load[2]~=nil then
						override_same_type_check = override_same_type_check or true
					end
					
					if not test_load[1] or (type(test_load[2])=="string") or (test_load[2]==nil)  then 
						if type(value)=="userdata" then
							to_load = jsonify_table({m_subtbl.value}, true)[1]
							to_load = type(to_load)~="table" and to_load
						elseif m_subtbl.value:find("[\"']")==1 and not (m_subtbl.value:find(";")==m_subtbl.value:len())  then 
							override_same_type_check = override_same_type_check or true
							to_load = m_subtbl.value:gsub("\"", ""):gsub("'", "")
						elseif m_subtbl.value:find(";") or (type(value)=="string" and (override_same_type_check and ((override_same_type_check~="string")))) then
							override_same_type_check = override_same_type_check or true
							to_load = run_command(m_subtbl.value)
						elseif type(value)=="string" then
							to_load = m_subtbl.value
						else
							to_load = run_command(m_subtbl.value .. ";")
						end
					end
					
					if type(to_load)=="table" then 
						to_load = to_load.output or to_load
					end
					
					if m_subtbl.value == "\"\";" and (not p_check_add_func or p_check_add_func(to_load)) then
						owner_tbl[key] = "" --special cases to let you assign an empty string with ""; or '';
					elseif m_subtbl.value == "'';" and (not p_check_add_func or p_check_add_func(to_load)) then
						owner_tbl[key] = ''
					else
						local cmd = ((to_load~=nil) and ((type(value)=="string" and type(to_load)=="string") and ("'" .. to_load .. "'") or ("to_load"))) or m_subtbl.value or ""
						if type(value)=="string" and cmd:find("%.") and not cmd:find("\\\\") then
							cmd = cmd:gsub("\\", "\\\\")
						end
						local try, out = pcall(load("return " .. cmd))
						--re.msg("CMD " .. cmd .. " " .. tostring(try) .. " " .. tostring(out))
						if out==false then 
							owner_tbl[key] = false 
							output = 1
						elseif (m_subtbl.value=="") or (m_subtbl.value=="nil") or (m_subtbl.value=='') then --lets you delete any value with "" or "nil"
							if not isArray(owner_tbl) or not pcall(function() table.remove(owner_tbl, key) end) then
								owner_tbl[key] = nil
							end
							output = 1
						elseif try and (out ~= nil) and (((og_override~=false) and override_same_type_check) or (out=="") or type(out)==type(value)) 
						and (not m_subtbl.is_obj or (sdk.is_managed_object(out) and out:get_type_definition():is_a(value:get_type_definition())) ) then 
							local final_value
							if (type(out)~="string" or not (out:find("ERROR:")==1)) then
								final_value = (((out ~= "") and (m_subtbl.value~="nil")) and out) or nil
							end
							--re.msg("FINAL: " .. tostring(final_value) .. ", Func:" .. tostring(p_check_add_func) .. " or " .. tostring(check_add_func) .. ", " .. tostring(p_check_add_func(final_value)) .. ", " .. tostring(check_add_func(final_value)))
							if (final_value==nil) then
								if not isArray(owner_tbl) or not pcall(function() table.remove(owner_tbl, key) end) then
									owner_tbl[key] = nil
								end
							else
								if (tostring(cmd) == "'nil'") or (tostring(cmd)=="to_load" and tostring(to_load)=="nil") then 
									owner_tbl[key] = m_subtbl.value
								elseif p_check_add_func==nil or p_check_add_func(final_value) then
									owner_tbl[key] = final_value 
								end
							end
							output = 1
						end
					end
					_G.to_load = tmp
					m_subtbl = nil
				end
				
				if (not args.always_show or (m_subtbl and m_subtbl.value ~= nil and m_subtbl.value ~= tostring(converted_value))) and not imgui.same_line() and imgui.button("X") then
					m_subtbl = nil
				end
			imgui.pop_id()
			imgui.same_line() 
		end
		
		local changed, new_value 
		if args.color_text and type(args.color_text)~="table" then
			args.color_text = {"", args.color_text}
		end
		
		if args.width then
			imgui.set_next_item_width(args.width)
		end
		
		if args.color_text then 
			changed, new_value = imgui.input_text_colored(args.color_text[1], args.color_text[2], args.color_text[3], m_subtbl and m_subtbl.value or tostring(converted_value))
		else
			changed, new_value = imgui.input_text(tostring(display_name) .. (args.hide_type and "" or " (" .. type(value) .. ")"), m_subtbl and m_subtbl.value or tostring(converted_value))
		end
		if changed then
			m_subtbl.value = new_value
		end
		
		m_tbl.___tics = tics
		m_tbl[key] = m_subtbl
		__temptxt[owner_key] = m_tbl
		
		if output == 1 then 
			update_lists_once = "all"
		end
		
		return output
	end
end

--Console Imgui Functions and classes -------------------------------------------------------------------------------------------------------------------------
--Class for managing tables and dictionaries in imgui:
local ImguiTable = {
	
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		
		o.key = args.key 
		o.is_array = (args.is_array or isArray(args.tbl)) or nil
		o.is_vec = not not (tostring(args.tbl):find("::vector")) or nil
		o.tbl = (o.is_vec and vector_to_table(args.tbl)) or args.tbl
		
		--local tbl_size = get_table_size(o.tbl)
		--if tbl_size > 25000 then return {} end
		
		o.skip_underscores = args.skip_underscores
		o.pairs = o.is_array and ipairs or orderedPairs
		o.name = args.name or o.tbl.name
		o.is_managed_object = args.is_managed_object or true
		o.is_xform = args.is_xform or true
		o.is_component = args.is_component or true
		o.ordered_idxes = {}
		o.do_update = true
		
		local gameobj
		for key, value in o.pairs(o.tbl) do
			if not o.skip_underscores or not ((type(key)=="string") and key:sub(1,2)=="__") then
				table.insert(o.ordered_idxes, key)
				if o.is_managed_object then
					if not sdk.is_managed_object(value)  then
						o.is_managed_object, o.is_component = nil
					elseif o.is_component then
						o.is_component = value:get_type_definition():is_a("via.Component") or nil
						o.is_xform = o.is_xform or (o.is_component and (value.__type.name == "RETransform")) or nil
						gameobj = gameobj or (o.is_component and (value:call("get_Valid") ~= false) and get_GameObject(value))
						if not o.sortable and o.is_component and gameobj and (gameobj ~= get_GameObject(value)) then
							o.sortable = true --dont distance-sort components all from the same gameobject
						end 
					end
				end
			else
				o.skip_underscores = o.skip_underscores + 1
			end
		end
		--log.info("created ImguiTable " .. o.name .. " " .. tostring(o.ordered_idxes and #o.ordered_idxes))
		return setmetatable(o, self)
	end,
	
	get_element_name = function(element, elem_key, is_obj)
		local name
		is_obj = is_obj or ((is_obj ~= false) and is_obj_or_vt(element))
		if is_obj then 
			name = elem_key .. ":	" .. logv(element)
		else
			if not pcall(function() for k, v in pairs(element) do goto exit end ::exit:: end) then return element.__type.name end
			if (element.new or element.update) and can_index(element) then --or (can_index(element) and element.new and (element.name .. ""))
				name = elem_key .. ":	" .. tostring(element.name) .. "	[Object] (" .. get_table_size(element) .. " elements)"
			elseif isArray(element) then
				name = elem_key .. ":	[" .. #element .. " elements]" 
			else
				local mt = getmetatable(element)
				local nm = element.name or (mt and mt.name)
				name = elem_key .. ":	" .. (((nm and (tostring(nm) .. " ")) or (element.obj and (logv(element.obj, nil, 0) .. " "))) or "") .. " (" .. get_table_size(element) .. " elements)" --[dictionary] 
			end
		end
		return name
	end,
	
	update = function(self, tbl)
		
		tbl = tbl or {}
		self.tbl = self.tbl or {}
		self.open = os.clock()
		self.tbl_count = (self.is_array and #tbl) or get_table_size(tbl) or 1
		self.should_update = (self.tbl_count ~= #self.ordered_idxes + (self.skip_underscores or 0)) or nil
		
		if self.do_update then
			--log.info("Started updating " .. (self.name or self.key) .. " at " .. tostring(os.clock()))
			local ordered_idxes = {}
			self.names = {}
			self.element_data = {}
			if self.is_vec then 
				tbl = vector_to_table(tbl)
			end
			for key, value in self.pairs(tbl) do
				if not self.skip_underscores or not ((type(key)=="string") and key:sub(1,2)=="__") then
					ordered_idxes[#ordered_idxes+1] = key
				end
			end
			if self.parent and self.parent.should_update then 
				self.parent.do_update = true
			end
			self.ordered_idxes = ordered_idxes
			self.do_update = nil
			--log.info("Finished updating " .. (self.name or self.key) .. " at " .. tostring(os.clock()) .. " " .. tostring(self.ordered_idxes and #self.ordered_idxes))
			self.tbl = tbl
		end
		
		if self.show_closest then
			--local camera = 
			--local player_obj = camera.gameobj
			--[[table.sort (self.ordered_idxes, function(idx1, idx2)
				return static_funcs.distance_gameobjs:call(nil, self.tbl[idx1]:call("get_GameObject"), player_obj) < static_funcs.distance_gameobjs:call(nil, self.tbl[idx2]:call("get_GameObject"), player_obj)
			end)]]
			local max_idx = self.sort_closest_optional_limit or 10
			if max_idx > #self.ordered_idxes then 
				max_idx = #self.ordered_idxes 
			end
			for i=1, max_idx do 
				local xform = tbl[ self.ordered_idxes[i] ]
				touched_gameobjects[xform] = touched_gameobjects[xform] or GameObject:new{xform=xform}
				shown_transforms[xform] = touched_gameobjects[xform]
			end
		end
	end,
}

--Read a table or dictionary in imgui, using ImguiTable to store metadata
read_imgui_pairs_table = function(tbl, key, is_array, editable)
	
	key = key or tbl
	editable = editable or ((editable~= false) and SettingsCache.show_editable_tables)
	local edit_args = (editable and type(editable)=="table") and editable
	
	if true then --not SettingsCache.always_update_lists then
		
		local tbl_obj = G_ordered[key] or ImguiTable:new{tbl=tbl or {}, key=key, is_array=is_array, skip_underscores=edit_args and edit_args.skip_underscores}
		
		tbl_obj:update(tbl)
		
		G_ordered[key] = tbl_obj
		local ordered_idxes = tbl_obj.ordered_idxes
		local will_update = SettingsCache.always_update_lists or (update_lists_once and (update_lists_once=="all" or tostring(key):find(update_lists_once))) --"update_lists_once" updates console commands when "Run Again" is pressed
		
		if will_update or (tbl_obj.should_update and not imgui.same_line()  and imgui.button("Update")) then 
			tbl_obj.do_update = true
		end
		
		if tbl_obj.do_update and not SettingsCache.always_update_lists then
			imgui.same_line()
			imgui.text("UPDATING")
		end
		
		if will_update or not tbl_obj.should_update then
			imgui.spacing()
		end
		
		if #ordered_idxes == 0 then return end
		
		if tbl_obj.sortable then 
			imgui.same_line()
			if imgui.button("Sort By Distance") then
				tbl_obj.sorted_once = true
				tbl_obj.ordered_idxes, tbl_obj.names, tbl_obj.element_data = {}, {}, {}
				local new_tbl, new_ordered_idxes, optional_max_idx = sort(tbl_obj.tbl, nil, tbl_obj.sort_closest_optional_max_distance or 25)
				tbl_obj.sort_closest_optional_limit = (optional_max_idx < 100 and optional_max_idx) or 100
				tbl_obj.ordered_idxes = next(new_ordered_idxes) and new_ordered_idxes or ordered_idxes
				ordered_idxes = tbl_obj.ordered_idxes
			end
			if tbl_obj.sorted_once then 
				imgui.same_line()
				if imgui.button("X") then
					tbl_obj.sorted_once = nil
					G_ordered[key] = nil
				end
				imgui.same_line()
				changed, tbl_obj.show_closest = imgui.checkbox("Show Closest", tbl_obj.show_closest) 
				if tbl_obj.show_closest then
					changed, tbl_obj.sort_closest_optional_max_distance = imgui.drag_float("Max Distance", tbl_obj.sort_closest_optional_max_distance or 25, 1, 0, 1000)
					tbl_obj.sort_closest_optional_max_distance = changed and tonumber(tbl_obj.sort_closest_optional_max_distance) or tbl_obj.sort_closest_optional_max_distance
				end
			else
				tbl_obj.sort_closest_optional_limit, tbl_obj.sort_closest_optional_max_distance = nil
			end
		end
		
		--[[if imgui.tree_node_str_id(key .. "T", "Table Metadata") then
			read_imgui_element(tbl_obj, nil, key .. "T")
			imgui.tree_pop()
		end]]
		--imgui.text(tostring(tbl_obj.tbl_count))
		
		local do_subtables = ordered_idxes and (#ordered_idxes > SettingsCache.max_element_size)
		--imgui.text(tostring(editable) .. asd)
		for j = 1, #ordered_idxes, ((do_subtables and SettingsCache.max_element_size) or #ordered_idxes) do 
			
			j = math.floor(j)
			local this_limit = math.floor((j+SettingsCache.max_element_size-1 < #ordered_idxes and j+SettingsCache.max_element_size-1) or #ordered_idxes)
			
			if not do_subtables or imgui.tree_node_str_id(tostring(ordered_idxes[j]) .. "Elements", "Elements " .. j .. " - " .. this_limit) then
				
				for i = j, this_limit do 
					
					local index = ordered_idxes[i]
					if index == "" then 
						goto continue --not allowed
					end
					local element = tbl[ index ]
					
					if not tbl_obj.is_array or (tbl_obj.sorted_once or index ~= i) then 
						imgui.text(i .. ". ")
						imgui.same_line()
					end
					
					if element ~= nil then
						
						if ((type(element) ~= "table") or (not element.__pairs or pcall(element.__pairs, element))) then
							
							local do_update = (not tbl_obj.element_data[i]) or random(50)
							local e_d = tbl_obj.element_data[i] or {}
							local tostring_name = tostring(element)
							local is_vec = (not do_update and e_d.is_vec) or tostring_name:find(":vector") or nil
							local is_vt = not is_vec and ((not do_update and e_d.is_vt) or tostring_name:find("::ValueType") or tostring_name:find("::SystemArray")) or nil
							local is_obj = is_vt or (not is_vec and ((not do_update and e_d.is_obj) or sdk.is_managed_object(element))) or nil --tostring_name:find("%.REManagedObject") or tostring_name:find("%.RETransform")
							local elem_key = tostring(index)
							
							if is_obj or is_vec or ((type(element) == "table" and next(element) ~= nil)) then 
								
								local name = not do_update and tbl_obj.names[i]
								if not name then
									name = ImguiTable.get_element_name(element, elem_key, is_obj)
								elseif e_d.is_array or name:find("e%] %(") then
									name = name:gsub("%(%d.+ ", "(" .. #element .. " ")
									e_d.is_array = true
								elseif (e_d.is_array == false) or name:find("[yt]%] %(") then
									name = name:gsub("%(%d.+ ", "(" .. get_table_size(element) .. " ")
									e_d.is_array = false
								end
								tbl_obj.names[i] = name
								
								if is_obj then 
									if is_vt or is_valid_obj(element) then
										if imgui.tree_node_str_id(elem_key, name) then --RE objects
											imgui.managed_object_control_panel(element, key .. elem_key) 
											imgui.tree_pop()
										end
									else
										if tbl_obj.is_vec then
											--tbl = vector_to_table(tbl)
											--tbl_obj.tbl = tbl
										--	tbl_obj.tbl[ index ] = tbl_obj.names[i]
										--	log.info( index )
										--	tbl:set(index, tbl_obj.names[i])
										else
											tbl_obj.element_data[i] = {}
											tbl_obj.names[i] = name:gsub("%:	", ":    [DELETED] ")
											tbl[ index ] = ""--tbl_obj.names[i] --delete broken RE objects from lua
										end
										imgui.text("[Deleted]")
										goto continue
									end
								elseif (not editable or not editable_table_field(index, element, tbl)) and imgui.tree_node_str_id(elem_key, name) then --tables/dicts/vectors
									read_imgui_pairs_table(element, key .. elem_key, elem_is_array, editable)
									if G_ordered[key .. elem_key] then 
										G_ordered[key .. elem_key].parent = tbl_obj
										G_ordered[key .. elem_key].index = i
									end
									imgui.tree_pop()
								end
							elseif not editable or not editable_table_field(index, element, tbl, nil, edit_args) then 
								imgui.text(logv(element, elem_key, 2, 0)) --primitives, strings, lua types, matrices
							end
							tbl_obj.element_data[i] = (not do_update and tbl_obj.element_data[i]) or {is_vec=is_vec, is_vt=is_vt, is_obj=is_obj, }
						else
							imgui.text(logv(ordered_idxes[i])) --unreadable sol classes
						end
					else
						imgui.new_line()
					--	tbl_obj.do_update = true
					end
					::continue::
				end
				if do_subtables then
					imgui.tree_pop()
				end
			end
		end
	
	--[[else
		for sub_key, sub_elem in orderedPairs(tbl) do 
			if (type(sub_elem)=="table" or can_index(sub_elem)) then
				if imgui.tree_node_str_id(key, sub_elem) then
					read_imgui_pairs_table(sub_elem, sub_key)
					imgui.tree_pop()
				end
			else
				imgui.text(sub_key .. ": " .. tostring(sub_elem))
			end
		end]]
	end
end

--Read any one thing in imgui, loads tables or objects:
read_imgui_element = function(elem, index, editable, key, is_vec, is_obj)
	
	editable = editable or ((editable~= false) and SettingsCache.show_editable_tables)
	
	if elem == nil then return end
	local is_vec = is_vec or tostring(elem):find(":vector")
	is_obj = is_obj or (not is_vec and can_index(elem) and type(elem.call) == "function" and type(elem)=="userdata")
	key = key or tostring(elem)
	
	if index then 
		imgui.text("[" .. index .. "] ")
		imgui.same_line()
	end
	
	if is_obj then--or is_valid_obj(elem) then 
		if imgui.tree_node_ptr_id(elem, (key and (key .. ": ") or "") .. logv(elem, nil, 0)) then 
			imgui.managed_object_control_panel(elem, key) 
			imgui.tree_pop()
		end
	elseif ((type(elem) == "table" and next(elem) ~= nil) or (is_vec and elem[1])) and pcall(pairs, elem)  then
		read_imgui_pairs_table(elem, key, (is_vec and elem[1]) or isArray(elem), editable)
	elseif editable and key and type(editable)=="table" then 
		editable_table_field(key, elem, editable)
	else
		imgui.text(logv(elem, nil, 2, 0))
	end
end

--Matrix and Transform Utilities ----------------------------------------------------------------------------------------------------------
--Get magnitude of a vector:
local function magnitude(vector)
    return math.sqrt(vector.x^2 + vector.y^2 + vector.z^2)
end

--Get scale of a matrix:
local function mat4_scale(mat)
	return Vector3f.new(magnitude(mat[0]), magnitude(mat[1]), magnitude(mat[2]))
end

--Forcibly read and write vector4s,  matrices and via.transforms:
local function write_vec34(managed_object, offset, vector, is_known_managed_object, doVec3)
	if is_known_managed_object or sdk.is_managed_object(managed_object) then 
		managed_object:write_float(offset, vector.x)
		managed_object:write_float(offset + 4, vector.y)
		managed_object:write_float(offset + 8, vector.z)
		if not doVec3 and vector.w then  managed_object:write_float(offset + 12, vector.w) end
	end
end

--Manually read a vector3 or vector4
local function read_vec34(managed_object, offset, is_known_managed_object, doVec3)
	if is_known_managed_object or sdk.is_managed_object(managed_object) then 
		local x = managed_object:read_float(offset)
		local y = managed_object:read_float(offset + 4)
		local z = managed_object:read_float(offset + 8)
		local w = 0
		if not doVec3 then  w = managed_object:read_float(offset + 12) end
		return Vector4f.new(x, y, z, w)
	end
end

--Manually read a matrix4
local function read_mat4(managed_object, offset, is_known_managed_object)
	local is_valid = false
	if is_known_managed_object or sdk.is_managed_object(managed_object) then 
		is_valid = true
		local new_mat4 = Matrix4x4f.new()
		new_mat4[0] = read_vec34(managed_object, offset, 	  is_valid)
		new_mat4[1] = read_vec34(managed_object, offset + 16, is_valid)
		new_mat4[2] = read_vec34(managed_object, offset + 32, is_valid)
		new_mat4[3] = read_vec34(managed_object, offset + 48, is_valid)
		return new_mat4
	end
end

--Convert matrix4 to Translation, Rotation and Scale
local function mat4_to_trs(mat4, as_tbl)
	local pos = mat4[3]:to_vec3()
	local rot = mat4:to_quat()
	local scale = mat4_scale(mat4)
	if as_tbl then return {pos, rot, scale} end
	return pos, rot, scale
end

--Manually write a matrix4, or not manually if no offset is provided
local function write_mat4(managed_object, mat4, offset, is_known_valid, is_4x3)
	is_known_valid = is_known_valid or tostring(managed_object):find("ValueType")
	if mat4 and (is_known_valid or sdk.is_managed_object(managed_object)) then 
		if offset then 
			write_vec34(managed_object, offset, 	 mat4[0], true)
			write_vec34(managed_object, offset + 16, mat4[1], true)
			write_vec34(managed_object, offset + 32, mat4[2], true)
			if not is_4x3 then
				write_vec34(managed_object, offset + 48, mat4[3], true)
			end
		elseif tostring(managed_object):find("RETransform") then
			local pos, rot, scale = mat4_to_trs(mat4)
			managed_object:call("set_Position", pos)
			managed_object:call("set_Rotation", rot)
			managed_object:call("set_Scale", scale)
		end
	end
end

--Convert Translation, Rotation and Scale to matrix4
local function trs_to_mat4(translation, rotation, scale)
	if type(translation)=="table" then 
		translation, rotation, scale = table.unpack(translation)
	end
	local scale_mat = Matrix4x4f.new(
		Vector4f.new(scale.x or 1, 0, 0, 0),
		Vector4f.new(0, scale.y or 1, 0, 0),
		Vector4f.new(0, 0, scale.z or 1, 0),
		Vector4f.new(0, 0, 0, 1)
	)
	local new_mat = rotation:to_mat4() or Matrix4x4f.identity()
	new_mat = new_mat * scale_mat
	new_mat[3] = ((translation and translation.to_vec4 and translation:to_vec4()) or translation) or new_mat[3]
	return new_mat
end

--Get Translation, Rotation and Scale from an GameObject or GameObject
local function get_trs(object) 
	if type(object) == "table" then
		return object.xform:call("get_Position"), object.xform:call("get_Rotation"), object.xform:call("get_LocalScale")
	end
	return object:call("get_Position"), object:call("get_Rotation"), object:call("get_LocalScale")
end

--Limit a variable's range
local function clamp(val, lowerlimit, upperlimit)
	if val < lowerlimit then
		val = lowerlimit
	elseif val > upperlimit then
		val = upperlimit
	end
	return val
end

local function smoothstep(edge0, edge1, x)
	x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0) 
	return x * x * (3 - 2 * x)
end

--Generate Enums --------------------------------------------------------------------------------------------------------
function generate_statics(typename, make_global)
    local try, t = pcall(sdk.find_type_definition, typename)
    if not try or not t then return {} end
    local fields = t:get_fields()
    local enum, value_to_list_order, enum_names = {}, {}, {}
	local enum_string = "\ncase \"" .. typename .. "\":" .. "\n	enum {"
    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)
			if type(raw_value) == "userdata" and type(raw_value.call) == "function" then 
				try, raw_value = pcall(raw_value, raw_value.call, "ToString()")
			end
			if raw_value ~= nil then
				enum_string = enum_string .. "\n		" .. name .. " = " .. tostring(raw_value) .. ","
				enum[name] = raw_value 
				table.insert(enum_names, name .. "(" .. raw_value .. ")")
				value_to_list_order[raw_value] = #enum_names
			end
        end
    end
	if make_global then 
		generate_statics_global(typename, enum)
	end
	--log.info(enum_string .. "\n	}" .. typename:gsub("%.", "_") .. ";\n	break;\n") --enums for RSZ template
    return enum, value_to_list_order, enum_names
end

function generate_statics_global(typename, static_class, dont_double)
    local parts = {}
    for part in typename:gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    local global = _G
    for i, part in ipairs(parts) do
        if not global[part] then
            global[part] = {}
        end
        global = global[part]
    end
    if global ~= _G then
        local static_class = static_class or generate_statics(typename)
        for k, v in pairs(static_class) do
            global[k] = v
			if not dont_double then 
				global[v] = k
			end
        end
    end
    return global
end

--Generate global enums of these:
local wanted_static_classes = {
    "via.hid.GamePadButton",
    "via.hid.MouseButton",
	"via.hid.KeyboardKey",
	--sdk.game_namespace("Collision.CollisionSystem.Layer"),
	--sdk.game_namespace("Collision.CollisionSystem.Filter"),
	--sdk.game_namespace("gimmick.CheckCondition.CheckLogic"),
	
	--"app.PadInput.GameAction",
	--"app.fsm2.player.ButtonCheckCondition.CheckType",
	
	--"via.dynamics.RigidBodyState",
    
	--sdk.game_namespace("InputDefine.Kind"),
	--"app.PlayerVergilPL.ActiveAction",
	
}

for i, typename in ipairs(wanted_static_classes) do
    generate_statics_global(typename)
end

local mouse_state = {
    down = {
        [via.hid.MouseButton.L] = false,
        [via.hid.MouseButton.R] = false,
        [via.hid.MouseButton.C] = false,
        [via.hid.MouseButton.UP] = false,
        [via.hid.MouseButton.DOWN] = false,
        [via.hid.MouseButton.EX0] = false,
        [via.hid.MouseButton.EX1] = false,
    },
    released = {
        [via.hid.MouseButton.L] = false,
        [via.hid.MouseButton.R] = false,
        [via.hid.MouseButton.C] = false,
        [via.hid.MouseButton.UP] = false,
        [via.hid.MouseButton.DOWN] = false,
        [via.hid.MouseButton.EX0] = false,
        [via.hid.MouseButton.EX1] = false,
    },
}

local kb_state = {
    down = {
        [via.hid.KeyboardKey.Menu] = false,
        [via.hid.KeyboardKey.Control] = false,
		[via.hid.KeyboardKey.Q] = false,
		[via.hid.KeyboardKey.F] = false,
		[via.hid.KeyboardKey.C] = false,
		[via.hid.KeyboardKey.R] = false,
		[via.hid.KeyboardKey.Z] = false,
		[via.hid.KeyboardKey.V] = false,
		[via.hid.KeyboardKey.Tab] = false,
		[via.hid.KeyboardKey.Return] = false,
		[via.hid.KeyboardKey.Add] = false,
		[via.hid.KeyboardKey.Subtract] = false,
		[via.hid.KeyboardKey.Shift] = false,
		[via.hid.KeyboardKey.Back] = false,
    },
    released = {
        [via.hid.KeyboardKey.Menu] = false,
        [via.hid.KeyboardKey.Control] = false,
		[via.hid.KeyboardKey.Z] = false,
		[via.hid.KeyboardKey.V] = false,
		[via.hid.KeyboardKey.Up] = false,
		[via.hid.KeyboardKey.Down] = false,
		[via.hid.KeyboardKey.Return] = false,
		[via.hid.KeyboardKey.Tab] = false,
		[via.hid.KeyboardKey.E] = false,	
		[via.hid.KeyboardKey.F] = false,
		[via.hid.KeyboardKey.G] = false,
		[via.hid.KeyboardKey.H] = false,
		[via.hid.KeyboardKey.Q] = false,
		[via.hid.KeyboardKey.R] = false,
		[via.hid.KeyboardKey.T] = false,
		[via.hid.KeyboardKey.U] = false,
		[via.hid.KeyboardKey.Y] = false,
		[via.hid.KeyboardKey.Multiply] = false,
		[via.hid.KeyboardKey.Alpha2] = false,
		[via.hid.KeyboardKey.Alpha4] = false,
		[via.hid.KeyboardKey.Alpha5] = false,
		[via.hid.KeyboardKey.Alpha6] = false,
		--[via.hid.KeyboardKey.NumPad0] = false,	
		--[via.hid.KeyboardKey.NumPad4] = false,	
		--[via.hid.KeyboardKey.NumPad6] = false,
		--[via.hid.KeyboardKey.Escape] = false,
    },
}

local function get_mouse_device()
    return sdk.call_native_func(static_objs.via_hid_mouse, tds.via_hid_mouse_typedef, "get_Device")
end

local function get_kb_device()
    return sdk.call_native_func(static_objs.via_hid_keyboard, tds.via_hid_keyboard_typedef, "get_Device")
end

local function update_mouse_state()
    local mouse = get_mouse_device()
    if not mouse then return end
    for button, state in pairs(mouse_state.down) do
        mouse_state.down[button] = mouse:call("isDown", button)
    end
    for button, state in pairs(mouse_state.released) do
        mouse_state.released[button] = mouse:call("isRelease", button)
    end
	static_objs.mouse = mouse
end

local function update_keyboard_state()
    local kb = get_kb_device()
    if not kb then return end
    for button, state in pairs(kb_state.down) do
        kb_state.down[button] = kb:call("isDown", button)
    end
    for button, state in pairs(kb_state.released) do
        kb_state.released[button] = kb:call("isRelease", button)
    end
	static_objs.kb = kb
end

--Create enums using generate_statics and store them in a dictionary, returns lists for imgui comboboxes
local global_enums = {}
local function get_enum(return_type)
	local return_type_name = return_type:get_full_name()
	local enum, value_to_list_order, enum_names = global_enums[return_type_name] 
	if not enum then 
		enum, value_to_list_order, enum_names = generate_statics(return_type_name, true)
		global_enums[return_type_name] = table.pack(enum, value_to_list_order, enum_names)
	else
		enum, value_to_list_order, enum_names = table.unpack(enum)
	end	
	return enum, value_to_list_order, enum_names
end

--Special keypress checker, use "down_timer" to make it trigger every frame after the key has been held down for more than the time limit
local function check_key_released(key_id, down_timer)
	kb_state.down[key_id] = kb_state.down[key_id] or false
	kb_state.released[key_id] = kb_state.released[key_id] or false
	local kb = static_objs.kb
	if not kb then return end
	local key_tbl = re3_keys[key_id] or {}
	key_tbl.down_result = nil
	key_tbl.just_released = nil
	if kb_state.released[key_id] then
		key_tbl.timer_start = nil
		key_tbl.down = nil
		key_tbl.just_pressed = true
	elseif down_timer and (key_tbl.down or kb_state.down[key_id]) then --if was down this frame or last frame
		key_tbl.down = kb_state.down[key_id]
		key_tbl.timer_start = key_tbl.timer_start or uptime
		if key_tbl.timer_start and ((uptime - key_tbl.timer_start) >= down_timer) then 
			key_tbl.down_result = true
		end
	elseif key_tbl.just_pressed then
		key_tbl.just_released = true 
	else
		key_tbl.timer_start = nil
	end
	if key_tbl.just_released then 
		key_tbl.just_pressed = nil
		key_tbl.timer_start = nil
		key_tbl.down = nil
		--[[if down_timer and (down_timer > 0) then
			key_tbl.just_released = nil
		end]]
	end
	re3_keys[key_id] = key_tbl
	return key_tbl.just_released or key_tbl.down_result
end

--Check if any key was released, and return its key ID and name:
local function check_any_key_released()
	for key_id, key_name in pairs(Hotkey.keys) do
		if check_key_released(key_id) then
			return key_id, key_name
		end
	end
end

-- Set a hotkey in Imgui ------------------------------------------------------------------------------------------------------------------
local function show_hotkey_setter(button_txt, imgui_keyname, deferred_call, dfc_args, dfcall_json)
	if not imgui_keyname then return end
	imgui.same_line()
	local hk_tbl = Hotkeys[imgui_keyname]
	imgui.push_id(imgui_keyname.."K")
		if hk_tbl and (hk_tbl.key_name == "[Press a Key]") then
			local key_id, key_name = check_any_key_released()
			if key_id then
				hk_tbl = Hotkey:new({button_txt=button_txt, imgui_keyname=imgui_keyname, key_id=key_id, key_name=key_name, dfcall=deferred_call, obj=deferred_call.obj, dfcall_json=dfcall_json})
				if deferred_call then
					if dfc_args ~= nil and deferred_call.args == nil then
						hk_tbl.dfcall = merge_tables({args=((type(dfc_args)~="table") and {dfc_args} or dfc_args)}, deferred_call, true) --make a unique copy of the deferred call with the given args
					end
					hk_tbl.dfcall = hk_tbl.dfcall or deferred_call
				end
				Hotkey.used[hk_tbl.imgui_keyname] = hk_tbl
				hk_tbl:set_key()
			end
		end
		
		if imgui.button((hk_tbl and hk_tbl.key_name) or "?") then
			
			if not hk_tbl then 
				hk_tbl = {}
				hk_tbl.key_name = "[Press a Key]"
			else
				if hk_tbl.key_id then
					Hotkey.used[hk_tbl.imgui_keyname] = nil
					hk_tbl.set_key()
				end
				hk_tbl = nil
			end
		end
		
	imgui.pop_id()
	Hotkeys[imgui_keyname] = hk_tbl
	
	return (not deferred_call and hk_tbl and hk_tbl.key_id and check_key_released(hk_tbl.key_id))
end

--Global hotkey setter shortcut with button, used like imgui.button():
function imgui.button_w_hotkey(button_txt, imgui_keyname, deferred_call, dfc_args, dfcall_json)
	imgui_keyname = imgui_keyname or button_txt
	local hk_tbl = Hotkey.used[imgui_keyname]
	if hk_tbl then imgui.begin_rect() end
	local is_pressed
	if ((imgui.button(button_txt) and not show_hotkey_setter(button_txt, imgui_keyname, deferred_call, dfc_args, dfcall_json)) or show_hotkey_setter(button_txt, imgui_keyname, deferred_call, dfc_args, dfcall_json)) then 
		is_pressed = true
		if deferred_call.obj and deferred_call.obj.CurrentNodeID then --BehaviorTrees sequencer special clause
			local seq = deferred_call.obj.sequencer or MoveSequencer:new{tree=deferred_call.obj}
			if seq then 
				if deferred_call.args == nil then
					deferred_call = merge_tables({args=((type(dfc_args)~="table") and {dfc_args} or dfc_args)}, deferred_call, true) --make a unique copy of the deferred call with the given args
				end
				seq.Hotkeys[imgui_keyname] = Hotkey:new({button_txt=button_txt, imgui_keyname=imgui_keyname, dfcall=deferred_call, obj=deferred_call.obj, dfcall_json=dfcall_json}, seq.Hotkeys[imgui_keyname])
				seq.movedata[imgui_keyname] = seq.movedata[imgui_keyname] or {}
				seq.movedata[imgui_keyname].pressed = tics
				seq:update()
				seq.idle_mot_name = (seq.mot_name and seq.mot_name:find("Idle") and seq.mot_name) or seq.idle_mot_name 
				deferred_call.obj.sequencer = seq
			end
		end
	end
	if hk_tbl then imgui.end_rect(3) end
	return is_pressed
end

Hotkey = {
	
	used = {},
	keys = {},
	
	new = function(self, args, o)
		o = o or {}
		o.key_id = args.key_id or o.key_id
		o.key_name = o.key_id and (args.key_name or o.key_name) or "?"
		o.imgui_keyname = args.imgui_keyname or o.imgui_keyname
		if not o.imgui_keyname then return end
		o.hash = hashing_method(o.imgui_keyname)
		o.button_txt = args.button_txt or o.button_txt or o.imgui_keyname
		o.dfcall = args.dfcall or o.dfcall
		o.dfcall_json = args.dfcall_json or o.dfcall_json
		if o.dfcall_json then
			o.down_timer  = o.dfcall_json.down_timer 
			o.gameobj_name = o.dfcall_json.__gameobj_name or o.dfcall_json.__cmd_name
		end
		o.gameobj_name = o.gameobj_name or o.imgui_keyname:match("^.+/(.-)%.") or o.imgui_keyname
		if o.dfcall then 
			o.obj = o.dfcall.obj
		end
		--o.metadata = {}
		self.__index = self  
		return setmetatable(o, self)
	end,
	
	display_imgui_button = function(self, button_txt)
		button_txt = button_txt or self.button_txt
		if imgui.button_w_hotkey(button_txt, self.imgui_keyname, self.dfcall, self.dfcall and self.dfcall.args, self.dfcall_json) then
			self.button_pressed = true
			self:update(true)
			return true
		end
	end,
	
	set_key = function(self)
		if self then 
			self.used[self.imgui_keyname] = self 
		end
		local dump_keys = {}
		for name, tbl in pairs(Hotkey.used) do 
			local dmp_tbl = deep_copy(tbl)
			if tbl.obj then
				dmp_tbl.dfcall.obj = obj_to_json(tbl.obj, true, tbl.dfcall_json)
				for i, arg in ipairs(tbl.dfcall.args or {}) do 
					local is_obj = is_obj_or_vt(arg)
					if is_obj then 
						local setn_arg = (arg:get_type_definition():get_name()=="SetNodeInfo") and {__is_vt=true, __is_setn=true} --awful hack fix, but it only works as a valuetype, not a REManagedObject (which it says it is)
						dmp_tbl.dfcall.args[i] = obj_to_json(arg, true, setn_arg or tbl.dfcall_json) --convert ValueType/object to json
					end
				end
				dmp_tbl.output = nil
			end
			dmp_tbl.metadata = nil
			dump_keys[name] = dmp_tbl
		end
		json.dump_file("EMV_Engine\\Hotkeys.json",  jsonify_table(dump_keys) or {})
	end,
	
	update = function(self, force, do_deferred)
		
		if not self.key_id then self.used[self.imgui_keyname] = nil end
		
		if not self.pressed_down and (force or (self.key_id and check_key_released(self.key_id, not force and self.down_timer) )) then
			
			local json = self.dfcall and self.dfcall.obj_json or self.dfcall_json or ((type(self.obj)=="table") and self.obj) or nil
			--re.msg_safe("pressed " .. self.key_name .. " " .. logv(json), 556546)
			if json and (not is_valid_obj(self.obj)) then --and ((self.obj.get_type_definition and not self.obj:get_type_definition():is_a("via.Component")) or not is_obj_or_vt(self.obj)) then
				self.obj = jsonify_table(json, true) --there is no way to know when a non-component is an orphan, so it must be searched for and found in the scene every single keypress
				self.dfcall.obj = sdk.is_managed_object(self.obj) and self.obj or nil
			end
			if self.dfcall.args then 
				for i, arg in ipairs(self.dfcall.args) do 
					if type(arg) == "table" then 
						arg = jsonify_table(arg, true) --make sure any tables that couldnt be converted to objects at first are made into objects
						self.dfcall.args[i] = arg 
					end
					if type(arg) == "userdata" and self.dfcall.args_json and self.dfcall.args_json[i] then
						local is_obj = is_obj_or_vt(arg)
						if not is_obj then 
							self.dfcall.args[i] = jsonify_table(self.dfcall.args_json[i], true, {is_vt=(is_obj==1)})
						end
					end
				end
			end
			local dfcall = merge_tables({}, self.dfcall) --make a copy
			if do_deferred then
				deferred_calls[self.obj or scene] = dfcall
			else
				deferred_call(self.obj or scene, dfcall)
				if self.down_timer then 
					deferred_call(self.obj, {func="set_PuppetMode", args=true})
					self.pressed_down = true
					return
				end
			end
			
		end
		
		if self.down_timer and self.pressed_down and not force and self.key_id and not check_key_released(self.key_id, self.down_timer) then
			deferred_calls[self.obj] = {func="set_PuppetMode", args=false} --next frame
			--deferred_call(self.obj, {func="set_PuppetMode", args=false})
			self.pressed_down = nil
		end
	end,
}

for key_name, key_id in orderedPairs(via.hid.KeyboardKey) do 
	Hotkey.keys[key_name] = ((type(key_name)=="number") and key_id) or nil
end

MoveSequencer = {

	items = {},
	
	new = function(self, args, o)
		
		o = o or {}
		o.obj = args.obj or o.obj
		if o.obj and (not self.items[o.name] or not is_valid_obj(self.items[o.name])) then
			o.name = args.name or o.name or (get_GameObject(o.obj, true))
			o._ = args._ or o._ or create_REMgdObj(o.obj, true)
			o.obj.sequencer = o
			o.GameObject = args.object or o._.go or o.object or GameObject:new_AnimObject{xform=get_GameObject(o.obj, 1)}
			o.motion = o.GameObject.components_named.Motion
			if not o.motion then return end
			o.mlayer = o.motion:call("getLayer", 0)
			o.last_frame = 0
			o.Hotkeys = {} --args.Hotkeys or {}
			o.movedata = {} --args.movedata or o.movedata or {}
			
			for name, Hotkey in pairs(Hotkey.used or {}) do 
				if name:find(o.name) and name:find("MotionFsm2") then
					o.Hotkeys[name] = Hotkey
					o.movedata[name] = {}
				end
			end
			
			--[[for name, Hotkey in pairs(Hotkeys) do 
				if Hotkey.button_pressed then
					o.Hotkeys[name] = Hotkey
					Hotkey.button_pressed = nil
				end
			end]]
			
			self.items[o.name] = o
			self.__index = self  
			return setmetatable(o, self)
		end
	end,
	
	display_imgui = function(self, key_name)
		if imgui.button((self.active_timeline and "Stop Rec") or (self.timeline and "Reset") or "Record") then
			if self.active_timeline and self.active_timeline[#self.active_timeline] and not self.active_timeline[#self.active_timeline].duration then 
				self.active_timeline[#self.active_timeline].duration = ((self.last_frame > 2) and self.last_frame) or (self.movedata[self.active_timeline[#self.active_timeline].imgui_keyname].end_frame - 2)
				self.active_timeline[#self.active_timeline].mot_name = self.mot_name
			end
			local reset = self.timeline
			self.last_frame = nil
			self.timeline = not reset and self.active_timeline or nil
			self.active_timeline = not reset and ((not self.active_timeline) and {}) or nil
		end
		imgui.same_line()
		
		local pressed_play = self.timeline and self.timeline[1] and imgui.button((self.playing and "Stop") or "Play")
		if pressed_play or self.playing then
			self.playing = self.timeline and ((pressed_play and tics) or (not pressed_play and self.playing)) or nil
			for i, move in ipairs(self.timeline or {}) do 
				local last_move = (i > 1) and self.timeline[i-1]
				--[[imgui.text(i)
				imgui.same_line()
				pcall(function()
					imgui.text("Move: " .. i .. " " .. move.mot_name .. " @ " .. self.movedata[move.imgui_keyname].frame .. ", Last move: " .. last_move.mot_name .. " @ " .. self.movedata[last_move.imgui_keyname].frame .. ", Current: " .. self.mot_name)
				end)]]
				if (i == #self.timeline) and (self.mot_name == move.mot_name) and (self.movedata[move.imgui_keyname].frame >= (self.movedata[move.imgui_keyname].end_frame - 2)) then
					self.playing = nil
				elseif (i == 1 and (tics <= self.playing+1)) or (last_move and ((last_move.mot_name == self.mot_name) and (self.movedata[last_move.imgui_keyname].frame >= (last_move.duration)))) then
					--[[if (i == 1 and (tics <= self.playing+1)) then
						re.msg_safe("Starting with " .. move.mot_name .. "  duration " .. move.duration)
					elseif last_move then 
						re.msg_safe("changing to " .. i .. " " .. move.mot_name .. " @ last move " .. last_move.mot_name ..  " duration " .. last_move.duration .. " frame " .. self.movedata[last_move.imgui_keyname].frame, 12444315253)
					end]]
					self.Hotkeys[move.imgui_keyname]:update(true)
					self.movedata[move.imgui_keyname].pressed = tics
					break
				end
			end
		end
		if not self.detach then
			imgui.same_line()
			changed, self.detach = imgui.checkbox("Detach", self.detach)
		end
		self.display = true
		self:update()
		
		imgui.spacing()
		imgui.push_id(self._.key_hash)
			for name, hk_tbl in orderedPairs(self.Hotkeys) do 
				if hk_tbl:display_imgui_button() and self.active_timeline then 
					self.frame_total = self.frame_total or 0
					self.last_frame = (self.active_timeline[1] and self.last_frame) or 0
					if #self.active_timeline > 0 then 
						self.active_timeline[#self.active_timeline].duration = self.last_frame
						self.active_timeline[#self.active_timeline].next = name
						self.active_timeline[#self.active_timeline].mot_name = self.mot_name
					end
					table.insert(self.active_timeline, {
						imgui_keyname = name,
						begin_frame = self.last_frame + self.frame_total,
					})
					self.frame_total = self.frame_total + self.last_frame
				end
				if self.movedata[name].name then 
					imgui.same_line()
					imgui.text(self.movedata[name].name)
					imgui.same_line()
					imgui.text(tostring(self.movedata[name].frame) .. " / " .. tostring(self.movedata[name].end_frame))
				end
			end
			if imgui.tree_node_str_id("MS", "[Lua]") then 
				read_imgui_element(self)
				imgui.tree_pop()
			end
		imgui.pop_id()
	end,
	
	update = function(self)
		self.mot_node = self.mlayer:call("get_HighestWeightMotionNode")
		self.mot_name = self.mot_node and self.mot_node:call("get_MotionName") or "[ERROR]"
		for name, movedata in pairs(self.movedata) do
			if movedata.pressed and (tics - movedata.pressed) > 1 then --2 frames to transition
				if not movedata.name and (self.mot_name ~= self.idle_mot_name) then
					movedata.name = self.mot_name
					movedata.end_frame = self.mlayer:call("get_EndFrame")
				end
				movedata.frame = tonumber(string.format("%." .. 2 .. "f", self.mlayer:call("get_Frame")))
				
				if self.mot_name == movedata.name then
					self.last_frame = movedata.frame
				elseif self.mot_name:find("Idle") then
					movedata.pressed = nil
				end
			end
		end
	end,
}

--Check if value would be converted to a lua type, such as a quaternion ------------------------------------------------------------------------
local function is_lua_type(typedef, example)
	local typedef_name = (type(typedef)=="string") and typedef
	typedef = (typedef_name and sdk.find_type_definition(typedef_name)) or typedef
	typedef_name = typedef_name or typedef:get_full_name()
	example = (example~=nil) and (type(example)~="userdata" or tostring(example):match("glm::(.+)%<")) --(type(example)=="number") or (type(example)=="string") or (type(example)=="boolean")
	return example or (typedef_name == "System.String") or (typedef:is_value_type() and ((typedef_name:find("^System%.") and typedef:get_valuetype_size() < 17) or (typedef_name:find("via.mat")))) or nil 
	--(not typedef_name:find("sfix") and typedef:get_valuetype_size() < 17) or 
end

--Turn a string into a murmur3 hash -------------------------------------------------------------------------------------------------------------
hashing_method = function(str) 
	if type(str) == "string" and tonumber(str) == nil then
		return static_funcs.string_hashing_method:call(nil, str)
	end
	return tonumber(str)
end

local get_gameobj_path = function(gameobj) 
	local try, folder = pcall(gameobj.call, gameobj, "get_Folder")
	return try and (((folder and (folder:call("get_Path") or "") .. "/") or "") .. gameobj:call("get_Name"))
end

--Get or create a GameObject or AnimObject class from a gameobj -----------------------------------------------------------------------------
local function get_anim_object(gameobj, args, use_pcall)
	local xform
	--use_pcall = true
	if use_pcall then
		xform = gameobj and gameobj.call and ({pcall(gameobj.call, gameobj, "get_Transform")})
		xform = xform and xform[1] and xform[2]
	else
		xform = gameobj and gameobj.call and gameobj:call("get_Transform")
	end
	if xform then 
		args = args or {}
		args.xform = xform
		args.gameobj = gameobj
		held_transforms[xform] = held_transforms[xform] or (GameObject.new_AnimObject and GameObject:new_AnimObject(args)) or GameObject:new(args)
		return held_transforms[xform]
	end
end

--Create a Resource (file) ------------------------------------------------------------------------------------------------------------------------
local function create_resource(resource_path, resource_type, force_create)
	
	static_funcs.init_resources()
	resource_path = resource_path:lower()
	resource_path = resource_path:match("^.+%[@?(.+)%]") or resource_path
	log.info("creating resource " .. resource_path)
	
	local ext = resource_path:match("^.+%.(.+)$")
	if not ext or (not force_create and (ext=="motbank") and EMVSettings and (EMVSettings.special_mode > 1)) then 
		return
	end
	
	RSCache[ext .. "_resources"] = RSCache[ext .. "_resources"] or {}
	force_create = force_create or (type(RSCache[ext .. "_resources"][resource_path])=="string") or force_create
	
	if not force_create and RSCache[ext .. "_resources"][resource_path] then
		return (ext == "mesh" and RSCache[ext .. "_resources"][resource_path][1]) or RSCache[ext .. "_resources"][resource_path]
	--elseif force_create == false then
	--	return {resource_path, resource_type} --keep the info ready for when its time to load the resource
	end
	resource_type = (resource_type.get_full_name and resource_type:get_full_name() or resource_type):gsub("Holder", "") 
	
	local new_resource = sdk.create_resource(resource_type, resource_path)
	new_resource = new_resource and new_resource:add_ref()
	if not new_resource then return end
	
	local new_rs_address = new_resource and new_resource:get_address()
	if type(new_rs_address) == "number" then
		local holder = sdk.create_instance(resource_type .. "Holder", true)
		if holder and is_valid_obj(holder) then
			holder = holder:add_ref()
			holder:call(".ctor()")
			holder:write_qword(0x10, new_rs_address)
			RSCache[ext .. "_resources"][resource_path] = holder:add_ref()
			return holder
		end
	end
	return RSCache[ext .. "_resources"][resource_path]
end

--Shortcut wrapper for sdk.create_instance()
local function make_obj(name, flag)
	local td = sdk.find_type_definition(name)
	if not td then return end
	if td:is_value_type() then 
		return ValueType.new(td)
	else
		local output = ((flag and sdk.create_instance(name, true)) or sdk.create_instance(name) or ((flag == nil) and sdk.create_instance(name, true))):add_ref()
		if output and td:get_method(".ctor") then
			output:call(".ctor")
		end
		return output
	end
end

--Gathers tables of data from a managed object in preparation to make it convertable to JSON by jsonify_table
obj_to_json = function(obj, do_only_metadata, args, doForce)
	
	local try, otype = pcall(obj.get_type_definition, obj)
	local is_vt = (try and otype and otype:is_value_type()) or (do_only_metadata == 1) or nil
	
	if not try or not otype or (not is_vt and not is_valid_obj(obj)) then 
		return 
	end
	
	local name_full = otype:get_full_name()
	
	if doForce or do_only_metadata or (otype:is_a("via.Component") or otype:is_a("via.GameObject")) or ((name_full:find("Layer$")  or name_full:find("Bank$")) and (not name_full:find("[_<>,%[%]]") and not name_full:find("Collections"))) then
		local j_tbl = {} 
		local used_fields = {}
		
		if not do_only_metadata or is_vt then 
			local propdata = metadata_methods[name_full] or get_fields_and_methods(otype)
			for field_name, field in pairs(propdata.fields) do
				if not field:is_static() then
					j_tbl[field_name] = field:get_data(obj)
					used_fields[field_name:match("%<(.+)%>") or field_name] = true
				end
			end
			
			for method_name, method in pairs(propdata.setters) do
				if not misc_vars.skip_props[method_name] then
					local count_method = (method:get_num_params() == 2) and propdata.counts[method_name]
					if (method:get_num_params() == 1 or count_method) and not used_fields[method_name:gsub("_", "")] and not (method_name:find("Count$") or method_name:find("Num$")) then
						local getter = propdata.getters[method_name]
						local prop_value 
						if tostring(prop_value):find("RETransform") then
							prop_value = {__gameobj_name=get_GameObject(prop_value, true), __address=("obj:"..prop_value:get_address()), __typedef="via.Transform",}
						elseif not count_method and getter then 
							local try, item = pcall(getter.call, getter, obj) --normal values
							prop_value = (try and not (type(item)=="string" and ((item == "") or item:find("%.%.%.") or item:find("rror")))) and item or nil
							if is_valid_obj(prop_value) then
								if (prop_value:get_type_definition():is_a("via.Component") or prop_value:get_type_definition():is_a("via.GameObject")) then 
									prop_value = nil
								elseif prop_value.add_ref then 
									prop_value = prop_value:add_ref()
								end
							end
						elseif getter then
							--log.info("found count method " .. count_method:get_name() .. ", count is " .. tostring(count_method:call(obj))) 
							prop_value = {}
							for i=1, count_method:call(obj) do 
								local try, item = pcall(getter.call, getter, obj, i-1)
								if try and item and sdk.is_managed_object(item) then 
									item = obj_to_json(item) or nil 
								end
								item = not (type(item)=="string" and ((item == "") or item:find("%.%.%.") or item:find("rror"))) and item or nil --lists
								if item == nil then break end
								prop_value[#prop_value+1] = item
							end
						end
						j_tbl[method_name] = prop_value
						used_fields[method_name:gsub("_", "")] = true
					end
				end
			end
			
			--Getters only:
			for method_name, method in pairs(propdata.getters) do
				if not misc_vars.skip_props[method_name] then
					if not j_tbl[method_name] then
						local prop_value, try 
						local count_method = (method:get_num_params() == 1) and propdata.counts[method_name]
						if count_method then
							prop_value = {}
							try, count = pcall(count_method.call, count_method, obj)
							for i=1, try and count or 0 do 
								try, item = pcall(method.call, method, obj, i-1)
								if try and item and sdk.is_managed_object(item) then 
									item = obj_to_json(item) or nil 
								end
								item = not (type(item)=="string" and ((item == "") or item:find("%.%.%.") or item:find("rror"))) and item or nil --lists
								if item == nil then break end
								prop_value[#prop_value+1] = item
							end
						elseif method:get_num_params() == 0 then
							local try, item = pcall(method.call, method, obj) --normal values
							prop_value = (try and not (type(item)=="string" and ((item == "") or item:find("%.%.%.") or item:find("rror")))) and item or nil 
							if is_valid_obj(prop_value) then 
								if (prop_value:get_type_definition():is_a("via.Component") or prop_value:get_type_definition():is_a("via.GameObject")) then 
									prop_value = nil
								elseif prop_value.add_ref then 
									prop_value = prop_value:add_ref()
								end
							end
						end
						j_tbl[method_name] = prop_value
					end
				end
			end
			
			if otype:is_a("via.Transform") then
				j_tbl = {_SameJointsConstraint=j_tbl._SameJointsConstraint, _Parent=j_tbl._Parent}
			end
			
			if otype:is_a("via.render.Mesh") then
				local anim_object = (obj._ and obj._.go) 
				local xform = not anim_object and get_GameObject(obj):call("get_Transform")
				anim_object = anim_object or (xform and held_transforms[xform] or GameObject:new{xform=xform})
				if anim_object then
					j_tbl.__materials = {}
					for i, mat in ipairs(anim_object.materials) do 
						j_tbl.__materials[mat.name] = {}
						for j, var in ipairs(mat.variables) do 
							table.insert(j_tbl.__materials[mat.name], var)
						end
					end
				end
			end
			--test3 = {j_tbl, used_fields}
		end
		
		j_tbl.__gameobj_name = (otype:is_a("via.Component") and get_GameObject(obj, true)) or (otype:is_a("via.GameObject") and obj:call("get_Name")) or nil
		j_tbl.__address = "obj:" .. obj:get_address()
		j_tbl.__typedef = name_full
		j_tbl.__is_vt = is_vt
		
		if args then 
			j_tbl = merge_tables(j_tbl, args)
		end
		if do_only_metadata or (used_fields and (next(used_fields)~=nil)) then
			return j_tbl
		end
	end
end

--Saves editable fields of a GameObject or Component (or some managed object fields) as a JSON file
local function save_json_gameobject(anim_object, return_merged_tables, single_component)
	
	local filename, output = anim_object.name_w_parent:match("^(.+) %(") or anim_object.name_w_parent
	local splitted = split(filename, "%.")
	local parent_name = splitted[#splitted-1]
	local gameobj_name = anim_object.gameobj:call("get_Name()")
	filename = (parent_name and parent_name .. "." or "") .. gameobj_name
	
	if single_component then 
		local old_file = json.load_file("EMV_Engine\\Saved_GameObjects\\" .. filename .. ".json") or {}
		local raw_tbl = {[single_component]=anim_object.components_named[single_component] or anim_object.gameobj}
		local file_style = jsonify_table(raw_tbl, false, {max_level=1})
		output = {[gameobj_name] = merge_tables(old_file[gameobj_name], file_style)}
	else
		output = { [gameobj_name] = merge_tables(anim_object.components_named, {["GameObject"]=anim_object.gameobj} ) }
	end
	
	if output[gameobj_name] then 
		--save component order, since the file stores them like a dictionary
		output[gameobj_name].__components_order = {}
		for i, component in ipairs(anim_object.components) do
			local comp_td = component:get_type_definition()
			if output[gameobj_name][comp_td:get_name()] then 
				table.insert(output[gameobj_name].__components_order, comp_td:get_full_name())
			end
		end
		--save children
		output[gameobj_name].__children = {}
		for i, child in ipairs(anim_object.children or {}) do
			table.insert(output[gameobj_name].__children, get_GameObject(child, true))
		end
	end
	
	local og_output = deep_copy(output)
	if return_merged_tables then 
		return output
	end
	
	local jsonified = jsonify_table(output, nil, {max_level=1})
	return jsonified and json.dump_file("EMV_Engine\\Saved_GameObjects\\" .. filename .. ".json", jsonified)
end

--Loads editable fields of a GameObject or Component (or some managed object fields) from a JSON file
local function load_json_game_object(anim_object, set_props, single_component, given_name, file)
	local filename, output = anim_object.name_w_parent:match("^(.+) %(") or anim_object.name_w_parent
	given_name = given_name or (anim_object and anim_object.name_w_parent)
	if given_name then
		given_name = given_name:match("^(.+) %(") or given_name --remove dmc5 names
		local splitted = split(given_name, "%.")
		local parent_name = splitted[#splitted-1]
		local gameobj_name = anim_object.gameobj:call("get_Name")
		given_name = (parent_name and parent_name .. "." or "") .. gameobj_name
		file = file or json.load_file("EMV_Engine\\Saved_GameObjects\\" .. given_name .. ".json")
		local single_component_file = file and file[gameobj_name] and file[gameobj_name][single_component]
		return file and jsonify_table(
			(single_component and {[single_component]=single_component_file}) or file, 
			true, 
			{set_props=set_props, obj_to_load_to=(anim_object and (single_component and anim_object.components_named[single_component])) or nil} --or anim_object.gameobj
		) or false
	end
end

--[[function json_REMgdObj(managed_object)
	managed_object = ((type(managed_object) == "number") and sdk.to_managed_object(managed_object)) or managed_object
	if not metadata[managed_object] and not managed_object:get_type_definition():is_a("System.Type") then
		--REMgdObj_minimal = true
		managed_object.REMgdObj_minimal = nil
		if managed_object.__update and metadata[managed_object] then 
			managed_object:__update(123)
			--REMgdObj_minimal = nil
			managed_object = metadata[managed_object]
			managed_object.__address = "obj:" .. managed_object._.obj:get_address()
			managed_object.__name = managed_object._.Name --== "GameObject" and managed_object._.gameobj_name
			collectgarbage()
			return managed_object, true
		end
		--REMgdObj_minimal = nil
	end
	return managed_object, false
end]]
--test_tables = {}


--Turn a table to JSON and back --------------------------------------------------------------------------------------------------------------
jsonify_table = function(tbl_input, go_back_to_table, args)
	
	args = args or {}
	local max_level = args.max_level
	local dont_create_resources = args.dont_create_resources
	local obj_to_load_to = args.obj_to_load_to
	local only_convert_addresses = args.only_convert_addresses
	local set_props = args.set_props
	local tbl_name = args.tbl_name or ""
	local convert_lua_objs = args.convert_lua_objs
	local loops = {} --prevent self-referencing objects, tables etc from infinitely looping
	
	local function recurse(tbl, tbl_key, level)
		
		if not tbl or tbl.__dont_convert then
			return
		end
		
		level = level or 0
		local new_tbl = {}
		
		for key, value in pairs(tbl or {}) do 
			
			--log.info(tostring(key) .. ", " .. tostring(value) .. " " .. tostring(go_back_to_table) .. " " .. logv(args))
			
			local tostring_val = tostring(value)
			local val_type = type(value)
			local str_prefix = go_back_to_table and ((tbl.__address and tbl.__address:sub(1,4)) or ((val_type == "string") and value:sub(1,4)))
			local splittable = str_prefix and (str_prefix == "vec:" or str_prefix == "mat:" or str_prefix == "res:" or str_prefix == "pfb:" or str_prefix == "lua:")
			local is_mgd_obj, is_component, is_xform, is_gameobj = not go_back_to_table and is_valid_obj(value) and value:get_type_definition(), nil
			local dont_convert = false
			if is_mgd_obj then
				is_component = value:get_type_definition():is_a("via.Component")
				is_xform = is_component and value:get_type_definition():is_a("via.Transform")
				is_gameobj = value:get_type_definition():is_a("via.GameObject")
			end
			
			--convert keys to strings
			if go_back_to_table and type(key)=="string" then
				if tbl.__typedef and (type(tbl_key)=="string") and tbl_key:find("json") then --tables with "json" in the key name will not be converted to objects
					dont_convert = true
				elseif key:find("obj:") == 1 then
					local num_key = tonumber(key:sub(5,-1))
					key = sdk.is_managed_object(num_key) and sdk.to_managed_object(num_key)
					if not key then goto continue end
				elseif key:find("num:") == 1 then 
					key = tonumber(key:sub(5,-1))
				end
			elseif not go_back_to_table then 
				if sdk.is_managed_object(key) then
					key = "obj:" .. ((type(key)=="number" and key) or key:get_address()) 
				elseif type(key)=="number" and not isArray(tbl) then
					key = "num:" .. key
				end
			end
			
			if not go_back_to_table and (is_mgd_obj or tostring_val:find(",float") or tostring_val:find("qua<") or tostring_val:find("mat<")) then
				if type(value) == "number" then
					new_tbl[key] = value
				elseif is_mgd_obj and (not max_level or is_xform or (not (is_component or is_gameobj) or (level <= (max_level or 0)))) then 
					local fname = is_mgd_obj:get_full_name()
					if fname:find("Holder$") then 
						--test = {tbl_input, tbl, value}
						local path = value:call("ToString()"):match("^.+%[@?(.+)%]")
						new_tbl[key] = path and "res:" .. value:call("ToString()"):match("^.+%[@?(.+)%]") .. " " .. fname
					elseif fname == "via.Prefab" then
						local path = value:call("get_Path")
						new_tbl[key] = path and ("pfb:" .. path)
					else
						if only_convert_addresses then
							new_tbl[key] = "obj:" .. value:get_address()
						elseif not loops[value] then
							loops[value] = true
							loops[value] = recurse(obj_to_json(value), nil, level + 1)
							new_tbl[key] = loops[value] 
						else
							new_tbl[key] = loops[value] 
						end
					end
				elseif can_index(value) then 
					if type(value[0])=="userdata" then 
						local str = "mat:" 
						for i=0, 3 do 
							if value[i].x and value[i].y then
								str = str .. value[i].x .. " " .. value[i].y .. (value[i].z and ((" " .. value[i].z) .. (value[i].w and (" " .. value[i].w) or "")) or "")
								if i ~= 3 then str = str .. " " end
							end
						end
						new_tbl[key] = str
					--elseif value.__is_vec4==true then
					--	new_tbl[key] = "qua:" .. value.x .. " " .. value.y .. " " .. value.z .. " " .. value.w
					elseif type(value.x) == "number" then
						new_tbl[key] = "vec:" .. value.x .. " " .. value.y .. (value.z and ((" " .. value.z) .. (value.w and (" " .. value.w) or "")) or "")
					end
				end
			
			elseif go_back_to_table and not dont_convert and (splittable or (tbl.__component_name or tbl.__address)) then -- or str_prefix == "obj:" 
				
				local splitted = splittable and split(value:sub(5,-1), " ") or nil
				if str_prefix == "res:" then 
					--if dont_create_resources then
					--	new_tbl[key] = value
					--else 
					
						new_tbl[key] = create_resource(splitted[1], splitted[2]) --keep the info ready for when its time to load the resource
						--log.info("aa created resource " .. tostring(splitted[1]) .. " " .. tostring(new_tbl[key] .. " " .. tostring(splitted[2])))
					--end
				elseif str_prefix == "pfb:" then
					if splitted[1] and splitted[1] ~= "" then
						add_pfb_to_cache(splitted[1])
						new_tbl[key] = RSCache.pfb_resources[ splitted[1] ]
					end
				elseif tbl.__component_name or str_prefix == "obj:" then
					
					--Find object in scene using clues from json table:
					local obj = obj_to_load_to or (splitted and (sdk.is_managed_object(tonumber(splitted[1])) and sdk.to_managed_object(tonumber(splitted[1]))))
					local typedef = tbl.__typedef and sdk.find_type_definition(tbl.__typedef) 
					
					if not is_valid_obj(obj) then 
						
						if typedef and (tbl.__is_vt or args.is_vt) then --create valuetypes
							if tbl.__is_setn then 
								obj = static_objs.setn --hack fix
							else
								obj = ValueType.new(typedef)
								if obj then 
									obj:call(".ctor()") 
								end
							end
						elseif tbl.__gameobj_name then 
						
							local gameobj = scene:call("findGameObject(System.String)", tbl.__gameobj_name)
							obj = gameobj and gameobj:call("getComponent(System.Type)", (tbl.__component_name and sdk.typeof(tbl.__component_name)) or sdk.typeof(tbl.__typedef))
							
							if gameobj and tbl.__component_name then --need all this to find Layers and field objects
								local component = lua_find_component(gameobj, tbl.__component_name)
								if component then 
									if tbl.__field then 
										obj = component:get_field(tbl.__field)
									elseif tbl.__getter then
										if tbl.__idx then
											obj = component:call(tbl.__getter, tbl.__idx)
										else
											obj = component:call(tbl.__getter)
										end
									end
								end
							end
						end
					end
					
					if obj then
						if tbl.__is_lua then 
							return held_transforms[obj] or GameObject:new{xform=obj, created=tbl.__was_created}
							 
						elseif (tbl.__is_vt or set_props) and ((tbl.__typedef ~= "via.Scene") and not (tbl.__typedef:find("[<>,%[%]]"))) then
							
							local propdata = get_fields_and_methods(typedef)
							tbl.__address = nil
							local converted_tbl = recurse(tbl, key, level + 1) or {}
							
							

							
							if (tbl.__is_vt or set_props) then
								local o_tbl = obj._ or create_REMgdObj(obj)
								for field_name, field in pairs(propdata.fields) do 
									deferred_calls[obj] = deferred_calls[obj] or {}
									local to_set = converted_tbl[field_name]
									if (to_set ~= nil) and type(to_set)~="string" then
										--log.info("Setting field " .. field_name .. " " .. logv(to_set, nil, 0) .. " for " .. logv(obj, nil, 0) )
										table.insert(deferred_calls[obj], { field=field_name, args=to_set, vardata=o_tbl.field_data[field_name] } )
									end
								end
								for method_name, method in pairs(propdata.setters) do
									if converted_tbl[method_name] ~= nil then
										deferred_calls[obj] = deferred_calls[obj] or {}
										local to_set = converted_tbl[method_name]
										if (type(to_set) == "table") or method:get_num_params() == 2 then 
											if to_set.__typedef == "via.Transform" then
												to_set = scene:call("findGameObject(System.String)", tbl.__gameobj_name:gsub(" %(%d%d?%)$", ""))
												to_set = to_set and to_set:call("get_Transform")
												if to_set then 
													table.insert(deferred_calls[obj], { func=method:get_name(), args=to_set } ) 
												end
											else
												for i, item in ipairs(tbl[method_name]) do --list objects, like TreeLayers
													
													local sub_obj = (propdata.getters[method_name] and ({pcall(propdata.getters[method_name].call, propdata.getters[method_name], obj, i-1)}) )
													sub_obj = (sub_obj and sub_obj[1] and sub_obj[2]) 
													if sub_obj == nil then 
														sub_obj = to_set[i] 
													end
													local is_obj = sub_obj and sdk.is_managed_object(sub_obj)
													local sub_pd = is_obj and (metadata_methods[sub_obj] or get_fields_and_methods(sub_obj:get_type_definition()))
													--test2 = {item, sub_obj, sub_pd, to_set, converted_tbl, tbl}
													if type(item) == "table" then
														if sub_pd then 
															deferred_calls[sub_obj] = deferred_calls[sub_obj] or {}
															local sub_tbl = recurse(item, key, 0) or {}
															for fname, val in pairs(sub_tbl) do 
																local sub_mth = sub_pd.setters[fname]
																if sub_mth then
																	local so_tbl = sub_obj._ or create_REMgdObj(sub_obj)
																	log.info("Sub table set " .. sub_mth:get_name() .. " " .. logv(val, nil, 0) .. " for " .. logv(sub_obj, nil, 0) )
																	table.insert(deferred_calls[sub_obj], { func=sub_mth:get_name(), args=val , vardata=so_tbl.props_named[fname]} )
																end
															end
														end
													else --if (type(to_set[i])~="string") or not to_set[i]:find("%.%.%.") then
														log.info("Multi-param set " .. method_name .. " " .. logv(to_set[i], nil, 0) .. " at idx " .. (i-1) .. " for " .. logv(obj, nil, 0) )
														table.insert(deferred_calls[obj], { func=method:get_name(), args= (not method:get_param_types()[2]:is_primitive()) and {i-1, to_set[i]} or {to_set[i], i-1}, vardata=o_tbl.props_named[method_name] } )
													end
												end
											end
										elseif (to_set ~= nil) and (to_set ~= "") then
											log.info("Setting " .. method_name .. " " .. logv(to_set, nil, 0) .. " for " .. logv(obj, nil, 0) )
											table.insert(deferred_calls[obj], { func=method:get_name(), args=to_set, vardata=o_tbl.props_named[method_name] } )
										end
									end
								end
							end
							if converted_tbl.__materials then 
								local anim_object = get_anim_object(get_GameObject(obj))
								if anim_object then
									on_frame_calls[anim_object.gameobj] = {lua_object=anim_object, method=anim_object.set_materials, args={false, {mesh=obj, saved_variables=converted_tbl.__materials}}}
								end
							end
							if deferred_calls[obj] and deferred_calls[obj][1] and not deferred_calls[obj][2] then
								deferred_calls[obj] = deferred_calls[obj][1]
							end
						end
						return obj, tbl.__copy_json and tbl
					end
				elseif splitted and splitted[8] then
					new_tbl[key] = Matrix4x4f.new(
						Vector4f.new(splitted[1], splitted[2], splitted[3], splitted[4]), 
						Vector4f.new(splitted[5], splitted[6], splitted[7], splitted[8]), 
						Vector4f.new(splitted[9], splitted[10], splitted[11], splitted[12]), 
						Vector4f.new(splitted[13], splitted[14], splitted[15], splitted[16])
					)
				elseif str_prefix == "qua:" and #splitted==4 then
					new_tbl[key] = Quaternion.new(table.unpack(splitted))
				elseif str_prefix == "vec:" then
					new_tbl[key] = (#splitted==4 and Vector4f.new(table.unpack(splitted))) or (#splitted==3 and Vector3f.new(table.unpack(splitted))) or (#splitted==2 and Vector2f.new(table.unpack(splitted)))
				end
			
			--Everything else:
			elseif not (key == "n" and next(tbl, key) == nil) then --dont include "n" (length) keys from arrays
				if type(value) == "table" then
					value = is_vec and vector_to_table(value) or value
					if key ~= "_" then
						local mt = getmetatable(value)
						if go_back_to_table and tbl["n"] and type(key) == "string" then 
							key = tonumber(key) or key --undo json methods converting numerical array keys into strings (as that makes them into dictionaries)
						end
						if next(value) == nil then --empty tables
							new_tbl[key] = value
						elseif value.update or value.__is_lua then --lua classes
							if convert_lua_objs or (level==0) then
								if not loops[value] then
									loops[value] = true
									loops[value] = (convert_lua_objs and (value.xform and obj_to_json(value.xform, true, {__is_lua=true, __was_created=value.created}) or value)) or (level==0 and recurse(value, key, level + 1)) or value
									new_tbl[key] = loops[value]
								else
									new_tbl[key] = loops[value]
								end
							end
						elseif (mt == nil or mt.update == nil) and not tostring_val:find("sol%.")  then --regular tables; avoid sol objects and dont follow nested tables
							if not loops[value] then
								loops[value] = true
								loops[value], new_tbl[key or "" .. "_json"] = recurse(value, key, level + 1)
								new_tbl[key] = loops[value]
							else
								new_tbl[key] = loops[value]
							end
						end
					end
				elseif val_type ~= "function" then 
					if val_type == "number" or val_type == "string" or val_type == "boolean" then
						if val_type == "number" and tostring(value):sub(-2) == ".0" then 
							value = math.floor(value) --having 1 be a 1.0 can break some Capcom methods
						end
						new_tbl[key] = value
					end
				end
			end
			::continue::
		end
		return (next(new_tbl) ~= nil) and new_tbl or nil
	end
	
	if sdk.is_managed_object(tbl_input) then
		tbl_input = obj_to_json(tbl_input)
	end
	return recurse(tbl_input or {}, tbl_name) or {}
end

--[[if key == "_" then 
	local data_tbl = {}
	for i, prop in ipairs(value.props) do 
		local val = prop.cvalue or prop.value	
		if prop.set and (type(val) ~= "table") then --and not sdk.is_managed_object(val) then
			new_tbl[prop.set:get_name()] = prop.cvalue or prop.value
		end
		if type(val) ~= "table" and not sdk.is_managed_object(val) then --and 
			data_tbl[prop.name] = val
			if sdk.is_managed_object(val) then 
				if not loops[val]  then
					loops[val] = true
					val = json_REMgdObj(val)
				end
				if type(val) == "table" then
					new_tbl[prop.name] = recurse(val)
				else
					new_tbl[prop.name] = "obj:" .. val:get_address()
				end
			else
				new_tbl[prop.name] = val
			end
		end
	end
	new_tbl = merge_tables(new_tbl, recurse(data_tbl) or {})
	for key, value in pairs(data_tbl) do
		new_tbl[prop.name]
	]]
	
--[[if not loops[value] and ((tostring_val:find("sol%.REManagedObject%*")==1) or (tostring_val:find("sol%.RETransform%*")==1)) then -- or tostring_val:find("::ValueType")) then 
	--log.info("Nonfunction " .. key)
	loops[value] = key
	new_tbl[key] = value
else]]


--Get all via.Folders -----------------------------------------------------------------------------------------------------------
local function get_folders(enumerator, owner)
	if not enumerator then return end
	local tbl = {}
	enumerator:call(".ctor", 0)
	local try, output = pcall(sdk.call_object_func, enumerator, "MoveNext")
	while try and output do
		local object = enumerator:get_field("<>2__current")
		local parent = object:call("get_Parent")
		if owner == nil then
			local name = object:call("get_Name") or get_GameObject(object, true)
			tbl[name] = object 
			--table.insert(tbl, object)
		elseif not parent or parent == owner then 
			local sub_tbl, name = {object=object}
			sub_tbl.children = get_folders(object:call("get_Children"), object)
			if object:get_type_definition():is_a("via.Component") then 
				name = get_GameObject(object, true)
			else
				sub_tbl.folders = get_folders(object:call("get_Folders"), object)
				name = object:call("get_Name")
			end
			tbl[name] = sub_tbl
		end
		try, output = pcall(sdk.call_object_func, enumerator, "MoveNext")
	end
	return next(tbl) and tbl
end

--Get children of a transform --------------------------------------------------------------------------------------------------------
local function get_children(xform)
	local children = {}
	local child = xform:call("get_Child")
	while child do 
		table.insert(children, child)
		child = child:call("get_Next")
	end
	return children[1] and children
end

--Check if xform is child of another -------------------------------------------------------------------------------------------------
local function is_child_of(child_xform, possible_parent_xform)
	while is_valid_obj(child_xform) do
		child_xform = child_xform:call("get_Parent")
		if child_xform == possible_parent_xform then
			return true
		end
	end
	return false
end

--Create an object and apply ctor --------------------------------------------------------------------------------------------------------
local function constructor(type_name)
	local output = (sdk.create_instance(type_name) or sdk.create_instance(type_name, true)):add_ref()
	if output then
		if output:get_type_definition():get_method(".ctor()") then 
			output:call(".ctor()")
		end
		return output
	end
end

--GameObject and component based functions ------------------------------------------------------------------------------------------------
--Get contents of an Enumerator
local function lua_get_enumerator(m_obj, o_tbl)
	if pcall(sdk.call_object_func, m_obj, ".ctor", 0) then
		local elements = {}
		local fields = m_obj:get_type_definition():get_fields()
		local wrap_obj
		for i, field in ipairs(fields) do 
			if field:get_name():find("wrap") then   --wrappers ("Enumerator"s) cant pcall movenext without crashing to desktop unless use .ctor
				pcall(sdk.call_object_func, m_obj, "MoveNext")
				wrap_obj = fields[i]:get_data(m_obj) --({pcall(fields[i].get_data, fields[i], m_obj)})[2]
				if wrap_obj then
					m_obj = m_obj:add_ref()
					m_obj:call("SystemCollectionsIEnumeratorReset")
					wrap_obj = wrap_obj:add_ref()
					wrap_obj:call("SystemCollectionsIEnumeratorReset")
					pcall(sdk.call_object_func, wrap_obj, ".ctor", 0) 
				end
				break
			end
		end
		local state, is_obj = fields[1]:get_data(m_obj), false
		while (state == 1 or state == 0) and ({pcall(sdk.call_object_func, m_obj, "MoveNext")})[2] == true do
			local current, val = fields[2]:get_data(m_obj), nil
			state = fields[1]:get_data(m_obj)
			if sdk.is_managed_object(current) then 
				val = current:get_field("mValue")
				if val==nil then 
					is_obj = true
					current = current:add_ref()
				end
			end
			if current ~= nil then
				table.insert(elements, val or current)
			end
		end
		pcall(function()
			if wrap_obj then wrap_obj:call("SystemCollectionsIEnumeratorReset") end
			if wrap_obj then wrap_obj:call("SystemIDisposableDispose") end
			m_obj:call("SystemCollectionsIEnumeratorReset")
			m_obj:call("SystemIDisposableDispose")
		end)
		if o_tbl and #elements > 10 then 
			o_tbl.delayed_names = uptime
		end
		return elements
	end
end


--Gets a SystemArray, List or WrappedArrayContainer
local function lua_get_system_array(sys_array, allow_empty, convert_to_table)
	if not sys_array or not sys_array.get_type_definition then return (allow_empty and {}) end
	local is_wrap = (sys_array:get_type_definition():get_name():sub(1,12) == "WrappedArray")
	local system_array
	if is_wrap or sys_array.get_Count then
		system_array = {}
		for i=1, sys_array:call("get_Count") do
			system_array[i] = sys_array[i-1]--sys_array:call("get_Item", i)
		end
	end
	if not system_array then
		system_array = not is_wrap and sys_array.get_elements and sys_array:get_elements()
		if not system_array then 
			system_array = sys_array:get_field("mItems") or sys_array:get_field("_items")
			system_array = system_array and system_array.get_elements and system_array:get_elements()
		end
	end
	if system_array and convert_to_table then
		if convert_to_table == true then
			system_array = vector_to_table(system_array)
		elseif (convert_to_table == 1) and tostring(system_array[1]):find("[RV][Ea][Ml][au][ne][aT]") then 
			local dict, used_names = {}, {}
			for i, object in ipairs(system_array) do
				local name, idx = get_mgd_obj_name(object) or i, 1
				local tmp_name = name
				while used_names[tmp_name] do 
					tmp_name = idx .. name
					idx = idx + 1
				end
				used_names[tmp_name] = true
				name = tmp_name
				dict[name] = object
			end
			system_array = dict
		end
	end
	return (allow_empty and system_array) or (system_array and system_array[1] and system_array)
end

--Get components from an xform (less error prone)
local function lua_get_components(xform_or_component) --xform expected
	local comps = {}
	local components_named = {}
	local component_name = "via.Transform"
	while not components_named[component_name] do
		table.insert(comps, xform_or_component)
		components_named[component_name] = xform_or_component
		xform_or_component = ({pcall(static_funcs.get_chain_method.call, static_funcs.get_chain_method, xform_or_component)})
		xform_or_component = xform_or_component and xform_or_component[1] and xform_or_component[2]
		if xform_or_component and xform_or_component.get_type_definition then
			component_name = xform_or_component:get_type_definition():get_name()
		end
	end
	return comps[1] and comps, comps[1] and components_named
end

--Get a component from a gameobject (less error prone)
lua_find_component = function(gameobj, component_name, do_use_pcall)
	if gameobj and sdk.find_type_definition(component_name) then
		if do_use_pcall then 
			local try, out = pcall(sdk.call_object_func, gameobj, "getComponent(System.Type)", sdk.typeof(component_name))
			return try and out
		else
			return gameobj:call("getComponent(System.Type)", sdk.typeof(component_name))
		end
	end
end

--Delete a component
local function delete_component(gameobj, component_to_del)
	local components = ({pcall(sdk.call_object_func, gameobj, "get_Components")}) --gameobj:call("get_Components"):get_elements()
	components = components and components[1] and components[2]
	for i, component in ipairs(components or {}) do 
		if i > 1 and component == component_to_del then 
			components[i-1]:write_qword(0x18, component_to_del:read_qword(0x18)) 
			component_to_del:write_qword(0x18, 0)
			break
		end
	end
	component_to_del:call("destroy", component_to_del)
end

--Test if an object's name (object.name) is repeated in a numbered list of objects:
local function is_unique_name(t, name)
	local ctr = 0
	for i, v in ipairs(t) do 
		if v.name == name then ctr = ctr + 1 end
		if ctr > 1 then return false end
	end
	return true
end

--Test if a transform (object.xform) is unique in a numbered list of GameObject style classes 
local function contains_xform(t, xform)
	for k, v in pairs(t) do 
		if v.xform == xform then 
			return k
		end
	end
	return false
end

--Spawns a GameObject at a position in a via.Folder
local function spawn_gameobj(name, position, folder)
	position = position or Vector3f.new(0,0,0)
	local create_method = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)")
	local gameobj = create_method:call(nil, name, folder or 0)
	if gameobj then 
		gameobj = gameobj:add_ref()
		gameobj:call(".ctor")
		local xform = gameobj:call("get_Transform")
		held_transforms[xform] = held_transforms[xform] or GameObject:new_AnimObject{xform=xform}
		return held_transforms[xform]
	end
end

--Make a transform or joint look at a position:
local function look_at(self, xform_or_joint, matrix)
	xform_or_joint = (self.joints and self.joints[self.lookat_joint_index]) or xform_or_joint
	matrix = matrix or (static_objs.cam:call("get_WorldMatrix"))
	--if xform_or_joint and matrix then 
	--	xform_or_joint:call("lookAt", Vector3f.new(-matrix[3].x, 0, -matrix[3].z), Vector3f.new(0, 1, 0)) 
		--xform_or_joint:call("lookAt", Vector3f.new(-matrix[3].x, -matrix[3].y, -matrix[3].z), Vector3f.new(0, 1, 0)) 
	--	return 
	--end
end

--Resource Management functions -----------------------------------------------------------------------------------------------------------------------------------
--Adds a resource to the cache, or returns the index to the already-cached texture in RN
local function add_resource_to_cache(resource_holder, paired_resource_holder, data_holder)
	
	if type(resource_holder)=="string" then
		resource_holder = jsonify_table({resource_holder}, true)[1]
	end
	if type(paired_resource_holder)=="string" then
		paired_resource_holder = jsonify_table({paired_resource_holder}, true)[1]
	end

	local ret_type = data_holder and (data_holder.ret_type or data_holder.item_type)
	if not resource_holder or type(resource_holder.call) ~= "function" then --nil (unset) values, problem is that you cant easily find out the extension
		local ext = ret_type and (SettingsCache.typedef_names_to_extensions[ret_type:get_name()] or ret_type:get_name():gsub("ResourceHolder", ""):lower()) or " "
		return 1, " ", ext
	end
	
	local resource_path = resource_holder:call("ToString()"):match("^.+%[@?(.+)%]")
	
	if not resource_path then 
		local ext = ret_type and (SettingsCache.typedef_names_to_extensions[ret_type:get_name()] or ret_type:get_name():gsub("ResourceHolder", ""):lower()) or " "
		return 1, " ", ext or " "
	end
	
	resource_path = resource_path and resource_path:lower()
	local ext = resource_path:match("^.+%.(.+)$")
	if not ext then return 1, " ", " " end
	local rs_name = ext .. "_resources"
	local rn_name = ext .. "_resource_names"
	RSCache[rs_name] = RSCache[rs_name] or {}
	RN[rn_name] = RN[rn_name] or {" "}
	
	local res = RSCache[rs_name][resource_path]
	if type(res) == "string" or (type(res)=="table" and type(res[1])=="string") then
		RSCache[rs_name][resource_path] = jsonify_table({res}, true)[1]
		--RSCache[rs_name][resource_path] = create_resource(table.unpack(RSCache[rs_name][resource_path]))
	--elseif  then 
	--	RSCache[rs_name][resource_path] = jsonify_table({res}, true)[1]
	end
	
	local td_name = ret_type and ret_type:get_name() or resource_holder:get_type_definition():get_name()
	SettingsCache.typedef_names_to_extensions[td_name] = SettingsCache.typedef_names_to_extensions[td_name] or ext
	local current_idx = 1
	
	if not RSCache[rs_name][resource_path] then 
		current_idx = table.binsert(RN[rn_name], resource_path)
		RSCache[rs_name][resource_path] = ((paired_resource_holder or (ext == "mesh")) and {resource_holder, paired_resource_holder}) or resource_holder
		resource_holder = resource_holder:add_ref()
		_G.resource_added = true
	else
		current_idx = find_index(RN[rn_name], resource_path)
	end
	return current_idx, resource_path, ext
end

--Adds a prefab to the cache
add_pfb_to_cache = function(via_prefab, pfb_path)
	RSCache.pfb_resources = RSCache.pfb_resources or {}
	RN.pfb_resource_names = RN.pfb_resource_names or {}
	if type(via_prefab)~="userdata" then
		pfb_path = pfb_path or via_prefab
		via_prefab = RSCache.pfb_resources[pfb_path] or constructor("via.Prefab")
		via_prefab:call("set_Path", pfb_path)
	end
	pfb_path = pfb_path or via_prefab:call("get_Path")
	if via_prefab:call("get_Exist") then
		local current_idx = not RSCache.pfb_resources[pfb_path] and table.binsert(RN.pfb_resource_names, pfb_path)
		RSCache.pfb_resources[pfb_path] = via_prefab
		return current_idx, pfb_path, "pfb"
	else
		--re.msg_safe("File not found", 23525643634)
		log.debug("File not found: " .. tostring(pfb_path))
	end
end
--stage/prefab/antique/antiqueFigure_MR/figure_104.pfb
--REResources\evc0010_Character.pfb.17

--Get the local player -----------------------------------------------------------------------------------------------------------------
local function get_player(as_GameObject)
	static_objs.playermanager = sdk.get_managed_singleton(sdk.game_namespace((isMHR and "player." or "") .. "PlayerManager"))
	if static_objs.playermanager or isRE8 or isRE7 then 
		local player, xform
		if isDMC then 
			player = static_objs.playermanager:call("get_manualPlayer")
			player = get_GameObject(player)
		elseif isMHR then 
			player = static_objs.playermanager:call("findMasterPlayer")
		elseif isRE8 then
			xform = find("app.PlayerUpdaterBase")[1]
			player = xform and get_GameObject(xform)
		elseif isRE7 then
			xform = find("app.PlayerCamera")[1]
			player = xform and get_GameObject(xform)
		else
			player = static_objs.playermanager:call("get_CurrentPlayer")
		end
		if player and as_GameObject then 
			xform = xform or player and player:call("get_Transform")
			player = xform and GameObject:new{xform=xform, gameobj=player}
			if isRE7 and player then player.isRE7player = true end
		end
		return player
	end
end

--Get the first GameObject in the scene:
local function get_first_gameobj()
	local try, xform = pcall(scene.call, scene, "get_FirstTransform")
	if try and xform and is_valid_obj(xform) then 
		touched_gameobjects[xform] = touched_gameobjects[xform] or GameObject:new {xform=xform }
		return touched_gameobjects[xform]
	end
end

--Retrieve all loaded via.Folders as a table:
local function get_all_folders()
	folders = get_folders(scene:call("get_Folders"), scene)
	return folders
end
get_all_folders()

--Retrieve all loaded via.Transforms as a table:
local function get_transforms()
	transforms = scene and scene:call("findComponents(System.Type)", sdk.typeof("via.Transform")):add_ref()
	transforms = transforms and transforms.get_elements and transforms:get_elements()
	return transforms
end
get_transforms()

--Search all via.Folders for a search term:
local function searchf(search_term)
	local all_folders = scene and get_folders(scene:call("get_Folders"))
	local results = {[search_term]=scene:call("findFolder", search_term)}
	local lower_term = search_term:lower()
	for name, folder in pairs(all_folders) do
		if name:lower():find(lower_term) then
			results[name] = folder
		end
	end
	return results
end

--Creates a new named GameObject+transform and gives it components from a list of component names:
local function create_gameobj(name, component_names, args, dont_rename)
	if not name then return end
	args = args or {}
	local parent_gameobj 
	if args.parent then
		if type(args.parent)=="string" then
			scene:call("findGameObject(System.String)", args.parent)
		elseif can_index(args.parent) and args.parent.get_type_definition then
			parent_gameobj = args.parent:call("get_GameObject") or args.parent
		end
	end
	--local parent_gameobj = args.parent and ((type(args.parent=="string") and scene:call("findGameObject(System.String)", args.parent)) or (type(args.parent)=="userdata" and (args.parent:call("get_GameObject") or args.parent)))
	local parent_joint = args.parent_joint
	local folder = (args.folder and scene:call("findFolder", args.folder)) or (parent_gameobj and parent_gameobj:call("get_Folder")) or static_objs.spawned_prefabs_folder or nil --or (player and player.gameobj:call("get_Folder"))
	local worldmatrix = args.worldmatrix
	local new_name = name
	if not dont_rename then
		local ctr = 0
		while scene:call("findGameObject(System.String)", new_name) do 
			ctr = ctr + 1
			new_name = name .. (ctr < 10 and "0" or "") .. ctr
		end
	end
	name = new_name
	args.parent, args.parent_joint, args.folder = nil
	local new_gameobj = folder and static_funcs.mk_gameobj_w_fld(nil, name, folder) or static_funcs.mk_gameobj(nil, name)
	new_gameobj = new_gameobj and new_gameobj:add_ref()
	if new_gameobj and new_gameobj:call(".ctor") then
		local xform = new_gameobj:call("get_Transform")
		--write_mat4(xform, worldmatrix)
		for i, name in ipairs(component_names or {}) do 
			local td = sdk.find_type_definition(name)
			local new_component = td and ((name == "via.Transform") and xform) or new_gameobj:call("createComponent(System.Type)", td:get_runtime_type())
			new_component = new_component and new_component:add_ref()
			if new_component then 
				new_component:call(".ctor()")
				if new_component:get_type_definition():is_a("via.Behavior") then
				--	pcall(new_component.call, new_component, "awake()")
				--	pcall(new_component.call, new_component, "start()")
				end
				if name == "via.render.Mesh" and args.mesh then 
					local mesh_res = create_resource(args.mesh, "via.render.MeshResource")
					if mesh_res then
						local mdf_res = create_resource(args.mdf or args.mesh:gsub("%.mesh", ".mdf2"), "via.render.MeshMaterialResource")
						new_component:call("setMesh", mesh_res)
						if mdf_res then
							new_component:call("set_Material", mdf_res)
						end
						args.mesh, args.mdf = nil
					end
				end
				if name == "via.motion.Motion" then 
					local new_layer = sdk.create_instance("via.motion.TreeLayer")
					new_layer = new_layer and new_layer:add_ref()
					if new_layer and new_layer:call(".ctor") then
						new_component:call("setLayerCount", 1)
						new_component:call("setLayer", 0, new_layer)
						local new_dbank = sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
						if new_dbank then 
							new_dbank :call(".ctor")
							new_component:call("setDynamicMotionBankCount", 1)
							new_component:call("setDynamicMotionBank", 0, new_dbank)
						end
					end
				end
			end
		end
		
		local new_obj = GameObject:new({xform=xform, gameobj=new_gameobj}, args)
		if parent_gameobj then
			local parent = parent_gameobj:call("get_Transform")
			new_obj:set_parent(parent)
			local parent_joint_obj = parent_joint and parent:call("getJointByName", parent_joint)
			if parent_joint_obj then
				xform:call("set_ParentJoint", parent_joint)
				xform:call("set_LocalPosition",  parent_joint_obj:call("get_BaseLocalPosition") or Vector3f.new(0,0,0))
				local rot = args.rot or parent_joint_obj:call("get_BaseLocalRotation") or Quaternion.new(0,0,0.681639,0.731689) --Vector4f.new(0,0,0,1) --
				xform:call("set_LocalRotation", rot)
			end
		end
		
		if args.same_joints_constraint then 
			xform:call("set_SameJointsConstraint", true)
		end
		
		local file = args.file --and deep_copy(args.file)
		
		
		if file then
			file.__dont_convert = nil
			local file_tbl = file[args.given_name:match("^.+%.(.-)$") or args.given_name]
			for i, comp_name in pairs(file_tbl and file_tbl.__components_order or {}) do
				if args.disabled_components[comp_name] then
					file_tbl[comp_name:match("^.+%.(.-)$") or 0] = nil
				end
			end
			
			local success = load_json_game_object(new_obj, true, false, args.given_name, file)
			
			if success and args.load_children and file_tbl and file_tbl.__children then 
				local glob = fs.glob([[EMV_Engine\\Saved_GameObjects\\.*.json]])
				for i, child_name in ipairs(file_tbl.__children) do 
					
					local child_file = find_index(glob, "EMV_Engine\\Saved_GameObjects\\" .. name .. "." .. child_name .. ".json") and json.load_file("EMV_Engine\\Saved_GameObjects\\" .. name .. "." .. child_name .. ".json")
					if child_file and child_file[child_name] then 
						--re.msg("Loaded Child EMV_Engine\\Saved_GameObjects\\" .. name .. "." .. child_name .. ".json")
						local child_components_ord = child_file[child_name].__components_order
						local child_args = { given_name=child_name, parent=name, file=child_file, load_children=true, disabled_components=args.disabled_components}
						local child_new_components = {}
						for i, full_name in ipairs(child_components_ord) do 
							table.insert(child_new_components, full_name)
							local comp_json = child_file[child_name][full_name:match("^.+%.(.-)$")]
							if comp_json then
								for k, v in pairs(comp_json or {}) do
									if full_name == "via.Transform" then
										if k=="_SameJointsConstraint" then child_args.same_joints_constraint = v end
										if k=="_ParentJoint" then child_args.parent_joint = v end
									end
									if full_name == "via.render.Mesh" then
										if k == "Mesh" then  child_args.mesh = v:match("res:(.+) ") end
										if k == "_Material" then  child_args.mdf = v:match("res:(.+) ") end
									end
								end
								if args.disabled_components[full_name] or (full_name == "via.motion.Motion") then
									child_file[child_name][full_name:match("^.+%.(.-)$")] = nil
								else
									child_file[child_name][full_name:match("^.+%.(.-)$")] = cd.recurse(comp_json)
								end
							end
						end
						--child_file[child_name]["Motion"] = nil
						local child_obj = create_gameobj(child_name, child_new_components, child_args, dont_rename)
						if child_obj then 
							new_obj.children = new_obj.children or {}
							table.insert(new_obj.children, child_obj)
							child_obj:set_parent(new_obj.xform)
							child_obj.display, child_obj.display_org  = true, true
							child_obj:toggle_display()
						end
					end
				end
			end
		end
		
		if args.add_to_anim_viewer and new_obj.activate_forced_mode then --EMVSettings and not figure_mode and new_obj.layer and
			total_objects = total_objects or {}
			if not figure_mode then
				deferred_calls[new_gameobj] = {lua_object=new_obj, method=new_obj.activate_forced_mode }
				new_obj.forced_mode_center = worldmatrix and worldmatrix[3]:to_vec3()
			else
				EMV.clear_figures()
			end
		end
		
		if worldmatrix then 
			local t, r, s = mat4_to_trs(worldmatrix)
			xform:call("set_Position", t)
			xform:call("set_Rotation", r)
			xform:call("set_Scale", s)
			deferred_calls[xform] = deferred_calls[xform] or {}
			table.insert(deferred_calls[xform], {lua_object=new_obj, method=new_obj.set_transform, args={{t,r,s}}})
		end
		
		new_obj.created = true
		new_obj.display, new_obj.display_org  = true, true
		new_obj:toggle_display()
		new_obj.load_children, new_obj.disabled_components, new_obj.chain_name, new_obj.add_to_anim_viewer, new_obj.given_name = nil
		--deferred_calls = {}
		--old_deferred_calls = {}
		Collection[name] = new_obj
		
		return new_obj
	end
end

--Clone an object:
local function clone(instance, instance_type)
	
	if sdk.is_managed_object(instance) then 
		instance_type = instance_type or instance:get_type_definition()
		local i_name = instance_type:get_full_name()
		--log.info(
		--	"type: " .. i_name .. 
		--	", is_by_ref: " .. tostring(instance_type:is_by_ref()) ..
		--	", is_pointer: " .. tostring(instance_type:is_pointer()) ..
		--	", is_primitive: " .. tostring(instance_type:is_primitive())
		--)
		
		local worked, copy = pcall(sdk.create_instance, instance_type:get_full_name())
		
		if not worked then 
			copy = ValueType.new(instance_type)
		end
		
		if copy then 
			copy:call(".cctor")
			copy:call(".ctor")
		end

		copy = copy or instance:call("MemberwiseClone")
		
		if copy and sdk.is_managed_object(copy) then 
			 
			if tostring(instance):find("SystemArray") then 
				local elements = instance:get_elements()
				for i, elem in ipairs(elements) do 
					local new_element = clone(elem)
					copy:call("set_Item", i, new_element)
				end
			else 
				for i, field in ipairs(instance_type:get_fields()) do 
					local field_name = field:get_name()
					local field_type = field:get_type()
					if not field:is_literal() then --and not field:is_static() 
						local new_field = instance:get_field(field_name)
						if new_field ~= nil and type(new_field) ~= "string" then 
							if sdk.is_managed_object(new_field) and not field_type:is_a("via.Component") and not field_type:is_a("via.GameObject") then 
								new_field = clone(new_field)
							end
							sdk.set_native_field(copy, instance_type, field_name, new_field)
							--local try = pcall(sdk.set_native_field, copy, instance_type, field_name, new_field) 
							--if not try then 
							--	log_value(copy:call("ToString()") .. " -> " .. field_name, "set_field failed") 
							--	tester = new_component
							--	return
							--end 
						end
					end
				end
			end
			return copy:add_ref()
		end
	end
	return instance
end

--Clone a gameobject:
--[[
function clone_gameobject(gobj)
	
	local new_name = gobj.name .. "_COPY"
	
	local clonobj = gobj.gameobj:call("create", new_name) 
	
	if clonobj then 
		clonobj:call(".ctor")
		clonobj = clonobj:add_ref()
		
		local size = gobj.gameobj:get_type_definition():get_size()
		--for i = 24, size do 
		--	clonobj:write_byte(i, gobj.gameobj:read_byte(i))
		--end
		local comp_addresses = {}
		local idx_comps = {}
		for i, component in ipairs(gobj.components) do 
			local new_component = clonobj:call("createComponent", component:get_type_definition():get_runtime_type()) --clone(component) --
			asdf = {clonobj, component, component:get_type_definition():get_runtime_type(), new_component}
			if new_component then 
				new_component = new_component:add_ref()
				table.insert(idx_comps, {new=new_component, old=component})
				comp_addresses[component] = i--clone(component)
				print("created comp")
			else	
				print("failed to create comp")
			end
		end
		
		for i, components in ipairs(idx_comps) do 
		
			local typedef = components.old:get_type_definition()
			components.new:write_qword(0x10, clonobj:get_address())
			local childComponent = components.old:read_qword(0x18) 
			if comp_addresses[childComponent] then 
				local new_addr = idx_comps[ comp_addresses[childComponent] ].new:get_address()
				--log.info("FOUND " .. typedef:get_full_name() .. ", writing " .. tostring(new_addr))
				components.new:write_qword(0x18, new_addr) 
			end
			
			--if typedef:get_full_name() == "via.Transform" then 
				--for i = 0, typedef:get_size() do 
				--	components.new:write_byte(i, components.old:read_byte(i))
				--end
				--write_mat4(components.new, 128, trs_to_mat4(components.old:call("get_Position"), components.old:call("get_Rotation"), components.old:call("get_LocalScale")))
			--end
			
			for i, field in ipairs(typedef:get_fields()) do
				if not field:is_literal() and not field:is_static() then
					local field_name = field:get_name()
					local field_value = components.old:get_field(field_name)
					--local new_field_value = components.new:get_field(field_name)
					if sdk.is_managed_object(field_value) then 
						if comp_addresses[field_value] ~= nil then
							--components.new:set_field(field_name, comp_addresses[field_value].new)
						else
							local cloned_value = clone(field_value)
							components.new:set_field(field_name, cloned_value)
						end
					elseif field_value ~= nil and type(field_value) ~= "string" then 
						sdk.set_native_field(components.new, typedef, field_name, field_value)
						--local try = pcall(sdk.set_native_field, components.new, typedef, field_name, field_value)
						--if not try then 
						--	re.msg(logv(components.old:call("ToString()") .. " -> " .. field_name, "set_field failed"))
						--	tester = components.new
						--	return
						--end 
					end
				end
			end
		end
		
		local output = GameObject:new { gameobj = clonobj }
		output.components = clonobj:call("get_Components"):get_elements()
		return output
	end
end
]]
--Check a SystemArray typedef for what trypedef the array contains. Caches results
local cached_array_typedefs = {}
local function evaluate_array_typedef_name(typedef, td_name)
	typedef = typedef or sdk.find_type_definition(td_name)
	td_name = td_name or typedef:get_full_name()
	local output = cached_array_typedefs[td_name]
	if not output then
		local str
		if td_name:find(">d__") then --arrays
			str = td_name:gsub("%." .. typedef:get_name(), "")
		elseif td_name:find("%[%]") then --arrays
			str = td_name:gsub("%[%]", "")
		elseif td_name:find("Generic%.") and not td_name:find("Enumerator") then --all other dictionaries and arrays
			str = td_name:match("<(.+)>")
			str = str and str:match("<(.+)>") or str
			str = str and str:match(",(.+)$") or str
		end
		--str = ((str == "via.GameObjectRef") and "via.GameObject") or str
		output = (str and sdk.find_type_definition(str))
	end
	return ((type(output) == "userdata") and output) or nil
end

--Manually writes a ValueType at a set offset
local function write_valuetype(parent_obj, offset, value)
    for i=0, value.type:get_valuetype_size()-1 do
        parent_obj:write_byte(offset+i, value:read_byte(i))
    end
end

--Manually reads a unicode string at an address
local function read_unicode_string(ptr, is_offset)
	ptr = (is_offset and sdk.to_valuetype(ptr, "System.UInt64").mValue) or ptr
	local offs = ptr
	local str = ""
	while offs - ptr < 256 and (sdk.to_valuetype(offs, "System.Int16") or {mValue=0}).mValue ~= 0 do
		local rByte = sdk.to_valuetype(offs, "System.Byte").mValue
		str = str .. utf8.char(rByte)
		offs = offs + 2
	end
    return str
end

--Takes managed objects (as keys) from deferred_calls[] and call functions on them based on their arguments, during UpdateMotion or on_frame
deferred_call = function(managed_object, args, index, on_frame)
	
	local deferred_calls = (on_frame and on_frame_calls) or deferred_calls
	
	if not index and isArray(args) then
		local frozen_calls = {}
		for idx, real_args in ipairs(args) do
			if deferred_call(managed_object, real_args, idx, on_frame) then
				table.insert(frozen_calls, real_args)
			end
		end
		deferred_calls[managed_object] = (frozen_calls[1] and frozen_calls) or nil --remove only non-frozen calls
	else
		
		managed_object = args.obj or managed_object
		
		if managed_object and managed_object.get_type_definition then
			
			--local name = managed_object:get_type_definition():get_full_name() .. (args.vardata and args.vardata.name or "") .. (index or "")
			
			local try, out
			local vardata = type(args.vardata)=="table" and args.vardata
			--[[if not vardata and args.obj and args.obj._ then 
				vardata = (args.field and args.obj._.field_data[args.field]) or  args.obj[args.func:sub(1,4)]
				args.vardata = vardata
			end]]
			local name = logv(managed_object, nil, 0) .. " " .. (vardata and vardata.name or "") .. (index or "")
			
			if old_deferred_calls[name] and old_deferred_calls[name].Error then
				log.info("Skipping broken deferred call")
				return
			end
			
			local freeze = vardata and vardata.freeze
			if vardata and vardata.freezetable then 
				freeze = vardata.freezetable[args.args[1] + 1]
			end
			
			if freeze and old_deferred_calls[name] and freeze ~= 1 then 
				--args = (index and old_deferred_calls[name][index]) or old_deferred_calls[name] --keep re-using the same deferred_call from old_deferred_calls if frozen
				args = old_deferred_calls[name]
			end
			
			if index then 
				old_deferred_calls[name] = old_deferred_calls[name] or {}
				old_deferred_calls[name] = args
			else
				old_deferred_calls[name] = args
			end
			
			if not freeze and not index then 
				deferred_calls[managed_object] = nil
			elseif managed_object._ then 
				if freeze then 
					managed_object._.is_frozen = true
				else
					managed_object._.is_frozen = nil
				end
			end
			
			if args.fn then
				try, out = pcall(args.fn)
			elseif args.command then --commands as strings
				out = run_command(args.command) --pcall(load("return " .. args.command))
				if args.lua_object and args.command_key ~= nil then 
					args.lua_object[args.command_key] = out
				end
			elseif args.lua_object and args.method then
				if args.method then 
					if args.args then
						try, out = pcall(args.method, args.lua_object, (type(args.args)=="table" and table.unpack(args.args)) or args.args)
					else
						try, out = pcall(args.method, args.lua_object)
					end
				end
			elseif args.lua_func then --objectless lua functions like draw_line()
				if args.args then
					try, out = pcall(args.lua_func, table.unpack(args.args))
				else
					try, out = pcall(args.lua_func)
				end
			elseif args.args ~= nil then
				local value = args.args
				if value == "__nil" then 
					value = nil
				end
				
				if args.field ~= nil and args.func == nil then
					--[[if vardata and vardata.is_lua_type == "vec" or vardata.is_lua_type == "quat" or vardata.is_lua_type == "string" or vardata.is_lua_type == "mat" then
						value = value_to_obj(value, vardata.ret_type)
					end]]
					try, out = pcall(managed_object.set_field,  managed_object, args.field, value) --fields
					--managed_object:set_field(args.field, value); try = true
					--out = try and tics or out
				else--if args.field == nil then
					if type(value) == "table" then 
						--[[for i, arg in ipairs(value) do 
							value[i] = (arg~="__nil") and arg or nil
						end]]
						if args.func then
							try, out = pcall(managed_object.call,	managed_object, args.func, 	table.unpack(value)) --methods by name with args 
						elseif args.method then
							try, out = pcall(args.method.call,	args.method, managed_object, table.unpack(value))
						end
					elseif args.func then
						try, out = pcall(managed_object.call,	managed_object, args.func, 	value) --methods with one arg
					elseif args.method then
						try, out = pcall(args.method.call,	args.method, managed_object, value)
						--log.info("Calling " .. args.func .. logv(value, nil, 0))
					end
				end
			else
				try, out = pcall(managed_object.call, managed_object, args.func) --methods with no args
			end
			
			if try == false then 
				old_deferred_calls[name].Error = tostring(out)
				old_deferred_calls[name].obj = managed_object
				log.info("Failed, Deferred Call Error:\n" .. logv(args)) 
			else--if not args.field and out==nil then
				old_deferred_calls[name].output = (out~=nil) and logv(out) or tics
				old_deferred_calls[name].obj = managed_object
				if args.delayed_global_key ~= nil and _G[args.delayed_global_key] ~= nil  then 
					_G[args.delayed_global_key] = out
				end
				if vardata then 
					vardata.update = true
				end
			end
			
			return freeze
		end
	end
end
		
--Convert a lua value to a RE Engine object
function value_to_obj(value, ret_type, ret_typename)
	ret_type = (type(ret_type)=="string" and sdk.find_type_definition(ret_type)) or ret_type
	ret_type = ret_type or (ret_typename and sdk.find_type_definition(ret_typename))
	if not ret_type then return value, "no ret type" end
	ret_typename = ret_typename or ret_type:get_full_name() 
	local func = typedef_to_function[ret_typename]
	if not func then
		for typename, fn in pairs(typedef_to_function) do
			if ret_type:is_a(typename) then
				log.info(typename)
				func = fn
				break
			end
		end
	end
	if func then 
		if func == sdk.create_managed_array then
			local arr_typedef = evaluate_array_typedef_name(ret_type) or ret_type --sdk.find_type_definition(ret_typename:gsub("%[%]", "")) or ret_type
			local new_arr = (arr_typedef and (type(value) == "table")) and func(arr_typedef, #value)
			new_arr = new_arr:add_ref()
			if new_arr then 
				new_arr:call(".ctor", #value)
				for i, element in ipairs(value) do 
					local elem_obj = value_to_obj(element, arr_typedef)
					log.info(i .. " " .. element .. " " .. logv(elem_obj))
					new_arr:call("SetValue(System.Object, System.Int32)", elem_obj, i-1)
				end
				return new_arr
			end
		elseif func == sdk.create_resource then
			return (type(value) == "string") and create_resource(value, ret_type)
		else
			local new_object = func(value)
			return (new_object and new_object:add_ref()) or nil
		end
	end
	return value, "no func"
end

--[[
--Convert
function create_array_object(tbl, ret_type)
	ret_type = ret_type.get_full_name and ret_type:get_full_name() or ret_type
	local new_arr = (sdk.create_instance(ret_type) or sdk.create_instance(ret_type, true)):add_ref()
	new_arr:call(".ctor")
	new_arr:call("set_Count", #tbl)
	for i, element in ipairs(tbl) do 
		new_arr:call("SetValue(System.Object, System.Int32)", element, i-1)
	end
	return new_arr
end]]

--Functions for displaying objects, tables and variables as text -------------------------------------------------------------------------------
--Format a vector2, vector3, vector4 or Quaternion as text:
local function vector_to_string(vector) 
	return  vector and   ("["  .. vector.x .. ", " .. vector.y
		.. (vector.z and (", " .. vector.z) or "")
		.. (vector.w and (", " .. vector.w) or "") .. "]") or "nil"
end

--Format a matrix4 as text
local function mat4_to_string(mat, padding) 
	padding = padding or ""
	if mat then 
		local transform_string = 	   "\n" .. padding ..  "[" .. mat[0].x .. ", " .. mat[0].y .. ", " .. mat[0].z .. ", " .. mat[0].w .. "]\n"
		transform_string = transform_string .. padding ..  "[" .. mat[1].x .. ", " .. mat[1].y .. ", " .. mat[1].z .. ", " .. mat[0].w .. "]\n"
		transform_string = transform_string .. padding ..  "[" .. mat[2].x .. ", " .. mat[2].y .. ", " .. mat[2].z .. ", " .. mat[0].w .. "]\n"
		return 			   transform_string .. padding ..  "[" .. mat[3].x .. ", " .. mat[3].y .. ", " .. mat[3].z .. ", " .. mat[0].w .. "]"
	end 
	return "nil"
end

--Format a table of bytes into a string
local function log_bytes(bytes) --takes a std::vector<unsigned char>
	local msg = {""}
	for i, sbyte in ipairs(bytes) do
		if i ~= 1 and (i-1) % 4 == 0 then table.insert(msg, "  ") end
		if i ~= 1 and (i-1) % 16 == 0 then 
			local str_msg = {""}
			for b=i-16, i-1 do 
				table.insert(str_msg, string.char(bytes[b]))
			end
			table.insert(msg, "	" .. string.gsub(table.concat(str_msg), "%c", ".") .. "\n")
		end
		table.insert(msg, string.format("%02X ", tostring(sbyte)))
	end
	return table.concat(msg)
end

--Display the bytes of a managed object as text, similar to a hex editor
local function read_bytes(obj)
	local tab = {}
	local sz = obj:get_type_definition():get_size()
	if sz > 8192 then sz = 8192 end 
	for i=1, sz do
		table.insert(tab, obj:read_byte(i-1))
	end
	return "\n" .. log_bytes(tab)
end

--Format all attributes of a method as text
local function log_method(method, padding)
	padding = (padding or "") .. "    "
	local msg = {"\n" .. padding .. method:get_return_type():get_full_name() .. " " .. method:get_name() .. "("}
	local num_params = method:get_num_params()
	local param_types = method:get_param_types()
	local param_names = method:get_param_names()
	for i, param in ipairs(param_names) do 
		if i ~= 1 then table.insert(msg, ", ") end
		table.insert(msg, param)
	end
	table.insert(msg, ")\n  " 
		.. padding .. "Declaring Type: " .. method:get_declaring_type():get_full_name() .. "\n  " 
		.. padding .. "Is Static: " .. tostring(method:is_static())
	)
	if num_params > 0 then 
		--table.insert(msg, "\n  " .. padding .. "Num Params: " .. tostring(method:get_num_params()))
		for i, param in ipairs(param_names) do 
			table.insert(msg, "\n    " .. padding .. tostring(i) .. ". " .. param_types[i]:get_full_name() .. " " .. param)
		end
	end
	return table.concat(msg)
end

--Format all attributes of a field as text
local function log_field(field, padding)
	padding = (padding or "") .. "    "
	return field:get_type():get_full_name() .. " " .. field:get_name()
		.. "\n" .. padding .. "Declaring Type: " .. field:get_declaring_type():get_full_name()
		.. "\n" .. padding .. "Offset from Base: " .. field:get_offset_from_base()
		.. "\n" .. padding .. "Offset from FieldPtr: " .. field:get_offset_from_fieldptr()
		.. "\n" .. padding .. "Flags: " .. tostring(field:get_flags())
		.. "\n" .. padding .. "Is Static: " .. tostring(field:is_static())
		.. "\n" .. padding .. "Is Literal: " .. tostring(field:is_literal())
end

--Format all attributes of a field as text
local function log_typedef(td, padding)
	padding = (padding or "") .. "\n    "
	return td:get_full_name()
		.. padding .. "Size: " .. td:get_size()
		--..  padding .. "Runtime Type: " .. tostring(td:get_runtime_type())
		..  padding .. "Is Enum: " .. tostring(td:is_a("System.Enum"))
		..  padding .. "Is Component: " .. tostring(td:is_a("via.Component"))
		..  padding .. "Is ValueType: " .. tostring(td:is_value_type())
		..  padding .. "Is UserData: " .. tostring(td:is_a("via.UserData"))
		..  padding .. "Is by Ref: " .. tostring(td:is_by_ref())
		..  padding .. "Is Pointer: " .. tostring(td:is_by_ref())
		..  padding .. "Is Primitive: " .. tostring(td:is_primitive())
		..  padding .. "Is Generic Type: " .. tostring(td:is_generic_type())
		..  padding .. "Is Generic Type Definition: " .. tostring(td:is_generic_type_definition())
end

--Display Translation, Rotation and Scale as text
local function log_transform(pos, rot, scale, xform)
	if obj then 
		pos = pos or xform:call("get_Position")
		rot = rot or xform:call("get_Rotation")
		scale = scale or xform:call("get_LocalScale")
	end
	if not pos or not rot or not scale then return "nil" end
	return "[" .. tostring(pos.x) .. ", " .. tostring(pos.y) .. ", " .. tostring(pos.z) .. "]\n"
		.. "[" .. tostring(rot.x) .. ", " .. tostring(rot.y) .. ", " .. tostring(rot.z) .. ", " .. tostring(rot.w) .. "]\n"
		.. "[" .. tostring(scale.x) .. ", " .. tostring(scale.y) .. ", " .. tostring(scale.z) .. "]"
end

--Returns a string of a lua table as you would see it in JSON:
function json.log(value, remove_arraykeys, remove_quotes, key, layer)
	
	if (value == nil) then 
		return "null" 
	end
	
	local msg, indent = {""}, {""}
	layer = layer or 0
	if layer > 0 then 
		for i=1, layer do 
			indent[#indent+1] = "	"
		end
	end
	indent = table.concat(indent)
	
	if value ~= nil then 
		if type(value) == "table" then
			
			local is_empty = (next(value) == nil)
			local is_arr = isArray(value)
			
			table.insert(msg, (key and ("\"" .. tostring(key) .. "\": ") or "") .. ((is_empty and "[],") or (is_arr and "[") or "{"))
			
			if not is_empty then 
				for tbl_key, tbl_val in orderedPairs(value) do
					if type(tbl_val)=="table" then
						table.insert(msg, "\n" .. json.log(tbl_val, remove_arraykeys, remove_quotes, (not is_arr or not remove_arraykeys) and tbl_key, layer + 1))
					else
						local is_string = (type(tbl_val)=="string") and "\"" or ""
						table.insert(msg,  "\n" .. indent .. "	" .. ((not is_arr or not remove_arraykeys) and ("\"" .. tostring(tbl_key) .. "\":	") or "") .. is_string .. tostring(tbl_val) .. is_string .. ",")
					end
				end
				if not is_arr then 
					table.insert(msg, "\n" .. indent .. "},")
				else
					table.insert(msg, "\n" .. indent .. "],")
				end
			end
		else
			local is_string = (type(value)=="string") and "\"" or ""
			table.insert(msg,  "\"" .. tostring(key or "") .. "\":	" .. is_string .. tostring(value) .. is_string .. ",")
		end
	else
		table.insert(msg, "null")
	end
	
	table.insert(msg, 1, indent)
	msg = table.concat(msg)
	
	if remove_quotes then
		msg = msg:gsub("\"", "")
	end
	
	return msg
end

--Generic text logger for most variables, indentation is meant to work with ImguiTables but also useful for printing/debugging:
local function log_value(value, value_name, layer_limit, layer, verbose, return_over_print)
	
	local msg = {""}
	local indent = (layer == 0 and {"	   "}) or {""}
	layer = layer or 0
	layer_limit = layer_limit or 1 -- "-1" means no limit
	
	if layer > 0 then 
		for i=1, layer do 
			table.insert(indent, "	")
		end
	end
	indent = table.concat(indent)
	
	if value ~= nil then 
		local str_val = tostring(value)
		local val_type = type(value)
		if val_type == "string" then 
			table.insert(msg, str_val)
		elseif val_type == "table" or str_val:sub(1,15) == "sol.std::vector" then 
			local is_vec = (val_type ~= "table")
			if (not is_vec and (next(value) ~= nil)) or value[1] then
				local len = 0
				local is_array = is_vec or (value[1] ~= nil and isArray(value))
				if is_array then
					if verbose then 
						table.insert(msg, (is_vec and " [vector] " or " ") .. " [" .. #value .. " elements] ") 
					end
					if (layer < layer_limit) or (layer_limit == -1) then
						for i, val in ipairs(value) do 
							local addition = "\n" .. log_value(val, i, layer_limit, layer + 1, verbose, true)
							len = len + addition:len()
							if (layer_limit < 2) and (len > 512) then break end
							table.insert(msg, addition)
						end
					end
				elseif (not value.__pairs or pcall(value.__pairs, value)) then 
					if verbose then 
						local name = value.name or (value._ and (value._.Name or value._.name)) or (value.obj and log_value(value.obj, nil, 0, 0, verbose, true)) or ""
						table.insert(msg, " [dictionary] " .. name .. " (" .. get_table_size(value) .. " elements) ")
					end
					if (layer < layer_limit) or (layer_limit == -1) then
						for key, val in orderedPairs(value) do  
							local addition = "\n" .. log_value(value[key], tostring(key), layer_limit, layer + 1, verbose, true)
							len = len + addition:len()
							if (layer_limit < 2) and (len > 512) then break end
							table.insert(msg, addition)
						end
						value.__orderedIndex = nil
					end
				else 
					table.insert(msg, str_val)
				end
			else 
				table.insert(msg, "{}")
			end
		elseif can_index(value) then
			local mt = getmetatable(value)
			if type(mt.__type) == "table" and mt.__type.name and not value.x then --string.find(str_val, "sdk::") and not str_val:find(":vector<") then 
				local typename = mt.__type.name
				if typename == "sdk::RETypeDefinition" then
					table.insert(msg, log_typedef(value, indent))
				elseif typename == "sdk::REMethodDefinition" then
					table.insert(msg, log_method(value, indent))
				elseif typename == "sdk::REField" then
					table.insert(msg, log_field(value, indent))
				elseif typename == "glm::mat<4,4,float,0>" then
					table.insert(msg, (verbose and "[matrix]" or "") .. mat4_to_string(value, indent .. "	"))
				elseif typename == "api::sdk::ValueType" or typename == "sdk::SystemArray" or sdk.is_managed_object(value) then
					local og_value = value
					if val_type == "number" then  
						value = sdk.to_managed_object(value) 
					end 
					local typedef = value:get_type_definition()
					if not typedef then return "" end
					msg = {typedef:get_full_name()}
					if msg[1] == "via.GameObject" and value:call("get_Valid") then
						msg[1] = value:call("get_Name")
					elseif typedef:is_a("via.Component") then
						local gameobj = get_GameObject(value)
						if gameobj then
							table.insert(msg, 1, " " .. gameobj:call("get_Name") .. " -> ")
						end
					end
					if val_type ~= "number" then 
						table.insert(msg, " @ " .. tostring(value:get_address()))
					else 
						table.insert(msg, " @ " .. tostring(og_value))
					end
				else
					imgui.text_colored((str_val:find("REManagedObject") and "Broken REManagedObject") or ("Missing type: " .. typename), 0xFF0000FF)
					table.insert(msg, str_val)
				end
			elseif string.find(str_val, "mat<4") then --value[0] and 
				table.insert(msg, (verbose and "[matrix]" or "") .. mat4_to_string(value, indent .. "	"))
			elseif value.x and string.find(str_val, "sol%.glm::") then --and not value.call then --via.Transforms getting in here??
				table.insert(msg, vector_to_string(value))
			else
				table.insert(msg, str_val)
			end
		else 
			table.insert(msg, str_val)
		end
	else 
		table.insert(msg, "nil")
	end
	
	if value_name then 
		table.insert(msg, 1, tostring(value_name) .. ": ")
	end
	
	--if #msg > 0 then
		table.insert(msg, 1, indent)
	--end
	
	msg = table.concat(msg)
	
	if return_over_print then 
		return msg, msg:len()
	else 
		log.info(msg)
	end
end

--Global printer version of above:
function logv(value, value_name, layer_limit, layer, verbose)
	return log_value(value, value_name, layer_limit, layer, verbose, true)
end

--ChainNode class for handling Chain Bone Nodes -------------------------------------------------------------------------------------------
local ChainNode = {
	o,
	new = function(self, args, o)
		o = o or {}
		self.__index = self  
		o.group_obj = args.group_obj
		o.idx = args.idx
		o.name = args.name or " "
		local try, hash = pcall(sdk.call_object_func, o.group_obj.group, "getNodeJointNameHash", o.idx)
		if try then 
			o.hash = hash
			o.pos = o.group_obj.group:call("getNodePosition", o.idx)
			o.joint = o.group_obj.xform:call("getJointByHash", o.hash)
			if o.joint then o.name = o.joint:call("get_Name") end
		end
		
		return setmetatable(o, self)
	end,
	
	update = function(self)
		self.pos = self.group_obj.group:call("getNodePosition", self.idx)
		if isMHR then 
			self.pos = self.pos + self.group_obj.anim_object.xform:call("get_Position") 
		end
		if self.group_obj.show_positions then 
			draw.world_text(self.name, self.pos, 0xFF00FF00) 
		end
	end,
}

--ChainGroup class for handling Chain Groups -------------------------------------------------------------------------------------------
local ChainGroup = {

	uses_customsettings = (statics.tdb_ver >= 69),
	
	new = function(self, args, o)
	
		local function read_uint64(ptr)
			local value_type = sdk.to_valuetype(ptr, "System.UInt64")
			return value_type.mValue
		end

		local function read_uint32(ptr)
			local value_type = sdk.to_valuetype(ptr, "System.UInt32")
			return value_type.mValue
		end

		local function get_setting_id(group)
			local setting = group:read_qword(0x18)
			if setting == 0 then return end

			local data = read_uint64(setting + 0x20)
			if data == 0 then return end

			local settingdata = read_uint64(data + 0x8)
			if settingdata == 0 then return end

			return read_uint32(settingdata + 0x18) 
		end
		
		o = o or {}
		self.__index = self  
		o.group = args.group
		o.xform = args.xform
		o.anim_object = args.anim_object or held_transforms[o.xform] or GameObject:new_AnimObject{xform=o.xform}
		o.chain = args.chain or o.anim_object.components_named.Chain or o.chain
		o.settings_ref = o.group:read_qword(0x18)
		o.settings = args.settings
		o.all_settings = args.all_settings
		o.terminal_name_hash = o.group:call("get_TerminalNameHash")
		o.node_count = args.node_count or o.group:call("get_NodeCount")
		o.terminal_name = args.terminal_name or " "--o.xform:call("getJointByHash", o.terminal_name_hash):call("get_Name")
		o.show_positions = args.show_positions or false
		o.do_blend = args.do_blend or false
		o.blend_ratio = args.blend_reset_ratio or 0.5
		o.nodes = {}
		for i=1, o.node_count do 
			table.insert(o.nodes, ChainNode:new{group_obj=o, idx=i-1})
			if i == o.node_count then  o.terminal_name = o.nodes[#o.nodes].name end
		end
		o.settings_id = get_setting_id(o.group)
		
        return setmetatable(o, self)
	end,
	
	change_custom_setting = function(self, blend_id)
		if not (self.uses_customsettings) then return end
		local chain_setting = self.all_settings[self.settings_id] or sdk.create_instance("via.motion.ChainCustomSetting")
		if chain_setting then 
			chain_setting:call(".ctor")
			blend_id = blend_id or self.settings_id
			if (self.settings_id ~= blend_id and (self.chain:call("blendSetting", self.settings_id, blend_id, self.blend_ratio, chain_setting)) or (self.settings_id == blend_id and self.chain:call("copySetting", self.settings_id, chain_setting))) then
				chain_setting = chain_setting:add_ref()
				self.group:write_byte(0x20, 1) --set to use custom settings
				pcall(sdk.call_object_func, self.group, "set_CustomSetting", chain_setting) --works overall but crashes if not in pcall()
				self.all_settings[self.settings_id] = chain_setting
				self.settings = chain_setting
			end
		end
	end,
	
	update = function(self, do_deferred)
		if do_deferred then
			on_frame_calls[self.group] = on_frame_calls[self.group] or {}
			table.insert( on_frame_calls[self.group], {lua_object=self, method=self.update} )
		else
			local pos_2d = {}
			for i, node in ipairs(self.nodes) do
				node:update()
				--if node.pos then
					table.insert(pos_2d, draw.world_to_screen(node.pos))
					if #pos_2d > 1 and pos_2d[i-1] and pos_2d[i] then 
						--if isDMC or isRE2 then
						--	on_frame_calls[self.group] = on_frame_calls[self.group] or {} --every game has its own stupid rules about this I swear...
						--	table.insert( on_frame_calls[self.group], { lua_func=draw.line, args=table.pack(pos_2d[i-1].x, pos_2d[i-1].y, pos_2d[i].x, pos_2d[i].y, 0xFF00FF00) })
						--else
							draw.line(pos_2d[i-1].x, pos_2d[i-1].y, pos_2d[i].x, pos_2d[i].y, 0xFF00FF00)
						--end
						--if parent_vec2 then draw.line(parent_vec2.x, parent_vec2.y, this_vec2.x, this_vec2.y, 0xFF00FFFF)  end
					end
				--end
			end
		end
	end,
}

--REMgdObj and its functions ----------------------------------------------------------------------------------------------------
--Scan a typedef for the best method to check the managed object's name
local function get_name_methods(ret_type, propdata, do_items)
	
	local ret_typename = ret_type:get_full_name()
	propdata = propdata or metadata_methods[ret_typename] or get_fields_and_methods(ret_type)
	local search_terms = {"Name", "Path", "Comment", "Message", "Title", "Description", "Id"} --, "All", "Numbers"
	local name_methods = (not do_items and propdata.name_methods) or (do_items and propdata.item_name_methods)
	local num_strings = 0
	--log.debug("########## " .. ret_typename)
	
	if not name_methods then
		name_methods = {}
		local uniques = {}
		for i, search_term in ipairs(search_terms) do
			if i == #search_terms or i == 1 or num_strings > 0 then
				for f, field_name in pairs(propdata.field_names) do 
					--log.debug(field_name)
					if not uniques[field_name] then
						local field = propdata.fields[field_name]
						local ftype = field:get_type()
						local is_resource = ftype:get_name():find("Holder$")
						local is_str = ftype:is_a("System.String")
						local is_guid = ftype:is_a("System.Guid")
						
						local is_enum = i==#search_terms and ftype:is_a("System.Enum")
						if i==1 and is_str then num_strings = num_strings + 1 end
						
						--if (is_enum or is_resource or (is_str and ((field_name:sub(-4) == search_term)))) then --or (ftype:is_primitive() and i==4) then
						if (is_enum or is_resource or (is_str and ((field_name:sub(-4) == search_term)))) or (is_guid and field_name:find(search_term)) then
							uniques[field_name] = field
							table.insert(name_methods, field_name)
							if i == #search_terms then goto exit end
						end
					end     
				end
				for m, name in pairs(propdata.method_names) do
					local method = propdata.methods[name]
					if not uniques[name] and method:get_num_params() == 0 then
						local mtype = method:get_return_type()
						local is_resource = mtype:get_name():find("Holder$")
						local is_str = mtype:is_a("System.String")
						local is_guid = mtype:is_a("System.Guid")
						local is_enum = i==#search_terms and mtype:is_a("System.Enum")
						if i==1 and is_str then num_strings = num_strings + 1 end
						
						--if (name:find("[Gg]et") == 1 or name:find("[Hh]as") == 1) and (is_enum or is_resource or (is_str and ((name:sub(-4) == search_term)))) then --or (mtype:is_primitive() and i==4) then
						if (name:find("[Gg]et") == 1 or name:find("[Hh]as") == 1) and ((is_enum or is_resource or (is_str and ((name:sub(-4) == search_term)))) or (is_guid and name:find(search_term))) then
							uniques[name] = method
							table.insert(name_methods, name)
							if i == #search_terms then goto exit end
						end
					end
				end
			end
		end
		::exit::
	end
	if do_items then 
		propdata.item_name_methods = name_methods
	else
		propdata.name_methods = name_methods
	end
	return name_methods
end

--Collect and return all applicable fields, methods, counts etc from a managed object and store them in a dictionary
get_fields_and_methods = function(typedef)
	
	local td_name = typedef:get_full_name()
	local propdata = {
		methods = {},
		method_names = {},
		method_full_names = {},
		functions = {},
		fields = {},
		field_names = {},
		clean_field_names = {},
		getters = {},
		setters = {},
		counts = {},
		simple_methods = {},
	}
	
	local td = typedef
	local unique_methods = {}
	while td ~= nil do
		for i, field in ipairs(td:get_fields()) do 
			--if not field:is_static() then
				local field_name = field:get_name()
				if not propdata.fields[field_name] then
					table.insert(propdata.field_names, field_name)
					propdata.fields[field_name] = field
					propdata.clean_field_names[(field_name:match("%<(.+)%>") or field_name):lower()] = i
				end
			--end
		end
		local type_unique_methods = {}
		for i, method in ipairs(td:get_methods()) do 
			local param_types = method:get_param_types()
			local method_name = method:get_name()
			local method_full_name = method:get_name() .. "("
			for i, param_type in ipairs(param_types) do
				method_full_name = method_full_name .. (((i ~= 1) and " ") or "") .. param_type:get_full_name() .. (((i ~= #param_types) and ",") or "")
			end
			method_full_name = method_full_name .. ")"
			
			local no_dot_name = method_name:gsub("%.", "")
			local type_unique_name = no_dot_name 
			local ctr = 0
			while type_unique_methods[type_unique_name] do
				ctr = ctr + 1
				type_unique_name = no_dot_name .. ctr
			end
			
			type_unique_methods[type_unique_name] = method
			local unique_name = type_unique_name
			if unique_methods[unique_name] then
				unique_name = unique_name .. "__" .. td:get_name()
			end
			
			unique_methods[unique_name] = method
			propdata.methods[unique_name] = method
			table.insert(propdata.method_names, unique_name)
			propdata.method_full_names[unique_name] = method_full_name
			
			if not propdata.clean_field_names[unique_name:lower()] then
				propdata.functions[unique_name] =
					function(self, args)
						if args then 
							return self._.obj:call(method_full_name, table.unpack(args))
						end
						return self._.obj:call(method_full_name)
					end
				if method:get_num_params() == 0 and (method_name:find("[Gg]et") == 1 or method_name:find("[Hh]as") == 1) then 
					local found_idx = method_name:find("Count") or method_name:find("Num")
					local found_idx = found_idx and ((found_idx == method_name:len()-4) or (found_idx == method_name:len()-2)) and found_idx
					if found_idx then
						propdata.counts[method_name:sub(1, found_idx - 1):sub(4, -1)] = method
					end
				end
			end
		end
		td = td:get_parent_type()
	end
	
	for i, name in ipairs(propdata.method_names) do 
		
		local method = propdata.methods[name]
		local lower_name = name:lower()
		local short_name = name:sub(4, -1)
		local num_params = method:get_num_params()
		local ret_typename = method:get_return_type():get_full_name()
		
		if num_params == 0 and (ret_typename == "System.Void" or (ret_typename == "System.Boolean" and lower_name:find("set")==1)) and not name:find("__") then
			propdata.simple_methods[name] = method
		elseif name:len() > 5 then
			if (num_params == 0 or num_params == 1) and (lower_name:find("get") == 1 or lower_name:find("has") == 1) then 
				if num_params == 1 then 
					if method:get_param_types()[1]:get_full_name():find("Int") then
						for count_name, count_method in pairs(propdata.counts) do 
							if short_name:find(count_name) or count_name:find(short_name) or short_name:find(count_name:gsub("%_", "")) then 
								propdata.counts[short_name] = propdata.counts[short_name] or count_method
								if count_name:find("[Gg]et_?" .. short_name .. "[CN][ou][um]") then
									propdata.counts[short_name] = count_method
									break
								end
							end
						end
						propdata.getters[short_name] = method
					end
				else
					propdata.getters[short_name] = method
				end
			elseif (num_params == 1 or num_params == 2) and lower_name:find("set") == 1 then 
				if num_params == 2 then 
					if method:get_param_types()[1]:get_full_name():find("Int") then 
						for count_name, count_method in pairs(propdata.counts) do 
							if short_name:find(count_name) or count_name:find(short_name) or short_name:find(count_name:gsub("%_", "")) then 
								propdata.counts[short_name] = propdata.counts[short_name] or count_method
								if count_name:find("[Gg]et_?" .. short_name .. "[CN][ou][um]") then
									propdata.counts[short_name] = count_method
									break
								end
							end
						end
						propdata.setters[short_name] = method
					end
				else
					propdata.setters[short_name] = method
				end
			end
		end
	end
	
	propdata.name_methods = get_name_methods(typedef, propdata)
	propdata.item_type = evaluate_array_typedef_name(typedef, td_name)
	if propdata.item_type and propdata.item_type:get_full_name() ~= "" then 
		propdata.item_name_methods = get_name_methods( propdata.item_type, get_fields_and_methods(propdata.item_type), true)
	end
	metadata_methods[td_name] = propdata
	
	return propdata
end

--Get the most appropriate name for a managed object element
get_mgd_obj_name = function(m_obj, o_tbl, idx, only_relevant)
	
	--log.info("checking name for " .. logv(m_obj))
	if type(m_obj)~="userdata" or not m_obj.get_type_definition or not is_valid_obj(m_obj) then return "" end
	o_tbl = o_tbl or m_obj._ or create_REMgdObj(m_obj)
	if not o_tbl then return end
	
	local typedef, name = (o_tbl.is_lua_type and (o_tbl.item_type or o_tbl.ret_type or o_tbl.type)) or (can_index(m_obj) and m_obj.get_type_definition and m_obj:get_type_definition()), nil
	if not typedef then return tostring(m_obj) end
	local td_name = typedef:get_full_name()
	local indexable = can_index(m_obj)
	
	if typedef:is_a("System.Array") or td_name:match("<(.+)>") then --arrays
		name = (o_tbl.elements and o_tbl.elements[1] and (o_tbl.elements[1]:get_type_definition():get_full_name().."["..#o_tbl.elements.."] -- "..get_mgd_obj_name(o_tbl.elements[1]))) or td_name:match("<(.+)>") 
		name = name or (o_tbl.name_full and o_tbl.name_full:gsub("%[%]", "")) or td_name:gsub("%[%]", "")
	elseif o_tbl.skeleton then
		name = o_tbl.skeleton[idx]
	elseif (type(m_obj) == "number") or (type(m_obj) == "boolean") or not can_index(m_obj) then
		name = typedef:get_name()
	elseif indexable and (m_obj.x or m_obj[0]) then
		pcall(function()
			name = (((o_tbl.is_vt or o_tbl.is_obj) and not o_tbl.is_lua_type) and (m_obj:get_type_definition():get_method("ToString()") and m_obj:call("ToString()")))
		end)
		name = name or typedef:get_name()
	elseif typedef:is_a("via.Component") then 
		name = td_name .. ((typedef:is_a("via.Transform") and (" (" .. get_GameObject(m_obj, true) .. ")")) or "")
	elseif typedef:is_a("via.GameObject") then
		try, name = pcall(sdk.call_object_func, m_obj, "get_Name")
		name = try and name
	elseif o_tbl.item_name_methods or o_tbl.name_methods then
		local fields = o_tbl.fields or (o_tbl.item_type and metadata_methods[o_tbl.item_type:get_full_name()].fields)
		local methods = o_tbl.methods or (o_tbl.item_type and metadata_methods[o_tbl.item_type:get_full_name()].methods)
		for i, fm_name in ipairs(o_tbl.item_name_methods or o_tbl.name_methods) do
			if fields and fields[fm_name] then
				try, name = pcall(m_obj.get_field, m_obj, fm_name)
			else
				try, name = pcall(sdk.call_object_func, m_obj, fm_name)
			end
			name = try and (name ~= "") and name
			if name ~= nil then 
				if type(name) == "number" then
					local ret_type = (fields and fields[fm_name] and fields[fm_name]:get_type()) or (methods and methods[fm_name] and methods[fm_name]:get_return_type()) 
					if ret_type then
						local enum, value_to_list_order, enum_names = get_enum(ret_type)
						name = enum_names[ value_to_list_order[name] ]
					else
						ret_type = tostring(ret_type)
					end
				end
				if type(name)=="userdata" and type(name.add_ref)=="function" then 
					--add_resource_to_cache(name, nil, o_tbl) --enabling this adds way too many cached resources
					if name:get_type_definition():is_a("System.Guid") then
						name = static_funcs.guid_method:call(nil, m_obj)
					else
						name = name:call("ToString()"):match("^.+%[@?(.+)%]") --fix resources
					end
				end
				if type(name)=="string" then
					if name:find("%.pfb$") then 
						add_pfb_to_cache(name)
					end
					break 
				end
				
				--name = tostring(name)
			end
		end
	end
	
	if not name and not only_relevant then 
		if o_tbl.msg or typedef:is_a("System.Guid") then
			name = o_tbl.msg or static_funcs.guid_method:call(nil, m_obj)
			name = (name ~= "") and name:gsub("\n.*", "...") or name
		end
		if not name and m_obj:get_type_definition():get_method("ToString()") then
			name = ({pcall(sdk.call_object_func, m_obj, "ToString()")}) ; name = name[1] and name[2] --m_obj:call("ToString()")--
		end
		name = name or m_obj:get_type_definition():get_name()
	end
	--log.info("Name is " .. tostring(name))
	return name or ""
end

--Class for containing fields and properties and their metadata -------------------------------------------------------------------------------------------
local VarData = {
	
	new = function(self, args, o)
		if not (args.get or args.field or args.value) then return end
		
		o = o or {}
		self.__index = self
		
		local o_tbl = args.o_tbl
		local obj = o_tbl.obj
		
		--o.is_VarData = true
		o.ret_type = args.ret_type
		o.name = args.name or args.ret_type:get_name()
		o.full_name = args.full_name or args.ret_type:get_full_name()
		o.field = args.field
		o.get = args.get
		o.set = args.set
		o.count = args.count
		
		o.is_vt = o.ret_type:is_value_type() or nil
		o.is_arr_element = args.is_arr_element
		o.is_sfix = ((o.ret_type:is_a("via.Sfix4") and 4) or (o.ret_type:is_a("via.Sfix3") and 3) or (o.ret_type:is_a("via.Sfix2") and 2) or (o.ret_type:is_a("via.sfix") and 1)) or nil --o.full_name:find("%.[Ss]fix") and 
		--o.ret_type = evaluate_array_typedef_name(o_tbl.type, o_tbl.name_full) or o.ret_type
		rt_name = o.ret_type:get_full_name()
		o.name_methods = (metadata_methods[rt_name] and metadata_methods[rt_name].name_methods) or get_name_methods(o.ret_type, get_fields_and_methods(o.ret_type))
		
		local try, out, example
		o.mysize = (o.get and (o.get:get_num_params() == 1)) and (((o.count and o.count:call(obj)) or (o_tbl.counts and o_tbl.counts.method and o_tbl.counts.method:call(obj))) or 0) or nil
		o.mysize = (type(o.mysize)=="number") and o.mysize or nil
		
		--[[local cnt_mthod = (o.get and (o.get:get_num_params() == 1)) and o.count or (o_tbl.counts and o_tbl.counts.method)
		o.mysize = cnt_mthod and ({pcall(cnt_mthod.call, cnt_mthod, obj)})
		o.mysize = (o.mysize and o.mysize[1] and o.mysize[2]) or (cnt_mthod and 0) or nil]]
		
		if o.mysize then --this whole thing gets so so much more complicated from counting list props as props
			o.value_org = {}
			for i=0, o.mysize-1 do
				if SettingsCache.use_pcall then 
					try, out = pcall(obj.call, obj, o.full_name, i)
				else
					try, out = true, obj:call(o.full_name, i)
				end
				if try and (out ~=nil) then
					example = example or out
					o.is_obj = o.is_obj or (not o.is_lua_type and (not o.is_vt and sdk.is_managed_object(example))) or nil
					table.insert(o.value_org, (o.is_obj and out:add_ref()) or out)
				end
			end
		elseif o.field then 
			if SettingsCache.use_pcall then
				try, out = pcall(o.field.get_data, o.field, obj)
			else
				try, out = true, o.field:get_data(obj)
			end
		else
			if args.value then 
				try, out = true, args.value
			elseif SettingsCache.use_pcall then
				try, out = pcall(obj.call, obj, o.full_name)
			else
				try, out = true, obj:call(o.full_name)
			end
		end
		
		if example == nil then 
			example = try and out
		end
		
		o.value_org = o.value_org or example
		o.value = o.value_org
		
		if example ~= nil then --need one example before can start updating
			o.can_index = can_index(example)
			o.is_lua_type = is_lua_type(o.ret_type, example) --or type(example)=="boolean"
			o.is_vt = not o.is_lua_type and (not not (tostring(example):find("::ValueType"))) or o.is_vt
			o.is_obj = (not o.is_lua_type and (not o.is_vt and sdk.is_managed_object(example))) or nil
			if type(o.is_lua_type)=="string" then
				o.is_mat = o.is_lua_type=="mat" or nil
				o.is_pos = o.is_lua_type=="vec" and ((o.name:find("[Pp]os") or o.name:find("ranslat")) and 1 or true) or nil
				o.is_rot = o.is_lua_type=="qua" or (o.is_lua_type == "vec" and (o.name:find("[Ee]uler") and true)) or nil
				o.is_pos = not o.is_rot and o.is_pos or nil
				o.is_scale = o.is_pos and not not o.name:find("[Ss]cale") or nil
				o.is_local = (o.is_pos or o.is_mat) and (not not o.name:find("[Ll]ocal") or ((o.is_mat and example[3] or example):length() < 1.0)) or nil
			elseif o.is_obj and o.ret_type:get_full_name():find("ResourceHolder") then
				o.is_res = true
			end
			o.array_count = o.is_obj and example:call("get_Count")
			o.item_type = o.array_count and evaluate_array_typedef_name(example:get_type_definition())
			if o.item_type and o.item_type:get_full_name() == "System.Object" then 
				o.item_type = nil
			end
			if o.is_obj then 
				example = example:add_ref()
			end
			local odc_key = logv(obj) .. " " .. o.name
			o.freeze = old_deferred_calls[odc_key] and old_deferred_calls[odc_key].vardata and old_deferred_calls[odc_key].vardata.freeze or nil -- and old_deferred_calls[odc_key].vardata
			if o.freeze then 
				o = merge_tables(old_deferred_calls[odc_key].vardata, o)
			end
			o.had_example = true
		end
		o.is_vt = (o.is_vt and o.ret_type:get_method("Parse(System.String)") and "parse") or o.is_vt
		
		if o.ret_type:is_a("System.Single") or o.ret_type:is_a("via.vec3") or o.ret_type:is_a("via.vec4") or o.ret_type:is_a("via.Quaternion") or o.ret_type:is_a("via.mat4") or o.is_sfix then
			SettingsCache.increments[rt_name] = SettingsCache.increments[rt_name] or {}
			o.increment = SettingsCache.increments[rt_name].increment or 0.01
			--if o.increment == 0.0 then o.increment = 0.01 end
			SettingsCache.increments[rt_name].increment = o.increment
		end
		
		--o.is_sfix = o.ret_type:is_a("via.sfix") or nil
		
		--[[if (type(o.value_org)=="table") and o_tbl.counts and o_tbl.counts.method and o_tbl.xform and o_tbl.counts.method:get_name():find("Joint") then
			skeleton = o_tbl.xform._.skeleton or lua_get_system_array(o_tbl.xform:call("get_Joints") or {}, nil, true)
			if skeleton and skeleton[1].call then  for i=1, #skeleton do skeleton[i] = skeleton[i]:call("get_Name") end end --set up a list of bone names for arrays relating to bones
			if skeleton and #skeleton == #o.value_org then -- (math.floor(#skeleton / 2) <= #o.value_org) then --((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj))
				if (#skeleton < ((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj))) then
					for i=1, (((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj)) - #skeleton) do 
						table.insert(skeleton, o.ret_type:get_full_name())
					end
				end
				o.skeleton = skeleton
			end
			o_tbl.xform._.skeleton = skeleton --keep a copy on the xform, without necessarily turning it into a REMgdObj 
		end]]
		
		if o.field and o.value_org then
			if o.field and (o.name == "_entries" or o.name == "mSlots") then
				o_tbl.elements, o_tbl.element_names  = {}, {}
				local key_type, value_type
				for i, element in ipairs(lua_get_system_array(o.value_org, nil, true)) do
					if element.get_field then
						element = element:add_ref()
						local key, value = element:get_field("key"), element:get_field("value")
						if key ~= nil then   --populate dictionaries:
							if type(key)=="number" then 
								if sdk.is_managed_object(key) then 
									key = sdk.to_managed_object(key) 
								else
									key_type = key_type or element:get_type_definition():get_field("key"):get_type()
									if key_type:is_a("System.Enum") then
										local enum, value_to_list_order, enum_names = get_enum(key_type)
										key = enum_names[ value_to_list_order[key] ]
									end
								end
							end
							key = (type(key)=="string" and key) or (type(key)=="userdata" and (key:call("get_Name()") or key:call("ToString()")) or tostring(key))
							if key then
								table.insert(o_tbl.elements, value)
								table.insert(o_tbl.element_names, key)
							end
						else --populate HashSets:
							value_type = value_type or element:get_type_definition():get_field("value"):get_type()
							table.insert(o_tbl.elements, value)
							table.insert(o_tbl.element_names, value_type:get_name())
						end
					end
				end
				--o_tbl.is_lua_type = o.is_lua_type
				o_tbl.mysize = o_tbl.elements and #o_tbl.elements
			elseif o.array_count and not o_tbl.elements and o_tbl.name_full:find("Collections%.Generic") then
				o.linked_array = o_tbl
				o_tbl.item_type = sdk.find_type_definition(o.ret_type:get_full_name():gsub("%[%]", ""))
				o_tbl.elements, o_tbl.element_names, o_tbl.item_data = {}, {}, {}
				for i, element in ipairs(lua_get_system_array(o.value_org, true)) do --
					o_tbl.elements[i] = element:get_field("mValue") or element
					o_tbl.element_names[i] = element:get_type_definition():get_name()
				end
			end
		end
		
		return setmetatable(o, self)
	end,
	
	get_org_value = function(self, element_idx)
		if element_idx then 
			return self.value_org[element_idx]
		else
			return self.value_org
		end
	end,
	
	set_freeze = function(self, freeze_value, element_idx)
		if element_idx then 
			self.freezetable = self.freezetable or {}
			self.freezetable[element_idx] = freeze_value
		else
			self.freeze = freeze_value
		end
	end,
	
	update_item = function(self, o_tbl, index)
	
		local try, out
		local obj = o_tbl.obj
		local excepted = not self.field and (not not (SettingsCache.exception_methods[o_tbl.name_full] and SettingsCache.exception_methods[o_tbl.name_full][self.name]))
		
		if SettingsCache.use_pcall then
			if self.field then
				try, out = pcall(self.field.get_data, self.field, obj)
			elseif excepted and SettingsCache.show_all_fields then
				try, out = pcall(obj.call, obj, self.full_name, index or 0)
			elseif index then
				try, out = pcall(obj.call, obj, self.full_name, index)
			else
				try, out = pcall(obj.call, obj, self.full_name)
			end
		else
			if self.field then
				out = self.field:get_data(obj)
			elseif excepted and SettingsCache.show_all_fields then
				out = obj:call(self.full_name, 0)
			elseif index then
				out = obj:call(self.full_name, index)
			else
				out = obj:call(self.full_name)
			end
		end
		
		if try or not SettingsCache.use_pcall then 
			if out ~= nil then
				if self.is_obj or (self.is_vt and not self.is_lua_type) then -- 
					
					if self.is_obj then 
						out = out:add_ref()
						self.array_count = (self.array_count and out:call("get_Count")) or self.array_count
					end
					local old_value = (index and self.cvalue and self.cvalue[#self.value+1]) or (not index and self.cvalue) or nil
					if (old_value ~= nil) and (old_value ~= out) and metadata[old_value]  then
						metadata[old_value] = nil --clear old metadata for values being replaced
					end
				end
				if index then
					table.insert(self.value, out)
				else
					self.value = out
				end
				if self.is_pos and (not o_tbl.pos or (self.is_pos==1 and o_tbl.pos[2]~=1)) then 
					o_tbl.pos = {out, self.is_pos}
				end
			end
			return true
		elseif excepted then
			return false
		else
			SettingsCache.exception_methods[o_tbl.name_full] = SettingsCache.exception_methods[o_tbl.name_full] or {} 
			SettingsCache.exception_methods[o_tbl.name_full][self.name] = true
			return true --one chance to try with a param
		end
	end,
	
	update_field = function(self, o_tbl, forced_update)
		
		local obj = o_tbl.obj
		local is_obj = self.is_obj or self.is_vt
		
		if not is_obj or (forced_update or self.update) then 
			if self:update_item(o_tbl) then
				self.cvalue = self.value
				if (self.value ~= nil) and not self.is_lua_type and is_obj then
					obj:__set_owner(self.value)
				end
				--self.value = nil
			end
			self.update = nil
		end
	end,

	update_prop = function(self, o_tbl, idx, forced_update)
		local obj = o_tbl.obj
		local is_obj = self.is_obj or self.is_vt
		if is_obj and self.cvalue and not o_tbl.is_folder and random(25) then --set owner
			if not pcall(function() 
				if self.element_names then
					for i, cv in ipairs(self.cvalue) do 
						obj:__set_owner(cv)
					end
				else
					obj:__set_owner(self.cvalue)
				end
			end) then
				log.error("Error updating property")
				--testerr2 = {self, obj, o_tbl, obj.__set_owner}
			end
		end
		local should_update_cvalue = (forced_update or self.update) or (self.cvalue == nil)
		
		if not is_obj or should_update_cvalue then
			
			if self.get:get_num_params() == 0 then 
				if self:update_item(o_tbl) then
					if should_update_cvalue and (self.value ~= nil) then 
						self.cvalue = self.value
					end
				else
					table.remove(o_tbl.props, idx)
					log.info("Removed field/prop " .. self.name .. " from " .. o_tbl.name)
				end
				
			elseif self.get:get_num_params() == 1 then --and (forced_update or o_tbl.keep_updating or (self.mysize and self.mysize == 1) or math.random(1, 5) == 1) then
				
				should_update_cvalue = should_update_cvalue or (#self.value ~= #self.cvalue)
				self.mysize = self.mysize or (self.count and self.count:call(obj)) or (o_tbl.counts and o_tbl.counts.method and o_tbl.counts.method:call(obj)) or 0
				self.mysize = (type(self.mysize)=="number") and self.mysize or 0
				if should_update_cvalue and (self.mysize < 25) or random(3) then
					if o_tbl.item_type and self.ret_type:get_full_name() == "System.Object" then --fix props with generic System.Object types if the parent MgdObj has the real ret type
						self.ret_type = o_tbl.item_type
						self.name_methods = get_name_methods(self.ret_type)
					end
					self.value = {}
					for j=0, (self.mysize and self.mysize-1) or 0 do 
						if not self:update_item(o_tbl, j) then 
							table.remove(o_tbl.props, idx)
							log.info("Removed field/prop " .. self.name .. " from " .. o_tbl.name)
							goto continue
						end
					end
					self.cvalue = ((should_update_cvalue and (self.value[1] ~= nil)) and self.value) or self.cvalue or self.value
					self.mysize = #self.cvalue
					if not self.element_names then
						self.element_names = {}
						for i, item in ipairs(self.value) do
							table.insert(self.element_names, get_mgd_obj_name(item, self, i))
						end
					end
					if self.name == "_Item" then --populate SystemArrays
						o_tbl.item_type = self.ret_type
						o_tbl.elements = self.cvalue
						o_tbl.mysize = self.mysize
						if (not o_tbl.item_type or not o_tbl.element_names) then
							o_tbl.element_names = self.element_names
						end
						o_tbl.is_lua_type = self.is_lua_type
					end
					o_tbl.item_data = o_tbl.item_data or {}
				end
			end
			::continue::
			self.update = nil
		end
	end,
}

--Class that supports indexable managed objects by constructing sub tables of all their important attributes and updating them ------------------------------
local REMgdObj = {
	
	__types = {},
	
	__new = function(self, obj, used_props, o) 
		
		if not obj or type(obj) == "number" or not can_index(obj) or not obj.get_type_definition then
			log.info("REMgdObj Failed step 1")
			return 
		end
		
		local o = o or metadata[obj] or {}
		self.__index = self
		
		local try, otype = pcall(obj.get_type_definition, obj)
		local is_vt = (try and otype and otype:is_value_type()) or tostring(obj):find("::ValueType") or nil
		
		if not try or not otype or (not is_vt and not is_valid_obj(obj)) or not pcall(obj.call, obj, "get_Type") then 
			log.info("REMgdObj Failed step 2")
			return 
		end
		
		local do_all_props = not used_props
		local o_tbl = {
			is_vt = (is_vt and otype:get_method("Parse(System.String)") and "parse") or is_vt,
			obj = obj,
			type = otype,
			name = otype:get_name() or "",
			name_full = otype:get_full_name() or "",
			used_props = {},
			skipped_props = not do_all_props or nil,
			is_arr = otype:is_a("System.Array") or nil,
			--is_ReMgdObj = true,
		}
		log.info("REMgdObj Creating " .. o_tbl.name_full)
		
		if not do_all_props then 
			for i, name in ipairs(used_props) do 
				o_tbl.used_props[name] = i
			end
		end
		
		o_tbl.components = (otype:is_a("via.GameObject") and lua_get_system_array(obj:call("get_Components"), true)) or nil
		if otype:is_a("via.Component") or o_tbl.components then 
			o_tbl.is_component = (otype:is_a("via.Transform") and 2) or (not o_tbl.components) or nil
			o_tbl.gameobj = o_tbl.is_component and get_GameObject(obj) or (not o_tbl.is_component and obj) or nil
			if not o_tbl.gameobj then return end
			o_tbl.gameobj_name = o_tbl.gameobj:call("get_Name")
			o_tbl.xform = o_tbl.gameobj:call("get_Transform")
			o_tbl.folder = o_tbl.gameobj:call("get_Folder")
			if o_tbl.is_component  == 2 then
				o_tbl.parent = o_tbl.xform:call("get_Parent")
				o_tbl.children = lua_get_enumerator(o_tbl.xform:call("get_Children"), o_tbl)
			end
			if o_tbl.components then
				for i, component in ipairs(o_tbl.components) do
					o[component:get_type_definition():get_name()] = component
				end
			end
			o_tbl.key_hash = hashing_method(get_gameobj_path(o_tbl.gameobj) .. o_tbl.name_full)
		elseif otype:is_a("via.Folder") then
			o_tbl.parent = obj:call("get_Parent")
			o_tbl.children = lua_get_enumerator(obj:call("get_Children"), o_tbl)
			o_tbl.child_folders = lua_get_enumerator(obj:call("get_Folders"), o_tbl) or {}
			o_tbl.scn_path = read_unicode_string(obj:get_address()+0x38, true)
		end
		
		local propdata = metadata_methods[o_tbl.name_full] or get_fields_and_methods(otype)
		o_tbl.methods = propdata.methods
		o_tbl.fields = next(propdata.fields) and propdata.fields
		
		if o_tbl.fields then
			o_tbl.field_data = {}
			--for name, field in pairs(o_tbl.fields) do
			for i, field_name in ipairs(propdata.field_names) do 
				if do_all_props or o_tbl.used_props[field_name] then
					local field = propdata.fields[field_name]
					o_tbl.field_data[field_name] = VarData:new{
						name=field_name,
						o_tbl=o_tbl,
						field=field, 
						ret_type=field:get_type(),
						index=i,
					}
					o_tbl.used_props[field_name] = get_table_size(propdata.field_names)
				end
			end
		end
		
		--for name, field in pairs(propdata.fields) do
		--	o[name:match("%<(.+)%>") or name] = field:get_data(obj)
		--end
		
		--for name, method in pairs(propdata.functions) do
		--	o[name] = method
		--end
		
		if next(propdata.counts) then 
			local counts = { counts=propdata.counts, counts_names={}, method=(SettingsCache.generic_count_methods[o_tbl.name_full] and otype:get_method(SettingsCache.generic_count_methods[o_tbl.name_full])) }
			local count_method_name = counts.method and counts.method:get_name():sub(4,-1):gsub("Count", "")
			for method_name, method in orderedPairs(propdata.counts) do 
				table.insert(counts.counts_names, method_name)
				counts.idx = (method_name == count_method_name) and #counts.counts_names
			end
			counts.idx = propdata.counts_idx or counts.idx or 1 
			o_tbl.counts = counts
		end
		
		o_tbl.name_methods = propdata.name_methods
		o_tbl.item_type = propdata.item_type
		o_tbl.name_methods = propdata.name_methods
		o_tbl.Name = get_mgd_obj_name(obj, o_tbl)
		
		--initial properties setup:
		if next(propdata.getters) then
			o_tbl.props = {}
			o_tbl.props_named = {}
			local skeleton
			for i, method_name in ipairs(propdata.method_names) do
				if do_all_props or o_tbl.used_props[method_name] then
					if (method_name:find("[Gg]et") == 1 or method_name:find("[Hh]as") == 1) and not method_name:find("__") then --(method_name:find("[Gg]et") == 1 or method_name:find("[Hh]as") == 1)
						if SettingsCache.show_all_fields or not (propdata.clean_field_names[method_name:sub(4, -1):gsub("_", ""):lower()] or propdata.clean_field_names[method_name:sub(4, -1):lower()]) then --is accessed already by a field
							local full_name = propdata.method_full_names[method_name]
							local full_name_method = o_tbl.type:get_method(full_name)
							method_name = method_name:sub(4, -1) 
							if full_name_method and propdata.getters[method_name] and (not SettingsCache.exception_methods[o_tbl.name_full] or not SettingsCache.exception_methods[o_tbl.name_full][method_name]) and not misc_vars.skip_props[method_name] then
								local method = propdata.getters[method_name]
								local prop = VarData:new{
									o_tbl=o_tbl,
									name=method_name, 
									full_name=full_name, 
									get=full_name_method, 
									set=propdata.setters[method_name], 
									count=propdata.counts[method_name], 
									ret_type=method:get_return_type(),
									is_count = not not method_name:find("[CN][ou][um][n]?[t]?$") or nil,
								}
								table.insert(o_tbl.props, prop)
								o_tbl.props_named[prop.name] = prop
								o_tbl.used_props[method_name] = #o_tbl.props
								--if o[method_name] and not bad_obj then
									--re.msg_safe("Prop " .. prop.name .. " name conflict in console object 'bad_obj'!", 1241545)
								--	bad_obj = obj
								--else
								--	o[method_name] = o[method_name] or prop
								--end
							end
						end
					end
				end
			end
		end
		
		o_tbl.do_auto_expand = ((o_tbl.fields or o_tbl.props) and not o_tbl.item_type and not o_tbl.is_arr and o_tbl.name~="Transform" and not o_tbl.name:find("^Wrapped")) or nil --and not o_tbl.is_vt --(o_tbl.is_arr and not o_tbl.elements[1])
		o_tbl.key_hash = o_tbl.key_hash or hashing_method(o_tbl.name_full)
		o_tbl.propdata = propdata
		o._ = o_tbl
		metadata_methods[o_tbl.name_full] = propdata
		
		return setmetatable(o, self)
	end,
	
	--[[
	__new_minimal = function(self, obj, do_minimal, o)
		
		self = self:__new(obj, true)
		if not self then return end
		local o_tbl = self._
		if not o_tbl then return end
		local propdata = o_tbl.propdata
		local obj = o_tbl.obj
		
		for i, method_name in ipairs(propdata.method_names) do
			o_tbl.props = o_tbl.props or {}
			if method_name:find("[Gg]et") == 1 then
				method_name = method_name:sub(4, -1)
				local method = propdata.getters[method_name]
				if method then
					local prop = {name=method_name, get=method, set=propdata.setters[method_name], count=propdata.counts[method_name], ret_type=method:get_return_type(), not_started=true }
					table.insert(o_tbl.props, prop)
				end
			end
		end
		
		for i, prop in ipairs(o_tbl.props) do 
			if prop.get:get_num_params() == 0 then 
				local try, out = pcall(prop.get.call, prop.get, o_tbl.obj)
				if try then 
					self[prop.name] = out
				end
			end
		end
		return self
	end,
	]]
	
	__set_owner = function(self, owned_obj)
		local cv_tbl = metadata[owned_obj] and metadata[owned_obj]._
		if cv_tbl and not cv_tbl.xform and not cv_tbl.child_folders and (cv_tbl ~= self._) then
			cv_tbl.owner = self --((self.get_elements or self._.methods.MoveNext) and self._.owner) or 
		end
	end,
	
	__update = function(self, is_known_valid, forced_update)
		
		if is_known_valid or self._.is_vt or sdk.is_managed_object(self) then
		
			local o_tbl = self._
			if not o_tbl then return end
			
			if o_tbl.is_open and o_tbl.skipped_props then --activate all props
				self._ = create_REMgdObj(o_tbl.obj, o_tbl.keep_alive)
				return
			end
			
			o_tbl.pos = nil
			local propdata = o_tbl.propdata
			local obj = o_tbl.obj
			forced_update = forced_update or o_tbl.keep_updating
			
			--Update owner
			if o_tbl.xform then 
				o_tbl.go = touched_gameobjects[o_tbl.xform] or held_transforms[o_tbl.xform] or o_tbl.go
			elseif o_tbl.owner and o_tbl.owner._ then 
				o_tbl.xform = o_tbl.owner._.xform
				o_tbl.gameobj = o_tbl.gameobj or o_tbl.owner._.gameobj
				o_tbl.gameobj_name = o_tbl.gameobj_name or o_tbl.owner._.gameobj_name
				if not o_tbl.folder and o_tbl.gameobj then 
					o_tbl.key_hash = o_tbl.gameobj and hashing_method(get_gameobj_path(o_tbl.gameobj) .. o_tbl.name_full)
				end
				o_tbl.folder = o_tbl.folder or o_tbl.owner._.folder
			end
			
			--Update Enumerators
			if o_tbl.methods.MoveNext and (o_tbl.elements == nil) then --populate enumerators. This is a dangerous operation so it updates as rarely as possible
				o_tbl.elements, o_tbl.element_names = lua_get_enumerator(obj, o_tbl)
				o_tbl.mysize = #o_tbl.elements
			end
			
			--Update fields
			if o_tbl.fields then
				for field_name, field in pairs(o_tbl.fields) do --update fields every frame, since they are simple
					local fdata = o_tbl.field_data[field_name]
					if fdata.new_self then
						fdata = fdata.new_self
						o_tbl.field_data[field_name] = fdata
					end
					local fname = (field_name:match("%<(.+)%>") or field_name)
					fdata:update_field(o_tbl, forced_update)
				end
			end
			
			--Update loose array vardata:
			if o_tbl.item_data and not o_tbl.is_arr then
				for prop_name, tbl in pairs(o_tbl.item_data) do
					for k, vardata in ipairs(tbl) do
						if vardata.new_self then tbl[k] = vardata.new_self end
						--vardata:update_prop(o_tbl, k-1)
					end
				end
			end
			
			--Update counts
			if o_tbl.counts then
				o_tbl.counts.method = o_tbl.counts.counts[ o_tbl.counts.counts_names[o_tbl.counts.idx] ] or o_tbl.counts.method
				SettingsCache.generic_count_methods[o_tbl.name_full] = (o_tbl.counts.method and o_tbl.counts.method:get_name()) or SettingsCache.generic_count_methods[o_tbl.name_full]
			end
			
			--Update properties
			if o_tbl.props then 
				for i, prop in ipairs(o_tbl.props) do 
					if prop.new_self then
						prop = prop.new_self
						o_tbl.props[i] = prop
						o_tbl.props_named[prop.name] = prop
					end
					prop:update_prop(o_tbl, i, forced_update)
				end
			end
			
			--Fix element names (these may randomly crash the game if collected on-frame, so sometimes it is delayed)
			if o_tbl.elements then 
				if (o_tbl.elements[1] ~= nil) and (not o_tbl.element_names or not o_tbl.element_names[1]) and (not o_tbl.delayed_names or (uptime-o_tbl.delayed_names > 0.66)) then
					o_tbl.element_names = {}
					o_tbl.item_data = {}
					o_tbl.delayed_names = nil
					for i, element in ipairs(o_tbl.elements) do 
						table.insert(o_tbl.element_names, get_mgd_obj_name(element, o_tbl, i))
					end
				end
			end
			
			--Specialty
			if o_tbl.name == "Chain" then
				if forced_update or not o_tbl.cgroups  then 
					o_tbl.cgroups = {}
					local all_settings = {}
					for i = 0, obj:call("getGroupCount") - 1 do 
						table.insert(o_tbl.cgroups, ChainGroup:new { group=obj:call("getGroup", i), xform=o_tbl.xform, all_settings=all_settings } )
					end
				end
				if o_tbl.show_all_joints and o_tbl.cgroups and o_tbl.cgroups[1] then 
					for i, group in ipairs(o_tbl.cgroups) do
						group:update(true)
					end
					o_tbl.last_opened = uptime --prevents deletion
				end
			end
		else
			self._.invalid = true
		end
	end,
}

--Function to initialize REMgdObj, used once at the start of the script
--Binds managed objects to a global dictionary, metadata, which allows them to be indexed like normal tables
--[[add_to_REMgdObj = function(obj)
	log.info("Adding " .. tostring(obj) .. " to REMgdObj")
	local mt = getmetatable(obj)
	local oldIndex = mt.__index
	local oldNewIndex = mt.__newindex
	mt.__index = function(self, key)
		if metadata[self] and metadata[self][key] then
			return metadata[self][key] 
		elseif key ~= "_" then
			return oldIndex(self, key)
		end
	end
	mt.__newindex = function(self, key, value)
		--using "REMgdObj" as the key will call the constructor:
		if key == "REMgdObj" then 
			metadata[self] = REMgdObj:__new(self, value) or {}
		--using "_" as the key will create an attached data table:
		elseif key == "_" then
			metadata[self] = metadata[self] or {}
			metadata[self][key] = value
		else 
			try, out = pcall(oldNewIndex, self, key, value) 
			if not try then
				log.debug(out)
				log.info(out)
			end
		end
	end
end]]


add_to_REMgdObj = function(obj)
	log.info("Adding " .. tostring(obj) .. " to REMgdObj")
	local mt = getmetatable(obj)
	local oldIndex = mt.__index
	local oldNewIndex = mt.__newindex
	mt.__index = function(self, key)
		local try, output = pcall(oldIndex, self, key)
		if try and output ~= nil then return output end
		return metadata[self] and metadata[self][key]
	end
	mt.__newindex = function(self, key, value)
		if key == "REMgdObj" then --using "REMgdObj" as the key will call the constructor
			metadata[self] = REMgdObj:__new(self) or {}
		elseif not pcall(oldNewIndex, self, key, value) then
			metadata[self] = metadata[self] or {}
			metadata[self][key] = value
		end
	end
	REMgdObj.__types[mt.__type.name] = true
	--re.msg_safe("added " .. tostring(mt.__type.name), 124823958)
end
--atr = add_to_REMgdObj

--Function to make an REMgdObj object
create_REMgdObj = function(managed_object, keep_alive, used_props)
	local mt = getmetatable(managed_object)
	if mt and mt.__type then
		if not REMgdObj.__types[mt.__type.name] or managed_object._ == 0 then
			add_to_REMgdObj(managed_object)
		end
		managed_object.REMgdObj = used_props
		if managed_object.__update then
			managed_object:__update(123)
			managed_object._.keep_alive = keep_alive
			return managed_object._
		end
	end
end

--Add BehaviorTrees to REMgdObj:
pcall(function()
	REMgdObj_objects.BHVT = findc("via.motion.MotionFsm2")[1]
	REMgdObj_objects.BHVT = REMgdObj_objects.BHVT and REMgdObj_objects.BHVT:call("getLayer", 0)
end)

--Add identifiers to metatables:
getmetatable(Matrix4x4f.new()).__is_mat4 = true
getmetatable(Vector4f.new(0,0,0,0)).__is_vec4 = 1
getmetatable(Quaternion.new(0,0,0,0)).__is_vec4 = true
getmetatable(Vector3f.new(0,0,0)).__is_vec3 = 1
getmetatable(Vector2f.new(0,0)).__is_vec2 = 1
getmetatable(tds.via_hid_keyboard_typedef).__is_td = true 
getmetatable(scene).__is_obj = true
--getmetatable(REMgdObj_objects.SystemArray).__is_arr = true
getmetatable(REMgdObj_objects.ValueType).__is_vt = true
getmetatable(static_funcs.mk_gameobj).__is_method = true
--getmetatable(REMgdObj_objects.BHVT).__is_bhvt = true

--Create initial REMgdObj:
if REMgdObj_objects then
	for name, object in pairs(REMgdObj_objects) do
		if not pcall(function()
			add_to_REMgdObj(object)
			if object.__type then
				REMgdObj.__types[object.__type.name] = true
			end
		end) then
			log.info(tostring(object) .. " add_to_REMgdObj type error")
		end
	end
	--REMgdObj_objects = nil
	mathex = tds.mathex and (sdk.create_instance(tds.mathex:get_full_name(), true) or sdk.create_instance(tds.mathex:get_full_name(), true))
	mathex = mathex and mathex:add_ref()
	if mathex then 
		create_REMgdObj(mathex, true) 
	end
end


--Functions to display managed objects in imgui --------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--If the gravity gun is running, offers to grab the game object with with an imgui button:
local function offer_grab(anim_object, grab_text, ungrab_text)
	if _G.grab then
		grab_text = grab_text or "Grab" .. (anim_object.same_joints_constraint and "*" or "")
		ungrab_text = ungrab_text or "Ungrab" .. (anim_object.same_joints_constraint and "*" or "")
		
		local is_grabbed = (last_grabbed_object and last_grabbed_object.active and last_grabbed_object.xform == anim_object.xform)
		if imgui.button(is_grabbed and ungrab_text or grab_text) then 
			grab(anim_object.xform, {init_offset=anim_object.cog_joint and anim_object.cog_joint:call("get_BaseLocalPosition")})
			if is_grabbed and forced_mode and (anim_object == current_figure or anim_object == selected) then
				anim_object.init_transform = anim_object.xform:call("get_WorldMatrix")
				--if anim_object.components_named and anim_object.components_named["GroundFixer"] then
				--	anim_object.components_named["GroundFixer"]:call("set_Enabled", false)
				--end
			end
			is_grabbed = not is_grabbed
		end
		return is_grabbed
	end
end

--Displays a resource as a changable combobox and text field inside imgui managed object:
--Should be used when actually handling any resource, after creating it with create_resource()
local function show_imgui_resource(value, name, key_name, data_holder, ret_type)
	local changed, was_changed
	
	if not data_holder.rs_index then --or data_holder.ext == " " then
		imgui.text(logv(data_holder.ret_type))
		data_holder.rs_index, data_holder.path, data_holder.ext = add_resource_to_cache(value, nil, data_holder)
	end
	
	if not data_holder.ext then 
		imgui.text(name .. ": " .. (value and value:call("ToString()") or "") .. " -- Failed to load file extension")
		return 
	end
	
	static_funcs.init_resources()
	
	imgui.push_id(key_name .. name .. "Rs")
		changed, data_holder.show_manual = imgui.checkbox("", data_holder.show_manual)
		if changed and data_holder.show_manual then 
			data_holder.cached_text = (RN[data_holder.ext .. "_resource_names"] and RN[data_holder.ext .. "_resource_names"][data_holder.rs_index]) or ""
		end
		--character/ch/animation/ch09_0500/ch09_0500_Head.jmap
		imgui.same_line()
		was_changed, data_holder.rs_index = imgui.combo(name, data_holder.rs_index, RN[data_holder.ext .. "_resource_names"] or {})
		if was_changed and data_holder.ext ~= " " then 
			data_holder.path = RN[data_holder.ext .. "_resource_names"][data_holder.rs_index]
			data_holder.cached_text = data_holder.show_manual and data_holder.path
			value = RSCache[data_holder.ext .. "_resources"][data_holder.path] or "__nil" --or create_resource("not_set." .. data_holder.ext, data_holder.ret_type) or "__nil"
			value = (value and value[1]) or value
		end
		
		if data_holder.show_manual then
			data_holder.cached_text = data_holder.cached_text or ""
			if data_holder.cached_text == data_holder.path and data_holder.rs_index ~= 1 then 
				if imgui.button(" X ") then 
					RSCache[data_holder.ext .. "_resources"][data_holder.path] = nil
					value = RSCache[data_holder.ext .. "_resources"][data_holder.path]
					--RN[data_holder.ext .. "_resource_names"][data_holder.rs_index] = "[Removed] " .. data_holder.path
					table.remove(RN[data_holder.ext .. "_resource_names"], data_holder.rs_index)
					re.msg("Removed " .. data_holder.path .. " from list of cached " .. data_holder.ext .. " resources")
					data_holder.cached_text = ""
				end
				imgui.same_line()
			elseif data_holder.cached_text ~= "" and data_holder.cached_text ~= data_holder.path and data_holder.cached_text:find("%." .. data_holder.ext) then
				if imgui.button("OK") then
					data_holder.cached_text = (data_holder.cached_text:match("natives\\%w%w%w\\(.+%." .. data_holder.ext ..")") or data_holder.cached_text):gsub("\\", "/")
					local new_resource = create_resource(data_holder.cached_text, (value and value:get_type_definition()) or ret_type or (data_holder and data_holder.ret_type))
					if new_resource then
						data_holder.rs_index, data_holder.path = add_resource_to_cache(new_resource)
						value = new_resource
						was_changed = true
					else
						data_holder.cached_text = "ERROR"
					end
				end
				imgui.same_line()
			else
				imgui.text("      ")
				imgui.same_line()
			end
			changed, data_holder.cached_text = imgui.input_text("Add " .. data_holder.ext, data_holder.cached_text)
		end
	imgui.pop_id()
	return was_changed, value
end

--Reads an editable text box field in imgui
local function show_imgui_text_box(display_name, value, o_tbl, can_set, tkey, is_field)
	
	tkey = tkey or display_name
	o_tbl.cached_text = o_tbl.cached_text or {}
	local str_name = value or ""
	local changed, was_changed
	--[[if value and type(value) ~= "string" then
		str_name = value:call("ToString()")
	end]]
	
	if str_name and can_set and o_tbl.cached_text[tkey] then 
		
		if type(str_name) ~= "string" then str_name = "" end --buggy new strings
		if string.find(str_name, "\n") then
			
			local cached_fields = o_tbl.cached_fields or {}
			split_lines = split(o_tbl.cached_text[tkey], "\n")
			cached_fields[tkey] = cached_fields[tkey] or 1 --idx of the current line
			was_changed, split_lines[ cached_fields[tkey] ] = imgui.input_text(display_name, split_lines[ cached_fields[tkey] ] )
			imgui.same_line()
			imgui.text(cached_fields[tkey] .. "/" .. #split_lines)
			
			if not imgui.same_line() and imgui.button("Up") and cached_fields[tkey] > 1 then 
				cached_fields[tkey] = cached_fields[tkey] - 1
			end
			
			if not imgui.same_line() and imgui.button("Dn") and cached_fields[tkey] < #split_lines then 
				cached_fields[tkey] = cached_fields[tkey] + 1
			end
			
			if was_changed then 
				o_tbl.cached_text[tkey] = ""
				for i, item in ipairs(split_lines) do 
					o_tbl.cached_text[tkey] = o_tbl.cached_text[tkey] .. ((i ~= 1) and "\n" or "") .. item
				end
			end
			o_tbl.cached_fields = cached_fields
		else
			was_changed, o_tbl.cached_text[tkey] = imgui.input_text(display_name, o_tbl.cached_text[tkey])
		end
		
		if can_set and o_tbl.cached_text[tkey] ~= str_name then
			imgui.push_id(tkey)
				if imgui.button("Set") then
					value = o_tbl.cached_text[tkey]
					o_tbl.cached_text[tkey] = nil
					changed = true
				end
				imgui.same_line()
				if imgui.button("Cancel") then
					o_tbl.cached_text[tkey] = str_name
					--collectgarbage()
				end
			imgui.pop_id()
		end
	else
		was_changed, str_name = imgui.input_text(display_name, str_name)
		if can_set and (was_changed or not o_tbl.cached_text[tkey]) then
			o_tbl.cached_text[tkey] = str_name
		else
			o_tbl.cached_text[tkey] = nil
		end
	end
	
	return changed, value
end

--Displays world coordinates of a vector3-4 field in imgui, if that vector is detected as being a coordinate:
local function draw_world_pos(pos, name, color)
	--if not pos then return end
	if type(pos.z) ~= "number" then 
		pos = pos[3] --matrices
	end
	draw.world_text((name or "Position") .. "\n[" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. "]", pos, color or 0xFF00FFFF)
end

local function offer_show_world_pos(value, name, key_name, obj, field_or_method)
	if value:length() > 5 or (world_positions[obj] and world_positions[obj][name]) then
		local o_tbl = obj._
		o_tbl.world_positions = o_tbl.world_positions or world_positions[obj] or {}
		local wpos_tbl, changed = o_tbl.world_positions[name]
		if not wpos_tbl then
			wpos_tbl = {}
			wpos_tbl.method = field_or_method.call and field_or_method
			wpos_tbl.field = field_or_method.get_data and field_or_method
			wpos_tbl.name = ((o_tbl.Name or o_tbl.name) .. "\n") .. name --(o_tbl.gameobj_name and (o_tbl.gameobj_name .. " ") or "") .. ((o_tbl.Name or o_tbl.name) .. "\n") .. name
			o_tbl.world_positions[name] = wpos_tbl
		end
		imgui.same_line()
		imgui.push_id(key_name .. name .. "Id")
			changed, wpos_tbl.active = imgui.checkbox("Display", wpos_tbl.active) 
			if wpos_tbl.active then 
				--imgui.same_line()
				--changed, wpos_tbl.as_local = imgui.checkbox("Local", wpos_tbl.as_local) 
				wpos_tbl.color = changed and (math.random(0x1,0x00FFFFFF) - 1 + 4278190080) or wpos_tbl.color
				world_positions[obj] = o_tbl.world_positions
			end
		imgui.pop_id()
	end
end

--Displays a vector2, 3 or 4 with editable fields in imgui:
local function show_imgui_vec4(value, name, is_int, increment, normalize)
	if not value then return end
	local changed = false
	local increment = increment or 0.01
	if type(value) ~= "number" then
		--local typename = value.__type and value.__type.name  glm::qua<float,0>
		if value.w  then 
			if name:find("olor") then
				changed, value = imgui.color_edit4(name, value, (not SettingsCache.use_color_bytes and 17301504) or nil)
				if SettingsCache.use_color_bytes then
					imgui.text_colored("Adjusted for Gamma: [" 
					.. static_funcs.calc_color(value.x) .. ", " .. static_funcs.calc_color(value.y) .. ", " .. static_funcs.calc_color(value.z) .. ", " .. static_funcs.calc_color(value.w) .. "]", 0xFFE0853D)
				end
			else
				changed, value = imgui.drag_float4(name, value, increment, -10000.0, 10000.0)
				--if changed and normalize or (value.__is_vec4==true) then -- (name:find("Rot") or (value - value:normalized()):length() < 0.001)  then -- and tostring(value):find("qua")
				--	value:normalize() 
				--end
			end
		elseif value.z then
			if is_int then
				changed, value = imgui.drag_float3(name, value, 1.0, -16777216, 16777216)
			elseif name:find("olor") then
				changed, value = imgui.color_edit3(name, value, (not SettingsCache.use_color_bytes and 17301504) or nil)
				if SettingsCache.use_color_bytes then
					imgui.text_colored("Adjusted for Gamma: [" 
					.. static_funcs.calc_color(value.x) .. ", " .. static_funcs.calc_color(value.y) .. ", " .. static_funcs.calc_color(value.z) .. "]", 0xFFE0853D)
				end
			else
				changed, value = imgui.drag_float3(name, value, increment, -10000.0, 10000.0)
			end
		elseif value.y then
			if is_int then  --17301504
				changed, value = imgui.drag_float2(name, value, 1.0, -16777216, 16777216)
			else
				changed, value = imgui.drag_float2(name, value, increment, -10000.0, 10000.0)
			end
		end
	else
		changed, value = imgui.drag_float(name, value, increment, -10000.0, 10000.0)
	end
	return changed, value
end

local function resource_ctx_menu(filetype, real_path, lua_obj_tbl)
	imgui.tooltip("Right click for more options")
	if imgui.begin_popup_context_item(filetype) then  
		if imgui.menu_item("Overwrite") then
			local file = _G[filetype]:new{filepath=real_path}
			ass = {real_path, true, false, lua_obj_tbl}
			file:save(real_path, false, true, false, lua_obj_tbl)
			lua_obj_tbl[filetype] = file
		end
		if imgui.menu_item("Backup") and BitStream.copyFile(real_path, real_path..".bak") and BitStream.checkFileExists(real_path..".bak") then
			re.msg("Backed up to " .. real_path..".bak")
		end
		if BitStream.checkFileExists(real_path..".bak") and imgui.menu_item("Restore") and BitStream.copyFile(real_path..".bak", real_path) then
			re.msg("Restored from " .. real_path..".bak")
		end
		imgui.end_popup() 
	end
end

--Displays settings for via.Chain objects in imgui:
local function imgui_chain_settings(via_chain, xform, game_object_name)
	
	local o_tbl = via_chain._
	local chain_groups = o_tbl.cgroups or {}
	local chain_settings = cached_chain_settings[via_chain] or {}
	
	if #chain_groups > 0 and imgui.tree_node_str_id(game_object_name .. "Groups", "Chain Groups (" .. #chain_groups ..  ")") then 
		
		changed, o_tbl.show_all_joints = imgui.checkbox("Show All Joints", o_tbl.show_all_joints)
		
		--[[if _G.RE_Resource and BitStream then
			if o_tbl.chain_save_path_exists then
				local real_path = o_tbl.chain_save_path_text:gsub("^reframework/data/", "")
				if imgui.button("Save Chain") then
					local chainFile = ChainFile:new{filepath=real_path, mobject=via_chain}
					if chainFile:save(real_path) then 
						re.msg("Saved Chain file to:\n" .. o_tbl.chain_save_path_text)
					end
					o_tbl.ChainFile = chainFile
				end
				resource_ctx_menu("ChainFile", real_path, o_tbl)
				imgui.same_line()
			end
			
			if o_tbl.chain_save_path_text==nil then
				local path = via_chain:get_ChainAsset() and via_chain:get_ChainAsset():get_ResourcePath() or ""
				o_tbl.chain_save_path_text = "$natives/" .. (((sdk.get_tdb_version() <= 67) and "x64/") or "stm/") .. path .. ((ChainFile and ChainFile.extensions[game_name]) or "")
			end
			
			changed, o_tbl.chain_save_path_text = imgui.input_text("Modify Chain File" .. ((o_tbl.chain_save_path_exists and "") or " (Does Not Exist)"), o_tbl.chain_save_path_text) --
			if changed or o_tbl.chain_save_path_exists==nil then
				o_tbl.chain_save_path_exists = BitStream.checkFileExists(o_tbl.chain_save_path_text:gsub("^reframework/data/", ""))
			end
			
			local tooltip_msg = "Access files in the 'REFramework\\data\\' folder.\nStart with '$natives\\' to access files in the natives folder.\nInput the location of the chain file for this via.motion.Chain"
			imgui.tooltip(tooltip_msg)
			
			if o_tbl.ChainFile and imgui.tree_node("ChainFile") then
				o_tbl.ChainFile:displayImgui()
				imgui.tree_pop()
			end
		end]]
		
		for i, group in ipairs(chain_groups) do 
		
			group.group._ = group.group._ or create_REMgdObj(group.group)
			
			if imgui.tree_node_str_id(game_object_name .. "Groups" .. i-1, i-1 .. ". Group " .. group.terminal_name) then 
				
				if not o_tbl.show_all_joints then
					group:update()
				end
				
				if not group.setting_idx then --initial setup (requiring all other chain groups)
					cached_chain_settings_names[via_chain] = cached_chain_settings_names[via_chain] or {}
					for j, grp in ipairs(chain_groups) do 
						insert_if_unique(cached_chain_settings_names[via_chain], "Settings " .. grp.settings_id)
						grp.setting_idx = find_index(cached_chain_settings_names[via_chain], "Settings " .. grp.settings_id)
						grp.blend_idx = grp.setting_idx
						grp:change_custom_setting()
					end
					table.sort(cached_chain_settings_names[via_chain], function(a,b) return a < b end)
				end
				
				if ChainGroup.uses_customsettings then 
					changed, group.setting_idx = imgui.combo("Set CustomSettings", group.setting_idx, cached_chain_settings_names[via_chain])
					if imgui.button("Reset CustomSettings") or changed then 
						group:change_custom_setting()
					end
					imgui.same_line()
				end
				
				changed, group.show_positions = imgui.checkbox("Show Names", group.show_positions) 
				
				if ChainGroup.uses_customsettings then 
					imgui.same_line()
					changed, group.do_blend = imgui.checkbox("Blend", group.do_blend)
					if group.do_blend then 
						imgui.text("Note: Only blends original settings to original settings")
						changed, group.blend_ratio = imgui.drag_float("Blend Ratio", group.blend_ratio, 0.01, 0, 1)
						changed, group.blend_idx = imgui.combo("Blend-To", group.blend_idx or 1, cached_chain_settings_names[via_chain])
						if changed then
							group:change_custom_setting(tonumber(cached_chain_settings_names[via_chain][group.blend_idx]:match(" (.+)")))
						end
					end
					if imgui.tree_node("CustomSettings") then 
						imgui.managed_object_control_panel(group.settings, game_object_name .. "CS" .. i, nil) 
						imgui.tree_pop()
					end
				end
				if not ChainGroup.uses_customsettings or imgui.tree_node("ChainGroup") then
					imgui.managed_object_control_panel(group.group, game_object_name .. "CGrp" .. i, group.terminal_name) 
					if ChainGroup.uses_customsettings then
						imgui.tree_pop()
					end
				end
				group.group._.is_open = true
				imgui.tree_pop()
			--elseif group.group._ then
			--	group.group._.is_open = nil
			end
		end
		
		imgui.tree_pop()
	end
end

--Displays a single field or property in imgui:
local function read_field(parent_managed_object, field, prop, name, return_type, key_name, element, element_idx)
	
	local value, is_obj, skip, changed, was_changed
	local o_tbl = parent_managed_object._
	local vd = prop or (field and o_tbl.field_data[name:match("%<(.+)%>") or name]) or o_tbl
	local display_name = vd.display_name or name
	local found_array = return_type:get_full_name():find("<") or o_tbl.mysize or o_tbl.element_names
	local Name -- = ""
	
	if element ~= nil then 
		value = element
	elseif field then 
		value = vd.value
		--[[value = parent_managed_object[name:match("%<(.+)%>") or name]
		if value == nil then 
			value = field:get_data(parent_managed_object)
		end]]
	elseif prop.get then --and value == nil then 
		if not prop.set then 
			display_name = display_name .. "*"
		end
		value = prop.cvalue
		if value == nil then 
			value = prop.value 
		end
	end
	
	local tostring_value = tostring(value)
	local values_type = type(value)
	local do_offer_worldpos
	
	if element_idx then --((value ~= nil) ) and
		local tbl = o_tbl.item_data
		if not o_tbl.is_arr then
			tbl[prop.name] = tbl[prop.name] or {}
			tbl = tbl[prop.name]
		end
		if not tbl.prototype then 
			local ret_type = (can_index(value) and value.get_type_definition and value:get_type_definition()) or o_tbl.item_type
			tbl.prototype = (ret_type and VarData:new{
				o_tbl=o_tbl or vd,
				value=value,
				ret_type=ret_type,
				name=ret_type:get_name(),
				full_name=ret_type:get_full_name(),
				is_arr_element=not not (o_tbl.name_full:find("%[%]") or o_tbl.name_full:find("List")) or nil,
			}) or {}
		end
		if not tbl[element_idx] then
			tbl[element_idx] = merge_tables({}, tbl.prototype)
			setmetatable(tbl[element_idx], VarData)
		end
		vd = tbl[element_idx]
	end

	vd.is_static = vd.is_static or (field and field:is_static() and "STATIC") or nil --or prop and prop.get and prop.get:is_static()
	
	--if field or vd.is_arr_element then  
	--	if vd.value~=nil then value = vd.value end
	--end
	
	imgui.push_id(display_name)	
		if imgui.button("+") then 
			vd.show_var_data = not vd.show_var_data or nil
		end
		imgui.tooltip((field and "Advanced Field Options") or "Advanced Property Options")
	imgui.pop_id()
	
	imgui.same_line()
	
	--imgui.push_item_width(256)
	
	if return_type:is_a("System.Enum") then
		local enum, value_to_list_order, enum_names = get_enum(return_type)
		if value_to_list_order then 
			changed, value = imgui.combo(display_name, value_to_list_order[value], enum_names) 
			if changed then 
				value = enum[ enum_names[value]:sub(1, enum_names[value]:find("%(")-1) ]
			end
		else
			changed, value = imgui.drag_int(display_name .. " (Enum)", value, 1, 0, 4294967296)
		end
	elseif values_type == "number" or values_type == "boolean" or return_type:is_primitive() then
		if return_type:is_a("System.Single") then
			changed, value = imgui.drag_float(display_name, value, vd.increment, -100000.0, 100000.0)
		elseif return_type:is_a("System.Boolean") then
			changed, value = imgui.checkbox(display_name, value)
		elseif return_type:is_a("System.UInt32") or return_type:is_a("System.UInt64") or return_type:is_a("System.UInt16") then
			changed, value = imgui.drag_int(display_name, value, 1, 0, 4294967296, "%u")
		else
			changed, value = imgui.drag_int(display_name, value, 1, -2147483647, 2147483647)
		end
	elseif return_type:is_a("via.Color") then
		if imgui.tree_node_str_id(key_name .. name, display_name) then 
			local rgba
			changed, rgba = imgui.color_picker_argb(display_name, value:get_field("rgba") or 0)
			if changed then 
				value:set_field("rgba", rgba)
			end
			imgui.tree_pop()
		end
	elseif vd.is_sfix then
		local new_value = (vd.is_sfix==4 and Vector4f.new(tonumber(value.x:call("ToString()")), tonumber(value.y:call("ToString()")), tonumber(value.z:call("ToString()")), tonumber(value.w:call("ToString()"))))
		or (vd.is_sfix==3 and Vector3f.new(tonumber(value.x:call("ToString()")), tonumber(value.y:call("ToString()")), tonumber(value.z:call("ToString()"))))
		or vd.is_sfix==2 and Vector2f.new(tonumber(value.x:call("ToString()")), tonumber(value.y:call("ToString()"))) or tonumber(value:call("ToString()"))
		if vd.is_sfix > 1 then
			changed, new_value = show_imgui_vec4(new_value, display_name, nil, vd.increment)
		else
			changed, new_value = imgui.drag_float(display_name, new_value, vd.increment, -100000.0, 100000.0)
		end
		if changed then 
			value = (vd.is_sfix==1 and value:call("From(System.Single)", tostring(new_value))) or value:call("Parse(System.String)", (new_value.x .. ", " .. new_value.y 
			.. ((new_value.z and ((", " .. new_value.z) .. ((new_value.w and (", " .. new_value.w)) or ""))) or "") ))
		end
	elseif return_type:is_a("via.Position") then
		local new_value = Vector3f.new(value:get_field("x"):read_double(0x0), value:get_field("y"):read_double(0x0), value:get_field("z"):read_double(0x0))
		changed, new_value = show_imgui_vec4(new_value, display_name, nil, vd.increment)
		--do_offer_worldpos = {new_value, display_name, key_name, parent_managed_object, (field or prop.get)}
		if changed then 
			value:write_double(0, new_value.x) ; value:write_double(0x8, new_value.y) ; value:write_double(0x10, new_value.z) 
		end
	elseif vd.is_lua_type == "mat" then
		if imgui.tree_node_str_id(key_name .. name, display_name) then 
			local new_value = Matrix4x4f.new()
			for i=0, 3 do 
				changed, new_value[i] = show_imgui_vec4(value[i], "Row[" .. i .. "]", nil, vd.increment)
				was_changed = changed or was_changed
				if i == 3 and new_value[i].w == 1 then 
					o_tbl.name = tostring(o_tbl.name)
					do_offer_worldpos = { new_value[i], (o_tbl and (o_tbl.Name or o_tbl.name) or "") .. " " .. display_name, key_name, parent_managed_object, (field or prop.get) }
					--vdl.is_pos = true is_pos, is_rot = name:find("Position"), name:find("Rotation")
				end
			end
			if was_changed then 
				value = new_value 
			end
			imgui.tree_pop()
		end
	elseif value and ((vd.is_lua_type == "qua") or (vd.is_lua_type == "vec")) then --all other lua types --or (value and vd.can_index and (type(value.x or value[0])=="number"))
		changed, value = show_imgui_vec4(value, display_name, nil, vd.increment)
		--if value.__is_vec4==true then 
		--	imgui.text("Before imgui: " .. tostring(value) .. ", " .. vector_to_string(value))
		--end
		if vd.is_lua_type=="qua" and value.w then 
			value = Quaternion.new(value.x, value.y, value.z, value.w) 
		end
		if value and ((vd.is_lua_type == "qua") or (vd.is_lua_type == "vec")) then
			do_offer_worldpos = { value, display_name, key_name, parent_managed_object, (field or prop.get) }
		end
	elseif not found_array and vd.is_res then 
		is_obj = true
		changed, value = show_imgui_resource(value, name, key_name, vd, return_type)		
	elseif (return_type:is_a("System.String")) then
		is_obj = true
		was_changed, value = show_imgui_text_box(display_name, value, o_tbl, (field or prop.set), nil, field )
		was_changed = not found_array and was_changed
	--managed objects and valuetypes:
	elseif (value and not (value.__is_mat4)) and ((vd.is_obj or vd.is_vt) or (vd.can_index and (value._ or tostring_value:find("::ValueType") or ({pcall(sdk.is_managed_object, value)})[2] == true))) then --value.x or 
		is_obj = true
		--[[if imgui.tree_node_str_id(key_name .. name .. "M", display_name .. (vd.mysize and (" (" .. vd.mysize .. ")") or "")) then
			read_imgui_element(vd)
			imgui.tree_pop()
		end]]
		local field_pd
		local count = vd.array_count or (not o_tbl.propdata and vd.mysize)
		local do_update = o_tbl.clear --or random(16)
		
		if not count and not element_idx then
			local return_type = value.get_type_definition and value:get_type_definition() or return_type
			if return_type then
				field_pd = metadata_methods[return_type:get_full_name()] or get_fields_and_methods(return_type)
				
				Name = not element_idx and ((not do_update and vd.Name) or get_mgd_obj_name(value, {
					ret_type=return_type, 
					name_methods=field_pd.name_methods or get_name_methods(return_type),
					fields=field_pd.fields,
				}, nil, false) or "") or ""
				
				vd.Name = (not do_update and vd.Name) or Name or ""
				
				--if Name ~= "" then
				--	display_name = display_name .. "	\"" .. Name .. "\""
				--end
			end
		end
		
		if imgui.tree_node_colored(name, display_name .. (count and (" (" .. count .. ")") or ""), vd.is_static or Name, vd.is_static and 0xFF0000FF) then
			
			if vd.is_static then
				imgui.same_line()
				imgui.text_colored(Name, 0xFFE0853D)
				--vd.is_static = nil
			end
			--value = imgui.managed_object_control_panel(value)
			
			changed, value = imgui.managed_object_control_panel(value, key_name .. name, name, not (prop.get and not prop.set)) --game_object_name .. " -> " .. name
			
			if value and value._ then
				value._.Name = value._.Name or display_name
				value._.owner = (value._.name~="Folder" and parent_managed_object) or value._.owner or nil
				--value._.can_set = not (prop.get and not prop.set)
				if vd.linked_array then
					o_tbl.item_data = value._.item_data
					o_tbl.elements = value._.elements
					o_tbl.element_names = value._.element_names
				end
			end
			imgui.tree_pop()
		else
			if prop and not vd.is_vt and not is_valid_obj(value) then
				local idx = find_index(o_tbl.props, prop)
				if idx then table.remove(o_tbl.props, idx) end --its broken
			elseif vd.is_static then
				imgui.same_line()
				imgui.text_colored(Name, 0xFFE0853D)
			end
		end
	else--if not prop.new_value then --value ~= nil and 
		--[[imgui.text(tostring(value and not (value.x or value.__is_mat4)) 
		.. ", " .. (tostring(vd.is_obj or vd.is_vt)) 
		.. ", " .. (tostring(vd.can_index and (value._ or tostring_value:find("::ValueType"))))
		.. ", " .. (tostring(({pcall(sdk.is_managed_object, value)})[2] == true)))]]
		imgui.text_colored(tostring((value and value.get_type_definition and value:get_type_definition():get_full_name()) or ""), 0xFF0000FF)
		if value ~= nil and vd.value_org == nil then
			local ret_type = (can_index(value) and value.get_type_definition and value:get_type_definition()) or o_tbl.item_type or return_type
			vd.new_self = ret_type and VarData:new{
				o_tbl=o_tbl,
				value=value,
				field=vd.field,
				get=vd.get,
				set=vd.set,
				ret_type=ret_type,
				name=ret_type:get_name(),
				full_name=ret_type:get_full_name(),
				is_arr_element=not not (o_tbl.name_full:find("%[%]") or o_tbl.name_full:find("List")) or nil,
			}
		end
		imgui.same_line()
		imgui.text(display_name)
	end
	
	--imgui.pop_item_width()
	
	
	local can_set = (field or vd.field or prop.set or vd.is_arr_element)
	changed = changed or was_changed
	if changed and not can_set and not is_obj then 
		imgui.set_tooltip("Cannot set")
		changed = false
	end
	
	--Freeze a field, setting it to the frozen setting every frame: ------------------------
	if not o_tbl.is_vt then
		local freeze, freeze_changed = vd.freeze
		if freeze == nil and vd.freezetable then 
			freeze = vd.freezetable[element_idx]
		end
		
		if not is_obj and (((freeze ~= nil) and (field or prop.set) and (vd.value_org ~= nil))) then --freezing / resetting values 
			
			imgui.push_id(vd.name or field:get_name() .. "F")
				if (freeze == false) and vd.timer_start and ((uptime - vd.timer_start) > 5.0) then 
					vd:set_freeze(nil, element_idx)
					vd.timer_start = nil
				end
				
				--vd.display_name is used when embedding the prop in a different menu
				if freeze and not vd.display_name and not imgui.same_line() and imgui.button(freeze and "Unfreeze" or "Freeze") then
					freeze = not freeze
					vd:set_freeze(freeze, element_idx)
					changed = true
					goto exit
				end
				
				if freeze or (vd.timer_start and (uptime - vd.timer_start) > 0.1) then
					if (not vd.display_name and not imgui.same_line() and imgui.button("Reset")) then
						vd:set_freeze(nil, element_idx)
						value = vd:get_org_value(element_idx)
						changed = true
						vd.was_changed = nil
						goto exit
					end
					if freeze then 
						vd:set_freeze((changed or was_changed) and 1 or true, element_idx) --bypass (1) for modifying an already-frozen field
					end
				end
			::exit::
			imgui.pop_id()
		elseif changed or was_changed then 
			o_tbl.was_changed = true
			vd.was_changed = true
			vd:set_freeze(freeze or false, element_idx)
			vd.timer_start = (changed and (freeze == nil) and uptime) or vd.timer_start or nil--set the timer when its changed (otherwise it flickers) --
		end
	end
	
	--[[if element_idx then
		log.debug(element_idx .. " " .. value .. " " .. tostring(element))
		vd.value = value
	end]]
	
	if vd.is_static and not is_obj then
		imgui.same_line()
		imgui.text_colored("STATIC", 0xFF0000FF)
	end
	
	if vd.show_var_data then 
		
		imgui.spacing()
		imgui.text_colored("---->", 0xFFE0853D)
		imgui.same_line()
		imgui.begin_rect()
		
			if do_offer_worldpos then 
				offer_show_world_pos(table.unpack(do_offer_worldpos)) 
				local world_tbl = o_tbl.world_positions and o_tbl.world_positions[name] 
				if (vd.set or vd.field or vd.is_arr_element) and ((world_tbl and world_tbl.active) or vd.is_pos ) then  --or vd.is_rot --rotation is being fucky
					imgui.same_line()
					local draw_changed
					draw_changed, vd.draw_gizmo = imgui.checkbox("Draw Gizmo", vd.draw_gizmo)
					if vd.draw_gizmo then
						imgui.same_line()
						draw_changed, vd.is_local = imgui.checkbox("Local", vd.is_local)
						local mat = Matrix4x4f.identity()
						local pos = ((o_tbl.pos and ((o_tbl.pos[1].to_vec4 and o_tbl.pos[1]:to_vec4()) or o_tbl.pos[1])) or mat[3])
						
						if vd.is_mat then 
							mat = Matrix4x4f.new(value[0], value[1], value[2], value[3])
							if vd.is_local then 
								mat[3] = pos or mat[3]
							end
						else
							if vd.is_rot then
								mat = (vd.is_lua_type=="qua" and value:to_mat4()) or value:to_mat()
							end
							if vd.is_rot or vd.is_scale or vd.is_local then
								mat[3] = pos or mat[3]
							else
								mat[3] = (value.to_vec4 and value:to_vec4()) or value
							end
							mat[3].w = 1.0
						end
						
						was_changed, mat = draw.gizmo(parent_managed_object:get_address() + (prop.index or 0), mat, 
							((vd.is_rot and imgui.ImGuizmoOperation.ROTATE) or (vd.is_pos and imgui.ImGuizmoOperation.TRANSLATE)) or nil, 
							vd.is_local and imgui.ImGuizmoMode.LOCAL or nil)
							
						if was_changed then
							changed = true
							local new_value
							if vd.is_mat then
								--if vd.is_local then 
								--	mat[3] = value[3] + (pos - mat[3])
								--end
								new_value = mat
							elseif vd.is_rot then
								new_value = (value.__is_vec3==true and mat:to_quat():to_euler()) or mat:to_quat()
							elseif vd.is_scale then
								new_value = value - (pos - mat[3])
							--elseif vd.is_local then
							--	new_value = value + (pos - mat[3])
							else
								new_value = (value.w and mat[3]) or mat[3]:to_vec3()
								if o_tbl.go then o_tbl.go.init_worldmat[3] = mat[3] end
							end
							value = new_value
							if freeze then 
								vd:set_freeze(1, element_idx) --bypass (1) for modifying an already-frozen field
							end
						end
					end
					vd.update = true
				end
				imgui.same_line()
			end
			
			if (vd.set or vd.field or vd.is_arr_element) then
				
				if imgui.button("Reset Value") then 
					freeze = nil
					vd:set_freeze(nil, element_idx)
					value = vd:get_org_value(element_idx)
					old_deferred_calls[logv(parent_managed_object) .. " " .. vd.name]  = nil
					vd.was_changed = nil
					changed = 1
				end
				
				if not is_obj or vd.is_res then 
					if not vd.is_res then
						imgui.same_line()
						local freeze_changed
						vd.timer_start = (freeze ~= nil) and uptime or nil
						freeze_changed, freeze = imgui.checkbox("Freeze", vd.freeze)
						if freeze_changed then 
							vd:set_freeze(freeze or false, element_idx)
						end
						
						imgui.same_line()
						imgui.text_colored(vd.ret_type:get_full_name(), 0xFFE0853D)
						
						--local ret_name = vd.ret_type:get_full_name()
						if vd.increment then
							local rt_name, changed = vd.ret_type:get_full_name()
							changed, metadata_methods[rt_name].increment = imgui.drag_float("Increment: " .. rt_name, metadata_methods[rt_name].increment or SettingsCache.increments[rt_name].increment, 0.0001, 0.0001, 1) 
							if changed then 
								vd.increment = metadata_methods[rt_name].increment
								SettingsCache.increments[rt_name].increment = vd.increment
							end
						end
					end
					
					if vd.set then 
						if editable_table_field("cvalue", vd.cvalue, vd, "Value") == 1 then 
							value = vd.cvalue
							changed = true
						end
					elseif vd.field or vd.is_arr_element then 
						if editable_table_field("value", vd.value, vd, "Value") == 1 then 
							value = vd.value
							changed = true
						end
					end
					--if vd.value_org then 
					--	editable_table_field("value_org", vd.value_org, vd, "Original Value")
					--end
				end
				
				if not vd.ret_type:is_primitive() then
					vd.gvalue_name = vd.gvalue_name or ""
					vd.value = vd.value or vd.value_org
					if editable_table_field("gvalue_name", vd.gvalue_name, vd, "Global Alias") == 1 then
						re.msg(tostring(vd.gvalue_name))
						_G[vd.gvalue_name] = vd.value
						if static_funcs.mini_console then
							command = vd.gvalue_name
							force_command = true
						end
					end
					imgui.tooltip("Assign this object to a global variable", 0)
					
					if editable_table_field("global_value", vd.global_value or "", vd, "Set as Global Var", is_obj and {check_add_func=(function(val) return sdk.find_type_definition(val):is_a(vd.ret_type) end)}) == 1 then
						changed = true
						value = vd.global_value
						o_tbl.invalid = true
					end
					imgui.tooltip("Set as 'nil' to delete", 0)
					
					if return_type:is_a("via.Prefab") then
						local obj_changed
						vd.pfb_path = vd.pfb_path or value:call("get_Path")
						vd.pfb_idx = not changed and vd.pfb_idx
						obj_changed, vd.pfb_idx = imgui.combo("Change Prefab", vd.pfb_idx or find_index(RN.pfb_resource_names, vd.pfb_path) or 1, RN.pfb_resource_names)
						if obj_changed then 
							changed = true
							value = RSCache.pfb_resources[ RN.pfb_resource_names[vd.pfb_idx] ]
							vd.pfb_path = value:call("get_Path")
						end
						if imgui.button("Spawn Prefab") then
							local pos = last_camera_matrix[3]
							o_tbl.keep_alive = true
							local last_object = scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))[0]
							value:call("instantiate(via.vec3, via.Folder", pos, spawned_prefabs_folder)
							local new_last_object = scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))[0]
							if new_last_object ~= last_object then
								o_tbl.spawned_prefabs = o_tbl.spawned_prefabs or {}
								o_tbl.spawned_prefabs[xform] = GameObject:new{xform=new_last_object}
							end
						end
						if o_tbl.spawned_prefabs and not imgui.same_line() and imgui.tree_node("Spawned Prefabs") then
							for xform, spawned_prefab in orderedPairs(o_tbl.spawned_prefabs) do
								if imgui.tree_node_str_id(spawned_prefab.key_hash, spawned_prefab.name) then
									imgui_anim_object_viewer(spawned_prefab)
									imgui.tree_pop()
								end
							end
							imgui.tree_pop()
						end
					end
				end
				
				if not vd.is_lua_type then
					
					local is_vt = vd.is_vt or vd.ret_type:is_value_type() or vd.ret_type:get_full_name():find("Collections")
					local can_create = not (vd.ret_type:is_primitive() or vd.ret_type:is_a("via.Component") or vd.ret_type:is_a("via.GameObject")) --is_vt or 
					
					if type(vd.new_value) == "string" then 
						vd.new_value = nil 
					end
					
					if can_create and imgui.button((vd.new_value and "Cancel New") or (vd.new_arr_elems and "Set Elements") or "Create New") then
						local rtype = vd.ret_type
						if not vd.new_value and rtype:is_a("System.Array") then
							vd.item_type = sdk.find_type_definition(rtype:get_full_name():gsub("%[%]", "")) or vd.item_type
							vd.new_value = (vd.new_arr_elems and sdk.create_managed_array(vd.item_type, #vd.new_arr_elems):add_ref()) or nil
							if vd.new_value and vd.new_arr_elems then
								for i, elem in ipairs(vd.new_arr_elems) do
									vd.new_value[i-1] = elem
								end
								vd.new_arr_elems = nil
								vd.new_key = nil
							elseif not vd.new_arr_elems then 
								vd.new_key = "new = sdk.create_instance(\"" .. vd.item_type:get_full_name() .. "\", true):add_ref();"
								if vd.value then
									vd.value._ = vd.value._ or create_REMgdObj(vd.value)
									vd.new_arr_elems = merge_indexed_tables({}, vd.value._.elements) or {}
								else
									vd.new_arr_elems = {(is_lua_type(vd.item_type) and 0) or sdk.create_instance(vd.item_type:get_full_name(), true):add_ref()} 
								end
							end
						else
							vd.new_value = not vd.new_value and ((is_vt and ValueType.new(rtype)) or sdk.create_instance(rtype:get_full_name()) or sdk.create_instance(rtype:get_full_name(), true)) or nil
							if vd.new_value and vd.new_value.add_ref then
								vd.new_value = ((vd.new_value:get_type_definition() == rtype) and vd.new_value:add_ref()) or nil
								if vd.new_value then 
									pcall(sdk.call_object_func, vd.new_value, ".ctor()") 
								end
							end
						end
					end
					
					if vd.new_arr_elems and not imgui.same_line() then 
						editable_table_field("new_arr_elems", vd.new_arr_elems, vd, "New Array Elements", {always_show=true, new_key=vd.new_key})
					end
					
					--[[if vd.new_method then
						editable_table_field("new_method", vd.new_method, vd, "New Method")
						editable_table_field("new_target", vd.new_target, vd, "New Target")
					end]]
					
					if vd.new_value then
						imgui.same_line()
						if imgui.button("Set New Value") then
							value, vd.new_value = vd.new_value, nil
							changed = true
							if vd.linked_array and vd.linked_array.fields._size then
								vd.linked_array.obj:set_field("_size", #value)
							end
							o_tbl.invalid = true
						elseif not imgui.same_line() and imgui.tree_node("New Value") then
							imgui.managed_object_control_panel(vd.new_value)
							imgui.tree_pop()
						end
					end
				end
			elseif vd.ret_type then
				imgui.text_colored(vd.ret_type:get_full_name(), 0xFFE0853D)
			end
			
			if vd.display_name and imgui.tree_node(o_tbl.name) then 
				local temp = vd.display_name
				vd.display_name, vd.show_var_data = nil, nil
				imgui.managed_object_control_panel(parent_managed_object)
				vd.display_name, vd.show_var_data = temp, true
				imgui.tree_pop()
			end
			
			if imgui.tree_node("[Lua]") then
				read_imgui_element(vd, nil, true)
				imgui.tree_pop()
			end
			
		imgui.end_rect(2)
	end
	
	if changed then
		o_tbl.clear_next_frame = true
		if vd.is_scale then 
			if value.x < 0.0001 then value.x = 0.0001 end --scale cannot be negative
			if value.y < 0.0001 then value.y = 0.0001 end
			if value.z < 0.0001 then value.z = 0.0001 end
		end
	end
	
	return changed, value
end


local function show_managed_objects_table(parent_managed_object, tbl, prop, key_name, is_elements)
	
	local o_tbl = parent_managed_object._
	local arr_tbl = o_tbl.element_names and o_tbl or prop
	arr_tbl.mysize = get_table_size(tbl)
	local item_type = arr_tbl.item_type or arr_tbl.ret_type
	local display_name = prop.name .. ((prop.field or prop.set) and "" or "*") .. ((arr_tbl.elements and (" (" .. arr_tbl.mysize .. ")")) or (" [" .. arr_tbl.mysize .. "]"))
	local tbl_changed, tbl_was_changed = false, false
	
	if item_type and arr_tbl.element_names and arr_tbl.mysize > 0 and (is_elements or imgui.tree_node_str_id(display_name, display_name)) then
		
		local function display_element(element, idx)
			local element_name = (sdk.is_managed_object(element) and element:get_type_definition():get_full_name()) or item_type:get_full_name()--arr_tbl.element_names[i]
			
			--local var_metadata = prop or (field and o_tbl.field_data[name:match("%<(.+)%>") or name]
			--[[if not element_name:find(element:get_type_definition():get_full_name()) then
				element_name = element:get_type_definition():get_name() .. "	\"" .. element_name .. "\""
				arr_tbl.element_names[idx] = element_name
			end]]
			
			local disp_name = idx .. ". " .. (element_name or tostring(element)) .. ((arr_tbl.set or o_tbl.is_arr) and "" or "*") 
			
			if (not prop.is_lua_type and not is_lua_type(item_type)) then --special thing for reading elements that are objects (read_field could also work though)
				imgui.text("")
				imgui.same_line()
				--if imgui.tree_node_str_id(key_name .. element_name .. idx, disp_name ) then
				arr_tbl.element_Names = arr_tbl.element_Names or {}
				arr_tbl.element_Names[idx] = arr_tbl.element_Names[idx] or get_mgd_obj_name(element)
				if imgui.tree_node_colored(idx, disp_name, arr_tbl.element_Names[idx] or "") then
					tbl_changed, element = imgui.managed_object_control_panel(element, key_name .. element_name .. idx, element_name)
					--[[if element._ then
						element._.Name = element._.Name or disp_name
						arr_tbl.element_names[idx] = element._.Name
						--element._.is_open = true
					end]]
					imgui.tree_pop()
				--elseif element._ then
				--	element._.is_open = nil
				end
			else
				tbl_changed, element = read_field(parent_managed_object, nil, prop, disp_name, item_type, key_name, element, idx)
			end
			
			if tbl_changed then 
				tbl_was_changed = true
				
				if o_tbl.is_arr then 
					parent_managed_object[idx-1] = element
					if o_tbl.item_data and o_tbl.item_data[idx] then 
						o_tbl.item_data[idx].value = element 
					end
				elseif (prop and prop.set) then
					deferred_calls[parent_managed_object] = deferred_calls[parent_managed_object] or {}
					table.insert(deferred_calls[parent_managed_object], {func=prop.set:get_name(), args={ idx-1, element }, vardata=prop })
				end
			end
		end
		
		local max_sz = SettingsCache.max_element_size
		
		if (#tbl > max_sz) then
			for lv = 1, #tbl, max_sz do 
				local this_limit = (#tbl < lv+max_sz and #tbl) or lv+max_sz
				if #tbl < max_sz or imgui.tree_node("Elements " .. lv .. " - " .. this_limit) then
					for i = lv, (this_limit==lv+max_sz and this_limit-1) or this_limit  do 
						display_element(tbl[i], i)
					end
					if #tbl >= max_sz then
						imgui.tree_pop()
					end
				end
			end
		else
			for i, element in ipairs(tbl) do 
				display_element(element, i)
			end
		end
		
		if not is_elements then
			imgui.tree_pop()
		end
	end
	
	--if tbl_was_changed then 
		--prop.cvalue = nil
		--prop.update = true
		--metadata[parent_managed_object] = nil
	--end
	--return tbl_was_changed, tbl 
end

--Wrapper for read_field(), displays one REMgdObj field in imgui:
local function show_field(managed_object, field, key_name)
	local changed
	local field_data = managed_object._.field_data[field:get_name()]
	imgui.push_id(field_data.name.."F")
		changed, value = read_field(managed_object, field, field_data, field_data.name, field_data.ret_type, key_name)
	imgui.pop_id()
	if changed then
		local value = value
		deferred_calls[managed_object] = {vardata=field_data, fn=function()
			if can_index(value) and value.type and value:get_type_definition():is_value_type() then --fixme
				--log.debug("writing valuetype " .. tostring(key_name))
				write_valuetype(managed_object, field:get_offset_from_base(), value)
			else
				managed_object:set_field(field:get_name(), value)
			end
		end}
		--deferred_calls[managed_object] = { field=field:get_name(), args=value, vardata=managed_object._.field_data[field:get_name()]}
	end
	return changed
end

--Wrapper for read_field(), displays one REMgdObj property in imgui:
local function show_prop(managed_object, prop, key_name)
	local changed
	if type(prop.cvalue) == "table" then
		--imgui_check_value(managed_object._)
		changed, value = show_managed_objects_table(managed_object, prop.cvalue, prop, key_name)
	else
		imgui.push_id(prop.name.."P")
			changed, value = read_field(managed_object, nil, prop, prop.name, prop.ret_type, key_name)
		imgui.pop_id()
		if changed and prop.set then 
			deferred_calls[managed_object] = {func=prop.set:get_name(), args=value, vardata=prop, }
			--deferred_calls[managed_object] = deferred_calls[managed_object] or {}
			--table.insert(deferred_calls[managed_object], {func=prop.set:get_name(), args=value, vardata=prop, })
		end
	end
	
	return changed
end

--Shows buttons that can save to a file or retrieve JSON data as tables from a filepath with gameobject components. The tables can be loaded onto a real GameObject with load_json_game_object()
local function show_save_load_button(o_tbl, button_type, load_by_name, save_children)
	local button_only = o_tbl.button_only --button_only == 1 means no checkbox
	
	if button_only or o_tbl.is_component or o_tbl.components then
		
		local components = o_tbl.components or (o_tbl.show_gameobj_buttons and o_tbl.go.components) --or o_tbl.fake_components
		local load_mode, file = (button_type == "Load")
		o_tbl.go = o_tbl.go or GameObject:new{xform=o_tbl.xform}
		if load_by_name then
			if not (button_only==1) then 
				imgui.same_line()
				changed, o_tbl.show_load_input = imgui.checkbox((type(load_by_name)=="string" and load_by_name) or "Load By Name", o_tbl.show_load_input)
			end
			o_tbl.files_list = ((button_only==1) or o_tbl.show_load_input) and (o_tbl.files_list or {paths=fs.glob([[EMV_Engine\\Saved_GameObjects\\.*.json]])}) or nil
			if changed or (o_tbl.show_load_input and random(60)) then 
				o_tbl.files_list = {paths=fs.glob([[EMV_Engine\\Saved_GameObjects\\.*.json]]) or {}}
			end
			if (o_tbl.show_load_input or (button_only==1)) and not o_tbl.files_list.names then
				o_tbl.files_list.names = {}
				for i, filepath in ipairs(o_tbl.files_list.paths or {}) do 
					table.insert(o_tbl.files_list.names, filepath:match("^.+\\(.+)%."))
				end
			end
			if not button_only and (o_tbl.files_list and (imgui.button("OK") or imgui.same_line())) then
				file = json.load_file(o_tbl.files_list.paths[o_tbl.input_file_idx])
			end
		end
		if (not load_by_name and imgui.button(button_type .. (components and " GameObject" or ""))) or (load_by_name and file) then
			if not button_only then
				local try
				if components then --GameObjects and Transforms (with option "All")
					if single_component then
						for i=1, #components do
							local component = components[i]
							local single_component = component:get_type_definition():get_name() or nil
							if load_by_name and file then
								try = load_json_game_object(o_tbl.go, 1, single_component, o_tbl.files_list.names[o_tbl.input_file_idx], file)
							elseif load_mode then
								try = load_json_game_object(o_tbl.go, 1, single_component, o_tbl.files_list and o_tbl.files_list.names[o_tbl.input_file_idx])
							else
								try = save_json_gameobject(o_tbl.go, nil, single_component)
							end
						end
					else
						try = save_json_gameobject(o_tbl.go)
						if try and save_children and not load_mode and not load_by_name then
							local all_children = o_tbl.go:gather_all_children()
							for i, save_child_obj in ipairs(all_children) do
								save_json_gameobject(save_child_obj)
							end
						end
					end
				elseif load_by_name and file then
					try = load_json_game_object(o_tbl.go, 1, o_tbl.name, o_tbl.files_list.names[o_tbl.input_file_idx], file)
				elseif load_mode then
					try = load_json_game_object(o_tbl.go, 1, o_tbl.name)
				else
					try = save_json_gameobject(o_tbl.go, nil, o_tbl.name)
				end
				old_deferred_calls = (components and load_mode and try and {}) or old_deferred_calls
				o_tbl.clear_next_frame = load_mode and true
				if components and o_tbl.obj.MotionFsm2 then 
					on_frame_calls[o_tbl.obj.MotionFsm2] = {func="restartTree"}
				end
				if not try then re.msg("File Error") end
			end
			return file
		end
		--read_imgui_element(o_tbl)
		if load_by_name then
			if o_tbl.show_load_input then -- or (button_only==1)
				changed, o_tbl.input_file_idx = imgui.combo("Select GameObject", o_tbl.input_file_idx or 1, o_tbl.files_list.names)
				if changed and button_only and o_tbl.files_list then
					local loaded_file = json.load_file(o_tbl.files_list.paths[o_tbl.input_file_idx])
					return loaded_file or false
				end
			else
				o_tbl.show_load_input = nil
			end
		end
	end
end

local function show_imgui_uservariables(m_obj, name)
	local o_tbl = m_obj._ or create_REMgdObj(m_obj)
	local uvar_count = m_obj:call("getUserVariablesCount")
	for u=1, uvar_count do
		local uvar = m_obj:call("getUserVariables", u-1)
		local var_count = uvar and uvar:call("getVariableCount")
		if var_count and imgui.tree_node_str_id(uvar:get_address()+u, "User Variables: \"" .. (name or o_tbl.Name) .. "\" (" .. var_count .. ")") then
			for i=1, var_count do 
				local var = uvar:call("getVariable", i-1)
				local var_name = var:call("get_Name") .. (var:call("get_ReadOnly") and "*" or "")
				local type_kind = var:call("get_TypeKind")
				local v_o_tbl = var._ or create_REMgdObj(var)
				local prop = v_o_tbl.props_named._U64
				if type_kind == 2 then --Bool
					prop = v_o_tbl.props_named._Bool
				elseif type_kind == 11 then --Float
					prop = v_o_tbl.props_named._F32
				end
				was_changed, value = read_field(var, nil, prop, var_name, prop.ret_type, o_tbl.key_hash .. u .. i)
				if was_changed then 
					deferred_calls[var] = {func=prop.set:get_name(), args=value, vardata=prop}
					var._.update = true
				end
				prop.update = true
				var._.last_opened = uptime
			end
			imgui.tree_pop()
		end
	end
end

--Function to display an entire managed object with fields and properties in imgui, utilizing REMgdObj class:
function imgui.managed_object_control_panel(m_obj, key_name, field_name)
	
	if type(m_obj) ~= "userdata" then return imgui.text_colored("	"..tostring(m_obj), 0xFF0000FF) end
	if not m_obj._ and is_obj_or_vt(m_obj) then 
		create_REMgdObj(m_obj) --create REMgdObj class	
		if (type(m_obj._)~="table") or (m_obj._.type==nil) then 
			return false--, m_obj 
		end
	end
	
	if m_obj.__update and m_obj._ and m_obj._.name_full then
		
		local o_tbl = m_obj._
		o_tbl.Name = o_tbl.Name or field_name or key_name
		o_tbl.is_open = true
		local changed, was_changed
		local typedef = m_obj:get_type_definition()
		local is_xform = o_tbl.name=="Transform" --(o_tbl.xform == m_obj)
		game_object_name = o_tbl.gameobj_name or game_object_name or " "
		key_name = key_name or o_tbl.name or (o_tbl.gameobj_name and (o_tbl.gameobj_name .. o_tbl.name)) or o_tbl.key_hash
		field_name = field_name or o_tbl.Name or o_tbl.name or key_name
		o_tbl.last_opened = uptime
		--key_name = o_tbl.key_hash or key_name
		
		imgui.push_id(key_name)
		imgui.begin_rect()
			imgui.begin_rect()	
				local imgui_changed
				imgui.begin_rect()
					if imgui.button("Update:") or o_tbl.clear_next_frame or o_tbl.keep_updating then 
						o_tbl.clear = true 
						o_tbl.clear_next_frame = nil
					end
					imgui.tooltip("Update the fields and properties of this class")
					imgui.same_line()
					imgui_changed, o_tbl.keep_updating = imgui.checkbox("", SettingsCache.objs_to_update[o_tbl.name_full])
					imgui.tooltip("Keep updating all control panels of this class every frame")
					if imgui_changed then 
						SettingsCache.objs_to_update[o_tbl.name_full] = o_tbl.keep_updating
					end
					o_tbl.keep_updating = o_tbl.keep_updating or nil
				imgui.end_rect(1)
				
				imgui.same_line()
				--local complete_name = (game_object_name ~= "" and (game_object_name .. " -> ") or "")  .. o_tbl.name_full .. ((not o_tbl.name_full:find(field_name) and (" " .. field_name)) or "")
				--o_tbl.Name = o_tbl.Name or field_name
				
				if imgui.tree_node_colored(key_name.."o", "[Object Explorer] ", (game_object_name ~= "" and (game_object_name .. " -> ") or "")
				..(o_tbl.name_full~=field_name and (" "..typedef:get_full_name()) or "").." "..tostring(field_name).." @ "..m_obj:get_address(), 0xFFF5D442) then
				--if imgui.tree_node_str_id(key_name .. "ObjEx",  "[Object Explorer]  "  .. complete_name .. " @ " .. m_obj:get_address() ) then  
					
					imgui_changed, o_tbl.sort_alphabetically = imgui.checkbox("Sort Alphabetically", o_tbl.sort_alphabetically)
					o_tbl.sort_alphabetically = o_tbl.sort_alphabetically or nil
					
					imgui.same_line()
					if imgui.button("Clear Lua Data") then
						SettingsCache.exception_methods[o_tbl.name_full] = nil
						o_tbl.invalid = true
					end
					imgui.tooltip("Rebuild the lua tables comprising this control panel, refreshing everything")
					
					if o_tbl.was_changed and not imgui.same_line() and imgui.button("Undo Changes") then
						deferred_calls[m_obj] = {}
						for name, field_data in pairs(o_tbl.field_data or {}) do 
							if (field_data.value_org ~= nil) and field_data.was_changed and not (field_data.is_obj or field_data.elements) then
								table.insert(deferred_calls[m_obj], {field=field_data.field, args=field_data.value_org})
							end
						end
						for i, prop in ipairs(o_tbl.props or {}) do 
							if (prop.value_org ~= nil) and prop.was_changed and not (prop.is_obj or prop.elements) and not prop.is_count then
								table.insert(deferred_calls[m_obj], {func=prop.set, args=prop.value_org})--:to_vec4()})
							end
						end
						o_tbl.invalid = true
					end
					
					if o_tbl.is_component or o_tbl.components then
						if o_tbl.is_component == 2 then 
							changed, o_tbl.show_gameobj_buttons = imgui.checkbox("All", o_tbl.show_gameobj_buttons)
							imgui.same_line()
						end
						if o_tbl.is_xform or o_tbl.is_gameobj then
							changed, o_tbl.save_children = imgui.checkbox("Save Children", o_tbl.save_children)
							imgui.same_line()
						end
						show_save_load_button(o_tbl, "Save", nil, o_tbl.save_children)
						imgui.same_line()
						show_save_load_button(o_tbl, "Load")
						imgui.same_line()
						show_save_load_button(o_tbl, "Load", true)
					end
					
					if not o_tbl.is_vt then
						object_explorer:handle_address(m_obj, true)
					end
					
					if metadata[m_obj] and imgui.tree_node("Metadata") then 
						--[[if o_tbl and not o_tbl.hierarchy then
							local o_tbl = o_tbl
							local owner = o_tbl.obj
							o_tbl.hierarchy = {}
							while owner do 
								--local name = owner._.name_full .. (((owner._.Name and (owner._.name_full ~= owner._.Name) and owner._.Name ~= "") and (" " .. owner._.Name)) or "")
								--if not owner._.item_type then
									table.insert(o_tbl.hierarchy, {name=owner._.Name, object=owner})
								--end
								owner = owner._.owner
							end
							o_tbl.hierarchy = reverse_table(o_tbl.hierarchy)
						end]]
						--if imgui.tree_node("[Lua]") then 
							read_imgui_element(o_tbl)
						--	imgui.tree_pop()
						--end
						--read_imgui_element(metadata[m_obj])
						imgui.tree_pop()
					end
					
					--[[if o_tbl and o_tbl.counts then 
						changed, o_tbl.counts.idx = imgui.combo("Generic Count Method", o_tbl.counts.idx or 1, o_tbl.counts.counts_names)
						if changed then 
							o_tbl.counts.method = o_tbl.counts.counts[ o_tbl.counts.counts_names[o_tbl.counts.idx] ] 
							for i, prop in ipairs(o_tbl.props) do prop.cached_value = nil; prop.elements = nil end
							o_tbl.elements = nil
						end
					end]]
					
					if o_tbl.counts then 
						changed, o_tbl.counts.idx = imgui.combo("Generic Count Method", o_tbl.counts.idx or 1, o_tbl.counts.counts_names)
						if changed then 
							metadata_methods[o_tbl.name_full].counts_idx = o_tbl.counts.idx
							o_tbl.propdata.counts_idx = o_tbl.counts.idx
							o_tbl.counts.method = o_tbl.counts.counts[ o_tbl.counts.counts_names[o_tbl.counts.idx] ] 
							--re.msg(tostring(o_tbl.counts.counts_names[o_tbl.counts.idx]) .. " " .. tostring(o_tbl.counts.method))
							o_tbl.clear = true
						end
					end
					
					if static_funcs.mini_console then
						static_funcs.mini_console(m_obj, game_object_name .. key_name) 
					end
					--[[elseif metadata[m_obj] then
						local str_key = (type(key) == "string" and key) or tostring(m_obj:get_address())
						if imgui.tree_node_str_id(str_key .. "M", "Metadata") then
							read_imgui_pairs_table(metadata[m_obj], str_key)
							imgui.tree_pop()
						end
						if o_tbl and o_tbl.counts then 
							imgui_changed, o_tbl.counts.idx = imgui.combo("Generic Count Method", o_tbl.counts.idx or 1, o_tbl.counts.counts_names)
							if imgui_changed then 
								metadata_methods[o_tbl.name_full].counts_idx = o_tbl.counts.idx
								o_tbl.counts.method = o_tbl.counts.counts[ o_tbl.counts.counts_names[o_tbl.counts.idx] ] 
								o_tbl.clear = true
							end
						end
					end]]

					imgui.tree_pop()
				end
			imgui.end_rect(1)		
			
			--imgui.text(o_tbl.name)
			if is_xform then
				o_tbl.go = o_tbl.go or held_transforms[m_obj] or GameObject:new{xform=m_obj}
				if o_tbl.go and o_tbl.go.xform then 
					o_tbl.go:imgui_xform()
				end
			elseif o_tbl.name == "Mesh" then
				--imgui.text(tostring(o_tbl.go) .. " " .. tostring(o_tbl.go and o_tbl.go.materials) .. " " .. tostring(o_tbl) .. " " .. " " .. tostring(m_obj._))
				if not o_tbl.go or not o_tbl.go.materials then 
					local gameobj = m_obj:call("get_GameObject")
					o_tbl.go = held_transforms[gameobj:call("get_Transform")] or GameObject:new{gameobj=gameobj}
				end
				if o_tbl.go and o_tbl.go.materials and imgui.tree_node_ptr_id(o_tbl.go.mesh:get_address() - 1234, "Materials") then
					show_imgui_mats(o_tbl.go) 
					imgui.tree_pop()
				end
			elseif o_tbl.name == "Chain" then
				imgui_chain_settings(m_obj, o_tbl.xform, game_object_name)
			--[[elseif o_tbl.name == "Motion" and EMVSettings and o_tbl.props_named["Layer"].mysize > 0 then --Embedded animation controller, requires Enhanced Model Viewer
				local tmp = forced_mode  --temporary swap
				if not o_tbl.go or not o_tbl.go.end_frame then
					local gameobj = o_tbl.gameobj or m_obj:call("get_GameObject")
					o_tbl.go = GameObject:new_AnimObject{gameobj=gameobj, forced_mode=true}
					forced_mode = o_tbl.go  --temporary swap
					o_tbl.go:update_components()
					o_tbl.go:get_current_bank_name()
					o_tbl.go:build_banks_list()
				elseif o_tbl.go.layer and (o_tbl.go.face_mode or not o_tbl.go.same_joints_constraint) and imgui.tree_node_str_id(o_tbl.go.name .. "Anims", "Animations") then 
					o_tbl.go:update_AnimObject(nil, o_tbl.go)
					forced_mode = o_tbl.go --temporary swap
					show_imgui_animation(o_tbl.go, nil, true)
					imgui.tree_pop()
				end
				forced_mode = tmp  --temporary swap]]
			elseif o_tbl.type:is_a("via.behaviortree.BehaviorTree") then 
				o_tbl.gameobj = o_tbl.gameobj or get_GameObject(m_obj)
				o_tbl.go = o_tbl.go or (o_tbl.gameobj and held_transforms[o_tbl.xform or o_tbl.gameobj:call("get_Transform")] or GameObject:new{gameobj=o_tbl.gameobj})
				o_tbl.go:action_monitor(m_obj)
			elseif o_tbl.name == "UserVariablesHub" then
				show_imgui_uservariables(m_obj)
			end
			
			if ((o_tbl.components or o_tbl.is_component) or next(o_tbl.propdata.simple_methods)) and imgui.tree_node_str_id(key_name .. "Methods", "Simple Methods") then 
				if o_tbl.is_component and imgui.button("destroy " .. o_tbl.name) then 
					delete_component(o_tbl.gameobj, m_obj) --via.Components
					if held_transforms[o_tbl.xform] then
						held_transforms[o_tbl.xform].components, held_transforms[o_tbl.xform].components_named = lua_get_components(m_obj.xform)
					end
				elseif o_tbl.components and imgui.button("destroy " .. o_tbl.gameobj_name) then
					deferred_calls[m_obj] = {{ func="destroy", args={m_obj} }, {lua_object=m_obj._.go.xform, method=clear_object}} --via.GameObjects
				end
				for name, method in orderedPairs(o_tbl.propdata.simple_methods or {}) do 
					if imgui.button(name) then
						deferred_calls[m_obj] = { func=method:get_name() }
					end
				end	
				imgui.tree_pop()
			end
			imgui.spacing()
			
			if o_tbl.scn_path then 
				imgui.text("       Scene Path:")
				imgui.same_line()
				imgui.text_colored(o_tbl.scn_path, 0xFFAAFFFF)
			end
			
			if o_tbl.do_auto_expand or ((o_tbl.fields or o_tbl.props) and imgui.tree_node_str_id(key_name .. "F", is_xform and "via.Transform" or "Fields & Properties")) then
				
				local max_elem_sz = SettingsCache.max_element_size
				
				if o_tbl.fields then
					imgui.text("   FIELDS:")
					imgui.text("  ")
					imgui.same_line()
					--imgui.push_id(key_name.."F")
					imgui.begin_rect()
						
						local ordered_idxes = o_tbl.propdata.field_names
						if o_tbl.sort_alphabetically then
							o_tbl.ordered_fields_idxes = o_tbl.ordered_fields_idxes or {}
							ordered_idxes = o_tbl.ordered_fields_idxes
							if ordered_idxes[1] == nil then --or ((#ordered_idxes > SettingsCache.max_element_size) and imgui.button("Clear Fields Cache")) then 
								local hashed_list = {}; for i, field in pairs(o_tbl.fields) do hashed_list[field:get_name():gsub("<", "")] = field end
								ordered_idxes = {}
								for name, field in orderedPairs(hashed_list) do 
									table.insert(ordered_idxes, field:get_name())
								end
								o_tbl.ordered_fields_idxes = ordered_idxes
							end
						end
						
						if (get_table_size(o_tbl.fields) > max_elem_sz) then
							for j = 1, #ordered_idxes, max_elem_sz do 
								j = math.floor(j)
								local this_limit = (#ordered_idxes < j+max_elem_sz and #ordered_idxes) or j+max_elem_sz
								local fname = (#ordered_idxes >= max_elem_sz) and ordered_idxes[j] --o_tbl.fields[ ordered_idxes[j] ]:get_name()
								if not fname or imgui.tree_node_str_id(key_name .. "Fields" .. j, "Fields " .. j .. " - " 
								.. math.floor((j+max_elem_sz-1 < #ordered_idxes and j+max_elem_sz-1) or #ordered_idxes) .. " --  " .. (fname:match("%<(.+)%>") or fname)) then
									for i = j, (this_limit==j+max_elem_sz and this_limit-1) or this_limit  do 
										local field = o_tbl.propdata.fields[ ordered_idxes[i] ]
										if field == nil then break end
										was_changed = show_field(m_obj, field, key_name) or was_changed
									end
									if #ordered_idxes >= max_elem_sz then
										imgui.tree_pop()
									end
								end
							end
						else
							--for i, field_name in ipairs(o_tbl.propdata.field_names) do
							for i = 1, #ordered_idxes do 
								was_changed = show_field(m_obj, o_tbl.fields[ ordered_idxes[i] ], key_name) or was_changed
							end
						end
					imgui.end_rect(3)
					--imgui.pop_id()
				end
				
				if o_tbl.props then
					local props = o_tbl.props
					if o_tbl.sort_alphabetically then
						o_tbl.ordered_props_idxes = o_tbl.ordered_props_idxes or {}
						props = o_tbl.ordered_props_idxes
						if props[1] == nil then --or ((#props > SettingsCache.max_element_size) and imgui.button("Clear Props Cache")) then 
							local hashed_list = {}; for i, prop in ipairs(o_tbl.props) do hashed_list[prop.name] = i end
							props = {}
							for name, idx in orderedPairs(hashed_list) do 
								table.insert(props, o_tbl.props[idx])
							end
							o_tbl.ordered_props_idxes = props
						end
					end
					if #props > max_elem_sz then 
						for j = 1, #props, max_elem_sz do 
							j = math.floor(j)
							local this_limit = (#props < j+max_elem_sz and #props) or j+max_elem_sz
							if #props < max_elem_sz or imgui.tree_node_str_id(key_name .. "Properties" .. j, "Properties " .. j .. " - " 
							.. math.floor((j+max_elem_sz-1 < #props and j+max_elem_sz-1) or #props) .. " --  " .. props[j].name ) then
								for i = j, (this_limit==j+max_elem_sz and this_limit-1) or this_limit  do 
									props[i].index = i
									was_changed = show_prop(m_obj, props[i], key_name) or was_changed
								end
								if #props >= max_elem_sz then
									imgui.tree_pop()
								end
							end
						end
					else
						for i, prop in ipairs(props) do 
							prop.index = i
							was_changed = show_prop(m_obj, prop, key_name) or was_changed
						end 
					end
				end
				
				if not o_tbl.do_auto_expand then
					imgui.tree_pop()
				end
			end
			
			if o_tbl.elements then 
				show_managed_objects_table(m_obj, o_tbl.elements, o_tbl, key_name, true)
			elseif o_tbl.is_vt == "parse" then -- o_tbl.name == "Guid" then
				local vt_as_string = m_obj:call("ToString()")
				changed, vt_as_string = show_imgui_text_box("Parse String", vt_as_string, o_tbl, (not prop or prop.set) and not was_changed, key_name .. "Guid", true)
				if changed then 
					--m_obj = m_obj:call("Parse(System.String)", vt_as_string) or m_obj
					--m_obj:call("Parse(System.String)", vt_as_string)
					if m_obj[".ctor(System.String)"] then
						m_obj = m_obj:call(".ctor(System.String)", vt_as_string) or m_obj
					else
						m_obj = m_obj:call("Parse(System.String)", vt_as_string) or m_obj
					end
				end
				if o_tbl.type:is_a("System.Guid") then 
					o_tbl.msg = o_tbl.msg or static_funcs.guid_method:call(nil, m_obj) 
					if o_tbl.msg and o_tbl.msg ~= "" then
						imgui.text(o_tbl.msg)
					elseif scene:call("findGameObject(System.Guid)", m_obj) then 
						o_tbl.found_object = o_tbl.found_object or scene:call("findGameObject(System.Guid)", m_obj)
						if imgui.tree_node_str_id(key_name .. "FObj", o_tbl.found_object:call("get_Name")) then
							imgui.managed_object_control_panel(o_tbl.found_object)
							imgui.tree_pop()
						end
					elseif tds.guid and tds.guid:get_method("checkAsFlag") and tds.guid:get_method("checkAsFlag"):call(nil, m_obj) ~= nil then 
						imgui.text("As Flag: " .. tostring(tds.guid:get_method("checkAsFlag"):call(nil, m_obj)))
					end
				end
			end
		imgui.end_rect(3)
		imgui.pop_id()
		
		return (changed or was_changed), m_obj
	end
end

--Removes a GameObject from most arrays
clear_object = function(xform)
	if xform then
		local is_player = (player and (player.xform == xform))
		if is_player then player = nil end
		if GameObject.clear_GrabObject then 
			GameObject.clear_GrabObject(nil, xform)
		end
		if GameObject.clear_AnimObject then 
			GameObject.clear_AnimObject(nil, xform)
		end
		if GameObject.clear_Spawn then 
			GameObject.clear_Spawn(nil, xform, is_player)
		end
		held_transforms[xform] = nil
		--Collection[xform] = nil
		if SettingsCache.Collection_data.sel_obj and SettingsCache.Collection_data.sel_obj.xform == xform then SettingsCache.Collection_data.sel_obj = nil end
		if player and player.xform == xform then player = nil end
		if xform.get_address then
			log.info("Removed lua objects with transform " .. xform:get_address())
			GameObject.dead_addresses[xform] = GameObject.dead_addresses[xform] or 0
		end
	end
end

--Material class and its supporting functions --------------------------------------------------------------------------------------------------
--Class for holding one RE Engine material:
local Material = {
	
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o.id = args.id
		o.anim_object = args.anim_object
		o.anim_object.update_materials = true
		o.mesh = args.mesh or o.anim_object.mesh
		o.on = true
		o.name = args.name or o.mesh:call("getMaterialName", o.id)
		o.flags = args.flags or {}
		o.variable_names = args.variable_names or {}
		o.variable_types = args.variable_types or {}
		o.variables = args.variables or {}
		o.orig_vars = {}
		o.deferred_vars = {}
		o.var_names_dict = {}
		o.multi = {}
		o.tex_num = o.mesh:call("getMaterialTextureNum", o.id)
		o.textures = args.textures or {}
		o.saved_variables = saved_mats[o.anim_object.name_w_parent] and saved_mats[o.anim_object.name_w_parent].m[o.anim_object.mesh_name] 
			and saved_mats[o.anim_object.name_w_parent].m[o.anim_object.mesh_name][o.name] or {texs={},vars={},toggled=self.on}
		
		if o.name then 
			if isRE2 or isRE3 or isDMC then
				o.on = (o.mesh:read_byte(0xE8 + 4 * (o.id >> 5)) & (1 << o.id)) ~= 0
			else
				o.on = o.mesh:call("getMaterialsEnable", o.id)
			end
			o.var_num = o.mesh:call("getMaterialVariableNum", o.id)
			if o.tex_num > 0 and not o.textures[1] then 
				o.tex_idxes = {}
				for i=1, o.tex_num do
					local texture = o.mesh:call("getMaterialTexture", o.id, i-1)
					if not texture then 
						o.tex_num = i-1
						break 
					end
					texture = texture:add_ref()
					add_resource_to_cache(texture)
					table.insert(o.textures, texture)
				end
				--if o.saved_variables then
				--	o.saved_variables.texs = o.textures
				--end
			end
			for i=1, o.var_num do
				local var_name = o.mesh:call("getMaterialVariableName", o.id, i-1)
				table.insert(o.variable_names, var_name)
				if isSF6 and var_name:find("CustomizeColor") then
					o.is_cmd = true
				end
				o.var_names_dict[var_name] = i
				local type_of = o.mesh:call("getMaterialVariableType", o.id, i-1)
				table.insert(o.variable_types, type_of)
				--local saved_variable = o.saved_variables and o.saved_variables.vars[i]
				if type_of == 1 then 
					table.insert(o.variables, o.mesh:call("getMaterialFloat", o.id, i-1))
				elseif type_of == 4 then 
					table.insert(o.variables, o.mesh:call("getMaterialFloat4", o.id, i-1))
				else
					table.insert(o.variables, o.mesh:call("getMaterialBool", o.id, i-1))
				end
			end
			for i, var in ipairs(o.variables) do 
				if o.variable_types[i] == 4 then
					table.insert(o.orig_vars, Vector4f.new(var.x, var.y, var.z, var.w))
				else
					table.insert(o.orig_vars, var)
				end
			end
		end
        return setmetatable(o, self)
	end,
	
	--Changes material variables, up to multiple at once from multiple related objects:
	change_multi = function(self, og_var_name, og_var_id, og_diff, og_object)
		og_object = og_object or self.anim_object
		local changed_objs = {[og_object.xform]=og_object}
		
		local function recurse_multi(mat, var_name, var_id, diff, object)
			object = object or mat.anim_object	
			mat.multi[var_id] = mat.multi[var_id] or {}
			if mat.multi[var_id].do_multi then 
				
				mat.multi[var_id].search_terms = mat.multi[var_id].search_terms or {}
				mat.multi[var_id].search_terms[1] = mat.multi[var_id].search_terms[1] or mat.multi[var_id].search_term or ""
				
				for m, other_mat in ipairs(object.materials or {}) do 
					for t, search_term in ipairs(mat.multi[var_id].search_terms) do
						if other_mat ~= mat and (search_term == "" or other_mat.name:lower():find(search_term:lower()))  then 
							local other_id = other_mat.var_names_dict[var_name]
							local other_var = other_mat.on and other_mat.variables[other_id]
							if other_var then 
								if not diff then 
									other_mat.variables[other_id] = (other_mat.variable_types[other_id] == 4 and Vector4f.new(other_mat.orig_vars[other_id].x, other_mat.orig_vars[other_id].y, other_mat.orig_vars[other_id].z, other_mat.orig_vars[other_id].w)) or other_mat.orig_vars[other_id] --for reset
								elseif other_mat.variable_types[other_id] == 4 then
									--for changing only by the amount of difference changed in the original mat:
									--other_mat.variables[other_id] = Vector4f.new(other_var.x + diff.x, other_var.y + diff.y, other_var.z + diff.z, other_var.w + diff.w) or (other_var + diff) 
									--for changing to exactly the value of the original mat:
									other_mat.variables[other_id] = Vector4f.new(mat.variables[var_id].x, mat.variables[var_id].y, mat.variables[var_id].z, mat.variables[var_id].w) or (mat.variables[var_id]) 
								end
								table.insert(other_mat.deferred_vars, other_mat.var_names_dict[var_name])
								other_mat.anim_object.update_materials = true
								changed_objs[object.xform] = object
							end
						end
					end 
				end
				
				if SettingsCache.affect_children then 
					for i, child in ipairs(object.children or {}) do
						if child ~= mat.anim_object.xform then 
							held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
							recurse_multi(mat, var_name, var_id, diff, held_transforms[child]) --change children
						end
					end
					if mat.anim_object.mesh_name_short and object==mat.anim_object then 
						
						local parent = object.pairing and (object.pairing.xform == object.parent) and object.pairing
						
						if not parent then --check sibling gameobjects of original gameobject be checking if the parent's gameobject has the same 4 chars of mesh name:
							parent = object.parent and held_transforms[object.parent] or GameObject:new_AnimObject{ xform=object.parent }
							parent = (parent and (parent.name:find(mat.anim_object.mesh_name_short:sub(1, 4)) or (figure_mode and (isRE2 or isRE3) and parent.name:find("_figure")))) and parent
						end
						if parent then
							for i, child in ipairs(parent.children or {}) do
								if child ~= mat.anim_object.xform then 
									held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
									recurse_multi(mat, var_name, var_id, diff, held_transforms[child])
								end
							end
						end
					end
				end
			end
		end
		
		recurse_multi(self, og_var_name, og_var_id, og_diff, og_object)
		
		og_object.shared_material_objects = changed_objs
	end,
	
	--Displays one material variable from Material class in imgui:
	draw_material_variable = function(self, var_name, v)
		imgui.push_id(self.mesh:get_address() + v)
		imgui.begin_rect()
			
			--[[if self.variables[v] ~= self.orig_vars[v] then 
				imgui.text("*")
				imgui.same_line()
			end]]
			
			local can_reset = (self.variables[v] ~= self.orig_vars[v])
			if can_reset then imgui.begin_rect() imgui.begin_rect() end
			if imgui.button(var_name) then 
				self.anim_object.update_materials = true
				self.variables[v] = self.variable_types[v] == 4 and Vector4f.new(self.orig_vars[v].x, self.orig_vars[v].y, self.orig_vars[v].z, self.orig_vars[v].w) or self.orig_vars[v]
				table.insert(self.deferred_vars, v)
				self:change_multi(var_name, v)
			end
			if can_reset then 
				imgui.end_rect(2) 
				imgui.end_rect(3)
				imgui.same_line()
				imgui.text("*")
			else
				imgui.same_line()
				imgui.text("  ")
			end
			
			imgui.same_line()
			self.multi[v] = self.multi[v] or {}
			changed, self.multi[v].do_multi = imgui.checkbox("Change Multiple", self.multi[v].do_multi)
			
			if self.is_cmd and (var_name:find("Customize") or (UserFile and find_index(UserFile.sf6_cmd_param_names, var_name))) then
				imgui.same_line()
				imgui.text_colored("CMD", 0xFFAAFFFF)
			end
			
			local new_var =  self.variable_types[v] == 4 and Vector4f.new(self.variables[v].x, self.variables[v].y, self.variables[v].z, self.variables[v].w) or self.variables[v]
			
			if self.variable_types[v] == 1 then 
				changed, new_var = imgui.drag_float(var_name, new_var, 0.01, -10000, 10000)
			elseif self.variable_types[v] == 4 then
				local was_changed = false
				changed, new_var = show_imgui_vec4(new_var, var_name)
			else
				changed, new_var = imgui.checkbox(var_name, new_var)
			end
			
			if changed then 
				self.anim_object.update_materials = true
				table.insert(self.deferred_vars, v)
				self.variables[v] = new_var
				self:change_multi(var_name, v, new_var - self.variables[v]) 
			end
			if self.multi[v].do_multi then 
				changed, self.multi[v].search_term = imgui.input_text("Search Terms", self.multi[v].search_term or self.last_search_terms)
				self.multi[v].search_terms = self.multi[v].search_terms or {}
				self.multi[v].search_terms[1] = self.multi[v].search_terms[1] or self.multi[v].search_term
				if changed then
					self.last_search_terms = self.multi[v].search_term
					self.multi[v].search_terms  = split(self.multi[v].search_term, " ") or table.pack(self.multi[v].search_term)
				end
			end
		imgui.end_rect(3)
		imgui.spacing()
		imgui.pop_id()
	end,
	
	--Draw the whole material menu in imgui
	draw_imgui_mat = function(self)
		imgui.push_id(self.name)
			changed, self.on = imgui.checkbox("", self.on)
			if changed then
				self.mesh:call("setMaterialsEnable", self.id, self.on)
			end
			imgui.same_line()
			if imgui.tree_node(self.name) then
				if not next(self.variables) then 
					self.anim_object:set_materials()
					return
				end
				imgui.spacing()
				imgui.begin_rect()
				if self.textures[1] and imgui.tree_node_colored(1, "", "Textures", 0xFFAAFFFF) then
					self.tex_idxes = self.tex_idxes or {}
					for t, texture in ipairs(self.textures) do 
						local tex_path
						self.tex_idxes[t], tex_path = add_resource_to_cache(texture)
						local tex_name = texture:call("ToString()"):match("^.+%[@?(.+)%]")
						local mat_name = self.mesh:call("getMaterialTextureName", self.id, t-1) or t
						--local mat_name = ({pcall(self.mesh.call, self.mesh, "getMaterialTextureName", self.id, t-1)})
						--mat_name = mat_name[1] and mat_name[2] or t
						changed, self.tex_idxes[t] = imgui.combo((mat_name or t), self.tex_idxes[t], RN.tex_resource_names) --self.tex_idxes[t] or find_index(RN.tex_resource_names, tex_name) or 1
						if changed then 
							local mat_var_idx = self.mesh:call("getMaterialVariableIndex", self.id, hashing_method(mat_name)) 
							add_resource_to_cache(RSCache.tex_resources[ RN.tex_resource_names[ self.tex_idxes[t] ] ])
							deferred_calls[self.mesh] = { func="setMaterialTexture", args={self.id, (mat_var_idx ~= 255) and mat_var_idx or t-1, RSCache.tex_resources[ RN.tex_resource_names[ self.tex_idxes[t] ] ] } }
							self.textures[t] = RSCache.tex_resources[ RN.tex_resource_names[ self.tex_idxes[t] ] ]
							
							if SettingsCache.remember_materials and self.saved_variables then
								self.saved_variables.texs[t] = self.textures[t]
							end
						end
					end
					imgui.tree_pop()
				end
				imgui.end_rect(3)
				imgui.spacing()
			
				for v, var_name in ipairs(self.variable_names) do  
					self:draw_material_variable(var_name, v)
				end
				
				if imgui.tree_node("[Lua]") then 
					read_imgui_element(self)
					imgui.tree_pop()
				end
				
				imgui.tree_pop() 
			end
		imgui.pop_id()
	end,
	
	load_all_mats_from_json = function(self)
		local new_saved_mats = {files={}, names_map={}, names_indexed={}}
		local files = fs.glob([[EMV_Engine\\Saved_Materials\\.*.json]])
		for i, path in ipairs(files) do
			local loaded_json_tbl = json.load_file(path) or {}
			if next(loaded_json_tbl) then
				local name = path:match("^.+\\(.+)%.")
				table.insert(new_saved_mats.files, path)
				table.insert(new_saved_mats.names_indexed, name)
				new_saved_mats.names_map[name] = #new_saved_mats.files
				new_saved_mats[name] = jsonify_table(loaded_json_tbl, true)
			end
		end
		return new_saved_mats
	end,
	
	load_json_material = function(self)
		if SettingsCache.remember_materials then
			saved_mats[self.anim_object.name_w_parent] = saved_mats[self.anim_object.name_w_parent] or {m={}, mesh=self.anim_object.mpaths.mesh_path, mdf=self.anim_object.mpaths.mdf2_path, active=true}
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name] = saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name] or {}
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name] = saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name] or {texs={}, vars={}, toggled=self.on}
			self.saved_variables = saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name]
			local sv_container = saved_mats[self.anim_object.name_w_parent]
			if sv_container.active and self.saved_variables then 
				local new_def_call = deferred_calls[self.mesh] or {}
				self.variables = {}
				self.deferred_vars = {}
				for i=1, self.var_num do
					local saved_variable = self.saved_variables.vars[i]
					if saved_variable then
						local type_of = self.mesh:call("getMaterialVariableType", self.id, i-1)
						local var_name = self.mesh:call("getMaterialVariableName", self.id, i-1)
						if (type_of==4 and type(saved_variable)=="number") or (type_of~=4 and type(saved_variable)=="table") then 
							re.msg("Mismatched saved variables!")
							self.saved_variables = {}
							--return
						end	
						if type_of == 4 then						
							table.insert(self.variables, Vector4f.new(saved_variable.x, saved_variable.y, saved_variable.z, saved_variable.w))
						else
							table.insert(self.variables, saved_variable)
						end
						table.insert(self.deferred_vars, i)
					end
				end
				if next(self.saved_variables.texs or {}) then
					for i=1, self.tex_num do 
						local tex_typename = self.mesh:call("getMaterialTextureName", self.id, i-1)
						if (self.textures[i]:call("ToString()"):lower() ~= self.saved_variables.texs[i]:call("ToString()"):lower()) then  --self.saved_variables.texs[i] and self.textures[i] and 
							local mat_var_idx = self.mesh:call("getMaterialVariableIndex", self.id, hashing_method(tex_typename)) 
							table.insert(new_def_call, { func="setMaterialTexture", args={self.id, (mat_var_idx ~= 255) and mat_var_idx or i-1, self.saved_variables.texs[i] } } )
							self.textures[i] = self.saved_variables.texs[i]
						end
					end
				end
				if self.saved_variables.toggled ~= nil then 
					self.on = self.saved_variables.toggled
					self.mesh:call("setMaterialsEnable", self.id, self.on)
				end
				deferred_calls[self.mesh] = new_def_call[1] and new_def_call
			end
			--saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name] = self.saved_variables
		end
	end,
	
	save_json_material = function(self)
		if SettingsCache.remember_materials then 
			saved_mats[self.anim_object.name_w_parent] = saved_mats[self.anim_object.name_w_parent] or {m={}, mesh=self.anim_object.mpaths.mesh_path, mdf=self.anim_object.mpaths.mdf2_path}
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name] = saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name] or {}
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name] = saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name] or {texs={}, vars={}, toggled=self.on}
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name].vars = self.variables
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name].texs = self.textures
			saved_mats[self.anim_object.name_w_parent].m[self.anim_object.mesh_name][self.name].toggled = self.on
			saved_mats[self.anim_object.name_w_parent].active = true
		end
	end,
	
	update = function(self)
		
		if self.var_num then 
			for v=1, self.var_num do
				pcall(function()
					self.mesh:call("get" .. mat_types[self.variable_types[v]], self.id, v-1)
				end) --random ass nonsense bug in RE7
			end
		end
		
		--[[if self.tex_num > 0 and not self.textures[1] then 
			self.tex_idxes = {}
			for i=1, self.tex_num do
				local texture = self.mesh:call("getMaterialTexture", self.id, i-1)
				if not texture then 
					self.tex_num = i-1
					break 
				end
				add_resource_to_cache(texture:add_ref())
				table.insert(self.textures, texture)
			end
			if self.saved_variables then
				self.saved_variables.texs = self.textures
			end
		end]]
	end,
}

--Resets saved material settings:
local function reset_material_settings(object)	
	if object.mesh_name and saved_mats[object.name_w_parent] then
		saved_mats[object.name_w_parent].active = false
		if saved_mats[object.name_w_parent] and saved_mats[object.name_w_parent].m[object.mesh_name] then 
			saved_mats[object.name_w_parent].m[object.mesh_name] = nil 
			json.dump_file("EMV_Engine\\Saved_Materials\\" .. object.name_w_parent .. ".json", {})
		end
		if SettingsCache.affect_children and object.children then 
			for i, child in ipairs(object.children) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
				reset_material_settings(held_transforms[child])
			end
		end
	end
end

--Displays one full material from the Material class in imgui:
show_imgui_mats = function(anim_object)
	
	if anim_object.pairing and (not anim_object.mesh or not anim_object.mesh:call("getMesh")) then
		anim_object = anim_object.pairing
	end
	
	if SettingsCache.remember_materials then
		imgui.begin_rect()
			if imgui.button("Save New Defaults") then 
				for i, mat in ipairs(anim_object.materials) do
					mat:save_json_material()
				end
				json.dump_file("EMV_Engine\\Saved_Materials\\" .. anim_object.name_w_parent .. ".json", jsonify_table(saved_mats[anim_object.name_w_parent]))
			end
		imgui.end_rect(3)
		if anim_object.mesh_name and saved_mats[anim_object.name_w_parent] and not imgui.same_line() and imgui.button(next(saved_mats[anim_object.name_w_parent].m) and "Clear New Defaults" or "[Cleared]") then 
			reset_material_settings(anim_object)
			saved_mats = Material.load_all_mats_from_json()
		end
		if saved_mats[anim_object.name_w_parent] then 
			imgui.same_line()
			changed, saved_mats[anim_object.name_w_parent].swap_mesh = imgui.checkbox("Load Swapped Mesh", saved_mats[anim_object.name_w_parent].swap_mesh)
			anim_object.mat_data = anim_object.mat_data or {}
			if changed or not anim_object.mat_data.swappables then 
				local current_file =  json.load_file(saved_mats.files[ saved_mats.names_map[anim_object.name_w_parent] ])
				if current_file then 
					current_file.swap_mesh = saved_mats[anim_object.name_w_parent].swap_mesh
					json.dump_file("EMV_Engine\\Saved_Materials\\" .. anim_object.name_w_parent .. ".json", current_file)
					anim_object.mat_data.swappables = {}
					anim_object.mat_data.current_swap_name = saved_mats[anim_object.name_w_parent].mesh
					for mesh_path, sub_tbl in orderedPairs(current_file.m) do 
						table.insert(anim_object.mat_data.swappables, mesh_path)
					end
				end
			end
			if imgui.button("Load") then
				local tmp = saved_mats[anim_object.name_w_parent].swap_mesh
				saved_mats = Material.load_all_mats_from_json()
				saved_mats[anim_object.name_w_parent].swap_mesh = tmp
				if not anim_object:load_json_mesh() then
					anim_object:set_materials()
				end
				for i, mat in ipairs(anim_object.materials) do
					mat:load_json_material()
				end
				anim_object.materials = nil
				anim_object:set_materials()
			end
			if saved_mats[anim_object.name_w_parent].swap_mesh and not imgui.same_line() then
				anim_object.mat_data.swap_idx = anim_object.mat_data.swap_idx or find_index(anim_object.mat_data.swappables, anim_object.mat_data.current_swap_name)
				changed, anim_object.mat_data.swap_idx = imgui.combo("Mesh Swap", anim_object.mat_data.swap_idx, anim_object.mat_data.swappables)
				if changed then 
					local current_file =  json.load_file(saved_mats.files[ saved_mats.names_map[anim_object.name_w_parent] ])
					current_file.mesh = anim_object.mat_data.swappables[ anim_object.mat_data.swap_idx ]
					local new_mdf = (RSCache.mesh_resources[current_file.mesh:lower()] and RSCache.mesh_resources[current_file.mesh:lower()][2])
					current_file.mdf = new_mdf and new_mdf:call("ToString()"):match("^.+%[@?(.+)%]") or current_file.mdf
					json.dump_file("EMV_Engine\\Saved_Materials\\" .. anim_object.name_w_parent .. ".json", current_file)
				end
			end
			--[[anim_object.mat_data.file_idx = find_index(saved_mats.names_indexed, anim_object.name_w_parent)
			if anim_object.mat_data.file_idx then 
				changed, anim_object.mat_data.file_idx = imgui.combo("Select File", anim_object.mat_data.file_idx, saved_mats.names_indexed)
				if changed then 
					anim_object.mat_data = {}
				end
			end]]
			--imgui.same_line()

		end
	end
	
	if RN.mesh_resource_names then
		anim_object.mpaths = anim_object.mpaths or {}
		changed, anim_object.current_mesh_idx = imgui.combo("Change Mesh: " .. anim_object.name, find_index(RN.mesh_resource_names, anim_object.mpaths.mesh_path) or anim_object.current_mesh_idx, RN.mesh_resource_names)
		if changed then 
			local m_r_name = RN.mesh_resource_names[ anim_object.current_mesh_idx]
			if type(RSCache.mesh_resources[m_r_name][1]=="string") then 
				add_resource_to_cache(RSCache.mesh_resources[m_r_name][1], RSCache.mesh_resources[m_r_name][2])
			end
			local msh_tbl = RSCache.mesh_resources[m_r_name]
			local old_parent = anim_object.parent
			anim_object:set_parent(0)
			anim_object.mesh:call("setMesh", msh_tbl[1])
			if old_parent then anim_object:set_parent(anim_object.parent) end
			
			if RSCache.mesh_resources[m_r_name][2] then 
				anim_object.mesh:call("set_Material", msh_tbl[2])
				anim_object.mpaths.mdf2_path = msh_tbl[2] and msh_tbl[2].call and msh_tbl[2]:call("ToString()"):match("^.+%[@?(.+)%]")
			end
			anim_object.mpaths.mesh_path = m_r_name
			anim_object:set_materials() 
		end
		
		changed, anim_object.current_mdf_idx = imgui.combo("Change Materials: " .. anim_object.name, find_index(RN.mdf2_resource_names, anim_object.mpaths.mdf2_path) or anim_object.current_mdf_idx, RN.mdf2_resource_names)
		if changed then 
			add_resource_to_cache(RSCache.mdf2_resources[ RN.mdf2_resource_names[anim_object.current_mdf_idx] ])
			anim_object.mesh:call("set_Material", RSCache.mdf2_resources[ RN.mdf2_resource_names[anim_object.current_mdf_idx] ])
			anim_object.mpaths.mdf2_path = RN.mdf2_resource_names[ anim_object.current_mdf_idx ]
			anim_object:set_materials() 
		end
	end
	
	local mesh = anim_object.mesh or (anim_object.materials and anim_object.materials[1] and anim_object.materials[1].mesh)
	if _G.RE_Resource and BitStream and mesh then
		
		if anim_object.materials.save_path_exists then
			local real_path = anim_object.materials.save_path_text:gsub("^reframework/data/", "")
			if imgui.button("Save MDF") then
				local mdfFile = MDFFile:new{filepath=real_path, mobject=mesh}
				if mdfFile:save(real_path) then 
					re.msg("Saved MDF file to:\n" .. anim_object.materials.save_path_text)
				end
				anim_object.materials.MDFFile = mdfFile
			end
			resource_ctx_menu("MDFFile", real_path, anim_object.materials)
			imgui.same_line()
		end
		
		if anim_object.materials.save_path_text==nil and anim_object.mpaths.mdf2_path then
			anim_object.materials.save_path_text = "$natives/" .. (((sdk.get_tdb_version() <= 67) and "x64/") or "stm/") .. anim_object.mpaths.mdf2_path .. ((MDFFile and MDFFile.extensions[game_name]) or "")
			--anim_object.materials.save_path_text = "reframework/data/REResources/" .. anim_object.mpaths.mdf2_path:match("^.+/(.+)$") .. ((MDFFile and MDFFile.extensions[game_name]) or "")
		end
		
		changed, anim_object.materials.save_path_text = imgui.input_text("Modify MDF File" .. ((anim_object.materials.save_path_exists and "") or " (Does Not Exist)"), anim_object.materials.save_path_text) --
		if changed or anim_object.materials.save_path_exists==nil then
			anim_object.materials.save_path_exists = BitStream.checkFileExists(anim_object.materials.save_path_text:gsub("^reframework/data/", ""))
		end
		
		local tooltip_msg = "Access files in the 'REFramework\\data\\' folder.\nStart with '$natives\\' to access files in the natives folder.\nInput the location of the original MDF file for this mesh"
		imgui.tooltip(tooltip_msg)
		
		if anim_object.materials.is_cmd and rsz_parser then 
			if rsz_parser.IsInitialized() then --SF6 CustomizeColors values
				if anim_object.materials.cmd_save_path_exists then
					local real_path = anim_object.materials.cmd_save_path_text:gsub("^reframework/data/", "")
					if imgui.button("Save CMD") then
						local cmdFile = UserFile:new{filepath=real_path}
						cmdFile:save(real_path, false, false, anim_object.materials)
						anim_object.materials.UserFile = cmdFile
						imgui.same_line()
					end
					resource_ctx_menu("UserFile", real_path, anim_object.materials)
					imgui.same_line()
				end
				
				if anim_object.materials.cmd_save_path_text == nil then
					pcall(function()
						local esf_no = anim_object.name:match("esf(.+)v")
						local color_slot = string.format("%03d", anim_object.parent_obj.components_named.PlayerColorController.ColorNum + 1)
						local costume_slot = anim_object.parent_obj.components_named.PlayerColorController.ColorData:get_Path():match("esf%d%d%d/(.+)/")
						anim_object.materials.cmd_save_path_text = ("$natives/stm/product/model/esf/esf"..esf_no.."/"..costume_slot.."/esf"..esf_no.."_"..costume_slot.."_cmd_"..color_slot..".user.2")
					end)
				end
				
				changed, anim_object.materials.cmd_save_path_text = imgui.input_text("Modify CMD File" .. ((anim_object.materials.cmd_save_path_exists and "") or " (Does Not Exist)"), anim_object.materials.cmd_save_path_text) --
				if changed or anim_object.materials.cmd_save_path_exists==nil then
					anim_object.materials.cmd_save_path_exists = BitStream.checkFileExists(anim_object.materials.cmd_save_path_text:gsub("^reframework/data/", ""))
				end
			else
				imgui.text_colored("Save CMD: Failed to initialize reframework\\data\\rsz\\rszsf6.json !\nDownload this file from https://github.com/alphazolam/RE_RSZ", 0xFF0000FF)
			end
		end
		
		imgui.tooltip(tooltip_msg)
		if anim_object.materials.MDFFile and imgui.tree_node("[MDF Lua]") then 
			anim_object.materials.MDFFile:displayImgui()
			imgui.tree_pop()
		end
		if anim_object.materials.UserFile and imgui.tree_node("[CMD Lua]") then 
			anim_object.materials.UserFile:displayImgui()
			imgui.tree_pop()
		end
	end
	
	for i, mat in ipairs(anim_object.materials) do
		mat:draw_imgui_mat()
	end
end

--Function to manage saved materials:
--[[local function imgui_saved_materials_menu() 
	local idx = 0
	if imgui.button("Clear Saved Materials") then 
		_G.saved_mats = {}
	end
	for key, sub_tbl in orderedPairs(_G.saved_mats) do
		idx = idx + 1
		local xform, obj = next(sub_tbl.__objects or {})
		if obj then 
			if imgui.tree_node_str_id(key .. idx, key) then 
				obj.materials.open = 2
				imgui_anim_object_viewer(obj)
				imgui.tree_pop()
			elseif obj.materials.open == 2 then
				obj.materials.open = nil
			end
		elseif imgui.tree_node_str_id(key .. idx, key) then
			read_imgui_pairs_table(sub_tbl, key .. idx)
			imgui.tree_pop()
		end
	end
end]]

--Handler for full GameObject/GameObject/GameObject type classes:
local function imgui_anim_object_viewer(anim_object, obj_name, index)

	if not anim_object or not anim_object.xform then return end
	obj_name = obj_name or anim_object.name	
	held_transforms[anim_object.xform] = held_transforms[anim_object.xform] or GameObject:new_AnimObject{xform=anim_object.xform}
	anim_object = held_transforms[anim_object.xform]
	if not anim_object then return end
	anim_object.opened = nil
	
	if imgui.tree_node_ptr_id(anim_object.gameobj, obj_name) then --(anim_object.components and anim_object.components[1]) or touched_gameobjects ~= nil)
		
		imgui.managed_object_control_panel(anim_object.xform, "Transform", anim_object.name)
		imgui.tree_pop()
	end
	
	if (not index or index == 1) or anim_object.children then
		local tree_name = anim_object.parent and "Parent"
		tree_name = (anim_object.children and (((tree_name and tree_name .. " & Child") or "Child") .. (anim_object.children[2] and "ren" or ""))) or tree_name
		local is_only_child = (tree_name == "Child") and "Child"
		local is_only_parent = (tree_name == "Parent") and "Parent"
		
		if (anim_object.parent or anim_object.children) and ((is_only_child or is_only_parent) or imgui.tree_node_ptr_id(anim_object.xform, tree_name)) then
			anim_object.opened = true
			if anim_object.parent then 
				--if not is_only_parent then imgui.begin_rect() end
					held_transforms[anim_object.parent] = held_transforms[anim_object.parent] or GameObject:new_AnimObject{ xform=anim_object.parent }
					if imgui.tree_node_str_id(obj_name .. "Prt", is_only_parent or held_transforms[anim_object.parent].name) then
						imgui_anim_object_viewer(held_transforms[anim_object.parent], held_transforms[anim_object.parent].name)
						--imgui.managed_object_control_panel(anim_object.parent, "Parent", held_transforms[anim_object.parent].name)
						imgui.tree_pop()
					end
				--if not is_only_parent then imgui.end_rect() end
			end
			
			if not (is_only_child or is_only_parent) then 
				imgui.text("  Children:")
				imgui.text("  ")
				imgui.same_line()
				imgui.begin_rect()
			end
			for i, child in ipairs(anim_object.children or {}) do
				local child_obj = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
				if child_obj then
					if imgui.tree_node_str_id(obj_name .. "Ch" .. i,  is_only_child or child_obj.name) then
						imgui_anim_object_viewer(child_obj, "Object")
						--imgui.managed_object_control_panel(child, "Ch" .. i, held_transforms[child].name)
						imgui.tree_pop()
					end
				else
					anim_object.children = get_children(anim_object.xform)
					break
				end
			end
			if not (is_only_child or is_only_parent) then
				imgui.end_rect(1)
				imgui.tree_pop()
			end
		end
	end
	
	--[[if (not anim_object.same_joints_constraint or not anim_object.parent or anim_object.body_part == "Face") and anim_object.joints and imgui.tree_node("Poser") then
		anim_object:imgui_poser()
		imgui.tree_pop()
	end]]
	
	if not figure_mode and not cutscene_mode and anim_object.behaviortrees and anim_object.behaviortrees[1] then --and imgui.tree_node_str_id(anim_object.name .. "Trees", "Action Monitor") then 
		anim_object.opened = true
		anim_object:action_monitor()
	end
	
	--if anim_object.mesh and not anim_object.materials then 
	--	anim_object:set_materials() 
	--end
	
	if anim_object.materials and imgui.tree_node_ptr_id(anim_object.mesh, "Materials") then
		show_imgui_mats(anim_object) 
		imgui.tree_pop()
	end
end

--Display a managed object in imgui
local function handle_obj(managed_object, title)
	title = title or "Object"
	if sdk.is_managed_object(managed_object) then 
		local typedef = managed_object:get_type_definition()
		if typedef:is_a("via.Component") then 
			local gameobj = get_GameObject(managed_object)
			local xform = gameobj:call("get_Transform")
			held_transforms[xform] = held_transforms[xform] or GameObject:new_AnimObject{gameobj=gameobj, xform=xform}
			imgui_anim_object_figure_viewer(held_transforms[xform], title)
		else
			imgui.managed_object_control_panel(managed_object, title)
		end
	else
		imgui.managed_object_control_panel(managed_object, title)
	end
end

--Displays the "Collection" menu in imgui
local function show_collection()
	
	local dump_collection
	cd = SettingsCache.Collection_data
	
	cd.recurse = cd.recurse or function(tbl)
		local new_tbl = merge_tables({}, tbl)
		for k, v in pairs(tbl) do
			if (SettingsCache.Collection_data.only_set_json_resources and ((type(v)~="string") or (v:sub(1,4)~="res:") or v:lower():find("error")) ) then  --
				new_tbl[k] = nil
			end
			if type(v) == "table" and #v < 140 then 
				new_tbl[k] = SettingsCache.Collection_data.recurse(v)
			end
		end
		tbl = new_tbl
		return (#tbl < 25) and tbl or nil
	end
	
	cd.setup = cd.setup or function(force)
		cd.collection_xforms = (not force and cd.collection_xforms or {}) or {}
		if force or not next(cd.collection_xforms) or (get_table_size(cd.collection_xforms) ~= get_table_size(Collection)) then
			local new_collection = {}
			for name, obj in pairs(Collection) do 
				if obj.xform then
					cd.collection_xforms[obj.xform] = obj.unique_name 
					new_collection[obj.unique_name] = obj
				elseif obj.__gameobj_name then
					new_collection[obj.__gameobj_name] = obj
				end
			end
			Collection = new_collection
		end
	end
	
	cd.setup()
	
	if imgui.button("Empty Collection") then 
		--Collection = {}
		local new_collection = merge_tables({}, Collection)
		for k, v in pairs(Collection) do 
			if not v.xform or not old_deferred_calls[logv(v.xform) .. " 1"] then 
				new_collection[k] = nil
				cd.collection_xforms[v.xform or 0] = nil
			end
		end
		Collection = new_collection
		dump_collection = true
	end
	
	imgui.same_line()
	if imgui.button("Remove Unfound Objects") then 
		Collection = jsonify_table(json.load_file("EMV_Engine\\Collection.json") or {}, true)
		for name, obj in pairs(Collection) do
			Collection[name] = obj.xform and obj or nil
		end
		dump_collection = true
	end
	
	if imgui.button("Search") then
		Collection = {}
		cd.do_filter = true
	end
	
	imgui.same_line()
	if imgui.button("Add") or cd.do_filter then
		cd.do_filter = nil
		if next(cd.search_for or {}) or cd.search_enemies or (cd.must_have.checked and cd.must_have.Component) then
			local must_have = {}
			cd.setup(true)
			if cd.must_have.checked then
				for i, result in ipairs(find(cd.must_have.Component)) do 
					must_have[result] = result
				end
			end
			new_collection = merge_tables({}, Collection)
			merged = cd.search_enemies and search("^[ep][ml]%d%d%d%d" .. (isDMC and "_?%d?%d?"  or "$"), cd.case_sensitive, true) or {}
			if isRE8 and cd.search_enemies then 
				merged = merge_tables(merged,  search("^ch%d%d_%d%d%d%d$", cd.case_sensitive, true) or {})
			end
			if cd.enable_component_search then
				for i, component_name in ipairs(cd.search_for) do
					if sdk.find_type_definition(component_name) then
						merged = merge_tables(merged, find(component_name, 1))
					end
				end
			else
				merged = merge_tables(merged, must_have)
			end
			
			if cd.enable_include_search then 
				for j, included_name in ipairs(cd.included) do 
					if included_name ~= "[New]" then
						merged = merge_tables({}, search(included_name, cd.case_sensitive, true))
					end
				end
			end
			
			for xform, result_xf in pairs(merged) do 
				if (not cd.must_have.checked or must_have[result_xf]) and not cd.collection_xforms[result_xf] then
					local name, is_excluded = get_GameObject(result_xf, true)
					if cd.enable_exclude_search then 
						for j, excluded_name in ipairs(cd.excluded) do 
							local lower_name = (cd.case_sensitive and name:lower()) or name
							local lower_ex_name = (cd.case_sensitive and excluded_name:lower()) or excluded_name
							if excluded_name ~= "[New]" and lower_name:find(lower_ex_name) then
								is_excluded = true
								break
							end
						end
					end
					if not is_excluded then
						local new_obj = held_transforms[result_xf] or GameObject:new{xform=result_xf}
						--new_obj.unique_name = new_obj.unique_name or resolve_duplicate_names(new_collection, new_obj:set_name_w_parent())
						new_collection[new_obj.unique_name] = new_obj
					end
				end
			end
			
			if cd.only_parents then
				for name, obj in pairs(new_collection) do --remove new objects that are children of other new objects
					if not Collection[name] then
						for nm2, obj2 in pairs(new_collection) do 
							if obj.name and obj2.name and is_child_of(obj.xform, obj2.xform) then 
								new_collection[name] = nil
							end
						end
					end
				end
			end
			
			Collection = merge_tables(Collection, new_collection)
			dump_collection = true
		end
		
	end
	
	imgui.same_line()
	if imgui.button("Re-Scan All") then 
		cd.setup(true)
		local new_collection = jsonify_table(json.load_file("EMV_Engine\\Collection.json") or {}, true)
		for name, obj in pairs(new_collection) do 
			if not cd.collection_xforms[obj.xform] then 
				Collection[obj.unique_name or obj.__gameobj_name] = obj --resolve_duplicate_names(new_collection, obj:set_name_w_parent())
			end
		end
		dump_collection = true
	end
	
	local do_reset
	imgui.same_line()
	if imgui.tree_node("Search Settings...") then
		imgui.text("	")
		imgui.same_line()
		imgui.begin_rect()
			if imgui.button("Reset to Default Terms") or not cd.must_have then
				do_reset = true
			end
			changed, cd.must_have.checked = imgui.checkbox("Must have this Component:", cd.must_have.checked)
			if cd.must_have.checked then 
				editable_table_field("Component", cd.must_have.Component, cd.must_have, nil, {check_add_func=(function(value) return sdk.find_type_definition(value) end)})
			else
				imgui.new_line()
				imgui.spacing()
			end
			cd.search_for = cd.search_for or {}
			if imgui.button("+") and (not cd.search_for[1] or sdk.find_type_definition(cd.search_for[#cd.search_for])) then 
				table.insert(cd.search_for, "[New]")
			end
			imgui.same_line()
			imgui.push_id(0)
				changed, cd.enable_component_search = imgui.checkbox("", cd.enable_component_search)
			imgui.pop_id()
			imgui.same_line()
			imgui.text("Must have one of these Components:")
			if cd.enable_component_search then
				for i, component_name in ipairs(cd.search_for or {}) do 
					editable_table_field(i, component_name, cd.search_for, nil, {check_add_func=(function(value) return sdk.find_type_definition(value) end)})
				end
			end
			
			for j = 1, 2 do
				imgui.push_id(j)
					local add_pressed
					local tbl_name = ({"excluded", "included"})[j]
					local bool_name = ({"enable_exclude_search", "enable_include_search"})[j]
					cd[tbl_name] = cd[tbl_name] or {}
					if imgui.button("+") then 
						add_pressed = true
						if cd[tbl_name][ #cd[tbl_name] ] ~= "[New]" then
							table.insert(cd[tbl_name], "[New]")
						end
					end
					imgui.same_line()
					changed, cd[bool_name] = imgui.checkbox("", cd[bool_name] or add_pressed)
					imgui.same_line()
					imgui.text((j == 1 and "Exclude these names from results:" or "Search for objects with any of these keywords:"))
					if cd[bool_name] then
						for i, term in ipairs(cd[tbl_name] or {}) do 
							imgui.text("	")
							imgui.same_line()
							editable_table_field(i, term, cd[tbl_name])
						end
					end
				imgui.pop_id()
			end
			changed, cd.search_enemies = imgui.checkbox("Find 'emXXXX' or 'plXXXX' names", cd.search_enemies)
			changed, cd.case_sensitive = imgui.checkbox("Case-sensitive names search", cd.case_sensitive)
			changed, cd.only_parents = imgui.checkbox("Exclude Children", cd.only_parents)
			
		imgui.end_rect(2)
		imgui.tree_pop()
	end
	
	local existing_objs, missing_objs = {}, {}
	for name, obj in orderedPairs(Collection) do
		if obj.xform then 
			table.insert(existing_objs, name)
		else
			table.insert(missing_objs, name)
		end
	end
	
	local sel_obj = Collection[cd.sel_obj_coll_key] or cd.sel_obj
	if sel_obj and sel_obj.set_transform then
		cd.sel_obj = sel_obj
		--sel_obj.created = true
	end
	
	local moved_last_obj
	if cd.new_args and cd.worldmatrix and (cd.sel_obj or cd.g_menu_open) then
		cd.worldmatrix[3].w = 1.0
		--local last_rot = not cd.gizmo_centers_on_selected and cd.worldmatrix:to_quat()
		if cd.sel_obj and cd.gizmo_centers_on_selected then
			cd.worldmatrix = cd.sel_obj.xform:call("get_WorldMatrix")
		end
		moved_last_obj, cd.worldmatrix = draw.gizmo(1234567890, cd.worldmatrix)
		--[[if moved_last_obj and last_rot and cd.sel_obj and last_rot == cd.worldmatrix:to_quat() then --if only moving position, update saved rotation to object's current rotation
			local new_pos = cd.worldmatrix[3]
			cd.worldmatrix = cd.sel_obj.xform:call("get_WorldMatrix")
			cd.worldmatrix[3] = new_pos
		end]]
	end
	
	imgui.text("Gizmo options:")
	imgui.text("	")
	imgui.same_line()
	
	if imgui.button("Move to Camera") then 
		cd.worldmatrix = last_camera_matrix
		moved_last_obj = true
	end
	
	imgui.same_line()
	if imgui.button("Reset rotation") then 
		local vec4 = cd.worldmatrix[3]
		cd.worldmatrix = Matrix4x4f.identity()
		cd.worldmatrix[3] = vec4
		moved_last_obj = true
	end

	
	if _G.grab and sel_obj and not imgui.same_line() and imgui.button("Grab Last") then
		grab(sel_obj.xform)
		sel_obj = last_grabbed_object or sel_obj
		Collection[sel_obj.unique_name] = sel_obj
	end
		
	imgui.same_line()
	changed, cd.gizmo_moves_selected = imgui.checkbox("Gizmo moves selected", cd.gizmo_moves_selected)
	if cd.gizmo_moves_selected then 
		imgui.same_line()
		changed, cd.gizmo_freeze_selected = imgui.checkbox("Freeze", cd.gizmo_freeze_selected)
		imgui.same_line()
		changed, cd.gizmo_centers_on_selected = imgui.checkbox("Center On", cd.gizmo_centers_on_selected)
	end
	
	if next(Collection) then
		imgui.text("Collected GameObjects:")
		for j = 1, 2 do 
			if j==2 then 
				if sel_obj and sel_obj.xform then 
					if imgui.tree_node("Selected: " .. sel_obj.name) then 
						imgui_anim_object_viewer(sel_obj)
						imgui.tree_pop()
					end
					if sel_obj.is_grabbed and sel_obj.packed_xform then
						cd.worldmatrix = trs_to_mat4(sel_obj.packed_xform)
					end
				else
					imgui.new_line()
				end
			end
			for i, coll_name in ipairs(j==1 and existing_objs or missing_objs) do 
				local obj = Collection[coll_name]
				local name = (obj.unique_name or obj.__gameobj_name) --.. (obj.char_name and (" (" .. obj.char_name .. ")") or "") 
				--or (obj.name_w_parent and resolve_duplicate_names(held_transforms, obj.name_w_parent, "name_w_parent")) 
				imgui.text("	")
				imgui.same_line()
				if obj.xform and obj.xform:read_qword(0x10) ~= 0 then
					obj.object_json = obj.object_json or jsonify_table({obj}, false, {convert_lua_objs=true})[1]
					imgui.push_id(name .. "X")
						local changed, is_selected = imgui.checkbox("", (cd.sel_obj and obj.xform==cd.sel_obj.xform))
						if changed then 
							if cd.sel_obj then --on un-selected:
								cd.sel_obj.force_center = nil 
								local vd = cd.sel_obj.xform._ or create_REMgdObj(cd.sel_obj.xform, true)
								vd.props_named._Position.freeze, vd.props_named._Rotation.freeze = true, true
								deferred_calls[cd.sel_obj.xform] = {{func="set_Position", args=vd.props_named._Position.value, vardata=vd.props_named._Position}, {func="set_Rotation", args=vd.props_named._Rotation.value, vardata=vd.props_named._Rotation}}
							end
							cd.sel_obj = is_selected and GameObject:new_AnimObject({xform=obj.xform}, obj) or nil
							cd.sel_obj_coll_key = cd.sel_obj and obj.unique_name
							if cd.sel_obj and not cd.same_joints_constraint then --on selected:
								obj.force_center, obj.aggressively_force_center, deferred_calls[obj.xform] = nil
								if metadata[obj.xform] then metadata[obj.xform].keep_alive = nil end
								cd.worldmatrix = obj.xform:call("get_WorldMatrix")
								if cd.gizmo_freeze_selected and obj.cog_joint then
									local vd = obj.cog_joint._ or create_REMgdObj(obj.cog_joint, true)
									if vd.props_named._LocalPosition then
										vd.props_named._LocalPosition.freeze = true
									end
									deferred_calls[obj.cog_joint] = {func="set_LocalPosition", args=obj.cog_joint:call("get_BaseLocalPosition"), vardata=vd.props_named._LocalPosition } --or {freeze=true}
									cd.worldmatrix[3] = (obj.cog_joint:call("get_Position") - obj.cog_joint:call("get_BaseLocalPosition")):to_vec4()
								end
								obj.sel_frozen = true
							end
						end
						imgui.same_line()
						if imgui.button("X") then 
							changed = true
							Collection[coll_name] = nil 
							dump_collection = true
						end
						if obj.created and not imgui.same_line() and imgui.button("Del") then 
							deferred_calls[obj.gameobj] = { func="destroy", args=obj.gameobj }
							--dump_collection = true
						end
						if obj.sel_frozen and not imgui.same_line() and imgui.button("Remove Offset") then 
							obj.sel_frozen = nil
							deferred_calls[obj.xform] = nil
							old_deferred_calls = {}
							if obj.cog_joint then 
								deferred_calls[obj.cog_joint] = nil
							end
							if obj.is_sel_obj then
								obj.is_sel_obj, cd.sel_obj, cd.sel_obj_coll_key = nil, nil, nil
							end
						end
					imgui.pop_id()
					imgui.same_line()
					if imgui.tree_node_str_id(tostring(obj.xform), name) then 
						imgui.text("	    ")
						imgui.same_line()
						imgui.begin_rect()
							imgui_anim_object_viewer(obj)
						imgui.end_rect(2)
						imgui.tree_pop()
					end
					obj.is_sel_obj = (cd.sel_obj and (cd.sel_obj.xform == obj.xform)) or nil
				elseif name then
					if obj.name then
						Collection[coll_name] = obj.object_json
						clear_object(obj.xform)
					else
						imgui.push_id(name .. "X")
							if imgui.button("X") then 
								Collection[coll_name] = nil 
								dump_collection = true
							end
							imgui.same_line()
							if imgui.button("Scan") then 
								file = json.load_file("EMV_Engine\\Collection.json")
								if file and file[coll_name] then
									new_entry = jsonify_table(file[coll_name], true)
									Collection[coll_name] = (next(new_entry) and new_entry) or Collection[coll_name]
								end
							end
						imgui.pop_id()
						imgui.same_line()
						imgui.text(name)
					end
					obj.__gameobj_name = name
				else
					Collection[coll_name] = nil
				end
			end
		end
	end
	
	imgui.new_line()
	if not cd.g_menu_open then imgui.begin_rect() end
		if imgui.button((cd.g_menu_open and "Collapse " or "Open ") .. "GameObject Spawner") then
			cd.g_menu_open = not cd.g_menu_open
		end
	if not cd.g_menu_open then imgui.end_rect(3) end
	
	imgui.spacing()
	
	if cd.g_menu_open then 
		--imgui.text(logv(cd.worldmatrix))
		
		local create_button_pressed
		cd.o_tbl = cd.o_tbl  or {go=true, button_only=true, components={}}
		if cd.new_g_name ~= "" then
			imgui.begin_rect()
				create_button_pressed = imgui.button("Create!")
			imgui.end_rect(3)
		end
		imgui.same_line()
		if imgui.button("Reset") then 
			do_reset = true
		end
		cd.new_args = cd.new_args or {}
		local file
		if cd.o_tbl.show_load_input then 
			imgui.same_line()
			changed, cd.only_set_json_resources = imgui.checkbox("Load Only Resources", cd.only_set_json_resources)
			imgui.same_line()
			changed, cd.new_args.load_children = imgui.checkbox("Load Children", cd.new_args.load_children)
			if cd.o_tbl.input_file_idx and (not cd.new_args.file or not cd.new_args.file.__dont_convert) and cd.o_tbl.files_list and cd.o_tbl.files_list.paths and cd.o_tbl.files_list.paths[cd.o_tbl.input_file_idx] then
				file = json.load_file(cd.o_tbl.files_list.paths[cd.o_tbl.input_file_idx])
			end
		end
		file = show_save_load_button(cd.o_tbl, "Load", cd.o_tbl.show_load_input and 1 or true) or file
		
		imgui.push_id(-1)
		imgui.text("Spawn Settings:")
		imgui.text("	")
		imgui.same_line()
		imgui.begin_rect()	
			if static_objs.spawned_prefabs_folder and imgui.button("Clear Spawned GameObjects") then 
				static_objs.spawned_prefabs_folder:call("deactivate")
				static_objs.spawned_prefabs_folder:call("activate")
			end
			if EMVSettings and not figure_mode then 
				imgui.same_line()
				changed, cd.new_args.add_to_anim_viewer = imgui.checkbox("Add to Animation Viewer", cd.new_args.add_to_anim_viewer)
			end
			static_funcs.init_resources()
			cd.new_components = cd.new_components or {"via.Transform", "via.render.Mesh", "via.motion.Motion"}
			changed, cd.new_g_name = imgui.input_text("Name", cd.new_g_name or "NewObject")
			changed, cd.new_g_parent_name = imgui.input_text("Parent Name", cd.new_g_parent_name)
			local try, loaded_parent = pcall(load("return " .. cd.new_g_parent_name))
			loaded_parent = try and loaded_parent and ((sdk.is_managed_object(loaded_parent) or (can_index(loaded_parent) and loaded_parent.set_parent)) and loaded_parent) or nil
			cd.new_args.parent = (loaded_parent and loaded_parent.xform) or loaded_parent
			local gameobj_parent = (cd.new_g_parent_name and scene:call("findGameObject(System.String)", cd.new_g_parent_name))
			cd.new_args.parent = cd.new_args.parent or gameobj_parent and gameobj_parent:call("get_Transform")
			local parent_joint
			--cd.worldmatrix = cd.worldmatrix or (last_impact_pos and last_impact_pos:length()>1 and last_impact_pos) or last_camera_matrix or Matrix4x4f.new()
			if tostring(cd.new_args.parent):find("RETransform%*") then 
				
				changed, cd.new_args.same_joints_constraint = imgui.checkbox("Same Joints Constraint", cd.new_args.same_joints_constraint)
				changed, cd.new_args.parent_joint = imgui.input_text("Attach to Parent Joint", cd.new_args.parent_joint)
				parent_joint = cd.new_args.parent:call("getJointByName", cd.new_args.parent_joint)
				if parent_joint then 
					local wm = parent_joint:call("get_WorldMatrix")
					--if imgui.button("Recenter") or not cd.has_parent_joint then
						cd.worldmatrix[3] = wm[3]
					--end
					cd.has_parent_joint = true
					cd.new_args.rot = cd.worldmatrix:to_quat():to_euler()--cd.new_args.rot or Vector3f.new(0,0,1.5)
					imgui.begin_rect()
						changed, cd.new_args.rot  = imgui.drag_float3("Parent Joint Rotation", cd.new_args.rot, 0.01, -360.0, 360.0) --show_imgui_vec4(cd.new_args.rot or Vector3f.new(0,0,1.5), "Parent Joint Rotation", nil, 0.01, true)
					imgui.end_rect(2)
				else
					cd.has_parent_joint = nil
				end
			end
			
			if imgui.button("+") and (not cd.new_components[1] or sdk.find_type_definition(cd.new_components[#cd.new_components])) then 
				table.insert(cd.new_components, "[New]")
			end
			
			imgui.same_line()
			imgui.text("Components:")
			for i, component_name in ipairs(cd.new_components) do 
				if component_name:gsub(" ", "") == "" then
					table.remove(cd.new_components, i)
					break
				else
					imgui.text("	")
					imgui.same_line()
					editable_table_field(i, component_name, cd.new_components, nil, {check_add_func=(function(str) return sdk.find_type_definition(tostring(str)) end)})
					
					if component_name == "via.render.Mesh" then 
						imgui.text("	  *")
						imgui.same_line()
						imgui.begin_rect()
							local tmp = cd.new_args.mesh
							if RN.mesh_resource_names then
								changed, cd.current_mesh_idx = imgui.combo("Select Mesh", cd.current_mesh_idx or find_index(RN.mesh_resource_names, cd.new_args.mesh or "") or 1, RN.mesh_resource_names)
								if changed then 
									cd.new_args.mesh = RN.mesh_resource_names[cd.current_mesh_idx]
									local mdf = RSCache.mesh_resources and RSCache.mesh_resources[RN.mesh_resource_names[cd.current_mesh_idx]]
									cd.new_args.mdf = (mdf and mdf[2] and mdf[2]:call("ToString()"):match("^.+%[@?(.+)%]")) or cd.new_args.mdf
								end
							end
							editable_table_field("mesh", (cd.new_args.mesh or (RN.mesh_resource_names and RN.mesh_resource_names[cd.current_mesh_idx]) or ""), cd.new_args, "Mesh", {check_add_func=(function(str) return str:find("%.mesh$") end)})
							editable_table_field("mdf2", (cd.new_args.mdf or ""), cd.new_args, "Material", {check_add_func=(function(str) return str:find("%.mdf2$") end)})
						imgui.end_rect(2)
					end
				end
			end
			
			cd.new_args.disabled_components = cd.new_args.disabled_components or {"via.motion.Motion"}
			if cd.o_tbl.show_load_input then
				
				local setup_comp_names
				cd.enabled_new_components = cd.enabled_new_components or {}
				
				if file then --when first loaded
					for key, value in pairs(file) do if type(value)=="table" then cd.new_args.name=key end end --just find the gameobject table, not knowing its name
					cd.new_args.given_name = cd.o_tbl.files_list.names[cd.o_tbl.input_file_idx]
					--cd.new_args.name =  cd.new_args.given_name and cd.new_args.given_name:match("^.+%.(.-)$") or cd.new_args.given_name
					--cd.new_args.name = cd.new_args.name and cd.new_args.name:match("^(.+) %(") or cd.new_args.name
					cd.new_g_name = cd.new_args.name
					cd.new_g_parent_name = split(cd.new_args.given_name, "%.")
					cd.new_g_parent_name = (cd.new_g_parent_name and cd.new_g_parent_name[#cd.new_g_parent_name-1]) 
					or (file[cd.new_args.name].Transform and file[cd.new_args.name].Transform._Parent and file[cd.new_args.name].Transform._Parent.__gameobj_name)
					cd.new_args.file = file 
					cd.prev_components = cd.new_components
					cd.new_components = {}
					cd.new_args.file.__dont_convert = cd.new_args.name
					cd.enabled_new_components = {}
					setup_comp_names = true
				elseif file == false then --failed to load with json.load_file
					cd.new_args.file = nil
				end --fake_components fake_gameobj
				
				local file_tbl = cd.new_args.file and cd.new_args.file[cd.new_args.file.__dont_convert]
				
				if file_tbl and file_tbl.__components_order and #file_tbl.__components_order > 0 then 
					imgui.text("Load Component Fields from JSON:")
					imgui.text("	")
					imgui.same_line()
					imgui.begin_rect()
						--local next_key, next_value = next(cd.new_args.file[) 
						for i, comp_name in pairs(file_tbl and file_tbl.__components_order or {}) do
							comp_json = file_tbl[comp_name:match("^.+%.(.-)$")]
							if comp_json then
								imgui.push_id(178943621+i)
									changed, cd.enabled_new_components[i] = imgui.checkbox("",  cd.enabled_new_components[i]) 
									if changed then 
										cd.new_args.disabled_components[ cd.new_components[i] ] = not cd.enabled_new_components[i] or false
									end
									imgui.same_line()
								imgui.pop_id()
								
								if setup_comp_names then  --initial setup (one time)
									table.insert(cd.new_components, comp_json.__typedef)
									
									if comp_name == "via.Transform" and comp_json._SameJointsConstraint ~= nil then
										cd.new_args.same_joints_constraint = comp_json._SameJointsConstraint
									end
									if comp_name == "via.render.Mesh" and comp_json.Mesh then 
										local mesh = jsonify_table({comp_json.Mesh}, true)[1]
										local mdf = jsonify_table({comp_json._Material}, true)[1]
										if mesh then 
											add_resource_to_cache(mesh, mdf, cd.o_tbl)
											cd.new_args.mesh = mesh:call("ToString()"):match("^.+%[@?(.+)%]")
											cd.new_args.mdf = mdf and mdf:call("ToString()"):match("^.+%[@?(.+)%]")
											comp_json.Mesh, comp_json._Material = nil--, comp_json.PartsEnable = nil
											cd.current_mesh_idx = nil
										end
									end
									for k, v in pairs(comp_json) do
										if type(v)=="table" then
											comp_json[k] = cd.recurse(v)
										end
									end
									cd.enabled_new_components[i] = not cd.new_args.disabled_components[comp_name] and comp_name~="via.motion.Motion"
								end
								
								editable_table_field(comp_name, comp_json, file_tbl, nil, {skip_underscores=0})
							end
						end
					imgui.end_rect(2)
					editable_table_field("disabled_components", cd.new_args.disabled_components, cd.new_args, "Disabled JSON Components")
				end
			end
			
			if create_button_pressed then 
				cd.gizmo_moves_selected = true
				cd.new_args.worldmatrix = cd.worldmatrix
				local copy_args = deep_copy(cd.new_args)
				copy_args.parent = copy_args.parent and (copy_args.parent:get_type_definition():is_a("via.GameObject") and copy_args.parent:call("get_Transform")) or copy_args.parent
				copy_args.rot = cd.has_parent_joint and copy_args.worldmatrix:to_quat()
				copy_args.worldmatrix = not cd.has_parent_joint and cd.worldmatrix
				copy_args.same_joints_constraint = copy_args.parent and copy_args.same_joints_constraint
				copy_args.only_set_json_resources = cd.only_set_json_resources or nil
				copy_args.created = true
				--copy_args.o_tbl = nil
				if not cd.o_tbl or not cd.o_tbl.show_load_input then 
					copy_args.file = nil 
				end
				local out = create_gameobj(cd.new_g_name, cd.new_components, copy_args, true)
				if out then 
					cd.sel_obj = out
					sel_obj_coll_key = out.unique_name or cd.new_g_name
					Collection[sel_obj_coll_key] = out
					if figure_mode or forced_mode then 
						table.insert(total_objects, out)
						deferred_calls[scene] = {lua_obj=out, method=out.update_components}
					end
				end
			end
			--Gun = create_gameobj("Gun", {"via.render.Mesh", "via.motion.Motion"}, {mesh="character/it/it02/008/it02_008_handgun_houndwolf02.mesh", mdf="character/it/it02/008/it02_008_handgun_houndwolf02.mdf2", parent="ch09_3000", parent_joint="R_Wep"})
			--Sword = create_gameobj("Sword", {"via.render.Mesh"}, {mesh="character/it/it01/012/it01_012_blade_longsword.mesh", parent_joint="R_Wep", rot=Quaternion.new(0,0,0.681639,0.731689)})
			--Sword = create_gameobj("Sword", {"via.render.Mesh"}, {mesh="Character/Weapon/wp01_000/wp01_000.mesh", parent="pl0100_ev01", parent_joint="L_WeaponHand", rot=Quaternion.new(0,0,0.681639,0.731689)})			
			--imgui.same_line()
			editable_table_field("new_args", cd.new_args, cd, "[args]")
			
		imgui.end_rect(2)
		imgui.pop_id()
	--elseif cd.new_args then
		--cd.worldmatrix = nil
		--cd.new_args.rot = nil
	end
	
	if cd and (moved_last_obj or cd.gizmo_freeze_selected) and cd.sel_obj and cd.gizmo_moves_selected then 
		local trs = mat4_to_trs(cd.worldmatrix, true)
		trs[2]:normalize()
		cd.sel_obj.start_time = uptime - 1
		--sel_obj.init_worldmat = cd.worldmatrix
		cd.sel_obj:set_transform(trs, true)
		if moved_last_obj == 1 then 
			cd.sel_obj.init_worldmat = cd.worldmatrix
		end
	end
	
	if dump_collection then 
		json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
	end
	
	if do_reset then 
		cd = deep_copy(default_SettingsCache.Collection_data)
	end
	
	SettingsCache.Collection_data = cd or SettingsCache
end

local BHVTAction = {
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or args.action or o.obj
		if not o.obj then return end
		o.node_obj = args.node_obj or o.node_obj
		o.name = o.obj:get_type_definition():get_full_name()
		self.__index = self
		return setmetatable(o, self)
	end,
}

local BHVTNode = {
	
	cached_node_names = {},
	
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or o.obj
		o.owner = args.owner or o.owner
		--if BHVT.nodes_failed or not pcall(function()
			o.name = args.name or (o.obj and o.obj.get_full_name and self:get_node_full_name(o.obj)) or o.name
		--end) or 
		if not o.owner or not o.obj or not o.name then
			BHVT.nodes_failed = true
			return 
		end
		o.id = o.obj:get_id()
		o.tree_idx = args.tree_idx or o.tree_idx
		
		local children = o.obj:get_children()--({pcall(o.obj.get_children, o.obj)})
		if children then
			for i, child in ipairs(children) do 
				if child.get_full_name then 
					o.children = o.children or {}
					local child_obj = self:new{obj=child, owner=o.owner, tree_idx=o.tree_idx}
					o.children[#o.children+1] = child_obj
				end
			end
			for i, action in ipairs(o.obj:get_actions()) do 
				o.actions = o.actions or {}
				local action_obj = BHVTAction:new{obj=action, node_obj=o} --self:get_action_obj(action, o.owner)
				o.actions[i] = action_obj
			end
			--[[for i, action in ipairs(o.obj:get_unloaded_actions()) do 
				o.unl_actions = o.unl_actions or {}
				local action_obj = BHVTAction:new{obj=action, node_obj=o} --self:get_action_obj(action, o.owner)
				o.unl_actions[i] = action_obj
			end]]
			--[[for i, transition in ipairs(o.obj:get_transitions()) do 
				if transition.get_full_name then 
					o.transitions = o.transitions or {}
					local transition_obj = self:new{obj=transition, owner=o.owner, tree_idx=o.tree_idx}
					o.transitions[#o.transitions+1] = transition_obj
				end
			end]]
		end
		self.__index = self
		return setmetatable(o, self)
	end,
	
	get_node_full_name = function(self, node)
		self = self or BHVTNode
		if node == nil then return "" end
		local addr = node:as_memoryview():get_address()
		if self.cached_node_names[addr] ~= nil then
			return self.cached_node_names[addr]
		end
		local fn = node:get_full_name()
		self.cached_node_names[addr] = fn
		return fn
	end,
}

local BHVTCoreHandle = {
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or o.obj
		o.tree = args.tree or (o.obj and o.obj.get_tree_object and o.obj:get_tree_object()) or o.tree
		o.index = args.index or o.index
		o.name = o.obj and get_mgd_obj_name(o.obj)
		if BHVT.nodes_failed or not o.tree or not o.obj then return o end -- 
		o.nodes = {}
		o.nodes_indexed = {}
		for j, node in ipairs(o.tree:get_nodes() or {}) do
			local node_obj = BHVTNode:new{obj=node, owner=o, tree_idx=o.index}
			if node_obj then
				o.nodes[BHVTNode:get_node_full_name(node)] = node_obj
				table.insert(o.nodes_indexed, node_obj)
			end
		end
		o.parent_nodes = {}
		for name, node_obj in orderedPairs(o.nodes) do 
			if not name:find("%.") then
				table.insert(o.parent_nodes, node_obj)
			end
		end
		self.__index = self
		return setmetatable(o, self)
	end,
}

--Class for holding behaviortree managed objects:
BHVT = {
	
	nodes_failed = not isDMC and statics.tdb_ver <= 67,
	
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or o.obj
		o.name = o.obj:call("ToString()")
		o.xform = args.xform or (o.obj and get_GameObject(o.obj, 1))
		if not o.xform then return end
		o.object = args.object or held_transforms[o.xform] or (GameObject and (touched_gameobjects[o.xform] or GameObject:new{xform=o.xform})) or GameObject:new{xform=o.xform}
		o.behaviortrees = args.behaviortrees or (o.object and o.object.behaviortrees) or o.behaviortrees or {}
		o.tree_idx = args.tree_idx or 0
		o.names = args.names or {}
		o.current_name_idx = 1
		o.input_text = ""
		o.imgui_keyname = (get_gameobj_path(o.object.gameobj) .. "." .. o.obj:get_type_definition():get_name())
		local comp_vars = o.obj:call("get_ComponentUserVariables")
		comp_vars = (comp_vars and (comp_vars:call("get_VariableSum()") > 0) and comp_vars) or nil
		o.variables = comp_vars and {ComponentUserVariables=comp_vars}
		o.tree_count = o.obj:call("getTreeCount")
		
		if o.tree_count > 0 then
			local core_handles = lua_get_system_array(o.obj:call("get_Layer()")) or (not BHVT.nodes_failed and o.obj:get_trees())
			if core_handles then 
				o.variables = o.variables or {}
				o.core_handles = o.core_handles or {}
				for i, core_handle in ipairs(core_handles) do 
					o.core_handles[i] = BHVTCoreHandle:new{obj=core_handle, index=i-1}
					local variable = core_handle:call("get_UserVariable")
					o.variables[core_handle.name or i] = (variable and (variable:call("get_VariableSum()") > 0) and variable) or nil
				end
			end
		end
		
        self.__index = self
		o = setmetatable(o, self)
		o:update()
        return o
	end,
	
	imgui_bhvt_nodes = function(self, node, name, imgui_keyname, dfcall_template, dfcall_json, array_location_tbl)
		if not name then 
			imgui.text("NO NAME")
			return
		end
		--imgui.text(node.tree_idx)
		local dfcall_args = {
			name,  
			node.tree_idx, 
			static_objs.setn
		}
		local is_running = (node.obj:get_status1() == 2) or (node.obj:get_status2() == 2)
		
		if is_running then imgui.begin_rect(); imgui.begin_rect() end
			if imgui.button_w_hotkey(name, self.imgui_keyname .. "." .. name, dfcall_template, dfcall_args, dfcall_json) then
				self:set_node(name, node.tree_idx)
			end
			
			
			--if (node.children or node.transitions or node.actions) then 
				name = name or BHVTNode:get_node_full_name(node.obj)
				imgui_keyname = imgui_keyname or self.imgui_keyname
				dfcall_template = dfcall_template or {obj=self.obj, func="setCurrentNode(System.String, System.UInt32, via.behaviortree.SetNodeInfo)"}
				--dfcall_template = dfcall_template or {obj=node.layer.layer, func="setCurrentNode(System.UInt64, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)"}
				imgui.same_line()
				if imgui.tree_node_str_id(node.obj.id, "") then
					if imgui.button("Reload") then
						array_location_tbl[1][array_location_tbl[2] ] = BHVTNode:new(node)
					end
					imgui.same_line()
					if imgui.button("Assign to 'node'") then
						_G.node = node.obj
					end
					if node.children and imgui.tree_node("Children") then
						for i, child_node_obj in pairs(node.children) do 
							self:imgui_bhvt_nodes(child_node_obj, child_node_obj.name, imgui_keyname, dfcall_template, dfcall_json, {node.children, i})
						end
						imgui.tree_pop()
					end
					if node.actions and imgui.tree_node("Actions") then
						for i, action_obj in ipairs(node.actions) do 
							--self:imgui_bhvt_nodes(action_node, action_name, imgui_keyname, dfcall_template)
							if imgui.tree_node(i .. ". " .. action_obj.name) then 
								imgui.managed_object_control_panel(action_obj.obj)
								imgui.tree_pop()
							end
						end
						imgui.tree_pop()
					end
					--[[if node.transitions and imgui.tree_node("Transitions") then
						for i, transition_node_obj in pairs(node.transitions) do 
							self:imgui_bhvt_nodes(transition_node_obj, transition_node_obj.name, imgui_keyname, dfcall_template, dfcall_json)
						end
						imgui.tree_pop()
					end]]
					imgui.tree_pop()
				end
			--end
		if is_running then imgui.end_rect(1); imgui.end_rect(2) end
	end,
	
	imgui_behaviortree = function(self)
		
		if BHVT.nodes_failed then 
			imgui.text("*Failed to load Nodes")
		end
		
		if not self.disabled and self.tree_count > 0 then 
			
			self._ = self._ or create_REMgdObj(self.obj, true)
			
			imgui.push_id(self.obj)
			imgui.begin_rect()
			
				self.tree_idx = 0
				node_name = self.obj:call("getCurrentNodeName", self.tree_idx) 
				
				if node_name then
					imgui.text((SettingsCache.transparent_bg and (self.object.name .. "\n") or "") .. "Action: " .. node_name)
					imgui.text("Action ID: " .. self.obj:call("getCurrentNodeID", self.tree_idx) .. "\nHash: " .. self.obj:call("getCurrentNodeNameHash", self.tree_idx) .. "\n")
				end
				
				if self.names_indexed[1] then 
					
					self.current_name_idx = find_index(self.names_indexed, node_name) or self.current_name_idx
					
					if changed then
						self.obj:call("set_PuppetMode", self.puppet_mode)
					end
					changed, self.show_input = imgui.checkbox("", self.show_input)
					imgui.same_line()
					
					changed, self.current_name_idx = imgui.combo("Set Node", self.current_name_idx, self.names_indexed)
					if self.show_input then
						imgui.text("	   ")
						imgui.same_line()
						changed, self.manual_node_input_text = imgui.input_text("Input Node", self.manual_node_input_text)
						if self.manual_node_input_text ~= "" and imgui.button("Add Node to List") then 
							--local current_name = self.names_indexed[self.current_name_idx]
							CachedActions[self.object.name][self.name][self.manual_node_input_text] = 1
							self.obj:call("set_PuppetMode", true)
							self.names_indexed = self.names_indexed or {}
							self:set_node(self.manual_node_input_text)
							self.manual_node_input_text = ""
						end
					end
					
					if changed then 
						--self.obj:call("set_PuppetMode", true)
						self:set_node(self.names_indexed[self.current_name_idx])
					end
					
					changed, self.puppet_mode = imgui.checkbox("Puppet Mode", self.obj:call("get_PuppetMode"))
					if changed then
						self.obj:call("set_PuppetMode", self.puppet_mode)
					end
					--[[changed, self.show_merge_lists = imgui.checkbox("Show Merge Lists", self.show_merge_lists)
					if changed then
						nodes_history_names = nodes_history_names or {}
						nodes_history_names[self.name] = {}
						for name, tbl in orderedPairs(CachedActions) do
							if tbl[self.name] and get_table_size(tbl[self.name]) > 1 then
								table.insert(nodes_history_names, name)
							end
						end
					end
					
					if self.show_merge_lists then
						changed, self.merge_name_idx = imgui.combo("[" .. i .."] Merge List", self.merge_name_idx or 1, nodes_history_names) 
						if changed and CachedActions[ nodes_history_names[self.merge_name_idx] ][self.name] then
							CachedActions[self.object.name][self.name] = merge_tables(CachedActions[self.object.name][self.name], CachedActions[ nodes_history_names[self.merge_name_idx] ][self.name])
							self:set_node(nil, 0, 1)
						end
					end]]
				end
				
				if imgui.button_w_hotkey("Restart Tree", self.imgui_keyname .. ".RestartTree", {obj=self.obj, func="restartTree"}) then
					self:restart_tree()
				end
				
				if self.core_handles then
					--local dfcall_template = {obj=layer.layer, func="setCurrentNode(System.UInt64, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)"}]] --other way
					local dfcall_template = {obj=self.obj, func="setCurrentNode(System.String, System.UInt32, via.behaviortree.SetNodeInfo)"}
					local dfcall_json = { --metadata used to locate the object in the scene using jsonify_table
						__gameobj_name = self.object.name,
						__typedef = "via.motion.MotionFsm2",
						__copy_json = true, --this makes jsonify_table create a json-table backup of the object when converting back to in-engine
						--down_timer = 0.0,
						__component_name = self.obj:get_type_definition():get_full_name(),
						--__getter = "getLayer",
						--__idx = layer.index, --these three^ can locate a field of a component in jsonify_table
					}
					for i, core_handle in ipairs(self.core_handles or {}) do
						if core_handle and imgui.tree_node(core_handle.name) then
							core_handle.obj._ = core_handle.obj._ or create_REMgdObj(core_handle.obj)
							if imgui.tree_node_ptr_id(core_handle.obj, core_handle.obj._.name_full) then
								imgui.managed_object_control_panel(core_handle.obj)
								imgui.tree_pop()
							end
							for j, node_tbl in ipairs(core_handle.parent_nodes or {}) do 
								self:imgui_bhvt_nodes(node_tbl, node_tbl.name, self.imgui_keyname, dfcall_template, dfcall_json, {core_handle.parent_nodes, j})
							end
							imgui.tree_pop()
						end
					end
				end
				
				if self.variables and imgui.tree_node("User Variables") then
					for name, variable in orderedPairs(self.variables) do
						variable._ = variable._ or create_REMgdObj(variable)
						if variable._ then
							show_imgui_uservariables(variable, name)
						else 
							self.variables = arrayRemove(self.variables, function(self)
								return true
							end)
						end
					end
					imgui.tree_pop()
				end
				
				--[[self._.sequencer = self._.sequencer or (not BHVT.nodes_failed and MoveSequencer:new({obj=self.obj}, self._.sequencer)) or {}
				
				if self._.sequencer.display_imgui then --next(self._.sequencer.Hotkeys) then
					local seq_detach = self._.sequencer and self._.sequencer.detach
					if seq_detach and imgui.begin_window("Sequencer: " .. self.object.name .. " " .. self.name, true, SettingsCache.transparent_bg and 128 or 0) == false then
						self._.sequencer.detach = false
					end
					
					if seq_detach or imgui.tree_node("Sequencer") then 
						if ((imgui.button("Reset") or imgui.same_line()) or not self._.sequencer) then
							self._.sequencer = MoveSequencer:new({obj=self.obj}, self._.sequencer)
						end
						self._.sequencer:display_imgui()
						imgui.spacing()
						if not seq_detach then
							imgui.tree_pop()
						end
					elseif self._.sequencer then
						self._.sequencer.display = nil
					end
					
					if seq_detach then
						imgui.end_window()
					end
				end]]
				
				if imgui.tree_node(self.name) then
					imgui.managed_object_control_panel(self.obj)
					if imgui.tree_node("[Lua]") then
						read_imgui_element(self)
						imgui.tree_pop()
					end
					imgui.tree_pop()
				end
			imgui.end_rect(0)
			imgui.pop_id()
		end
	end,
	
	restart_tree = function(self)
		self.obj:call("resetTree")
		self.obj:call("restartTree")
	end,
	
	set_node = function(self, node_name, tree_idx, node_id, check_idx)
		node_name = node_name or self.names_indexed[check_idx or self.current_name_idx]
		if node_id then 
			self.obj:call("setCurrentNode(System.UInt64, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)", node_id, nil, nil)
		else
			self.obj:call("setCurrentNode(System.String, System.UInt32, via.behaviortree.SetNodeInfo)", node_name, tree_idx or self.tree_idx, static_objs.setn)
		end
	end,
	
	set_total_nodes = function(self)
		if not self or not self.behaviortrees then return end
		self.behaviortrees.total_actions = 0
		for i, obj in ipairs(self.behaviortrees) do
			self.behaviortrees.total_actions = self.behaviortrees.total_actions + get_table_size(obj.names)
		end
	end,
	
	update = function(self)
		if self.disabled or self.tree_count == 0 then return end
		if not sdk.is_managed_object(self.obj) then 
			self.disabled = true 
			log.info("Removing BHVT " .. self.object.name .. " " .. self.name)
			if self.index and self.object.behaviortrees then 
				self.object.behaviortrees = arrayRemove(self.object.behaviortrees, function(bhvt_obj)
					bhvt_obj.index = i
					return true
				end)
			end
			return
		end
		
		local node_name = self.obj:call("getCurrentNodeName", 0)--pcall(self.obj.call, self.obj, "getCurrentNodeName", 0)
		if node_name then 
			self.node_name = node_name
			CachedActions[self.object.name] = CachedActions[self.object.name] or {}
			CachedActions[self.object.name][self.name] = CachedActions[self.object.name][self.name] or {}
			CachedActions[self.object.name][self.name][node_name] = CachedActions[self.object.name][self.name][node_name] or 1
			self.names = CachedActions[self.object.name][self.name]
			self.current_name_idx =  self.current_name_idx or (self.names_indexed and find_index(self.names_indexed, node_name)) --or self.current_name_idx
			if not self.names[node_name] or not self.names_indexed or not self.current_name_idx or (get_table_size(self.names) ~= #self.names_indexed) then --
				self.names[node_name] = true
				self.names_indexed =  {}
				for name, idx in orderedPairs(self.names) do
					table.insert(self.names_indexed, name)
				end
				self.current_name_idx =  find_index(self.names_indexed, node_name)
				--self:set_total_nodes()
			end
		end
	end,
}

--Get which body part a GameObject represents (body, face, hair or item):
local function get_body_part(str)
	local body_part_name
	local lower_name = str:lower()
	if lower_name:find("face") or lower_name:find("head") or (isRE8 and lower_name:find("20_")) or (isDMC and lower_name:find("%d%d%d%d_[01]1")) or (isRE3 and lower_name:find("[ep][ml]%d%d%d1")) or (isSF6 and lower_name:find("v00_01")) then
		body_part_name = "Face"
	elseif (lower_name:find("hair") and not lower_name:find("chair")) or lower_name:find("entacle") or (isSF6 and lower_name:find("v00_02")) then --no chairs pls
		body_part_name = "Hair"
	elseif not lower_name:find("wp_") and (isDMC or not lower_name:find("%d%d%d%d_%d%d")) and (lower_name:find("body") or lower_name:find("ch%d%d_") or lower_name:find("[ep][ml]%d%d") or (isSF6 and lower_name:find("v00_00"))) then
		body_part_name = "Body"
	else
		body_part_name = "Other"
	end
	return body_part_name
end

--GameObject lua class, used for everything: -------------------------------------------------------------------------------------------------
GameObject = {
	
	dead_addresses = {},
	
	new = function(self, args, o)
		o = o or {} 
		o.xform 			= args.xform or o.xform
		o.gameobj			= args.gameobj or o.gameobj
		if o.xform and self.dead_addresses[o.xform] then 
			self.dead_addresses[o.xform] = self.dead_addresses[o.xform] + 1
			log.info("Prevented dead GameObject " .. tostring(o.xform) .. ", attempt #" .. self.dead_addresses[o.xform])
			if self.dead_addresses[o.xform] == 300 then 
				log.info("asdf " .. asdffggsd) --causes an error that can be traced to what keeps trying to create
			end
			return
		end
		--local try = true 	
		--if o.xform and not o.gameobj then 
		--	try, o.gameobj =  pcall(sdk.call_object_func, o.xform, "get_GameObject") 
		--end
		o.gameobj = (o.gameobj and is_valid_obj(o.gameobj) and o.gameobj) or (o.xform and get_GameObject(o.xform))
		o.xform = o.xform or (o.gameobj and o.gameobj:call("get_Transform"))
		o.gameobj = o.gameobj or (o.xform and get_GameObject(o.xform))
		
		if not o.gameobj or not is_valid_obj(o.xform) then
			if o.xform then 
				self.dead_addresses[o.xform] = self.dead_addresses[o.xform] or 0
			end
			log.info("Failed to create GameObject") 
			return 
		end
		
		self.__index = self
		o.name = args.name or o.gameobj:call("get_Name")
		o.name_w_parent = o.name
		o.parent = args.parent or o.xform:call("get_Parent")
		o.parent_org = o.parent_org or o.parent
		o.children = args.children or get_children(o.xform)
		o.display = args.display or o.gameobj:call("get_Draw") --or number_to_bool[o.gameobj:read_byte(0x13)]
		o.same_joints_constraint = o.xform:call("get_SameJointsConstraint") or o.same_joints_constraint or  nil
		o.body_part = args.body_part or o.body_part or get_body_part(o.name)
		o.layer = args.layer or o.layer
		o.components = args.components
		o.init_worldmat = args.init_worldmat or o.init_worldmat or o.xform:call("get_WorldMatrix")
		
		if o.parent then
			local parent_gameobj = get_GameObject(o.parent)
			local parent_name = parent_gameobj and parent_gameobj:call("get_Name")
			--o.name_w_parent = ((parent_name and (parent_name .. " -> ") or "")) .. o.name_w_parent
		end
		
		if not o.components then 
			o.components = o.gameobj:call("get_Components")
			o.components = o.components and o.components.get_elements and o.components:get_elements()
			o.components = o.components or lua_get_components(o.xform)
		end
		
		if not o.components then
			log.info(o.name .. " failed to load components") --51 45, 15 7, 41 12
		else
			o.components_named = {}
			for i, component in ipairs(o.components or {}) do  
				local typedef = component:get_type_definition()
				local fname = typedef:get_full_name()
				o.components_named[typedef:get_name()] = component
				o.IBL = typedef:get_name() == "IBL" and component or nil
				o.is_light = o.is_light or o.IBL or (not not (fname:find("Light[Shaft]-$") and fname:find("^via%.render"))) or nil
				if typedef:is_a("via.behaviortree.BehaviorTree") then 
					o.behaviortrees = o.behaviortrees or {}
					local bhvt = {obj=component, xform=o.xform, object=o, index=#o.behaviortrees+1}
					table.insert(o.behaviortrees, bhvt)
					--log.info(json.log(bhvt.names) .. " " ..  get_table_size(bhvt.names) .. " " .. o.behaviortrees.total_actions .. " " .. tostring(bhvt.names_indexed and #bhvt.names_indexed))
				end
			end
		end
		
		--o.isRE7player = (isRE7 and o.name:find("[Pp]l%d000")==1 and o.components_named.Humanoid and o.components_named.CharacterController and true) or nil
		
		if not o.layer and o.components_named.Motion and o.components_named.Motion:call("getLayerCount") > 0 then 
			o.layer = o.components_named.Motion:call("getLayer", 0)
		end
		
		o.mfsm2 = args.mfsm2 or o.components_named.MotionFsm2 or o.mfsm2
		o.mesh = args.mesh or o.components_named.Mesh or lua_find_component(o.gameobj, "via.render.Mesh") or (sdk.is_managed_object(o.mesh) and o.mesh) or nil
		
		if o.mesh then 
			o.materials = o.materials or {}
			local mdf2_resource = o.mesh:call("get_Material")
			if mdf2_resource then 
				o.mpaths = {}
				o.current_mdf_idx, o.mpaths.mdf2_path = add_resource_to_cache(mdf2_resource)
			end
			local mesh_resource = o.mesh:call("getMesh")
			if mesh_resource then 
				o.mpaths = o.mpaths or {}
				o.mesh_name = args.mesh_name or mesh_resource:call("ToString()"):match("^.+%[@?(.+)%]")
				o.current_mesh_idx, o.mpaths.mesh_path = add_resource_to_cache(mesh_resource, mdf2_resource)
				o.mesh_name_short = args.mesh_name_short or o.mesh_name:match("^.+/(.+)%.mesh")
				if isDMC then 
					o.mesh_name_short = o.mesh_name_short:sub(1, 9)
				elseif isRE8 then
					o.mesh_name_short = o.mesh_name_short:sub(1, 8) --7
				else
					o.mesh_name_short = o.mesh_name_short:sub(1, 6) 
				end
				o.mesh_name_short = o.mesh_name_short:lower()
				GameObject.set_materials(o) 
			end
			o.mesh_name = (o.mesh_name and o.mesh_name:lower()) or ""
			if o.body_part == "Other" then 
				o.body_part = get_body_part(o.mesh_name)
			end
		end
		
		o.key_name = get_gameobj_path(o.gameobj)
		o.key_hash = o.key_name and hashing_method(o.key_name)
		o.name_w_parent = self.set_name_w_parent(o)
		
		if isDMC and SettingsCache.add_DMC5_names then 
			local possible_names = {o.mesh_name, o.key_name}
			for s, possible_name in ipairs(possible_names) do
				for i, part in ipairs(split(possible_name, "/")) do 
					local sub_tbl = split(part, "_")
					for j, sub_part in ipairs(sub_tbl or {}) do
						if sub_part:find("[ep][ml]%d%d")==1 and #sub_tbl > 1 and not sub_tbl[#sub_tbl]:find("%.") and not (sub_tbl[#sub_tbl]:find("ev")==1) then --and sub_tbl[#sub_tbl]~="ev" and sub_tbl[#sub_tbl]~="ev01"
							o.char_name = sub_tbl[#sub_tbl]
							goto exit
						end
						break
					end
				end
			end
			::exit::
			if o.char_name then 
				o.name = o.name .. " (" .. o.char_name .. ")"
				o.name_w_parent = o.name_w_parent .. " (" .. o.char_name .. ")" 
				o.unique_name = o.unique_name .. " (" .. o.char_name .. ")"
			end
		end
		
		if (touched_gameobjects[o.xform]) and (touched_gameobjects[o.xform]~=o) then
			o = merge_tables(o, touched_gameobjects[o.xform], true)
			touched_gameobjects[o.xform] = o
		end
		
		if (held_transforms[o.xform]) and (held_transforms[o.xform]~=o) then
			o = merge_tables(o, held_transforms[o.xform], true)
		end
		held_transforms[o.xform] = o
		
		if o.children and ((o.components_named.DummySkeleton or o.components_named.CustomSkeleton) or o.components_named.CharacterController or (o.mesh and o.components_named.FigureObjectBehavior)) then
			
			local candidate
			for i, child in ipairs(o.children) do  
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{xform=child} 
				local other = held_transforms[child] 
				if other and other.gameobj and (other.layer or (other.mpaths and not o.mpaths)) then --(other.body_part == "Body")
					candidate = other 
					if candidate.body_part == "Body" and candidate.gameobj:call("get_Draw") then 
						break 
					end
				end
			end
			
			if candidate and not candidate.pairing then
				o.pairing = candidate
				candidate.pairing = o
			end
		end
		
        return setmetatable(o, self)
	end,
	
	action_monitor = function(self, tree_obj)
		if self.behaviortrees and imgui.tree_node_str_id(self.name .. "Trees", "Action Monitor") then 
			for i, bhvt_obj in ipairs(self.behaviortrees) do
				if not tree_obj or bhvt_obj.obj == tree_obj then
					if not bhvt_obj.imgui_behaviortree then 
						bhvt_obj = BHVT:new(bhvt_obj)
						self.behaviortrees[i] = bhvt_obj
					end
					bhvt_obj:imgui_behaviortree()
				end
			end
			imgui.tree_pop()
		end
	end,
	
	change_child_setting = function(self, setting_name)
		for i, child_xform in ipairs(self.children or {}) do 
			held_transforms[child_xform] = held_transforms[child_xform] or GameObject:new_AnimObject{xform=child_xform}
			if held_transforms[child_xform] then
				held_transforms[child_xform][setting_name] = self[setting_name]
				held_transforms[child_xform]:change_child_setting(setting_name)
			end
		end
	end,
	
	gather_all_children = function(self, tbl_to_insert_to)
		tbl_to_insert_to = tbl_to_insert_to or {}
		insert_if_unique(tbl_to_insert_to, self)
		for i, child in ipairs(self.children or {}) do
			local child_obj = held_transforms[child] or GameObject:new_AnimObject{xform=child}
			if child_obj and insert_if_unique(tbl_to_insert_to, child_obj) then 
				tbl_to_insert_to = child_obj:gather_all_children(tbl_to_insert_to)
			end
		end
		return tbl_to_insert_to
	end,
	
	get_components = function(self)
		local comps, comps_named = {}, {}
		local component = self.xform
		local comp_name = component:get_type_definition():get_name()
		while component and not comps_named[comp_name] do 
			table.insert(comps, component)
			comps_named[comp_name] = component
			component = ({pcall(sdk.call_object_func, component, "get_Chain")})
			component = component and component[1] and component[2]
			comp_name = component and component.get_type_definition and component:get_type_definition()
			comp_name = comp_name and comp_name:get_name()
		end
		if comps and comps[1] and next(comps_named) then 
			self.components = comps
			self.components_named = comps_named
		end
	end,
	
	imgui_poser = function(self)
		
		self.poser = self.poser or {
			name=self.key_name:gsub("/", "."),
			slots = {},
			current_slot_idx = 1, 
			current_object_idx = 1,
			prop_idx = 1,
			prop_names = {"_LocalEulerAngle", "_LocalPosition", }, --"_EulerAngle", "_Position"
			use_gizmos = false, --(self.body_part ~= "Face"),
			undo = {{last={}},{last={}}},
			last_undo_idxs = {},
			sensitivity = 0.01,
			load_all = (self.body_part == "Face"),
			load_to_selected = false,
			do_alphanumeric = false,
			closest_to_mouse = {},
		}
		local poser = self.poser
		local undo = poser.undo[poser.prop_idx]
		frozen_joints[self.xform] = frozen_joints[self.xform] or {}
		local fj = frozen_joints[self.xform]
		local alt_pressed =  check_key_released(via.hid.KeyboardKey.Menu, 0.0)
		local ctrl_pressed = check_key_released(via.hid.KeyboardKey.Control, 0.0)
		local prop_changed_joint
		local text_pos = {statics.width/4*3, statics.height/4*3}
		poser.freeze_total = 0
		poser.is_open = uptime
		
		if poser.use_gizmos and kb_state.released[via.hid.KeyboardKey.Control] and poser.closest_to_mouse[5] and tics - poser.closest_to_mouse[5] <= 2 then
			prop_changed_joint = poser.closest_to_mouse[1]
			undo[prop_changed_joint].start = 0
		end
		
		local function clear_joint(joint)
			frozen_joints[self.xform][joint] = frozen_joints[self.xform][joint] or {false, false}
			frozen_joints[self.xform][joint][poser.prop_idx] = false
			if not frozen_joints[self.xform][joint][1] and not frozen_joints[self.xform][joint][2] then 
				frozen_joints[self.xform][joint] = nil 
			end
		end
		
		if not poser.names then
			poser.current_name = poser.current_name or poser.name
			local current_file = json.load_file("EMV_Engine\\Poses\\" .. poser.current_name .. ".json") or {}
			poser.slot_names = {}
			poser.slots = {}
			for name, tbl in orderedPairs(current_file) do
				table.insert(poser.slot_names, name)
				poser.slots[name] = tbl
			end
			poser.current_slot_idx = find_index(poser.slot_names, poser.save_name) or poser.current_slot_idx
			poser.save_name = ""
			poser.paths=fs.glob([[EMV_Engine\\Poses\\.*.json]])
			poser.names = {}
			for i, filepath in ipairs(poser.paths) do 
				table.insert(poser.names, filepath:match("^.+\\(.+)%."))
			end
			poser.current_object_idx = find_index(poser.names, poser.current_name) or table.binsert(poser.names, poser.current_name)
		end
		
		if imgui.tree_node("[Lua]") then
			read_imgui_element(poser)
			imgui.tree_pop()
		end
		
		if not next(undo, "last") then
			for i=1, 2 do
				for j, joint in ipairs(poser.all_joints or {}) do 
					poser.undo[i][joint] = {prev_rot={}, start=uptime, }
				end
			end
		end
		
		if imgui.button("+") then
			poser.show_add_json = not poser.show_add_json
		end
		imgui.same_line()
		
		changed, poser.current_object_idx = imgui.combo("Json File", poser.current_object_idx, poser.names)
		if changed then 
			poser.current_name = poser.names[poser.current_object_idx]
			poser.names = nil
			poser.current_slot_idx = 1
		end
		
		if poser.show_add_json then 
			imgui.text("    ") imgui.same_line()
			changed, poser.new_object_name = imgui.input_text("New Json Name", poser.new_object_name)
		end
		
		imgui.push_id(999)
			if imgui.button("+") then
				poser.show_add_slot = not poser.show_add_slot
			end
		imgui.pop_id()
		imgui.same_line()
		
		changed, poser.current_slot_idx = imgui.combo("Pose", poser.current_slot_idx, poser.slot_names)
		
		local current_slot_name = poser.slot_names[poser.current_slot_idx]
		
		imgui.same_line()
		local clear_slot = imgui.button("Del")
		imgui.tooltip("Delete the selected pose", 0)
		
		if poser.show_add_slot or #poser.slot_names == 0 then
			imgui.text("    ") imgui.same_line()
			changed, poser.save_name = imgui.input_text("New Pose Name", poser.save_name)
		end
		
		changed, poser.prop_idx = imgui.combo("Pose Type", poser.prop_idx, poser.prop_names)
		imgui.tooltip("Pose joints by their rotations or positions")
		
		poser.prop_name = poser.prop_names[poser.prop_idx]
		
		changed, poser.use_gizmos = imgui.checkbox("Use Gizmos", poser.use_gizmos)
		imgui.tooltip("Use gizmos on the screen to rotate and move bones")
		
		imgui.same_line()
		changed, poser.do_alphanumeric = imgui.checkbox("Sort Alphabetically", poser.do_alphanumeric)
		imgui.tooltip("Sort bones alphabetically")
		local changed_alphanumeric = changed
		
		if not poser.all_joints or (#poser.all_joints > #self.joints) and not imgui.same_line() then
			changed, poser.save_only_this = imgui.checkbox("Only this object", poser.save_only_this)
			imgui.tooltip("Save and Load only bones from this object, not from any children (except for the body)")
		end
		
		changed, poser.load_to_selected = imgui.checkbox("Load to Selected", poser.load_to_selected)
		imgui.tooltip("Load json bones only to bones that are selected")
		
		imgui.same_line()
		changed, poser.load_all = imgui.checkbox("Save/Load Position and Rotation Together", poser.load_all)
		imgui.tooltip("Import Postions and Rotations at the same time")
		
		if imgui.button("Save Pose") or clear_slot then 
			local current_name = (poser.new_object_name ~= "" and poser.new_object_name) or poser.current_name
			local current_file = json.load_file("EMV_Engine\\Poses\\" .. current_name .. ".json") or {}
			local save_name = (poser.save_name ~= "" and poser.save_name) or poser.slot_names[poser.current_slot_idx]
			
			if save_name and not clear_slot  then
				local pose = {}
				for i=1, 2 do
					if poser.load_all or poser.prop_idx == i then
						for j, joint in ipairs((poser.save_only_this and (poser.body_joints or self.joints)) or poser.all_joints or {}) do
							local name = joint:get_Name()
							pose[name] = pose[name] or {}
							pose[name][poser.prop_names[i] ] = jsonify_table({joint:call("get"..poser.prop_names[i])})[1]
						end
					end
				end
				for name, joint in pairs(pose) do 
					pose[name] = merge_tables(current_file[save_name] and current_file[save_name][name] or {}, pose[name])
				end
				current_file[save_name] = pose
			elseif current_slot_name then
				current_file[current_slot_name] = nil
				table.remove(poser.slot_names, poser.current_slot_idx)
				poser.current_slot_idx = (poser.current_slot_idx > 1 and poser.current_slot_idx-1) or 1
			end
			
			json.dump_file("EMV_Engine\\Poses\\" .. current_name .. ".json", current_file)
			json.current_name = current_name
			poser.current_name = current_name
			poser.names = nil
		end
		imgui.tooltip("Save frozen joints to a json file as a named pose")
		
		imgui.same_line()
		if imgui.button("Load Pose") then 
			local pose = json.load_file("EMV_Engine\\Poses\\" .. poser.current_name .. ".json")
			pose = pose and pose[current_slot_name]
			if pose then
				for i, joint in pairs((poser.save_only_this and (poser.body_joints or self.joints)) or poser.all_joints) do 
					local saved_joint = pose[joint:get_Name()]
					if saved_joint then 
						for key, value in pairs(saved_joint) do 
							local prop_idx = find_index(poser.prop_names, key)
							local undo_tbl = poser.undo[prop_idx]
							if (poser.load_all or key == poser.prop_name) and (not poser.load_to_selected or (undo[joint] and undo[joint].selected_to_load)) and type(value)=="string" then 
								fj[joint] = fj[joint] or {false, false}
								local splitted = split(value:sub(5,-1), " ")
								if #splitted == 3 then 
									fj[joint][prop_idx] = Vector3f.new(table.unpack(splitted))
									table.insert(undo_tbl.last, joint) 
									table.insert(undo_tbl[joint].prev_rot, joint["get"..key](joint))
									table.insert(poser.last_undo_idxs, prop_idx)
								end
							end
						end
					end
				end
			end
			poser.names = nil
		end
		imgui.tooltip("Load frozen joints from a json file to this skeleton")
		
		imgui.same_line()
		if imgui.same_line and imgui.button("Freeze All") then  
			for i=1, 2 do 
				if poser.load_all or i == poser.prop_idx then
					for j, joint in ipairs((poser.save_only_this and (poser.body_joints or self.joints)) or poser.all_joints) do
						fj[joint] = fj[joint] or {false, false}
						fj[joint][i] = joint["get"..poser.prop_names[i] ](joint)
						table.insert(poser.undo[i].last, joint) 
						table.insert(poser.undo[i][joint].prev_rot, joint["get"..poser.prop_names[i] ](joint))
						table.insert(poser.last_undo_idxs, i)
					end
				end
			end
		end
		imgui.tooltip("Freeze all joints, depending on the checkboxes above")
		
		imgui.same_line()
		if imgui.button("Unfreeze All") then 
			poser.last_undo_idxs = {}
			frozen_joints[self.xform] = {}
			for i=1, 2 do 
				poser.undo[i].last = {}
				for j, joint in ipairs((poser.save_only_this and (poser.body_joints or self.joints)) or poser.all_joints) do  
					poser.undo[i][joint] = poser.undo[i][joint] or {}
					poser.undo[i][joint].prev_rot = {}
				end
			end
		end
		imgui.tooltip("Unfreeze all joints and clear undo history, depending on the checkboxes above")
		
		imgui.same_line()
		local pressed_undo = imgui.button("Undo [" .. #poser.last_undo_idxs .. "]") or check_key_released(via.hid.KeyboardKey.Z)
		
		imgui.same_line()
		if imgui.button("Show Help") then
			poser.opened_help = not poser.opened_help 
		end
		
		changed, poser.sensitivity = imgui.drag_float("Sensitivity", poser.sensitivity, 0.001, 0.0001, 1.0)
		
		changed, poser.search_text = imgui.input_text("Filter", poser.search_text)
		imgui.tooltip("Filter bones by name\nSeparate multiple terms with spaces")
		
		if changed or not poser.searched_joints or changed_alphanumeric then 
			
			search_terms = split(poser.search_text:lower(), " ")
			search_terms[1] = search_terms[1] or ""
			
			poser.all_joints = {}
			
			local uniques = {}
			
			if self.same_joints_constraint and self.parent then
				for j, joint in ipairs(lua_get_system_array(self.parent:get_Joints())) do
					uniques[joint:get_Name()] = true
				end
			end 
			
			for i, child in ipairs(merge_indexed_tables({self.xform}, self.children) or {}) do
				if i == 1 or child:get_SameJointsConstraint() then
					local is_body = ((i == 1) or (get_body_part(child:get_GameObject():get_Name()) == "Body"))
					for j, joint in ipairs(lua_get_system_array(child:get_Joints())) do 
						if not uniques[joint:get_Name()] then
							uniques[joint:get_Name()] = true
							table.insert(poser.all_joints, joint)
							if is_body then
								poser.body_joints = poser.body_joints or {}
								table.insert(poser.body_joints, joint)
							end
						end
					end
				end
			end
			
			--if not poser.searched_joints then
			--	imgui.set_next_item_open(true)
			--end
			poser.searched_joints = {}
			
			for i, joint in ipairs(poser.all_joints) do
				for t, term in ipairs(search_terms) do 
					if term == "" or joint:get_Name():lower():find(term) then
						insert_if_unique(poser.searched_joints, joint)
					end
				end
			end
			if poser.do_alphanumeric then
				table.sort(poser.searched_joints, function(a, b) return a:get_Name() < b:get_Name()  end) 
			end
		end
		
		if poser.opened_help then
			imgui.text_colored("- Right click a joint in the list below to have it look at the camera", 0xFFF5D442)
			imgui.text_colored("- Freeze joints by moving them in the list or with gizmos, then click 'Save Pose' to save to a json file", 0xFFF5D442)
			imgui.text_colored("- Freeze facial animations by saving both their Positions and EulerAngles (Rotations)", 0xFFF5D442)
			imgui.text_colored("- Load only specific joints of a pose by checking the boxes next to them and importing with 'Load to Selected' checked", 0xFFF5D442)
			imgui.text_colored("- Search through long lists of joints by typing keywords into the 'Filters' text box. Separate keywords with spaces", 0xFFF5D442)
			imgui.text_colored("- Poses are saved to 'reframework\\data\\EMV Engine\\Poses' in your game folder", 0xFFF5D442)
			imgui.text_colored("- Hotkeys:\n	[Z] - Undo\n	[Ctrl] - Freeze hovered joint, or select gizmo/joint from on-screen\n	[Alt] - Unfreeze hovered joint", 0xFFF5D442)--\n	[Shift] - Stop changing gizmos")
		end
		
		local next_joint
		local mouse_tables = {}
		local do_subtables = (#poser.searched_joints > SettingsCache.max_element_size)
		local cam_xform = poser.use_gizmos and self.joint_positions and sdk.get_primary_camera():get_GameObject():get_Transform()
		local cam_xform_data = cam_xform and {
			cam_joint = cam_xform:getJointByName("Camera"),
			last_xform = {cam_xform:get_Position(), cam_xform:get_Rotation()},
		}
			
		if #poser.searched_joints > 0 then
			
			for i, joint in ipairs(poser.all_joints) do
				if fj[joint] and fj[joint][poser.prop_idx] then 
					poser.freeze_total = poser.freeze_total + 1
				end
			end
			
			if cam_xform_data then
				cam_xform:set_Rotation(cam_xform_data.cam_joint:get_Rotation()) 
				cam_xform:set_Position(cam_xform_data.cam_joint:get_Position()) --must temporarily move the cam_xform to the cam joint in order for draw.world_to_screen to work
				closest_delta = 99999
				for i, joint in ipairs(poser.all_joints) do
					local mat = self.joint_positions[joint] 
					if mat then
						local pos = mat[3]:to_vec3() --world pos
						local cam_dist = (pos - cam_xform:call("get_WorldMatrix")[3]):length()
						local mat_screen = draw.world_to_screen(pos)
						if mat_screen then
							local mouse_delta = (mat_screen - imgui.get_mouse()):length()
							mouse_tables[joint] = {joint, mat_screen, mat, mouse_delta, tics}
							if mouse_delta < closest_delta then
								if ctrl_pressed and self.last_show_joints == nil then 
									self.last_show_joints = self.show_joints 
									self.show_joints = true
								end
								closest_delta = mouse_delta
								poser.closest_to_mouse = mouse_tables[joint] 
							end
						end
					end
				end
			end
			
			for j = 1, #poser.searched_joints, ((do_subtables and SettingsCache.max_element_size) or #poser.searched_joints) do 
				j = math.floor(j)
				local this_limit = math.floor((j+SettingsCache.max_element_size-1 < #poser.searched_joints and j+SettingsCache.max_element_size-1) or #poser.searched_joints)
				if not do_subtables or imgui.tree_node_str_id(tostring(poser.searched_joints[j]) .. "Elements", "Elements " .. j .. " - " .. this_limit) then
					for i = j, this_limit do 
						local joint = poser.searched_joints[i]
						local j_o_tbl = joint._ or create_REMgdObj(joint, nil, {"get_LocalEulerAngle", "get_LocalPosition" }) --"get_EulerAngle", "get_Position"
						j_o_tbl.last_opened = uptime
						local frozen_prop_data = fj[joint] and fj[joint][poser.prop_idx]
						imgui.push_id(i)
							
							j_o_tbl.selected = poser.freeze_total > 0 and #undo.last > 0 and (undo.last[#undo.last] == joint)
							if j_o_tbl.selected then imgui.begin_rect() imgui.begin_rect() end
							
							--undo[joint] = undo[joint] or {}
							if undo[joint] then
								changed, undo[joint].selected_to_load = imgui.checkbox("", undo[joint].selected_to_load)
								if (ctrl_pressed or alt_pressed) and imgui.is_item_hovered() then
									undo[joint].selected_to_load = ctrl_pressed
								end
								imgui.tooltip("Import poses to this bone with 'Load to Selected' checked")
								
								imgui.same_line()
								local changed, new_value = imgui.drag_float3(j_o_tbl.Name, joint["get"..poser.prop_name](joint), poser.sensitivity, -1000000, 1000000)
								local hovered = imgui.is_item_hovered()
								
								if changed or (not frozen_prop_data and hovered and ctrl_pressed) then
									prop_changed_joint = joint
									fj[joint] = fj[joint] or {false, false}
									fj[joint][poser.prop_idx] = new_value
									if not changed then undo[joint].start = 0 end
								end
								
								local do_lookat = false
								if poser.prop_idx == 1 and imgui.begin_popup_context_item("ctx") then
									do_lookat = imgui.menu_item("Look at camera")
									imgui.end_popup() 
								end
								
								if frozen_prop_data then 
									imgui.same_line() 
									if undo[joint] and #undo[joint].prev_rot > 0 then
										if imgui.button(#undo[joint].prev_rot) then
											pressed_undo = true
											next_joint = joint
										end
										imgui.tooltip("Undo one action for this joint")
										imgui.same_line()
									end
									if imgui.button("X") or (hovered and alt_pressed) then
										undo[joint].prev_rot = {}
										clear_joint(joint)
									end
									imgui.tooltip("Unfreeze this joint and clear its undo history")
								end
								
								if do_lookat then
									table.insert(undo.last, joint) 
									table.insert(undo[joint].prev_rot, joint["get"..poser.prop_name](joint))
									table.insert(poser.last_undo_idxs, poser.prop_idx)
									local mat = sdk.find_type_definition("via.matrix"):get_method("makeLookAtLH"):call(nil, joint:get_Position(), static_objs.cam:get_GameObject():get_Transform():getJointByName("Camera"):get_Position(), last_camera_matrix[1])
									joint:set_EulerAngle(mat:to_quat():conjugate():to_euler())
									fj[joint] = fj[joint] or {false, false}
									fj[joint][1] = joint:get_LocalEulerAngle()
								end
							end
							if j_o_tbl.selected then imgui.end_rect(2) imgui.end_rect(3) end
						imgui.pop_id()
					end
					if do_subtables then 
						imgui.tree_pop()
					end
				end
			end
		end
		
		local gizmo_tbl = (not ctrl_pressed and mouse_tables[(undo.last[#undo.last] or 0)]) or poser.closest_to_mouse
		if poser.use_gizmos and gizmo_tbl[1] then 
			
			local joint = gizmo_tbl[1]
			local mat = gizmo_tbl[3]:clone()
			
			if (ctrl_pressed or poser.freeze_total > 0) then
				if (not ctrl_pressed and poser.closest_to_mouse[4] < 200) or (ctrl_pressed and poser.closest_to_mouse[4] < 25) then
					mat[3].w = 1
					
					changed, mat = draw.gizmo(joint:get_address(), mat)
					
					if changed then
						prop_changed_joint = joint
						poser.prop_idx = (mat[3]:to_vec3() ~= gizmo_tbl[3][3]:to_vec3() and 2) or 1
						poser.prop_name = poser.prop_names[poser.prop_idx]
						undo = poser.undo[poser.prop_idx]
						joint:set_Rotation(mat:to_quat())
						joint:set_Position(mat[3]:to_vec3())
						fj[joint] = fj[joint] or {false, false}
						fj[joint][poser.prop_idx] = joint["get"..poser.prop_name](joint)
					end
					draw.text("\n" .. joint:get_Name(), text_pos[1], text_pos[2], 0xFFFFFFFF)
					draw.line(gizmo_tbl[2].x, gizmo_tbl[2].y, text_pos[1], text_pos[2] + 30, 0xFFFFFFFF )
					if not ctrl_pressed and self.last_show_joints ~= nil then
						self.show_joints, self.last_show_joints = self.last_show_joints, nil
					end
				end
			end
		end
		
		if prop_changed_joint then
			local joint = prop_changed_joint
			if (uptime - undo[joint].start) > 0.33 then --or not mouse_state.down[via.hid.MouseButton.L] then --and (joint._.props_named[poser.prop_name].cvalue - undo[joint].prev_rot):length() > 0.1
				table.insert(undo.last, joint)
				table.insert(poser.last_undo_idxs, poser.prop_idx)
				fj[joint] = fj[joint] or {false, false}
				if not pressed_undo and fj[joint][1] == false and fj[joint][2] == false then
					fj[joint][poser.prop_idx] = joint["get"..poser.prop_name](joint)
				end
				table.insert(undo[joint].prev_rot, fj[joint][poser.prop_idx])
			end
			undo[joint].start = uptime
		end
		
		if pressed_undo then 
			local prop_idx = poser.last_undo_idxs[#poser.last_undo_idxs]
			local undo_tbl = poser.undo[prop_idx]
			local joint = next_joint or (undo_tbl and undo_tbl.last[#undo_tbl.last])
			if joint and undo_tbl then
				undo_tbl.last[#undo_tbl.last] = nil
				poser.last_undo_idxs[#poser.last_undo_idxs] = nil
				fj[joint] = fj[joint] or {}
				fj[joint][prop_idx] = joint["get"..poser.prop_names[prop_idx] ](joint)
				if undo_tbl[joint] and undo_tbl[joint].prev_rot then
					fj[joint][prop_idx] = undo_tbl[joint].prev_rot[#undo_tbl[joint].prev_rot]
					undo_tbl[joint].prev_rot[#undo_tbl[joint].prev_rot] = nil
				end
				if not undo_tbl[joint].prev_rot or not undo_tbl[joint].prev_rot[1] then
					clear_joint(joint)
				end
			end
		end
		if cam_xform_data then
			cam_xform:set_Rotation(cam_xform_data.last_xform[2]) 
			cam_xform:set_Position(cam_xform_data.last_xform[1])
		end
	end,
	
	--huge fukn thing mostly to get/set parents:
	imgui_xform = function(self)
		imgui_changed, self.display = imgui.checkbox("Enabled", self.display)
		if imgui_changed then 
			self.display_org = self.display
			self:toggle_display()
		end
		imgui.same_line()
		
		if imgui.button("Destroy " .. self.name) then 
			deferred_calls[self.gameobj] = { { func="destroy", args=self.gameobj }, (self.frame and EMV.clear_figures and {lua_func=EMV.clear_figures}) }
		end
		
		if GameObject.update_banks and (self.layer or self.children) and not imgui.same_line() and imgui.button(forced_mode and "Add to Animation Viewer" or "Enable Animation Viewer") then --and not cutscene_mode 
			self = GameObject:new_AnimObject({xform=m_obj}, self)
			--self.is_forced = true
			total_objects = total_objects or {}
			if not forced_mode then
				forced_mode = GameObject:new{xform=self.xform}
				--forced_mode.init_transform = forced_mode.xform:call("get_WorldMatrix")
				forced_object = forced_mode
				--forced_mode:activate_forced_mode()
				--if grab then 
				--	grab(self.xform, {init_offet=self.cog_joint and self.cog_joint:call("get_BaseLocalPosition")}) 
				--end
			elseif insert_if_unique(total_objects, self) then
				total_objects = self:gather_all_children(total_objects)
			elseif insert_if_unique(imgui_anims, self) then
				imgui_anims = self:gather_all_children(imgui_anims)
			end
			self.forced_mode_center = self.xform:call("get_WorldMatrix")
		end
		--tbl = {}; for i, comp in ipairs(findc("via.timeline.Timeline")) do tbl[EMV.get_GameObject(comp):call("get_Transform")]={obj=comp, amt=comp:call("get_BindGameObjects"):get_size()} end; result = qsort(tbl, "amt") 
		
		self.parent = self.xform:call("get_Parent")
		self.parents_list = self.parents_list or {names={}, names_to_xforms={}, edited_names={}}
		
		local htc = get_table_size(held_transforms)
		if not self.index_h_count or (self.index_h_count ~= htc) or (self.parent and (self.parent ~= self.parents_list.names_to_xforms[ self.parents_list.names[self.parent_index] ])) then 
			imgui.same_line()
			imgui.text("Sorting")
			local uniques = {}
			sorted_held_transforms, self.parents_list = {}, {names={}, names_to_xforms={}, edited_names={}}
			for xform, obj in pairs(held_transforms) do 
				table.insert(sorted_held_transforms, obj) 
			end
			table.sort (sorted_held_transforms, function (obj1, obj2) return (obj1.name_w_parent or obj1.name) < (obj2.name_w_parent or obj2.name) end )
			for i, obj in ipairs(sorted_held_transforms) do
				
				local edited_name = obj.name_w_parent or obj.name
				if obj.xform == self.xform then 
					edited_name = " "
				elseif is_child_of(obj.xform, self.xform) then
					edited_name = edited_name .. " [CHILD]"
				end
				
				local unique_name = obj.unique_name --resolve_duplicate_names(self.parents_list.names_to_xforms, obj.unique_name or obj.name_w_parent)
				self.parents_list.names_to_xforms[unique_name] = obj.xform
				table.insert(self.parents_list.names, unique_name)
				table.insert(self.parents_list.edited_names, edited_name)
				--obj.unique_name = unique_name
				obj.index_h = i
			end
			self.index_h_count = htc
		end
		
		self.parent_index = (held_transforms[self.parent] and held_transforms[self.parent].index_h) or self.index_h

		local do_unset_parent = false
		if imgui.button((self.parent_org and not self.parent and "Reset") or "Unset") then  
			do_unset_parent = true
		end
		
		imgui.same_line()
		imgui_changed, self.parent_index = imgui.combo("Parent", self.parent_index, self.parents_list.edited_names)
		
		if self.parent_index == self.index_h then 
			imgui.same_line()
			imgui.text("[No Parent]")
			--[[if self.parents_list.names[self.parent_index] ~= " " then 
				self.parents_list = {} 
			end]]
		end
		
		local parent_name = self.parents_list.edited_names[self.parent_index]
		
		if do_unset_parent or (imgui_changed and parent_name ~= " " and not parent_name:find(" %[CHILD%]")) then 
			local new_parent = sorted_held_transforms[self.parent_index].xform 
			if do_unset_parent or self.parent_index == self.index_h then 
				if self.parent_org and not self.parent then
					self:set_parent(self.parent_org or 0)
				else
					self:set_parent(0)
					--self.parent_obj.children = get_children(self.parent_obj.xform)
				end
			elseif not is_child_of(self.xform, new_parent) then
				self:set_parent(sorted_held_transforms[self.parent_index].xform or 0)
			end
			if self.xform._ then
				self.xform._.invalid = true
			end
			self.display = true
			deferred_calls[self.gameobj] = {lua_object=self, method=GameObject.toggle_display}
			if _G.grab and self.is_grabbed then 
				grab(self.xform)
			end
		end
		
		imgui_changed, self.display_transform = imgui.checkbox("Show Transform", self.display_transform)
		
		if self.display_transform then 
			imgui.same_line()
			if imgui.button("Print Transform to Log") then
				local pos, rot, scale = get_trs(self)
				log.info("\n" .. game_object_name .. "->" .. " Transform: \n" .. log_transform(pos, rot, scale))
				re.msg("Printed to re2_framework_log.txt")
			end
		end 
		
		if _G.grab then --and not self.same_joints_constraint then  --not figure_mode and 
			imgui.same_line()
			offer_grab(self)
		end
		
		if self.parent then 
			held_transforms[self.parent] = held_transforms[self.parent] or GameObject:new_AnimObject{xform = self.parent}
		end
		
		if Collection and (not Collection[self.unique_name] or not Collection[self.unique_name].xform) and (not imgui.same_line() and imgui.button("Add to Collection")) then 
			Collection[self.unique_name] = self
			SettingsCache.detach_collection = true
			json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
		end
		
		if self.joints then 
			
			imgui.same_line()
			imgui_changed, self.show_joints = imgui.checkbox("Show Joints", self.show_joints)	
			if imgui_changed and SettingsCache.affect_children and self.children then 
				self:change_child_setting("show_joints")
			end
			
			if self.show_joints then 
				imgui.same_line()
				imgui_changed, self.show_joint_names = imgui.checkbox("Show Joint Names", self.show_joint_names)	
				if imgui_changed and SettingsCache.affect_children and self.children then 
					self:change_child_setting("show_joint_names")
				end					
				if self.joints and self.joint_positions then
					local output_str = "\n"
					local active_poser = self.poser and (uptime - self.poser.is_open) < 5
					for i, joint in ipairs((active_poser and self.poser.all_joints) or self.joints) do 
						output_str = output_str .. joint:call("get_Name") .. " = " .. joint:call("get_NameHash") .. ",\n"
						local joint_pos = self.joint_positions[joint][3]
						local parent = joint:call("get_Parent")
						if not parent or self.joint_positions[parent] ~= nil then 
							local parent_pos = parent and self.joint_positions[parent][3]
							local this_vec2 = draw.world_to_screen(joint_pos)
							if self.show_joint_names or (parent and (parent_pos-joint_pos):length() > 1) then 
								draw.world_text(joint:call("get_Name"), joint_pos, 0xFFFFFFFF) 
							end
							if parent and this_vec2 then 
								local parent_vec2 = draw.world_to_screen(parent_pos)
								if parent_vec2 then 
									draw.line(parent_vec2.x, parent_vec2.y, this_vec2.x, this_vec2.y, 0xFF00FFFF)  
								end
							end
						end
					end
					if not imgui.same_line() and imgui.button("Print Bones Enum") then 
						log.info(output_str) 
					end
					if not imgui.same_line() and imgui.button("Print ChainBones Enum") then 
						output_str = "\n"
						for name, hash in pairs(chain_bone_names) do 
							output_str = output_str .. name .. " = " .. hash .. "\n"
						end
						log.info(output_str) 
					end
				end
			end
		end
		
		if not self.same_joints_constraint or not self.parent then
			--[[imgui_changed, self.lookat_enabled = imgui.checkbox("LookAt", self.lookat_enabled)
			if self.lookat_enabled then 
				if self.joints and not self.same_joints_constraint then
					if not self.joints_names then 
						self.joints_names = {}
						for i, joint in ipairs(self.joints) do  table.insert(self.joints_names, joint:call("get_Name")) end
					end
					if self.joints_names[1] then
						imgui.same_line()
						imgui_changed, self.lookat_joint_index = imgui.combo("Set Source Bone", self.lookat_joint_index, self.joints_names)
						--imgui.text("                    "); imgui.same_line()
						if imgui.button(self.joints[self.lookat_joint_index].frozen and " Unfreeze " or "   Freeze   ") then 
							self.joints[self.lookat_joint_index].frozen = not not not self.joints[self.lookat_joint_index].frozen
							self.lookat_joints = self.lookat_joints or {}
							if self.joints[self.lookat_joint_index].frozen then
								self.lookat_joints[self.joints[self.lookat_joint_index] ] = self.joints[self.lookat_joint_index]:call("get_LocalRotation")
							else
								self.lookat_joints[self.joints[self.lookat_joint_index] ] = nil
							end
						end
						imgui.same_line()
					end
				end
				self.lookat_index = self.lookat_index or (selected and find_index(self.parents_list, selected.name_w_parent)) or find_index(self.parents_list, "Main Camera")
				imgui_changed, self.lookat_index = imgui.combo("Set Target", self.lookat_index, self.parents_list)
				self.lookat_obj = sorted_held_transforms[self.lookat_index]
				self.lookat_enabled = not not self.lookat_obj
			else
				self.lookat_joints = nil
			end]]
		end
		
		if imgui.tree_node("GameObject") then
			self.opened = true
			if imgui.button("Refresh") then 
				self = self:update_components()
				self.children = get_children(self.xform)
			end
			if imgui.tree_node("[Lua]") then 
				read_imgui_pairs_table(self, self.name .. "EMV")
				imgui.tree_pop()
			end
			
			if imgui.tree_node_str_id(self.gameobj:get_address(), "via.GameObject") then
				imgui.managed_object_control_panel(self.gameobj, "GameObject", game_object_name)
				if self.gameobj._ and self.gameobj._.name ~= "Folder" then 
					self.gameobj._.owner = self.gameobj._.owner or m_obj 
				end
				--game_object_name = game_object_name or self.gameobj:call("get_Name")
				imgui.tree_pop()
			end
			
			if self.components[1] then 
				for i=1, #self.components do 
					local component = self.components[i]
					local comp_def = component:get_type_definition()
					if imgui.tree_node_str_id(component:get_address(), i .. ". " .. comp_def:get_full_name()) then
						imgui.managed_object_control_panel(component, comp_def:get_name(), comp_def:get_name())
						if component._ then 
							component._.owner = component._.owner or m_obj 
						end
						imgui.tree_pop()
					end
				end
			end
			imgui.tree_pop()
		end
		
		self.joints = self.joints or lua_get_system_array(self.xform:call("get_Joints"))
		
		if self.joints and imgui.tree_node("Poser") then --
			if not (not self.same_joints_constraint or not self.parent or self.body_part == "Face") then 
				imgui.text("*Object may only move via Parent")
			end
			self:imgui_poser()
			imgui.tree_pop()
		end
		--[[
		if self and self.materials and self.materials[1] and imgui.tree_node_ptr_id(self.materials[1].mesh:get_address() - 1235, "Materials") then
			show_imgui_mats(self) 
			imgui.tree_pop()
		end
		self:action_monitor()]]
	end,
	
	load_json_mesh = function(self)
		saved_mats[self.name_w_parent] = saved_mats[self.name_w_parent] or {m={}, mesh=self.mpaths.mesh_path, mdf=self.mpaths.mdf2_path, active=true, swap_mesh=false}
		local sv_container = saved_mats[self.name_w_parent]
		if sv_container.active then 
			if sv_container.swap_mesh then
				if self.mpaths.mesh_path ~= sv_container.mesh then 
					local rs = create_resource(sv_container.mesh, "via.render.MeshResource")
					if rs then
						self.mpaths.mesh_path = sv_container.mesh
						local old_parent = self.parent
						if old_parent then 
							self:set_parent(0)
						end
						self.mesh:call("setMesh", rs)
						if old_parent then 
							deferred_calls[self.xform] = {lua_object=self, method=self.set_parent, args={old_parent}}
						end
					end
				end
				if self.mpaths.mdf2_path ~= sv_container.mdf then 
					local rs = create_resource(sv_container.mdf, "via.render.MeshMaterialResource")
					if rs then
						self.mpaths.mdf2_path = sv_container.mdf
						self.mesh:call("set_Material", rs)
					end
					self:set_materials()
					return true
				end
			end
		end
	end,
	
	reset_physics = function(self, do_deferred)
		if self.components_named.Chain or self.components_named.PhysicsCloth then
			local tmp = function()
				if self.components_named.Chain then self.components_named.Chain:call("restart") end
				if self.components_named.PhysicsCloth then self.components_named.PhysicsCloth:call("restart") end
			end
			if do_deferred then 
				deferred_calls[self.components_named.Chain or self.components_named.PhysicsCloth or self.gameobj] = {lua_func = tmp}
			else
				tmp()
			end
		end
	end,
	
	set_materials = function(self, do_change_defaults, args) --use this with "do_change_defaults" to save all materials current settings to JSON
		args = args or {}
		local mesh = args.mesh or self.mesh
		args.on = self.on
		local materials_count = mesh and mesh:call("get_MaterialNum") or 0
		if materials_count == 0 then return end
		self.materials = {}
		if SettingsCache.remember_materials and saved_mats[self.name_w_parent] then
			saved_mats[self.name_w_parent].active = saved_mats[self.name_w_parent].active or do_change_defaults
		end
		for i=1, materials_count do 
			local new_args = {anim_object=self, id=i-1, do_change_defaults=do_change_defaults}
			local new_mat = Material:new((args and merge_tables(new_args, args) or new_args))
			self.materials.is_cmd = self.materials.is_cmd or new_mat.is_cmd
			table.insert(self.materials, new_mat)
		end
		if do_change_defaults and SettingsCache.affect_children and self.children then 
			for i, child in ipairs(self.children) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
				if held_transforms[child].mesh then 
					held_transforms[child]:set_materials(true, args)
				end
			end
		end
	end,
	
	set_name_w_parent = function(self, parent)
		local name_w_parent = ""
		local name = self.name:match("^(.+) %(") or self.name
		self.name = name
		local tmp_xform = parent or self.xform:call("get_Parent")
		while tmp_xform do
			name_w_parent = get_GameObject(tmp_xform, true) .. "." .. name_w_parent
			tmp_xform = tmp_xform:call("get_Parent")
		end
		self.name_w_parent = name_w_parent .. name
		self.unique_name = self.name_w_parent .. " @ " .. self.xform:get_address()
		if self.char_name and SettingsCache.add_DMC5_names then 
			self.name_w_parent = self.name_w_parent:gsub(" ?(" .. self.char_name .. ")", "") .. " (" .. self.char_name .. ")"
			self.unique_name = self.unique_name:gsub(" ?(" .. self.char_name .. ")", "") .. " (" .. self.char_name .. ")"
		end
		return self.name_w_parent
	end,
	
	pre_fix_displays = function(self)
		self.last_display = self.display
		if SettingsCache.affect_children and self.children then 
			for i, child in ipairs(self.children) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{xform=child}
				if held_transforms[child] then held_transforms[child]:pre_fix_displays() end
			end
		end
	end,
	
	set_transform = function(self, trs, do_deferred)
		if do_deferred then
			deferred_calls[self.xform] = deferred_calls[self.xform] or {}
			table.insert(deferred_calls[self.xform], {lua_object=self, method=GameObject.set_transform, args={trs}})
		else
			--self:pre_fix_displays()
			--log.info("setting transform for " .. self.name .. " 1. " .. tostring(trs[1]) .. " 2. " .. tostring(trs[2]) .. " 3. " .. tostring(trs[3]))
			if trs[1] then self.xform:call("set_Position", trs[1]) end
			if trs[2] then self.xform:call("set_Rotation", trs[2]) end
			if trs[3] then self.xform:call("set_Scale", trs[3]) end
			--self:toggle_display()
		end
	end,
	
	set_parent = function(self, new_parent_xform, do_deferred)
		if do_deferred then
			local deferred_calls = (do_deferred==1) and on_frame_calls or deferred_calls
			deferred_calls[self.xform] = deferred_calls[self.xform] or {}
			table.insert(deferred_calls[self.xform], {lua_object=self, method=GameObject.set_parent, args=new_parent_xform})
		else 
			self:pre_fix_displays()
			pcall(sdk.call_object_func, self.xform, "set_Parent", new_parent_xform or 0)
			self.parent = self.xform:call("get_Parent")
			self.parent_obj = self.parent and (held_transforms[self.parent] or (GameObject.new_AnimObject and GameObject:new_AnimObject{xform=self.parent} or GameObject:new{xform=self.parent}))
			self:toggle_display()
		end
	end,
	
	toggle_display = function(self, is_child, forced_setting)
		
		local restore = (self.last_display ~= nil)
		if forced_setting ~= nil then 
			self.display = forced_setting 
		elseif restore then
			self.display = self.last_display
			self.last_display = nil
		end
		
		self.gameobj:call("set_UpdateSelf", self.display)
		self.gameobj:call("set_DrawSelf", self.display)
		self.gameobj:write_byte((isSF6 and 0x11) or 0x13, bool_to_number[self.display])	--draw
		
		if not is_child and not isDMC and self.parent_obj then 
			local tmp = not not self.parent_obj.xform:call("get_SameJointsConstraint")
			self.parent_obj.same_joints_constraint = tmp
			self.parent_obj.xform:call("set_SameJointsConstraint", not tmp) --refreshes
			self.parent_obj.xform:call("set_SameJointsConstraint", tmp)
		end
		
		--self.gameobj:write_byte(0x14, bool_to_number[self.display]) --updateself
		--self.gameobj:write_byte(0x12, bool_to_number[self.display])	--update	
		
		if changed and not is_child then -- or forced_setting 
			self.keep_on = nil
			self.display_org = self.display
		end
		
		if SettingsCache.affect_children and self.children then
			changed = false
			for i, child in ipairs(self.children) do
				local child_obj = held_transforms[child]
				if child_obj and (child_obj.parent == self.xform) and (restore or (cutscene_mode or (not self.display or child_obj.display_org == true))) then
					child_obj.display = self.display
					child_obj:toggle_display(true)
				end
			end
		end
		--[[if changed and figure_mode and self.mesh_name_short then
			EMVCache.custom_lists[self.mesh_name_short] = EMVCache.custom_lists[self.mesh_name_short] or {}
			EMVCache.custom_lists[self.mesh_name_short].Display = self.display
		end]]
		self.toggled_display = self.display
		--log.info("set " .. self.name .. " to " .. tostring(self.display) .. ", draw is " .. tostring(self.gameobj:call("get_Draw")) .. ", drawself is " .. tostring(self.gameobj:call("get_DrawSelf")))
	end,
	
	update_components = function(self, basis_args)
		if not self or not is_valid_obj(self.xform) then return end
		held_transforms[self.xform], touched_gameobjects[self.xform] = nil
		self = GameObject:new_AnimObject({xform=self.xform}, basis_args, true)
		if touched_gameobjects[self.xform] then
		--	self = GameObject:new_GrabObject({xform=self.xform}, basis_args, true)
		end
		return self
	end,
	
	update_all_joint_positions = function()
		for xform, obj in pairs(held_transforms) do 
			if obj.joints  then
				local active_poser = obj.poser and (uptime - obj.poser.is_open) < 5
				if (obj.show_joints or active_poser) and is_valid_obj(xform) then
					obj.joint_positions = obj.joint_positions or {}
					for i, joint in pairs((active_poser and obj.poser.all_joints) or obj.joints) do 
						obj.joint_positions[joint] = joint:call("get_WorldMatrix")
					end
				end
			end
		end
	end,
	
	update = function(self, is_known_valid)
		
		if is_known_valid or is_valid_obj(self.xform) then
			
			self.display = self.gameobj:call("get_Draw")
			if self.display_org == nil then 
				self.display_org = self.display
			end
			
			if (self.toggled_display ~= nil) and (self.display ~= self.toggled_display) then --if setting Draw is not enough, and DrawSelf must also be changed
				self.display = self.toggled_display
				self.gameobj:call("set_DrawSelf", self.display)
				self:toggle_display()
			end
			self.toggled_display = nil
			
			local parent = self.xform:call("get_Parent")
			self.parent_obj = parent and held_transforms[parent]
			self.center_obj = self.same_joints_constraint and self.parent_obj and not self.parent_obj.same_joints_constraint and self.parent_obj
			
			if parent ~= self.parent then --recreate name_w_parent
				self:set_name_w_parent(parent)
			end
			
			self.parent = parent
			self.same_joints_constraint = self.xform:call("get_SameJointsConstraint") or nil
			
			if self.behaviortrees then
				for i, bhvt_obj in ipairs(self.behaviortrees) do 
					--self.behaviortrees[i] = (touched_gameobjects[self.xform] and touched_gameobjects[self.xform].behaviortrees and touched_gameobjects[self.xform].behaviortrees[i]) or bhvt_obj
					if bhvt_obj.update then
						bhvt_obj:update()
					end
				end
			end
			
			if self.lookat_enabled and self.lookat_obj then  
				look_at(self, self.xform, self.lookat_obj.xform:call("get_WorldMatrix") )
			end
			
			if self.lookat_joints then 
				for joint, rot in pairs(self.lookat_joints) do 
					joint:call("set_LocalRotation", rot)
				end
			end
			
			--[[if not (figure_mode or forced_mode) and (self.joints and (self.show_joints or (self.poser and self.poser.is_open))) then
				self.joint_positions = self.joint_positions or {}
				for i, joint in pairs(self.joints) do 
					if sdk.is_managed_object(joint) then 
						self.joint_positions[joint] = { joint:call("get_LocalMatrix"), joint:call("get_WorldMatrix") }
					else
						self.joint_positions, self.show_joints, self.poser = nil
					end
				end
			end]]
			
			if self.display_transform then 
				shown_transforms[self.xform] = self
			end
			--[[for key, value in pairs(self) do 
				if not value then 
					self[key] = nil --cleans up keys, til I need one to be false
				end
			end]]
			if SettingsCache.Collection_data.sel_obj and SettingsCache.Collection_data.sel_obj.xform == self.xform then 
				SettingsCache.Collection_data.sel_obj = self 
				--[[if self.motion and self.motion:call("getDynamicMotionBankCount") == 0 then
					--re.msg_safe("creating dbank", 12355346)
					local new_dbank = sdk.create_instance("via.motion.DynamicMotionBank"):add_ref()
					if new_dbank then 
						new_dbank :call(".ctor")
						self.motion:call("setDynamicMotionBankCount", 1)
						self.motion:call("setDynamicMotionBank", 0, new_dbank)
					end
				end]]
			end
			if held_transforms[self.xform] and held_transforms[self.xform]~=self then
				self = merge_tables(self, held_transforms[self.xform], true)
				held_transforms[self.xform] = self
			end
			if SettingsCache.Collection_data.collection_xforms and SettingsCache.Collection_data.collection_xforms[self.xform] and Collection[SettingsCache.Collection_data.collection_xforms[self.xform] ] and Collection[SettingsCache.Collection_data.collection_xforms[self.xform] ]~=self then
				self = merge_tables(self, Collection[SettingsCache.Collection_data.collection_xforms[self.xform] ], true)
				Collection[SettingsCache.Collection_data.collection_xforms[self.xform] ] = self
			end
			
			if self.isRE7player then 
				local wasCutscene = self.isRE7cutscene
				self.isRE7cutscene = not (self.components_named.Humanoid:call("get_Enabled") and self.components_named.CharacterController:call("get_Enabled"))
				player = self
				if wasCutscene and not self.isRE7cutscene and is_skipping_cs then 
					scene:call("set_TimeScale(System.Single)", 1.0)
					is_skipping_cs = nil
					if stop_wwise then stop_wwise() end
				end
			end
			
			return true
		else
			clear_object(self.xform)
		end
	end,
}

GameObject.new_GrabObject = GameObject.new --overwritten by Gravity Gun
GameObject.update_GrabObject = GameObject.update --^
GameObject.new_AnimObject = GameObject.new --overwritten by Enhanced Model Viewer
GameObject.update_AnimObject = GameObject.update --^

--Load cache, and create list of names of them for imgui in RN[] -------------------------------------------------------------------------------
local function init_resources(force)
	if force or not static_funcs.loaded_json then
		static_funcs.loaded_json = true
		if SettingsCache.load_json then
			local new_cache = json.load_file("EMV_Engine\\RSCache.json")
			if new_cache then 
				new_cache = jsonify_table(new_cache, true, {dont_create_resources=true})
				if new_cache then 
					for key, value in pairs(new_cache) do 
						if type(value)=="table" then
							RSCache[key] = merge_tables(value, RSCache[key] or {}, true)
						end
					end
				end
			end
			if SettingsCache.remember_materials then 
				saved_mats = Material.load_all_mats_from_json()
			end
		end
		for key, value in pairs(RSCache or {}) do
			local resource_names_key = key:find("_resources$") and key:gsub("_resources$", "_resource_names")
			if resource_names_key and type(value) == "table" then
				local new_table = {}
				RN[resource_names_key] = {" "}
				for name, resource in orderedPairs(value) do 
					local converted_name = name:match("^.+%[@?(.+)%]") or name
					table.insert(RN[resource_names_key], converted_name)
					new_table[converted_name] = resource
				end
				RSCache[key] = new_table
			end
		end
	end
	return true
	--re.msg_safe("init resources", 123145125)
end
static_funcs.init_resources = init_resources
static_funcs.loaded_json = false

--Load other settings, enums, misc tables:
default_SettingsCache = deep_copy(SettingsCache)

local function init_settings()
	
	local try, new_cache = pcall(json.load_file, "EMV_Engine\\SettingsCache.json")
	if try and new_cache then SettingsCache.load_json = new_cache.load_json end
	
	if try and new_cache and SettingsCache.load_json then 
		try, new_cache = pcall(jsonify_table, new_cache, true)
		if try and new_cache then 
			for key, value in pairs(SettingsCache) do 
				if new_cache[key] == nil then 
					new_cache[key] = value  --add any new settings from this script
				end 
			end
			SettingsCache = new_cache
			SettingsCache.exception_methods = {}
		end
		
		CachedGlobals = jsonify_table(json.load_file("EMV_Engine\\CachedGlobals.json") or {}, true)
		for key, value in pairs(CachedGlobals) do 
			if sdk.is_managed_object(value) then
				_G[key] = value
			end
		end
		
		Hotkey.used = jsonify_table(json.load_file("EMV_Engine\\Hotkeys.json") or {}, true)
		CachedActions = jsonify_table(json.load_file("EMV_Engine\\CachedActions.json") or {}, true)
		Collection = jsonify_table(json.load_file("EMV_Engine\\Collection.json") or {}, true)
	end
end

local function dump_settings(no_resources)
	if SettingsCache.load_json then 
		json.dump_file("EMV_Engine\\SettingsCache.json", jsonify_table(SettingsCache))
		json.dump_file("EMV_Engine\\CachedActions.json", jsonify_table(CachedActions))
		CachedGlobals = {}
		if not isRE7 and not isRE4 then
			for key, value in pairs(_G) do 
				if type(key) == "string" and ({pcall(sdk.is_managed_object, value)})[2] == true then 
					CachedGlobals[key] = value
				end
			end
			json.dump_file("EMV_Engine\\CachedGlobals.json",  jsonify_table(CachedGlobals, false))
		end
		json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
		pcall(function()
			if not no_resources then
				json.dump_file("EMV_Engine\\RSCache.json", jsonify_table(RSCache))
			end
		end)
	end
end

--On Script Reset ------------------------------------------------------------------------------------------------------------------------------------------
re.on_script_reset(function()	
	dump_settings()
	--for i, gameobj in ipairs(lua_get_system_array(scene:call("findGameObjectsWithTag(System.String)", "Lua"))) do
	--	gameobj:call("destroy", gameobj)
	--end
end)

--On UpdateMotion -------------------------------------------------------------------------------------------------------------------------------------------
re.on_application_entry("UpdateMotion", function() 
	
	if misc_vars.update_modules[SettingsCache.update_module_idx] == "UpdateMotion" then
		if figure_mode or forced_mode or cutscene_mode then --Enhanced Model Viewer will update it
			for xform, obj in pairs(held_transforms) do 
				obj:update_AnimObject()
			end
		else
			for xform, obj in pairs(held_transforms) do 
				obj:update()
			end
		end
		
		--if not isMHR and not isDMC then 
		--	GameObject.update_all_joint_positions()
		--end
		for managed_object, args in pairs(deferred_calls) do 
			deferred_call(managed_object, args)
		end
	end
	

end)

re.on_application_entry("PrepareRendering", function()
	if misc_vars.update_modules[SettingsCache.update_module_idx] == "PrepareRendering" then
		if figure_mode or forced_mode or cutscene_mode then --Enhanced Model Viewer will update it
			for xform, obj in pairs(held_transforms) do 
				obj:update_AnimObject()
			end
		else
			for xform, obj in pairs(held_transforms) do 
				obj:update()
			end
		end
		
		--if not isMHR and not isDMC then 
		--	GameObject.update_all_joint_positions()
		--end
		for managed_object, args in pairs(deferred_calls) do 
			deferred_call(managed_object, args)
		end
	end
	
	for xform, joints in pairs(frozen_joints) do
		if is_valid_obj(xform) then
			for joint, tbl in pairs(joints) do
				if tbl[1] then
					joint:call("set_LocalEulerAngle", tbl[1])
				end
				if tbl[2] then
					joint:call("set_LocalPosition", tbl[2])
				end
			end
		else
			frozen_joints[xform] = nil
		end
	end
end)

--On pre-LockScene -------------------------------------------------------------------------------------------------------------------------------------------
re.on_pre_application_entry("LockScene", function()
	--if isMHR or isDMC then 
		GameObject.update_all_joint_positions()
	--end
end)

--On UpdateHID -------------------------------------------------------------------------------------------------------------------------------------------
re.on_application_entry("UpdateHID", function()
	update_keyboard_state()
	update_mouse_state()
	if tics > 1 then --and not reframework:is_drawing_ui() then 
		for name, hk_tbl in pairs(Hotkey.used) do
			if hk_tbl.imgui_keyname then
				if not hk_tbl.update then 
					hk_tbl = Hotkey:new(hk_tbl)
					Hotkey.used[hk_tbl.imgui_keyname] = hk_tbl
				end
				Hotkeys[hk_tbl.imgui_keyname] = hk_tbl
				hk_tbl:update()
			end
		end
	end
end)

--On BeginRendering ---------------------------------------------------------------------------------------------------------------------------------------
re.on_application_entry("BeginRendering", function()
	for xform, obj in pairs(held_transforms) do 
		if xform:read_qword(0x10) ~= 0 then 
			if obj.mesh and not obj.materials then 
				obj:set_materials() 
			end
			if obj.materials and obj.update_materials then 
				for i, mat in ipairs(obj.materials) do 
					for v, var_id in ipairs(mat.deferred_vars) do
						mat.mesh:call("set" .. mat_types[mat.variable_types[var_id] ], mat.id, var_id-1, mat.variables[var_id]) 
						--log.debug("set" .. mat_types[mat.variable_types[var_id] ] .. ", " .. mat.id .. ", " .. var_id-1 .. ", " .. mat.variables[var_id])
					end
					mat.deferred_vars = {}
					mat:update()
				end
				obj.update_materials = nil
			end
		end
	end
end)

--Hooked copy of handle_address:
object_explorer = merge_tables({old=object_explorer}, getmetatable(object_explorer))
object_explorer.handle_address = function(self, address, skip_ctl_panel)
	if object_explorer.old then
		object_explorer.old:handle_address(address)
		if not (SettingsCache.embed_mobj_control_panel or skip_ctl_panel) and imgui.tree_node("Managed Object Control Panel") then
			if type(address)=="number" then
				address = sdk.to_managed_object(address)
			end
			imgui.managed_object_control_panel(address)
			imgui.tree_pop()
		end
	end
end

--On Frame ------------------------------------------------------------------------------------------------------------------------------------------------
re.on_frame(function()
	
	if isGNG and os.clock() < 30.0 then return end
	
	re.msgs_this_frame = 0
	static_objs.cam = sdk.get_primary_camera()
	pcall(function() 
		last_camera_matrix = static_objs.cam and static_objs.cam:call("get_WorldMatrix") or last_camera_matrix
	end)
	
	tics = tics + 1
	uptime = os.clock()
	history_input_this_frame = nil
	
	if tics == 1 then
		init_settings()
	end
	
	
	--deferred_calls = {}
	for instance, data in pairs(metadata) do
		local o_tbl = instance._
		if o_tbl then 
			if not (o_tbl.keep_alive or o_tbl.is_frozen) then
				o_tbl.last_opened = o_tbl.last_opened or uptime
			end
			if o_tbl.invalid or (o_tbl.last_opened and (uptime - o_tbl.last_opened) > 5) then
				metadata[instance] = nil
				log.info("REMgdObj deleting " .. o_tbl.name)
			elseif not o_tbl.is_vt then
				instance:__update(nil, o_tbl.clear)
				o_tbl.clear = nil
			end
			o_tbl.is_open = nil
		--else
		--	metadata[instance] = nil
		end
	end
	
	if random(60) then
		for key, tbl in pairs(G_ordered) do
			if not tbl.open or (uptime > tbl.open + 30) then
				G_ordered[key] = nil --periodically purge old table metadatas
			end
		end
	end
	
	for managed_object, args in pairs(on_frame_calls) do 
		deferred_call(managed_object, args, nil, true) 
	end
	
	for tbl_addr, metadata in pairs(__temptxt or {}) do
		if metadata.___tics + 240 < tics then
			__temptxt[tbl_addr] = nil
		end
	end
	
	player = player or get_player(true)
	
	if isRE7 and not re7csettings and reframework:is_drawing_ui() then 
		if player and player.isRE7cutscene then
			imgui.begin_window("RE7 Cutscene Skipper", nil, 0)
				if imgui.button("Skip Cutscene") or is_skipping_cs then 
					stop_wwise = stop_wwise or function()
						for i, wwise in ipairs(findc("via.wwise.WwiseContainer")) do 
							wwise:call("stopAll()")
							--for c=0, wwise:call("getContainableAssetCount")-1 do
								--local asset = wwise:call("getContainableAsset", c)
								--local asset_path = asset and asset:call("get_ResourcePath")
								--if asset_path and asset_path:lower():find("event") then 
								--	wwise:call("stopAll()")
								--	break
								--end
							--end
						end
						stop_wwise = nil
					end
					scene:call("set_TimeScale(System.Single)", 100.0)
					is_skipping_cs = true
				end
			imgui.end_window()
		elseif is_skipping_cs then --if a cutscene ends with no player:
			scene:call("set_TimeScale(System.Single)", 1.0)
			is_skipping_cs = nil
			stop_wwise()
		end
	end
	
	for xform, object in pairs(shown_transforms) do 
		if xform:read_qword(0x10) == 0 then 
			clear_object(xform)
			--shown_transforms[xform] = nil
		else
			local pos, rot, scale = get_trs(xform) 
			draw.world_text(object.name .. "\n" .. log_transform(pos, rot, scale), pos, 0xFF00FFFF)
			
		end
	end
	
	local good_objs = {}
	for obj, tbl in pairs(world_positions) do 
		local keep_updating
		for name, sub_tbl in pairs(tbl) do
			if sub_tbl.active then
				keep_updating = true
				if (good_objs[obj] or sdk.is_managed_object(obj)) then
					good_objs[obj] = true
					sub_tbl.world_value = (sub_tbl.method and sub_tbl.method:call(obj)) or (sub_tbl.field and sub_tbl.field:get_data(obj))
					if sub_tbl.as_local and obj._.xform then 
						sub_tbl.world_value = sub_tbl.world_value + obj._.xform:call("get_Position")
					end
					if sub_tbl.world_value then 
						draw_world_pos(sub_tbl.world_value, sub_tbl.name, sub_tbl.color)
					end
				else
					world_positions[obj] = nil
				end
			end
		end
		if keep_updating and obj._ then
			obj._.last_opened = uptime
		end
	end
	
	if saved_mats then --for managing saved material settings etc
		local meshes
		for name, args in pairs(saved_mats) do
			if args.active then
				local obj_name, parent_name = name
				if name:find("%.") then 
					parent_name = name:match("^(.-)%.")
					obj_name = name:match("^.+%.(.-)$")
				end
				
				local gameobj = scene:call("findGameObject(System.String)", parent_name or obj_name)
				--log.info("searching for " .. (parent_name or obj_name))
				if gameobj then 
					local xform = gameobj:call("get_Transform")
					--detect that one example of the object exists and then refresh the whole list if it's not already cached:
					if not saved_mats[name].__objects or not saved_mats[name].__objects[xform] then 
						local searchresults = scene and lua_get_system_array(scene:call("findComponents(System.Type)", sdk.typeof("via.render.Mesh")))
						for i, result in ipairs(searchresults or {}) do
							local r_gameobj = get_GameObject(result)
							if r_gameobj and (r_gameobj:call("get_Name") == (parent_name or obj_name)) then 
								local r_xform = r_gameobj:call("get_Transform")
								local to_search = parent_name and get_children(r_xform) or {r_xform}
								for i, xf in ipairs(to_search) do
									local mesh = (not parent_name and result) or lua_find_component(get_GameObject(xf), "via.render.Mesh")
									if mesh then
										local mesh_name = mesh:call("getMesh")
										mesh_name = mesh_name and mesh_name:call("ToString()"):match("^.+%[@?(.+)%]"):lower()
										if (args.swap_mesh or (args.m[mesh_name] and (not args.mesh or (mesh_name==args.mesh)))) then
											local go = held_transforms[xf] or GameObject:new_AnimObject{xform=xf}
											if not go:load_json_mesh() then
												go:set_materials()
											end
											for i, mat in ipairs(go.materials) do
												mat:load_json_material()
											end
											saved_mats[name].__objects = saved_mats[name].__objects or {}
											saved_mats[name].__objects[xf] = go
										--else
										end
									end
								end
							end
						end
						--cache the first one even if it wasnt a match just to keep it from searching again:
						saved_mats[name].__objects = saved_mats[name].__objects or {}
						saved_mats[name].__objects[xform] = saved_mats[name].__objects[xform] or held_transforms[xform] or GameObject:new_AnimObject{xform=xform} 
					end
				end
				if saved_mats[name].__objects then 
					for xform, object in pairs(saved_mats[name].__objects) do 
						if not is_valid_obj(object.xform) then 
							saved_mats[name].__objects[object.xform] = nil
							clear_object(object.xform)
						end
					end
					if get_table_size(saved_mats[name].__objects) == 0 then saved_mats[name].__objects = nil end
				end
			end
		end
	end
	
	if reframework:is_drawing_ui() then
		shown_transforms = {} 
		--SettingsCache.detach_collection = SettingsCache.detach_collection and not not next(Collection)
		if not SettingsCache.detach_collection or (imgui.begin_window("Collection", true, SettingsCache.transparent_bg and 128 or 0) == false) then 
			SettingsCache.detach_collection = false
		end
		if SettingsCache.detach_collection then
			show_collection()
			imgui.end_window()
		end
		--world_positions = {} 
	end
	
	if _G.resource_added then
		_G.resource_added = nil
		json.dump_file("EMV_Engine\\RSCache.json", jsonify_table(RSCache))
	end
end)

--On Draw UI (Show Settings) ---------------------------------------------------------------------------------------------------------------------------------------
re.on_draw_ui(function()
	
	--[[if counter > 0 then
		imgui.text("Call Count: " .. tostring(counter))
	end]]
	
	local csetting_was_changed, special_changed
	
	if imgui.tree_node("EMV Engine Settings") then
		special_changed, SettingsCache.load_json = imgui.checkbox("Remember Settings", SettingsCache.load_json); csetting_was_changed = csetting_was_changed or changed
		changed, SettingsCache.affect_children = imgui.checkbox("Affect Children", SettingsCache.affect_children); csetting_was_changed = csetting_was_changed or changed
		changed, SettingsCache.cache_orderedPairs = imgui.checkbox("Cache Ordered Dictionaries", SettingsCache.cache_orderedPairs); csetting_was_changed = csetting_was_changed or changed
		changed, SettingsCache.remember_materials = imgui.checkbox("Remember Material Settings", SettingsCache.remember_materials); csetting_was_changed = csetting_was_changed or changed
		if imgui.tree_node("Managed Object Control Panel Settings") then
			changed, SettingsCache.max_element_size = imgui.drag_int("Max Fields/Properties Per-Grouping", SettingsCache.max_element_size, 1, 1, 2048); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.show_all_fields = imgui.checkbox("Show Extra Fields", SettingsCache.show_all_fields); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.embed_mobj_control_panel = imgui.checkbox("Embed Into Object Explorer (Lua)", SettingsCache.embed_mobj_control_panel); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.use_pcall = imgui.checkbox("Exception Handling", SettingsCache.use_pcall); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.update_module_idx = imgui.combo("Update During", SettingsCache.update_module_idx, misc_vars.update_modules); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.use_color_bytes = imgui.checkbox("Display Colors as Bytes", SettingsCache.use_color_bytes); csetting_was_changed = csetting_was_changed or changed
			
			if SettingsCache.remember_materials and next(saved_mats) and imgui.tree_node("Saved Material Settings") then
				--if imgui.button("Clear") then 
				--	saved_mats = {}
				--end
				read_imgui_element(saved_mats)
				imgui.tree_pop()
			end
			imgui.tree_pop()
		end
		if imgui.tree_node("Hotkeys") then 
			if imgui.button("Clear Hotkeys") then 
				Hotkeys, Hotkey.used = {}, {}
				json.dump_file("EMV_Engine\\Hotkeys.json", Hotkey.used)
			end
			local last_name
			for key_name, hk_tbl in orderedPairs(Hotkey.used) do
				if hk_tbl then 
					if not hk_tbl.display_imgui_button then
						hk_tbl = Hotkey:new(hk_tbl, hk_tbl)
						Hotkeys[key_name] = hk_tbl
					end
					if not hk_tbl then 
						Hotkey.used[key_name] = nil
						goto continue
					end
					if not hk_tbl.gameobj_name or hk_tbl.gameobj_name ~= last_name then 
						imgui.spacing()
						last_name = hk_tbl.gameobj_name
						imgui.text(last_name .. ":")
					end
					imgui.text("    ")
					imgui.same_line()
					hk_tbl:display_imgui_button()
					imgui.same_line()
					imgui.push_id(hk_tbl.hash)
						if imgui.tree_node("") then 
							read_imgui_element(hk_tbl)
							imgui.tree_pop()
						end
					imgui.pop_id()
					::continue::
				end
			end
			imgui.tree_pop()
		end
		if imgui.tree_node("Deferred Method Calls") then
			if imgui.button("Clear") then
				old_deferred_calls = {}
				deferred_calls = {}
			end
			read_imgui_element(old_deferred_calls)
			imgui.tree_pop()
		end
		
		if not _G.search and imgui.tree_node("Table Settings") then 
			changed, SettingsCache.max_element_size = imgui.drag_int("Elements Per Grouping", SettingsCache.max_element_size, 1, 10, 1000); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.always_update_lists = imgui.checkbox("Always Update Lists", SettingsCache.always_update_lists); csetting_was_changed = csetting_was_changed or changed 
			changed, SettingsCache.show_editable_tables = imgui.checkbox("Editable Tables", SettingsCache.show_editable_tables); csetting_was_changed = csetting_was_changed or changed 
			if isDMC then
				changed, SettingsCache.add_DMC5_names = imgui.checkbox("Add Character Names", SettingsCache.add_DMC5_names); csetting_was_changed = csetting_was_changed or changed 
			end
			
			imgui.same_line() 
			if imgui.button("Reset Settings") then 
				SettingsCache = deep_copy(default_SettingsCache)
				changed = true
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
		imgui.tree_pop()
	end
	
	if EMV.displayResourceEditor and imgui.tree_node("Resource Editor") then --, {check_add_func=(function(str) return str:lower():find("%.[psm][fcd][bnf]2?%.") end)} --tdb_ver >= 69 and 
		EMV.displayResourceEditor()
		imgui.tree_pop()
	end
	
	if imgui.tree_node("Collection") then --next(Collection) and 
		imgui.begin_rect()
			changed, SettingsCache.detach_collection = imgui.checkbox("Detach", SettingsCache.detach_collection); csetting_was_changed = changed or csetting_was_changed
			imgui.same_line()
			show_collection()
		imgui.end_rect(2)
		imgui.tree_pop()
	end
	
	if special_changed or (SettingsCache.load_settings and (csetting_was_changed or random(255))) then
		special_changed = nil
		dump_settings()
	end
	
	update_lists_once = nil
end)


--These functions available by require() ------------------------------------------------------------------------------------------
EMV = {
	GameObject = GameObject,
	REMgdObj = REMgdObj,
	ChainGroup = ChainGroup,
	ChainNode = ChainNode,
	Material = Material,
	BHVT = BHVT,
	Hotkey = Hotkey,
	ImguiTable = ImguiTable,
	default_SettingsCache = default_SettingsCache,
	static_objs = static_objs,
	static_funcs = static_funcs,
	statics = statics,
	cog_names = cog_names,
	bool_to_number = bool_to_number,
	number_to_bool = number_to_bool,
	random_range = random_range,
	random = random,
	create_REMgdObj = create_REMgdObj,
	get_valid = get_valid,
	is_only_my_ref = is_only_my_ref,
	is_valid_obj = is_valid_obj,
	orderedNext = orderedNext,
	orderedPairs = orderedPairs,
	run_command = run_command,
	merge_indexed_tables = merge_indexed_tables,
	merge_tables = merge_tables,
	deep_copy = deep_copy,
	insert_if_unique = insert_if_unique,
	can_index = can_index,
	jsonify_table = jsonify_table,
	mouse_state = mouse_state,
	kb_state = kb_state,
	get_mouse_device = get_mouse_device,
	get_kb_device = get_kb_device,
	split = split,
	Split = Split,
	vector_to_table = vector_to_table,
	magnitude = magnitude,
	mat4_scale = mat4_scale,
	write_vec34 = write_vec34,
	read_vec34 = read_vec34,
	read_mat4 = read_mat4,
	write_mat4 = write_mat4,
	trs_to_mat4 = trs_to_mat4,
	mat4_to_trs = mat4_to_trs,
	get_trs = get_trs,
	create_resource = create_resource,
	get_folders = get_folders,
	get_table_size = get_table_size,
	isArray = isArray,
	arrayRemove = arrayRemove,
	deferred_call = deferred_call,
	get_children = get_children,
	is_child_of = is_child_of,
	get_player = get_player,
	constructor = constructor,
	is_lua_type = is_lua_type,
	delete_component = delete_component,
	lua_find_component = lua_find_component,
	lua_get_components = lua_get_components,
	lua_get_enumerator = lua_get_enumerator,
	lua_get_system_array = lua_get_system_array,
	reverse_table = reverse_table,
	clamp = clamp,
	smoothstep = smoothstep,
	generate_statics = generate_statics,
	get_enum = get_enum,
	value_to_obj = value_to_obj,
	to_obj = to_obj,
	log_value = log_value,
	logv = logv,
	log_transform = log_transform,
	log_bytes = log_bytes,
	read_bytes = read_bytes,
	log_method = log_method,
	log_field = log_field,
	log_typedef = log_typedef,
	vector_to_string = vector_to_string,
	mat4_to_string = mat4_to_string,
	hashing_method = hashing_method,
	get_gameobj_path = get_gameobj_path,
	draw_world_pos = draw_world_pos,
	offer_show_world_pos = offer_show_world_pos,
	show_imgui_vec4 = show_imgui_vec4,
	imgui_chain_settings = imgui_chain_settings,
	read_field = read_field,
	show_field = show_field,
	show_prop = show_prop,
	editable_table_field = editable_table_field,
	imgui_anim_object_viewer = imgui_anim_object_viewer,
	--imgui_behaviortrees = imgui_behaviortrees,
	imgui_saved_materials_menu = imgui_saved_materials_menu,
	draw_material_variable = draw_material_variable,
	show_imgui_mats = show_imgui_mats,
	is_unique_name = is_unique_name,
	contains_xform = contains_xform,
	look_at = look_at,
	offer_grab = offer_grab,
	add_resource_to_cache = add_resource_to_cache,
	add_pfb_to_cache = add_pfb_to_cache,
	search = search,
	sort = sort,
	sort_components = sort_components,
	closest = closest,
	calln = calln,
	find = find,
	findc = findc,
	findtdm = findtdm,
	find_index = find_index,
	qsort = qsort,
	read_imgui_pairs_table = read_imgui_pairs_table,
	read_imgui_element = read_imgui_element,
	get_first_gameobj = get_first_gameobj,
	get_all_folders = get_all_folders,
	get_transforms = get_transforms,
	searchf = searchf,
	check_key_released = check_key_released,
	get_anim_object = get_anim_object,
	dump_settings = dump_settings,
	clear_object = clear_object,
	make_obj = make_obj,
	create_gameobj = create_gameobj,
	obj_to_json = obj_to_json,
	get_body_part = get_body_part,
	is_obj_or_vt = is_obj_or_vt,
	get_GameObject = get_GameObject,
	get_fields_and_methods = get_fields_and_methods,
	nextValue = nextValue,
	get_args = get_args,
	read_unicode_string = read_unicode_string,
}

return EMV