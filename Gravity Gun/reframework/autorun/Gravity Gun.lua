--RE Gravity Gun by alphazomega
--Based on original gravity gun script by praydog
--June 26, 2022
--if true then return end
log.info("initializing Gravity Gun")
log.debug("initializing Gravity Gun")
local EMV = require("EMV Engine")

----------------------------------------------------------------------------------------------------------[[GLOBALS]]
local game_name = reframework.get_game_name()

--types
local guimaster_type = sdk.find_type_definition(sdk.game_namespace("gui.GUIMaster"))
local inputsystem = sdk.get_managed_singleton(sdk.game_namespace("InputSystem"))
local inputsystem_typedef = sdk.find_type_definition(sdk.game_namespace("InputSystem"))
local contact_point_typedef = sdk.find_type_definition("via.physics.ContactPoint")
local rigid_body_set_typedef = sdk.find_type_definition("via.dynamics.RigidBodySet")
local d_contact_point_typedef
local rigid_body_id_typedef

--singletons
local scene_manager = sdk.get_native_singleton("via.SceneManager")
local via_physics_system = sdk.get_native_singleton("via.physics.System")
local via_dynamics_system = sdk.get_native_singleton("via.dynamics.System")
local via_dynamics_system_typedef = sdk.find_type_definition("via.dynamics.System")
local via_physics_system_typedef = sdk.find_type_definition("via.physics.System")
local inventorymanager = sdk.get_managed_singleton(sdk.game_namespace("InventoryManager")) or  sdk.get_managed_singleton(sdk.game_namespace("gamemastering.InventoryManager"))
local playermanager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager")) or sdk.get_managed_singleton("snow.player.PlayerManager")
local via_app = sdk.get_native_singleton("via.Application")

--RE methods
local compounder_request_bake_method = sdk.find_type_definition("via.physics.StaticCompoundChildren"):get_method("requestBake")
local cast_ray_method = sdk.find_type_definition("via.physics.System"):get_method("castRay(via.physics.CastRayQuery, via.physics.CastRayResult)")
local d_cast_ray_method

local has_dynamics = false
if via_dynamics_system_typedef then
	has_dynamics = true
	d_cast_ray_method = via_dynamics_system_typedef:get_method("castRay(via.dynamics.RayCastQuery, via.dynamics.RayCastResult)")
	d_contact_point_typedef = sdk.find_type_definition("via.dynamics.ContactPoint")
	rigid_body_id_typedef = sdk.find_type_definition("via.dynamics.RigidBodyId")
end

local filter_info = nil

--global variables
scene = (scene_manager and sdk.call_native_func(scene_manager, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene"))
touched_gameobjects = {}
go = nil

--variables
last_grabbed_object = nil
last_impact_pos = Vector4f.new(0, 0, 0, 0)

local grav_objs = {}
local d_grav_objs = {}
local active_objects = EMV.active_objects
local resetted_objects = {}
local initial_positions = {}

local next = next
local ipairs = ipairs
local pairs = pairs
local tics = 0
local toks = 0
local player = nil 
local changed 
local try, out
local new_vector4 = Vector4f.new(0, 0, 0, 0)
local new_vector3 = Vector3f.new(0, 0, 0)
local new_mat4 = Matrix4x4f.new(Vector4f.new(1, 0, 0, 0), Vector4f.new(0, 1, 0, 0), Vector4f.new(0, 0, 1, 0), Vector4f.new(0, 0, 0, 1))
local last_game_object_pos = Vector4f.new(0, 0, 0, 0)
local last_colliders_pos = nil
local last_collidable = nil
local last_contact_point = nil
local grab_distance = 1.0
local camera_forward = nil
local last_camera_matrix = Matrix4x4f.new()
local neg_last_camera_matrix = Matrix4x4f.new()

GGSettings = {}
GGSettings.load_json = false
GGSettings.block_input = false
GGSettings.action_monitor = false
GGSettings.force_functions = (isMHR and true) or false
GGSettings.show_transform = true
GGSettings.prefer_rigid_bodies = (isRE2 or isRE3) and true
GGSettings.wanted_layer = -1
GGSettings.wanted_mask_bits = (isMHR and 10) or 2 --1?
GGSettings.forced_funcs_data = {}

local wants_rigid_bodies = false
local loaded_EMV = false
local current_layer = GGSettings.wanted_layer
local d_current_layer = GGSettings.wanted_layer
local reset_objs = false
local was_just_disabled = false
local is_middle_mouse_down = false
local is_middle_mouse_released = false
local was_middle_mouse_released = false
local is_right_mouse_down = false
local is_left_mouse_down = false
local is_left_mouse_released = false
local is_v_key_released = false
local is_alt_key_down = false
local is_f_key_down = false
local is_z_key_down = false
local is_r_key_down = false
local is_calling_transform_funcs = false
local is_calling_hooked_function = false
local write_transforms = true
local show_ten_closest = false
local god_mode = false
local toggled = false
local current_contact_points = 0
local d_current_contact_points = 0
local sort_closest_optional_limit
local sort_closest_optional_max_distance

local saved_xforms = {}
local saved_lights = {}
local spawned_lights = {}
local collected_objects = {}
local shown_transforms = {}
local active_objects = {}
local width = EMV.statics.width
local height = EMV.statics.height


--table.insert(GGSettings.ray_layers_tables.re3, )
--Collision layers from which the gravity gun samples for each game:
GGSettings.ray_layers_tables = {
	["re2"] = 		{0, 1, 4, 5, 6, 9, 10, 11, 12, 13, 15, 16, 17, 19, 20, 22, 21, 23, 24 , 27, 28, 29, 30, 31, 32},
	["re3"] =		{0, 1, 4, 5, 6, 9, 10, 11, 12, 13, 15, 16, 17, 19, 20, 22, 21, 23, 24 , 27, 28, 29, 30, 31, 32},
	["re7"] =		{0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24 , 25, 26, 27, 28, 29, 30, 31, 32},
	["mhrise"] =	{0, 1, 3, 4, 5, 6, 8, 9, 10, 13, 14, 15, 17, 20, 21, 22, 23, 24 , 25, 26, 27, 28, 29, 30, 31, 32},
	["re8"] =		{1, 4, 5, 6, 9, 10, 11, 12, 13, 15, 16, 17, 20, 22, 21, 23, 24, 27, 28, 29, 30, 31, 32},
	["dmc5"] =		{1, 2, 3, 4, 5, 6, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24 , 25, 26, 27, 28, 29, 30, 31, 32}
}

----------------------------------------------------------------------------------------------------------[[REMgdObj Functions]]

local GameObject = EMV.GameObject
local ChainNode = EMV.ChainNode
local ChainGroup = EMV.ChainGroup
local Material = EMV.Material
local REMgdObj = EMV.REMgdObj
local BHVT = EMV.BHVT
local ImguiTable = EMV.ImguiTable

local bool_to_number = EMV.bool_to_number
local number_to_bool = EMV.number_to_bool
local cog_names = EMV.cog_names

local random = EMV.random
local random_range = EMV.random_range
local read_imgui_object = EMV.read_imgui_object
local read_imgui_pairs_table = EMV.read_imgui_pairs_table
local read_imgui_element = EMV.read_imgui_element
local create_REMgdObj = EMV.create_REMgdObj
local mouse_state = EMV.mouse_state
local kb_state = EMV.kb_state
local get_mouse_device = EMV.get_mouse_device 
local get_kb_device = EMV.get_kb_device
local update_mouse_state = EMV.update_mouse_state
local update_keyboard_state = EMV.update_keyboard_state
local merge_indexed_tables = EMV.merge_indexed_tables
local merge_tables = EMV.merge_tables
local find_index = EMV.find_index
local jsonify_table = EMV.jsonify_table
local orderedPairs = EMV.orderedPairs
local orderedNext = EMV.orderedNext
local split = EMV.split
local Split = EMV.Split
local reverse_table = EMV.reverse_table
local vector_to_table = EMV.vector_to_table
local magnitude = EMV.magnitude
local mat4_scale = EMV.mat4_scale
local write_vec34 = EMV.write_vec34
local read_vec34 = EMV.read_vec34
local read_mat4 = EMV.read_mat4
local write_mat4 = EMV.write_mat4
local trs_to_mat4 = EMV.trs_to_mat4
local mat4_to_trs = EMV.mat4_to_trs
local deferred_call = EMV.deferred_call
local lua_get_components = EMV.lua_get_components
local lua_find_component = EMV.lua_find_component
local can_index = EMV.can_index
local is_only_my_ref = EMV.is_only_my_ref
local is_valid_obj = EMV.is_valid_obj
local get_table_size = EMV.get_table_size
local isArray = EMV.isArray
local vector_to_string = EMV.vector_to_string
local mat4_to_string = EMV.mat4_to_string
local log_bytes = EMV.log_bytes
local log_method = EMV.log_method
local log_field = EMV.log_field
local log_transform = EMV.log_transform
local log_value = EMV.log_value
local logv = EMV.logv
local hashing_method = EMV.hashing_method
local imgui_anim_object_viewer = EMV.imgui_anim_object_viewer
local imgui_saved_materials_menu = EMV.imgui_saved_materials_menu
local mini_console = EMV.mini_console
local get_first_gameobj = EMV.get_first_gameobj
local editable_table_field = EMV.editable_table_field
local get_folders = EMV.get_folders
local search = EMV.search
local find = EMV.find
local clear_object = EMV.clear_object


----------------------------------------------------------------------------------------------------------[[UTILITY FUNCTIONS]]

local gg_default_settings = merge_tables({}, GGSettings)
local function load_settings()
	local new_settings = jsonify_table(json.load_file("GravityGunAndConsole\\GGunConsoleSettings.json"), true)
	if new_settings and new_settings.load_json then 
		GGSettings = new_settings
		for key, value in pairs(gg_default_settings) do
			if GGSettings[key] == nil then 
				GGSettings[key] = value
			end
		end
		for key, value in pairs(GGSettings) do
			if gg_default_settings[key] == nil then 
				GGSettings[key] = nil
			end
		end
	end
end
load_settings()

re.on_script_reset(function()
	for i, obj in ipairs(grav_objs) do
		obj:toggle_forced_funcs(false)
	end
	if GGSettings.load_json then 
		json.dump_file("GravityGunAndConsole\\GGunConsoleSettings.json", GGSettings)
	end
end)

local function write_transform(gameobject, translation, rotation, scale)
	is_calling_transform_funcs = true
	if not wants_rigid_bodies or gameobject.rigid_body == nil then
		if translation then gameobject.xform:call("set_Position", translation) end
		if rotation then gameobject.xform:call("set_LocalRotation", rotation) end
		if scale then gameobject.xform:call("set_LocalScale", scale) end
	end
	if gameobject.shapes then 
		local mat
		for i, shape in ipairs(gameobject.shapes) do 
			local shape_mat = shape:call("get_TransformMatrix")
			if shape_mat and shape_mat[3] ~= new_vector4 then 
				mat = mat or gameobject.xform:call("get_WorldMatrix")
				shape_mat[3] = mat[3]
				shape:call("set_TransformMatrix", shape_mat)
			end
		end
		if gameobject.components_named.Colliders then
			gameobject.components_named.Colliders:call("updatePose")
			gameobject.components_named.Colliders:call("updateNotify")
			--gameobject.components_named.Colliders:call("updateBroadphase")
			gameobject.components_named.Colliders:call("onDirty")
		end
	end
	is_calling_transform_funcs = false
end

--i'd be more willing to if I weren't so lazy if I played Rise

--Commands and cheats:
local get_player = function()
	local player = EMV.get_player()
	if player then 
		local gameobj = isMHR and player:call("get_GameObject")
		local xform = (gameobj and gameobj:call("get_Transform")) or player:call("get_Transform")
		if xform then 
			touched_gameobjects[xform] = touched_gameobjects[xform] or GameObject:new_GrabObject { gameobj=gameobj, xform=xform  }
			return touched_gameobjects[xform]
		end
	end
end

--[[local function clear_object(xform)
	EMV.clear_object(xform)
	active_objects[xform] = nil
	if last_grabbed_object and (last_grabbed_object.xform == xform) then last_grabbed_object = nil end
	if grav_objs[1] and grav_objs[1].xform == xform then grav_objs = {} end
end]]

----------------------------------------------------------------------------------------------------------[[CLASSES AND UTILITY TABLES]]

-- '"set()", "get()", table.pack(args1, args2, etc)' means use set() function to force value every frame. get() is used to restore original value when disabled.
-- Functions may have nil arguments or nil getters,  and having a 4th value means to call this function once when grabbed and not again
-- Instances not returned by "get_Components()" may be used if they are manually inserted into the GrabObject.components table
-- Uses table.pack to allow them to be run in a specific order
local fields_to_force_by_component = {

}

local funcs_to_force_by_component = {
	["via.render.Mesh"] = {
		{set="set_ForceDynamicMesh", get="get_ForceDynamicMesh", changeto={true} } --,  once=1
		,{set="set_StaticMesh", get="get_StaticMesh", changeto={false},  once=1 } 
	},
	["via.physics.Colliders"] = {
		{set="set_Static", get="get_Static", changeto={false} }
		,{set="set_Enabled", get="get_Enabled", changeto={true} }
		,{set="updatePose", changeto={} }
		,{set="updateNotify", changeto={} }
		--,{set="updateBroadphase", changeto={} }
		,{set="onDirty", changeto={} }
	},
	["via.physics.Collider"] = {
		 {set="set_Enabled", get="get_Enabled", changeto={true} }
	},
	--[[[sdk.game_namespace("GroundFixer")] = {
		--{set="setAdjustMode", get="getAdjustMode", changeto={2}, once=0 }
		{set="set_Enabled", get="get_Enabled", 	changeto={false}, once=1 }
		,{set="set_FallTime", get="get_FallTime", changeto={0.0} }
	},]]
	["via.motion.IkLeg"] = {
		{ set="set_Enabled", get="get_Enabled", changeto={false} }
	},
	[sdk.game_namespace("TerrainAnalyzer")] = {
		{set="set_Enabled", get="get_Enabled", changeto={false}, once=1 }
	},
	["via.physics.CharacterController"] = {
		{set="warp", changeto={} }
		,{set="set_OverwritePosition", get="get_OverwritePosition", changeto={false}, once=1 }
	},
	["via.dynamics.RigidBodySet"] = {
		{set="set_StateName", get="get_StateName", changeto={"DynamicStates"} }
		,{set="setStates", get="getStates", count="getStatesCount", changeto={3} }
		--,{set="set_State", get="get_State", changeto={3} }
		,{set="set_Enabled", get="get_Enabled", changeto={true}, once=1 }
	}, 
	[sdk.game_namespace("RagdollController")] = {
		{ set="set_IsStable", get="get_IsStable", changeto={false}, once=1 }
	--	,{ set="set_Status", get="get_Status", changeto={2}, once=1 } --*important!
		,{ set="set_RagdollStateName", get="get_RagdollStateName", changeto={"DynamicStates"}, once=1 }
		,{ set="set_InfiniteFallingSafetyEnabled", get="get_InfiniteFallingSafetyEnabled", changeto={false}, once=1 }
		,{ set="fixRagdoll", changeto={}, once=1 }
		,{ set="unfixRagdoll", changeto={}, once=1 } 
	},
	--["via.dynamics.RigidBodyMeshSet"] = {
	--),
	--["via.dynamics.Ragdoll"] = {
	--	{"reset", nil, {nil}, once=1}
	--	{"set_State", "get_State", {[1]=3})
	--	{"set_MotorControl", "get_MotorControl", {true}, once=1}
	--	,{"set_Enabled", "get_Enabled", {[1]=true})
	--},
}

for component_name, tbl in pairs(funcs_to_force_by_component) do 
	GGSettings.forced_funcs_data[component_name] = GGSettings.forced_funcs_data[component_name] or {enabled=true}
	for i, sub_tbl in ipairs(tbl) do
		GGSettings.forced_funcs_data[component_name][i] = GGSettings.forced_funcs_data[component_name][i] or {enabled=true}
	end
end

local ForcedValue = {
	
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o.toggled = args.toggled or false
		o.object = args.object
		o.field_name = args.field_name
		o.method = args.method
		o.get_method = args.get_method
		o.count_method = args.count_method
		o.initial_values = args.initial_values or {}
		o.changed_values = args.changed_values or {}
		o.typedef = args.typedef or o.object:get_type_definition()
		o.only_set_once = args.only_set_once
		o.update_count = 0
		o.name = o.method or o.field_name
        return setmetatable(o, self)
	end,
	
	update = function(self)
		if self.toggled and (self.update_count < 1 or not self.only_set_once) then --and sdk.is_managed_object(self.object) 
			if self.method then 
				if self.count_method then 
					local count = sdk.call_native_func(self.object, self.typedef, self.count_method)
					for i=0, count-1 do
						sdk.call_native_func(self.object, self.typedef, self.method, i, table.unpack(self.changed_values))
					end
				else
					sdk.call_native_func(self.object, self.typedef, self.method, table.unpack(self.changed_values))
				end
			end
			self.update_count = self.update_count + 1
		end
	end,
	
	toggle = function(self, bool)
		if bool ~= self.toggled then
			if self.field_name then
				if bool == true then 
					self.initial_values = table.pack(sdk.get_native_field(self.object, self.typedef, self.field_name))
				elseif self.initial_values[1] ~= nil then
					sdk.set_native_field(self.object, self.typedef, self.field_name, self.initial_values[1])
				end
			elseif self.method then
				if bool == true then  
					if self.get_method then 
						if self.count_method then 
							local count = sdk.call_native_func(self.object, self.typedef, self.count_method) 
							if count and count > 0 then
								self.initial_values = {}
								for i=0, count-1 do
									table.insert(self.initial_values, sdk.call_native_func(self.object, self.typedef, self.get_method, i) )
								end
							end
						else
							self.initial_values = table.pack(sdk.call_native_func(self.object, self.typedef, self.get_method))
						end
					end
				else 
					if self.initial_values[1] ~= nil and self.only_set_once ~= 0 then 
						sdk.call_native_func(self.object, self.typedef, self.method, table.unpack(self.initial_values))
					end
				end
			end
			self.update_count = 0
		end
		self.toggled = bool
	end,
}

GameObject.new_GrabObject = function(self, args, o)
	
	o = o or {}
	self = (args.xform and held_transforms[args.xform]) or GameObject:new(args, o)
	--self = (args.xform and held_transforms[args.xform] and merge_tables(held_transforms[args.xform], o, true)) or GameObject:new(args, o)
	if not self or not self.update then 
		log.info("Failed to create GameObject") 
		return nil
	end
	touched_gameobjects[self.xform] = (touched_gameobjects[self.xform] and (touched_gameobjects[self.xform] ~= self) and merge_tables(self, touched_gameobjects[self.xform], true)) or self
	self = touched_gameobjects[self.xform]
	
	log.info("Creating " .. self.name)
	self.collidable 			= args.collidable		
	self.rigid_body 			= args.rigid_body		or has_dynamics and self.gameobj:call("getComponent(System.Type)", sdk.typeof("via.dynamics.RigidBodySet"))
	self.contact_pt 			= args.contact_pt 	
	self.pos 					= args.pos				or self.xform:call("get_Position")
	self.rot 					= args.rot				or self.xform:call("get_Rotation")
	self.scale 					= args.scale			or self.xform:call("get_LocalScale")
	self.init_pos 				= args.init_pos 		or self.pos 
	self.init_rot 				= args.init_rot 	 	or self.xform:call("get_LocalRotation")--self.rot
	self.init_rot_false			= args.init_rot_false 	or self.init_rot
	self.init_scale 			= args.init_scale 	 	or self.scale
	self.init_worldmat			= args.init_worldmat	or initial_positions[self.xform] or self.xform:call("get_WorldMatrix") --or read_mat4(self.xform, isRE7 and 0x90 or 0x80, true)
	self.cam_pos	 			= args.cam_pos 			or last_camera_matrix[3]
	self.impact_pos				= args.impact_pos 	 	or self.pos --self.cam_pos --new_vector4
	self.cam_forward 			= args.cam_forward 		or last_camera_matrix[2] * -1.0
	self.init_offset 			= args.init_offset 		or self.impact_pos and (self.impact_pos - self.pos) or new_vector4
	self.dist  					= args.dist				or self.init_offset:length()
	self.forced_funcs   		= args.forced_funcs	 	or {}
	self.forced_fields 			= args.forced_fields	or {}
	self.ray_layer 				= args.ray_layer 		or -1
	self.num_contacts			= args.num_contacts		or 0
	self.multiplier				= args.multiplier 		or 1.0	
	self.center 				= args.center			or (self.cog_joint and self.cog_joint:call("get_BaseLocalPosition")) or self.center
	self.init_neg_cam_rot  		= args.init_neg_cam_rot	or neg_last_camera_matrix[2]:to_quat()
	self.initflatncam_rot 		= args.initflatncam_rot or Vector3f.new(neg_last_camera_matrix[2].x, 0.0, neg_last_camera_matrix[2].z):normalized():to_quat()
	self.shapes 				= args.shapes			or {}
	self.colliders 				= args.colliders		
	self.root_joint 			= args.root_joint		or self.xform:call("getJointByName", "root")
	self.folder 				= args.folder			or self.gameobj:call("get_Folder")
	self.hp 					= args.hp				
	self.think 					= args.think			
	self.do_reset 				= args.do_reset 		or 0
	self.invalid 				= args.invalid
	
	initial_positions[self.xform] = initial_positions[self.xform] or self.init_worldmat
	--if self.mesh and not self.aabb then self.aabb = self.mesh:call("get_ModelLocalAABB")  end
	if not self.center then 
		local aabb = self.mesh and self.mesh:call("get_ModelLocalAABB")
		self.center = aabb and aabb:call("getCenter") or Vector3f.new(0, 0.75, 0)
	end
	
	--if self.folder then self.scene = self.scene or self.folder:call("get_Scene") end
	if isRE2 or isRE3 then 
		self.hp = self.hp or self.gameobj:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("EnemyHitPointController"))) or self.gameobj:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("HitPointController")))
	end
	
	if self.components then 
		if tostring(self.components):find("Array") then 
			self.components = self.components:get_elements()
		end
		for i, comp in ipairs(self.components) do 
			local typedef = comp:get_type_definition()
			local comp_name = typedef:get_name()
			if not isRE7 and #self.shapes == 0 and typedef:is_a("via.physics.Colliders") then  --
				for c = 0, comp:call("get_NumColliders") do 
					local collider = comp:call("getColliders", c)
					if collider then 
						self.colliders = self.colliders or {}
						table.insert(self.components, collider)
						table.insert(self.colliders, collider)
						local shape = collider:call("get_Shape")
						local t_shape = collider:call("get_TransformedShape")
						table.insert(self.shapes, t_shape)--table.pack(shape, t_shape))
					end
				end
			end
			if not self.think and comp_name:find("Think") then 
				self.think = comp
			end
		end
	end
	
	if isRE7 and (self.impact_pos ~= new_vector4 and (self.impact_pos - self.pos):length() > 10) then --not string.find(self.name, "pl%d%d") and not string.find(self.name, "em%d%d") and --shit
		self.invalid = true
	end
	if isDMC and self.ray_layer == 18 then 
		self.invalid = true
	end
	if self.invalid == nil and (string.find(self.name, "errain")  or self.name == "StayRequester" or string.match(self.name, "^st[0-9].") or string.match(self.name, "^x[0-9].z[0-9].") or string.match(self.name, "^m[0-9].*Zone")) then
	--or (isRE7 and not self.gameobj:call("getComponent(System.Type)", sdk.typeof("via.motion.Motion"))) then 
		self.invalid = true
	end
	
	if go and (self.xform == go.xform) then go = self end --update other vars
	if grav_objs[1] and (self.xform == grav_objs[1].xform) then grav_objs[1] = self end
	if last_grabbed_object and (self.xform == last_grabbed_object.xform) then last_grabbed_object = self end
	
	return self
end

GameObject.clear_GrabObject = function(self, xform)
	xform = xform or self.xform
	--log.info("Clearing GrabObject " .. (xform and xform:get_address() or ""))
	touched_gameobjects[xform] = nil
	active_objects[xform] = nil
	if last_grabbed_object and (last_grabbed_object.xform == xform) then last_grabbed_object = nil end
	if grav_objs[1] and grav_objs[1].xform == xform then grav_objs = {} end
	if go and (go.xform == xform) then go = nil end
	if player and player.xform == xform then player = nil end
end

GameObject.update_GrabObject = function(self, is_known_valid)
	
	if is_known_valid or self:update() then
		self.active = (not not active_objects[self.xform]) or nil	
--[[
	if self.packed_xform and self.packed_xform[1] then -- and self.packed_xform[1] ~= self.pos then 
		if cutscene_mode and self.cog_joint  then 
			--local pos = self.cog_joint:call("get_Position")
			--local rot = self.cog_joint:call("get_Rotation")
			--local scale = self.cog_joint:call("get_LocalScale")
			local pos = self.cog_joint:call("get_LocalPosition")
			local rot = self.cog_joint:call("get_LocalRotation")
			if self.active then
				self.cog_joint:call("set_Position", self.packed_xform[1] + self.center)
				self.cog_joint:call("set_Rotation", self.packed_xform[2])
				--self.cog_joint:call("set_LocalScale", self.packed_xform[3])
				self.last_cog_offset = {
					self.cog_joint:call("get_LocalPosition") - pos,
					self.cog_joint:call("get_LocalRotation") * rot,
				}
			else
				--local transformed_pos = mathex:call("transform(via.vec3, via.Quaternion)", pos, Quaternion.new(0,0,-1,0)) --test
				if not cutscene_mode.paused then
					self.cog_joint:call("set_LocalPosition", self.last_cog_offset[1] + pos)
					self.cog_joint:call("set_LocalRotation", self.last_cog_offset[2] * rot:inverse())
				--	self.cog_joint:call("set_Position", pos + self.last_cog_offset[1])
				--	self.cog_joint:call("set_Rotation", rot:inverse() * self.last_cog_offset[2]) -- 
				else
					self.cog_joint:call("set_Position", self.packed_xform[1] + self.center)
					self.cog_joint:call("set_Rotation", self.packed_xform[2])
				--	write_transform(self, self.packed_xform[1], self.packed_xform[2], self.packed_xform[3])
				end
				--self.cog_joint:call("set_LocalScale", scale + self.last_cog_offset[3])
			end
		else
			write_transform(self, self.packed_xform[1], self.packed_xform[2], self.packed_xform[3])
			self.packed_xform = nil
		end
	end
]]
		if self.packed_xform and self.packed_xform[1] then -- and self.packed_xform[1] ~= self.pos then 
			if cutscene_mode and self.cog_joint  then 
				local pos = self.cog_joint:call("get_Position")
				local rot = self.cog_joint:call("get_Rotation")
				if self.active then
					self.last_cog_offset = {
						((self.packed_xform[1] + self.center) - pos), 
						(self.packed_xform[2] * rot),
					}
					self.cog_joint:call("set_Position", self.packed_xform[1] + self.center)
					self.cog_joint:call("set_Rotation", self.packed_xform[2])
				else
					self.cog_joint:call("set_Position", pos + self.last_cog_offset[1])
					self.cog_joint:call("set_Rotation", rot:inverse() * self.last_cog_offset[2])
				end
			else
				write_transform(self, self.packed_xform[1], self.packed_xform[2], self.packed_xform[3])
				self.packed_xform = nil
			end
		end
		if self.active then 
			if self.components_named.GroundFixer then
				self.components_named.GroundFixer:call("set_FallTime", 0.0)
			end
		end
		
		self.pos = self.xform:call("get_Position")
		self.rot = self.xform:call("get_Rotation")
		self.scale = self.xform:call("get_LocalScale")
		
		self:update_funcs()
		if self.is_forced and self.do_reset <= 0 and not active_objects[self.xform] then 
			self:toggle_forced_funcs(false)
		end
	else
	--	clear_object(self.xform) 
	end
end

GameObject.toggle_forced_funcs = function(self, bool) 
	if GGSettings.force_functions then
		is_calling_hooked_function = true
		if self.is_forced == bool or self.invalid then 
			return 
		end 
		self.is_forced = bool 
		if self.is_forced == true then
			--[[--only gravity gun objects should have reached this part, so give them collidables and rigid body components if they didnt have them:
			--disabled because it causes internal game exceptions that make testing very hard
			if not self.gameobj:call("getComponent(System.Type)", sdk.typeof("via.physics.Colliders")) then 
				local colliders = self.gameobj:call("createComponent", sdk.typeof("via.physics.Colliders"))
				colliders:call(".ctor")
				colliders:add_ref()
				local new_collider = sdk.create_instance("via.physics.Collider")
				new_collider:call(".ctor")
				new_collider:add_ref()
				local userdata = sdk.create_instance("via.physics.UserData")
				userdata:call(".ctor")
				userdata:add_ref()
				new_collider:call("set_UserData", userdata)
				colliders:call("setCollidersCount", 1)
				colliders:call("setColliders", 0, new_collider)
			end
			if self.center and not self.gameobj:call("getComponent(System.Type)", sdk.typeof("via.dynamics.RigidBodySet")) then --self.root_joint
				self.rigid_body = self.gameobj:call("createComponent", sdk.typeof("via.dynamics.RigidBodySet"))
				self.rigid_body:write_dword(0x48, 1)
				self.rigid_body:call("setStatesCount", 1)
				self.rigid_body:call("set_StateName", "DynamicStates")
				self.rigid_body:call("setBlendWeights", 0, 1.0)
				self.rigid_body:call("setBlendWeightsCount", 1)
				self.rigid_body:call("setBlendWeights", 0, 1.0)
				self.rigid_body:call("setStateHash", 3416527488) 
				self.rigid_body:call("set_Position", 0, self.center)
				--self.rigid_body:call("set_Rotation", 0, self.root_joint:call("get_Rotation"))
				if self.shapes and self.shapes[1] then 
					self.rigid_body:call("set_Shape", 0, self.shapes[1][1])
				end
				self.rigid_body:call("set_Layer", 0)
				self.rigid_body:call("setStates", 0, 3)
				self.rigid_body:call("set_State", 0)
			end]]
			
			self.forced_fields = {}
			self.forced_funcs = {}
			self.components = self.gameobj:call("get_Components")
			self.components = (self.components and self.components.get_elements and self.components:get_elements()) or lua_get_components(self.xform)
			for i, component in ipairs(self.components or {}) do 
				local type_definition = component:get_type_definition()
				local component_name = type_definition:get_full_name()
				if funcs_to_force_by_component[component_name] and GGSettings.forced_funcs_data[component_name].enabled then 
					for j, func in ipairs(funcs_to_force_by_component[component_name]) do
						if GGSettings.forced_funcs_data[component_name][j].enabled then
							local new_func = ForcedValue:new { object=component, method=func.set, get_method=func.get, typedef=type_definition, changed_values=func.changeto, only_set_once=func.once, count_method=func.count }
							new_func:toggle(true)
							table.insert(self.forced_funcs, new_func)
						end
					end
				end
			end
		elseif self.is_forced == false then
			for i, field in ipairs(self.forced_fields) do 
				field:toggle(false)
			end
			for i, func in ipairs(self.forced_funcs) do 
				func:toggle(false)
			end
		end
		is_calling_hooked_function = false
	end
end

GameObject.update_funcs = function(self)
	if toggled and self.forced_funcs and (self.is_forced or self.do_reset > 0) then
		for i, func in ipairs(self.forced_funcs) do
			func:update()
		end
		for i, field in ipairs(self.forced_fields) do
			field:update()
		end
		if self.do_reset > 0 then self.do_reset = self.do_reset - 1 end
	end
end


--local wrote_transform
--[[local function on_update_transform(transform)
	local obj = touched_gameobjects[transform]
	wrote_transform = nil
	if obj and obj.packed_xform then
		log.info("Writing ")
		write_transform(obj, obj.packed_xform[1], obj.packed_xform[2], obj.packed_xform[3])
		obj.cog_joint = (obj.cog_joint and is_valid_obj(obj.coj_joint)) and obj.cog_joint
		if obj.cog_joint and obj.center_offset then 
			log.info("Writing cog ")
			obj.cog_joint:call("set_LocalPosition", obj.center_offset)
		end
		obj.packed_xform = nil
		if obj.do_reset <= 0 and (is_z_key_down or reset_objs) then 
			obj:toggle_forced_funcs(false)
		end
		wrote_transform = true
	end
end]]


--[[
local function sample_cams()
	local player = get_player()
	if player and cam_system and cams and tics % 120 == 0 then 
		local cam = cams[random_range(1, #cams)]
		local cam_xform = cam:call("get_GameObject"):call("get_Transform")
		while (cam_xform:call("get_Position") - player.pos):length() > 15 do
			cam = cams[random_range(1, #cams)]
			cam_xform = cam:call("get_GameObject"):call("get_Transform")
		end
		cam_system:call("setCurrentFixedCamera", cam:call("get_GameObject"))
	end
end

cam_folder = scene and scene:call("findFolder", "FixCamera_RPD")
cam_folder = cam_folder and cam_folder:call("activate")

function setup_cams()
	local cams_list = scene:call("findComponents(System.Type)", sdk.typeof("app.ropeway.FixCameraIdentifier"))
	cams = cams_list:get_elements()
	local gates_list = scene:call("findComponents(System.Type)", sdk.typeof("app.ropeway.CameraGateController"))
	gates = gates_list:get_elements()
	cam_system = scene:call("findComponents(System.Type)", sdk.typeof("app.ropeway.camera.CameraSystem"))
	if cam_system then 
		cam_system = cam_system:get_elements()[1]
		
		for i, cam in ipairs(cams) do 
			cam:call("set_Enabled", true)
			--cam_system:call("mountFixedCamera", cam)
		end
		for i, gate in ipairs(gates) do 
			gate:call("set_Enabled", true)
		end
		cam_system:call("set_MountedFixCameraList", cams_list)
		--cam_system:call("set_MountedCameraGateList", gates_list)
		for i, cam in ipairs(cams) do 
			cam_system:call("mountFixedCamera", cam)
		end
		--cam_system:call("setCurrentFixedCamera", cams[1]:call("get_GameObject")) --sdk.get_primary_camera():call("get_GameObject")) --
		cam_system:call("switchFixedCamera")
	end
end
]]

function grab(object_or_component, args)
	
	local xform = (object_or_component.components and object_or_component.xform) or object_or_component:call("get_Transform") or object_or_component:call("get_GameObject"):call("get_Transform")
	if not xform then return end
	
	args = args or {}
	new_args = merge_tables({xform=xform, rot=not args.init_offset and last_camera_matrix:to_quat(), invalid=false, dist=args.dist or 3}, args, true)
	local game_object = GameObject:new_GrabObject(new_args)
	--if not game_object.components or tostring(game_object):find("sol%.RE") then
		--local gameobj = object_or_component:call("get_GameObject") or object_or_component
		--local xform = gameobj and gameobj:call("get_Transform")
	--	game_object = GameObject:new_GrabObject{ gameobj=(object_or_component:call("get_GameObject") or object_or_component), rot=not init_offset and last_camera_matrix:to_quat(), invalid=false, dist=3 }
	--end
	
	if game_object.xform:call("get_SameJointsConstraint") then
		local parent, ctr, temp = game_object.xform, 0
		while parent do 
			temp = parent
			parent = parent:call("get_Parent")
		end
		game_object = touched_gameobjects[temp] or GameObject:new_GrabObject{xform=temp}
	end
	game_object.gameobj:write_byte(0x14, 1) --updateself
	game_object.gameobj:write_byte(0x12, 1)	--update	
	game_object.gameobj:write_byte(0x13, 1)	--draw
	
	if not is_alt_key_down and (last_grabbed_object and last_grabbed_object.xform == game_object.xform) then --ungrab
		game_object:toggle_forced_funcs(false)
		toggled = false
		active_objects = {}
		was_just_disabled = true
		last_grabbed_object = nil
		--[[if forced_mode and game_object.forced_mode_center then 
			game_object.forced_mode_center = game_object:call("get_WorldMatrix")
		end]]
	else
		grav_objs, active_objects = {}, {}
		last_grabbed_object, active_objects[game_object.xform], grav_objs[1] = game_object, game_object, game_object, game_object
		game_object.init_offset = args.init_offset or game_object.center or Vector3f.new(0,0,0)
		game_object.impact_pos = game_object.pos + game_object.init_offset
		last_contact_point = game_object.contact_pt
		game_object:toggle_forced_funcs(true)
		grab_distance = game_object.components_named["SpotLight"] and 0.1 or 3
		toggled = true
	end
	
	return game_object
end

----------------------------------------------------------------------------------------------------------[[FUNCTIONS]]

local function reset_object(game_object, parent)
	if not resetted_objects[game_object.xform] then 
		if is_valid_obj(game_object.xform) then 
			if parent or game_object.multiplier < 1.0 and (player == nil or player.xform ~= game_object.xform) then
				resetted_objects[game_object.xform] = game_object
				active_objects[game_object.xform] = game_object
				game_object.multiplier = 1.0
				local init_pos, init_rot, init_scale = mat4_to_trs(game_object.init_worldmat)
				if parent then 
					game_object.xform:call("set_Parent", nil)
					game_object.xform:call("set_Parent", parent.xform)
				else
					game_object.do_reset = 3
					game_object:toggle_forced_funcs(true)
					game_object.packed_xform = table.pack(init_pos, init_rot, init_scale)
					write_transform(game_object, init_pos, init_rot, init_scale)
				end
				for i, child in ipairs(game_object.children or {}) do 
					reset_object(child, game_object)
				end
			end
		elseif game_object.xform then 
			touched_gameobjects[game_object.xform] = nil
		end
	end
end


----------------------------------------------------------------------------------------------------------[[HOOKED FUNCTIONS]]

local function on_pre_set_transform(args)
	if toggled and write_transforms and not is_calling_transform_funcs then
		local transform = sdk.is_managed_object(args[1]) and sdk.to_managed_object(args[1])
		if sdk.is_managed_object(transform) and active_objects[transform]  then
			return sdk.PreHookResult.SKIP_ORIGINAL
		end
	end
end

local count = 0
local function on_pre_func_skip(args)
	count = count + 1
	if toggled then 
		return sdk.PreHookResult.SKIP_ORIGINAL
	end
end

local function on_pre_func(args)

end

local function on_pre_func_skip_always(args)
	return sdk.PreHookResult.SKIP_ORIGINAL
end

local function on_post_func_skip(retval)
    return retval
end

local counter = 0 

local function on_pre_test(args)	
	counter = counter + 1
end

local function on_pre_generic_hook(args)
	if is_calling_hooked_function == false then 
		local obj = hooked_funcs[sdk.to_managed_object(args[2])]
		if not obj or not obj.exclusive_hook then 
			return sdk.PreHookResult.SKIP_ORIGINAL
		else
			obj.count = obj.count + 1
			obj.args = args
		end
	end
end

local function on_post_generic_hook(retval)
	return retval
end

local function on_pre_forced_func(args)
	if toggled and not is_calling_hooked_function then
		local try, object = pcall(sdk.to_managed_object, args[1])
		if try and object and is_valid_obj(object) then
			local try, go = pcall(sdk.call_object_func, object, "get_GameObject")
			if try and go and active_objects[go:call("get_Transform")] then 
				return sdk.PreHookResult.SKIP_ORIGINAL
			end
		end
	end
end


--[[args_table = {}

local function on_pre_destroy_gameobj(args)
	if not is_calling_hooked_function then 
		--counter = counter + 1
		--args_table = args
		--log.debug("4 " .. tostring(sdk.is_managed_object(sdk.to_managed_object(args[4]))))
		--log.debug("2 " .. tostring(sdk.is_managed_object(sdk.to_managed_object(args[3])))) 
		--log.debug("1 " .. tostring(sdk.is_managed_object(sdk.to_managed_object(args[1])))) 
		--spawned_prefabs[sdk.to_managed_object(args[3]):call("get_Transform")] then 
		--return sdk.PreHookResult.SKIP_ORIGINAL
	end
end

local function on_post_forced_func(retval)
	return retval
end
]]
--[[

local function on_pre_resource_path(args)	
	local try, object = pcall(sdk.to_managed_object, args[2])
	if try and object then 
		local name = object:get_type_definition():get_full_name()
		resource_exts[name] = object:call("ToString()"):match("^.+%.(.+)%]")
	end
end

local function on_post_resource_path(retval)
	if res_obj then
		
		res_obj = nil
	end
	return retval
end

sdk.hook(sdk.find_type_definition("via.ResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.SceneResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.PrefabResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.nnfc.nfp.NFPResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.areamap.AreaMapResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.areamap.AreaQueryResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.autoplay.AutoPlayResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.movie.MovieResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.browser.BrowserConfigHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.puppet.PuppetResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.effect.EffectResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.effect.EffectCollisionResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.effect.lensflare.LensflareResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.uvsequence.UVSequenceResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.BankResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.ContainableResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.EventListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.MemorySettingsResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.PlugInsResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.PackageResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SetStateListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.FreeAreaListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.BankInfoResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.BankListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.ContainerListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.FloatEnumConverterListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.GameParameterListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.GetGameParameterListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SetGameParameterListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.GlobalUserVariablesSetStateListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.JointAngleListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.JointMaterialListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.JointRotationListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.MaterialObsOclListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.MaterialSwitchListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.MarkerStateListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.MotionSwitchListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.PackageListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.RagdollListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.RigidBodyListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SpaceDeterminationAuxSendsListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SpaceDeterminationFeatureListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SpaceDeterminationStateListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.StateListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SwitchListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.SwitchByNameListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.TriggerListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.TwistAngleListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.VelocityListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.JointMoveListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.DistanceListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.FootContactListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.EncodedMediaResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.TargetOperationTriggerSettingsResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.wwise.TargetOperationTriggerResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.fsm.FsmResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.timeline.TimelineBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.timeline.ClipResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.timeline.TimelineResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.timeline.UserCurveResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.timeline.UserCurveListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.userdata.UserVariablesResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.PSOPatchHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.ShaderResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.MasterMaterialResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.TextureResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.RenderTargetTextureResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.SSSProfileResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.LodResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.MeshResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.MeshMaterialResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.IESLightResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.SparseShadowTreeHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.ProbesResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.SceneStructureResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.render.LightProbesResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.network.AutoSessionRulesResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.network.NetworkConfigHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionBlendResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionTreeResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionListBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.JointMapResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionBankBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionBankResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionCameraBankResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionFsmResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionFsm2ResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.ChainResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.SkeletonResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.FbxSkeletonResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.JointConstraintsResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.DevelopRetargetResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.IkDamageActionResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionCameraResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.motion.MotionCameraListResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.hid.VibrationResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionDefinitionResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionFilterResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionMaterialResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionMeshResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.CollisionSkinningMeshResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.RequestSetColliderResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.physics.TerrainResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.navigation.AIMapResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.navigation.NavigationFilterSettingResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.navigation.AIMapAttributeResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.GUISoundResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.BaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.GUIResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.GUIConfigResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.OutlineFontResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.IconFontResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.TextAnimationResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.gui.MessageResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.RigidBodySetResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.RagdollResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.RagdollControllerResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.RigidBodyMeshResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.DefinitionResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.GpuClothResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.dynamics.GpuCloth2ResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.behaviortree.BehaviorTreeBaseResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.behaviortree.FSMv2TreeResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
sdk.hook(sdk.find_type_definition("via.behaviortree.BehaviorTreeResourceHolder"):get_method("ToString()"), on_pre_resource_path, on_post_resource_path)
]]


if not isRE7 then 
	sdk.hook(sdk.find_type_definition("via.Transform"):get_method("set_Position"), on_pre_set_transform, on_post_func_skip)
	sdk.hook(sdk.find_type_definition("via.Transform"):get_method("set_LocalPosition"), on_pre_set_transform, on_post_func_skip)
	sdk.hook(sdk.find_type_definition("via.Transform"):get_method("set_Rotation"), on_pre_set_transform, on_post_func_skip)
	sdk.hook(sdk.find_type_definition("via.Transform"):get_method("set_LocalScale"), on_pre_set_transform, on_post_func_skip)
	--sdk.hook(sdk.find_type_definition("via.GrabObject"):get_method("destroy(via.GrabObject)"), on_pre_destroy_gameobj, on_post_func_skip, false)
end

--[[
if isRE2 then 
	for typedef_name, functions in pairs(funcs_to_force_by_component) do 
		local typedef = sdk.find_type_definition(typedef_name)
		for f, packed_func in ipairs(functions) do 
			if not packed_func.once then 
				pcall( function() sdk.hook(typedef:get_method(packed_func.set), on_pre_forced_func, on_post_func_skip) end)
			end
		end
	end
end]]
--[[
function create_searchcolinfo()
	local searchcolinfo = sdk.create_instance("via.physics.System.SearchCollisionInfo"):add_ref()
	searchcolinfo:call(".ctor")
	return searchcolinfo
end

function create_rigid_body()
	local construction_info = sdk.find_type_definition("via.dynamics.RigidBody.ConstructionInfo"):get_field("Default"):get_data()
	local main_world = sdk.call_native_func(via_dynamics_system, via_dynamics_system_typedef, "get_MainWorld") --via_dynamics_system_typedef:get_method("get_MainWorld"):call() --
	--main_world:call("set_RigidBodyCapacity", main_world:call("get_RigidBodyCapacity")+1)
	--local new_shape = ValueType.new(sdk.find_type_definition("via.dynamics.Shape"))
	--local new_rigid = via_dynamics_system_typedef:get_method("createRigidBody"):call(nil, "createRigidBody", construction_info, main_world)
	local try, new_rigid = pcall(sdk.call_native_func, via_dynamics_system, via_dynamics_system_typedef, "createRigidBody", construction_info, main_world)
	--new_rigid = via_dynamics_system_typedef:get_method("createRigidBody"):call(nil, "createRigidBody", construction_info, main_world)
	return new_rigid
end]]


----------------------------------------------------------------------------------------------------------[[GRAVITY GUN]]

local function cast_rays(ray_method, ray_query)
	
	local gameobjects = {}
	local ray_layers_table = GGSettings.ray_layers_tables[game_name]  --auto mode
	if GGSettings.wanted_layer ~= -1 then ray_layers_table = {GGSettings.wanted_layer} end  --manual mode
	
	ray_query = ray_query or sdk.create_instance("via.physics.CastRayQuery"):add_ref()
	ray_query:call("clearOptions")
	ray_query:call("enableAllHits")
	ray_query:call("enableNearSort")
	local filter_info = ray_query:call("get_FilterInfo")
	filter_info:call("set_Group", 0)
	filter_info:call("set_MaskBits", GGSettings.wanted_mask_bits)
	
	if ray_method == cast_ray_method then 
		
		local ray_result = sdk.create_instance("via.physics.CastRayResult"):add_ref()
		
		for i, ray_layer in ipairs(ray_layers_table) do
			filter_info:call("set_Layer", ray_layer)
			ray_query:call("set_FilterInfo", filter_info)
			ray_method:call(via_physics_system, ray_query, ray_result)
			local num_contact_pts = ray_result:call("get_NumContactPoints") 
			if num_contact_pts and num_contact_pts > 0 then
				local new_contactpoint = ray_result:call("getContactPoint(System.UInt32)", 0)
				--local noExcept, new_collidable = pcall(sdk.call_object_func, ray_result, "getContactCollidable(System.UInt32)", 0) --sdk.find_type_definition("via.physics.CastRayResult"),
				local new_collidable = ray_result:call("getContactCollidable(System.UInt32)", 0)
				--if not noexcept then log.info("fail") end
				--if noExcept and 
				if new_contactpoint and new_collidable then 
					local contact_pos = sdk.get_native_field(new_contactpoint, sdk.find_type_definition("via.physics.ContactPoint"), "Position")
					local contact_pt_dist = (contact_pos - last_camera_matrix[3]):length()
					local game_object = new_collidable:call("get_GameObject")
					if sdk.is_managed_object(game_object) then 		
						local transform = game_object:call("get_Transform")
						if touched_gameobjects[transform] then 
							gameobjects[contact_pt_dist] = touched_gameobjects[transform]
							gameobjects[contact_pt_dist].impact_pos = contact_pos
							gameobjects[contact_pt_dist].contact_pt = new_contactpoint 
							gameobjects[contact_pt_dist].is_old = true
						else
							gameobjects[contact_pt_dist] = GameObject:new_GrabObject { gameobj=game_object, xform=transform, collidable=new_collidable, contact_pt=new_contactpoint, impact_pos = contact_pos, ray_layer=ray_layer, dist=contact_pt_dist, num_contacts=num_contact_pts }
							--re.on_update_transform(transform, on_update_transform)
						end
					end
				end
			end
			ray_result:call("clear")
		end
		
	elseif ray_method == d_cast_ray_method then 
		
		local d_ray_result = has_dynamics and sdk.create_instance("via.dynamics.RayCastResult"):add_ref()
		
		for i, ray_layer in ipairs(ray_layers_table) do
			
			filter_info:call("set_Layer", ray_layer)
			ray_query:call("set_FilterInfo", filter_info)
			ray_method:call(via_dynamics_system, ray_query, d_ray_result)
			
			local new_contactpoint = d_ray_result:call("getContactPoint(System.Int32)", 0)
			local noExcept, new_rigid_id = pcall(sdk.call_object_func, d_ray_result, "getContactRidigBodyID", 0)
			
			if new_contactpoint and new_rigid_id  then
				
				local contact_pos = sdk.get_native_field(new_contactpoint, sdk.find_type_definition("via.dynamics.ContactPoint"), "Position") --getDynamicsContactPtPos(new_contactpoint) new_contactpoint:get_field("Position") --
				local num_contact_pts = d_ray_result:call("get_NumContactPoints") 
				local rigid_index = new_rigid_id:get_field("Value")
				
				if contact_pos then 
					local contact_pt_dist = (contact_pos - last_camera_matrix[3]):length()
					local new_rigid_component = sdk.call_native_func(via_dynamics_system, via_dynamics_system_typedef, "getComponent", new_rigid_id)
					if new_rigid_component and new_rigid_component:get_type_definition():is_a("via.dynamics.RigidBodySet") then 
						local game_object = new_rigid_component:call("get_GameObject")
						if sdk.is_managed_object(game_object) then 
							local transform = game_object:call("get_Transform")
							if contact_pt_dist and touched_gameobjects[transform] then 
								gameobjects[contact_pt_dist] = touched_gameobjects[transform]
								gameobjects[contact_pt_dist].impact_pos = contact_pos
								--gameobjects[contact_pt_dist].dist = contact_pt_dist
								gameobjects[contact_pt_dist].rigid_body = new_rigid_component
								gameobjects[contact_pt_dist].rigid_id = new_rigid_id:get_field("Value")
								gameobjects[contact_pt_dist].contact_pt = new_contactpoint 
								gameobjects[contact_pt_dist].is_old = true
							elseif not touched_gameobjects[transform] then
								gameobjects[contact_pt_dist] = GameObject:new_GrabObject { gameobj=game_object, xform=transform, rigid_body=new_rigid_component, rigid_id=rigid_index, contact_pt=new_contactpoint, impact_pos=contact_pos, ray_layer=ray_layer, dist=contact_pt_dist, num_contacts=num_contact_pts } 
								--re.on_update_transform(transform, on_update_transform)
							end
						end
					end
				end
			end
		end
	end
	return gameobjects
end

local function fire_gravity_gun(start_position, end_position, use_dynamics, allow_invalid)
	local start_position = start_position or last_camera_matrix[3]
	local ray_query = sdk.create_instance("via.physics.CastRayQuery"):add_ref()
	ray_query:call("setRay(via.vec3, via.vec3)", start_position, end_position)
	local results = cast_rays(cast_ray_method, ray_query)
	if use_dynamics and has_dynamics then
		local d_ray_query = sdk.create_instance("via.dynamics.RayCastQuery"):add_ref()
		d_ray_query:call("setRay(via.vec3, via.vec3)", start_position, end_position)
		local d_results = cast_rays(d_cast_ray_method, d_ray_query)
		if d_results then 
			for dist, d_value in orderedPairs(d_results) do
				if allow_invalid or not d_value.invalid then
					while results[dist] do
						dist = dist - 0.01
					end
					results[dist] = d_value 
				end
			end
		end
	end
	return results
end


local function gravity_gun()
	
	--set inputs this frame:
    local mouse = get_mouse_device()
    if not mouse then return end
	is_middle_mouse_down = mouse_state.down[via.hid.MouseButton.C]
	is_middle_mouse_released = mouse_state.released[via.hid.MouseButton.C]
	is_right_mouse_down = mouse_state.down[via.hid.MouseButton.R]
    is_left_mouse_down = mouse_state.down[via.hid.MouseButton.L]
	is_left_mouse_released = mouse_state.released[via.hid.MouseButton.L]
	is_z_key_down = kb_state.down[via.hid.KeyboardKey.Z]
	is_v_key_released = kb_state.released[via.hid.KeyboardKey.V] 
	is_f_key_down = kb_state.down[via.hid.KeyboardKey.F] 
	is_r_key_down = kb_state.down[via.hid.KeyboardKey.R] 
	is_alt_key_down = kb_state.down[via.hid.KeyboardKey.Menu]

	--TOGGLE OFF:
	if is_middle_mouse_released then 
		if not was_middle_mouse_released then 
			was_middle_mouse_released = true
			if toggled then 
				if last_grabbed_object then
					last_grabbed_object:toggle_forced_funcs(false)
					--last_grabbed_object = nil
				end
				active_objects = {}
				toggled = false
				was_just_disabled = true
				log.info("Disabled Gravity Gun at frame " .. tics)				
			end
		end
	else
		was_just_disabled = false
		was_middle_mouse_released = false
	end
	
	if is_v_key_released then 
		--GGSettings.prefer_rigid_bodies = not GGSettings.prefer_rigid_bodies
		--wants_rigid_bodies = GGSettings.prefer_rigid_bodies
		wants_rigid_bodies = not wants_rigid_bodies
	end
	
	--set camera variables:
	local last_camera_forward = camera_forward
	camera_forward = last_camera_matrix[2] * -1.0
	
	local camera_pos = last_camera_matrix[3]
	local camera_rotation = last_camera_matrix:to_quat()
	local negated_camera_rotation = neg_last_camera_matrix:to_quat()
	local flat_negated_forward = Vector3f.new(neg_last_camera_matrix[2].x, 0.0, neg_last_camera_matrix[2].z):normalized()
	local flat_negated_camera_rotation = flat_negated_forward:to_quat()
	
	--Increase or decrease grab distance if mouse wheel is changed:
	if not is_f_key_down then
		if mouse_state.down[via.hid.MouseButton.DOWN] then
			grab_distance = grab_distance - (grab_distance * 0.05)
		elseif mouse_state.down[via.hid.MouseButton.UP] then
			grab_distance = grab_distance + (grab_distance * 0.05)
		end
	end	
	
	if not toggled and not was_just_disabled and not figure_mode and (is_middle_mouse_down or is_middle_mouse_released) then 
	
		local results = {}
		grav_objs = {} 		--indexed table ordered by proximity
		d_grav_objs = {}	--from via.system.Dynamics
		active_objects = {} --dictionary with transform addresses as keys
		local d_results = {}
		
		if is_alt_key_down and last_grabbed_object and is_valid_obj(last_grabbed_object.xform) then --grabs last gameobject
			if is_middle_mouse_released then 
				local cam_dist = (last_camera_matrix[3] - (last_grabbed_object.pos + last_grabbed_object.center)):length()
				local target_pos = last_camera_matrix[3] - (last_camera_matrix[2] * cam_dist)
				last_grabbed_object.xform:call("set_Position", target_pos - last_grabbed_object.center)
				grav_objs[1] = GameObject:new_GrabObject{xform=last_grabbed_object.xform, impact_pos=target_pos, dist=cam_dist}-- init_offset=Vector3f.new(0,-4,0)} --last_grabbed_object.cog_joint:call("get_BaseLocalPosition")
				grab_distance = cam_dist
			end
		else 
			last_grabbed_object = nil
			current_contact_points = 0
			d_current_contact_points = 0
			local end_position = last_camera_matrix[3] - (last_camera_matrix[2] * 9999.0) --far end of the ray
			
			local ray_query = sdk.create_instance("via.physics.CastRayQuery"):add_ref()
			ray_query:call("setRay(via.vec3, via.vec3)", camera_pos, end_position)
			
			--collect physics results:
			results = cast_rays(cast_ray_method, ray_query)
			
			--collect Rigid Body results:
			if has_dynamics then --GGSettings.prefer_rigid_bodies and 
				local d_ray_query = sdk.create_instance("via.dynamics.RayCastQuery"):add_ref()
				d_ray_query:call("setRay(via.vec3, via.vec3)", camera_pos, end_position)
				d_results = cast_rays(d_cast_ray_method, d_ray_query)
				if d_results then 
					for dist, d_value in orderedPairs(d_results) do
						if not d_value.invalid then
							table.insert(d_grav_objs, d_value)
							while results[dist] do
								dist = dist - 0.01
							end
							results[dist] = d_value 
						end
					end
				end
			end
			
			--last_impact_pos = nil 
			for dist, gameobject in orderedPairs(results) do 
				last_impact_pos = gameobject.impact_pos or last_impact_pos
				--other_last_impact_pos = (gameobject.impact_pos and logv(gameobject.impact_pos)) or other_last_impact_pos
				if not gameobject.invalid then
					table.insert(grav_objs, gameobject)
				end
			end

			if d_grav_objs[1] then 
				d_current_contact_points = d_grav_objs[1].num_contacts 
			end
		end	
		
		if grav_objs[1] then 
			while grav_objs[1].parent do 
				touched_gameobjects[grav_objs[1].parent] = GameObject:new_GrabObject{xform=grav_objs[1].parent, impact_pos=grav_objs[1].impact_pos }
				--touched_gameobjects[grav_objs[1].parent]:update()
				if not touched_gameobjects[grav_objs[1].parent].invalid then --touched_gameobjects[grav_objs[1].parent].pos and 
					grav_objs[1] = touched_gameobjects[grav_objs[1].parent]
				else
					break
				end
			end
			
			last_grabbed_object = grav_objs[1]
			
			if last_grabbed_object.name == "StaticCompounder" then 
				local game_object = last_grabbed_object.gameobj
				local shortest_distance = 9999.0
				local static_compound_controller = game_object:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("StaticCompoundController")))
				local static_compound_game_objects = static_compound_controller:get_field("CompoundGameObjectList"):get_elements()
				
				local closest_gameobject = nil
				for g, static_game_object in ipairs(static_compound_game_objects) do  
					local go_name = static_game_object:call("get_Name")
					if go_name ~= "StaticCompounder" then 
						local position = nil
						local mesh = static_game_object:call("getComponent(System.Type)", sdk.typeof("via.render.Mesh"))
						if mesh then
							local AABB = mesh:call("get_WorldAABB")
							position =  AABB:call("getCenter")
						else
							position = static_game_object:call("get_Transform"):call("get_Position")
						end
						local dist = (last_grabbed_object.impact_pos - position):length()
						if dist < shortest_distance then
							closest_gameobject =  static_game_object
							shortest_distance = dist
						end
					end
				end
				if closest_gameobject then
					last_grabbed_object = GameObject:new_GrabObject { gameobj=closest_gameobject, collidable=last_grabbed_object.collidable, contact_pt=last_grabbed_object.contact_pt, impact_pos=last_grabbed_object.impact_pos, ray_layer=last_grabbed_object.ray_layer } 
					--if not touched_gameobjects[last_grabbed_object.xform] then 
						--re.on_update_transform(last_grabbed_object.xform, on_update_transform) 
					--end
					touched_gameobjects[last_grabbed_object.xform] = last_grabbed_object
					grav_objs[1] = last_grabbed_object
				end
			end
			
			for i, child in ipairs(grav_objs[1].children or {}) do 
				table.insert(grav_objs, touched_gameobjects[child] or GameObject:new_GrabObject{xform=child})
			end
			
			for i, go in ipairs(grav_objs) do
				if go.invalid or (grav_objs[1].pos - go.pos):length() > 0.001 then 
					table.remove(grav_objs, i)
				else
					for j, go2 in ipairs(grav_objs) do 
						if i ~= j and go.xform == go2.xform then 
							table.remove(grav_objs, j)
						end
					end
				end
			end
			
			for i, go in ipairs(grav_objs) do
				active_objects[go.xform] = go
			end
			
			current_contact_points = last_grabbed_object.num_contacts
			current_layer = last_grabbed_object.ray_layer
			
			if is_middle_mouse_released and not last_grabbed_object.invalid then 
				if last_grabbed_object.is_old then
					local o = last_grabbed_object
					last_grabbed_object = GameObject:new_GrabObject{ 
						gameobj=o.gameobj, 
						collidable=o.collidable, 
						rigid_body=o.rigid_body, 
						init_worldmat=o.init_worldmat, 
						contact_pt=o.contact_pt, 
						impact_pos=o.impact_pos, 
						ray_layer=o.ray_layer, 
						children=o.children, 
						shapes=o.shapes 
					}
					active_objects[last_grabbed_object.xform] = last_grabbed_object
					grav_objs[1] = last_grabbed_object
				end
				last_grabbed_object:toggle_forced_funcs(true)
				last_contact_point = last_grabbed_object.contact_pt
				last_impact_pos = last_grabbed_object.impact_pos
				grab_distance = (last_grabbed_object.pos - camera_pos + last_grabbed_object.init_offset):length()
				if last_grabbed_object.components_named.GroundFixer then
					last_grabbed_object.components_named.GroundFixer:call("set_Enabled", true)
					last_grabbed_object.components_named.GroundFixer:call("setAdjustMode", 2)
				end
				log.info("Toggled Gravity Gun at frame " .. tics)
				toggled = true
			end
		end
	end
	
	-- WHILE GRAVITY GUN IS ACTIVE:
	if toggled then
		
		local new_pos = camera_pos + (camera_forward * grab_distance) 
		--wants_rigid_bodies = false
		
		for i, game_object in ipairs(grav_objs) do
			
			if i == 1 and game_object.init_offset and not game_object.invalid then
				
				--if GGSettings.prefer_rigid_bodies and game_object.rigid_body and (game_object.hp == nil or game_object.hp:call("get_CurrentHitPoint") == 0) then --only RigidBodySet things that are dead				
				--	wants_rigid_bodies = not not game_object.rigid_body
				--end
				
				local final_pos = Vector3f.new(new_pos.x - (game_object.init_offset.x  * game_object.multiplier), new_pos.y - game_object.init_offset.y, new_pos.z - (game_object.init_offset.z  * game_object.multiplier))
				local new_rotation = (game_object.components_named.SpotLight or game_object.components_named.IESLight or game_object.components_named.DirectionalLight) and last_camera_matrix:to_quat()
				new_rotation = new_rotation or ((game_object.init_rot_false * game_object.initflatncam_rot:inverse()) * flat_negated_camera_rotation):normalized()
				local new_scale = game_object.scale
				
				if game_object.multiplier == 1 then game_object.multiplier = 0.9999999999999 end --just marking that the object was moved
				
				if game_object.center and last_camera_forward and game_object.multiplier > 0 then
					local diff = last_camera_forward:to_quat() * camera_forward:to_quat():inverse()
					diff = 1.0 - math.abs(diff.w)
					if diff > 0.00005 then --when the camera moves quickly, the multiplier is reduced a little
						game_object.multiplier = game_object.multiplier * 0.985
						if game_object.multiplier < 0.01 then game_object.multiplier = 0 end
					end
				end		
				
				if is_alt_key_down then 
					game_object.init_rot_false = game_object.xform:call("get_LocalRotation")--game_object.rot
					game_object.initflatncam_rot = flat_negated_camera_rotation
				end
				
				if is_f_key_down then
					local scale_multiplier = 1
					if mouse_state.down[via.hid.MouseButton.DOWN] then
						scale_multiplier = 0.95
					elseif mouse_state.down[via.hid.MouseButton.UP] then
						scale_multiplier = 1.05
					end
					if scale_multiplier ~= 1 then 
						new_scale = new_scale * scale_multiplier
						if game_object.hp ~= nil and game_object.scale.x > 1.0 then
							game_object.hp:call("set_CurrentHitPoint", math.floor(game_object.hp:call("get_CurrentHitPoint") * scale_multiplier))
						end
					end
				end
				
				if is_z_key_down then
					if not player or player.xform ~= game_object.xform then 
						final_pos, new_rotation, new_scale = mat4_to_trs(game_object.init_worldmat)
						reset_object(game_object)
					else
						game_object.hp:call("set_CurrentHitPoint", game_object.hp:call("get_DefaultHitPoint"))
					end
					if game_object.think and game_object.hp and game_object.hp:call("get_CurrentHitPoint") == 0 then 
						local req ; if isRE2 then req = game_object.think:call("get_RequestActionState") else req = game_object.think:call("get_ActionState") end
						if req then 
							game_object.think:call("resetThink")
							req:call("apply", 4, 0, game_object.gameobj) --revive zombies
							game_object.hp:call("set_CurrentHitPoint", game_object.hp:call("get_DefaultHitPoint"))
						end
					end
					--
				end
				
				if is_r_key_down then 
					wants_rigid_bodies = false
				end		
				
				if wants_rigid_bodies and game_object.rigid_body then -- and game_object.rigid_body:call("get_StateName") == "DynamicStates" 

					if is_left_mouse_released then  --fire!
						local pos = game_object.rigid_body:call("getPosition", game_object.closest_id)
						game_object.rigid_body:call("setLinearVelocity", game_object.closest_id, (last_camera_matrix[3] - (last_camera_matrix[2] * 150.0)) - pos)
						active_objects[game_object.xform] = nil
						toggled = false 
						was_just_disabled = true
					else
						local states = game_object.rigid_body:call("get_States")
						
						if states then 
							local state_count = states:call("get_Count")
							
							if state_count and state_count > 0 then 
								if pcall(game_object.rigid_body.call, game_object.rigid_body, "getPosition", 0) then 
									if game_object.closest_id == nil then 
										local shortest = 9999
										for i = 0, state_count - 1 do 
											local pos = game_object.rigid_body:call("getPosition", i)
											if pos then 
												local dist = (game_object.impact_pos - pos):length()
												if dist < shortest then
													game_object.closest_id =  i
													shortest = dist
												end
											end
										end
									end
									final_pos.y = final_pos.y + 0.85
									local pos = game_object.rigid_body:call("getPosition", game_object.closest_id)
									game_object.rigid_body:call("setLinearVelocity", game_object.closest_id, (final_pos - pos) * 15)
								end
							end
						end
					end
				end
				if write_transforms then 
					--[[if cutscene_mode and game_object.cog_joint then
						local cam_matrix = sdk.get_primary_camera():call("get_WorldMatrix")
						deferred_calls[game_object.cog_joint] = {
							{func="set_Position", args=final_pos},
							{func="set_Rotation", args=new_rotation},
							{func="set_LocalScale", args=new_scale},
						}
					else]]
					game_object.packed_xform = table.pack(final_pos, new_rotation, new_scale)
					--end
				end 
			end
		end
	end
	
	if not grav_objs or is_z_key_down then
		toggled = false
		was_just_disabled = true
		active_objects, grav_obs = {}, {}
	end
end


----------------------------------------------------------------------------------------------------------[[ON DRAW UI]]

re.on_draw_ui(function()
	
	local setting_was_changed = false
	if imgui.tree_node("Gravity Gun Settings") then
		
		changed, GGSettings.load_json = imgui.checkbox("Persistent Settings", GGSettings.load_json); setting_was_changed = setting_was_changed or changed
		changed, GGSettings.action_monitor = imgui.checkbox("Action Monitor", GGSettings.action_monitor); setting_was_changed = setting_was_changed or changed
		changed, GGSettings.force_functions = imgui.checkbox("Forced functions", GGSettings.force_functions); setting_was_changed = setting_was_changed or changed
		if isRE2 or isRE3 then 
			changed, GGSettings.block_input = imgui.checkbox("Block input when UI", GGSettings.block_input); setting_was_changed = setting_was_changed or changed
		end
		changed, GGSettings.show_transform = imgui.checkbox("Show transform", GGSettings.show_transform); setting_was_changed = setting_was_changed or changed
		if has_dynamics then 
		--	changed, GGSettings.prefer_rigid_bodies = imgui.checkbox("Prefer Physics Objects", GGSettings.prefer_rigid_bodies); setting_was_changed = setting_was_changed or changed
			changed, wants_rigid_bodies = imgui.checkbox("wants_rigid_bodies", wants_rigid_bodies)
		end
		
		if imgui.tree_node("Ray Layers") then
			local layer_name, changed = "Auto (" .. tostring(current_layer) .. ")"
			pcall(function()
				if GGSettings.wanted_layer ~= -1 and _G[sdk.game_namespace(""):sub(1, -2)] and _G[sdk.game_namespace(""):sub(1, -2)].Collision.CollisionSystem.ray_layer[GGSettings.wanted_layer] then 
					layer_name = _G[sdk.game_namespace(""):sub(1, -2)].Collision.CollisionSystem.ray_layer[GGSettings.wanted_layer] 
				end
			end)
			changed, GGSettings.wanted_layer = imgui.drag_int("Wanted layer: " .. layer_name, GGSettings.wanted_layer, 1, -1, 2048); --setting_was_changed = setting_was_changed or changed
			changed, GGSettings.wanted_mask_bits = imgui.drag_int("Wanted mask bits", GGSettings.wanted_mask_bits, 1, 0, 100000000); --setting_was_changed = setting_was_changed or changed
			imgui.text("Auto Mode Layers:")
			for i=0, 32 do 
				local exists = find_index(GGSettings.ray_layers_tables[game_name], i) --table.bfind(GGSettings.ray_layers_tables[game_name], i)
				local changed, layer = imgui.checkbox("Layer " .. i, not not exists) 
				if changed then
					setting_was_changed = changed
					if not layer then 
						table.remove(GGSettings.ray_layers_tables[game_name], exists)
					else
						table.insert(GGSettings.ray_layers_tables[game_name], i)
					end
				end
			end
			imgui.tree_pop()
		end
		
		if imgui.tree_node("Forced Functions") then
			--read_imgui_pairs_table(funcs_to_force_by_component, "Forced_Functions")
			for component_name, tbl in orderedPairs(funcs_to_force_by_component) do 
				imgui.begin_rect()
					imgui.push_id(component_name)
						changed, GGSettings.forced_funcs_data[component_name].enabled = imgui.checkbox("", GGSettings.forced_funcs_data[component_name].enabled)
					imgui.pop_id()
					imgui.same_line()
					if imgui.tree_node(component_name) then
						for i, sub_tbl in ipairs(tbl) do
							imgui.begin_rect()
								imgui.push_id(sub_tbl.set)
									changed, GGSettings.forced_funcs_data[component_name][i].enabled = imgui.checkbox("", GGSettings.forced_funcs_data[component_name][i].enabled)
								imgui.pop_id()
								imgui.same_line()
								if imgui.tree_node(sub_tbl.set) then
									for key, value in orderedPairs(sub_tbl) do
										if key ~= "get" and key ~= "set" and key ~= "count" and key ~= "disabled" then
											imgui.begin_rect()
												if type(value) == "table" then 
													if imgui.tree_node(key) then
														for k, v in orderedPairs(value) do
															editable_table_field(k, v, funcs_to_force_by_component[component_name][i][key])
														end
														imgui.tree_pop()
													end
												else
													editable_table_field(key, value, funcs_to_force_by_component[component_name][i])
												end
											imgui.end_rect()
											--[[if type(value) == "boolean" then
												changed, sub_tbl.value = imgui.checkbox(key, value)
											elseif type(value) == "string" then
												changed, sub_tbl.value = imgui.input_text(key, value)
											elseif type(value) == "number" then
												changed, sub_tbl.value = imgui.drag_int(key, value, 1, 0, 100000000)
											else
												imgui.text(tostring(value) .. "	" .. key)
											end]]
										end
									end
									imgui.tree_pop()
								end
							imgui.end_rect(2)
						end
						imgui.tree_pop()
					end
				imgui.end_rect(3)
				imgui.spacing()
			end
			imgui.tree_pop()
		end
		
		reset_objs = nil
		if imgui.button("Reset All Objects") then
			reset_objs = true
		end
		
		if jsonify_table then --save/load positions from a file, using the object's original position as its key
			imgui.same_line()
			if imgui.button("Save Transforms") then 
				saved_xforms = {}
				for xform, object in pairs(touched_gameobjects) do 
					if object.components_named.Mesh and (object.init_worldmat ~= new_mat4) and not object.xform:call("getJointByName", "COG") and not object.xform:call("getJointByName", "Hip") then 
						--local getmesh = object.components_named.Mesh:call("getMesh")
						--if getmesh then 
						if object.key_hash then
							--local key = jsonify_table({object.init_worldmat})[1]
							saved_xforms[object.key_hash] = { matrix=object.xform:call("get_WorldMatrix") } --mesh=getmesh:call("ToString()"),
						end
					end
				end
				json.dump_file("GravityGunAndConsole\\GGCSavedXforms.json", jsonify_table(saved_xforms))
			end
			
			imgui.same_line()
			if imgui.button("Load Transforms") then 
				local meshes = find("via.render.Mesh")
				saved_xforms = jsonify_table(json.load_file("GravityGunAndConsole\\GGCSavedXforms.json") or {}, true)
				for key_hash, sub_tbl in pairs(saved_xforms) do 
					--local mat_key = jsonify_table({init_worldmat}, true)[1]
					for i, mesh_xform in ipairs(meshes) do 
						--local this_mesh_xform = (touched_gameobjects[mesh] and touched_gameobjects[mesh].init_worldmat) or mesh:call("get_WorldMatrix")
						--if this_mesh_xform == mat_key then
						local obj = touched_gameobjects[mesh_xform] --and touched_gameobjects[mesh_xform].init_worldmat
						local obj_key_hash = (obj and obj.key_hash) or hashing_method(EMV.get_gameobj_path(mesh_xform:call("get_GameObject")))
						if obj_key_hash == key_hash then
							touched_gameobjects[mesh_xform] = touched_gameobjects[mesh_xform] or GameObject:new_GrabObject{xform=mesh_xform}
							obj = touched_gameobjects[mesh_xform]
							obj.packed_xform =  table.pack(mat4_to_trs(sub_tbl.matrix))
							write_transform(obj, table.unpack(obj.packed_xform))
							break
						end
					end
				end
			end
		end
		
		imgui.text("Hotkeys:\n[F] - Scale Objects with Mouse Wheel\n[R] - Force Move Physics Objects without Physics\n[Z] - Reset Object to Original\n[Alt] - Unlock Rotation\n[V] - Toggle between Physics/Normal mode")
		imgui.tree_pop()
	end
	
	imgui.begin_rect()
		imgui.text("Gravity Gun Objects")
		
		if last_grabbed_object then
			local active = active_objects[last_grabbed_object.xform]
			imgui.text((not active and "  Last " or "  ") .."Grabbed GameObject")
			imgui.text("  "); imgui.same_line()
			if imgui.tree_node_ptr_id(sdk.to_ptr(last_grabbed_object.gameobj), last_grabbed_object.name) then
				--changed, last_grabbed_object.grab_by_cog = imgui.checkbox("Grab by COG", last_grabbed_object.grab_by_cog)
				imgui_anim_object_viewer(last_grabbed_object)
				imgui.tree_pop()
			end
			
			if active and grav_objs and #grav_objs > 1 then 
				imgui.text("  Other Grabbed GameObjects")
				for i, game_object in ipairs(grav_objs) do 
					if i ~= 1 then 
						imgui.text("  "); imgui.same_line()
						if imgui.button(tostring(i-1)) then 
							local tmp = grav_objs[i]
							grav_objs[i] = grav_objs[1] 
							--grav_objs[1] = grab(tmp, {grav_objs[i]})
						end
						imgui.same_line()
						if imgui.tree_node_ptr_id(game_object.gameobj, game_object.name) then
							imgui_anim_object_viewer(game_object)
							imgui.tree_pop()
						end
					end
				end
			end
		else
			toggled = false
			was_just_disabled = true
		end
		if next(touched_gameobjects) then
			if imgui.tree_node("Touched GameObjects") then 
				for xform, game_object in orderedPairs(touched_gameobjects) do 
					imgui.text("  "); imgui.same_line()
					if imgui.tree_node_str_id(game_object.key_hash, game_object.name) then
						imgui_anim_object_viewer(game_object)
						imgui.tree_pop()
					end
				end
			end
		end
	imgui.end_rect(1)
	imgui.new_line()
	
	--[[if imgui.button("Save") then
		for i, xform in ipairs(find("via.motion.DummySkeleton")) do
			local obj = GameObject:new_GrabObject{xform=xform}
			if not go.mesh and obj.name:find("pl") == 1 then 
				go = obj or go
			end
		end
		if go then
			test1 = jsonify_table(go.xform)
			test2 = jsonify_table(test1, true)
			collectgarbage()
		end
	end]]
	--[[if total_objects then
		imgui.text("SAVE/LOAD")
		if sorted_held_transforms_names == nil or random(10) then
			--if sorted_held_transforms_names ~= nil then imgui.text(tostring(#sorted_held_transforms_names) .. "loading" .. tostring(get_table_size(held_transforms))) end
			sorted_held_transforms_alt, sorted_held_transforms_names, tmp_tbl = {}, {}, {}
			--table.sort (sorted_held_transforms, function (obj1, obj2) return (obj1.name_w_parent or obj1.name) < (obj2.name_w_parent or obj2.name) end)
			for xform, obj in pairs(held_transforms) do 
				obj.temp_name = obj.name_w_parent
				while sorted_held_transforms_alt[obj.temp_name] do
					obj.temp_name = obj.temp_name .. " "
				end
				sorted_held_transforms_alt[obj.temp_name] = obj
			end
			for temp_name, obj in orderedPairs(sorted_held_transforms_alt) do 
				table.insert(sorted_held_transforms_names, temp_name)
				obj.temp_name = nil
			end
		end
		imgui.begin_rect()
			changed, saveable_gameobject_idx = imgui.combo("Select GameObject", saveable_gameobject_idx, sorted_held_transforms_names)
			local anim_obj = sorted_held_transforms_alt[ sorted_held_transforms_names[saveable_gameobject_idx] ]
			if imgui.button("Save") and anim_obj then
				test = save_json_gameobject(anim_obj) --current_figure
			end
			imgui.same_line()
			if imgui.button("Load") and anim_obj then
				test = load_json_game_object(anim_obj, save_with_props and 1 or 0)
			end
			imgui.same_line()
			changed, save_with_props = imgui.checkbox("Save/Load Props", save_with_props)
			if anim_obj and imgui.tree_node_str_id(anim_obj.name .. "Sv", anim_obj.name) then
				imgui.managed_object_control_panel(anim_obj.xform)
				imgui.tree_pop()
			end
			imgui.new_line()
			imgui.new_line()
		imgui.end_rect(1)
		
	end]]
	
	if GGSettings.load_settings and (setting_was_changed or random(255)) then
		json.dump_file("GravityGunAndConsole\\GGunConsoleSettings.json", jsonify_table(GGSettings))
	end
end)

----------------------------------------------------------------------------------------------------------[[ON APPLICATION ENTRY]]

re.on_application_entry("UpdateHID", function()
	--disable mouse while UI is up
	if GGSettings.block_input and inputsystem and reframework:is_drawing_ui() then 
		inputsystem:set_field("<IgnoreMouseMove>k__BackingField", true)
	end 
	
	--disable quick weapon switch while object is grabbed:
	if inventorymanager then 
		if toggled then 
			inventorymanager:call("set_Enabled", false)
		else
			inventorymanager:call("set_Enabled", true)
		end
	end
end)


re.on_application_entry("UpdateMotion", function() --BeginPhysics
	
	resetted_objects = {}
	local rem_count = 0
	for xform, game_object in pairs(touched_gameobjects) do
		if not is_valid_obj(xform) then 
			rem_count = rem_count + 1
			clear_object(xform)
		else
			if game_object.is_forced and not active_objects[xform] then 
				game_object:toggle_forced_funcs(false)
			end
			game_object:update_GrabObject()
		end
	end 
	
	if reset_objs then
		is_z_key_down = true
		for xform, game_object in pairs(touched_gameobjects) do 
			reset_object(game_object)
		end
	end
	
	-----------------------------------------------------------------GRAVITY GUN
	gravity_gun()
end)


re.on_application_entry("BeginRendering", function()
	
	uptime = os.clock()
	tics = tics + 1
	toks = math.floor(uptime * 100)
	math.randomseed(math.floor(uptime))
	
	--for xform, obj in pairs(touched_gameobjects) do 
	--	obj:update_funcs()
	--end
	--sample_cams()
end)

----------------------------------------------------------------------------------------------------------[[ON FRAME]]

re.on_frame(function()
	
	player = get_player()
	go = last_grabbed_object or go or player or (next(touched_gameobjects)) or get_first_gameobj() or (held_transforms and (next(held_transforms)))
	go = (go and is_valid_obj(go.xform)) and go
	
    local camera = sdk.get_primary_camera()
	if not camera then return end
	last_camera_matrix = camera:call("get_WorldMatrix") or last_camera_matrix
	
	neg_last_camera_matrix[0] = last_camera_matrix[0] * -1.0
	neg_last_camera_matrix[1] = last_camera_matrix[1]
	neg_last_camera_matrix[2] = last_camera_matrix[2] * -1.0
	neg_last_camera_matrix[3] = last_camera_matrix[3]
	if toggled and kb_state.down[via.hid.KeyboardKey.V] then 
		camera:set_field("WorldMatrix", last_camera_matrix)
	end
	last_camera_matrix = camera:call("get_WorldMatrix")
	
	--[[if tics == 1 then 
		for i, xform in ipairs(find("via.motion.DummySkeleton")) do
			local obj = GameObject:new_GrabObject{xform=xform}
			if not go.mesh and obj.name:find("pl") == 1 then 
				go = obj
			end
		end
	end]]
	
	if (isRE2 or isRE3) and player and player.behaviortrees then
		player.cc = player.cc or player.components_named.CharacterController
		if player.cc and (player.behaviortrees[1].node_name ~= "STEP.STEP_UP") and player.cc:call("get_Wall") and EMV.check_key_released(via.hid.KeyboardKey.G) then --
			local player_wmatrix = player.xform:call("get_WorldMatrix")
			local start_pos = player_wmatrix[3] + player.center
			start_pos.y = start_pos.y + (player.center.y / 2)
			start_pos = start_pos + (player_wmatrix[2] * 0.2)
			local end_pos = start_pos + (player_wmatrix[2] * 3.0) 
			--EMV.draw_world_pos(start_pos, "start_pos")
			--EMV.draw_world_pos(end_pos, "end_pos")
			local results = fire_gravity_gun(start_pos, end_pos, false, true)
			if not next(results) then 
				player.behaviortrees[1]:set_node("STEP.STEP_UP")
			end
			--test = results
		end
	end
	
	
	if reframework:is_drawing_ui() then
		if GGSettings.action_monitor and go and go.behaviortrees and go.behaviortrees[1] and go.behaviortrees[1].names[1] then
			if imgui.begin_window("Action Monitor - " .. go.name, true, GGSettings.transparent_bg and 129) == false then GGSettings.action_monitor = false end--128
				for i, bhvt_obj in ipairs(go.behaviortrees) do
					bhvt_obj:imgui_behaviortree()
				end
			imgui.end_window()
		end
	end
	
	if toggled and last_grabbed_object  then --and sdk.is_managed_object(last_grabbed_object.xform)
		if GGSettings.show_transform and is_valid_obj(last_grabbed_object.xform) then
			local position = last_grabbed_object.pos
			position.y = position.y+0.025
			draw.world_text(last_grabbed_object.name , position, 0xFFFFFFFF) -- white, on last valid target
			local rotation = last_grabbed_object.rot
			local scale = last_grabbed_object.scale
			--local joint = last_grabbed_object.root_joint
			local joint_position = position
			--if joint then  joint_position = is_valid_obj(joint) and joint:call("get_Position") end
			local output_string = log_transform(joint_position, rotation, scale)
			draw.world_text("\n" .. output_string .. ", " .. tostring(last_grabbed_object.multiplier), joint_position, 0xFFFFFFFF)
		end
	end
	
	if not figure_mode then 
		if is_middle_mouse_down or is_right_mouse_down then 
			draw.line(width / 2, height / 2, width / 2, height / 2 - 1, 0xFFFFFFFF) --draw a 1px crosshair in the middle of the screen
		end
		if GGSettings.show_transform and is_middle_mouse_down and current_contact_points then 		 
			draw.text("Dynamics Contact Points: " .. d_current_contact_points .. ", Layer: " .. tostring(current_layer), width / 2, 0, 0xFFFFFFFF) -- 0xFFFFFFFF == white
			draw.text("\nPhysics Contact Points: " .. current_contact_points .. ", Layer: " .. tostring(current_layer) .. "\n\n" .. logv(last_impact_pos), width / 2, 0, 0xFFFFFFFF) --on last valid target
			
			if last_grabbed_object then 
				draw.text("\n\n" .. tostring(last_grabbed_object.name), width / 2, 0, 0xFFFFFFFF) -- .. ", Invalid: " .. tostring(last_grabbed_object.invalid)
			end 
		end
	end
end)