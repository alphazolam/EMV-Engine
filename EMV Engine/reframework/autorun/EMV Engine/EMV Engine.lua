--EMV_Engine.lua by alphaZomega
--Console, imgui and support classes and functions for REFramework
--v1.0, June 26 2022
--if true then return end
--Global variables --------------------------------------------------------------------------------------------------------------------------
_G["is" .. reframework.get_game_name():sub(1, 4):upper()] = true --sets up the "isRE2", "isRE3" etc boolean
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
default_SettingsCache = {}
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
}

--tmp:call("trigger", )

--Local copies for performance --------------------------------------------------------------------------------------------------------------
local next = next
local ipairs = ipairs
local pairs = pairs
--tmp:trigger26{ tmp._.gameobj, -621435095, tmp._.gameobj, 0, req, false, false, false, 12.0, }
--Local variables ---------------------------------------------------------------------------------------------------------------------------
local uptime = os.clock()
local tics, toks = 0, 0
local changed, was_changed, try, out, value
local game_name = reframework.get_game_name()
local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene")
local msg_ids = {}
local saved_mats = {} --Collection of auto-applied altered material settings for GameObjects (by name)
local created_resources = {}
local chain_bone_names = {}
local CachedActions = {}
local CachedGlobals  = {}
Hotkeys = {}
re3_keys = {}		
local cached_chain_settings = {}
local cached_chain_settings_names = {}
local bool_to_number = { [true]=1, [false]=0 }
local number_to_bool = { [1]=true, [0]=false }
local tds = {
	via_hid_mouse_typedef = sdk.find_type_definition("via.hid.Mouse"),
	via_hid_keyboard_typedef = sdk.find_type_definition("via.hid.Keyboard"),
	guid = sdk.find_type_definition(sdk.game_namespace("GuidExtention")),
}

static_objs = {
	playermanager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager")) or sdk.get_managed_singleton("snow.player.PlayerManager"),
	via_hid_mouse = sdk.get_native_singleton("via.hid.Mouse"),
	via_hid_keyboard = sdk.get_native_singleton("via.hid.Keyboard"),
	setn = ValueType.new(sdk.find_type_definition("via.behaviortree.SetNodeInfo")),
}
static_objs.setn:call(".ctor")
static_objs.setn:call("set_Fullname", true)

local static_funcs = {
	distance_method = sdk.find_type_definition((isRE2 and "app.MathEx") or sdk.game_namespace("MathEx")):get_method("distance(via.GameObject, via.GameObject)"),
	get_chain_method = sdk.find_type_definition("via.Component"):get_method("get_Chain"),
	guid_method = sdk.find_type_definition("via.gui.message"):get_method("get"),
	mk_gameobj = sdk.find_type_definition("via.GameObject"):get_method("create(System.String)"),
	mk_gameobj_w_fld = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)"),
	string_hashing_method = sdk.find_type_definition("via.murmur_hash"):get_method("calc32"),
}

local cog_names = { 
	["re2"] = "COG", 
	["re3"] = "COG", 
	["re7"] = "Hip", 
	["re8"] = "Hip", 
	["dmc5"] = "Hip", 
	["mhrise"] = "Cog", 
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
	REManagedObject = scene,
	RETransform = scene:call("get_FirstTransform"),
}
if true then --or not isRE7 then 
	REMgdObj_objects.SystemArray = sdk.find_type_definition("System.Array"):get_method("CreateInstance"):call(nil, sdk.typeof("via.Transform"), 0):add_ref()
	REMgdObj_objects.ValueType = ValueType.new(sdk.typeof("via.AABB"))
	--REMgdObj_objects.BehaviorTree = findc("via.motion.MotionFsm2")[1]
end

--local addresses of important functions and tables defined later:
local GameObject
local BHVT
local Hotkey
local MoveSequencer
local read_imgui_element
local show_imgui_mat
local get_mgd_obj_name
local create_REMgdObj
local add_to_REMgdObj
local obj_to_json
local jsonify_table
local get_fields_and_methods
local lua_find_component
local deferred_call
local hashing_method

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

--Merge ordered lists
local function merge_indexed_tables(table_a, table_b, is_vec)
	table_a = table_a or {}
	table_b = table_b or {}
	if is_vec then 
		local new_tbl = {} 
		for i, value_a in ipairs(table_a) do table.insert(new_tbl, value_a) end
		for i, value_b in ipairs(table_b) do table.insert(new_tbl, value_b) end
		return new_tbl
	else
		for i, value_b in ipairs(table_b) do table.insert(table_a, value_b) end
		return table_a
	end
end

--Merge hashed dictionaries
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

local function deep_copy(tbl)
	local new_tbl = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			new_tbl[key] = deep_copy(value)
		else
			new_tbl[key] = value
		end
	end
	return new_tbl
end

--Reverse a table order
local function reverse_table(t)
	local new_table = {}
	for i =  #t, 1, -1 do 
		table.insert(new_table, t[i])
	end
	return new_table
end

--like find_index but simpler
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

--Sort any table by a given key
local function qsort(tbl, key, ascending)
	if can_index(tbl) and tbl[1] and (tbl[1][key] ~= nil) and isArray(tbl) then --(({ pcall(function() local test = (tbl[1][key] < tbl[1][key]) end) })[2] == true)
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
			if type(tbl[1][key]) == "table" then 
				if isArray(tbl[1][key]) then 
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
	log.info("__genOrderedIndex " .. tics)
    return orderedIndex
end

local function orderedNext(t, state)
    local key = nil
    if state == nil then
		local do_multitype = type(state) ~= "string" and type(state) ~= "number"
		if not G_ordered[t] or (G_ordered[t].ords and (#G_ordered[t].ords ~= get_table_size(t))) then 
			t.__orderedIndex = __genOrderedIndex(t , do_multitype)
			G_ordered[t] = {ords=t.__orderedIndex, open=uptime}
		end
		t.__orderedIndex = G_ordered[t].ords or __genOrderedIndex( t , do_multitype)
        key = t.__orderedIndex[1]
    elseif t.__orderedIndex then
		t.__orderedIndex = G_ordered[t].ords
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end
    if key then
        return key, t[key]
    end
    t.__orderedIndex = nil
    return
end


local function orderedPairs(t)
    return orderedNext, t, nil
end

--Call re.msg without displaying every single frame -----------------------------------------------------------------------------------------
function re.msg_safe(msg, msg_id, frame_limit) 
	frame_limit = frame_limit or 15
	if msg_id and (not msg_ids[msg_id] or ((tics == msg_ids[msg_id])) or (frame_limit and ((tics - msg_ids[msg_id]) > frame_limit))) then
		msg_ids[msg_id] = tics
		re.msg("Frame " .. (tics - (msg_ids[msg_id] or 0)) ..  " " .. tostring(msg))
	else
		log.info("Frame " .. tics .. " Unsafe re.msg output: " .. tostring(msg))
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
local function find(typedef_name, non_transforms) --find components by type, returned as via.Transforms
	local typeof = sdk.typeof(typedef_name)
	local result
	if typeof then 
		result = scene and scene:call("findComponents(System.Type)", typeof)
		result = result and result.get_elements and result:get_elements() or {}
		if not non_transforms then
			local xforms = {}
			for i, item in ipairs(result) do 
				table.insert(xforms, item:call("get_GameObject"):call("get_Transform"))
			end
			return xforms
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
local function findc(typedef_name)
	return find(typedef_name, true)
end

--Add BehaviorTrees to REMgdObj:
--REMgdObj_objects.BHVT = findc("via.motion.MotionFsm2")[1]
--REMgdObj_objects.BHVT = REMgdObj_objects.BHVT and REMgdObj_objects.BHVT:call("getLayer", 0)

--Wrapper for converting an address to an object
local function to_obj(object, is_known_obj)
	if is_known_obj or sdk.is_managed_object(object) then 
		return sdk.to_managed_object(sdk.to_ptr(object)) 
	end
end

--Search the global list of all transforms by gameobject name
local function search(search_term, case_sensitive)
	local result = scene and scene:call("findComponents(System.Type)", sdk.typeof("via.Transform"))
	if result and result.get_elements then 
		local search_results = {}
		local term = not case_sensitive and search_term:lower() or search_term
		for i, element in ipairs(result:get_elements()) do
			local name = not case_sensitive and element:call("get_GameObject"):call("get_Name"):lower() or element:call("get_GameObject"):call("get_Name")
			if name:find(term) then 
				table.insert(search_results, element)
			end
		end
		return search_results
	end
end

--Sort the list of all components
local function sort_components(tbl)
	tbl = ((not tbl or (type(tbl) == "string")) and search(tbl)) or tbl
	local ordered_indexes, output = {}, {}
	local cam_gameobj = sdk.get_primary_camera():call("get_GameObject")
	for i=1, #tbl do ordered_indexes[i]=i end
	table.sort (ordered_indexes, function(idx1, idx2)
		return static_funcs.distance_method:call(nil, tbl[idx1]:call("get_GameObject"), cam_gameobj) < static_funcs.distance_method:call(nil, tbl[idx2]:call("get_GameObject"), cam_gameobj)
	end)
	for i=1, #ordered_indexes do output[#output+1] = tbl[ ordered_indexes[i] ] end
	return output
end

--Sort a list transforms by distance to a position:
local function sort(tbl, position, optional_max_dist, only_important)
	
	position = position or sdk.get_primary_camera():call("get_WorldMatrix")[3]
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
				try, gameobj = pcall(element.call, element, "get_GameObject")
				elem_pos = try and gameobj and gameobj:call("get_Transform"):call("get_Position")
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
local function calln(object_name, method_name, args)
	return sdk.call_native_func(sdk.get_native_singleton(object_name), sdk.find_type_definition(object_name), method_name)
end

--Methods to check if managed objects are valid / usable --------------------------------------------------------------------------------------------------
--Check if a managed object is only referenced by REFramework:
local function is_only_my_ref(obj)
	if obj:read_qword(0x8) <= 0 then return true end
	--if not obj.get_reference_count or (obj:get_reference_count() <= 0) then return true end
	if not isRE7 and obj:get_type_definition():is_a("via.Component") then
		local gameobject_addr = obj:read_qword(0x10)
		if gameobject_addr == 0 or not sdk.is_managed_object(gameobject_addr) then 
			return true
		end
	end
	return false
end

--Check officially that a managed object is valid:
local function get_valid(obj)
	return true --(obj and obj.call and (obj:call("get_Valid") ~= false))
end

--General check that object is usable:
local function is_valid_obj(obj, is_not_vt)
	if type(obj)=="userdata" then 
		if (not is_not_vt and tostring(obj):find("::ValueType")) then 
			return true
		end
		return sdk.is_managed_object(obj) and get_valid(obj) and not is_only_my_ref(obj)
	end
end

--Check if an object is outwardly a ValueType or REManagedObject
local function is_obj_or_vt(obj)
	return obj and ((tostring(obj):find("::ValueType") and 1) or is_valid_obj(obj, true))
end

--View a table entry as input_text and change the table -------------------------------------------------------------------------------------------------------
local temptxt = {}
local function editable_table_field(owner_tbl, key, value)
	local m_tbl =  temptxt[owner_tbl]
	if m_tbl and m_tbl[key] ~= nil and m_tbl[key] ~= tostring(value) then 
		imgui.push_id(key)
			if imgui.button("Set") then
				local try, out = pcall(load("return " .. ((type(value) == "string") and ("'" .. m_tbl[key] .. "'") or (m_tbl[key]))))
				if try and (out ~= nil) then 
					owner_tbl[key] = out
				end
				m_tbl[key] = nil
			end
		imgui.pop_id()
		imgui.same_line() 
	end
	local changed, new_value = imgui.input_text(key, (m_tbl and m_tbl[key]) or tostring(value))
	if changed then
		temptxt[owner_tbl] = temptxt[owner_tbl] or {}
		temptxt[owner_tbl][key] = new_value
		temptxt[owner_tbl].__tics = tics
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
		o.pairs = o.is_array and ipairs or orderedPairs
		o.name = args.name or o.tbl.name
		o.is_managed_object = args.is_managed_object or true
		o.is_xform = args.is_xform or true
		o.is_component = args.is_component or true
		o.ordered_idxes = {}
		o.do_update = true
		
		local gameobj
		for key, value in o.pairs(args.tbl) do
			table.insert(o.ordered_idxes, key)
			if o.is_managed_object then
				if not sdk.is_managed_object(value)  then
					o.is_managed_object, o.is_component = nil
				elseif o.is_component then
					o.is_component = value:get_type_definition():is_a("via.Component") or nil
					o.is_xform = o.is_xform or (o.is_component and (value.__type.name == "RETransform")) or nil
					gameobj = gameobj or (o.is_component and (value:call("get_Valid") ~= false) and value:call("get_GameObject"))
					if not o.sortable and o.is_component and gameobj and (gameobj ~= value:call("get_GameObject")) then
						o.sortable = true --dont distance-sort components all from the same gameobject
					end 
				end
			end
		end
		--log.info("created ImguiTable " .. o.name .. " " .. tostring(o.ordered_idxes and #o.ordered_idxes))
		return setmetatable(o, self)
	end,
	
	update = function(self, tbl)
		
		tbl = tbl or {}
		self.tbl = self.tbl or {}
		self.open = os.clock()
		self.tbl_count = self.is_array and #tbl or get_table_size(tbl)
		self.should_update = (self.tbl_count ~= #self.ordered_idxes) or nil
		
		if self.do_update then
			--log.info("Started updating " .. (self.name or self.key) .. " at " .. tostring(os.clock()))
			local ordered_idxes = {}
			self.names = {}
			self.element_data = {}
			if self.is_vec then 
				tbl = vector_to_table(tbl)
			end
			for key, value in self.pairs(tbl) do
				ordered_idxes[#ordered_idxes+1] = key
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
				return static_funcs.distance_method:call(nil, self.tbl[idx1]:call("get_GameObject"), player_obj) < static_funcs.distance_method:call(nil, self.tbl[idx2]:call("get_GameObject"), player_obj)
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
local function read_imgui_pairs_table(tbl, key, is_array)
	
	local tbl_obj = G_ordered[key] or ImguiTable:new{tbl=tbl or {}, key=key, is_array=is_array}
	
	tbl_obj:update(tbl)
	
	G_ordered[key] = tbl_obj
	local ordered_idxes = tbl_obj.ordered_idxes
	local will_update = SettingsCache.always_update_lists or (update_lists_once and tostring(key):find(update_lists_once)) --"update_lists_once" updates console commands when "Run Again" is pressed
	
	if will_update or (tbl_obj.should_update and not imgui.same_line()  and imgui.button("Update")) then 
		tbl_obj.do_update = true
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
			changed, tbl_obj.show_closest = imgui.checkbox("Show Closest", tbl_obj.show_closest) 
			if tbl_obj.show_closest then
				changed, tbl_obj.sort_closest_optional_max_distance = imgui.drag_float("Max Distance", tbl_obj.sort_closest_optional_max_distance or 25, 1, 0, 1000)
				tbl_obj.sort_closest_optional_max_distance = changed and tonumber(tbl_obj.sort_closest_optional_max_distance) or tbl_obj.sort_closest_optional_max_distance
			end
		else
			tbl_obj.sort_closest_optional_limit, tbl_obj.sort_closest_optional_max_distance = nil
		end
	end
	
	--[[if imgui.tree_node_str_id(key .. "T", "Table Medadata") then
		read_imgui_element(tbl_obj, nil, key .. "T")
		imgui.tree_pop()
	end]]
	
	local do_subtables = ordered_idxes and (#ordered_idxes > SettingsCache.max_element_size)
	
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
				
				if tbl_obj.is_array and (tbl_obj.sorted_once or index ~= i) then 
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
								if is_obj then 
									name = elem_key .. ":	" .. logv(element)
								else
									if element.name and (element.new or element.update) then --or (can_index(element) and element.new and (element.name .. ""))
										name = elem_key .. ":	" .. element.name .. "	[Object] (" .. get_table_size(element) .. " elements)"
									elseif isArray(element) then
										name = elem_key .. ":	[table] (" .. #element .. " elements)" 
									else
										name = elem_key .. ":	" .. (((element.name and (element.name .. " ")) or (element.obj and (logv(element.obj, nil, 0) .. " "))) or "") .. "[dictionary] (" .. get_table_size(element) .. " elements)" 
									end
								end
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
							elseif imgui.tree_node_str_id(elem_key, name) then --tables/dicts/vectors
								read_imgui_pairs_table(element, key .. elem_key, elem_is_array)
								if G_ordered[key .. elem_key] then 
									G_ordered[key .. elem_key].parent = tbl_obj
									G_ordered[key .. elem_key].index = i
								end
								imgui.tree_pop()
							end
						else
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
end

--Read any one thing in imgui, loads tables or objects:
read_imgui_element = function(elem, index, key, is_vec, is_obj)
	if elem == nil then return end
	local is_vec = is_vec or tostring(elem):find(":vector")
	is_obj = is_obj or (not is_vec and can_index(elem) and type(elem.call) == "function")
	key = key or tostring(elem)
	
	if index then 
		imgui.text("[" .. index .. "] ")
		imgui.same_line()
	end
	
	if is_obj then--or is_valid_obj(elem) then 
		if imgui.tree_node_ptr_id(elem, logv(elem, nil, 0)) then 
			imgui.managed_object_control_panel(elem, key) 
			imgui.tree_pop()
		end
	elseif ((type(elem) == "table" and next(elem) ~= nil) or (is_vec and elem[1])) and pcall(pairs, elem)  then
		read_imgui_pairs_table(elem, key, (is_vec and elem[1]) or isArray(elem))
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
	return Vector4f.new(magnitude(Vector4f.new(mat[0].x, mat[1].x, mat[2].x, 0)), magnitude(Vector4f.new(mat[0].y, mat[1].y, mat[2].y, 0)), magnitude(Vector4f.new(mat[0].z, mat[1].z, mat[2].z, 0)), 0)
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

--Manually write a matrix4, or not manually if no offset is provided
local function write_mat4(managed_object, mat4, offset, is_known_valid)
	is_known_valid = is_known_valid or tostring(managed_object):find("ValueType")
	if mat4 and (is_known_valid or sdk.is_managed_object(managed_object)) then 
		if offset then 
			write_vec34(managed_object, offset, 	 mat4[0], is_known_valid)
			write_vec34(managed_object, offset + 16, mat4[1], is_known_valid)
			write_vec34(managed_object, offset + 32, mat4[2], is_known_valid)
			write_vec34(managed_object, offset + 48, mat4[3], is_known_valid)
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
	if not translation or not rotation or not scale then return Matrix4x4f.new() end
	local scale_mat = Matrix4x4f.new(
		Vector4f.new(scale.x,	 0, 		0, 		 0),
		Vector4f.new(0, 		 scale.y, 	0, 		 0),
		Vector4f.new(0, 		 0, 		scale.z, 0),
		Vector4f.new(0, 		 0, 		0, 		 1)
	)
	local new_mat = rotation:to_mat4() 
	new_mat = new_mat * scale_mat
	new_mat[3] = translation
	return new_mat
end

--Convert matrix4 to Translation, Rotation and Scale
local function mat4_to_trs(mat4)
	local pos = mat4[3]
	local rot = mat4:to_quat()
	local scale = mat4_scale(mat4)
	return pos, rot, scale
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

--Convert a float to a byte, meant for colors:
local function convert_color_float_to_byte(flt)
	local integer = math.floor(flt * 255 + 0.5)
	if integer > 255 then integer = 255 end
	return integer
end

local function smoothstep(edge0, edge1, x)
	x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0) 
	return x * x * (3 - 2 * x)
end

--Generate Enums --------------------------------------------------------------------------------------------------------
local function generate_statics(typename)
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
				raw_value = raw_value:call("ToString()")
			end
			if raw_value ~= nil then
				enum_string = enum_string .. "\n		" .. name .. " = " .. tostring(raw_value) .. ","
				enum[name] = raw_value 
				table.insert(enum_names, name .. "(" .. raw_value .. ")")
				value_to_list_order[raw_value] = #enum_names
			end
        end
    end
	--log.info(enum_string .. "\n	}" .. typename:gsub("%.", "_") .. ";\n	break;\n") --enums for RSZ template
    return enum, value_to_list_order, enum_names
end

local function generate_statics_global(typename)
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
        local static_class = generate_statics(typename)

        for k, v in pairs(static_class) do
            global[k] = v
            global[v] = k
        end
    end
    return global
end

--Generate global enums of these:
local wanted_static_classes = {
    "via.hid.GamePadButton",
    "via.hid.MouseButton",
	"via.hid.KeyboardKey",
	sdk.game_namespace("Collision.CollisionSystem.Layer"),
	sdk.game_namespace("Collision.CollisionSystem.Filter"),
	sdk.game_namespace("gimmick.CheckCondition.CheckLogic")
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
		enum, value_to_list_order, enum_names = generate_statics(return_type_name)
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
local function get_any_key_released()
	for key_id, key_name in pairs(Hotkey.keys) do
		if check_key_released(key_id) then
			return key_id, key_name
		end
	end
end

-- Set a hotkey in Imgui ------------------------------------------------------------------------------------------------------------------
local function show_hotkey_setter(button_txt, imgui_keyname, deferred_call, dfc_args, dfcall_json)
	
	imgui.same_line()
	local hk_tbl = Hotkeys[imgui_keyname]
	imgui.push_id(imgui_keyname.."K")
		
		if hk_tbl and (hk_tbl.key_name == "[Press a Key]") then
			local key_id, key_name = get_any_key_released()
			if key_id then
				hk_tbl = Hotkey:new({button_txt=button_txt, imgui_keyname=imgui_keyname, key_id=key_id, key_name=key_name, dfcall=deferred_call, obj=deferred_call.obj, dfcall_json=dfcall_json})
				if deferred_call then
					if deferred_call.args == nil then
						hk_tbl.dfcall = merge_tables({args=((type(dfc_args)~="table") and {dfc_args} or dfc_args)}, deferred_call, true) --make a unique copy of the deferred call with the given args
					end
					hk_tbl.dfcall = hk_tbl.dfcall or deferred_call
				end
				Hotkey.used[hk_tbl.imgui_keyname] = hk_tbl
				hk_tbl:set_key()
			end
		end
		
		if imgui.button((hk_tbl and hk_tbl.key_name) or "?") then
			
			--[[if not hk_tbl then 
				Hotkey.used[hk_tbl.imgui_keyname] = nil
				Hotkey.set_key()
				hk_tbl = nil
			elseif not hk_tbl.key_id then 
				hk_tbl.key_name = "[Press a Key]"
				hk_tbl.key_id = nil
			end]]
			
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
		o.hash = hashing_method(o.imgui_keyname)
		o.button_txt = args.button_txt or o.button_txt or o.imgui_keyname
		o.dfcall = args.dfcall or o.dfcall
		o.dfcall_json = args.dfcall_json or o.dfcall_json
		if o.dfcall_json then
			o.down_timer  = o.dfcall_json.down_timer 
			o.gameobj_name = o.dfcall_json.__gameobj_name
		end
		if o.dfcall then 
			o.obj = o.dfcall.obj
		end
		o.metadata = {}
		self.__index = self  
		return setmetatable(o, self)
	end,
	
	display_imgui_button = function(self, button_txt)
		button_txt = button_txt or self.button_txt
		if imgui.button_w_hotkey(button_txt, self.imgui_keyname, self.dfcall, self.dfcall and self.dfcall.args, self.dfcall_json) then
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
						local setn_arg = (arg:get_type_definition():get_name()=="SetNodeInfo") and {__is_vt=true} --awful hack fix, but it only works as a valuetype, not a REManagedObject (which it says it is)
						dmp_tbl.dfcall.args[i] = obj_to_json(arg, true, setn_arg or tbl.dfcall_json) --convert ValueType/object to json
					end
				end
				dmp_tbl.output = nil
			end
			dmp_tbl.metadata = nil
			dump_keys[name] = dmp_tbl
		end
		json.dump_file("EMV_Engine\\Hotkeys.json",  jsonify_table(dump_keys))
	end,
	
	update = function(self, force, do_deferred)
		
		self.used[self.imgui_keyname] = (self.key_id and self) or nil
		
		if self.obj and not self.pressed_down and (force or (self.key_id and check_key_released(self.key_id, not force and self.down_timer ))) then
			
			if self.dfcall.obj_json and ((type(self.obj)=="table") or (self.obj.get_type_definition and not self.obj:get_type_definition():is_a("via.Component"))) or not is_obj_or_vt(self.obj) then
				self.obj = jsonify_table(self.dfcall.obj_json, true) --there is no way to know when a non-component is an orphan, so it must be searched for and found in the scene every single keypress
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
				deferred_calls[self.obj] = dfcall
			else
				deferred_call(self.obj, dfcall)
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
			o.name = args.name or o.name or (o.obj:call("get_GameObject"):call("get_Name"))
			o._ = args._ or o._ or create_REMgdObj(o.obj, true)
			o.obj.sequencer = o
			o.GameObject = args.object or o._.go or o.object or (GameObject.new_AnimObject and GameObject:new_AnimObject{xform=o.obj:call("get_GameObject"):call("get_Transform")} or GameObject:new{xform=o.obj:call("get_GameObject"):call("get_Transform")})
			o.motion = o.GameObject.components_named.Motion
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
					--re.msg_safe("finished", 1242315253)
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
	example = example and ((type(example)=="number") or (type(example)=="string") or (type(example)=="boolean") or tostring(example):match("glm::(.+)%<"))
	return example or (typedef_name == "System.String") or (typedef:is_value_type() and ((typedef:get_valuetype_size() < 17) or typedef_name:find("via.mat"))) or nil
end

--Turn a string into a murmur3 hash -------------------------------------------------------------------------------------------------------------
hashing_method = function(str) 
	if type(str) == "string" and tonumber(str) == nil then
		return static_funcs.string_hashing_method:call(nil, str)
	end
	return tonumber(str)
end

local get_gameobj_path = function(gameobj) 
	local folder = gameobj:call("get_Folder")
	return (((folder and folder:call("get_Path") .. "/") or "") .. gameobj:call("get_Name"))
end

--Get or create a GameObject or AnimObject class from a gameobj -----------------------------------------------------------------------------
local function get_anim_object(gameobj, args)
	local xform = gameobj and gameobj.call and ({pcall(gameobj.call, gameobj, "get_Transform")})
	xform = xform and xform[1] and xform[2]
	if xform then 
		args = args or {}
		args.xform = xform
		held_transforms[xform] = held_transforms[xform] or (GameObject.new_AnimObject and GameObject:new_AnimObject(args)) or GameObject:new(args)
		return held_transforms[xform]
	end
end

--Create a Resource (file) ------------------------------------------------------------------------------------------------------------------------
local function create_resource(resource_path, resource_type, force_create)
	resource_path = resource_path:lower()
	local ext = resource_path:match("^.+%.(.+)$")
	if not ext then return end
	RSCache[ext .. "_resources"] = RSCache[ext .. "_resources"] or {}
	if not force_create and RSCache[ext .. "_resources"][resource_path] then
		return (ext == "mesh" and RSCache[ext .. "_resources"][resource_path][1]) or RSCache[ext .. "_resources"][resource_path]
	end
	resource_type = resource_type.get_full_name and resource_type:get_full_name() or resource_type
	resource_type = resource_type:gsub("Holder", "")
	local new_resource = sdk.create_resource(resource_type, resource_path)
	local new_rs_address = new_resource and new_resource:add_ref() and new_resource:get_address()
	if type(new_rs_address) == "number" then
		local holder = sdk.create_instance(resource_type .. "Holder", true)
		if holder and holder:add_ref() and sdk.is_managed_object(holder) then 
			holder:call(".ctor")
			--deferred_calls[holder] = {lua_object=holder, method=holder.write_qword, args={0x10, new_rs_address}} 
			holder:write_qword(0x10, new_rs_address)
			RSCache[ext .. "_resources"][resource_path] = holder
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
		local output = (flag and sdk.create_instance(name, true)) or sdk.create_instance(name) or ((flag == nil) and sdk.create_instance(name, true))
		if output and output:add_ref() and td:get_method(".ctor") then
			output:call(".ctor")
		end
		return output
	end
end

--Gathers tables of data from a managed object in preparation to make it convertable to JSON by jsonify_table
obj_to_json = function(obj, do_only_metadata, args)
	
	local try, otype = pcall(obj.get_type_definition, obj)
	local is_vt = (try and otype and otype:is_value_type()) or (do_only_metadata == 1) or nil
	
	if not try or not otype or (not is_vt and not is_valid_obj(obj)) then 
		return 
	end
	local name_full = otype:get_full_name()
	
	if do_only_metadata or ((otype:is_a("via.Component") or otype:is_a("via.GameObject") or (name_full:find("Layer$")  or name_full:find("Bank$"))) and (not name_full:find("[_<>,%[%]]") and not name_full:find("Collections"))) then
		
		local j_tbl = {} 
		if not do_only_metadata or is_vt then 
			local used_fields = {}
			local propdata = metadata_methods[name_full] or get_fields_and_methods(otype)
			for field_name, field in pairs(propdata.fields) do --update fields every frame, since they are simple
				j_tbl[field_name] = field:get_data(obj)
				used_fields[field_name:match("%<(.+)%>") or field_name] = true
			end
			for method_name, method in pairs(propdata.setters) do
				local count_method = (method:get_num_params() == 2) and propdata.counts[method_name]
				if (method:get_num_params() == 1 or count_method) and not used_fields[method_name:gsub("_", "")] and not method_name:find("Count$") and not method_name:find("Num$") then
					local getter = propdata.getters[method_name]
					local prop_value 
					if tostring(prop_value):find("RETransform") then
						prop_value = {__gameobj_name=prop_value:call("get_GameObject"):call("get_Name"), __address=("obj:"..prop_value:get_address()), __typedef="via.Transform",}
					elseif not count_method then 
						prop_value = getter and getter:call(obj) --normal values
						if prop_value == "" then prop_value = nil end
					elseif getter then
						--log.info("found count method " .. count_method:get_name() .. ", count is " .. tostring(count_method:call(obj))) 
						prop_value = {}
						for i=1, count_method:call(obj) do 
							local try, item = pcall(getter.call, getter, obj, i-1)
							if try and item and sdk.is_managed_object(item) then item = obj_to_json(item) or nil end
							if type(item)=="string" and ((item == "") or item:find("%.%.%.")) then item = nil end
							prop_value[#prop_value+1] = item --lists
						end
					end
					j_tbl[method_name] = prop_value
					used_fields[method_name:gsub("_", "")] = true
				end
			end
			
			if otype:is_a("via.render.Mesh") then
				local anim_object = (obj._ and obj._.go) 
				local xform = not anim_object and obj:call("get_GameObject"):call("get_Transform")
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
		end
		
		j_tbl.__gameobj_name = (otype:is_a("via.Component") and obj:call("get_GameObject"):call("get_Name")) or (otype:is_a("via.GameObject") and obj:call("get_Name")) or nil
		j_tbl.__address = "obj:" .. obj:get_address()
		j_tbl.__typedef = name_full
		j_tbl.__is_vt = is_vt
		if args then 
			j_tbl = merge_tables(j_tbl, args)
		end
		
		return (do_only_metadata or (used_fields and next(used_fields))) and j_tbl
	end
end

--Saves editable fields of a GameObject or Component (or some managed object fields) as a JSON file
local function save_json_gameobject(anim_object, merge_table, single_component)
	local filename, output = anim_object.parent_org and held_transforms[anim_object.parent_org] and (held_transforms[anim_object.parent_org].name .. "." .. anim_object.name) 
		or anim_object.name_w_parent and anim_object.name_w_parent:gsub(" -> ", ".") or anim_object.name
	if single_component then 
		local old_file = json.load_file("EMV_Engine\\Saved_GameObjects\\" .. filename .. ".json") or {}
		local file_style = jsonify_table({[single_component]=anim_object.components_named[single_component] or anim_object.gameobj}, false, {dont_nest_components=true})
		output = {[anim_object.name]=merge_tables(old_file[anim_object.name], file_style)}
	else
		output = { [anim_object.name] = merge_tables(anim_object.components_named, {["GameObject"]=anim_object.gameobj} ) }
		for i, child in ipairs(anim_object.children or {}) do
			local child_object = held_transforms[child] or GameObject:new_AnimObject{xform=child}
			if child_object then
				output = merge_tables(output, save_json_gameobject(child_object, true))
			end
		end
	end
	if merge_table then 
		--log.info(json.dump_string(jsonify_table(output, nil, true)))
		return output
	end
	return json.dump_file("EMV_Engine\\Saved_GameObjects\\" .. filename .. ".json", jsonify_table(output, nil, {dont_nest_components=true}), filename)
end

--Loads editable fields of a GameObject or Component (or some managed object fields) from a JSON file
local function load_json_game_object(anim_object, set_props, single_component, given_name, file)
	if given_name then
		given_name = given_name:match("%.(.+)$") or given_name
		file = file or json.load_file("EMV_Engine\\Saved_GameObjects\\" .. given_name .. ".json")
		return file and jsonify_table(
			single_component and {[given_name]=file[given_name][single_component]} or file, 
			true, 
			{set_props=set_props, obj_to_load_to=(anim_object and (single_component and anim_object.components_named[single_component]) or anim_object.gameobj) or nil} 
		) or false
	elseif anim_object then
		local filename = anim_object.parent_org and held_transforms[anim_object.parent_org] and (held_transforms[anim_object.parent_org].name .. "." .. anim_object.name) or anim_object.name_w_parent:gsub(" -> ", ".") or anim_object.name
		file = file or json.load_file("EMV_Engine\\Saved_GameObjects\\" .. filename .. ".json")
		return file and jsonify_table(single_component and {[anim_object.name]=file[anim_object.name][single_component]} or file, true, {set_props=set_props}) or false
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
	local dont_nest_components = args.dont_nest_components
	local obj_to_load_to = args.obj_to_load_to
	local only_convert_addresses = args.only_convert_addresses
	local set_props = args.set_props
	local tbl_name = args.tbl_name or ""
	local convert_lua_objs = args.convert_lua_objs
	local loops = {} --prevent self-referencing objects, tables etc from infinitely looping
	
	local function recurse(tbl, tbl_key, level)
		
		level = level or 0
		local new_tbl = {}
		
		for key, value in pairs(tbl or {}) do 
			
			local tostring_val = tostring(value)
			local val_type = type(value)
			local str_prefix = go_back_to_table and ((tbl.__address and tbl.__address:sub(1,4)) or ((val_type == "string") and value:sub(1,4)))
			local splittable = str_prefix and (str_prefix == "vec:" or str_prefix == "mat:" or str_prefix == "res:" or str_prefix == "lua:")
			local is_mgd_obj, is_component, is_xform, is_gameobj = not go_back_to_table and is_valid_obj(value)
			local dont_convert = false
			if is_mgd_obj and dont_nest_components then
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
					key = "obj:" .. key:get_address() 
				elseif type(key)=="number" and not isArray(tbl) then
					key = "num:" .. key
				end
			end
			
			if not go_back_to_table and (is_mgd_obj or tostring_val:find(",float") or tostring_val:find("qua<")) then
				
				if type(value) == "number" then
					new_tbl[key] = value
				elseif is_mgd_obj and (not dont_nest_components or is_xform or (not (is_component or is_gameobj) or (level == 0))) then 
					if value:get_type_definition():get_full_name():find("Holder$") then 
						new_tbl[key] = "res:" .. value:call("ToString()") .. " " .. value:get_type_definition():get_full_name()
					else
						if only_convert_addresses then
							new_tbl[key] = "obj:" .. value:get_address()
						else
							new_tbl[key] = loops[value] or recurse(obj_to_json(value), key, level + 1)
							loops[value] = new_tbl[key]
						end
					end
				elseif can_index(value) then 
					if type(value.x) == "number" then
						new_tbl[key] = "vec:" .. value.x .. " " .. value.y .. (value.z and ((" " .. value.z) .. (value.w and (" " .. value.w) or "")) or "")
					elseif value[0] then 
						local str = "mat:" 
						for i=0, 3 do 
							if value[i].x and value[i].y then
								str = str .. value[i].x .. " " .. value[i].y .. (value[i].z and ((" " .. value[i].z) .. (value[i].w and (" " .. value[i].w) or "")) or "")
								if i ~= 3 then str = str .. " " end
							end
						end
						new_tbl[key] = str
					end
				end
			
			elseif go_back_to_table and not dont_convert and (splittable or (tbl.__component_name or tbl.__address)) then -- or str_prefix == "obj:" 
				
				local splitted = splittable and split(value:sub(5,-1), " ")
				
				if str_prefix == "res:" then
					new_tbl[key] = create_resource(splitted[1]:gsub("Resource%[", ""):gsub("%]", ""), splitted[2])
				
				elseif tbl.__component_name or str_prefix == "obj:" then
					
					--Find object in scene using clues from json table:
					local obj = obj_to_load_to or (splitted and (sdk.is_managed_object(tonumber(splitted[1])) and sdk.to_managed_object(tonumber(splitted[1]))))
					local typedef = tbl.__typedef and sdk.find_type_definition(tbl.__typedef) 
					
					if not is_valid_obj(obj) then 
						
						if typedef and (tbl.__is_vt or args.is_vt) then --create valuetypes
							obj = ValueType.new(typedef)
							if obj then obj:call(".ctor()") end
						
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
							return held_transforms[obj] or GameObject:new{xform=obj}
							 
						elseif (tbl.__is_vt or set_props) and ((tbl.__typedef ~= "via.Scene") and not (tbl.__typedef:find("[<>,%[%]]"))) then
							
							local propdata = get_fields_and_methods(typedef)
							tbl.__address = nil
							local converted_tbl = recurse(tbl, key, level + 1)
							
							for field_name, field in pairs(propdata.fields) do 
								deferred_calls[obj] = deferred_calls[obj] or {}
								local to_set = converted_tbl[field_name]
								if (to_set ~= nil) and type(to_set)~="string" then
									--log.info("Setting field " .. field_name .. " " .. logv(to_set, nil, 0) .. " for " .. logv(obj, nil, 0) )
									table.insert(deferred_calls[obj], { field=field_name, args= to_set } )
								end
							end
							if (tbl.__is_vt or set_props) then
								for method_name, method in pairs(propdata.setters) do
									if (converted_tbl[method_name] ~= nil) then
										deferred_calls[obj] = deferred_calls[obj] or {}
										local to_set = converted_tbl[method_name]
										if (type(to_set) == "table") or method:get_num_params() == 2 then 
											if to_set.__typedef == "via.Transform" then
												to_set = scene:call("findGameObject(System.String)", tbl.__gameobj_name)
												to_set = to_set and to_set:call("get_Transform")
												if to_set then table.insert(deferred_calls[obj], { method=method, args=to_set } ) end
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
															local sub_tbl = recurse(item, key, 0)
															for fname, val in pairs(sub_tbl) do 
																local sub_mth = sub_pd.setters[fname]
																if sub_mth then
																	log.info("Sub table set " .. sub_mth:get_name() .. " " .. logv(val, nil, 0) .. " for " .. logv(sub_obj, nil, 0) )
																	table.insert(deferred_calls[sub_obj], { method=sub_mth, args=val } )
																end
															end
														end
													else --if (type(to_set[i])~="string") or not to_set[i]:find("%.%.%.") then
														log.info("Multi-param set " .. method_name .. " " .. logv(to_set[i], nil, 0) .. " at idx " .. (i-1) .. " for " .. logv(obj, nil, 0) )
														table.insert(deferred_calls[obj], { method=method, args= (not method:get_param_types()[2]:is_primitive()) and {i-1, to_set[i]} or {to_set[i], i-1} } )
													end
												end
											end
										elseif (to_set ~= nil) and (to_set ~= "") then
											log.info("Setting " .. method_name .. " " .. logv(to_set, nil, 0) .. " for " .. logv(obj, nil, 0) )
											table.insert(deferred_calls[obj], { method=method, args=to_set } )
										end
									end
								end
							end
							if converted_tbl.__materials then 
								local anim_object = get_anim_object(obj:call("get_GameObject"))
								if anim_object then
									on_frame_calls[anim_object.gameobj] = {lua_object=anim_object, method=anim_object.set_materials, args={false, {mesh=obj, saved_variables=converted_tbl.__materials}}}
								end
							end
						end
						
						return obj, tbl.__copy_json and tbl
					end
				elseif splitted[8] then
					new_tbl[key] = Matrix4x4f.new(
						Vector4f.new(splitted[1], splitted[2], splitted[3], splitted[4]), 
						Vector4f.new(splitted[5], splitted[6], splitted[7], splitted[8]), 
						Vector4f.new(splitted[9], splitted[10], splitted[11], splitted[12]), 
						Vector4f.new(splitted[13], splitted[14], splitted[15], splitted[16])
					)
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
						elseif value.update then --lua classes
							if convert_lua_objs then
								new_tbl[key] = obj_to_json(value.xform, true, {__is_lua=true})
							elseif level == 0 then
								new_tbl[key] = loops[value] or recurse(value, key, level + 1)
							end
							loops[value] = new_tbl[key]
						elseif (mt == nil or mt.update == nil) and not tostring_val:find("sol%.")  then --regular tables; avoid sol objects and dont follow nested tables
							if loops[value] then 
								new_tbl[key] = loops[value]
							else
								new_tbl[key], new_tbl[key or "" .. "_json"] = recurse(value, key, level + 1)
							end
							loops[value] = new_tbl[key]
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
			local name = object:call("get_Name") or object:call("get_GameObject"):call("get_Name")
			tbl[name] = object 
			--table.insert(tbl, object)
		elseif not parent or parent == owner then 
			local sub_tbl, name = {object=object}
			sub_tbl.children = get_folders(object:call("get_Children"), object)
			if object:get_type_definition():is_a("via.Component") then 
				name = object:call("get_GameObject")
				name = name and name:call("get_Name")
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
		if child_xform == possible_parent_xform then
			return true
		end
		child_xform = child_xform:call("get_Parent")
	end
	return false
end

--Create an object and apply ctor --------------------------------------------------------------------------------------------------------
local function constructor(type_name)
	local output = sdk.create_instance(type_name)
	output:call(".ctor")
	output:add_ref()
	return output
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
					m_obj:add_ref():call("SystemCollectionsIEnumeratorReset")
					wrap_obj:add_ref():call("SystemCollectionsIEnumeratorReset")
					pcall(sdk.call_object_func, wrap_obj, ".ctor", 0) 
				end
				break
			end
		end
		local state, is_obj = fields[1]:get_data(m_obj)
		while (state == 1 or state == 0) and ({pcall(sdk.call_object_func, m_obj, "MoveNext")})[2] == true do
			local current, val = fields[2]:get_data(m_obj)
			state = fields[1]:get_data(m_obj)
			if sdk.is_managed_object(current) then 
				val = current:get_field("mValue")
				if not val then 
					is_obj = true
					current:add_ref()
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

--Gets a SystemArray 
local function lua_get_system_array(sys_array, allow_empty, convert_to_table)
	if not sys_array then return (allow_empty and {}) end
	local system_array = sys_array.get_elements and sys_array:add_ref():get_elements()
	if not system_array then
		system_array = sys_array.get_field and sys_array:get_field("mItems")
		system_array = system_array and system_array.get_elements and system_array:add_ref():get_elements()
	end
	if not system_array and sys_array.get_type_definition and sys_array:get_type_definition():get_method("GetEnumerator") then 
		system_array = lua_get_enumerator(sys_array:call("GetEnumerator"))
	end
	system_array = (allow_empty and system_array) or (system_array and system_array[1] and system_array)
	system_array = system_array and ((convert_to_table == true) and vector_to_table(system_array)) or system_array
	if system_array and (convert_to_table == 1) and tostring(system_array[1]):find("[RV][Ea][Ml][au][ne][aT]") then 
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
		system_array = dict--((get_table_size(dict) == #system_array) and dict) or system_array
	end
	return system_array
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
	if sdk.find_type_definition(component_name) then
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
local function is_unique_xform(t, xform)
	for i, v in ipairs(t) do 
		if v.xform == xform then return false end
	end
	return true
end

--Spawns a GameObject at a position in a via.Folder
local function spawn_gameobj(name, position, folder)
	position = position or Vector3f.new(0,0,0)
	local create_method = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)")
	local gameobj = create_method:call(nil, name, folder or 0)
	if gameobj then 
		gameobj:add_ref()
		gameobj:call(".ctor")
		local xform = gameobj:call("get_Transform")
		held_transforms[xform] = held_transforms[xform] or GameObject:new_AnimObject{xform=xform}
		return held_transforms[xform]
	end
end

--Make a transform or joint look at a position:
local function look_at(self, xform_or_joint, matrix)
	xform_or_joint = (self.joints and self.joints[self.lookat_joint_index]) or xform_or_joint
	matrix = matrix or (sdk.get_primary_camera():call("get_WorldMatrix"))
	if xform_or_joint and matrix then 
		xform_or_joint:call("lookAt", Vector3f.new(-matrix[3].x, 0, -matrix[3].z), Vector3f.new(0, 1, 0)) 
		--xform_or_joint:call("lookAt", Vector3f.new(-matrix[3].x, -matrix[3].y, -matrix[3].z), Vector3f.new(0, 1, 0)) 
		return 
	end
end

--Resource Management functions -----------------------------------------------------------------------------------------------------------------------------------
--Adds a resource to the cache, or returns the index to the already-cached texture in RN
local function add_resource_to_cache(resource_holder, paired_resource_holder, data_holder)
	local ret_type = data_holder and (data_holder.ret_type or data_holder.item_type)
	if not resource_holder or type(resource_holder.call) ~= "function" then --nil (unset) values, problem is that you cant easily find out the extension
		local ext = ret_type and (SettingsCache.typedef_names_to_extensions[ret_type:get_name()] or ret_type:get_name():gsub("ResourceHolder", ""):lower()) or " "
		return 1, " ", ext
	end
	local current_idx = 1
	local resource_path = resource_holder:call("ToString()"):match("^.+%[@?(.+)%]")
	if not resource_path then 
		return 1, " ", ext or " "
	end
	resource_path = resource_path and resource_path:lower()
	local ext = resource_path:match("^.+%.(.+)$")
	RSCache[ext .. "_resources"] = RSCache[ext .. "_resources"] or {}
	RN[ext .. "_resource_names"] = RN[ext .. "_resource_names"] or {" "}
	local td_name = ret_type and ret_type:get_name() or resource_holder:get_type_definition():get_name()
	SettingsCache.typedef_names_to_extensions[td_name] = SettingsCache.typedef_names_to_extensions[td_name] or ext
	if not RSCache[ext .. "_resources"][resource_path] then 
		current_idx = table.binsert(RN[ext .. "_resource_names"], resource_path)
		RSCache[ext .. "_resources"][resource_path] = ((paired_resource_holder or (ext == "mesh")) and {resource_holder, paired_resource_holder}) or resource_holder
		resource_holder:add_ref()
	else
		current_idx = find_index(RN[ext .. "_resource_names"], resource_path)
	end
	return current_idx, resource_path, ext
end

--Get the local player -----------------------------------------------------------------------------------------------------------------
local function get_player(as_GameObject)
	static_objs.playermanager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager"))
	if static_objs.playermanager then 
		local player
		if isDMC5 then 
			player = static_objs.playermanager:call("get_manualPlayer")
			player = player and player:call("get_GameObject")
		elseif isMHR then 
			player = static_objs.playermanager:call("findMasterPlayer")
		else
			player = static_objs.playermanager:call("get_CurrentPlayer")
		end
		if player and as_GameObject then 
			local xform = player and player:call("get_Transform")
			player = xform and GameObject:new{xform=xform, gameobj=player}
		end
		return player
	end
end

--Get the first GameObject in the scene:
local function get_first_gameobj()
	local xform = scene:call("get_FirstTransform")
	if xform and is_valid_obj(xform) then 
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
	transforms = transforms and transforms.get_elements and transforms:add_ref() and transforms:get_elements()
	return transforms
end
get_transforms()

--Search all via.Folders for a search term:
local function searchf(search_term)
	local all_folders = scene and get_folders(scene:call("get_Folders"))
	local results = {}
	for name, folder in pairs(all_folders) do
		if name:lower():find(search_term) then
			results[name] = folder
		end
	end
	return results
end

--Creates a new named GameObject+transform and gives it components from a list of component names:
local function create_gameobj(name, worldmatrix, target_folder, component_names)
	if not name then return end
	local new_gameobj = target_folder and static_funcs.mk_gameobj_w_fld(nil, name, target_folder) or static_funcs.mk_gameobj(nil, name)
	if new_gameobj and new_gameobj:add_ref() and new_gameobj:call(".ctor") then
		local xform = new_gameobj:call("get_Transform")
		write_mat4(xform, worldmatrix)
		if component_names then 
			for i, name in ipairs(component_names) do 
				local td = sdk.find_type_definition(name)
				local new_component = td and new_gameobj:call("createComponent(System.Type)", td:get_runtime_type())
				if new_component and new_component:add_ref() then 
					new_component:call(".ctor()")
				end
			end
		end
		return new_gameobj
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
					if not field:is_literal() and not field:is_static() then
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
			copy:add_ref()
			return copy
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
		clonobj:add_ref()
		
		local size = gobj.gameobj:get_type_definition():get_size()
		--for i = 24, size do 
		--	clonobj:write_byte(i, gobj.gameobj:read_byte(i))
		--end
		local comp_addresses = {}
		local idx_comps = {}
		for i, component in ipairs(gobj.components) do 
			local new_component = clonobj:call("createComponent", component:get_type_definition():get_runtime_type()) --clone(component) --
			if new_component then 
				new_component:add_ref()
				table.insert(idx_comps, {new=new_component, old=component})
				comp_addresses[component] = i--clone(component)
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
end]]

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
			str = str:match(",(.+)$") or str
		end
		str = ((str == "via.GameObjectRef") and "via.GameObject") or str
		output = (str and sdk.find_type_definition(str))
	end
	return ((type(output) == "userdata") and output) or nil
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
			
			local name = managed_object:get_type_definition():get_full_name() .. (args.vardata and args.vardata.name or "") .. (index or "")
			
			if old_deferred_calls[name] and old_deferred_calls[name].Error then
				log.info("Skipping broken deferred call")
				return
			end
			
			local try, out
			local freeze = args.vardata and args.vardata.freeze
			if args.vardata and args.vardata.freezetable then 
				freeze = args.vardata.freezetable[args.args[1] + 1]
			end
			
			if freeze and old_deferred_calls[name] then 
				args = old_deferred_calls[name] --keep re-using the same deferred_call from old_deferred_calls if frozen
			end
			old_deferred_calls[name] = args
			if not freeze and not index then 
				deferred_calls[managed_object] = nil
			elseif managed_object._ then 
				if freeze then 
					managed_object._.is_frozen = true
				else
					managed_object._.is_frozen = nil
				end
			end
			
			if args.lua_object then
				if args.method then 
					if args.args then
						try, out = pcall(args.method, args.lua_object, table.unpack(args.args))
					else
						try, out = pcall(args.method, args.lua_object)
					end
				elseif args.delayed_command then --commands as strings
					local tmp_object = object
					object = args.lua_object
					local try, output = pcall(load("return " .. args.delayed_command))
					if args.delayed_command_key ~= nil then 
						object[args.delayed_command_key] = output
					end
					object = tmp_object
				end
			elseif args.lua_func then --objectless lua functions like draw_line()
				if args.args then
					try, out = pcall(args.lua_func, table.unpack(args.args))
				else
					try, out = pcall(args.lua_func)
				end
			elseif args.args ~= nil then
				local value = (args.args ~= "__nil") and args.args or nil
				if args.field ~= nil and args.func == nil then
					--[[if vardata and vardata.is_lua_type == "vec" or vardata.is_lua_type == "quat" or vardata.is_lua_type == "string" or vardata.is_lua_type == "mat" then
						value = value_to_obj(value, vardata.ret_type)
					end]]
					try, out = pcall(managed_object.set_field,  managed_object, args.field, value) --fields
				elseif args.field == nil then
					if type(value) == "table" then 
						--[[for i, arg in ipairs(value) do 
							value[i] = (arg~="__nil") and arg or nil
						end]]
						if args.func then
							try, out = pcall(managed_object.call,	managed_object, args.func, 	table.unpack(value)) --methods with args 
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
		
			if not try then 
				old_deferred_calls[name].Error = tostring(out)
				old_deferred_calls[name].obj = managed_object
				log.info("Failed, Deferred Call Error:\n" .. logv(args)) 
			else--if not args.field and out==nil then
				old_deferred_calls[name].output = out
				old_deferred_calls[name].obj = managed_object
				if args.delayed_global_key ~= nil and _G[args.delayed_global_key] ~= nil  then 
					_G[args.delayed_global_key] = out
				end
				if args.vardata then 
					args.vardata.update = true
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
			if new_arr and new_arr:add_ref() then 
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
			return new_object and new_object:add_ref()
		end
	end
	return value, "no func"
end

--[[
--Convert
function create_array_object(tbl, ret_type)
	ret_type = ret_type.get_full_name and ret_type:get_full_name() or ret_type
	local new_arr = sdk.create_instance(ret_type) or sdk.create_instance(ret_type, true)
	new_arr:add_ref()
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

--Display Translation, Rotation and Scale as text
local function log_transform(pos, rot, scale, xform)
	if obj then 
		pos = pos or xform:call("get_Position")
		rot = rot or xform:call("get_Rotation")
		scale = scale or xform:call("get_LocalScale")
	end
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
						table.insert(msg, (is_vec and " [vector] " or " [table] ") .. " (" .. #value .. " elements) ") 
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
					end
				else 
					table.insert(msg, str_val)
				end
			else 
				table.insert(msg, "{}")
			end
		elseif can_index(value) then
			if type(value.__type) == "table" and value.__type.name and not value.x then --string.find(str_val, "sdk::") and not str_val:find(":vector<") then 
				local typename = value.__type.name
				if typename == "sdk::RETypeDefinition" then
					table.insert(msg, str_val .. " (" .. value:get_full_name() .. ")")
				elseif typename == "sdk::REMethodDefinition" then
					table.insert(msg, log_method(value, indent))
				elseif typename == "sdk::REField" then
					table.insert(msg, log_field(value, indent))
				--elseif typename == "sdk::ValueType" then
				--	table.insert(msg, str_val .. " (" .. value.type:get_full_name() .. ") @ " .. tostring(value:address()))
				elseif typename == "api::sdk::ValueType" or sdk.is_managed_object(value) then
					local og_value = value
					if val_type == "number" then  
						value = sdk.to_managed_object(value) 
					end 
					local typedef = value:get_type_definition()
					msg = {typedef:get_full_name()}
					--if verbose then 
						if msg[1] == "GameObject" then
							msg[1] = value:call("get_Name")
						elseif typedef:is_a("via.Component") then
							local gameobj = ({pcall(value.call, value, "get_GameObject")})
							gameobj = gameobj[1] and gameobj[2]
							if gameobj then
								table.insert(msg, 1, " " .. gameobj:call("get_Name") .. " -> ")
							end
						end
					--end
					if val_type ~= "number" then 
						table.insert(msg, " @ " .. tostring(value:get_address()))
					else 
						table.insert(msg, " @ " .. tostring(og_value))
					end
				else
					table.insert(msg, str_val)
				end
			elseif value[0] and string.find(str_val, "mat<4") then
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
	group, xform, anim_object, settings_id, settings_ref, settings, terminal_name_hash, node_count, nodes, terminal_name, show_positions, do_blend, blend_id, blend_ratio,
	
	new = function(self, args, o)
		o = o or {}
		self.__index = self  
		o.group = args.group
		o.xform = args.xform
		o.anim_object = args.anim_object or held_transforms[o.xform]
		o.chain = args.chain or o.anim_object.chain
		o.settings_ref = o.group:read_qword(0x18)
		o.settings = args.settings
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
        return setmetatable(o, self)
	end,
	
	change_custom_setting = function(self, id)
		if not (isRE8 or isMHR or isRE2) then return end
		id = id or self.settings_id
		local chain_setting = sdk.create_instance("via.motion.ChainCustomSetting")
		if chain_setting then 
			chain_setting:call(".ctor")
			if (self.settings_id ~= self.blend_id and self.chain:call("blendSetting", self.settings_id - 1, self.blend_id - 1, self.blend_ratio, chain_setting)) or (self.settings_id == self.blend_id and self.chain:call("copySetting", self.settings_id - 1, chain_setting)) then
				chain_setting:add_ref()
				self.group:write_byte(0x20, 1) --set to use custom settings
				pcall(sdk.call_object_func, self.group, "set_CustomSetting", chain_setting) --works overall but crashes if not in pcall()
				self.settings = chain_setting
			end
		end
	end,
	
	update = function(self)
		local pos_2d = {}
		for i, node in ipairs(self.nodes) do
			node:update()
			if node.pos then
				table.insert(pos_2d, draw.world_to_screen(node.pos))
				if #pos_2d > 1 and pos_2d[i-1] and pos_2d[i] then 
					if isDMC5 or isRE2 then
						on_frame_calls[self.group] = on_frame_calls[self.group] or {} --every game has its own stupid rules about this I swear...
						table.insert( on_frame_calls[self.group], { lua_func=draw.line, args=table.pack(pos_2d[i-1].x, pos_2d[i-1].y, pos_2d[i].x, pos_2d[i].y, 0xFF00FF00) })
					else
						draw.line(pos_2d[i-1].x, pos_2d[i-1].y, pos_2d[i].x, pos_2d[i].y, 0xFF00FF00)
					end
					--if parent_vec2 then draw.line(parent_vec2.x, parent_vec2.y, this_vec2.x, this_vec2.y, 0xFF00FFFF)  end
				end
			end
		end
	end,
}

--REMgdObj and its functions ----------------------------------------------------------------------------------------------------
--Scan a typedef for the best method to check the managed object's name
local function get_name_methods(ret_type, propdata, do_items)
	
	propdata = propdata or metadata_methods[ret_type:get_full_name()] or get_fields_and_methods(ret_type)
	local search_terms = {"Name", "Path", "Comment"}
	local name_methods = (not do_items and propdata.name_methods) or (do_items and propdata.item_name_methods)
	
	if not name_methods then
		name_methods = {} --{ret_type:get_method("get_Name()") and "get_Name()"}
		local uniques = {}
		for i, search_term in ipairs(search_terms) do
			for i, field_name in ipairs(propdata.field_names) do 
				if not uniques[field_name] then
					local field = propdata.fields[field_name]
					local ftype = field:get_type()
					local is_resource = ftype:get_name():find("Holder$")
					local is_str = ftype:is_a("System.String")
					if (is_resource or (is_str and (field_name:sub(-4) == search_term))) then
						uniques[field_name] = field
						table.insert(name_methods, field_name)
					end
				end
			end
			for i, name in ipairs(propdata.method_names) do
				local method = propdata.methods[name]
				if not uniques[name] and method:get_num_params() == 0 then
					local mtype = method:get_return_type()
					local is_resource = mtype:get_name():find("Holder$")
					local is_str = mtype:is_a("System.String")
					if (name:find("[Gg]et") == 1) and (is_resource or (is_str and (name:sub(-4) == search_term))) then
						uniques[name] = method
						table.insert(name_methods, name)
					end
				end
			end 
		end
		if do_items then 
			propdata.item_name_methods = name_methods
		else
			propdata.name_methods = name_methods
		end
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
			if not field:is_static() then
				local field_name = field:get_name()
				if not propdata.fields[field_name] then
					table.insert(propdata.field_names, field_name)
					propdata.fields[field_name] = field
					propdata.clean_field_names[(field_name:match("%<(.+)%>") or field_name):lower()] = i
				end
			end
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
				if method:get_num_params() == 0 and method_name:find("[Gg]et") == 1 then 
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
		
		if num_params == 0 and method:get_return_type():get_full_name() == "System.Void" and not name:find("__") then
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
	
	log.info("checking name for " .. logv(m_obj))
	o_tbl = o_tbl or m_obj._ or create_REMgdObj(m_obj)
	if not o_tbl then return end
	
	local typedef, name = (o_tbl.is_lua_type and (o_tbl.item_type or o_tbl.ret_type or o_tbl.type)) or (can_index(m_obj) and m_obj:get_type_definition())
	if not typedef then return tostring(m_obj) end
	
	if typedef:get_full_name():match("<(.+)>") then 
		name = o_tbl.name_full --Enumerators crashing
	elseif o_tbl.skeleton then
		name = o_tbl.skeleton[idx]
	elseif (type(m_obj) == "number") or (type(m_obj) == "boolean") or not can_index(m_obj) then
		name = typedef:get_name()
	elseif (type(m_obj) ~= "userdata") or (m_obj.x or m_obj[0]) then
		name = (((o_tbl.is_vt or o_tbl.is_obj) and not o_tbl.is_lua_type) and (m_obj:get_type_definition():get_method("ToString()") and m_obj:call("ToString()"))) or typedef:get_name()
	elseif typedef:is_a("via.Component") then 
		name = typedef:get_full_name()
		if typedef:is_a("via.Transform") then
			local try, gameobj = pcall(m_obj.call, m_obj, "get_GameObject")
			name = (try and gameobj and (name .. " (" .. gameobj:call("get_Name") .. ")")) or name
		end
	elseif typedef:is_a("via.GameObject") then
		try, name = pcall(sdk.call_object_func, m_obj, "get_Name")
		name = try and name
	elseif o_tbl.item_name_methods or o_tbl.name_methods then
		local fields = o_tbl.fields or (o_tbl.item_type and metadata_methods[o_tbl.item_type:get_full_name()].fields)
		--log.info("checking name methods for " .. logv(m_obj, nil, 5))
		for i, fm_name in ipairs(o_tbl.item_name_methods or o_tbl.name_methods) do
			if fields and fields[fm_name] then
				try, name = pcall(m_obj.get_field, m_obj, fm_name)
			else
				try, name = pcall(sdk.call_object_func, m_obj, fm_name)
			end
			name = try and (name ~= "") and name
			if name and (type(name) ~= "string") and name.add_ref then 
				--add_resource_to_cache(name, nil, o_tbl) --enabling this adds way too many cached resources
				name = name:call("ToString()"):match("^.+%[@?(.+)%]") --fix resources
			end
			if name then break end
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
	log.info("Name is " .. tostring(name))
	return name or ""
end

--Class for containing fields and properties and their metadata -------------------------------------------------------------------------------------------
local VarData = {
	
	new = function(self, args, o)
		if not (args.get or args.field) then return end
		
		o = o or {}
		self.__index = self
		
		local o_tbl = args.o_tbl
		local obj = o_tbl.obj
		
		o.name = args.name
		o.full_name = args.full_name
		o.field = args.field
		o.get = args.get
		o.set = args.set
		o.count = args.count
		o.ret_type = args.ret_type
		
		o.is_vt = o.ret_type:is_value_type() or nil
		--o.ret_type = evaluate_array_typedef_name(o_tbl.type, o_tbl.name_full) or o.ret_type
		rt_name = o.ret_type:get_full_name()
		o.name_methods = (metadata_methods[rt_name] and metadata_methods[rt_name].name_methods) or get_name_methods(o.ret_type, get_fields_and_methods(o.ret_type))
		
		local try, out, example
		o.mysize = (o.get and (o.get:get_num_params() == 1)) and (((o.count and o.count:call(obj)) or (o_tbl.counts and o_tbl.counts.method and o_tbl.counts.method:call(obj))) or 0) or nil
		o.mysize = (type(o.mysize)=="number") and o.mysize
		--[[local cnt_mthod = (o.get and (o.get:get_num_params() == 1)) and o.count or (o_tbl.counts and o_tbl.counts.method)
		o.mysize = cnt_mthod and ({pcall(cnt_mthod.call, cnt_mthod, obj)})
		o.mysize = (o.mysize and o.mysize[1] and o.mysize[2]) or (cnt_mthod and 0) or nil]]
		
		if o.mysize then --this whole thing gets so so much more complicated from counting list props as props
			o.value_org = {}
			for i=0, o.mysize-1 do
				try, out = pcall(sdk.call_object_func, obj, o.full_name, i)
				if try and (out ~=nil) then
					example = example or out
					o.is_obj = o.is_obj or (not o.is_lua_type and (not o.is_vt and sdk.is_managed_object(example))) or nil
					table.insert(o.value_org, o.is_obj and out:add_ref() or out)
				end
			end
		elseif o.field then 
			try, out = pcall(o.field.get_data, o.field, obj)
		else
			try, out = pcall(sdk.call_object_func, obj, o.full_name)
		end
		
		example = example or (try and out)
		o.value_org = o.value_org or example
		
		if example then --need one example before can start updating
			o.is_lua_type = is_lua_type(o.ret_type, example)
			o.is_vt = not not (tostring(example):find("::ValueType")) or o.is_vt or nil
			o.is_obj = (not o.is_lua_type and (not o.is_vt and sdk.is_managed_object(example))) or nil
			o.array_count = o.is_obj and example:call("get_Count")
			o.item_type = o.array_count and evaluate_array_typedef_name(example:get_type_definition())
			if o.is_obj then example:add_ref() end
		end
		o.is_vt = (o.is_vt and o.ret_type:get_method("Parse(System.String)") and "parse") or o.is_vt
		
		if (type(o.value_org)=="table") and o_tbl.counts and o_tbl.counts.method and o_tbl.xform and o_tbl.counts.method:get_name():find("Joint") then
			skeleton = o_tbl.xform.skeleton or lua_get_system_array(o_tbl.xform:call("get_Joints") or {}, nil, true)
			if skeleton and skeleton[1].call then  for i=1, #skeleton do skeleton[i] = skeleton[i]:call("get_Name") end end --set up a list of bone names for arrays relating to bones
			if skeleton and #skeleton == #o.value_org then -- (math.floor(#skeleton / 2) <= #o.value_org) then --((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj))
				if (#skeleton < ((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj))) then
					for i=1, (((o.count and o.count:call(obj)) or o_tbl.counts.method:call(obj)) - #skeleton) do 
						table.insert(skeleton, o.ret_type:get_full_name())
					end
				end
				o.skeleton = skeleton
			end
			o_tbl.xform.skeleton = skeleton --keep a copy on the xform, without necessarily turning it into a REMgdObj 
		end
		
		if o.field and o.name == "_entries" and o.value_org then --populate dictionaries
			o_tbl.elements = {}
			o_tbl.element_names = {}
			for i, element in ipairs(lua_get_system_array(o.value_org or {}, nil, true)) do
				if element.get_field then
					element:add_ref()
					local key, value = element:get_field("key"), element:get_field("value")
					key = (type(key)=="string" and key) or (key and (key:call("get_Name()") or key:call("ToString()")))
					if key then
						table.insert(o_tbl.elements, element:get_field("value"))
						table.insert(o_tbl.element_names, key)
					end
				end
			end
			--o_tbl.is_lua_type = o.is_lua_type
			o_tbl.mysize = o_tbl.elements and #o_tbl.elements
		end
		
		return setmetatable(o, self)
	end,
	
	update_item = function(self, o_tbl, index)
	
		local try, out
		local obj = o_tbl.obj
		local excepted = not self.field and (not not (SettingsCache.exception_methods[o_tbl.name_full] and SettingsCache.exception_methods[o_tbl.name_full][self.name]))
		
		if self.field then
			try, out = pcall(self.field.get_data, self.field, obj)
		elseif excepted and EMVSettings.show_all_fields then
			try, out = pcall(obj.call, obj, self.full_name, index or 0)
		elseif index then
			try, out = pcall(obj.call, obj, self.full_name, index)
		else
			try, out = pcall(obj.call, obj, self.full_name)
		end
		
		if try then 
			if out ~= nil then
				if self.is_obj or self.is_vt then
					if self.is_obj then 
						out:add_ref()
						self.array_count = (self.array_count and out:call("get_Count")) or self.array_count
					end
					local old_value = obj[self.name] or (index and self.cvalue and self.cvalue[#self.value+1]) or (not index and self.cvalue)
					if (old_value ~= nil) and (old_value ~= out) then
						metadata[old_value] = nil --clear old metadata for values being replaced
					end
				end
				if index then
					table.insert(self.value, out)
				else
					self.value = out
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
		--log.info(self.name)
		local obj = o_tbl.obj
		local is_obj = self.is_obj or self.is_vt
		if not is_obj or (forced_update or self.update) then 
			if self:update_item(o_tbl) then
				obj[self.name] = self.value
				if (self.value ~= nil) and not self.is_lua_type and is_obj then
					obj:__set_owner(self.value)
				end
				self.value = nil
			end
			self.update = nil
		end
	end,
	
	update_prop = function(self, o_tbl, idx, forced_update)
		local obj = o_tbl.obj
		local is_obj = self.is_obj or self.is_vt
		if is_obj and self.cvalue and not o_tbl.is_folder and random(25) then --set owner
			if self.element_names then
				for i, cv in ipairs(self.cvalue) do 
					obj:__set_owner(cv)
				end
			else
				obj:__set_owner(self.cvalue)
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
				if should_update_cvalue and (self.mysize < 25) or random(3) then
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
					--self.updated_this_frame = should_update_cvalue
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
						o_tbl.element_names = self.element_names
						o_tbl.is_lua_type = self.is_lua_type
					end
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
	
	__new = function(self, obj, o)
		
		if not obj or type(obj) == "number" or not can_index(obj) or not obj.get_type_definition then
			log.info("REMgdObj Failed step 1")
			return 
		end
		
		o = o or metadata[obj] or {}
		self.__index = self
		
		local try, otype = pcall(obj.get_type_definition, obj)
		local is_vt = (try and otype and otype:is_value_type()) or tostring(obj):find("::ValueType") or nil
		
		if not try or not otype or (not is_vt and not is_valid_obj(obj)) then 
			log.info("REMgdObj Failed step 2")
			return 
		end
		
		local o_tbl = {
			is_vt = (is_vt and otype:get_method("Parse(System.String)") and "parse") or is_vt,
			obj = obj,
			type = otype,
			name = otype:get_name() or "",
			name_full = otype:get_full_name() or "",
		}
		log.info("REMgdObj Creating " .. o_tbl.name_full)
		
		o_tbl.components = (otype:is_a("via.GameObject") and lua_get_system_array(obj:call("get_Components"), true)) or nil
		if otype:is_a("via.Component") or o_tbl.components then 
			o_tbl.is_component = (otype:is_a("via.Transform") and 2) or (not o_tbl.components) or nil
			o_tbl.gameobj = (o_tbl.is_component and ({pcall(obj.call, obj, "get_GameObject")}))
			o_tbl.gameobj = o_tbl.gameobj and (o_tbl.gameobj[1] and o_tbl.gameobj[2]) or (not o_tbl.is_component and obj) or nil
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
		end
		
		local propdata = metadata_methods[o_tbl.name_full] or get_fields_and_methods(otype)
		o_tbl.methods = propdata.methods
		o_tbl.fields = next(propdata.fields) and propdata.fields
		
		if o_tbl.fields then
			o_tbl.field_data = {}
			for name, field in pairs(o_tbl.fields) do
				o_tbl.field_data[name] = VarData:new{
					name=name,
					o_tbl = o_tbl,
					field=field, 
					ret_type=field:get_type(),
				}
			end
		end
		
		for name, field in pairs(propdata.fields) do
			o[name:match("%<(.+)%>") or name] = field:get_data(obj)
		end
		
		for name, method in pairs(propdata.functions) do
			o[name] = method
		end
		
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
			local skeleton
			for i, method_name in ipairs(propdata.method_names) do
				if (method_name:find("[Gg]et") == 1 ) and not method_name:find("__") then --(method_name:find("[Gg]et") == 1 or method_name:find("[Hh]as") == 1)
					if SettingsCache.show_all_fields or not (propdata.clean_field_names[method_name:sub(4, -1):gsub("_", ""):lower()] or propdata.clean_field_names[method_name:sub(4, -1):lower()]) then --is accessed already by a field
						local full_name = propdata.method_full_names[method_name]
						local full_name_method = o_tbl.type:get_method(full_name)
						method_name = method_name:sub(4, -1) 
						if full_name_method and propdata.getters[method_name] and (not SettingsCache.exception_methods[o_tbl.name_full] or not SettingsCache.exception_methods[o_tbl.name_full][method_name]) then
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
							if o[method_name] and not bad_obj then
								--re.msg_safe("Prop " .. prop.name .. " name conflict in console object 'bad_obj'!", 1241545)
								bad_obj = obj
							else
								o[method_name] = o[method_name] or prop
							end
						end
					end
				end
			end
		end
		
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
			local propdata = o_tbl.propdata
			local obj = o_tbl.obj
			forced_update = forced_update or o_tbl.keep_updating
			
			--Update owner
			if o_tbl.xform then 
				o_tbl.go = touched_gameobjects[o_tbl.xform] or held_transforms[o_tbl.xform]
			elseif o_tbl.owner and o_tbl.owner._ then 
				o_tbl.xform = o_tbl.owner._.xform
				o_tbl.gameobj = o_tbl.gameobj or o_tbl.owner._.gameobj
				o_tbl.gameobj_name = o_tbl.gameobj_name or o_tbl.owner._.gameobj_name
				if not o_tbl.folder then 
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
					local fname = (field_name:match("%<(.+)%>") or field_name)
					fdata:update_field(o_tbl, forced_update)
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
					prop:update_prop(o_tbl, i, forced_update)
				end
			end
			
			--Fix element names (these may randomly crash the game if collected on-frame, so sometimes it is delayed)
			if o_tbl.elements and (o_tbl.elements[1] ~= nil) and (not o_tbl.element_names or not o_tbl.element_names[1]) and (not o_tbl.delayed_names or (uptime-o_tbl.delayed_names > 0.66)) then
				o_tbl.element_names = {}
				o_tbl.delayed_names = nil
				for i, element in ipairs(o_tbl.elements) do 
					table.insert(o_tbl.element_names, get_mgd_obj_name(element, o_tbl, i))
				end
			end
			
			--Specialty
			if o_tbl.name == "Chain" then
				if forced_update or not o_tbl.cgroups  then 
					o_tbl.cgroups = {}
					for i = 0, obj:call("getGroupCount") - 1 do 
						table.insert(o_tbl.cgroups, ChainGroup:new { group=obj:call("getGroup", i), xform=o_tbl.xform } )
					end
				end
				if o_tbl.show_all_joints and o_tbl.cgroups and o_tbl.cgroups[1] then 
					for i, group in ipairs(o_tbl.cgroups) do
						group:update()
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
add_to_REMgdObj = function(obj)
	log.info("Adding " .. tostring(obj) .. " to REMgdObj")
	local mt = getmetatable(obj)
	local typename = mt.__type.name
	if typename:find(":") then typename = typename:sub(typename:find(":[^:]*$")+1, -1) end
	mt.__index = function(self, key)
		return ((key ~= "type" or typename ~= "ValueType") and _G[typename][key]) or REManagedObject[key] or (metadata[self] and metadata[self][key]) 
	end
	mt.__newindex = function(self, key, value)
		if _G[typename][key] then 
			_G[typename][key] = value
		elseif REManagedObject[key] then 
			REManagedObject[key] = value
		elseif key == "REMgdObj" then --using "REMgdObj" as the key will call the constructor
			metadata[self] = REMgdObj:__new(self) or {}
			metadata[self][key] = value
		elseif key == "REMgdObj_minimal" then
			metadata[self] = REMgdObj:__new_minimal(self) or {}
			metadata[self][key] = value
		else
			metadata[self] = metadata[self] or {}
			metadata[self][key] = value
		end
	end
end

--Function to make an REMgdObj object
create_REMgdObj = function(managed_object, keep_alive, do_minimal)
	--[[if REMgdObj_objects then
		for name, object in pairs(REMgdObj_objects) do
			if not pcall(function()
			if object.__type then
				REMgdObj.__types[object.__type.name] = true
			end
			add_to_REMgdObj(object)
			end) then testes = object end
		end
		REMgdObj_objects = nil
		if not mathex then 
			_G.mathex = sdk.create_instance(sdk.game_namespace("MathEx")) or sdk.create_instance("app.MathEx")
			mathex = mathex and mathex:add_ref()
			if mathex then create_REMgdObj(mathex, true) end
		end
	end]]
	--if type(managed_object.call)=="function" then
		if not REMgdObj.__types[managed_object.__type.name] then
			REMgdObj.__types[managed_object.__type.name] = true
			add_to_REMgdObj(managed_object)
		end
		managed_object.REMgdObj = nil
		if managed_object.__update then
			managed_object:__update(123)
			managed_object._.keep_alive = keep_alive
			return managed_object._
		end
	--end
end

--Functions to display managed objects in imgui --------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--Offers to create a new REManagedObject and add it as a field to an exististing REManagedObject:
local function check_create_new_value(value, prop, o_tbl, name, typedef, create_button_text, set_button_text)
	typedef = typedef or prop.item_type or prop.ret_type or o_tbl.type
	local do_set = false
	--if prop.field or prop.set or o_tbl.can_set then
		if not (typedef:is_a("via.Component") or typedef:is_a("via.GameObject") or typedef:is_a("via.GameObjectRef") or typedef:is_a("System.MulticastDelegate") or typedef:get_name():find("Holder$")) then
			if prop.new_value == nil then
				local td_name = typedef:get_full_name()
				local is_array = td_name:find("%[")
				local typedef = is_array and sdk.find_type_definition(td_name:sub(1, is_array-1)) or typedef
				if imgui.button(create_button_text) then 
					local new_value
					if typedef:is_value_type() then
						new_value = ValueType.new(typedef:get_runtime_type())
					else
						pcall(function() 
							new_value = sdk.create_instance(td_name)
							new_value = (sdk.is_managed_object(new_value) and new_value) or sdk.create_instance(td_name, true)
						end)
						new_value = sdk.is_managed_object(new_value) and new_value:add_ref() or nil
					end
					if new_value then 
						prop.new_value = new_value
						--test = {o_tbl, prop, prop.new_value}
					else
						re.msg("Failed to create " .. td_name .. "\nResult: " .. tostring(new_value))
					end
				end
				imgui.same_line()
				imgui.text("  (" .. (td_name or "") .. ")  " .. name)
			elseif prop.new_value and imgui.button(set_button_text) then
				do_set = true
			elseif prop.new_value and not imgui.same_line() and imgui.button("[Cancel]") then
				prop.new_value, value = nil
			end
		end
	--end
	return do_set, ((value ~= nil and value) or prop.new_value)
end

--If the gravity gun is running, offers to grab the game object with with an imgui button:
local function offer_grab(anim_object, grab_text, ungrab_text)
	if _G.grab then
		grab_text = grab_text or "Grab"
		ungrab_text = ungrab_text or "Ungrab"
		local is_grabbed = (last_grabbed_object and last_grabbed_object.active and last_grabbed_object.xform == anim_object.xform)
		if not anim_object.same_joints_constraint and imgui.button(is_grabbed and ungrab_text or grab_text) then 
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
local function show_imgui_resource(value, name, key_name, data_holder)
	local changed, was_changed
	
	if not data_holder.index then --or data_holder.ext == " " then
		imgui.text(logv(data_holder.ret_type))
		data_holder.index, data_holder.path, data_holder.ext = add_resource_to_cache(value, nil, data_holder)
	end
	
	imgui.push_id(key_name .. name .. "Rs")
		changed, data_holder.show_manual = imgui.checkbox("", data_holder.show_manual)
		if changed and data_holder.show_manual then 
			data_holder.cached_text = (RN[data_holder.ext .. "_resource_names"] and RN[data_holder.ext .. "_resource_names"][data_holder.index]) or ""
		end
		imgui.same_line()
		was_changed, data_holder.index = imgui.combo(name, data_holder.index, RN[data_holder.ext .. "_resource_names"] or {})
		if was_changed and ext ~= " " then 
			data_holder.path = RN[data_holder.ext .. "_resource_names"][data_holder.index]
			data_holder.cached_text = data_holder.show_manual and data_holder.path
			value = RSCache[data_holder.ext .. "_resources"][data_holder.path] or "__nil" --or create_resource("not_set." .. data_holder.ext, data_holder.ret_type) or "__nil"
			value = value and value[1] or value
		end
		if data_holder.show_manual then
			data_holder.cached_text = data_holder.cached_text or ""
			if data_holder.cached_text == data_holder.path and data_holder.index ~= 1 then 
				if imgui.button(" X ") then 
					RSCache[data_holder.ext .. "_resources"][data_holder.path] = nil
					value = RSCache[data_holder.ext .. "_resources"][data_holder.path]
					--RN[data_holder.ext .. "_resource_names"][data_holder.index] = "[Removed] " .. data_holder.path
					table.remove(RN[data_holder.ext .. "_resource_names"], data_holder.index)
					re.msg("Removed " .. data_holder.path .. " from list of cached " .. data_holder.ext .. " resources")
					data_holder.cached_text = ""
				end
				imgui.same_line()
			elseif data_holder.cached_text ~= "" and data_holder.cached_text ~= data_holder.path and data_holder.cached_text:find("%." .. data_holder.ext) then
				if imgui.button("OK") then
					local new_resource = create_resource(data_holder.cached_text, value:get_type_definition())
					if new_resource then
						data_holder.index, data_holder.path = add_resource_to_cache(new_resource)
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
					--[[if o_tbl.is_vt == "set" then --not return_type:is_a("System.String") 
						value = create_resource(value, return_type, true)
					else]]
					if is_field then 
						--value = sdk.create_managed_string(value):add_ref() --not sure
					end
					o_tbl.cached_text[tkey] = nil
					changed = true
				end
				imgui.same_line()
				if imgui.button("Cancel") then
					o_tbl.cached_text[tkey] = str_name
					collectgarbage()
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
	if value:length() > 5 or (world_positions[obj] and world_positions[obj][key_name .. name]) then
		obj._.world_positions = obj._.world_positions or world_positions[obj] or {}
		local wpos_tbl, changed = obj._.world_positions[key_name .. name]
		if not wpos_tbl then
			wpos_tbl = {}
			wpos_tbl.method = field_or_method.call and field_or_method
			wpos_tbl.field = field_or_method.get_data and field_or_method
			wpos_tbl.name = ((obj._.Name or obj._.name) .. "\n") .. name --(obj._.gameobj_name and (obj._.gameobj_name .. " ") or "") .. ((obj._.Name or obj._.name) .. "\n") .. name
			obj._.world_positions[key_name .. name] = wpos_tbl
		end
		imgui.same_line()
		imgui.push_id(key_name .. name .. "Id")
			changed, wpos_tbl.active = imgui.checkbox("Display", wpos_tbl.active) 
			if wpos_tbl.active then 
				--imgui.same_line()
				--changed, wpos_tbl.as_local = imgui.checkbox("Local", wpos_tbl.as_local) 
				wpos_tbl.color = changed and (math.random(0x1,0x00FFFFFF) - 1 + 4278190080) or wpos_tbl.color
				world_positions[obj] = obj._.world_positions
			end
		imgui.pop_id()
	end
end

--Displays a vector2, 3 or 4 with editable fields in imgui:
local function show_imgui_vec4(value, name, is_int)
	if not value then return end
	local changed = false
	if type(value) ~= "number" then
		if value.w then 
			if name:find("olor") then
				changed, value = imgui.color_edit4(name, value, 17301504)
			else
				changed, value = imgui.drag_float4(name, value, 0.1, -10000.0, 10000.0)
				if changed and (name:find("Rot") or (value - value:normalized()):length() < 0.001)  then -- and tostring(value):find("qua")
					value:normalize() 
				end
			end
		elseif value.z then
			if is_int then
				changed, value = imgui.drag_float3(name, value, 1.0, -16777216, 16777216)
			elseif name:find("olor") then
				changed, value = imgui.color_edit3(name, value, 17301504)
			else
				changed, value = imgui.drag_float3(name, value, 0.1, -10000.0, 10000.0)
			end
		elseif value.y then
			if is_int then  --17301504
				changed, value = imgui.drag_float2(name, value, 1.0, -16777216, 16777216)
			else
				changed, value = imgui.drag_float2(name, value, 0.1, -10000.0, 10000.0)
			end
		end
	else
		changed, value = imgui.drag_float(name, value, 0.1, -10000.0, 10000.0)
	end
	return changed, value
end

--Displays settings for via.Chain objects in imgui:
local function imgui_chain_settings(via_chain, xform, game_object_name)
	
	local chain_groups = via_chain._.cgroups or {}
	local chain_settings = cached_chain_settings[via_chain] or {}
	cached_chain_settings_names[via_chain] = cached_chain_settings_names[via_chain] or {}
	
	if #chain_groups > 0 and imgui.tree_node_str_id(game_object_name .. "Groups", "Chain Groups (" .. #chain_groups ..  ")") then 
		
		changed, via_chain._.show_all_joints = imgui.checkbox("Show All Joints", via_chain._.show_all_joints)
		
		for i, group in ipairs(chain_groups) do 
			
			if imgui.tree_node_str_id(game_object_name .. "Groups" .. i-1, i-1 .. ". Group " .. group.terminal_name) then 
				
				if not via_chain._.show_all_joints then
					group:update()
				end
				
				if not group.settings_id then --initial setup (requiring all other chain groups)
					local ref_tbl, ctr = {}, 0
					for j, other_group in ipairs(chain_groups) do 
						if not ref_tbl[other_group.settings_ref] then 
							ctr = ctr + 1
							ref_tbl[other_group.settings_ref] = ctr
							cached_chain_settings_names[via_chain][ctr] = "Settings " .. tostring(ctr)
						end
					end
					group.settings_id = ref_tbl[group.settings_ref]
					group.blend_id = group.settings_id
					group:change_custom_setting()
				end
				
				if isRE2 or isRE8 then 
					changed, group.settings_id = imgui.combo("Set CustomSettings", group.settings_id, cached_chain_settings_names[via_chain])
					if imgui.button("Reset CustomSettings") or changed then 
						group:change_custom_setting()
					end
					imgui.same_line()
				end
				
				changed, group.show_positions = imgui.checkbox("Show Positions", group.show_positions) 
				
				if isRE2 or isRE8 then 
					imgui.same_line()
					changed, group.do_blend = imgui.checkbox("Blend", group.do_blend)
					if group.do_blend then 
						imgui.text("Note: Only blends original settings to original settings")
						changed, group.blend_ratio = imgui.drag_float("Blend Ratio", group.blend_ratio, 0.01, -1, 1)
						changed, group.blend_id = imgui.combo("Blend-To", group.blend_id, cached_chain_settings_names[via_chain])
						if changed then 
							group:change_custom_setting()
						end
					end
				end
				
				imgui.managed_object_control_panel(group.group, game_object_name .. "CGrp" .. i, group.terminal_name) 
				group.group._.is_open = true
				imgui.tree_pop()
			elseif group.group._ then
				group.group._.is_open = nil
			end
		end
		imgui.tree_pop()
	end
end

--Displays a single field or property in imgui:
local function read_field(parent_managed_object, field, prop, name, return_type, key_name, element, element_idx)
	
	local value, is_obj, skip, changed, was_changed
	local display_name = name
	local o_tbl = parent_managed_object._
	local found_array = return_type:get_full_name():find("<") or o_tbl.mysize or o_tbl.element_names
	
	if element ~= nil then 
		value = element
	elseif field then 
		--value = parent_managed_object[name:match("%<(.+)%>") or field:get_name()]
		--if value == nil then 
			value = field:get_data(parent_managed_object)
		--end
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
	local var_metadata = prop or o_tbl --(field and o_tbl.field_data and o_tbl.field_data[name]) --this is a clusterfuck, with tables being passed as parent_managed_object
	if var_metadata.can_index == nil then
		var_metadata.can_index = can_index(value)
	end
	
	if return_type:is_a("System.Enum") then
		local enum, value_to_list_order, enum_names = get_enum(return_type)
		if value_to_list_order then 
			changed, value = imgui.combo(display_name, value_to_list_order[value], enum_names) 
			if changed then 
				value = enum[ enum_names[value]:sub(1, enum_names[value]:find("%(")-1) ]
			end
		else
			changed, value = imgui.drag_int(display_name .. " (Enum)", value, 1, 0, 4294967294)
		end
	elseif values_type == "number" or values_type == "boolean" or return_type:is_primitive() then
		if return_type:is_a("System.Single") then
			changed, value = imgui.drag_float(display_name, value, 0.1, -100000.0, 100000.0)
		elseif return_type:is_a("System.Boolean") then
			changed, value = imgui.checkbox(display_name, value)
		elseif return_type:is_a("System.UInt32") or return_type:is_a("System.UInt64") or return_type:is_a("System.UInt16") then
			changed, value = imgui.drag_int(display_name, value, 1, 0, 4294967294)
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
	elseif return_type:is_a("via.Position") then
		
		local new_value = Vector3f.new(value:get_field("x"):read_double(0x0), value:get_field("y"):read_double(0x0), value:get_field("z"):read_double(0x0))
		changed, new_value = show_imgui_vec4(new_value, display_name)
		--offer_show_world_pos(new_value, display_name, key_name, parent_managed_object, (field or prop.get) )
		if changed then value:write_double(0, new_value.x) ; value:write_double(0x8, new_value.y) ; value:write_double(0x10, new_value.z) end
		
	elseif var_metadata.is_lua_type == "mat" then
		if imgui.tree_node_str_id(key_name .. name, display_name) then 
			local new_value = Matrix4x4f.new()
			for i=0, 3 do 
				changed, new_value[i] = show_imgui_vec4(value[i], "Row[" .. i .. "]")
				was_changed = changed or was_changed
				if i == 3 then 
					offer_show_world_pos(new_value[i], (o_tbl and (o_tbl.Name or o_tbl.name) or "") .. " " .. display_name, key_name, parent_managed_object, (field or prop.get) ) 
				end
			end
			if was_changed then value = new_value end
			imgui.tree_pop()
		end
	elseif ((var_metadata.is_lua_type == "qua") or (var_metadata.is_lua_type == "vec")) then
		changed, value = show_imgui_vec4(value, display_name)
		if value and (return_type:is_a("via.vec3") or return_type:is_a("via.vec4") or return_type:is_a("via.Quaternion")) then
			offer_show_world_pos(value, display_name, key_name, parent_managed_object, (field or prop.get) )
		end
	elseif not found_array and return_type:get_full_name():find("ResourceHolder")  then 
		is_obj = true
		changed, value = show_imgui_resource(value, name, key_name, prop or (field and o_tbl.field_data and o_tbl.field_data[name]))
		
	elseif (return_type:is_a("System.String")) then
		is_obj = true
		was_changed, value = show_imgui_text_box(display_name, value, o_tbl, (field or prop.set), nil, field )
		was_changed = not found_array and was_changed
	elseif value and (var_metadata.is_obj or var_metadata.is_vt) or (can_index(value) and (value._ or tostring_value:find("::ValueType") or ({pcall(sdk.is_managed_object, value)})[2] == true)) then --managed objects and valuetypes
		is_obj = true
		--[[if imgui.tree_node_str_id(key_name .. name .. "M", display_name .. (var_metadata.mysize and (" (" .. var_metadata.mysize .. ")") or "")) then
			read_imgui_element(var_metadata)
			imgui.tree_pop()
		end]]
		
		local field_pd, Name
		local count = var_metadata.array_count or (not o_tbl.propdata and var_metadata.mysize)
		local do_update = o_tbl.clear --or random(16)
		if not count and not element_idx then
			local return_type = value:get_type_definition()
			--var_metadata.element_Names = element_idx and (var_metadata.element_Names or {})
			field_pd = metadata_methods[return_type:get_full_name()] or get_fields_and_methods(return_type)
			--Name = (element_idx and var_metadata.element_Names[element_idx]) or (not element_idx and var_metadata.Name) or
			Name = not element_idx and ((not do_update and var_metadata.Name) or get_mgd_obj_name(value, {
					ret_type=return_type, 
					name_methods=field_pd.name_methods or get_name_methods(return_type),
					fields=field_pd.fields,
				}, nil, false) or "") or ""
			--if element_idx then
			--	var_metadata.element_Names[element_idx] = var_metadata.element_Names[element_idx] or Name
			--else
				var_metadata.Name = (not do_update and var_metadata.Name) or (not display_name:lower():find(Name:lower()) and Name) or ""
			--end
			if Name ~= "" then
				display_name = display_name .. "	\"" .. Name .. "\""
			end
		end
		
		if imgui.tree_node_str_id(key_name .. name, display_name .. (count and (" (" .. count .. ")") or "")) then
			changed, value = imgui.managed_object_control_panel(value, key_name .. (value:get_type_definition():get_name() or name), name, not (prop.get and not prop.set)) --game_object_name .. " -> " .. name
			if value and value._ then
				value._.Name = value._.Name or display_name
				value._.is_open = true
				value._.owner = parent_managed_object
				value._.can_set = not (prop.get and not prop.set)
				--[[if value._.is_vt then
					o_tbl.clear_next_frame = o_tbl.clear_next_frame or value._.clear_next_frame
					o_tbl.clear = o_tbl.clear or value._.clear
				end]]
			end
			imgui.tree_pop()
		elseif var_metadata.is_vt then
			if value._ then value._.is_open = nil end
		elseif is_valid_obj(value) then
			if value._ then value._.is_open = nil end
		elseif prop then
			local idx = find_index(o_tbl.props, prop)
			if idx then table.remove(o_tbl.props, idx) end --its broken
		end
	elseif value ~= nil and not prop.new_value then
		imgui.text(tostring(value) .. " " .. display_name)
		--imgui.text(tostring(value) .. " " .. display_name .. ", " .. tostring(value.can_index) .. ", " .. tostring(var_metadata.is_obj) .. ", " .. tostring(var_metadata.is_lua_type))
	end
	
	changed = ((field or prop.set) and (changed or was_changed))
	
	--Freeze a field, setting it to the frozen setting every frame: ------------------------
	local freeze, freeze_changed = var_metadata.freeze
	if freeze == nil and var_metadata.freezetable then 
		freeze = var_metadata.freezetable[element_idx]
	end
	
	if not is_obj and (freeze ~= nil) and (field or prop.set) and (var_metadata.value_org ~= nil) then --freezing / resetting values 
		imgui.push_id(var_metadata.name or field:get_name() .. "F")
			if (freeze == false) and var_metadata.timer_start and ((uptime - var_metadata.timer_start) > 5.0) then 
				var_metadata.freeze = nil
				if var_metadata.freezetable then 
					var_metadata.freezetable[element_idx] = nil 
				end
				var_metadata.timer_start = nil
			end
			imgui.same_line()
			if imgui.button(freeze and "Unfreeze" or "Freeze") then 
				if element_idx then 
					var_metadata.freezetable[element_idx] = not var_metadata.freezetable[element_idx]
				else
					var_metadata.freeze = not freeze
				end
				changed = true
				goto exit
			end
			if freeze or (var_metadata.timer_start and (uptime - var_metadata.timer_start) > 0.1) then
				--if var_metadata.value_org ~= var_metadata.value and (not var_metadata.ret_type:is_a("System.Boolean") or not imgui.same_line()) and imgui.button("X") then
				imgui.same_line()
				if imgui.button("X") then --value_org ~=
					if element_idx then 
						value = var_metadata.value_org[element_idx]
						var_metadata.freezetable[element_idx] = nil
					else
						value = var_metadata.value_org
						var_metadata.value = value
						var_metadata.freeze = nil
					end
					changed = true
					goto exit
				end
				if freeze then 
					if element_idx then 
						var_metadata.freezetable[element_idx] = (changed or was_changed) and 1 or true
					else
						var_metadata.freeze = (changed or was_changed) and 1 or true  --bypass (1) for modifying an already-frozen field
					end
				end
				--var_metadata.timer_start = nil
			end
		::exit::
		imgui.pop_id()
	elseif changed or was_changed then 
		o_tbl.was_changed = true
		var_metadata.was_changed = true
		if element_idx then 
			var_metadata.freezetable = var_metadata.freezetable or {}
			var_metadata.freezetable[element_idx] = freeze or false 
		else
			var_metadata.freeze = freeze or false 
		end
		var_metadata.timer_start = (changed and (freeze == nil) and uptime) or var_metadata.timer_start --set the timer when its changed (otherwise it flickers) --
	end
	
	
	if changed then
		--imgui.same_line()
		--imgui.text("!")
		o_tbl.clear_next_frame = true
	end
	
	--if changed  then--((changed and prop.set) or var_metadata.is_lua_type or (not is_obj and values_type ~= "table")) then
		 --refresh value for non-objects and non-tables every frame, or if they were changed
		--parent_managed_object._.clear = true
	--end
	
	if prop and prop.updated_this_frame then 
		imgui.same_line()
		imgui.text(" UPDATING ") 
		prop.updated_this_frame = nil 
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
		
		for i, element in ipairs(tbl) do 
			
			local element_name = arr_tbl.element_names[i]
			--[[if not element_name:find(element:get_type_definition():get_full_name()) then
				element_name = element:get_type_definition():get_name() .. "	\"" .. element_name .. "\""
				arr_tbl.element_names[i] = element_name
			end]]
			local disp_name = i .. ". " .. (element_name or tostring(element)) .. (arr_tbl.set and "" or "*") 
			
			if (arr_tbl.is_obj or arr_tbl.is_vt) and not is_lua_type(item_type) then --special thing for reading elements that are objects (read_field could also work though)
				imgui.text("")
				imgui.same_line()
				if imgui.tree_node_str_id(key_name .. element_name .. i, disp_name ) then
					tbl_changed, element = imgui.managed_object_control_panel(element, key_name .. element_name .. i, element_name)
					if element._ then
						element._.Name = element._.Name or disp_name
						arr_tbl.element_names[i] = element._.Name
						element._.is_open = true
					end
					imgui.tree_pop()
				elseif element._ then
					element._.is_open = nil
				end
			else
				tbl_changed, element = read_field(parent_managed_object, nil, prop, disp_name, item_type, key_name, element, i)
			end
			
			if tbl_changed then 
				tbl_was_changed = true
				if o_tbl.type:is_a("System.Array") then 
					--local td_name = array_info_holder.ret_type:get_full_name() --(type(element) == "string" and sdk.create_managed_string(element))
					--deferred_calls[parent_managed_object] = { func="SetValue(System.Object, System.Int32)", args={ (typedef_to_function[td_name] and typedef_to_function[td_name](element)) or element, i-1 } }
				elseif (prop and prop.set) then
					deferred_calls[parent_managed_object] = { func=prop.set:get_name(), args={ i-1, element }, vardata=prop }
				end
			end
		end
		
		--if prop.can_set or o_tbl.can_set then
		local array_way = o_tbl.owner and o_tbl.type:is_a("System.Array") and o_tbl.can_set and o_tbl.owner._.fields and o_tbl.owner._.fields[o_tbl.Name]
		local mItems_way = not mItems_way and (arr_tbl.fields and arr_tbl.fields["mItems"])
		local prop_way = not array_way and not mItems_way and prop and prop.set and (o_tbl.methods[prop.set:get_name() .. "Count"] or o_tbl.methods[prop.set:get_name() .. "Num"])
		
		if array_way or mItems_way or prop_way then -- or (arr_tbl.methods and or arr_tbl.methods["SetValue"] or arr_tbl.methods["set_Item"]) then
			
			item_type = ((item_type:get_name() == "Object") and evaluate_array_typedef_name(o_tbl.type)) or item_type
			local item_typename = item_type:get_name()
			local elements = arr_tbl.elements or arr_tbl.cvalue
			local arr_type = (prop_way and prop.ret_type) or (array_way and evaluate_array_typedef_name(o_tbl.type) or o_tbl.type) or (mItems_way and o_tbl.fields["mItems"]:get_type())
			if arr_tbl.new_value ~= nil then
				local disp_name = #elements+1 .. ". " .. (((arr_tbl.new_value._ and arr_tbl.new_value._.Name) or item_type:get_full_name()) or tostring(arr_tbl.new_value)) .. (arr_tbl.set and "" or "*") 
				if ((arr_tbl.is_obj or prop.is_obj) or (arr_tbl.is_vt or prop.is_vt)) then 
					if imgui.tree_node_str_id(key_name .. arr_tbl.name .. "New", disp_name .. " [NEW]") then 
						imgui.managed_object_control_panel(arr_tbl.new_value, key_name .. arr_tbl.name .. "New", item_typename)
						imgui.tree_pop()
					end
				else
					tbl_changed, arr_tbl.new_value = read_field(parent_managed_object, nil, prop, disp_name .. " [NEW]", item_type, key_name, element,  #elements+1)
				end
			end
			local new_set
			new_set, arr_tbl.new_value = check_create_new_value(arr_tbl.new_value, arr_tbl, o_tbl, arr_tbl.name, item_type, "[Create " .. item_typename .. "]", "[Add New " .. item_typename .. "]")
			if (arr_tbl.new_value ~= nil) and new_set then 
				table.insert(elements, arr_tbl.new_value)
				table.insert(arr_tbl.element_names, get_mgd_obj_name(arr_tbl.new_value, arr_tbl))
				--arr_tbl.mysize = #elements
				
				--test = (prop_way and arr_tbl.new_value) or value_to_obj(elements, arr_type)
				if prop_way and test then
					deferred_calls[parent_managed_object] = { { func=prop_way:get_name(), args=#elements, }, { func=prop.set:get_name(), args={test, #elements}, } }
				elseif array_way then
					deferred_calls[o_tbl.owner] = { field=o_tbl.owner.fields[o_tbl.Name]:get_name(), args=test, }
				elseif mItems_way then
					deferred_calls[parent_managed_object] = { field="mItems", args=test, }
				end
				arr_tbl.new_value = nil
				o_tbl.invalid = true
				--managed_object._.clear = true
				arr_tbl.update = true
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
	
	--[[local name = field:get_name()
	local type = field:get_type()
	local value = field:get_data(managed_object)
	local new_set, new_value = check_create_new_value(value, key_name, name, type, "[Create " .. name .. "]", "[Set New " .. name .. "]") 
	
	if nil_field_values[key_name .. name] then
		managed_object[name] = (value == nil) and new_value or value
	elseif managed_object[name] ~= nil and value == nil then
		managed_object[name] = nil
	end
	
	if new_set == true then 
		managed_object:set_field(field:get_name(), value)
		nil_field_values[key_name .. name] = nil
		managed_object._.clear = true
	end]]
	
	--[[if type(prop.cvalue) == "table" then
		--imgui_check_value(managed_object._)
		changed, value = show_managed_objects_table(managed_object, prop.cvalue, prop, key_name)
	else
		changed, value = read_field(managed_object, nil, prop, prop.name, prop.ret_type, key_name)
		if changed then 
			--prop.cvalue = nil
			--prop.update = true
			deferred_calls[managed_object] = prop.set and { func=prop.set:get_name(), args=value, prop=prop, }
		end
	end]]
	local field_data = managed_object._.field_data[field:get_name()]
	changed, value = read_field(managed_object, field, field_data, field_data.name, field_data.ret_type, key_name) 
	if changed then
		deferred_calls[managed_object] = { field=field:get_name(), args=value, prop=managed_object._.field_data[field:get_name()] } --test=value_to_obj(value, field:get_type())
	end
	return changed
end

--Wrapper for read_field(), displays one REMgdObj property in imgui:
local function show_prop(managed_object, prop, key_name)
	
	--[[if prop.set and prop.value == nil then
		local new_set, new_value
		new_set, new_value = check_create_new_value(prop.value, key_name, prop.name, prop.ret_type, "[Create " .. prop.name .. "]", "[Set New " .. prop.name .. "]") 
		if nil_field_values[key_name .. prop.name] then
			prop.cvalue = (prop.cvalue == nil) and new_value or prop.cvalue
		elseif prop.cvalue ~= nil and prop.value == nil then
			prop.cvalue = nil
		end
		if new_set == true then 
			deferred_calls[managed_object] = { func=prop.set:get_name(), args=prop.value, } --test=value_to_obj(prop.cvalue, prop.ret_type)
			nil_field_values[key_name .. prop.name] = nil
			managed_object._.clear = true
		end
	end]]
	
	if type(prop.cvalue) == "table" then
		--imgui_check_value(managed_object._)
		changed, value = show_managed_objects_table(managed_object, prop.cvalue, prop, key_name)
	else
		changed, value = read_field(managed_object, nil, prop, prop.name, prop.ret_type, key_name)
		if changed then 
			--prop.cvalue = nil
			--prop.update = true
			deferred_calls[managed_object] = prop.set and { func=prop.set:get_name(), args=value, vardata=prop, }
		end
	end
	
	return changed
end

local function show_save_load_button(o_tbl, button_type, load_by_name)
	if o_tbl.is_component or o_tbl.components then
		local components = o_tbl.components or (o_tbl.show_gameobj_buttons and o_tbl.go.components)
		local load_mode, file = (button_type == "Load")
		o_tbl.go = o_tbl.go or GameObject:new{xform=o_tbl.xform}
		if load_by_name then
			imgui.same_line()
			changed, o_tbl.show_load_input = imgui.checkbox("Load By Name", o_tbl.show_load_input)
			o_tbl.files_list = o_tbl.show_load_input and (o_tbl.files_list or {names={}, paths=fs.glob([[EMV_Engine\\Saved_GameObjects\\.*.json]])}) or nil
			if changed and o_tbl.files_list then 
				for i, filepath in ipairs(o_tbl.files_list.paths) do 
					table.insert(o_tbl.files_list.names, filepath:match("^.+\\(.+)%."))
				end
			end
			if o_tbl.files_list and (imgui.button("OK") or imgui.same_line()) then
				file = json.load_file(o_tbl.files_list.paths[o_tbl.input_file_idx])
			end
		end
		if (not load_by_name and imgui.button(button_type .. (components and " GameObject" or ""))) or (load_by_name and file) then
			local try
			if components then 
				for i=2, #components do --dont load via.Transforms or via.GameObjects with gameobjects
					local component = components[i]
					if load_by_name and file then
						try = load_json_game_object(o_tbl.go, 1, component:get_type_definition():get_name(), o_tbl.files_list.names[o_tbl.input_file_idx], file)
					elseif load_mode then
						try = load_json_game_object(o_tbl.go, 1, component:get_type_definition():get_name(), o_tbl.files_list and o_tbl.files_list.names[o_tbl.input_file_idx])
					else
						try = save_json_gameobject(o_tbl.go, nil, component:get_type_definition():get_name())
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
		if load_by_name then
			if o_tbl.show_load_input then
				changed, o_tbl.input_file_idx = imgui.combo("Select GameObject", o_tbl.input_file_idx or 1, o_tbl.files_list.names)
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
		if var_count and imgui.tree_node_str_id(uvar:get_address()+u, "User Variables: " .. (name or o_tbl.Name) .. " (" .. var_count .. ")") then
			for i=1, var_count do 
				local var = uvar:call("getVariable", i-1)
				local var_name = var:call("get_Name") .. (var:call("get_ReadOnly") and "*" or "")
				local type_kind = var:call("get_TypeKind")
				if not metadata[var] then 
					create_REMgdObj(var)
				end
				local prop = var._U64
				if type_kind == 2 then --Bool
					prop = var._Bool
				elseif type_kind == 11 then --Float
					prop = var._F32
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
	
	if not m_obj._ and (tostring(m_obj):find("::ValueType") or is_valid_obj(m_obj)) then 
		create_REMgdObj(m_obj) --create REMgdObj class	
		if type(m_obj._) ~= "table" or m_obj._.type == nil then 
			return false--, m_obj 
		end
	end
	
	if m_obj.__update and m_obj._ and m_obj._.name_full then

		local o_tbl = m_obj._
		local changed, was_changed
		local typedef = m_obj:get_type_definition()
		local is_xform = (o_tbl.xform == m_obj)
		game_object_name = o_tbl.gameobj_name or game_object_name or " "
		key_name = key_name or (o_tbl.gameobj_name and (o_tbl.gameobj_name .. o_tbl.name)) or o_tbl.name
		field_name = field_name or o_tbl.Name or o_tbl.name or key_name
		o_tbl.last_opened = uptime
		key_name = o_tbl.key_hash or key_name
		
		imgui.push_id(key_name)
		imgui.begin_rect()
			imgui.begin_rect()	
				local imgui_changed
				imgui.begin_rect()
					if imgui.button("Update") or o_tbl.clear_next_frame or o_tbl.keep_updating then 
						o_tbl.clear = true 
						o_tbl.clear_next_frame = nil
					end
					imgui.same_line()
					imgui_changed, o_tbl.keep_updating = imgui.checkbox("", o_tbl.keep_updating)
					o_tbl.keep_updating = o_tbl.keep_updating or nil
				imgui.end_rect(1)
				
				imgui.same_line()
				local complete_name = (game_object_name ~= "" and (game_object_name .. " -> ") or "")  .. o_tbl.name_full .. " " .. field_name
				--o_tbl.Name = o_tbl.Name or field_name
				
				if imgui.tree_node_str_id(key_name .. "ObjEx",  "[Object Explorer]  "  .. complete_name .. " @ " .. m_obj:get_address()) then  
				
					imgui_changed, o_tbl.sort_alphabetically = imgui.checkbox("Sort Alphabetically", o_tbl.sort_alphabetically)
					o_tbl.sort_alphabetically = o_tbl.sort_alphabetically or nil
					
					imgui.same_line()
					if imgui.button("Clear Lua Data") then
						SettingsCache.exception_methods[o_tbl.name_full] = nil
						o_tbl.invalid = true
					end
					
					if o_tbl.was_changed and not imgui.same_line() and imgui.button("Undo Changes") then
						deferred_calls[m_obj] = {}
						for name, field_data in pairs(o_tbl.field_data) do 
							if (field_data.value_org ~= nil) and field_data.was_changed and not (field_data.is_obj or field_data.elements) then
								table.insert(deferred_calls[m_obj], {field=field_data.field, args=field_data.value_org})
							end
						end
						for i, prop in ipairs(o_tbl.props) do 
							if (prop.value_org ~= nil) and field_data.was_changed and not (prop.is_obj or prop.elements) and not prop.is_count then
								table.insert(deferred_calls[m_obj], {func=prop.full_name, args=prop.value_org})
							end
						end
						o_tbl.invalid = true
					end
					
					if o_tbl.is_component or o_tbl.components then
						if o_tbl.is_component == 2 then 
							--imgui.same_line()
							changed, o_tbl.show_gameobj_buttons = imgui.checkbox("All", o_tbl.show_gameobj_buttons)
						end
						imgui.same_line()
						show_save_load_button(o_tbl, "Save")
						imgui.same_line()
						show_save_load_button(o_tbl, "Load")
						imgui.same_line()
						show_save_load_button(o_tbl, "Load", true)
					end
					
					if not o_tbl.is_vt then
						object_explorer:handle_address(m_obj)
					end
					
					--[[if not o_tbl.cant_set and not nil_field_values[key_name]  then 
						if imgui.button("Set nil") then 
							do_set = true
							m_obj = "__nil"
						end
						if not imgui.same_line() and imgui.button("Set 0") then 
							do_set = true
							m_obj = 0
						end
						if not imgui.same_line() and imgui.button("Set New") then 
							do_set = true
							local new_managed_object =  (typedef:is_value_type() and ValueType.new(typedef:get_runtime_type())) or sdk.create_instance(typedef:get_full_name()) or sdk.create_instance(typedef:get_full_name(), true)
							if new_managed_object then 
								new_managed_object:add_ref()
								new_managed_object:call(".ctor")
								m_obj = new_managed_object
							end
						end
						if tmp and is_valid_obj(tmp) and m_obj ~= tmp and tmp:get_type_definition() == typedef and not imgui.same_line() and imgui.button("Set tmp") then 
							m_obj = tmp
							do_set = true
						end
					end]]
					
					--if mini_console ~= nil then --if the console is running
					
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
						if imgui.tree_node("[Lua]") then 
							read_imgui_element(o_tbl)
							imgui.tree_pop()
						end
						read_imgui_element(metadata[m_obj])
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
					
					if mini_console then
						mini_console(m_obj, game_object_name .. key_name) 
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
			
			if is_xform then
				--huge fukn thing mostly to get/set parents:
				held_transforms[m_obj] = held_transforms[m_obj] or o_tbl.go or GameObject:new_AnimObject{xform=m_obj}
				local anim_object = o_tbl.go
				if anim_object then 
					
					imgui_changed, anim_object.display = imgui.checkbox("Enabled", anim_object.display)
					if imgui_changed then 
						anim_object.display_org = anim_object.display
						anim_object:toggle_display()
					end
					imgui.same_line()
					
					if imgui.button("Destroy " .. anim_object.name) then 
						deferred_calls[anim_object.gameobj] = { { func="destroy", args=anim_object.gameobj }, (anim_object.frame and {lua_func=_G.clear_figures}) }
					end
					
					if EMVSettings and not figure_mode and not cutscene_mode and not anim_object.same_joints_constraint 
					and anim_object.layer and not anim_object.total_objects_idx and not imgui.same_line() and imgui.button(forced_mode and "Add to Animation Viewer" or "Enable Animation Viewer") then
						if not forced_mode then
							forced_mode = GameObject:new{xform=o_tbl.xform}
							--forced_mode.init_transform = forced_mode.xform:call("get_WorldMatrix")
							forced_object = forced_mode
							--activate_forced_mode(forced_mode)
							--if grab then 
							--	grab(anim_object.xform, {init_offet=anim_object.cog_joint and anim_object.cog_joint:call("get_BaseLocalPosition")}) 
							--end
							anim_object.forced_mode_center = anim_object.xform:call("get_WorldMatrix")
						elseif insert_if_unique(total_objects, anim_object) then
							local function gather_children(object)
								for i, child in ipairs(object.children or {}) do
									local child_obj = held_transforms[child] or GameObject:new_AnimObject{xform=child}
									if child_obj and insert_if_unique(total_objects, child_obj) then 
										gather_children(child_obj)
									end
								end
							end
							gather_children(anim_object)
							anim_object.forced_mode_center = anim_object.xform:call("get_WorldMatrix")
						end
					end
					
					anim_object.parent = anim_object.xform:call("get_Parent")
					anim_object.parents_list = anim_object.parents_list or {}
					
					local htc = get_table_size(held_transforms)
					if not anim_object.index_h_count or (anim_object.index_h_count ~= htc) or (anim_object.parent and (anim_object.parent:call("get_GameObject"):call("get_Name") ~= anim_object.parents_list[anim_object.parent_index])) then 
						--if anim_object.parents_list[1] then imgui.text(anim_object.index_h_count .. " SORTING " .. #anim_object.parents_list[1]) end
						imgui.text("Sorting")
						local uniques = {}
						sorted_held_transforms, anim_object.parents_list = {}, {}
						for xform, obj in pairs(held_transforms) do 
							table.insert(sorted_held_transforms, obj) 
						end
						table.sort (sorted_held_transforms, function (obj1, obj2) return (obj1.name_w_parent or obj1.name) < (obj2.name_w_parent or obj2.name) end )
						
						for i, obj in ipairs(sorted_held_transforms) do
							obj.index_h = i
							local name_to_add = obj.name_w_parent or obj.name
							if obj == anim_object then 
								name_to_add = " "
							elseif is_child_of(obj.xform, anim_object.xform) then
								name_to_add = name_to_add .. " [CHILD]"
							end 
							local unique_name, cnt = name_to_add, 0
							while uniques[unique_name] do
								cnt = cnt + 1
								unique_name = name_to_add .. " (" .. cnt .. ")"
							end
							uniques[unique_name] = true
							table.insert(anim_object.parents_list, unique_name)
						end
						anim_object.index_h_count = htc
					end
					
					anim_object.parent_index = (held_transforms[anim_object.parent] and held_transforms[anim_object.parent].index_h) or anim_object.index_h

					local do_unset_parent = false
					if imgui.button((anim_object.parent_org and not anim_object.parent and "Reset") or "Unset") then  
						do_unset_parent = true
					end
					
					imgui.same_line()
					imgui_changed, anim_object.parent_index = imgui.combo("Set Parent ", anim_object.parent_index, anim_object.parents_list)
					
					if anim_object.parent_index == anim_object.index_h then 
						imgui.same_line()
						imgui.text("[No Parent]")
						if anim_object.parents_list[anim_object.parent_index] ~= " " then anim_object.parents_list = {} end
					end
					
					local parent_name = anim_object.parents_list[anim_object.parent_index]
					
					if do_unset_parent or (imgui_changed and parent_name ~= " " and not parent_name:find("CHILD")) then 
						if do_unset_parent or anim_object.parent_index == anim_object.index_h then 
							if anim_object.parent_org and not anim_object.parent then
								anim_object:set_parent(anim_object.parent_org or 0)
							else
								anim_object:set_parent(0)
								--anim_object.parent_obj.children = get_children(anim_object.parent_obj.xform)
							end
						else
							anim_object:set_parent(sorted_held_transforms[anim_object.parent_index].xform or 0)
						end
						--o_tbl.props_named._Parent.cvalue = nil
						--o_tbl.props_named._Parent.update = true
						--o_tbl.clear_next_frame = true
						o_tbl.invalid = true
						anim_object.display = true
						deferred_calls[anim_object.gameobj] = {lua_object=anim_object, method=GameObject.toggle_display}
						if _G.grab and anim_object.is_grabbed then 
							grab(anim_object.xform)
						end
					end
					
					imgui_changed, anim_object.display_transform = imgui.checkbox("Show Transform", anim_object.display_transform)
					
					if anim_object.display_transform then 
						imgui.same_line()
						if imgui.button("Print Transform to Log") then
							local pos, rot, scale = get_trs(anim_object)
							log.info("\n" .. game_object_name .. "->" .. " Transform: \n" .. log_transform(pos, rot, scale))
							re.msg("Printed to re2_framework_log.txt")
						end
					end 
					
					if not figure_mode and _G.grab and not anim_object.same_joints_constraint then 
						imgui.same_line()
						offer_grab(anim_object)
					end
					
					if anim_object.parent then 
						held_transforms[anim_object.parent] = held_transforms[anim_object.parent] or GameObject:new_AnimObject{xform = anim_object.parent}
					end
					
					if Collection and not Collection[anim_object.xform] and (not imgui.same_line() and imgui.button("Add to Collection")) then 
						Collection[anim_object.xform] = anim_object
						SettingsCache.detach_collection = true
						json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
					end
					
					if anim_object.joints then 
						
						imgui.same_line()
						imgui_changed, anim_object.show_joints = imgui.checkbox("Show Joints", anim_object.show_joints)	
						if imgui_changed and SettingsCache.affect_children and anim_object.children then 
							anim_object:change_child_setting("show_joints")
						end
						
						if anim_object.show_joints then 
							imgui.same_line()
							imgui_changed, anim_object.show_joint_names = imgui.checkbox("Show Joint Names", anim_object.show_joint_names)	
							if imgui_changed and SettingsCache.affect_children and anim_object.children then 
								anim_object:change_child_setting("show_joint_names")
							end					
							if anim_object.joints and anim_object.joint_positions then
								local output_str = "\n"
								for i, joint in ipairs(anim_object.joints) do 
									output_str = output_str .. joint:call("get_Name") .. " = " .. joint:call("get_NameHash") .. ",\n"
									local joint_pos = anim_object.joint_positions[joint]
									local parent = joint:call("get_Parent")
									local parent_pos = parent and anim_object.joint_positions[parent]
									local this_vec2 = draw.world_to_screen(joint_pos)
									if anim_object.show_joint_names or (parent and (parent_pos-joint_pos):length() > 1) then 
										draw.world_text(joint:call("get_Name"), joint_pos, 0xFFFFFFFF) 
									end
									if parent and this_vec2 then 
										local parent_vec2 = draw.world_to_screen(parent_pos)
										if parent_vec2 then 
											draw.line(parent_vec2.x, parent_vec2.y, this_vec2.x, this_vec2.y, 0xFF00FFFF)  
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
					
					if not anim_object.same_joints_constraint or not anim_object.parent then
						imgui_changed, anim_object.lookat_enabled = imgui.checkbox("LookAt", anim_object.lookat_enabled)
						if anim_object.lookat_enabled then 
							if anim_object.joints and not anim_object.same_joints_constraint then
								if not anim_object.joints_names then 
									anim_object.joints_names = {}
									for i, joint in ipairs(anim_object.joints) do  table.insert(anim_object.joints_names, joint:call("get_Name")) end
								end
								if anim_object.joints_names[1] then
									imgui.same_line()
									imgui_changed, anim_object.lookat_joint_index = imgui.combo("Set Source Bone", anim_object.lookat_joint_index, anim_object.joints_names)
									--imgui.text("                    "); imgui.same_line()
									if imgui.button(anim_object.joints[anim_object.lookat_joint_index].frozen and " Unfreeze " or "   Freeze   ") then 
										anim_object.joints[anim_object.lookat_joint_index].frozen = not not not anim_object.joints[anim_object.lookat_joint_index].frozen
										anim_object.lookat_joints = anim_object.lookat_joints or {}
										if anim_object.joints[anim_object.lookat_joint_index].frozen then
											anim_object.lookat_joints[anim_object.joints[anim_object.lookat_joint_index]] = anim_object.joints[anim_object.lookat_joint_index]:call("get_LocalRotation")
										else
											anim_object.lookat_joints[anim_object.joints[anim_object.lookat_joint_index]] = nil
										end
									end
									imgui.same_line()
								end
							end
							anim_object.lookat_index = anim_object.lookat_index or (selected and find_index(anim_object.parents_list, selected.name_w_parent)) or find_index(anim_object.parents_list, "Main Camera")
							imgui_changed, anim_object.lookat_index = imgui.combo("Set Target", anim_object.lookat_index, anim_object.parents_list)
							anim_object.lookat_obj = sorted_held_transforms[anim_object.lookat_index]
							anim_object.lookat_enabled = not not anim_object.lookat_obj
						else
							anim_object.lookat_joints = nil
						end
					end
					
					if imgui.tree_node_str_id(anim_object.xform:get_address()-50, "GameObject") then
						anim_object.opened = true
						if imgui.tree_node("[Lua]") then 
							if imgui.button("Clear Lua Data") then 
								anim_object:update_components()
								anim_object.children = get_children(anim_object.xform)
							end
							read_imgui_pairs_table(anim_object, anim_object.name .. "EMV")
							imgui.tree_pop()
						end
						
						if imgui.tree_node_str_id(anim_object.gameobj:get_address(), "via.GameObject") then
							imgui.managed_object_control_panel(anim_object.gameobj, "GameObject", game_object_name)
							if anim_object.gameobj._ then anim_object.gameobj._.owner = anim_object.gameobj._.owner or m_obj end
							--game_object_name = game_object_name or anim_object.gameobj:call("get_Name")
							imgui.tree_pop()
						end
						
						if anim_object.components[1] then 
							for i=1, #anim_object.components do 
								local component = anim_object.components[i]
								local comp_def = component:get_type_definition()
								if imgui.tree_node_str_id(component:get_address(), i .. ". " .. comp_def:get_full_name()) then
									imgui.managed_object_control_panel(component, comp_def:get_name(), comp_def:get_name())
									if component._ then component._.owner = component._.owner or m_obj end
									imgui.tree_pop()
								end
							end
						end
						imgui.tree_pop()
					end
				end
			elseif o_tbl.name == "Mesh" then
				if o_tbl.go and o_tbl.go.materials and imgui.tree_node_ptr_id(o_tbl.go.mesh:get_address() - 1234, "Materials") then
					show_imgui_mat(o_tbl.go) 
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
				o_tbl.gameobj = o_tbl.gameobj or m_obj:call("get_GameObject")
				o_tbl.go = o_tbl.go or (o_tbl.gameobj and held_transforms[o_tbl.xform or o_tbl.gameobj:call("get_Transform")] or GameObject:new{gameobj=o_tbl.gameobj})
				--if o_tbl.go.behaviortrees and o_tbl.go.behaviortrees.total_actions and (o_tbl.go.behaviortrees.total_actions > 0) and imgui.tree_node_str_id(o_tbl.go.name .. "Trees", "Action Monitor") then 
				if o_tbl.go.behaviortrees and imgui.tree_node_str_id(o_tbl.go.name .. "Trees", "Action Monitor") then 
					for i, bhvt_obj in ipairs(o_tbl.go.behaviortrees) do
						bhvt_obj:imgui_behaviortree()
					end
					imgui.tree_pop()
				end
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
			
			local do_auto_expand = (o_tbl.fields or o_tbl.props) and not o_tbl.item_type and not is_xform and not o_tbl.is_vt
			
			if do_auto_expand or ((o_tbl.fields or o_tbl.props) and imgui.tree_node_str_id(key_name .. "F", is_xform and "via.Transform" or "Fields & Properties")) then
				
				local max_elem_sz = SettingsCache.max_element_size or EMVSettings.max_element_size
				
				if o_tbl.fields then
					imgui.text("   FIELDS:")
					imgui.text("  ")
					imgui.same_line()
					imgui.push_id(key_name.."F")
					imgui.begin_rect()
						if (get_table_size(o_tbl.fields) > max_elem_sz) then
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
							for j = 1, #ordered_idxes, max_elem_sz do 
								j = math.floor(j)
								local this_limit = (#ordered_idxes < j+max_elem_sz and #ordered_idxes) or j+max_elem_sz
								local fname = (#ordered_idxes >= max_elem_sz) and o_tbl.fields[ ordered_idxes[j] ]:get_name()
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
							for i, field_name in ipairs(o_tbl.propdata.field_names) do
								was_changed = show_field(m_obj, o_tbl.fields[field_name], key_name) or was_changed
							end
						end
					imgui.end_rect(3)
					imgui.pop_id()
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
									was_changed = show_prop(m_obj, props[i], key_name) or was_changed
								end
								if #props >= max_elem_sz then
									imgui.tree_pop()
								end
							end
						end
					else
						for i, prop in ipairs(props) do 
							was_changed = show_prop(m_obj, prop, key_name) or was_changed
						end 
					end
				end
				
				if not do_auto_expand then
					imgui.tree_pop()
				end
			end
			
			if o_tbl.elements then 
				show_managed_objects_table(m_obj, o_tbl.elements, o_tbl, key_name, true)
			elseif o_tbl.is_vt == "parse" then -- o_tbl.name == "Guid" then
				local vt_as_string = m_obj:call("ToString()")
				changed, vt_as_string = show_imgui_text_box("Parse String", vt_as_string, o_tbl, (not prop or prop.set) and not was_changed, key_name .. "Guid", true)
				if changed then 
					--[[local try, out = pcall(m_obj.call, m_obj, "Parse(System.String)", vt_as_string)
					changed = try and not not out
					m_obj = out or m_obj]]
					deferred_calls[m_obj] = {func="Parse(System.String)", args=vt_as_string}
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
local function clear_object(xform)
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
		Collection[xform] = nil
		if player and player.xform == xform then player = nil end
		if xform.get_address then
			log.info("Removed lua objects with transform " .. xform:get_address())
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
		o.on = args.on or false
		o.anim_object = args.anim_object
		o.anim_object.update_materials = true
		o.mesh = args.mesh or o.anim_object.mesh
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
		
		if o.name then 
			o.on = o.mesh:call("getMaterialsEnable", o.id) or true
			o.var_num = o.mesh:call("getMaterialVariableNum", o.id)
			if SettingsCache.remember_materials and saved_mats[o.anim_object.name] and saved_mats[o.anim_object.name][o.anim_object.mesh_name] then
				saved_mats[o.anim_object.name][o.anim_object.mesh_name][o.name] = saved_mats[o.anim_object.name][o.anim_object.mesh_name][o.name] or {}
			end
			local saved_variables = args.saved_variables or (SettingsCache.remember_materials and saved_mats[o.anim_object.name] and saved_mats[o.anim_object.name][o.anim_object.mesh_name] and saved_mats[o.anim_object.name][o.anim_object.mesh_name])
			for i=1, o.var_num do
				var_name = o.mesh:call("getMaterialVariableName", o.id, i-1)
				table.insert(o.variable_names, var_name)
				o.var_names_dict[var_name] = i
				local type_of = o.mesh:call("getMaterialVariableType", o.id, i-1)
				table.insert(o.variable_types, type_of)
				local saved_variable = saved_variables and saved_variables[o.name][i]
				if not SettingsCache.remember_materials or (args.do_change_defaults or (not saved_variable or (type_of == 4 and type(saved_variable) == "number"))) then
					if type_of == 1 then 
						table.insert(o.variables, o.mesh:call("getMaterialFloat", o.id, i-1))
					elseif type_of == 4 then 
						table.insert(o.variables, o.mesh:call("getMaterialFloat4", o.id, i-1))
					else
						table.insert(o.variables, o.mesh:call("getMaterialBool", o.id, i-1))
					end
					if SettingsCache.remember_materials and saved_mats[o.anim_object.name] and saved_mats[o.anim_object.name][o.anim_object.mesh_name] then 
						saved_mats[o.anim_object.name][o.anim_object.mesh_name][o.name][i] = o.variables[i]
					end
				else
					if type_of == 4 then
						table.insert(o.variables, Vector4f.new(saved_variable.x, saved_variable.y, saved_variable.z, saved_variable.w))
					else
						table.insert(o.variables, saved_variable)
					end
					table.insert(o.deferred_vars, i)
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
	
	update = function(self)
		if self.var_num then 
			for v=1, self.var_num do
				self.mesh:call("get" .. mat_types[self.variable_types[v]], self.id, v-1)
			end
		end
		if self.tex_num > 0 and not self.textures[1] then 
			self.tex_idxes = {}
			for i=1, self.tex_num do
				local texture = self.mesh:call("getMaterialTexture", self.id, i-1)
				if not texture then 
					self.tex_num = i-1
					break 
				end
				table.insert(self.textures, texture:add_ref())
			end
		end
	end,
}

--Changes material variables, sometimes multiple at once from multiple related objects:
local function change_multi(og_mat, og_var_name, og_var_id, og_diff, og_object)
	og_object = og_object or og_mat.anim_object
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
	recurse_multi(og_mat, og_var_name, og_var_id, og_diff, og_object)
	og_object.shared_material_objects = changed_objs
end

--Displays one material variable from Material class in imgui:
local function draw_material_variable(mat, var_name, v)
	imgui.push_id(mat.mesh:get_address() + v)
	imgui.begin_rect()
		
		--[[if mat.variables[v] ~= mat.orig_vars[v] then 
			imgui.text("*")
			imgui.same_line()
		end]]
		
		local can_reset = (mat.variables[v] ~= mat.orig_vars[v])
		if can_reset then imgui.begin_rect() imgui.begin_rect() end
		if imgui.button(var_name) then 
			mat.anim_object.update_materials = true
			mat.variables[v] = mat.variable_types[v] == 4 and Vector4f.new(mat.orig_vars[v].x, mat.orig_vars[v].y, mat.orig_vars[v].z, mat.orig_vars[v].w) or mat.orig_vars[v]
			table.insert(mat.deferred_vars, v)
			change_multi(mat, var_name, v)
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
		mat.multi[v] = mat.multi[v] or {}
		changed, mat.multi[v].do_multi = imgui.checkbox("Change Multiple", mat.multi[v].do_multi)
		
		local new_var =  mat.variable_types[v] == 4 and Vector4f.new(mat.variables[v].x, mat.variables[v].y, mat.variables[v].z, mat.variables[v].w) or mat.variables[v]
		
		if mat.variable_types[v] == 1 then 
			changed, new_var = imgui.drag_float(var_name, new_var, 0.01, -10000, 10000)
		elseif mat.variable_types[v] == 4 then
			local was_changed = false
			changed, new_var = show_imgui_vec4(new_var, var_name)
		else
			changed, new_var = imgui.checkbox(var_name, new_var)
		end
		if changed then 
			mat.anim_object.update_materials = true
			table.insert(mat.deferred_vars, v)
			mat.variables[v] = new_var
			change_multi(mat, var_name, v, new_var - mat.variables[v]) 
		end
		if mat.multi[v].do_multi then 
			changed, mat.multi[v].search_term = imgui.input_text("Search Terms", mat.multi[v].search_term or mat.last_search_terms)
			mat.multi[v].search_terms = mat.multi[v].search_terms or {}
			mat.multi[v].search_terms[1] = mat.multi[v].search_terms[1] or mat.multi[v].search_term
			if changed then
				mat.last_search_terms = mat.multi[v].search_term
				mat.multi[v].search_terms  = split(mat.multi[v].search_term, " ") or table.pack(mat.multi[v].search_term)
			end
		end
	imgui.end_rect(3)
	imgui.spacing()
	imgui.pop_id()
end

--Displays one full material from the Material class in imgui:
show_imgui_mat = function(anim_object)
	
	if anim_object.pairing and (not anim_object.mesh or not anim_object.mesh:call("getMesh")) then
		anim_object = anim_object.pairing
	end
	
	if SettingsCache.remember_materials then
		imgui.begin_rect()
			if imgui.button("Save New Defaults") then 
				for xform, obj in pairs(anim_object.shared_material_objects) do
					saved_mats[obj.name] = saved_mats[obj.name] or {}
					saved_mats[obj.name][obj.mesh_name] = saved_mats[obj.name][obj.mesh_name] or {} --enable material saving
					obj:set_materials(true) 
				end
				EMVSettings.saved_mats = jsonify_table(saved_mats)
				json.dump_file("EnhancedModelViewer\\EMVSettings.json", jsonify_table(EMVSettings))
			end
		imgui.end_rect(3)
		if saved_mats[anim_object.name] and not imgui.same_line() and imgui.button(next(saved_mats[anim_object.name]) and "Clear New Defaults" or "[Cleared]") then 
			reset_material_settings(anim_object)
		end
	end
	
	if RN.mesh_resource_names then
		changed, anim_object.current_mesh_idx = imgui.combo("Change Mesh: " .. anim_object.name, find_index(RN.mesh_resource_names, anim_object.mpaths.mesh_path) or anim_object.current_mesh_idx, RN.mesh_resource_names)
		if changed then 
			local msh_tbl = RSCache.mesh_resources[ RN.mesh_resource_names[anim_object.current_mesh_idx] ]
			anim_object.mesh:call("setMesh", msh_tbl[1])
			if RSCache.mesh_resources[ RN.mesh_resource_names[ anim_object.current_mesh_idx] ][2] then 
				anim_object.mesh:call("set_Material", msh_tbl[2])
				anim_object.mpaths.mdf2_path = msh_tbl[2] and msh_tbl[2].call and msh_tbl[2]:call("ToString()"):match("^.+%[@?(.+)%]")
			end
			anim_object.mpaths.mesh_path = RN.mesh_resource_names[ anim_object.current_mesh_idx ]
			anim_object:set_materials() 
		end
		
		changed, anim_object.current_mdf_idx = imgui.combo("Change Materials: " .. anim_object.name, find_index(RN.mdf2_resource_names, anim_object.mpaths.mdf2_path) or anim_object.current_mdf_idx, RN.mdf2_resource_names)
		if changed then 
			anim_object.mesh:call("set_Material", RSCache.mdf2_resources[ RN.mdf2_resource_names[anim_object.current_mdf_idx] ])
			anim_object.mpaths.mdf2_path = RN.mdf2_resource_names[ anim_object.current_mdf_idx ]
			anim_object:set_materials() 
		end
	end
	
	for i, mat in ipairs(anim_object.materials) do
		imgui.push_id(mat.name)
			changed, mat.on = imgui.checkbox("", mat.on)
			if changed then
				anim_object.mesh:call("setMaterialsEnable", i-1, anim_object.materials[i].on)
			end
			imgui.same_line()
			if imgui.tree_node_str_id(mat.name, mat.name) then
				
				if mat.textures[1] and imgui.tree_node("Textures") then
					mat.tex_idxes = mat.tex_idxes or {}
					for t, texture in ipairs(mat.textures) do 
						local tex_name = texture:call("ToString()"):match("^.+%[@?(.+)%]")
						--local mat_name = mat.mesh:call("getMaterialTextureName", i-1, t-1) or t
						local mat_name = ({pcall(mat.mesh.call, mat.mesh, "getMaterialTextureName", i-1, t-1)})
						mat_name = mat_name[1] and mat_name[2] or t
						mat.tex_idxes[t] = add_resource_to_cache(texture)
						changed, mat.tex_idxes[t] = imgui.combo((mat_name or t), find_index(RN.tex_resource_names, tex_name) or 1, RN.tex_resource_names) --mat.tex_idxes[t] or find_index(RN.tex_resource_names, tex_name) or 1
						if changed then 
							local mat_var_idx = mat.mesh:call("getMaterialVariableIndex", i-1, hashing_method and hashing_method(mat_name) or t-1) 
							deferred_calls[mat.mesh] = { func="setMaterialTexture", args={i-1, (mat_var_idx ~= 255) and mat_var_idx or t-1, RSCache.tex_resources[ RN.tex_resource_names[ mat.tex_idxes[t] ] ] } }
							mat.textures[t] = RSCache.tex_resources[ RN.tex_resource_names[ mat.tex_idxes[t] ] ]
						end
					end
					imgui.tree_pop()
				end
			
				for v, var_name in ipairs(mat.variable_names) do  
					draw_material_variable(mat, var_name, v)
				end
				
				imgui.tree_pop() 
			end
		imgui.pop_id()
	end
end

--Resets saved material settings:
local function reset_material_settings(object)	
	if object.mesh_name then 
		if saved_mats[object.name] and saved_mats[object.name][object.mesh_name] then saved_mats[object.name][object.mesh_name] = {} end
		if SettingsCache.affect_children and object.children then 
			for i, child in ipairs(object.children) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
				reset_material_settings(held_transforms[child])
			end
		end
	end
end

--Function to manage saved materials:
local function imgui_saved_materials_menu() 
	local idx = 0
	if imgui.button("Clear Saved Materials") then 
		_G.saved_mats = {}
	end
	for key, sub_tbl in orderedPairs(_G.saved_mats) do
		idx = idx + 1
		local xform, obj = next(sub_tbl._objects or {})
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
end

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
						--imgui_anim_object_viewer(held_transforms[anim_object.parent], held_transforms[anim_object.parent].name)
						imgui.managed_object_control_panel(anim_object.parent, "Parent", held_transforms[anim_object.parent].name)
						imgui.tree_pop()
					end
				--if not is_only_parent then imgui.end_rect() end
			end
			
			if not (is_only_child or is_only_parent) then 
				imgui.text("	")
				imgui.same_line()
				imgui.begin_rect()
			end
			for i, child in ipairs(anim_object.children or {}) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{ xform=child }
				if held_transforms[child] and imgui.tree_node_str_id(obj_name .. "Ch" .. i,  is_only_child or held_transforms[child].name) then
					--imgui_anim_object_viewer(held_transforms[child], "Object")
					imgui.managed_object_control_panel(child, "Ch" .. i, held_transforms[child].name)
					imgui.tree_pop()
				end
			end
			if not (is_only_child or is_only_parent) then
				imgui.end_rect(1)
				imgui.tree_pop()
			end
		end
	end
	
	if not figure_mode and not cutscene_mode and anim_object.behaviortrees and anim_object.behaviortrees[1] and anim_object.behaviortrees[1].names_indexed and imgui.tree_node_str_id(anim_object.name .. "Trees", "Action Monitor") then 
		anim_object.opened = true
		for i, bhvt_obj in ipairs(anim_object.behaviortrees or {}) do
			if imgui.tree_node(bhvt_obj.name) then
				bhvt_obj:imgui_behaviortree()
				imgui.tree_pop()
			end
		end
		imgui.tree_pop()
	end
	
	--if anim_object.mesh and not anim_object.materials then 
	--	anim_object:set_materials() 
	--end
	if anim_object.materials and imgui.tree_node_ptr_id(anim_object.mesh, "Materials") then
		show_imgui_mat(anim_object) 
		imgui.tree_pop()
	end
end

--Display a managed object in imgui
local function handle_obj(managed_object, title)
	title = title or "Object"
	if sdk.is_managed_object(managed_object) then 
		local typedef = managed_object:get_type_definition()
		if typedef:is_a("via.Component") then 
			local gameobj = managed_object:call("get_GameObject")
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
	if imgui.button("Clear Collected Objects") then 
		Collection = {}
	end
	for xform, obj in pairs(Collection) do 
		if xform:read_qword(0x10) ~= 0 then
			if imgui.tree_node_ptr_id(xform, obj.name) then 
				imgui.same_line()
				if imgui.button("X") then 
					Collection[xform] = nil 
					json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
				end
				imgui_anim_object_viewer(obj)
				imgui.tree_pop()
			end
		else
			clear_object(xform)
		end
	end
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
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj
		log.info("making node")
		local owner = args.layer or args.BHVT
		if not owner or not o.obj then return end
		o.name = args.name or o.obj:get_full_name() or o.name
		o.id = o.obj:get_id()
		o.tree_idx = args.tree_idx
		owner.node_names = owner.node_names or {}
		owner.node_names[o.name] = o
		for i, child in ipairs(o.obj:get_children()) do 
			if child.get_full_name then 
				o.children = o.children or {}
				local child_obj = self:get_node_obj(child, owner, o.tree_idx)
				o.children[#o.children+1] = child_obj
			end
		end
		for i, action in ipairs(o.obj:get_actions()) do 
			o.actions = o.actions or {}
			local action_obj = BHVTAction:new{obj=action, node_obj=o} --self:get_action_obj(action, owner)
			o.actions[i] = action_obj
		end
		for i, transition in ipairs(o.obj:get_transitions()) do 
			if transition.get_full_name then 
				o.transitions = o.transitions or {}
				local transition_obj = self:get_node_obj(transition, owner, o.tree_idx)
				o.transitions[#o.transitions+1] = transition_obj
			end
		end
		self.__index = self
		return setmetatable(o, self)
	end,
	
	get_node_obj = function(self, node, owner, tree_idx)
		return self:new({obj=node, owner=owner, name=node:get_full_name(), tree_idx=tree_idx})
	end,
}

local BHVTCoreHandle = {
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or o.obj
		o.tree = args.tree or (o.obj and o.obj:get_tree_object()) or o.tree
		o.index = args.index or o.index
		if not o.tree or not o.obj then return end
		o.name = get_mgd_obj_name(o.obj)
		o.nodes = {}
		o.nodes_indexed = {}
		testes = o
		for j, node in ipairs(o.tree:get_nodes() or {}) do
			local node_obj = BHVTNode:new{obj=node, layer=o, tree_idx=o.index}
			o.nodes[node:get_full_name()] = node_obj
			table.insert(o.nodes_indexed, node_obj)
		end
		local new_node_names = {}
		for name, node in orderedPairs(o.node_names or {}) do 
			if not name:find("%.") then
				table.insert(new_node_names, {name=name, obj=node})
			end
		end
		o.node_names_indexed = new_node_names
		self.__index = self
		return setmetatable(o, self)
	end,
}


--Class for holding behaviortree managed objects:
local BHVT = {
	
	new = function(self, args, o)
		o = o or {}
		o.obj = args.obj or o.obj
		o.name = o.obj:call("ToString()")
		o.xform = args.xform or (o.obj and o.obj:call("get_GameObject"):call("get_Transform"))
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
			local core_handles = lua_get_system_array(o.obj:call("get_Layer()")) or o.obj:get_trees()
			if core_handles then 
				o.variables = o.variables or {}
				o.core_handles = o.core_handles or {}
				for i, core_handle in ipairs(core_handles) do 
					o.core_handles[get_mgd_obj_name(core_handle) or i] = BHVTCoreHandle:new{obj=core_handle, index=i-1}
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
	
	imgui_bhvt_nodes = function(self, node, name, imgui_keyname, dfcall_template, dfcall_json)
		
		--imgui.text(node.tree_idx)
		if imgui.button_w_hotkey(name, self.imgui_keyname .. "." .. name, dfcall_template, {name,  node.tree_idx, static_objs.setn}, dfcall_json) then
			self:set_node(name)
		end
		
		if (node.children or node.transitions or node.actions) then 
			name = name or node.obj:get_full_name()
			imgui_keyname = imgui_keyname or self.imgui_keyname
			dfcall_template = dfcall_template or {obj=self.obj, func="setCurrentNode(System.String, System.UInt32, via.behaviortree.SetNodeInfo)"}
			--dfcall_template = dfcall_template or {obj=node.layer.layer, func="setCurrentNode(System.UInt64, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)"}
			imgui.same_line()
			if imgui.tree_node_str_id(name.."C", "") then
				if node.children and imgui.tree_node("Children") then
					for i, child_node_obj in pairs(node.children) do 
						self:imgui_bhvt_nodes(child_node_obj, child_node_obj.name, imgui_keyname, dfcall_template)
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
				if node.transitions and imgui.tree_node("Transitions") then
					for i, transition_node_obj in pairs(node.transitions) do 
						self:imgui_bhvt_nodes(transition_node_obj, transition_node_obj.name, imgui_keyname, dfcall_template)
					end
					imgui.tree_pop()
				end
				imgui.tree_pop()
			end
		end
	end,
	
	imgui_behaviortree = function(self)
		
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
							self:set_node(nil, 1)
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
						down_timer = 0.0,
						--__component_name = self.obj:get_type_definition():get_full_name(),
						--__getter = "getLayer",
						--__idx = layer.index, --these three^ can locate a field of a component in jsonify_table
					}
					for core_name, core_handle in orderedPairs(self.core_handles) do
						if imgui.tree_node(core_name) then
							for i, node_tbl in ipairs(core_handle.nodes_indexed) do 
								self:imgui_bhvt_nodes(node_tbl, node_tbl.name, self.imgui_keyname, dfcall_template, dfcall_json)
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
				
				self._.sequencer = self._.sequencer or MoveSequencer:new({obj=self.obj}, self._.sequencer)
				
				--if next(self._.sequencer.Hotkeys) then
					local seq_detach = self._.sequencer and self._.sequencer.detach
					if seq_detach and imgui.begin_window("Sequencer: " .. self.object.name .. " " .. self.name, true, SettingsCache.transparent_bg and 128 or 0) == false then
						self._.sequencer.detach = false
					end
					
					if seq_detach or imgui.tree_node("Sequencer") then 
						if ((imgui.button("Update") or imgui.same_line()) or not self._.sequencer) then
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
				--end
				
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
	
	set_node = function(self, node_name, node_id, check_idx)
		node_name = node_name or self.names_indexed[check_idx or self.current_name_idx]
		if node_id then 
			self.obj:call("setCurrentNode(System.UInt64, via.behaviortree.SetNodeInfo, via.motion.SetMotionTransitionInfo)", node_id, nil, nil)
		else
			self.obj:call("setCurrentNode(System.String, System.UInt32, via.behaviortree.SetNodeInfo)", node_name, self.tree_idx, static_objs.setn)
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

--GameObject lua class, used for everything: -------------------------------------------------------------------------------------------------
GameObject = {
	
	new = function(self, args, o)
		
		o = o or {} 
		o.xform 			= args.xform or o.xform
		o.gameobj			= args.gameobj
		local try = true 	
		if o.xform and not o.gameobj then 
			try, o.gameobj =  pcall(sdk.call_object_func, o.xform, "get_GameObject") 
		end
		o.xform = o.xform or o.gameobj and o.gameobj:call("get_Transform")
		if not try or not o.gameobj or not is_valid_obj(o.xform) then
			return 
		end
		self.__index = self
		
		o.name = args.name or o.gameobj:call("get_Name")
		o.name_w_parent = o.name
		o.parent = args.parent or o.xform:call("get_Parent")
		o.parent_org = o.parent
		o.children = args.children or get_children(o.xform)
		o.display = args.display or o.gameobj:call("get_Draw") --or number_to_bool[o.gameobj:read_byte(0x13)]
		o.same_joints_constraint = o.xform:call("get_SameJointsConstraint") or nil
		o.components = args.components
		
		if o.parent then
			local parent_gameobj = o.parent:call("get_GameObject")
			local parent_name = parent_gameobj and parent_gameobj:call("get_Name")
			GameObject.set_name_w_parent(o)
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
				o.is_light = o.is_light or (typedef:get_name() == "IBL") or (not not (fname:find("Light[Shaft]-$") and fname:find("^via%.render"))) or nil
				if typedef:is_a("via.behaviortree.BehaviorTree") then 
					o.behaviortrees = o.behaviortrees or {}
					local bhvt = BHVT:new{obj=component, xform=o.xform, object=o, index=#o.behaviortrees+1}
					table.insert(o.behaviortrees, bhvt)
					--log.info(json.log(bhvt.names) .. " " ..  get_table_size(bhvt.names) .. " " .. o.behaviortrees.total_actions .. " " .. tostring(bhvt.names_indexed and #bhvt.names_indexed))
				end
			end
		end
		
		o.mfsm2 = o.components_named.MotionFsm2
		o.mesh = args.mesh or o.components_named.Mesh or lua_find_component(o.gameobj, "via.render.Mesh") or o.mesh
		
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
				if isDMC5 then 
					o.mesh_name_short = o.mesh_name_short:sub(1, 9)
				elseif isRE8 then
					o.mesh_name_short = o.mesh_name_short:sub(1, 8) --7
				else
					o.mesh_name_short = o.mesh_name_short:sub(1, 6) 
				end
				o.mesh_name_short = o.mesh_name_short:lower()
				GameObject.set_materials(o) 
			end
			o.mesh_name = o.mesh_name or ""
		end
		o.key_name = get_gameobj_path(o.gameobj)
		o.key_hash = o.key_name and hashing_method(o.key_name)
		
        return setmetatable(o, self)
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
	
	reset_physics = function(self)
		if self.physicscloth then self.physicscloth:call("restart") end
		if self.chain then self.chain:call("restart") end
	end,
	
	set_materials = function(self, do_change_defaults, args)
		local mesh = args and args.mesh or self.mesh
		local materials_count = mesh and mesh:call("get_MaterialNum") or 0
		if materials_count == 0 then return end
		self.materials = {}
		--saved_mats[self.mesh_name] = saved_mats[self.mesh_name] or {}
		if SettingsCache.remember_materials and saved_mats[self.name] then
			saved_mats[self.name].active = saved_mats[self.name].active or do_change_defaults
		end
		for i=1, materials_count do 
			local new_args = {anim_object=self, id=i-1, do_change_defaults=do_change_defaults}
			local new_mat = Material:new((args and merge_tables(new_args, args) or new_args))
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
	
	set_name_w_parent = function(self)
		self.name_w_parent = self.name
		local tmp_xform = self.xform:call("get_Parent")
		while tmp_xform do
			local parent_gameobj = tmp_xform:call("get_GameObject")
			if figure_mode and not lua_find_component(parent_gameobj, "via.motion.Motion") then
				break
			end
			self.name_w_parent = tmp_xform:call("get_GameObject"):call("get_Name") .. " -> " .. self.name_w_parent
			tmp_xform = tmp_xform:call("get_Parent")
		end
	end,
	
	pre_fix_displays = function(self)
		self.last_display = self.display
		if SettingsCache.affect_children and self.children then 
			for i, child in ipairs(self.children) do
				held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{xform=child}
				held_transforms[child]:pre_fix_displays()
			end
		end
	end,
	
	set_transform = function(self, trs, do_deferred)
		if do_deferred then
			deferred_calls[self.xform] = deferred_calls[self.xform] or {}
			table.insert(deferred_calls[self.xform], {lua_object=self, method=GameObject.set_transform, args={trs}})
		else
			--self:pre_fix_displays()
			if trs[1] then self.xform:call("set_Position", trs[1]) end
			if trs[2] then self.xform:call("set_Rotation", trs[2]) end
			if trs[3] then self.xform:call("set_Scale", trs[3]) end
			--self:toggle_display()
		end
	end,
	
	set_parent = function(self, new_parent_xform, do_deferred)
		if do_deferred then
			deferred_calls[self.xform] = deferred_calls[self.xform] or {}
			table.insert(deferred_calls[self.xform], {lua_object=self, method=GameObject.set_parent, args={new_parent_xform}})
		else 
			self:pre_fix_displays()
			pcall(sdk.call_object_func, self.xform, "set_Parent", new_parent_xform)
			self.parent = self.xform:call("get_Parent")
			self.parent_obj = self.parent and (held_transforms[self.parent] or GameObject:new{xform=self.parent})
			if self.parent_obj then
				local tmp = not not self.parent_obj.same_joints_constraint
				self.parent_obj.xform:call("set_SameJointsConstraint", not tmp) --refreshes
				self.parent_obj.xform:call("set_SameJointsConstraint", tmp)
			end
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
		
		if self.parent_obj then 
			local tmp = not not self.parent_obj.same_joints_constraint
			self.parent_obj.xform:call("set_SameJointsConstraint", not tmp) --refreshes
			self.parent_obj.xform:call("set_SameJointsConstraint", tmp)
		end
		--self.gameobj:call("set_UpdateSelf", self.display)
		--self.gameobj:write_byte(0x14, bool_to_number[self.display]) --updateself
		--self.gameobj:write_byte(0x12, bool_to_number[self.display])	--update	
		self.gameobj:write_byte(0x13, bool_to_number[self.display])	--draw
		
		if changed and not is_child then -- or forced_setting 
			self.keep_on = nil
			self.display_org = self.display
		end
		
		if SettingsCache.affect_children and self.children then
			changed = false
			for i, child in ipairs(self.children) do
				local child_obj = held_transforms[child]
				if child_obj and (restore or (cutscene_mode or (not self.display or child_obj.display_org == true))) then
					child_obj.display = self.display
					child_obj:toggle_display(true)
				end
			end
		end
		if changed and figure_mode and self.mesh_name_short then
			EMVCache.custom_lists[self.mesh_name_short] = EMVCache.custom_lists[self.mesh_name_short] or {}
			EMVCache.custom_lists[self.mesh_name_short].Display = self.display
		end
		self.toggled_display = self.display
		--log.info("set " .. self.name .. " to " .. tostring(self.display) .. ", draw is " .. tostring(self.gameobj:call("get_Draw")) .. ", drawself is " .. tostring(self.gameobj:call("get_DrawSelf")))
	end,
	
	update_components = function(self)
		--self.components, self.components_named = lua_get_components(self.xform)
		if held_transforms[self.xform] then
			held_transforms[self.xform] = GameObject.new_AnimObject and GameObject:new_AnimObject({xform=self.xform}) or GameObject:new({xform=self.xform})
		end
		if touched_gameobjects[self.xform] then
			touched_gameobjects[self.xform] = GameObject.new_GrabObject and GameObject:new_GrabObject({xform=self.xform}) or GameObject:new({xform=self.xform})
		end
		--[[if self.mot_idx then
			local new_obj = self.layer and GameObject:new_AnimObject{xform=self.xform, bank_idx=self.bank_idx, mlist_idx=self.mlist_idx, mot_idx=self.mot_idx} or GameObject:new_AnimObject{xform=self.xform}
			deferred_calls[self.gameobj] = {anim_object=new_obj, lua_object="object:control_action( { do_seek=true, force_seek=true, current_frame=" .. self.frame .. ", } )"}
		end
		if self.total_objects_idx then 
			total_objects[self.total_objects_idx] = new_obj 
		end
		if selected then 
			selected = (selected.xform == self.xform) and new_obj or selected 
		else 
			selected = new_obj 
		end
		held_transforms[self.xform] = new_obj]]
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
			
			if parent ~= self.parent then --recreate name_w_parent
				self:set_name_w_parent()
			end
			
			self.parent = parent
			self.same_joints_constraint = self.xform:call("get_SameJointsConstraint") or nil
			
			if self.behaviortrees then
				for i, bhvt_obj in ipairs(self.behaviortrees) do 
					--self.behaviortrees[i] = (touched_gameobjects[self.xform] and touched_gameobjects[self.xform].behaviortrees and touched_gameobjects[self.xform].behaviortrees[i]) or bhvt_obj
					bhvt_obj:update()
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
			
			if self.show_joints and self.joints and not self.force_center then
				self.joint_positions = self.joint_positions or {}
				for i, joint in pairs(self.joints) do 
					self.joint_positions[joint] = sdk.is_managed_object(joint) and joint:call("get_Position")
				end
			end
			
			if self.display_transform then 
				shown_transforms[self.xform] = self
			end
			--[[for key, value in pairs(self) do 
				if not value then 
					self[key] = nil --cleans up keys, til I need one to be false
				end
			end]]
			return true
		else
			clear_object(self.xform)
		end
	end,
	
	update_all = function(self)
		if self:update() then
			if self.update_AnimObject then self:update_AnimObject(true) end
			if self.update_GameObject then self:update_GrabObject(true) end
		end
	end,
}

--Load cache, and create list of names of them for imgui in RN[] -------------------------------------------------------------------------------
local function init_resources()
	if SettingsCache.load_json then
		local try, new_cache = pcall(json.load_file, "EMV_Engine\\RSCache.json")
		if try and new_cache then 
			try, new_cache = pcall(jsonify_table, new_cache, true)
			if try and new_cache then 
				if SettingsCache.remember_materials and new_cache.saved_mats and next(new_cache.saved_mats) then 
					saved_mats = new_cache.saved_mats
				end
				for key, value in pairs(new_cache) do
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
		end
	end
end

--Load other settings, enums, misc tables:
default_SettingsCache = deep_copy(SettingsCache)
local function init_settings()
	
	local try, new_cache = pcall(json.load_file, "EMV_Engine\\SettingsCache.json")
	if try and new_cache then SettingsCache.load_json = new_cache.load_json end
	
	if try and new_cache and SettingsCache.load_json then 
		--re.msg_safe(tostring(new_cache.load_json), 3523534)
		try, new_cache = pcall(jsonify_table, new_cache, true)
		if try and new_cache then 
			for key, value in pairs(SettingsCache) do 
				if new_cache[key] == nil then 
					new_cache[key] = value  --add any new settings from this script
				end 
			end
			SettingsCache = new_cache
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

local function dump_settings()
	if SettingsCache.load_json then 
		RSCache.saved_mats = saved_mats
		json.dump_file("EMV_Engine\\RSCache.json", jsonify_table(RSCache))
		json.dump_file("EMV_Engine\\SettingsCache.json", jsonify_table(SettingsCache))
		json.dump_file("EMV_Engine\\CachedActions.json", jsonify_table(CachedActions))
		CachedGlobals = {}
		for key, value in pairs(_G) do 
			if type(key) == "string" and ({pcall(sdk.is_managed_object, value)})[2] == true then 
				CachedGlobals[key] = value
			end
		end
		json.dump_file("EMV_Engine\\CachedGlobals.json",  jsonify_table(CachedGlobals, false))
		json.dump_file("EMV_Engine\\Collection.json",  jsonify_table(Collection, false, {convert_lua_objs=true}))
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
re.on_pre_application_entry("LockScene", function() 
	
	if not EMVSettings then --Enhanced Model Viewer will update it
		for xorm, obj in pairs(held_transforms) do 
			obj:update()
		end
	end
	
	for managed_object, args in pairs(deferred_calls) do 
		deferred_call(managed_object, args)
	end
	--deferred_calls = {}
	for instance, data in pairs(metadata) do
		local o_tbl = instance._
		if o_tbl then 
			if not (o_tbl.keep_alive or o_tbl.is_frozen) then
				o_tbl.last_opened = o_tbl.last_opened or uptime
			end
			if o_tbl.invalid or (o_tbl.last_opened and (uptime - o_tbl.last_opened) > 5) then
				log.info("Deleting instance " .. o_tbl.name)
				metadata[instance] = nil
			else
				instance:__update(nil, o_tbl.clear)
				o_tbl.clear = nil
			end
		--else
		--	metadata[instance] = nil
		end
	end
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
					end
					mat.deferred_vars = {}
					mat:update()
				end
				obj.update_materials = nil
			end
		end
	end
end)

--On Frame ------------------------------------------------------------------------------------------------------------------------------------------------
re.on_frame(function()
	
	--[[if check_key_released(via.hid.KeyboardKey.B, 0.0) then
		imgui.text("B")
	end]]
	
	tics = tics + 1
	uptime = os.clock()
	history_input_this_frame = nil
	
	if tics == 1 then
		
		init_settings()
		init_resources()
	end
	
	if random(60) then
		log.info("ord size: " .. get_table_size(G_ordered))
		for key, tbl in pairs(G_ordered) do
			if not tbl.open or (uptime > tbl.open + 30) then
				G_ordered[key] = nil --periodically purge old table metadatas
			end
		end
	end
	
	for managed_object, args in pairs(on_frame_calls) do 
		deferred_call(managed_object, args, nil, true)
	end
	
	player = player or get_player(true)
	
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
					local world_value = (sub_tbl.method and sub_tbl.method:call(obj)) or (sub_tbl.field and sub_tbl.field:get_data(obj))
					if sub_tbl.as_local and obj._.xform then 
						world_value = world_value + obj._.xform:call("get_Position")
					end
					if world_value then 
						draw_world_pos(world_value, sub_tbl.name, sub_tbl.color)
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
				local gameobj = scene:call("findGameObject(System.String)", name)
				if gameobj then 
					if not saved_mats[name]._objects then --create the original objects list once by doing a full search:
						local searchresults = scene and lua_get_system_array(scene:call("findComponents(System.Type)", sdk.typeof("via.render.Mesh")))
						saved_mats[name]._objects = searchresults and {}
						for i, result in ipairs(searchresults or {}) do
							local gameobj = result:call("get_GameObject")
							if gameobj and gameobj:call("get_Name") == name then 
								local mesh_name = result:call("getMesh")
								mesh_name = mesh_name and mesh_name:call("ToString()")
								if args[mesh_name] and is_valid_obj(gameobj) then 
									local xform = gameobj:call("get_Transform")
									saved_mats[name]._objects[xform] = saved_mats[name]._objects[xform] or GameObject:new{xform=xform}
								end
							end
						end
					else
						local xform = gameobj:call("get_Transform")
						if not saved_mats[name]._objects[xform] then --...or find+add any newcomers to the list one-by-one as they are spawned:
							local via_render_mesh = lua_find_component(gameobj, "via.render.Mesh")
							local mesh_name = via_render_mesh and via_render_mesh:call("getMesh")
							mesh_name = mesh_name and mesh_name:call("ToString()"):match("^.+%[@?(.+)%]") or mesh_name
							
							if mesh_name and args[mesh_name] and not saved_mats[name]._objects[xform] then 
								held_transforms[xform] = held_transforms[xform] or GameObject:new{ gameobj=gameobj, xform=xform }
								saved_mats[name]._objects[xform] = held_transforms[xform]
								meshes = lua_get_system_array(scene:call("findComponents(System.Type)", sdk.typeof("via.render.Mesh"))) --refresh the whole list when the newest xform isnt known
								for i, mesh in ipairs(meshes or {}) do 
									local other_mesh_name = mesh:call("getMesh")
									other_mesh_name = other_mesh_name and other_mesh_name:call("ToString()")
									if other_mesh_name == held_transforms[xform].mesh_name then
										local other_xform = mesh:call("get_GameObject"); other_xform = other_xform and other_xform:call("get_Transform")
										if other_xform then
											held_transforms[other_xform] = held_transforms[other_xform] or GameObject:new{ xform=other_xform }
											saved_mats[name]._objects[other_xform] = held_transforms[other_xform]
										end
									end
								end
							end
						end
					end
				end
				if saved_mats[name]._objects then 
					for xform, object in pairs(saved_mats[name]._objects) do 
						if not is_valid_obj(object.xform) then 
							saved_mats[name]._objects[object.xform] = nil
							clear_object(object.xform)
						end
					end
					--if #saved_mats[name]._objects == 0 then saved_mats[name]._objects = nil end
				end
			end
		end
	end
	
	if reframework:is_drawing_ui() then
		shown_transforms = {} 
		SettingsCache.detach_collection = SettingsCache.detach_collection and not not next(Collection)
		if not SettingsCache.detach_collection or (imgui.begin_window("Collection", true, SettingsCache.transparent_bg and 128 or 0) == false) then 
			SettingsCache.detach_collection = false
		end
		if SettingsCache.detach_collection then
			show_collection()
			imgui.end_window()
		end
		--world_positions = {} 
	end
end)


--On Draw UI (Show Settings) ---------------------------------------------------------------------------------------------------------------------------------------
re.on_draw_ui(function()
	
	--[[for tbl_addr, metadata in pairs(temptxt) do
		if metadata.__tics + 500 < tics then
			temptxt[tbl_addr] = nil
		end
	end]]
	--[[if counter > 0 then
		imgui.text("Call Count: " .. tostring(counter))
	end]]
	
	local csetting_was_changed, special_changed
	
	if imgui.tree_node("EMV Engine Settings") then
		special_changed, SettingsCache.load_json = imgui.checkbox("Remember Settings", SettingsCache.load_json); csetting_was_changed = csetting_was_changed or changed
		if imgui.tree_node("Managed Object Control Panel Settings") then
			local EMVSetting_was_changed
			changed, SettingsCache.max_element_size = imgui.drag_int("Max Fields/Properties Per-Grouping", SettingsCache.max_element_size, 1, 1, 2048); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, SettingsCache.affect_children = imgui.checkbox("Affect Children", SettingsCache.affect_children); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, SettingsCache.show_all_fields = imgui.checkbox("Show Extra Fields", SettingsCache.show_all_fields); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, SettingsCache.remember_materials = imgui.checkbox("Remember Material Settings", SettingsCache.remember_materials); EMVSetting_was_changed = EMVSetting_was_changed or changed
			if SettingsCache.remember_materials and next(saved_mats) and imgui.tree_node("Saved Material Settings") then
				read_imgui_element(saved_mats)
				imgui.tree_pop()
			end
			if next(Hotkey.used) and imgui.tree_node("Hotkeys") then 
				if imgui.button("Clear Hotkeys") then 
					Hotkeys, Hotkey.used = {}, {}
					json.dump_file("EMV_Engine\\Hotkeys.json", Hotkey.used)
				end
				local last_name
				for key_name, hk_tbl in orderedPairs(Hotkeys) do
					if hk_tbl.gameobj_name and  hk_tbl.gameobj_name ~= last_name then 
						last_name = hk_tbl.gameobj_name
						imgui.text(last_name)
					end
					imgui.text("    ")
					imgui.same_line()
					hk_tbl:display_imgui_button()
				end
				imgui.tree_pop()
			end
			if next(old_deferred_calls) and imgui.tree_node("Old Deferred Calls") then
				if imgui.button("Clear") then 
					old_deferred_calls = {}
				end
				read_imgui_element(old_deferred_calls)
				imgui.tree_pop()
			end
			imgui.tree_pop()
		end
		
		if not _G.search and imgui.tree_node("Table Settings") then 
			changed, SettingsCache.max_element_size = imgui.drag_int("Elements Per Grouping", SettingsCache.max_element_size, 1, 10, 1000); csetting_was_changed = csetting_was_changed or changed
			changed, SettingsCache.always_update_lists = imgui.checkbox("Always Update Lists", SettingsCache.always_update_lists); csetting_was_changed = csetting_was_changed or changed 
			
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
	
	if  next(Collection) and imgui.tree_node("Collection") then 
		changed, SettingsCache.detach_collection = imgui.checkbox("Detach", SettingsCache.detach_collection)
		imgui.same_line()
		show_collection()
		imgui.tree_pop()
	end
	
	if special_changed or (SettingsCache.load_settings and (csetting_was_changed or random(255))) then
		json.dump_file("EMV_Engine\\SettingsCache.json", jsonify_table(SettingsCache))
	end
end)

--These functions available by require() ------------------------------------------------------------------------------------------
local EMV = {
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
	convert_color_float_to_byte = convert_color_float_to_byte,
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
	change_multi = change_multi,
	show_imgui_mat = show_imgui_mat,
	is_unique_name = is_unique_name,
	is_unique_xform = is_unique_xform,
	look_at = look_at,
	offer_grab = offer_grab,
	add_resource_to_cache = add_resource_to_cache,
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
}

return EMV