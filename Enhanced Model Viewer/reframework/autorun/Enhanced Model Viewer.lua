--Enhanced Model Viewer Script by alphaZomega
--v3
--June 26th 2022

--if true then return end
log.info("Initializing Enhanced Model Viewer")
log.debug("Initializing Enhanced Model Viewer")
local game_name = reframework.get_game_name()
local EMV = require("EMV Engine")
local res = require("Enhanced Model Viewer\\enhanced_model_viewer_" .. game_name .. "_resources")

--Global Persistent Settings
EMVSettings = EMVSettings or {}
EMVSettings.load_json = true
SettingsCache.remember_materials = true
EMVSettings.sync_face_mots = true
EMVSettings.transparent_bg = true
EMVSettings.seek_all = true
EMVSettings.cutscene_viewer = true
EMVSettings.detach_ani_viewer = false
EMVSettings.detach_cs_viewer = false 
EMVSettings.allow_performance_mode = false
EMVSettings.bg_resources = EMVSettings.bg_resources or {}
EMVSettings.current_loaded_ids = {}
EMVSettings.hotkeys = true
EMVSettings.special_mode = 1
EMVSettings.frozen_fov = 68.0
EMVSettings.use_savedata = true
EMVSettings.alt_sound_seek = not isDMC and true
EMVSettings.use_frozen_fov = false
EMVSettings.customize_cached_banks = false

EMVCache = {}
EMVCache.global_cached_banks = {}
EMVCache.savedata = {}
--if true then return end

--Shared Global Variables:
held_transforms = {}
deferred_calls = {}
global_cached_banks = {}
shown_transforms = {}

--Global (but just to check them in the console)
RN = RN or {} --resource names
total_objects = nil
imgui_anims = nil
imgui_others = nil
figure_mode = nil
cutscene_mode = nil
forced_mode = nil
selected = nil

local next = next
local ipairs = ipairs
local pairs = pairs
local player
local try, out
local start_time
local follow_figure = false
local do_move_light_set = false
local do_show_all_lights = false
local do_unlock_all_lights = false
local EMVSetting_was_changed = false
local this_figure_via_motions_count = 0
local new_mat4 = Matrix4x4f.new(Vector4f.new(1, 0, 0, 0), Vector4f.new(0, 1, 0, 0), Vector4f.new(0, 0, 1, 0), Vector4f.new(0, 0, 0, 1))

local static_objs = EMV.static_objs
static_objs.scene_manager = sdk.get_native_singleton("via.SceneManager")
static_objs.playermanager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager")) or sdk.get_managed_singleton("snow.player.PlayerManager")
static_objs.inputsystem = sdk.get_managed_singleton(sdk.game_namespace("InputSystem"))
static_objs.via_app = sdk.get_native_singleton("via.Application")

local static_funcs = EMV.static_funcs
static_funcs.get_enum_names_func = sdk.find_type_definition("System.Enum"):get_method("GetNames")
static_funcs.get_enum_values_func = sdk.find_type_definition("System.Enum"):get_method("GetValues")
static_funcs.setup_mbank_method = sdk.find_type_definition("via.motion.Motion"):get_method("setupMotionBank")

local scene = static_objs.scene_manager and sdk.call_native_func(static_objs.scene_manager, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene") 
base_mesh = nil
local current_figure = nil
local current_figure_name
local current_frame = 0
local play_speed = 1.0
local paused = true
local changed, was_changed
local tics = 0
local toks = 0
local current_em_name
local figure_start_time = nil
local held_transforms_count = 0
local ev_object = nil
figure_settings = nil
local figure_behavior
local current_fig_name = nil
local fig_mgr_name
local cutscene_cam
local re2_figure_container_obj = nil
local total_objects_names = {}
local sorted_held_transforms = {}
local cached_text_boxes = {}
local figure_objects = {}
local current_figure_meshes = {}
local motlists = {}
local motlist_mot_names = {}
local lights = {}
local non_lights = {}
local lightsets = {}

-----------------------------------------------------------------------------------------------------------------EMV_Engine
--EMV Classes
local GameObject = EMV.GameObject
local ChainNode = EMV.ChainNode
local ChainGroup = EMV.ChainGroup
local Material = EMV.Material
local REMgdObj = EMV.REMgdObj
local BHVT = EMV.BHVT
local ImguiTable = EMV.ImguiTable

--EMV Dictionaries
local bool_to_number = EMV.bool_to_number
local number_to_bool = EMV.number_to_bool
local cog_names = EMV.cog_names

--EMV functions
local random = EMV.random
local random_range = EMV.random_range
local read_imgui_object = EMV.read_imgui_object
local read_imgui_pairs_table = EMV.read_imgui_pairs_table
local read_imgui_element = EMV.read_imgui_element
local create_REMgdObj = EMV.create_REMgdObj
local log_value = EMV.log_value
local logv = EMV.logv
local log_transform = EMV.log_transform
local is_only_my_ref = EMV.is_only_my_ref
local is_valid_obj = EMV.is_valid_obj
local merge_indexed_tables = EMV.merge_indexed_tables
local merge_tables = EMV.merge_tables
local deep_copy = EMV.deep_copy
local vector_to_table = EMV.vector_to_table
local find_index = EMV.find_index
local can_index = EMV.can_index
local orderedPairs = EMV.orderedPairs
local split = EMV.split
local Split = EMV.Split
local create_resource = EMV.create_resource
local get_folders = EMV.get_folders
local deferred_call = EMV.deferred_call
local is_lua_type = EMV.is_lua_type
local mouse_state = EMV.mouse_state
local kb_state = EMV.kb_state
local get_mouse_device = EMV.get_mouse_device 
local get_kb_device = EMV.get_kb_device
local get_table_size = EMV.get_table_size
local get_children = EMV.get_children
local isArray = EMV.isArray
local arrayRemove = EMV.arrayRemove
local jsonify_table = EMV.jsonify_table
local lua_find_component = EMV.lua_find_component
local lua_get_components = EMV.lua_get_components
local lua_get_system_array = EMV.lua_get_system_array
local is_child_of = EMV.is_child_of
local reverse_table = EMV.reverse_table
local magnitude = EMV.magnitude
local mat4_scale = EMV.mat4_scale
local get_trs = EMV.get_trs
local write_vec34 = EMV.write_vec34
local read_vec34 = EMV.read_vec34
local read_mat4 = EMV.read_mat4
local write_mat4 = EMV.write_mat4
local trs_to_mat4 = EMV.trs_to_mat4
local mat4_to_trs = EMV.mat4_to_trs
local delete_component = EMV.delete_component
local value_to_obj = EMV.value_to_obj
local clamp = EMV.clamp
local smoothstep = EMV.smoothstep
local draw_world_pos = EMV.draw_world_pos
local offer_show_world_pos = EMV.offer_show_world_pos
local show_imgui_vec4 = EMV.show_imgui_vec4
local check_create_new_value = EMV.check_create_new_value
local imgui_anim_object_viewer = EMV.imgui_anim_object_viewer
local imgui_saved_materials_menu = EMV.imgui_saved_materials_menu
local draw_material_variable = EMV.draw_material_variable
local change_multi = EMV.change_multi
local show_imgui_mat = EMV.show_imgui_mat
local get_enum = EMV.get_enum
local contains_xform = EMV.contains_xform
local is_unique_name = EMV.is_unique_name
local look_at = EMV.look_at
local offer_grab = EMV.offer_grab
local add_resource_to_cache = EMV.add_resource_to_cache
local insert_if_unique = EMV.insert_if_unique
local search = EMV.search
local sort = EMV.sort
local closest = EMV.closest
local calln = EMV.calln
local find = EMV.find
local findc = EMV.findc
local qsort = EMV.qsort
local check_key_released = EMV.check_key_released
local get_anim_object = EMV.get_anim_object
local clear_object = EMV.clear_object
local create_gameobj = EMV.create_gameobj
local get_GameObject = EMV.get_GameObject

EMV.clear_figures = function()
	paused = true
	total_objects, lightsets, lights, imgui_others, imgui_anims = {}, {}, {}, {}, {}, {} --clear all
	do_move_light_set, do_unlock_all_lights = false
	selected, figure_start_time, base_mesh, current_em_name, re2_figure_container_obj, figure_settings, current_figure = nil
	cutscene_mode, figure_mode, forced_mode, player = nil
	ev_object, background_objs = nil
	this_figure_via_motions_count = 0
	play_speed = 1
	log.info("CLEAR")
	collectgarbage()
end

local function New_AnimObject(args)
	local anim_object = GameObject:new_AnimObject(args)
	return anim_object
end

local function get_player()
	local player = EMV.get_player()
	if player then 
		local gameobj = isMHR and get_GameObject(player)
		local xform = (gameobj and gameobj:call("get_Transform")) or player:call("get_Transform")
		if xform then 
			held_transforms[xform] = held_transforms[xform] or GameObject:new_AnimObject { gameobj=gameobj, xform=xform  }
			return held_transforms[xform]
		end
	end
end

local function write_transform(gameobject, translation, rotation, scale, only_write_mat)--)	
	if sdk.is_managed_object(gameobject.xform) then 
		translation = translation or gameobject.xform:call("get_Position")
		--[[if translation then 
			gameobject.xform:call("set_Position", translation)
			--write_vec34(gameobject.xform, 0x40, translation, is_valid)
		end
		if rotation then 
			gameobject.xform:call("set_LocalRotation", rotation)
			--write_vec34(gameobject.xform, 0x30, rotation, is_valid)
		end
		if scale then
			gameobject.xform:call("set_LocalScale", scale)
		end]]
		local new_mat = trs_to_mat4(translation or gameobject.xform:call("get_Position"), rotation or gameobject.xform:call("get_Rotation"), scale or gameobject.xform:call("get_Scale"))
		write_mat4(gameobject.xform, new_mat, 0x80, true)
	else
		gameobject = nil
	end
end

--[[local function on_pre_update_transform(transform)
	local object = held_transforms[transform]
	if object and object.packed_xform and not is_calling_hooked_func  then
		write_transform(object, object.packed_xform[1], object.packed_xform[2], object.packed_xform[3], true) 
		object.packed_xform = nil
		--object.wrote_this_frame = true
	end
end]]

local function find_matching_mot(orig_object, tested_object, frame_count, orig_name, exclude_keyword)
	--log.info(tostring(exclude_keyword))
	local total = 0
	local matches = {}
	if tested_object.matched_random_limit and tested_object ~= orig_object and tested_object.display and (isRE8 or not tested_object.name:find("entacle")) then --and tested_object.body_part ~= "Other" 
		for i, mot in ipairs(tested_object.all_mots) do
			--log.info(tostring(tested_object.cached_banks[ mot[1] ]))
			if i > tested_object.matched_random_limit then 
				break
			elseif tested_object.cached_banks[ mot[1] ] then
				if not exclude_keyword or not tested_object.cached_banks[ mot[1] ].name:find(exclude_keyword) then --too many screaming "jack" face animations...
					if mot[4] == frame_count then --and mot[5] ~= orig_object.motbank_names[orig_object.mbank_idx] then --same frame but not anything from the same bank
						table.insert(matches, table.pack(tested_object, mot[1], mot[2], mot[3], mot[4], i))
					end
					total = total + 1
					if total > tested_object.matched_random_limit then break end
				--else
				--	log.info("excluded result " .. tested_object.cached_banks[ mot[1] ].name)
				end
			end
		end
	end
	--log_value(matches, orig_object.name .. " to " .. tested_object.name)
	if #matches == 1 then 
		return table.unpack(matches[1])
	elseif #matches > 1 then 
		local orig_splits = split(orig_name, "_")
		for i, packed_match in ipairs(matches) do
			if orig_splits[1] and packed_match[1].cached_banks and packed_match[1].cached_banks[ packed_match[2] ] and packed_match[1].cached_banks[ packed_match[2] ].motion_names 
			and packed_match[1].cached_banks[ packed_match[2] ].motion_names[ packed_match[3] ] and packed_match[1].cached_banks[ packed_match[2] ].motion_names[ packed_match[3] ][ packed_match[4] ]  then
				local mot_name = packed_match[1].cached_banks[ packed_match[2] ].motion_names[ packed_match[3] ][ packed_match[4] ]
				local splits = split(mot_name, "_")
				if splits[1] and splits[#splits] == orig_splits[#orig_splits] then --find if word after last `_` underscore is the same
					return table.unpack(packed_match)
				end
			end
		end
		return table.unpack(matches[random_range(1, #matches)])
	end
end

local function convert_mot_ids(cached_bank, mlist_idx, mot_idx)
	mlist_idx = mlist_idx or 1
	mot_idx = mot_idx or 1
	if not cached_bank then 
		return 1, 1
	end
	if mlist_idx == 0 then 
		mlist_idx = #cached_bank.motlist_names
	elseif mlist_idx == -1 then 
		mlist_idx = random_range(1, #cached_bank.motlist_names)
	elseif not cached_bank.motlist_names or mlist_idx > #cached_bank.motlist_names then 
		mlist_idx = 1
	end
	cached_bank.motion_names = cached_bank.motion_names or {}
	if not cached_bank.motion_names[mlist_idx] or mot_idx > #cached_bank.motion_names[ mlist_idx ] then 
		mot_idx = 1
	elseif mot_idx == 0 then 
		mot_idx = #cached_bank.motion_names[ mlist_idx ]
	elseif mot_idx == -1 then 
		mot_idx = random_range(1, #cached_bank.motion_names[ mlist_idx ])
	end
	return mlist_idx or 1, mot_idx or 1
end

local function draw_world_xform(object) 
	shown_transforms[object.xform or object] = object
end 

local function imgui_anim_object_figure_viewer(anim_object, obj_name, index)
	
	if not anim_object or not anim_object.gameobj then return end
	
	imgui.begin_rect()
		imgui.push_id(anim_object.gameobj:get_address()+ 3 + (tonumber(index) or 0))
			changed, anim_object.display = imgui.checkbox("",  anim_object.display)
			if changed and not anim_object.name:find("amera") then 
				anim_object:toggle_display()
			end
			imgui.same_line()
			imgui.begin_rect()
				imgui_anim_object_viewer(anim_object, obj_name, index)
				if anim_object.IBL then
					changed, anim_object.background_idx = imgui.combo(" ", anim_object.background_idx, RN.tex_resource_names)
					if changed or (anim_object.background_idx ~= 1 and not anim_object.IBL:call("get_DetonemapEnable")) then 
						--anim_object.gameobj:write_dword(0x12, 16843009)
						anim_object.IBL:call("set_IBLTextureResource", RSCache.tex_resources[ RN.tex_resource_names[ anim_object.background_idx] ])
						anim_object.IBL:call("set_DetonemapEnable", true)
					end
				end
				if background_objs and background_objs[anim_object.xform] then
					changed, anim_object.greenscreen_on = imgui.checkbox("Greenscreen", anim_object.greenscreen_on)
					if changed then 
						anim_object.original_textures = anim_object.original_textures or anim_object.materials[1].textures
						if anim_object.greenscreen_on then 
							anim_object.materials[1].variables[1] = Vector4f.new(0,1,0,1)
							deferred_calls[anim_object.materials[1].mesh] = { 
								{func="setMaterialTexture", args={0, 0, RSCache.tex_resources["systems/rendering/NullWhite.tex"] or create_resource("systems/rendering/NullWhite.tex", "via.render.TextureResource") } },
								{func="setMaterialTexture", args={0, 1, RSCache.tex_resources["systems/rendering/NullNormalRoughness.tex"] or create_resource("systems/rendering/NullNormalRoughness.tex", "via.render.TextureResource") } },
								{func="setMaterialTexture", args={0, 2, RSCache.tex_resources["systems/rendering/NullATOS.tex"] or create_resource("systems/rendering/NullATOS.tex", "via.render.TextureResource") } },
							}
						else
							anim_object.materials[1].variables[1] = Vector4f.new(anim_object.materials[1].orig_vars[1].x, anim_object.materials[1].orig_vars[1].y, anim_object.materials[1].orig_vars[1].z, anim_object.materials[1].orig_vars[1].w)
							deferred_calls[anim_object.materials[1].mesh] = { 
								{func="setMaterialTexture", args={0, 0, anim_object.original_textures[1] } },
								{func="setMaterialTexture", args={0, 1, anim_object.original_textures[2] } },
								{func="setMaterialTexture", args={0, 2, anim_object.original_textures[3] } },
							}
						end
						anim_object.materials[1].textures = {}
						table.insert(anim_object.materials[1].deferred_vars, 1)
						change_multi(anim_object.materials[1], "BaseColor", 1)
						change_multi(anim_object.materials[1], "BaseColor", 1)
					end
					if anim_object.greenscreen_on and anim_object.materials[1] then
						anim_object.materials[1]:draw_material_variable("BaseColor", 1)
					else
						imgui.new_line()
						imgui.new_line()
						imgui.spacing()
					end
				end
			imgui.end_rect()
		imgui.pop_id()
	imgui.end_rect()
end

re.on_application_entry("BeginRendering", function()
	
	if (isRE2 or isRE3) and figure_mode and current_figure and figure_settings and (mouse_state.released[via.hid.MouseButton.UP] or mouse_state.released[via.hid.MouseButton.DOWN]) then
		--local cam_dist = selected.cog_joint and selected.cog_joint:call("get_Position") or selected.xform:call("get_Position")
		local cam_dist = current_figure.xform:call("get_Position"); cam_dist.y = cam_dist.y + 1.1
		cam_dist = (camera.xform:call("get_Position") - cam_dist):length()
		--log.info("Rolled down " .. tostring(mouse_state.released[via.hid.MouseButton.DOWN]))
		if cam_dist < 50 then
			local new_movement_limit_x = (cam_dist * 0.5)
			new_movement_limit_x = (new_movement_limit_x < 2.5) and 2.5 or new_movement_limit_x
			new_movement_limit_y = ((new_movement_limit_x * 0.565) < 2.5) and (new_movement_limit_x * 0.565) or 2.5
			figure_settings:set_field("_LimitedMovementX", new_movement_limit_x)
			figure_settings:set_field("_LimitedMovementY", new_movement_limit_y)
			figure_settings:set_field("_LimitedNearDistance", cam_dist * 0.5)
			figure_settings:set_field("_LimitedFarDistance", cam_dist * 2)
		end
	end
end)

re.on_application_entry("UpdateMotion", function() 
	
	if total_objects and (figure_mode or cutscene_mode or forced_mode) then
		called_once = nil
		--local random_amt = math.floor(#total_objects / 200)
		performance_mode = EMVSettings.allow_performance_mode and  held_transforms_count > 500
		
		if (current_figure and not is_valid_obj(current_figure.xform)) or (selected and not is_valid_obj(selected.xform)) then
			EMV.clear_figures()
			forced_mode = nil
		end
		
		total_objects_names = {}
		local total_object_ctr = 0
		total_objects = arrayRemove(total_objects, function(total_object)
			if not total_object then return end
			if total_object.xform:read_qword(0x10) == 0 then
				held_transforms[total_object.xform] = nil
				--[[if forced_mode and total_object.components_named.PlayerLookAt then 
					total_object.components_named.PlayerLookAt:call("set_Enabled", true)
				end]]
				return false
			end
			total_object_ctr = total_object_ctr + 1
			total_object.total_objects_idx = total_object_ctr
			total_objects_names[total_object_ctr] = total_object.name
			return true
		end)
		
		--[[if (current_figure and not is_valid_obj(current_figure.xform)) then 
			log.info("current_figure is broken")
		end
		if (current_figure and not is_valid_obj(selected.xform)) then 
			log.info("selected is broken")
		end]]
		
		--[[for i, anim_object in pairs(held_transforms) do 
			if not performance_mode or anim_object.layer or random(3) then --performance mode gives each static object a 1/3 chance of being updated each frame
				anim_object:update_AnimObject()
			end
		end]]
		
		for i, anim_object in ipairs(total_objects) do 
			total_objects[i] = held_transforms[anim_object.xform] or anim_object --updating to match held_transforms
		end
		
		for i, obj in ipairs(imgui_anims or {}) do 
			local checked_object = obj or (EMVSettings.seek_all and selected) or obj 
			if checked_object and checked_object.mlist_idx and checked_object.loop_b then --looping check
				local current_frame
				if obj.delayed_seek then 
					current_frame = obj.delayed_seek
					obj.delayed_seek = nil
				elseif (checked_object.mlist_idx == checked_object.loop_b[3] and checked_object.mot_idx == checked_object.loop_b[4]) and checked_object.layer:call("get_Frame") >= checked_object.loop_b[1] then 
					if checked_object.mbank_idx ~= checked_object.loop_a[2] or checked_object.mlist_idx ~= checked_object.loop_a[3] or checked_object.mot_idx ~= checked_object.loop_a[4] then
						if obj.display then
							if checked_object.loop_a[2] ~= checked_object.mbank_idx then 
								obj:set_motionbank(checked_object.loop_a[2], checked_object.loop_a[3], checked_object.loop_a[4])
							else
								--log.info("setting " .. checked_object.name .. " to " .. checked_object.loop_a[2] .. ", " ..  checked_object.loop_a[3] .. ", " ..  checked_object.loop_a[4]  .. ", frame " .. checked_object.loop_a[1])
								obj:change_motion(checked_object.loop_a[3], checked_object.loop_a[4])
							end
						end
						obj.delayed_seek = checked_object.loop_a[1]
					else
						current_frame = checked_object.loop_a[1]
					end
				end
				if current_frame then 
					obj:control_action( { do_seek=true, current_frame=current_frame } )
				end
			end
		--[[
		if selected and selected.loop_b then --looping check
			local current_frame
			if selected.loop_b then 
				if selected.delayed_seek then 
					current_frame = selected.delayed_seek
					selected.delayed_seek = nil
				elseif (selected.mlist_idx == selected.loop_b[3] and selected.mot_idx == selected.loop_b[4]) and selected.layer:call("get_Frame") >= selected.loop_b[1] then 
					if selected.mbank_idx ~= selected.loop_a[2] or selected.mlist_idx ~= selected.loop_a[3] or selected.mot_idx ~= selected.loop_a[4] then
						for i, obj in ipairs(imgui_anims) do 
							if obj.display then
								if obj.loop_a[2] ~= obj.mbank_idx then 
									obj:set_motionbank(obj.loop_a[2], obj.loop_a[3], obj.loop_a[4])
								else
									--log.info("setting " .. obj.name .. " to " .. obj.loop_a[2] .. ", " ..  obj.loop_a[3] .. ", " ..  obj.loop_a[4]  .. ", frame " .. obj.loop_a[1])
									obj:change_motion(obj.loop_a[3], obj.loop_a[4])
								end
							end
						end
						selected.delayed_seek = selected.loop_a[1]
					else
						current_frame = selected.loop_a[1]
					end
				end
			end
			if current_frame then 
				for i, object in ipairs(imgui_anims) do
					object:control_action( { do_seek=true, current_frame=current_frame } )
				end
			end
		end
		]]
		end
		
		if cutscene_cam and EMVSettings.frozen_fov and EMVSettings.use_frozen_fov then 
			cutscene_cam.components[2]:call("set_FOV", EMVSettings.frozen_fov)
		end
	end
end)

local function is_matchable_motlist(motlist_name)
	if isRE8 then 
		return not (motlist_name:find("adddamage"))
	elseif isRE2 or isRE3 or isDMC then 
		return not (motlist_name:find("tree"))
	end
	return true --motlist_name ~= ""
end

local function is_matchable_mot(mot_name)
	if isRE2 or isRE3 or isDMC then 
		return not (mot_name:find("_ff"))
	end
	return true
end
--self.body_part ~= "Hair"

--Create alternate list of mot names with frame count in them
function get_motion_names_w_frames(cached_bank)
	local names_w_frames = {}
	for i, name in ipairs(cached_bank.motlist_names or {}) do
		names_w_frames[i] = {}
		for j, mot_name in ipairs(cached_bank.motion_names[i] or {}) do
			table.insert(names_w_frames[i], mot_name .. " (" .. math.floor(cached_bank.mots_ids[i][j][4]) .. " frames)")
		end
	end
	return names_w_frames
end

GameObject.new_AnimObject = function(self, args, o)
	args = args or {}
	o = o or {}
	--self = (args.xform and touched_gameobjects[args.xform] and merge_tables(touched_gameobjects[args.xform], o, true)) or GameObject:new(args, o)
	--self =  GameObject:new(args, o)
	self = GameObject:new(args, o)--, o or (args.xform and touched_gameobjects[args.xform])) --args.xform and touched_gameobjects[args.xform] or 
	if not self or not self.update or not self.xform then
		return nil
	end
	log.info("CREATING NEW ANIM OBJECT " .. self.name)
	--[[if self.name == "Body" then
		bodyCount = bodyCount + 1
		if bodyCount >100 then log.info(asd .. " asdaf") end
	end]]
	
	--if held_transforms[self.xform] and held_transforms[self.xform] ~= self then 
	--	held_transforms[self.xform] = merge_tables(self, held_transforms[self.xform], true)
	--end
	
	--self = held_transforms[self.xform] or self
	--held_transforms[self.xform] = self
	
	self.figure_name = args.figure_name or current_figure_name or (forced_mode and "Free Mode") or ""
	self.index = args.index --or #total_objects
	self.motion = args.motion or self.components_named.Motion or self.motion
	--self.layer = args.layer or (self.motion and self.motion:call("getLayer", 0)) or self.layer
	self.materials = args.materials or self.materials
	self.force_center = args.force_center or o.force_center or (figure_mode and not not (self.body_part == "Body" or self.name:find("base")))
	self.init_worldmat = args.init_worldmat or self.xform:call("get_WorldMatrix")
	self.alt_names = args.alt_names
	self.excluded_names = args.excluded_names
	self.physicscloth = self.components_named.PhysicsCloth
	self.chain = self.components_named.Chain
	self.joints = args.joints or lua_get_system_array(self.xform:call("get_Joints") or {}, false, true)
	self.cog_joint = args.cog_joint or self.xform:call("getJointByName", cog_names[game_name])
	self.center = (self.cog_joint and self.cog_joint:call("get_BaseLocalPosition")) --or (self.mesh and self.mesh:call("get_WorldAABB"):call("getCenter")) or Vector3f.new(0,1.25,0)
	--self.init_cog_offset = self.cog_joint and self.cog_joint:call("get_Position")
	self.is_light = args.is_light or self.is_light
	self.is_wep = (self.name:find("wp%d%d")==1) or nil
	
	if self.is_light and self.parent then 
		local p_xform, lightset_xform = self.parent
		while p_xform do 
			lightset_xform = p_xform
			p_xform = p_xform:call("get_Parent")
		end
		self.lightset_xform = lightset_xform
	end
	
	if self.components_named.IBL then
		self.IBL = self.components_named.IBL
		local ibl_resource = self.IBL:call("get_IBLTextureResource")
		if ibl_resource then 
			ibl_resource = ibl_resource:add_ref()
			local ibl_name_full = ibl_resource:call("ToString()"):match("^.+%[@?(.+)%]")
			if RSCache.tex_resources and not RSCache.tex_resources[ibl_name_full] then
				self.background_idx = table.binsert(RN.tex_resource_names or {}, ibl_name_full)
				RSCache.tex_resources[ibl_name_full] = ibl_resource
			else
				self.background_idx = find_index(RN.tex_resource_names or {}, ibl_name_full)
			end
		end
	end
	
	if self.components_named.GalleryPositionErrorCorrector then
		self.components_named.GalleryPositionErrorCorrector:get_field("Corrector"):set_field("IsStop", true)
	end	
	
	if (current_fig_name and self.name:find(current_fig_name)) then 
		current_figure = self
	end
	
	--log.info(self.name .. " " .. tostring(current_fig_name) .. " " .. tostring((current_fig_name and self.name:find(current_fig_name))) .. " " .. logv(current_figure, nil, 0))
	--has_gpuc = not not (self.physicscloth or self.chain)
	
	local forced_mode = args.forced_mode or forced_mode
	
	for i, child in ipairs(self.children or {}) do 
		local childgameobj = child:call("get_GameObject")
		if childgameobj then
			o.physicscloth = o.physicscloth or lua_find_component(childgameobj, "app.PhysicsCloth") or nil
			o.chain = o.chain or lua_find_component(childgameobj, "via.motion.Chain") or nil
			if (o.physicscloth or o.chain) then break end
		end
	end
	
	--Check for parent container object:
	if self.children and (self.components_named.DummySkeleton or self.components_named.CharacterController or (self.mesh and self.components_named.FigureObjectBehavior)) then --(isRE2 or isRE3) and 
	--if self.children and self.components_named.Motion and 
		local candidate
		for i, child in ipairs(self.children) do  
			held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{xform=child} 
			local other = held_transforms[child] 
			--log.info("checking " .. self.name .. " vs " .. other.name)
			--if other and ((other.layer and other.body_part == "Body") or (other.display and other.children and ((isRE2 or isRE3) and ((other.name:find("igure")) or (other.mesh and not other.mesh:call("getMesh")))))) then 
			if other and ( (other.layer or (other.mpaths and not self.mpaths))) and other.gameobj then --(other.body_part == "Body")
				candidate = other 
				if candidate.body_part == "Body" and candidate.gameobj:call("get_Draw") then 
					break 
				end
			end
		end
		
		if candidate then 
			if current_figure and isRE3 then
				--self.xform:call("set_Parent", current_figure.xform)
				self.parent = self.xform:call("get_Parent")
				self.parent_org = self.parent
				current_figure.children = get_children(current_figure.xform)
			end
			self.alt_names = merge_tables(self.alt_names or {}, candidate.alt_names or {})
			self.em_name = candidate.em_name
			self.mesh_name = self.mesh_name or candidate.mesh_name
			self.body_part = "Body"
			self.force_center = true
			re2_figure_container_obj = self
			base_mesh = candidate
			selected = self
			self.pairing = candidate
			candidate.pairing = self
			self.mesh_name_short = self.mesh_name_short or candidate.mesh_name_short
			if not self.mpaths then
				--self.mesh = candidate.mesh
				--self.materials = candidate.materials
				--self.mpaths = candidate.mpaths
				self:set_materials(nil, {mesh=candidate.mesh})
			end
		end
	end
	
	--setup figure mode:
	if (figure_mode or forced_mode) and self.layer and ((self.body_part == "Body") or (self.body_part == "Face") or self.is_wep) then 
	-- and (self.body_part ~= "Hair") then --or cutscene_mode [cutscene_mode animations are controlled by ActorMotion, which is not handled by this script)
		if not next(RSCache.motbank_resources or {})  then 
			return --too early, abort
		end
		self.mbank_idx = args.mbank_idx or 1
		self.mlist_idx = args.mlist_idx or 1
		self.mot_idx = args.mot_idx or 1
		self.mots_ids = args.mots_ids or {}
		self.alt_names = args.alt_names or self.alt_names or {}
		self.motbanks = args.motbanks or self.motbanks or {}
		self.motbank_names = args.motbank_names or self.motbank_names or {}
		self.motlist_names = args.motlist_names or {}
		self.motion_names = args.motion_names or {}
		self.motion_names_w_frames = args.motion_names_w_frames or {}
		self.paused = args.paused
		self.play_speed = self.layer:call("get_Speed")
		self.frame = args.frame or 0
		self.end_frame = args.end_frame or self.frame
		self.matched_banks_count = args.matched_banks_count or 0
		self.face_mode = args.face_mode or (self.body_part == "Face")
		this_figure_via_motions_count = this_figure_via_motions_count + 1
		self.frame = self.frame or self.layer:call("get_Frame")
		self.end_frame = self.end_frame or self.layer:call("get_EndFrame")
		self.running = self.running or (not self.layer:call("get_TreeEmpty"))
		--self.dynamic_bank = args.dynamic_bank or self.dynamic_bank or self.motion:call("getDynamicMotionBank", 0)
		self.sync = EMVSettings.sync_face_mots or nil
		self.cog_init_transform = (self.cog_joint and self.cog_joint:call("get_WorldMatrix")) or self.init_worldmat		
		--self.cached_banks = {}
		--self.all_mots = {}
		
		self.em_name = args.em_name or self.name:match("^[ep][ml]%d%d%d%d")
		if current_figure then
			if self.cog_init_transform then
				local pos = current_figure.xform:call("get_Position")
				self.cog_init_transform[3] = Vector3f.new(pos.x, self.cog_init_transform.y, pos.z)
			end
			current_figure.em_name = self.em_name or current_figure.em_name
		end
		
		self.em_name = self.em_name or (current_figure and current_figure.em_name)
		self.em_name = self.em_name and self.em_name:lower()
		
		if isRE8 and self.em_name then 
			self.alt_names[self.em_name] = true
		elseif isRE2 and figure_mode then
			self.alt_names[self.figure_name:lower():gsub("_normal", ""):gsub("figure_", "")] = true
		end
		
		if not isRE8 then
			if self.em_name and self.em_name:find("[ep][ml]%d%d") then 
				self.alt_names[self.em_name:sub(1,(self.em_name:find("[ep][ml]%d%d") or 1)+3)] = true 
			end
		end
		
		if self.mesh_name_short then 
			--set up alt names
			if isRE2 or isRE3 then --and not self.mesh_name_short:find("em%d%d%d%d")
				self.alt_names[self.mesh_name_short:sub(1, -2)] = true
				if self.body_part == "Body" then 
					self.alt_names[self.mesh_name_short:sub(1, -3)] = true
				end
				if self.mesh_name_short:find("em%d%d%d%d") then 
					self.alt_names[self.mesh_name_short:sub(1, -3) .. "0"] = true
				end
				if self.face_mode then
					local alt = self.mesh_name_short:find("[ep][ml]%d%d5%d")
					alt = alt and (self.mesh_name_short:sub(1, alt+2) .. "0" .. self.mesh_name_short:sub(alt+4, -2))
					if alt then 
						self.alt_names[alt] = true 
						self.alt_names[alt:sub(1, -2)] = true
					end
				end
			else
				if isRE8 then 
					self.alt_names[self.mesh_name_short:sub(1,7)] = true
				else
					self.alt_names[self.mesh_name_short] = true
				end
				if isDMC and self.mesh_name_short:find("_11") then
					local name = self.mesh_name_short:gsub("_11", "_01")
					self.alt_names[name] = true
				end
			end
		end
		
		self.mesh_name_short = self.mesh_name_short or self.em_name or self.name or ""
		
		--load json data
		local sd = EMVCache.savedata[self.key_hash]
		if sd and sd.mbank_idx and EMVSettings.use_savedata and sd.matched_banks and next(sd.matched_banks) then
			self.mbank_idx, self.mlist_idx, self.mot_idx = sd.mbank_idx, sd.mlist_idx, sd.mot_idx
			self.force_center, self.aggressively_force_center = sd.force_center, sd.aggressively_force_center
			self.matched_banks = merge_tables(sd.matched_banks, self.matched_banks)
			sd.matched_banks = self.matched_banks
			self.matched_banks_count = get_table_size(self.matched_banks)
			self.display = sd.display
			log.info("Loaded save data for " .. self.name)
		end
		
		if res.alt_names then --merge manually-specified alternate names list
			for em_name, sub_table in pairs(res.alt_names) do
				if self.mesh_name_short:find(em_name) then -- or em_name:find(self.mesh_name_short) then 
					for key, tbl in pairs(sub_table) do
						if key==self.body_part or key=="exclude" then 
							for i, extra_name in ipairs(tbl) do
								if key=="exclude" then
									self.excluded_names = self.excluded_names or {}
									self.excluded_names[extra_name] = true
								else
									self.alt_names[extra_name] = true
								end
							end
						end
					end
				end
			end
		end
		
		self:get_current_bank_name()
		--self:build_banks_list()
		
		if not forced_mode then --or not self.running  then
			if self.savedata then
				if self.mbank_idx > self.matched_banks_count then 
					self:change_motion(self:shuffle())
				else
					self:set_motionbank(self.mbank_idx)
					if not isRE8 then 
						self:change_motion(self.mlist_idx, self.mot_idx) 
					end
				end
			elseif not pre_cached_banks then
				self:set_motionbank(self.mbank_idx, self.mlist_idx, self.mot_idx)
			end
		end
		self:update_banks()
	end
	
	if isDMC and figure_mode and self.name:find("03_Transparent") then --this thing keeps acting weird and glowing
		--deferred_calls[self.gameobj] = { func="destroy", args=self.gameobj }
		self.display = false
		self:toggle_display()
	end
	
	--Update named vars:
	if forced_mode and (forced_mode~=self) and (forced_mode.xform==self.xform) then
		self = merge_tables(self, forced_mode, true)
		forced_mode = self
	end
	if current_figure and (current_figure~=self) and (current_figure.xform==self.xform) then
		self = merge_tables(self, current_figure, true)
		current_figure = self
	end
	if selected and (selected~=self) and (selected.xform==self.xform) then
		self = merge_tables(self, selected, true)
		selected = self
	end
	if base_mesh and (base_mesh~=self) and (base_mesh.xform==self.xform) then
		self = merge_tables(self, base_mesh, true)
		base_mesh = self
	end
	if re2_figure_container_obj and (re2_figure_container_obj~=self) and (re2_figure_container_obj.xform==self.xform) then
		self = merge_tables(self, re2_figure_container_obj, true)
		re2_figure_container_obj = self
	end
	if ev_object and (ev_object~=self) and (ev_object.xform==self.xform) then
		self = merge_tables(self, ev_object, true)
		ev_object = self
	end
	if (self.total_objects_idx and total_objects[self.total_objects_idx]) and (total_objects[self.total_objects_idx]~=self) and (total_objects[self.total_objects_idx].xform==self.xform) then
		self = merge_tables(self, total_objects[self.total_objects_idx], true)
		total_objects[self.total_objects_idx] = self
	end
	
	held_transforms[self.xform] = self
	self.is_AnimObject = true
	
	--setup cutscene mode:
	if self.components_named.Timeline and (self.components_named.CutSceneMediator or self.components_named.CutScenePlaySetting) then  
		self.timeline = self.components_named["Timeline"]
		self.mediator = self.components_named["CutSceneMediator"]
		self.endframe = self.timeline and self.timeline:call("get_EndFrame")
		self.cutscene_name = self.mediator and self.mediator:call("get_CutSceneID")
		local bind_gameobjects = lua_get_system_array(self.timeline:call("get_BindGameObjects") or {}, false, true)
		if bind_gameobjects then
			self.bind_gameobjects = {}
			for i, gameobj in ipairs(bind_gameobjects) do
				local xform = gameobj.call and ({pcall(gameobj.call, gameobj, "get_Transform")})
				if xform and xform[1] then
					
					table.insert(self.bind_gameobjects, held_transforms[ xform[2] ] or GameObject:new_AnimObject{gameobj=gameobj, xform=xform[2]})
				end
			end
			
			if self.bind_gameobjects[1] and (not ev_object or (#self.bind_gameobjects > #ev_object.bind_gameobjects)) then
				ev_object = self
				pre_cached_banks = ev_object and nil 
			end
		end
	end
	
	return self
end

GameObject.clear_AnimObject = function(self, xform)
	xform = xform or self.xform
	self = self or held_transforms[xform]
	--log.info("Clearing AnimObject " .. (xform and xform:get_address() or ""))
	lights[xform] = nil
	non_lights[xform] = nil
	lightsets[xform] = nil
	if current_figure and xform == current_figure.xform then current_figure = nil end 
	if selected and xform == selected.xform then selected = nil end
	if forced_mode and xform == forced_mode.xform then forced_mode = nil end
	if base_mesh and xform == base_mesh.xform then base_mesh = nil end
	if re2_figure_container_obj and xform == re2_figure_container_obj.xform then re2_figure_container_obj = nil end
	if ev_object and xform == ev_object.xform then ev_object = nil end
	if player and player.xform == xform then player = nil end
	if self and self.total_objects_idx and total_objects[self.total_objects_idx] and xform == total_objects[self.total_objects_idx].xform then 
		table.remove(total_objects, self.total_objects_idx)
		log.info("Removed idx " .. self.total_objects_idx .. " from total_objects, now at count " .. #total_objects)
		if #total_objects == 0 then 
			EMV.clear_figures()
		else
			local idx = contains_xform(imgui_anims, self.xform)
			if idx then 
				table.remove(imgui_anims, idx) 
				log.info("Removed idx " .. idx .. " from imgui_anims, now at count " .. #imgui_anims)
			else
				idx = contains_xform(imgui_others, self.xform)
				if idx then 
					table.remove(imgui_others, idx)
					log.info("Removed idx " .. idx .. " from imgui_others, now at count " .. #imgui_others)
				end
			end
		end
	end
end

local updates_this_frame = {}

GameObject.update_AnimObject = function(self, is_known_valid, fake_forced_mode)
	
	if self:update(is_known_valid) then		
		local forced_mode = fake_forced_mode or forced_mode --lets this object be updated as though it were in forced mode
		if figure_mode or forced_mode then --or cutscene_mode then 
			
			self.selected = (selected == self) or nil
			
			local selected_frame = selected and selected.running and selected.layer:call("get_Frame")
			
			if selected_frame and selected_frame < 2 and selected_frame > 0 and selected.end_frame > 10 then
				self:reset_physics() --for resetting physics on objects when the animation is looped w/o change_motion
			end
			
			self.em_name = self.name:match("^[ep][ml]%d%d%d%d") or (current_figure and current_figure.em_name) or current_em_name --or self.mesh_name_short or self.name 
			
			if self.layer and self.motbanks then 
				
				--if (not self.cant_find_motbanks or self.cant_find_motbanks < 3) and (not self.motbanks or not self.motbank_names or not self.motbank_names[2]) then
				if (not self.cant_find_motbanks ) and (not self.motbanks or not self.motbank_names or not self.motbank_names[2]) then --or (toks % 150 == 0)
					self:update_components({cant_find_motbanks=true})
					self.cant_find_motbanks = not self.motbanks and true or nil
					--[[self.update_retries = self.update_retries or 0
					self.update_retries = self.update_retries + 1
					if self.update_retries == 5 then 
						EMVCache.global_cached_banks, global_cached_banks, pre_cached_banks = {}, {}, {}
						RN.loaded_resources = false
						if forced_mode then
							forced_mode = total_objects[1]
							forced_mode.init_transform = forced_mode.xform:call("get_WorldMatrix")
						end
					end]]
					--self.cant_find_motbanks = not self.motbanks and (self.cant_find_motbanks and (self.cant_find_motbanks + 1) or 0) or nil
				end
				
				if self.changed_bank then --delayed bank change
					self.changed_bank = nil
					if not static_funcs.setup_mbank_method then
						log.info("Changing " .. self.name .. " motion after bank change " .. self.mbank_idx .. " " .. self.mlist_idx .. " " .. self.mot_idx)
						self:update_banks((pre_cached_banks ~= nil))
						self:change_motion()
					end
				end
				
				if self.cached_banks and not self.running and (not self.retry_count or (self.retry_count < 3)) then
					self.retry_count = self.retry_count or 0
					--log.info("RETRYING MOT CHANGE")
					self:change_motion(self.mlist_idx, self.mot_idx, true)
					self.retry_count = self.retry_count + 1
				elseif self.running then
					self.retry_count = nil
				end
				
				if not self.current_bank_name or not self.mbank_idx or not self.cached_banks or not global_cached_banks[self.current_bank_name] then 
					self:get_current_bank_name()
				end
				self.do_prev, self.do_next, self.do_shuffle, self.do_restart = nil
				self.running = not self.layer:call("get_TreeEmpty") or nil
				self.play_speed = self.layer:call("get_Speed")
				self.frame = self.layer:call("get_Frame")
				self.end_frame = math.floor(self.layer:call("get_EndFrame"))
				self.puppetmode = forced_mode and self.mfsm2 and self.mfsm2:call("get_PuppetMode")
				self.anim_finished, self.anim_maybe_finished = nil
				
				--self.stop_at_motion_end = self.motion:call("get_StopAtMotionEnd")
				if not self.looping then 
					self.motion:call("set_StopAtMotionEnd", true)
				else
					self.motion:call("set_StopAtMotionEnd", false)
				end
				
				if (figure_mode or forced_mode) and (self.body_part == "Body" or self.face_mode) and (self.puppetmode or (self ~= player)) then
					if self.play_speed and self.end_frame and self.frame then
						local frames_in = (self.play_speed < 0 and (self.end_frame - self.frame)) or self.frame
						
						self.anim_finished = ((frames_in >= self.end_frame) and self.running and (self.end_frame > 10.0)) or nil
						
						self.anim_maybe_finished = (frames_in ~= 0 and (self.end_frame > 1) and (frames_in + (0.1 * self.play_speed)) >= self.end_frame - 1) or self.anim_finished or nil
						if (self.anim_maybe_finished or self.loop_a) and not self.looping and self.start_time and (math.abs(self.play_speed) == 1) and (uptime - self.start_time) > 5.0 then --1 * (self.end_frame / 60
							self.anim_finished = true
						end
						--if self.anim_finished or self.anim_maybe_finished then 
						--	log.info(self.name .. " " .. self.frame .. " " .. self.end_frame .. " " .. frames_in)
						--end
					else
						log.info(self.name .. " is missing " .. tostring(self.play_speed) .. " " .. tostring(self.end_frame) .. " " .. tostring(self.frame))
					end
				end
				
				if forced_mode and self.mlist_idx and self.motlist_names then --confirm mlist and mot names in their comboboxes
					local motion_node = self.layer:call("get_HighestWeightMotionNode")
					local mot_name = motion_node and motion_node:call("get_MotionName")
					local mbank = motion_node and self.motion:call("findMotionBank(System.UInt32, System.UInt32)", motion_node:call("get_MotionBankID"), motion_node:call("get_MotionBankType"))
					--local mbank = self.active_mbanks and (self.active_mbanks[ self.motlist_names[self.mlist_idx] ] or self.active_mbanks[ tostring(self.mlist_idx-1) ])
					--mbank = mbank and self.motion:call("getActiveMotionBank", mbank)
					--if self.name == "pl1000" then log.info("0") end
					if mbank then 
						local motlist = mbank:call("get_MotionList")
						local motlist_name = motlist and motlist:call("ToString()"):match("^.+%[@?(.+)%]") 
						local mlist_idx_new = (motlist_name and find_index(self.motlist_names, motlist_name))
						--if self.name == "pl1000" then log.info("A") end
						if mlist_idx_new then
							--if self.name == "pl1000" then log.info("B") end
							local mot_idx_new = (mot_name and self.motion_names and find_index(self.motion_names[mlist_idx_new], mot_name))
							if mot_idx_new then 
								--if self.name == "pl1000" then log.info("C") end
								self.mlist_idx = mlist_idx_new
								self.mot_idx = mot_idx_new
							end
						end
					end
				end
				
				if self.synced and self.running and self.synced.end_frame and self.frame > 5 then 
					if toks % 4 == 0 and ((self.synced.end_frame ~= self.end_frame) ) then --or (self.frame > self.synced.frame+15) or (self.frame < self.synced.frame-15)) then 
						self.synced = nil
					end
				end
				
				if not reframework:is_drawing_ui() and (self.display) and (self.anim_finished and not self.looping and (not self.synced or (self == selected))) then --((EMVSettings.seek_all and not self.synced) or selected == self)
					self:change_motion(self:next_motion())
				end
				
				--[[if self.joints and (self.show_joints or (self.poser and self.poser.is_open)) then
					self.joint_positions = {}
					for i, joint in pairs(self.joints) do 
						if sdk.is_managed_object(joint) then 
							self.joint_positions[joint] = { joint:call("get_LocalMatrix"), joint:call("get_WorldMatrix") }
						else
							self.joint_positions, self.show_joints, self.poser = nil
						end
					end
				end]]
				
				if self.savedata then --and self.start_time and (uptime - self.start_time) < 0.01 then
					self.savedata.mbank_idx = self.mbank_idx
					self.savedata.mlist_idx = self.mlist_idx
					self.savedata.mot_idx = self.mot_idx
					--[[EMVSettings.current_loaded_ids[current_figure.name] = EMVSettings.current_loaded_ids[current_figure.name] or {}
					EMVSettings.current_loaded_ids[current_figure.name][self.name] = { mbank_idx=self.mbank_idx, mlist_idx=self.mlist_idx, mot_idx=self.mot_idx, display=self.display, force_center=self.force_center }]]
				end
			end
		end
		if cutscene_mode then 
			if self.keep_on then
				self.display = true
				if self.parent_forced and self.parent ~= self.parent_forced then
					deferred_calls[self.xform] = { {lua_object=self, method=GameObject.set_parent, args=self.parent_forced }, {lua_object=self, method=GameObject.toggle_display} }
				end
				if self.gameobj:call("get_Draw") == false then 
					self:toggle_display()
				end
			end
		end
		if self.force_center and (pre_cached_banks == nil) then
			self:center_object()
		end
		updates_this_frame[self.xform] = nil
	else
	--	log.info("Removed held transform: " .. self.name .. " " .. self.xform:get_address())
	end
end

GameObject.activate_forced_mode = function(self)
	
	if not figure_mode and not cutscene_mode then
		self.init_transform = forced_mode and forced_mode.init_transform or self.init_transform --keep old init transform
		self = GameObject.new_AnimObject(nil, {xform=self.xform}) --recreate object with class from this script
		forced_mode = self
		current_figure = self
		total_objects, imgui_anims, imgui_others = {}, {}
		--held_transforms, total_objects, imgui_anims, imgui_others = {[self.xform]=self}, {self}, {}, {} --
		self.forced_mode_center = self.xform:call("get_WorldMatrix")
		if self.components_named.PlayerLookAt then 
			self.PlayerLookAt = self.components_named.PlayerLookAt
		end
		for i, xform in ipairs(sort(find("via.render.SpotLight"), self.xform:call("get_Position"), 10)) do
			if i > 50 then break end
			table.insert(total_objects, held_transforms[xform] or GameObject:new_AnimObject{xform=xform, index=#total_objects})
			held_transforms[xform] = total_objects[#total_objects]
		end
	end
	
	selected = self or selected
	
	for i, child in ipairs(self.children or {}) do
		local object = held_transforms[child] or GameObject:new_AnimObject{xform=child}
		table.insert(total_objects, object)
	end
	
	--[[if not self.motbank_names then
		self:update_components()
	end]]
	--deferred_calls[self.gameobj] = {lua_object=self, method=GameObject.update_components}
	--merged_objects = (nearby_lights and merge_indexed_tables(total_objects, nearby_lights)) or total_objects
	--total_objects = (nearby_lights and merge_indexed_tables(total_objects, nearby_lights)) or total_objects
	
	--self:change_motion(self:shuffle())
	--deferred_calls[self.gameobj] = {lua_object=self, method=change_motion, args={self:shuffle()}}
end

GameObject.build_banks_list = function(self)
	log.info("Building banks list "  .. self.name)
	self.matched_banks_count = 0
	self.matched_random_limit = 0
	self.active_mbanks = {}
	self.matched_banks = self.matched_banks or {}
	self.motbanks = self.motbanks or {}
	self.motbank_names = {}
	self.cached_banks = {}
	self.all_mots = {}
	
	--Find the matched banks:
	self.em_name = self.em_name or current_em_name
	local object_name = (isRE8 and self.em_name and self.em_name:lower()) or (self.mesh_name_short and self.mesh_name_short:lower()) or self.name:lower()
	for bank_name, bank in pairs(RSCache.motbank_resources or {}) do
		if global_cached_banks[bank_name] then 
			if self:check_bank_name(bank_name, object_name) then --and insert_if_unique(self.motbank_names, bank_name) then
				self.matched_banks[bank_name] = bank
			end
		end
	end
	
	if self.key_hash then
		EMVCache.savedata[self.key_hash] = EMVCache.savedata[self.key_hash] or {
			cb_data = {},
			matched_banks = self.matched_banks,
			display = self.display,
			force_center=self.force_center,
			aggressively_force_center=self.aggressively_force_center,
			name = self.key_name --(current_figure and current_figure.name or "") .. self.name_w_parent .. " (" .. self.mesh_name_short .. ")",
		}
		self.savedata = EMVCache.savedata[self.key_hash]
	end
	
	self.matched_banks_count = get_table_size(self.matched_banks)
	
	--Make ordered list with matched banks first:
	local mb_names = {}
	for bank_name, bank in orderedPairs(self.matched_banks) do
		if global_cached_banks[bank_name] and not mb_names[bank_name] then
			mb_names[bank_name] = true
			self.motbanks[bank_name] = bank
			table.insert(self.motbank_names, bank_name)
		end
	end
	
	--And then the rest, in alphebetical order:
	for bank_name, bank in orderedPairs(RSCache.motbank_resources) do
		if global_cached_banks[bank_name] and not mb_names[bank_name] and not global_cached_banks[bank_name].is_dummy then
			mb_names[bank_name] = true
			self.motbanks[bank_name] = bank
			table.insert(self.motbank_names, bank_name)
		end
	end
	
	--set up dictionary of ActiveMotionBanks (loaded motlists) to know which index to select from:
	local active_mbanks_raw = lua_get_system_array(self.motion:call("get_ActiveMotionBank")) or {}
	for i, mbank in ipairs(active_mbanks_raw) do
		local motlist = mbank:call("get_MotionList")
		local motlist_name = (motlist and motlist:call("ToString()"):match("^.+%[@?(.+)%]")) or tostring(i)
		self.active_mbanks[motlist_name] = i-1
	end
	
	--Set up mot indexes (for shuffle):
	local cb_names = {}
	for i, bank_name in ipairs(self.motbank_names) do  
		local cb = global_cached_banks[bank_name] --deep_copy(global_cached_banks[bank_name])
		if cb and not cb.is_dummy and cb.motlist_names[1] and not cb_names[bank_name] then 
			cb_names[bank_name] = true
			local cached_bank = self:customize_cached_bank(cb)
			table.insert(self.cached_banks, cached_bank)
			cached_bank.mots_ids = cached_bank.mots_ids or {}
			for j, motlist in ipairs(cached_bank.mots_ids) do
				for k, mot in ipairs(motlist) do
					table.insert(self.all_mots, table.pack(#self.cached_banks, j, k, mot[4]))
				end
			end
		end
		if #self.cached_banks == self.matched_banks_count then 
			self.matched_random_limit = #self.all_mots
		end
	end
	
	--self.motion:call("setDynamicMotionBankCount", 0)
	
	if self.matched_random_limit == 0 then
		self.matched_random_limit = #self.all_mots
	end
	
	--add or update imgui_anims
	imgui_anims = imgui_anims or {}
	local idx = contains_xform(imgui_anims, self.xform, true)
	if idx then 
		imgui_anims[idx] = self
	else
		table.insert(imgui_anims, self)
	end
end

GameObject.center_object = function(self)
	
	--log.info(tostring(self.cog_joint and self.cog_joint.call and is_valid_obj(self.xform)) .. " " .. tostring(self.start_time) .. " " .. tostring(self.cog_joint) .. " ")
	self.cog_joint = self.xform:call("getJointByName", cog_names[game_name])
	
	if self.cog_joint and self.cog_joint.call and is_valid_obj(self.xform) then 
		
		self.center = self.center or self.cog_joint:call("get_BaseLocalPosition")
		local org_cog_pos = self.cog_joint:call("get_LocalPosition")
		self.last_cog_pos = org_cog_pos or self.last_cog_pos
		
		if self.active and forced_mode then 
			self.forced_mode_center = self.xform:call("get_WorldMatrix")
			self.init_worldmat = self.xform:call("get_WorldMatrix")
			--self.cog_init_transform = self.cog_joint:call("get_WorldMatrix")
		end
		
		if self.start_time  then
			if self.cog_joint then 
				--log.info("centering " .. self.name)
				local do_reset_pos = self.do_next or self.do_prev or ((uptime - self.start_time < 0.01) and self.running and self.layer:call("get_Running")) or (self.anim_maybe_finished and self.end_frame > 10)
				do_reset_pos = do_reset_pos and ((player ~= self) or self.puppetmode)
				if not self.init_cog_offset or (do_reset_pos and (not (self.loop_a or self.loop_b) or (isRE3 and selected.delayed_seek)))  then
					local init_cog_offset = self.center - org_cog_pos
					--[[if not (isDMC) then
						local parent = self.xform
						while parent do 
							init_cog_offset = (init_cog_offset - parent:call("get_LocalPosition"))
							parent = parent:call("get_Parent")
						end
					end]]
					self.init_cog_offset = init_cog_offset
					if forced_mode and self.forced_mode_center and (self.anim_finished or self.do_next or self.do_prev) then -- and ((self.xform:call("get_Position") - self.forced_mode_center[3]):length() > 2.5) then 
						self.xform:call("set_Position", self.forced_mode_center[3])
						--self.xform:call("set_Rotation", self.forced_mode_center:to_quat())
					elseif isRE3 and self.init_worldmat and self.anim_finished or self.do_next or self.do_prev or (self.xform:call("get_Position"):length() > 5.0) then 
						--if not (self.anim_maybe_finished and not self.anim_finished) or (self.last_cog_pos:length() > 3.0) then 
						--if isRE3 then
							self.xform:call("set_LocalPosition", self.init_worldmat[3])
							self.xform:call("set_LocalRotation", self.cog_joint:call("get_BaseLocalRotation"))
							self.xform:call("set_Position", self.init_worldmat[3])
						--elseif isRE8 then
						--	self.xform:call("set_Position", current_figure.xform:call("get_Position"))
						--end
					end
				end
				
				if forced_mode and self.forced_mode_center then 
					if self.aggressively_force_center then
						self.cog_joint:call("set_Position", self.forced_mode_center[3] + self.center)
					else
						--self.cog_joint:call("set_LocalPosition", new_pos)
					end
				elseif not isRE3 or (self.aggressively_force_center or (self.init_cog_offset and self.init_cog_offset:length() > 10)) then --RE3 only centers aggressively or when figure gets too far away
					local new_pos =  (isRE3 and self.cog_init_transform[3]) or self.center
					if mathex and not self.aggressively_force_center and self.parent and self.init_cog_offset then 
						new_pos = org_cog_pos + self.init_cog_offset
						local parent_matrix = isRE8 and Matrix4x4f.identity() or self.parent:call(isRE2 and "get_WorldMatrix" or "get_LocalMatrix")
						local transformed_pos = mathex:call("transform(via.vec3, via.mat4)", new_pos, parent_matrix)
						if not self.is_sel_obj then
							transformed_pos.y = new_pos.y
						end
						new_pos = transformed_pos
					end
					--[[if forced_mode then 
						--dont sink below ground
					end]]
					self.cog_joint:call(isRE8 and "set_LocalPosition" or "set_Position", new_pos)
				end
			end
			
			--fix facial anims on body
			if isRE2 or isRE3 then
				self.spine_joint = ((isRE2 or isRE3) and (self.body_part == "Body")) and (self.spine_joint or self.xform:call("getJointByName", "spine_2"))
				if self.spine_joint then 
					if self.spine_joint:call("get_LocalPosition"):length() > 3 then
						self.spine_joint_center = self.spine_joint_center or self.spine_joint:call("get_BaseLocalPosition")
						self.spine_joint:call("set_LocalPosition", self.spine_joint_center)
						self.spine_joint:call("set_LocalRotation", Quaternion.new(1,0,0,0))
					else
						self.spine_joint_center = nil
					end
				end
			end
		end
	end
end

GameObject.change_motion = function(self, mlist_idx, mot_idx, is_searching_sync, interp_frames) --sync is started in here automatically, only when a mot change is done manually
	if not self.cached_banks then return end
	local cached_bank = self.cached_banks[self.mbank_idx] --self:customize_cached_bank(global_cached_banks[ self.motbank_names[self.mbank_idx] ])
	mlist_idx, mot_idx = convert_mot_ids(cached_bank, mlist_idx or self.mlist_idx, mot_idx or self.mot_idx)
	self.mlist_idx, self.mot_idx = mlist_idx or 1, mot_idx or 1
	
	if (figure_mode or forced_mode) and self.motion and not self.changed_bank and self.mots_ids then
		
		log.info("CM: Setting " .. self.name .. " motion to idxes " .. tostring(self.mbank_idx) .. " " .. tostring(self.mlist_idx) .. " " .. tostring(self.mot_idx))
		
		interp_frames = interp_frames or 10
		if not (self.mots_ids[mlist_idx] and self.mots_ids[mlist_idx][mot_idx] and self.mots_ids[mlist_idx][mot_idx][2]) then 
			mlist_idx, mot_idx = convert_mot_ids(cached_bank, -1, -1)
		end
		
		if cached_bank and cached_bank.mots_ids[mlist_idx] and cached_bank.mots_ids[mlist_idx][mot_idx] then
			self.motion:call("set_TargetBankType(System.UInt32)",  cached_bank.mots_ids[mlist_idx][mot_idx][3])
			cached_bank.mots_ids[mlist_idx][1][5] = cached_bank.mots_ids[mlist_idx][1][5] and math.floor(cached_bank.mots_ids[mlist_idx][1][5])
		end
		
		local mots_ids = self.mots_ids[mlist_idx] and self.mots_ids[mlist_idx][mot_idx] and self.mots_ids[mlist_idx][mot_idx]
		local mlist = mots_ids and mots_ids[1] or 0
		local mot = mots_ids and mots_ids[2] or 0
		
		local start_frame = ((self.play_speed > 0.0) and 0.0) or (mots_ids and (mots_ids[4] - 1.0))
		--local try, out = pcall(self.layer.call, self.layer, "changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)", mlist, mot, start_frame or 0, interp_frames, 1, 0)
		
		self.layer:call("changeMotion(System.UInt32, System.UInt32, System.Single, System.Single, via.motion.InterpolationMode, via.motion.InterpolationCurve)", mlist, mot, start_frame or 0, interp_frames, 1, 0)
		--self.layer_output = self.motion:call("continueMotionOnSeparateLayer", 0, 1, 0, 0, 1.0, 0)
		
		if EMVSettings.sync_face_mots and self.selected and (self.sync and not (forced_mode or self.puppetmode)) and not is_searching_sync and (self.face_mode or (self.body_part == "Body")) and self.end_frame > 10 then 
		--and EMVSettings.seek_all  --and not self.synced and self.running 
			if self.display and self.cached_banks[self.mbank_idx] and self.cached_banks[self.mbank_idx].mots_ids[self.mlist_idx] and self.cached_banks[self.mbank_idx].mots_ids[self.mlist_idx][self.mot_idx] then
				local end_frame = self.cached_banks[self.mbank_idx].mots_ids[self.mlist_idx][self.mot_idx][4]
				local mot_name = self.cached_banks[self.mbank_idx].motion_names[self.mlist_idx][self.mot_idx] 
				local exclude_keyword = "jack"
				exclude_keyword = not self.current_bank_name:find(exclude_keyword) and exclude_keyword
				for i, object in ipairs(imgui_anims) do 
					if (object ~= self) and object.display and object.sync and (object.body_part ~= self.body_part) then --and not object.body_part == "Other" then 
						local face_object, fc_mbank_idx, fc_mlist_idx, fc_mot_idx, frames, all_mots_idx = find_matching_mot(self, object, end_frame, mot_name, exclude_keyword)
						if face_object then --and face_object ~= selected 
							local face_cb = face_object.cached_banks[fc_mbank_idx]
							if not pcall(function()
								log.info("Matched mots:\n" .. self.name .. " -> " .. self.motbank_names[self.mbank_idx] .. " -> " .. self.motlist_names[self.mlist_idx] .. " -> " .. self.motion_names[self.mlist_idx][self.mot_idx] .. " (" .. end_frame .. " frames) " .. "[" .. self.mbank_idx .. "," .. self.mlist_idx .. "," .. self.mot_idx .. "]" .. "\n" .. face_object.name .. " -> " .. face_object.motbank_names[fc_mbank_idx] .. " -> " .. face_cb.motlist_names[fc_mlist_idx] .. " -> " .. face_cb.motion_names[fc_mlist_idx][fc_mot_idx] .. " (" .. frames .. " frames)" .. "[" .. fc_mbank_idx .. "," .. fc_mlist_idx .. "," .. fc_mot_idx .. "]. #" .. all_mots_idx .. " of " .. face_object.matched_random_limit or #face_object.all_mots)
							end) then 
								log.error("Error reading mot info " .. self.name) 
							end
							if face_object.mbank_idx ~= fc_mbank_idx then
								face_object:set_motionbank(fc_mbank_idx, fc_mlist_idx, fc_mot_idx, true)
							else
								face_object:change_motion(fc_mlist_idx, fc_mot_idx, true)
							end
							face_object.synced = self
							self.synced = face_object
							face_object.do_next, face_object.do_prev, face_object.do_shuffle = nil
							--imgui.text()
						end
					end
				end
			end
		end
		self.frame = 0
		self.start_time = uptime
		self.layer:call("set_Frame", 0)
		self.anim_finished, self.anim_maybe_finished = nil
		self:reset_physics()
		
		updates_this_frame[self.xform] = updates_this_frame[self.xform] or 0
		updates_this_frame[self.xform] = updates_this_frame[self.xform] + 1
		if updates_this_frame[self.xform] > 50 then 
		--	log.info(asdf .. 1234)
		end
		
		--if self.components_named.MotionFsm2 then
		--	deferred_calls[self.components_named.MotionFsm2] = {func="restartTree"}
		--end
		--[[if self.layer:call("get_EndFrame") <= 10.0 then 
			paused = true
			self:control_action( { paused=true })
		end]]
	end
end

GameObject.check_bank_name = function(self, name, object_name, quick_check)
	
	local lower_name = name:lower()
	local found_item = lower_name:find("[wis][ptm]%d%d") or lower_name:find("weap")
	local found_facial = lower_name:find("fac") or name:find("FCE") or (isDMC and lower_name:find("_[01]1")) or (isRE2 and lower_name:find("[pe][lm]%d%d5%d")) or (isRE3 and lower_name:find("[pe][lm]%d%d%d1"))
	local found_body =  lower_name:find("body") or ((isRE8 and lower_name:find("ch%d%d_")) or (isRE8 and not found_facial)) or ((isRE2 or isRE3) and lower_name:find("[pe][lm]%d%d%d0"))
	--(isRE8 and (lower_name:find("pl%d%d00") or lower_name:find("em%d%d00") or lower_name:find("barehand"))
	
	--if self.name == "Face" then log.info("Checking " .. lower_name .. " vs " .. object_name .. ",  found facial: " .. tostring(found_facial) .. ", found_body: " .. tostring(found_body)) end
	if self.body_part ~= "Other" and found_item then return false end
	if self.body_part == "Body" and found_facial  then return false end --or (isDMC and lower_name:find("%d%d%d%d_%d%d") and not lower_name:find("_10"))
	if (isRE2 or isRE3) and object_name:find("em%d%d%d") and lower_name:find("_[pe][ls]") then return false end
	if quick_check and self.face_mode and not found_facial and found_body then return false end
	if quick_check or (lower_name:find(object_name) and object_name:find(lower_name)) then return true end
	
	--if self.name == "em5801_shadow (shadow)" and name:find("em5801_") then
	--	re.msg_safe(("bad shadow bank " .. name), 1234142)
	--end
	
	local function is_excluded()
		if not self.excluded_names then return end
		for excluded_name, bool in pairs(self.excluded_names) do
			if lower_name:find(excluded_name) then 
				return true
			end
			if self.name == "em5801_shadow (shadow)" then 
				log.info(lower_name .. " does not have " .. excluded_name .. " in it")
			end
		end
	end
	
	--if self.name == "Face" then log.info("Checking " .. lower_name .. " vs " .. object_name .. ",  found facial: " .. tostring(found_facial) .. ", found_body: " .. tostring(found_body)) end
	if self.alt_names then
		for alt_name, value in pairs(self.alt_names) do 
			if lower_name:find(alt_name) then 
				if self.face_mode and found_facial then
					return not is_excluded()
				elseif self.body_part == "Body" and not found_facial and not found_item then --and found_body 
					return not is_excluded()
				elseif self.body_part == "Other" and found_item then
					return not is_excluded()
				end
			end
		end
	end
	--if self.name == "Face" then  log.info("nah") end
	
	return false
end

GameObject.control_action = function(self, args) --args = { paused, do_restart, do_seek, play_speed, current_frame, do_reset_gpuc, force_seek }
	--args.paused = args.paused or paused
	args.play_speed = args.play_speed or self.play_speed
	args.current_frame = args.current_frame or self.frame
	--log.info("running control action " .. logv(args))
	if args.do_reset_gpuc then 
		self:reset_physics()
	end	
	if self.layer then
		if args.paused ~= nil then
			self.motion:call("set_PlayState", bool_to_number[args.paused]) 
			if (args.paused == false) and (self.frame == 0) then 
				self:set_motionbank()
				--self:change_motion()
				deferred_calls[self.motion] = { {lua_object=self, method=GameObject.change_motion}, {func="set_PlayState", args=bool_to_number[args.paused]}, }
			end
		end
		if args.do_restart then 
			self.motion:call("resetAnimation")
		end
		self.layer:call("set_Frame", self.frame)
		--if EMVSettings.seek_all or (self == selected) then-- or (SettingsCache.affect_children and is_child_of(self, selected))  then 
			if args.do_seek then
				if selected == self and args.current_frame > self.end_frame then
					self.do_next = true
				elseif args.current_frame < 0 then --selected == self and 
					if args.current_frame < -40 then
						self.do_prev = true
					else
						self.layer:call("set_Frame", 0)
					end
				else
					self.layer:call("set_Frame", args.current_frame)
				end
				self:reset_physics()
			end
			self.layer:call("set_Speed", args.play_speed)
		--end
	end
	--[[if SettingsCache.affect_children and args.force_seek and self.children and EMVSettings.seek_all then
		for i, child in ipairs(self.children) do 
			held_transforms[child]:control_action(args)
		end
	end]]
	--if self.pairing then 
	--	self.pairing:control_action(args)
	--end
	EMVSetting_was_changed = nil
end

--Make a custom copy of the cached bank meant for only this body part (no face motlists in a body's matched bank)
GameObject.customize_cached_bank = function(self, cb)
	self.matched_banks = self.matched_banks or {}
	if EMVSettings.customize_cached_banks and cb and (self.body_part ~= "Hair") and self.matched_banks[cb.name] then 
		local cached_bank = {motlist_names={}, motion_names={}, mots_ids={}, name=cb.name,}
		for j, mlist_name in ipairs(cb.motlist_names) do
			if (isRE8 and mlist_name:find("msgmot")) or self:check_bank_name(mlist_name, (self.alt_names and self.alt_names[1]) or self.mesh_name_short or self.em_name or self.name, true) then
				table.insert(cached_bank.motlist_names, mlist_name)
				table.insert(cached_bank.motion_names, cb.motion_names[j])
				table.insert(cached_bank.mots_ids, cb.mots_ids[j])
			end
		end
		return cached_bank
	end
	return cb
end

GameObject.get_current_bank_name = function(self, no_check)
	
	if self.layer then
		local bank = self.motion:call("get_MotionBankAsset")
		if not bank then 
			--rando_bank = ({next(self.motbanks or {})})[2] or ({next(RSCache.motbank_resources or {})})[2] --NOT WORKING, FINDING DEAD BROKEN BANK OBJECTS SOMEHOW
			local rando_bank, found
			for key, value in pairs(RSCache.motbank_resources) do 
				if is_valid_obj(value) then
					rando_bank = value
					found = true
					break
				else
					--re.msg_safe("FOUND BROKEN MOTBANK " .. key, 1231441515)
					RSCache.motbank_resources[key] = create_resource(key, "via.motion.MotionBankResource", true)
				end
			end
			if found or is_valid_obj(rando_bank) then
				self.motion:call("set_MotionBankAsset", rando_bank) --set any random motionbank just so it can get started
				bank = self.motion:call("get_MotionBankAsset")
			end
		end
		bank = bank and bank:add_ref()
		self.current_bank_name = bank and bank:call("ToString()"):match("^.+%[@?(.+)%]")
		self.current_bank_name = self.current_bank_name and self.current_bank_name:lower()
		if bank and not no_check then
			RSCache.motbank_resources[self.current_bank_name] = RSCache.motbank_resources[self.current_bank_name] or bank
			--self.motbanks = self.motbanks or {}
			if not self.cached_banks then 
				self:build_banks_list()
			end
			if not global_cached_banks[self.current_bank_name] then
				self:build_banks_list()
				self:update_banks()
			end
			
			self.mbank_idx = find_index(self.motbank_names, self.current_bank_name) or 1
			self.mbank_idx_orig = self.mbank_idx_orig or self.mbank_idx
			RSCache.motbank_resources[self.current_bank_name] = bank
		end
		return self.current_bank_name
	end
end

GameObject.next_motion = function(self, mlist_idx, mot_idx)
	--log.info("next motion " .. " " .. self.name .. " " .. tics)
	self.anim_finished, self.anim_maybe_finished = nil
	if not self.mbank_idx then
		self:get_current_bank_name()
	end
	local new_mlist_idx = mlist_idx or self.mlist_idx or 1
	local new_mot_idx = mot_idx or self.mot_idx or 1
	local new_mbank_idx = self.mbank_idx or 1
	local next_idx = new_mot_idx + 1; 
	local prev_idx = new_mot_idx - 1; 
	local do_set_motionbank
	
	local do_prev, do_next = self.do_prev, self.do_next
	if (self.play_speed < 0.0) then
		do_prev, do_next = do_next, do_prev
	end
	
	if not self.motion_names or not self.motlist_names or not self.motbank_names or not self.motion_names[self.mlist_idx] then
		return 1, 1
	end
	
	if self.do_shuffle or not_started then
		--log.info("shuffling as part of next motion " .. self.name .. " " .. tics)
		new_mlist_idx, new_mot_idx = self:shuffle()
	else
		if do_prev then
			new_mot_idx = prev_idx
			if prev_idx == 0 and (not self.looping or #self.motion_names[self.mlist_idx] == 1) then 
				new_mlist_idx = new_mlist_idx - 1
				if new_mlist_idx == 0 then 
					new_mbank_idx = new_mbank_idx - 1
					if new_mbank_idx == 0 then 
						new_mbank_idx = ((self.matched_banks_count ~= 0) and self.matched_banks_count) or #self.motbank_names
					end
					do_set_motionbank = true
				end
			end
		else
			new_mot_idx = next_idx
			--if not self.motion_names[self.mlist_idx] or (next_idx > #self.motion_names[self.mlist_idx] and (not self.looping or #self.motion_names[self.mlist_idx] == 1)) then
			if next_idx > #self.motion_names[self.mlist_idx] and (not self.looping or do_next) then 
				new_mot_idx = 1
				new_mlist_idx = new_mlist_idx + 1
				if new_mlist_idx > #self.motlist_names then 
					new_mlist_idx = 1
					new_mbank_idx = new_mbank_idx + 1
					if (new_mbank_idx == self.matched_banks_count+1) or new_mbank_idx > #self.motbank_names then --continuous mode or next button will reset to mot 1 at the matched_banks_count
						new_mbank_idx = 1
					end
					do_set_motionbank = true
				end
			end
		end
	end
	
	if do_set_motionbank then --and not forced_mode then
		--log.info("setting " .. self.name .. " motionbank to idx " .. tostring(new_mbank_idx) .. " " .. tostring(new_mlist_idx) .. " " .. tostring(new_mot_idx))
		self:set_motionbank(new_mbank_idx, new_mlist_idx, new_mot_idx)
	end
	--self.mlist_idx, self.mot_idx = new_mlist_idx
	
	return new_mlist_idx, new_mot_idx
end

GameObject.set_motionbank = function(self, mbank_idx, mlist_idx, mot_idx, is_searching_sync, is_pre_cache)
	if (figure_mode or forced_mode) and self.layer then 
		
		mbank_idx = mbank_idx or self.mbank_idx
		local motbank_name = (is_pre_cache and RN.motbank_resource_names[mbank_idx]) or self.motbank_names[mbank_idx]
		local mb_asset = RSCache.motbank_resources[motbank_name]
		if mb_asset then
			--log.info("Setting motionbank " .. mbank_idx .. " " .. (motbank_name and (motbank_name .. " " .. tostring(mb_asset)) or "[No Name Found]") .. " for " .. self.name)
			self.old_dynamic_banks = self.old_dynamic_banks or {}
			local dyn_bank_count = self.motion:call("getDynamicMotionBankCount")
			if dyn_bank_count > 0 and not self.old_dynamic_banks[1] then 
				for i=1, dyn_bank_count do 
					local dbank = self.motion:call("getDynamicMotionBank", i-1)
					if dbank then
						local mbank = dbank:call("get_MotionBank")
						local mbank_name = mbank and (mbank:call("ToString()"):match("^.+%[@?(.+)%]") or tostring(i-1))
						if mbank_name then 
							self.old_dynamic_banks[mbank_name] = { i, dbank:add_ref()}
						end
					end
				end
			end
			
			if not self.is_sel_obj or (dyn_bank_count > 1) then
				self.motion:call("setDynamicMotionBankCount", 0) --dynamic motion banks allow the ActiveMotionBanks list to be polluted with old Motlists that were unloaded, but is critical for player control
			end
			
			--this shit just makes it T-pose and lose all motlists and mots:
			--[[if not self.old_dynamic_banks[mb_asset:call("ToString()"):match("^.+%[@?(.+)%]")] then
				local new_dbank = sdk.create_instance("via.motion.DynamicMotionBank"):add_ref() 
				if new_dbank then 
					new_dbank :call(".ctor")
					new_dbank:call("set_MotionBank", mb_asset)
					--self.motion:call("setDynamicMotionBankCount", get_table_size(self.old_dynamic_banks) + 1)
					self.motion:call("setDynamicMotionBankCount", 1)
					self.motion:call("setDynamicMotionBank", 0, new_dbank)
				end
			end]]
			
			self.layer:call("clearMotionResource")
			self.motion:call("set_MotionBankAsset", mb_asset) 
			
			if forced_mode and player and (self.xform == player.xform) and self.mfsm2 then 
				self.mfsm2:call("set_PuppetMode", true)
			end
			if mlist_idx or mot_idx then 
				self.mlist_idx, self.mot_idx = convert_mot_ids(global_cached_banks[self.motbank_names[mbank_idx]], mlist_idx, mot_idx)
			end
			
			self.mbank_idx = find_index(self.motbank_names, motbank_name) or mbank_idx
			if static_funcs.setup_mbank_method then 
				self.motion:call("setupMotionBank")
				self:change_motion(self.mlist_idx, self.mot_idx)--, true) --thanks to setupMotionBank(), it can change immediately
				self:update_banks()
			end
			self.changed_bank = not is_pre_cache and true
		end
	end
end

--Pre caches motbanks, finding their motlists and mots w/ all info, filling up global_cached_banks with data tables
GameObject.pre_cache_all_banks = function(self) 
	log.info("Precache all banks: " .. self.name)
	if not RN.motbank_resource_names then return end
	--if not self.motion then 
	--	self = GameObject:new_AnimObject({xform=self.xform}, self)
	--end
	if self.finished_pre_cache then --Once finished
		self.finished_pre_cache, pre_cached_banks = nil
		EMVCache.global_cached_banks = global_cached_banks
		local f_mode = forced_mode
		EMV.clear_figures()
		if f_mode then --for setting up forced_mode
			f_mode:activate_forced_mode()
		end
		if self.name == "dummy_AnimLoaderBody" then 
			deferred_calls[self.gameobj] = {func="destroy", args=self.gameobj}
		end
		json.dump_file("EnhancedModelViewer\\EMVCache.json", jsonify_table(EMVCache))
	elseif static_funcs.setup_mbank_method then 
		if not self.cached_banks then return end
		--if figure_mode then
		--	self.motion:call("setDynamicMotionBankCount", 0)
		--end
		for i=1, #RN.motbank_resource_names do 
			self:set_motionbank(i, nil, nil, nil, true)
			self:update_banks(true)
		end
		self:set_motionbank(1, 1, 1)
		--[[self:get_current_bank_name()
		self:build_banks_list()
		self:update_banks()]]
		self.finished_pre_cache = true
	else
		local sz = pre_cached_banks and get_table_size(pre_cached_banks)
		if sz and sz < get_table_size(RSCache.motbank_resources) then
			if not self.changed_bank then
				for name, bank in pairs(RSCache.motbank_resources) do
					if not pre_cached_banks[name] then 
						pre_cached_banks[name] = bank
						self.motion:call("set_MotionBankAsset", bank)
						self:get_current_bank_name()
						self.changed_bank = true
						break
					end	
				end
			end
		elseif not self.changed_bank then 
			self:set_motionbank(1, 1, 1) --One final set, to the first
			self.finished_pre_cache = true
		end 
	end
end

--local appdata_td = sdk.find_type_definition( "via.motion.AppendDataArrayInfo" )

--Create or retrieve a cached_bank and set up combo boxes for it:
GameObject.update_banks = function(self, force)
	
	--force = not forced_mode and true
	force = true
	
	local bank_name = self:get_current_bank_name(true)
	local cached_bank = global_cached_banks[self.current_bank_name]
	local sd_cb_tbl = global_cached_banks[self.current_bank_name] and EMVCache.savedata[self.key_hash] and EMVCache.savedata[self.key_hash].cb_data and EMVCache.savedata[self.key_hash].cb_data[self.current_bank_name]
	self.mbank_idx = find_index(self.motbank_names, bank_name) or self.mbank_idx or 1
	
	if force or not cached_bank or not cached_bank.mots_ids or not cached_bank.mots_ids[1] then
		
		--log.info("Update Banks: Generating " .. tostring(bank_name) .. " for " .. self.name)
		local found_empty = false
		cached_bank = {
			name=bank_name, 
			motion_names={},  
			mots_ids={}, 
			motlist_names={}, 
		}
		
		::restart::
		local mlist_count = self.motion:call("getActiveMotionBankCount")
		local mot_count = 0
		
		if mlist_count > 0 then 
			local unique_motlists, unique_motlists_files, unique_bank_ids = {}, {}, {}
			
			for b=1, mlist_count do 
				--log.info("A")
				local unique_mots, mots_ids_subtable, motion_names_subtable = {}, {}, {}
				local motlist = self.motion:call("getActiveMotionBank(System.UInt32)", b-1)
				if motlist then 
					local current_bank_id = motlist:call("get_BankID")
					local bank_type = motlist:call("get_BankType")
					if unique_bank_ids[current_bank_id .. " " .. bank_type] then --weird motlists with the same exact IDs, need to force them to be different
						while unique_bank_ids[current_bank_id .. " " .. bank_type] do
							bank_type = bank_type + 1
						end
						motlist:call("set_BankType", bank_type)
						current_bank_id = motlist:call("get_BankID")
					end
					
					unique_bank_ids[current_bank_id .. " " .. bank_type] = true
					local num_motions = self.motion:call("getMotionCount(System.UInt32)", current_bank_id)
					local mlist_file = motlist:call("get_MotionList")
					local motlist_name = (mlist_file and mlist_file:call("ToString()"):match("^.+%[@?(.+)%]")) or motlist:call("get_Name")
					
					if is_matchable_motlist(motlist_name:lower()) then
						--log.info("B")
						--unique_motlists_files[mlist_file] = true
						if motlist_name == "" and not found_empty then 
							self.motion:call("changeMotionBankSize", 0)
							found_empty = true
							goto restart
						end
						
						if unique_motlists[motlist_name] then
							goto continue
						end
						
						unique_motlists[motlist_name] = true
						local inserted_motlist = false
						
						for j=1, num_motions do
						
							local mot_info = sdk.create_instance("via.motion.MotionInfo")
							mot_info:call(".ctor")
							if self.motion:call("getMotionInfoByIndex(System.UInt32, System.Int32, System.UInt32, via.motion.MotionInfo)", current_bank_id, bank_type, j-1, mot_info) then
								--log.info("C")
								local mot_name = mot_info:call("get_MotionName")
								if not unique_mots[mot_name] and is_matchable_mot(mot_name:lower()) then
									unique_mots[mot_name] = true
									local mot_id = mot_info:call("get_MotionID")
									
									--[[local appdata_arr = ValueType.new(appdata_td)--mkobj("via.motion.AppendDataArrayInfo", true)
									self.motion:call("getAppendDataArrayInfoByID(System.UInt32, System.UInt32, System.UInt32, System.UInt32, via.motion.AppendDataArrayInfo)", current_bank_id, mot_id, 0, 4181906692, appdata_arr)
									if appdata_arr:call("get_Valid") then 
										g_appdata = g_appdata or {}
										g_appdata[mot_name] = appdata_arr
									end
									
									local count = self.motion:call("getAppendDataCount(System.UInt32, System.Int32, System.UInt32)", current_bank_id, bank_type, mot_id)
									if count and count > 0 then 
										self.append_data = self.append_data or {}
										ap_tbl = self.append_data[current_bank_id .. "-" .. bank_type .. "-" .. mot_id .. " " .. motlist_name .. " " .. mot_name] or {count=count}
										for i=1, ap_tbl.count do 
											ap_tbl.appdata = ap_tbl.appdata or {}
											local appdata = mkobj("via.motion.AppendData")
											self.motion:call("getAppendDataByIndex(System.UInt32, System.UInt32, System.UInt32, via.motion.AppendData)", current_bank_id, bank_type, mot_id, i-1, appdata)
											ap_tbl.appdata[i] = appdata
											ap_tbl.appdata_arr = ap_tbl.appdata_arr or {}
											
											--appdata_arr:write_byte(0x10, 1)
											
											--self.motion:call("getAppendDataArrayInfoByIndex(System.UInt32, System.Int32, System.UInt32, System.UInt32, System.UInt32, via.motion.AppendDataArrayInfo)", current_bank_id, bank_type, mot_id, i-1, 1604786292, appdata_arr)
											ap_tbl.appdata_arr[i] = appdata_arr
											--
										end
										self.append_data[current_bank_id .. "-" .. bank_type .. "-" .. mot_id .. " " .. motlist_name .. " " .. mot_name] = ap_tbl
									end]]
									
									local frame_count = mot_info:call("get_MotionEndFrame") or 0
									if frame_count > 0 then 
										local motion_id = mot_info:call("get_MotionID")
										table.insert(motion_names_subtable, mot_name)
										table.insert(mots_ids_subtable, table.pack(current_bank_id, motion_id, bank_type, frame_count, (#mots_ids_subtable==0 and b-1) or nil)) --, mot_info
										if not inserted_motlist then 
											table.insert(cached_bank.motlist_names, motlist_name)
											inserted_motlist = true; 
										end
										mot_count = mot_count + 1
										--log.info("inserted sub table to " .. tostring(bank_name))
									end
								end
							end
						end
						if mots_ids_subtable[1] and motion_names_subtable[1] then 
							table.insert(cached_bank.mots_ids, mots_ids_subtable)
							table.insert(cached_bank.motion_names, motion_names_subtable)
							--log.info("inserted table to " .. tostring(bank_name))
						else
							
						end
					end
				end
				::continue::
			end
			
			cached_bank.is_dummy = (mot_count == 0) or nil
			--[[if cached_bank.is_dummy then
				dummies = dummies or {}
				dummies[cached_bank.name] = cached_bank
			end]]
			
			--log.info("added " .. tostring(bank_name) .. " to global_cached_banks, also known as " .. tostring(bank_name))	
			global_cached_banks[bank_name] = cached_bank
			self.cached_banks[self.mbank_idx] = cached_bank
			
			--[[if isRE8 and not pre_cached_banks then 
				held_transforms[self.xform] = held_transforms[self.xform] or GameObject:new_AnimObject{xform=self.xform}
				if self.total_objects_idx then total_objects[self.total_objects_idx] = held_transforms[self.xform] end
			end]]
			
			--Cached_bank saved data table:
			if self.motbank_names[self.mbank_idx] then
				sd_cb_tbl = sd_cb_tbl or {}
				sd_cb_tbl.matched_random_limit = self.matched_random_limit or sd_cb_tbl.matched_random_limit or #self.all_mots
				EMVCache.savedata[self.key_hash] = EMVCache.savedata[self.key_hash] or {}
				EMVCache.savedata[self.key_hash].cb_data = EMVCache.savedata[self.key_hash].cb_data or {}
				EMVCache.savedata[self.key_hash].cb_data[ self.motbank_names[self.mbank_idx] ] = sd_cb_tbl
			end
		end
	else
		--dummies = dummies or {}
		--dummies[bank_name or self.motion:call("get_MotionBankAsset"):call("ToString")] = {}
		log.info("Update Banks: Using global motbank " .. bank_name .. " for " .. self.name)
	end
	
	--set up the cached bank:
	
	cached_bank = self:customize_cached_bank(cached_bank)
	self.mots_ids = cached_bank.mots_ids
	self.motlist_names = cached_bank.motlist_names
	self.motion_names = cached_bank.motion_names
	self.motion_names_w_frames = get_motion_names_w_frames(cached_bank)
	self.matched_random_limit = (sd_cb_tbl and sd_cb_tbl.matched_random_limit) or self.matched_random_limit
	self.cached_banks = self.cached_banks or {}
	self.cached_banks[self.mbank_idx] = cached_bank
end

GameObject.shuffle = function(self)
	if self.layer then
		local limit = (self.matched_random_limit and (self.matched_random_limit > 0) and self.matched_random_limit) or #self.all_mots
		local random_idxes = self.all_mots and self.all_mots[(random_range(1, limit))] or {1,1,1}
		--[[if not self.face_mode and (not self.matched_random_limit or self.matched_random_limit == 0) then
			local count = 0
			while count < 100 and not self:check_bank_name(self.cached_banks[ random_idxes[1] ].name, self.alt_names[1] or self.mesh_name_short, true) do
				count = count + 1
				random_idxes = self.all_mots and self.all_mots[(limit > 1 and (random_range(1, #self.all_mots)))]
			end
		end]]
		if self.mbank_idx ~= random_idxes[1] then
			--re.msg_safe("Shuffle motbank change: " .. self.name .. " " .. random_idxes[2] .. " " .. random_idxes[3] .. " " .. random_idxes[3] .. " " .. tostring(self.matched_banks_count) .. " " .. tostring(limit), 1241)
			self:set_motionbank(random_idxes[1], random_idxes[2], random_idxes[3])
		end
		if self.paused then self.layer:call("set_Speed", 0) end
		return random_idxes[2], random_idxes[3]
	end
end

local event_control_action --defined later

re.on_application_entry("UpdateHID", function()
	
	player = get_player()
	--if forced_mode and selected == player then
	--	inputsystem:set_field("<IgnoreMouseMove>k__BackingField", true)
	--end
	--F:/modmanager/REtool/DMC_chunk_000/natives/x64/prefab/character/enemy/em6030_vergil.pfb.16
	if EMVSettings.hotkeys and (figure_mode or forced_mode or cutscene_mode) then 
		local control_action_args
		
		if check_key_released(via.hid.KeyboardKey.T) then
			if ev_object and ev_object.timeline then
				ev_object.paused = not ev_object.paused
				event_control_action(ev_object, nil, ev_object.paused)
			elseif selected and (forced_mode or figure_mode) then 
				paused = not paused
				control_action_args = { paused=paused }
			end
		elseif EMVSettings.use_frozen_fov and cutscene_cam and check_key_released(via.hid.KeyboardKey.Multiply) then
			EMVSettings.frozen_fov = nil
		elseif EMVSettings.use_frozen_fov and cutscene_cam and kb_state.down[via.hid.KeyboardKey.Add] then
			cutscene_cam.components[2]:call("set_FOV", cutscene_cam.components[2]:call("get_FOV") + ((kb_state.down[via	.hid.KeyboardKey.Shift] and (1)) or 0.25) ) --+ ((kb_state.down[via.hid.KeyboardKey.Shift] and (1.05)) or 1.01)
			EMVSettings.frozen_fov = not ev_object.free_cam and cutscene_cam.components[2]:call("get_FOV")
		elseif EMVSettings.use_frozen_fov and cutscene_cam and kb_state.down[via.hid.KeyboardKey.Subtract] then
			cutscene_cam.components[2]:call("set_FOV", cutscene_cam.components[2]:call("get_FOV") - ((kb_state.down[via.hid.KeyboardKey.Shift] and (1)) or 0.25))
			EMVSettings.frozen_fov = not ev_object.free_cam and cutscene_cam.components[2]:call("get_FOV")
		elseif check_key_released(via.hid.KeyboardKey.Alpha2, 0.5) then
			if cutscene_mode then
				local new_frame = ev_object.frame  - 60 * (3 * bool_to_number[ kb_state.down[via.hid.KeyboardKey.Shift] ] + 1)
				new_frame = (ev_object.paused and kb_state.down[via.hid.KeyboardKey.Menu]) and (ev_object.frame-1) or new_frame
				event_control_action(ev_object, new_frame)
			elseif selected and (forced_mode or figure_mode) then 
				control_action_args = { do_seek=true, current_frame=selected.frame - 60 * (3 * bool_to_number[ kb_state.down[via.hid.KeyboardKey.Shift] ] + 1) } 
			end
		elseif check_key_released(via.hid.KeyboardKey.Alpha4, 0.5) then
			local do_multiplier = bool_to_number[ kb_state.down[via.hid.KeyboardKey.Shift] or kb_state.down[via.hid.KeyboardKey.Shift] ]
			if cutscene_mode then
				local new_frame = ev_object.frame  + 60 * (3 * bool_to_number[ kb_state.down[via.hid.KeyboardKey.Shift] ] + 1)
				new_frame = (ev_object.paused and kb_state.down[via.hid.KeyboardKey.Menu]) and (ev_object.frame+1) or new_frame
				event_control_action(ev_object, new_frame)
			elseif selected and (forced_mode or figure_mode) then 
				control_action_args = { do_seek=true, current_frame=selected.frame + 60 * (3 * bool_to_number[ kb_state.down[via.hid.KeyboardKey.Shift] ] + 1) } 
			end
		elseif check_key_released(via.hid.KeyboardKey.F) then
			if cutscene_mode and ev_object.cam_layer then
				ev_object.free_cam = not ev_object.free_cam
				if ev_object.free_cam then 
					ev_object.cam_layer:call("set_BlendMode", 2)
					cutscene_cam.components[2]:call("set_FOV", ev_object.zoom_level or 68.0)
				else
					ev_object.cam_layer:call("set_BlendMode", 0)
				end
			end
		elseif selected and (figure_mode or forced_mode) and check_key_released(via.hid.KeyboardKey.U) then
			selected:change_motion(selected:shuffle())
		elseif check_key_released(via.hid.KeyboardKey.Alpha6) then
			EMVSettings.seek_all = not EMVSettings.seek_all
		elseif figure_mode and selected and check_key_released(via.hid.KeyboardKey.H) then
			if (selected.force_center and selected.aggressively_force_center) then selected.force_center, selected.aggressively_force_center = false
			elseif selected.force_center then selected.aggressively_force_center = true
			else selected.force_center = true end
		elseif forced_mode and grab and selected and check_key_released(via.hid.KeyboardKey.G) then
			grab(selected.xform, {init_offset=selected.cog_joint and selected.cog_joint:call("get_BaseLocalPosition")})
		end
		if control_action_args then 
			for i, obj in ipairs(imgui_anims) do
				obj:control_action( control_action_args )
			end
		end
	end
end)

--import settings from file
local default_settings = deep_copy(EMVSettings) --merge_tables({}, EMVSettings) --deep copies
local default_cache = merge_tables({}, EMVCache) 
EMVSettings.init_EMVSettings = function()
	--re.msg(tostring(EMVSettings.init_EMVSettings))
	local new_settings = json.load_file("EnhancedModelViewer\\EMVSettings.json")
	if new_settings and new_settings.load_json then 
		local this = EMVSettings.init_EMVSettings
		EMVSettings = jsonify_table(new_settings, true) or default_settings
		for key, value in pairs(default_settings) do 
			if EMVSettings[key] == nil then EMVSettings[key] = value end
		end
		local new_cache = json.load_file("EnhancedModelViewer\\EMVCache.json")
		if new_cache then
			EMVCache = jsonify_table(new_cache, true) or default_cache
			for key, value in pairs(default_cache) do 
				if EMVCache[key] == nil then EMVCache[key] = value end
			end
		end
		EMVSettings.init_EMVSettings = this
	end
	--re.msg(tostring(EMVSettings.init_EMVSettings))
end

re.on_script_reset(function()
	if ev_object and ev_object.cam_layer then
		ev_object.cam_layer:call("set_BlendMode", 0)
	end
	if EMVSettings then
		for key, value in pairs(EMVSettings or {}) do 
			if default_settings[key] == nil then 
				EMVSettings[key] = nil --wipe any options not set up at the top of this script
			end
		end
		if EMVSettings.load_json then
			json.dump_file("EnhancedModelViewer\\EMVSettings.json", jsonify_table(EMVSettings))
			json.dump_file("EnhancedModelViewer\\EMVCache.json", jsonify_table(EMVCache))
		end
	end
	if static_objs.center then
		for i, child in ipairs(get_children(static_objs.center.xform) or {}) do 
			local obj = (held_transforms[child] or GameObject:new_AnimObject{xform=child})
			obj:set_parent(obj.parent_org or obj.parent or 0)
		end
	end
end)

local function wwise_seek_all(ev_object, seek_frame, pause)
	
	if not ev_object.last_wwise_req_time or ((ev_object.last_wwise_req_time+5) < tics) then
		
		ev_object.last_wwise_req_time = tics
		
		seek_frame = seek_frame and (seek_frame + 0.0000001)
		if ev_object.timeline_mgr then 
			ev_object.timeline_mgr:call("set_CurrentFrameForWwise", seek_frame) 
		end
		
		for obj_name, wwise in pairs(ev_object.wwise_objs) do 
			wwise.wwise:call("stopAll()")
			for name, sub_tbl in pairs(wwise.trigger_ids) do 
				
				--wwise.wwise:call("stopTriggered(System.UInt32)", sub_tbl.id)
				sub_tbl.obj:call("stopTriggered()")
				
				if seek_frame and not pause then
					local msec = math.floor((seek_frame / 60) * 1000) --milliseconds
					if ev_object.alt_sound_seek then
						local req = sdk.create_instance("via.wwise.RequestInfo", true):add_ref()
							req:call(".ctor")
							req:call("set_TriggerId", sub_tbl.id)
							req:call("set_EnableEndOfEventPerTrigger", false)
							--req:call("set_SeekTime", msec) --UInt16 max of 65536 ms
							req:call("set_SeekTimeMsec(System.Int32)", msec)
							req:call("set_Triggerd",  true)
							req:call("set_Triggered", true)
							req:call("Finalize")
						wwise.wwise:call("trigger(via.GameObject, System.UInt32, via.GameObject, System.UInt32, via.wwise.RequestInfo, System.Boolean, System.Boolean, System.Boolean, System.Int32)",
							wwise.gameobj,  --target gameobj
							sub_tbl.id,     --triggerID
							wwise.gameobj,  --position gameobj
							0, 				--bone hash
							req, 	 		--request object
							false,			--is positioned
							false,			--from FSM
							false,			--symmetry
							msec			--Int32
						)
					else
						--wwise.wwise:call("seekTrigger(System.UInt32, System.Single)", sub_tbl.id, seek_frame)
						sub_tbl.obj:call("seekTrigger(System.Single)", seek_frame)
					end
					--[[
					wwise.wwise:call("set_UseTimeScale", true)
					old_deferred_calls["app.WwiseContainerApp"] = nil
					deferred_calls[wwise.wwise] = {lua_object=wwise.wwise, method=wwise.wwise.write_float, args={0x214, (ev_object.play_speed+0.000001)}, vardata={freeze=true}}
					--deferred_calls[wwise.wwise] = {func="set_TimeScale(System.Single)", args=ev_object.play_speed+0.000001}
					--wwise.wwise:call("set_TimeScale(System.Single)", ev_object.play_speed)
					]]
				end
			end
		end
		
		if ev_object.timeline_mgr then
			if pause then 
				ev_object.timeline_mgr:call("requestPauseWwiseApp")
			else
				ev_object.timeline_mgr:call("requestResumeWwiseApp")
			end
		end
	end
end

event_control_action = function(ev_object, current_frame, ev_paused, ev_play_speed, playstate)
	
	ev_object.frame = current_frame or ev_object.frame
	ev_object.play_speed = ev_play_speed or ev_object.play_speed
	if ev_paused ~= nil then 
		ev_object.paused = ev_paused 
	end
	
	ev_object.timeline:call("set_Frame", current_frame or ev_object.frame)
	
	if ev_object.paused then
		wwise_seek_all(ev_object, current_frame or ev_object.frame, true)
		if ev_object.timeline_mgr then 
			deferred_calls[ev_object.timeline_mgr] = {func="pauseEvent"} --resume for one frame to allow seeking while paused, then pause again on the next
		else
			deferred_calls[ev_object.timeline] = {func="set_PlayState", args=3}
		end
	else
		wwise_seek_all(ev_object, current_frame or ev_object.frame, (ev_object.play_speed ~= 1.0)) --only resume wwise if playspeed is 100%
		ev_object.timeline:call("set_PlayState", playstate or 1)
	end
	
	ev_object.timeline:call("set_PlaySpeed", tonumber(string.format("%." .. 2 .. "f", ev_object.play_speed)))
	
	if ev_object.timeline_mgr and (current_frame or not ev_object.paused) then
		ev_object.timeline_mgr:call("resumeEvent")  
	end
end

--[[
event_control_action = function(ev_object, current_frame, ev_paused, ev_play_speed, playstate)
	
	ev_object.frame = current_frame or ev_object.frame
	ev_object.play_speed = ev_play_speed or ev_object.play_speed
	if ev_paused ~= nil then 
		ev_object.paused = ev_paused 
	end
	
	ev_object.timeline:call("set_PlayState", 1) --set to play during control actions, so changes take effect
	ev_object.timeline:call("set_Frame", current_frame or ev_object.frame)
	
	if ev_object.paused then
		if ev_object.timeline_mgr then ev_object.timeline_mgr:call("pauseEvent") end
		wwise_seek_all(ev_object, current_frame or ev_object.frame, true)
		playstate = playstate or 3
	elseif ev_paused == false then
		if ev_object.timeline_mgr then ev_object.timeline_mgr:call("resumeEvent") end
		wwise_seek_all(ev_object, current_frame or ev_object.frame, (ev_object.play_speed ~= 1.0))
	end
	
	ev_object.timeline:call("set_PlayState", playstate or ev_object.play_state) --resume play/paused state
	ev_object.timeline:call("set_PlaySpeed", tonumber(string.format("%." .. 2 .. "f", ev_play_speed or ev_object.play_speed)))
end

]]

local function cs_viewer()
	
	if not ev_object or not is_valid_obj(ev_object.xform) then 
		ev_object, cutscene_mode = nil 
		collectgarbage()
		return
	end
	
	imgui.begin_rect()
		
		if ev_object.timeline then  
			
			--[[if ev_object.wwise_objs then
				for k, v in pairs(ev_object.wwise_objs) do 
					imgui.text(v.wwise:call("get_TimeScale()"))
				end
			end]]
			
			if not ev_object.cam_layer then
				local actor_motioncamera = scene:call("findComponents(System.Type)", sdk.typeof("via.motion.ActorMotionCamera")) 
				actor_motioncamera = actor_motioncamera and actor_motioncamera.get_elements and actor_motioncamera:get_elements()[1]
				ev_object.cam_layer = actor_motioncamera and actor_motioncamera:call("getLayer", 0)
			end
			
			if (isRE2 or isRE3) and not ev_object.timeline_mgr then
				local levelmaster = search("LevelMaster")[1]
				ev_object.levelmaster = held_transforms[levelmaster] or GameObject:new_AnimObject{xform=levelmaster}
				ev_object.timeline_mgr = ev_object.levelmaster and ev_object.levelmaster.components_named.TimelineEventManager
				--ev_object.wwise = ev_object.levelmaster and ev_object.levelmaster.components_named.WwiseContainerApp
				if ev_object.timeline_mgr then
					ev_object.contents = lua_get_system_array(ev_object.timeline_mgr:get_field("_ContentsList"), true, true)
					ev_object.timeline_mgr:call("requestResumeWwiseApp")
				end
			end
			
			ev_object.wwise_objs = ev_object.wwise_objs or {}
			if not next(ev_object.wwise_objs) then
				local snd_objs = {}
				for i, anim_object in ipairs(ev_object.bind_gameobjects) do 
					if anim_object.name:find("so?u?nd") then 
						table.insert(snd_objs, anim_object) 
					end
				end
				for i, wwise in ipairs(snd_objs) do
					wwise.trigger_ids = {}
					wwise.end_frame = ev_object.end_frame
					wwise.wwise = wwise.components_named.WwiseContainerApp
					wwise.idlist = wwise.components_named.WwiseClipTriggerList
					if wwise.idlist then 
						for i=1, wwise.idlist:call("getSeqTriggerParamCount") do
							local param = wwise.idlist:call("getSeqTriggerParam", i-1)
							if not param then break end 
							local trigger_id_name = param:call("get_TriggerIdName()")
							wwise.trigger_ids[trigger_id_name or i-1] = {obj=param, id=param:call("get_TriggerId")}
							ev_object.wwise_objs[wwise.name] = wwise
						end
					end
				end
				ev_object.alt_sound_seek = EMVSettings.alt_sound_seek 
			end
			
			current_figure_name = ev_object.cutscene_name or current_figure_name
			
			if ev_object.play_state == 0 then 
				deferred_calls[ev_object.timeline] = { { func="set_PlayState", args=1 }, { func="set_PlaySpeed", args=1.0 } }
			end
			
			--local cutscene_seek_changed, current_frame = imgui.slider_float("Seek Bar (" .. math.floor(ev_object.endframe) .. " frames)", ev_object.frame, 0, ev_object.endframe)
			local changed, current_frame = imgui.slider_float("Seek Bar (" .. tonumber(string.format("%." .. 2 .. "f",(ev_object.endframe/60))) .. " seconds)", (ev_object.frame/60), 0, (ev_object.endframe/60))
			current_frame = current_frame * 60
			if changed then 
				event_control_action(ev_object, current_frame, nil)
			end
			
			local ps = ev_object.timeline:call("get_PlaySpeed")
			changed, ev_object.play_speed = imgui.drag_float("Cutscene Speed", ps, 0.01, 0, 5.0)
			if changed then 
				event_control_action(ev_object, nil, nil, ev_object.play_speed)
			end
			
			if ev_object.paused == nil then 
				ev_object.paused = (ev_object.mediator and (ev_object.mediator:call("get_CurrentState") == 3)) or false
				--[[for i, content in ipairs(ev_object.contents or {}) do
					ev_object.paused = ev_object.paused or content:get_field("_Pause")
				end]]
			end
			
			if imgui.button((ev_object.paused and "  Play  ") or "Pause") then 
				ev_object.paused = not ev_object.paused
				event_control_action(ev_object, nil, ev_object.paused)
			end
			
			imgui.same_line()
			if imgui.button("Restart") then 
				event_control_action(ev_object, 0.0, false, 1.0, 0)
				total_objects, held_transforms = {}, {}
				ev_object.paused = false
				if ev_object.timeline_mgr then 
					ev_object.timeline_mgr:call("requestResumeWwiseApp") 
				end
				EMV.clear_figures()
				return
			end
			
			if next(ev_object.wwise_objs) then
				imgui.same_line()
				--imgui.begin_rect()
					if imgui.button("Stop Audio") then
						wwise_seek_all(ev_object, nil, true)
						if ev_object.timeline_mgr then 
							ev_object.timeline_mgr:call("requestPauseWwiseApp") 
						end
					end
					--imgui.same_line()
					--changed, EMVSettings.seek_short = imgui.checkbox("Seek Type 2", EMVSettings.seek_short)
				--imgui.end_rect(2) 
				imgui.same_line()
				changed, EMVSettings.alt_sound_seek = imgui.checkbox("Alt Sound Seek", EMVSettings.alt_sound_seek); EMVSetting_was_changed = changed or EMVSetting_was_changed
			end
			
			if ev_object.cam_layer then--and not and imgui.button((ev_object.no_zoom and "Cinematic Cam") or "Free Cam") then 
				imgui.same_line()
				changed, ev_object.free_cam = imgui.checkbox("Free Cam", (ev_object.cam_layer:call("get_BlendMode") == 2))
				if changed then 
					if ev_object.free_cam then 
						deferred_calls[ev_object.cam_layer] = { func="set_BlendMode", args=2 } --Overwrite 
						deferred_calls[ cutscene_cam.components[2] ] = { func="set_FOV", args=ev_object.zoom_level or 68.0 }
						if camera.components_named.DepthOfFieldParamBlender then
							camera.components_named.DepthOfFieldParamBlender:call("set_Enabled", false)
						end
						deferred_calls[ camera.components_named.DepthOfField ] = { func="set_Enabled", args=false }
					else
						deferred_calls[ev_object.cam_layer] = { func="set_BlendMode", args=0 } --Private (cutscene-controlled)
						if camera.components_named.DepthOfFieldParamBlender then 
							camera.components_named.DepthOfFieldParamBlender:call("set_Enabled", true)
						end
					end
				end
				
				imgui.same_line()
				changed, EMVSettings.use_frozen_fov = imgui.checkbox("Zoom Control", EMVSettings.use_frozen_fov); EMVSetting_was_changed = changed or EMVSetting_was_changed
			end
			
			imgui.same_line()
			changed, EMVSettings.detach_cs_viewer = imgui.checkbox("Detach", EMVSettings.detach_cs_viewer); EMVSetting_was_changed = EMVSetting_was_changed or changed
			
			imgui.same_line()
			if imgui.button("End Scene") then
				deferred_calls[ev_object.cam_layer] = { func="set_BlendMode", args=0 }
				event_control_action(ev_object, ev_object.endframe-15.0, false, 1.0)
				if ev_object.timeline_mgr then ev_object.timeline_mgr:call("requestPauseWwiseApp") end
				return EMV.clear_figures()
			end
			
			--[[if ev_object.timeline_mgr then
				imgui.same_line()
				imgui.text(tostring(ev_object.timeline_mgr:call("get_CurrentFrameForWwise")))
			end]]
			
			--A-B looping
			local cancelled
			if imgui.button((ev_object.loop_b and "Clear Loop") or (ev_object.loop_a and "Set Loop B") or "Set Loop A") or check_key_released(via.hid.KeyboardKey.Alpha5) then
				cancelled = true
				if ev_object.loop_b then 
					ev_object.loop_b, ev_object.loop_a = nil 
				elseif ev_object.loop_a then
					ev_object.loop_b = ev_object.frame
				else
					ev_object.loop_a = ev_object.frame
				end
			end
			if ev_object.loop_a and not ev_object.loop_b and not imgui.same_line() and (imgui.button("Cancel") or (check_key_released(via.hid.KeyboardKey.Alpha5) and not cancelled)) then
				ev_object.loop_a = nil
			end
			if ev_object.loop_a then  
				imgui.same_line() 
				imgui.text("A: " .. math.floor(ev_object.loop_a) .. (ev_object.loop_b and ("  <-->  B: " .. math.floor(ev_object.loop_b)) or "")) 
			end
			
			if ev_object.free_cam then
				changed, ev_object.zoom_level = imgui.drag_float("FOV Zoom", cutscene_cam.components[2]:call("get_FOV"), 0.1, 1, 190)
				if changed then
					deferred_calls[ cutscene_cam.components[2] ] = { func="set_FOV", args=ev_object.zoom_level }
				end
			end
		end
		
	imgui.end_rect(0)
end

local show_animation_controls

local function show_imgui_animation(anim_object, idx, embedded_mode)
	
	local not_started = not forced_mode and ((not anim_object.running) and (tics - figure_start_time) < 10) and (anim_object.frame == 0) and not (isRE8 and anim_object.matched_banks_count == 0) --anim_object.mbank_idx == 1 or 
	local subtitle_string = anim_object.name .. (isDMC and (" (" .. anim_object.body_part .. ") ") or "") .. (anim_object.synced  and (" [Synced]") or "") .. " [" .. (anim_object.mbank_idx or 1) .. "," .. (anim_object.mlist_idx or 1) .. "," .. (anim_object.mot_idx or 1) .. "]"
	local is_main = (idx == 0)
	local id = anim_object.gameobj:get_address()+1+(bool_to_number[is_main])
	
	imgui.push_id(id)
		
		local was_changed
		if not embedded_mode then
			if anim_object.motbank_names then
				imgui.text((anim_object == selected) and ("SELECTED" or "") .. (is_main and ("\n" .. subtitle_string) or ""))
			end
			
			if cutscene_mode and anim_object.packed_xform and not anim_object.active and not imgui.same_line() and imgui.button("Remove Offset") then
				anim_object.last_cog_offset = nil
				anim_object.packed_xform = nil
			end
			
			changed, anim_object.display = imgui.checkbox(is_main and "Display" or "",  anim_object.display)
			imgui.tooltip("Check once to select this object, check while selected to enable/disable it", id)
			if cutscene_mode then 
				imgui.same_line()
				imgui.text(anim_object == selected and "*" or " ")
			end
			
			if changed then
				if is_main or (selected == anim_object) then  --or not anim_object.motbank_names
					anim_object:toggle_display()
				else
					selected = anim_object
					anim_object.display = not anim_object.display 
					if static_objs.center and do_move_light_set then --move the lights-center to the new selected object
						local children = get_children(static_objs.center.xform) or {}
						for i, child in ipairs(children) do 
							held_transforms[child] = held_transforms[child] or GameObject:new_AnimObject{xform=child}
							child:call("set_Parent", 0) 
						end
						local aabb = selected.components_named.Mesh and selected.components_named.Mesh:call("get_WorldAABB")
						local center_pos = (aabb and aabb:call("getCenter")) or (selected.cog_joint or (selected.joints and (selected.joints[3] or selected.joints[2] or selected.joints[1])) or selected.xform):call("get_Position")
						write_transform(static_objs.center, center_pos)
						for i, child in ipairs(children) do 
							held_transforms[child]:set_parent(held_transforms[child].parent or 0) 
						end
					end
				end
			end
		end
		
		--[[if cutscene_mode then
			imgui.same_line()
			imgui_anim_object_viewer(anim_object, anim_object.name)
		else]]
		if (is_main or embedded_mode) or (not imgui.same_line() and imgui.tree_node_str_id(anim_object.name, subtitle_string)) then
			
			if anim_object.layer and not cutscene_mode and not anim_object.alt_names and not anim_object.motbank_names then --if it got here without alt_names or motbank names, there was some table confusion somewhere and its not a real AnimObject
				anim_object = GameObject:new_AnimObject({xform=anim_object.xform}, anim_object)
				if not anim_object then return end
			end
			
			if anim_object.motbank_names then 
				if not selected and anim_object.display and anim_object.body_part == "Body" then
					selected = anim_object
				end
				
				changed, anim_object.mbank_idx = imgui.combo("Bank", anim_object.mbank_idx or 1, anim_object.motbank_names); was_changed = was_changed or changed
				if changed then
					--selected = anim_object
					anim_object:set_motionbank(anim_object.mbank_idx, 1, 1)
				end
				
				--Add or remove a bank from matched_banks manually:
				imgui.same_line()
				local matched_bank = anim_object.matched_banks and anim_object.matched_banks[ anim_object.motbank_names[anim_object.mbank_idx] ]
				if imgui.button(matched_bank and "-" or "+") then
					local mb_name = anim_object.motbank_names[anim_object.mbank_idx]
					anim_object.matched_banks[mb_name] = not matched_bank and anim_object.motbanks[mb_name] or nil
					anim_object:build_banks_list()
					anim_object:update_banks()
					anim_object.mbank_idx = find_index(anim_object.motbank_names, mb_name) or 1
					anim_object.savedata.matched_banks = anim_object.matched_banks
					anim_object.matched_banks_count = get_table_size(anim_object.matched_banks)
					if anim_object.pairing and anim_object.pairing.motion then
						anim_object.pairing.matched_banks = anim_object.pairing.matched_banks or {}
						anim_object.pairing.matched_banks[mb_name] = not matched_bank and anim_object.motbanks[mb_name] or nil
						anim_object.pairing:build_banks_list()
						anim_object.pairing:update_banks()
						anim_object.pairing.mbank_idx = find_index(anim_object.pairing.motbank_names, mb_name) or 1
						anim_object.pairing.savedata.matched_banks = anim_object.pairing.matched_banks
						anim_object.pairing.matched_banks_count = get_table_size(anim_object.pairing.matched_banks)
					end
				end
				
				changed, anim_object.mlist_idx = imgui.combo("Motlist", anim_object.mlist_idx, anim_object.motlist_names); was_changed = was_changed or changed
				if changed then 
					anim_object:change_motion(anim_object.mlist_idx, 1)
				end
				
				changed, anim_object.mot_idx = imgui.combo("Mot", anim_object.mot_idx, anim_object.motion_names_w_frames[anim_object.mlist_idx] or {} ); was_changed = was_changed or changed
				if changed then 
					anim_object:change_motion(nil, anim_object.mot_idx)
				end
				if (figure_mode or forced_mode) and not imgui.same_line() and imgui.button("Refresh") then 
					anim_object = anim_object:update_components({selected=(anim_object==selected) or nil})
					anim_object.children = get_children(anim_object.xform)
				end
			end
			
			if embedded_mode or (not is_main and anim_object.motbank_names and imgui.tree_node_str_id(anim_object.name .. "Ctrl", "Controls")) then
				show_animation_controls(anim_object, idx, embedded_mode)
				if not embedded_mode 	then
					imgui.tree_pop()
				end
			end
			
			if not embedded_mode then
				imgui_anim_object_viewer(anim_object, "Object")
			end

			if not is_main and not embedded_mode then
				imgui.tree_pop()
			end
		end
	imgui.pop_id()
	
	--not_started = false 
	--if not_started then imgui.text("NOT STARTED") end
	if not was_changed and not is_main and anim_object.layer and anim_object.display then -- and not anim_object.synced --(EMVSettings.seek_all or (selected == anim_object))
		if anim_object.do_next or anim_object.do_prev or ((anim_object.anim_finished and not anim_object.looping) and (not anim_object.synced or (anim_object == selected))) then
			anim_object:change_motion(anim_object:next_motion())
		end
	end
end


show_animation_controls = function(game_object, idx, embedded_mode)
	
	local game_object = game_object or selected
	if not game_object then return end
	
	local is_main = (idx == 0)
	--if cutscene_mode and not forced_mode then return end
	local good =  game_object and game_object.motion and game_object.layer
		
	if good and game_object.end_frame then --not figure_mode or 
		
		imgui.begin_rect()
		imgui.push_id(game_object.xform)
			
			if game_object.selected then 
				imgui.text("\nSelected:")
			end
			imgui.same_line()
			imgui.text("\n" .. tostring(game_object.name))
			
			local control_changed
			local current_frame = game_object.frame or 0
			local seek_changed, current_frame = imgui.slider_float("Seek Bar (" .. math.floor(game_object.end_frame) .. " frames)", current_frame, 0, game_object.end_frame)
			--current_figure = current_figure or game_object
		
			control_changed, game_object.play_speed = imgui.drag_float("Playback Speed", game_object.play_speed, 0.01, -5.0, 5.0)
			
			
			local button_str = (game_object.paused or not game_object or not game_object.running) and "  Play  " or "Pause"
			if imgui.button(button_str) then 
				game_object.paused = not game_object.paused
				control_changed = true
			--elseif number_to_bool[game_object.motion:call("get_PlayState")] ~= game_object.paused then 
			--	control_changed = true
			end
			--game_object.paused = number_to_bool[game_object.motion:call("get_PlayState")]
			
			imgui.same_line()
			if imgui.button("Reverse") then 
				game_object.play_speed, game_object.paused, control_changed = -game_object.play_speed, false, true
			end
			imgui.same_line()
			if imgui.button("0.05x") then 
				game_object.play_speed, game_object.paused, control_changed = 0.05, false, true
			end
			imgui.same_line()
			if imgui.button("0.25x") then 
				game_object.play_speed, game_object.paused, control_changed = 0.25, false, true
			end
			imgui.same_line()
			if imgui.button("0.5x") then 
				game_object.play_speed, game_object.paused, control_changed = 0.5, false, true
			end
			imgui.same_line()
			if imgui.button("0.75x") then 
				game_object.play_speed, game_object.paused, control_changed = 0.75, false, true
			end
			imgui.same_line()
			if imgui.button("1.0x") then 
				game_object.play_speed, game_object.paused, control_changed = 1.00, false, true
			end
			imgui.same_line()
			if imgui.button("+0.25x") then 
				game_object.play_speed, game_object.paused, control_changed = game_object.play_speed + 0.25, false, true
			end
			
			imgui.same_line()
			was_changed, EMVSettings.seek_all = imgui.checkbox("Seek All", EMVSettings.seek_all); EMVSetting_was_changed = EMVSetting_was_changed or was_changed
			
			if imgui.button("Prev") then 
				control_changed = true
				game_object.do_prev = true
			end
			imgui.same_line()
			if imgui.button("Next") then 
				control_changed = true
				game_object.do_next = true
			end
			
			--[[imgui.same_line()
			if imgui.button(continuous_banks and "Continuous" or "Looping") then 
				continuous_banks = not continuous_banks
			end]]
			
			imgui.same_line()
			if imgui.button("Shuffle") then
				game_object.play_speed, game_object.paused, control_changed = 1.00, false, true
				game_object.do_shuffle, game_object.do_next = true, true
			end
			
			imgui.same_line()
			game_object.do_restart = nil
			if imgui.button("Restart") then 
				game_object.play_speed, control_changed = 1.00, true
				game_object.do_restart = true
				deferred_calls[base_mesh.xform] = { func="set_Rotation", args=Quaternion.new(1,0,0,0) }
			end
			
			local do_reset_gpuc = false
			if (game_object.physicscloth or game_object.chain) and not imgui.same_line() and imgui.button("Reset Physics") then 
				do_reset_gpuc, control_changed = true, true
			end
			
			--A-B looping
			imgui.same_line()
			if game_object.loop_a then
				imgui.begin_rect()
			end
				if game_object then
					local cancelled
					if imgui.button((game_object.loop_b and "Clear Loop") or (game_object.loop_a and "Set Loop B") or "Set Loop A") or check_key_released(via.hid.KeyboardKey.Alpha5) then
						cancelled = true
						if game_object.loop_b then 
							for i, obj in ipairs(imgui_anims) do 
								if (obj == game_object) or EMVSettings.seek_all then obj.loop_b, obj.loop_a = nil, nil end
							end
						elseif game_object.loop_a and not (game_object.loop_a[2] == game_object.mbank_idx and game_object.loop_a[3] == game_object.mlist_idx and game_object.loop_a[4] == game_object.mot_idx and game_object.loop_a[1] >= game_object.frame ) then
							for i, obj in ipairs(imgui_anims) do 
								if (obj == game_object) or EMVSettings.seek_all then 
									obj.loop_b = { obj.frame, obj.mbank_idx, obj.mlist_idx, obj.mot_idx}  
									if not (game_object.loop_a[2] == game_object.mbank_idx and game_object.loop_a[3] == game_object.mlist_idx and game_object.loop_a[4] == game_object.mot_idx) then
										obj.looping = false --set 'Continuous' mode if its looping across multiple mots
									end
								end
							end
						else
							for i, obj in ipairs(imgui_anims) do 
								if (obj == game_object) or EMVSettings.seek_all then obj.loop_a = { obj.frame, obj.mbank_idx, obj.mlist_idx, obj.mot_idx} end
							end
						end
					end
					if game_object and game_object.loop_a and not game_object.loop_b and not imgui.same_line() and (imgui.button("Cancel") or (check_key_released(via.hid.KeyboardKey.Alpha5) and not cancelled)) then
						for i, obj in ipairs(imgui_anims) do 
							if (obj == game_object) or EMVSettings.seek_all then 
								obj.loop_a = nil 
								obj.init_cog_offset = nil
							end
						end
					end
				end
				
				if game_object.loop_a and not imgui.same_line() then  
					imgui.text("A: [" .. game_object.loop_a[2] .. "," .. game_object.loop_a[3] .. "," .. game_object.loop_a[4] .. "] " .. math.floor(game_object.loop_a[1])) 
				end
				
				if game_object.loop_b and not imgui.same_line() then 
					imgui.text("<-->  B: [" .. game_object.loop_b[2] .. "," .. game_object.loop_b[3] .. "," .. game_object.loop_b[4] .. "] " .. math.floor(game_object.loop_b[1]))
				end
			if game_object.loop_a then
				imgui.end_rect(2)
			end
			
			was_changed, game_object.looping = imgui.checkbox("Repeat", game_object.looping)
			if was_changed then
				if EMVSettings.seek_all or is_main then
					for i, obj in ipairs(imgui_anims) do
						obj.layer:call("set_WrapMode", game_object.looping and 2 or 0) --set looping
					end
				else
					game_object.layer:call("set_WrapMode", game_object.looping and 2 or 0)
				end
			end
			
			imgui.same_line()
			--if true then --not game_object.same_joints_constraint or game_object.center_obj then
				local center_obj = game_object --game_object.center_obj or game_object
				was_changed, center_obj.force_center = imgui.checkbox("Center" .. (center_obj.aggressively_force_center and "*" or ""), center_obj.force_center)
				if was_changed then
					if center_obj.force_center and not center_obj.aggressively_force_center then
						center_obj.aggressively_force_center = true
						center_obj.init_worldmat = (center_obj.parent_obj and center_obj.parent_obj.xform:call("get_WorldMatrix")) or Matrix4x4f.identity()
						--log_value(center_obj.init_worldmat)
						center_obj:set_parent(center_obj.parent or 0)
						--deferred_calls[center_obj.xform] = {
						--	{lua_object=center_obj, method=GameObject.set_parent, args={center_obj.parent or 0}},
							--{lua_object=center_obj, method=GameObject.set_transform, args={center_obj.init_worldmat}},
							--(center_obj.init_worldmat and {func="set_Position", args=center_obj.init_worldmat}) or {},
						--}
					elseif not center_obj.force_center and center_obj.aggressively_force_center then--if center_obj.force_center then 
						center_obj.aggressively_force_center = nil
						center_obj.force_center = true
					--else
					--	center_obj.force_center, center_obj.aggressively_force_center = nil
						--center_obj.force_center = false
					--else
					--	center_obj.aggressively_force_center = nil
					--	center_obj.force_center = not center_obj.force_center
					end
						
						
						--if isRE3 and current_figure then deferred_calls[center_obj.xform] = {func="set_Position", current_figure.xform:call("get_Position")} end
					if center_obj.savedata then
						center_obj.savedata.force_center = center_obj.force_center
						center_obj.savedata.aggressively_force_center = center_obj.aggressively_force_center
					end
					if forced_mode and center_obj.force_center then
						center_obj.init_transform = center_obj.xform:call("get_WorldMatrix") 
					end
					center_obj.init_cog_offset = nil
				end
				imgui.same_line()
				was_changed, game_object.mirrored = imgui.checkbox("Mirror", game_object.layer:call("get_MirrorSymmetry"))
				if was_changed then 
					game_object.layer:call("set_MirrorSymmetry", game_object.mirrored)
				end
			--end
			if EMVSettings.sync_face_mots then
				imgui.same_line()
				was_changed, game_object.sync = imgui.checkbox("Sync", game_object.sync)
				if was_changed and game_object.savedata then 
					game_object.savedata.sync = game_object.sync 
				end
			end
			
			if forced_mode and game_object.mfsm2 and not imgui.same_line() then 
				was_changed, game_object.puppetmode = imgui.checkbox("Puppet", game_object.puppetmode)
				if was_changed then 
					game_object.mfsm2:call("set_PuppetMode", game_object.puppetmode)
					if not game_object.puppetmode then 
						deferred_calls[game_object.mfsm2] = {func="restartTree"}--{{func="set_PuppetMode", game_object.puppetmode}, {func="restartTree"}}
					end
				end
			end
			
			if not embedded_mode and not figure_mode and _G.grab and not game_object.same_joints_constraint or not game_object.parent then
				imgui.same_line()
				offer_grab(game_object)
			end
			
			if game_object.PlayerLookAt then
				imgui.same_line()
				changed, game_object.player_lookat_enabled = imgui.checkbox("Player LookAt", game_object.PlayerLookAt:call("get_Enabled"))
				if changed then
					deferred_calls[game_object.PlayerLookAt] = {func="set_Enabled", args=game_object.player_lookat_enabled}
				end
			end
			
			--[[if game_object.test_tbl then
				EMV.read_imgui_element(game_object.test_tbl)
			end]]
			
			if control_changed or seek_changed then 
				if EMVSettings.seek_all then
					if do_reset_gpuc then 
						for i, item in ipairs(merge_indexed_tables(findc("via.motion.Chain"), findc("app.PhysicsCloth"))) do
							item:call("restart") 
						end
					end
					for i, object in ipairs(imgui_anims or {game_object}) do
						object:control_action( { paused=game_object.paused, do_restart=game_object.do_restart, do_seek=seek_changed, play_speed=game_object.play_speed, current_frame=current_frame, do_reset_gpuc=do_reset_gpuc } )
					end
				else
					game_object:control_action( { paused=game_object.paused, do_restart=game_object.do_restart, do_seek=seek_changed, play_speed=game_object.play_speed, current_frame=current_frame, do_reset_gpuc=do_reset_gpuc } )
				end
			end
			
			if is_main then 
				show_imgui_animation(game_object, 0)
			end
			if not game_object or not game_object.parent and not game_object.children then 
				imgui.new_line()
			end
			if not game_object or not game_object.materials then 
				imgui.new_line()
			end	
			changed = nil
		imgui.pop_id()
		imgui.end_rect(5)
	elseif good and toks % 16 == 0 then
		game_object.end_frame = game_object.layer:call("get_EndFrame")
		--game_object:update_components()
	end
end

local function find_selected(imgui_anims, case)
	if not selected then
		case = case or ((isRE2 or isRE3 or isDMC) and 0) or 1
		for i=case, 2 do 
			for i, anim_object in ipairs(reverse_table(imgui_anims)) do
				if i == 0 then 
					selected = (anim_object.display and anim_object.name:find("figure_base")) and anim_object
				elseif i == 1 then
					selected = (anim_object.display and (anim_object.body_part == "Body")) and anim_object
				elseif i == 2 then
					selected = (anim_object.body_part == "Body") and anim_object
				end
				if selected then return selected end
			end
		end
	end
	return selected
end

local function show_emv_settings()
	if imgui.tree_node("Enhanced Model Viewer Settings") then 
		imgui.begin_rect()
			local EMVSetting_was_changed
			changed, EMVSettings.load_json = imgui.checkbox("Persistent Settings", EMVSettings.load_json); EMVSetting_was_changed = EMVSetting_was_changed or changed
			imgui.same_line()
			if imgui.button("Reset Settings") then 
				EMVSettings = merge_tables({}, default_settings)
				EMVSetting_was_changed = true
			end
			if (figure_mode or forced_mode or cutscene_mode or total_objects) and not imgui.same_line() and imgui.button("Restart EMV") then 
				--forced_object = forced_mode
				EMV.clear_figures()
			end 
			--[[
			changed, EMVSettings.max_element_size = imgui.drag_int("Max Fields/Properties Per-Grouping", EMVSettings.max_element_size, 1, 1, 2048); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, SettingsCache.affect_children = imgui.checkbox("Affect Children", SettingsCache.affect_children); EMVSetting_was_changed = EMVSetting_was_changed or changed	
			changed, EMVSettings.show_all_fields = imgui.checkbox("Show Extra Fields", EMVSettings.show_all_fields); EMVSetting_was_changed = EMVSetting_was_changed or changed]]
			--changed, SettingsCache.remember_materials = imgui.checkbox("Remember Material Settings", SettingsCache.remember_materials); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.sync_face_mots = imgui.checkbox("Sync Animations", EMVSettings.sync_face_mots); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.transparent_bg = imgui.checkbox("Transparent Background", EMVSettings.transparent_bg); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.cutscene_viewer = imgui.checkbox("Cutscene Viewer", EMVSettings.cutscene_viewer); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.detach_ani_viewer = imgui.checkbox("Detach Animation Seek Bar", EMVSettings.detach_ani_viewer); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.detach_cs_viewer = imgui.checkbox("Detach Cutscene Seek Bar", EMVSettings.detach_cs_viewer); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.customize_cached_banks = imgui.checkbox("Remove mismatched motlists", EMVSettings.customize_cached_banks); EMVSetting_was_changed = EMVSetting_was_changed or changed
			--changed, EMVSettings.allow_performance_mode = imgui.checkbox("Allow Performance Mode", EMVSettings.allow_performance_mode); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.use_savedata = imgui.checkbox("Cache Figure Data", EMVSettings.use_savedata); EMVSetting_was_changed = EMVSetting_was_changed or changed
			changed, EMVSettings.hotkeys = imgui.checkbox("Enable Hotkeys", EMVSettings.hotkeys); EMVSetting_was_changed = EMVSetting_was_changed or changed
			if (figure_mode or forced_mode or cutscene_mode) and EMVSettings.hotkeys then
				imgui.text((cutscene_mode and "	[F] - Enable/Disable Free Cam\n" or "")  
				.. "	[T] - Pause/Unpause\n	[2] - Step Left ('Shift' faster, 'Alt' slower)\n	[4] - Step Right ('Shift' faster, 'Alt' slower)\n	[5] - Set A-B Loop\n	[U] - Shuffle\n	[6] - Seek All On/Off" 
				.. (figure_mode and "\n	[H] - Toggle Centering" or "")
				.. (cutscene_mode and "\n	[-] - Zoom In\n	[+] - Zoom Out" or "")
				.. ((not figure_mode and grab) and "\n	[G] - Grab/Ungrab" or ""))
			end
			local cm_changed
			if isRE2 then  
				cm_changed, EMVSettings.special_mode = imgui.combo("Specific Cutscene Anims", EMVSettings.special_mode, {"All Non-cutscene Animations", "Claire Cutscenes", "Ada Cutscenes"} ); EMVSetting_was_changed = EMVSetting_was_changed or cm_changed
				if cm_changed then 
					re.msg("You must restart the game to see the changes")
				end
				--cm_changed, EMVSettings.claire_mode = imgui.checkbox("Claire Cutscene Anims (Requires Restart)", EMVSettings.claire_mode); EMVSetting_was_changed = EMVSetting_was_changed or changed 
			end
			
			if (isRE2 or isRE3) and figure_mode then
				static_objs.gamemaster = static_objs.gamemaster or scene:call("findGameObject(System.String)", "30_GameMaster")
				recordmanager = recordmanager or (static_objs.gamemaster and lua_find_component(static_objs.gamemaster, sdk.game_namespace("gamemastering.RecordManager")))
				if recordmanager and imgui.button("Unlock All Figures") then
					recordmanager:set_field("<Naomi>k__BackingField", true)
				end
			end
			if imgui.button("Re-Cache Animations") then  --(figure_mode or forced_mode) and
				EMVCache.global_cached_banks, global_cached_banks, pre_cached_banks = {}, {}, {}
				RN.loaded_resources = false
				if forced_mode then
					forced_mode = total_objects[1]
					forced_mode.init_transform = forced_mode.xform:call("get_WorldMatrix")
				end
			end
			--imgui.same_line()
			if imgui.button("Clear Motbank Resource Cache") or cm_changed then 
				RSCache.motbank_resources = {}
				RN.motbank_resource_names = {}
				json.dump_file("EMV_Engine\\RSCache.json", jsonify_table(RSCache))
				res.reset()
				EMVSetting_was_changed = true
			end
			imgui.same_line() 
			
			if imgui.button("Clear Figure Saved Data") then 
				EMVCache = merge_tables({}, default_cache)
				json.dump_file("EnhancedModelViewer\\EMVCache.json", jsonify_table(EMVCache))
				EMVSetting_was_changed = true
			end
			
			if EMVSetting_was_changed then 
				json.dump_file("EnhancedModelViewer\\EMVSettings.json", jsonify_table(EMVSettings))
			end
		imgui.end_rect()
		imgui.tree_pop()
	end
end

re.on_draw_ui(function()
	show_emv_settings()
end)

--not_loaded = true
--bodyCount = 0
re.on_frame(function()
	
	tics = tics + 1
	uptime = os.clock()
	start_time = start_time or uptime
	toks = math.floor(uptime * 100)
	EMVSetting_was_changed = nil
	
	if tics == 1 then 
		EMVSettings.init_EMVSettings()
	end
	
	--[[
	results = {}; 
	for i, result in ipairs(search("event")) do 
		table.insert(results,{obj=result, amt=result:call("get_GameObject"):call("get_Components"):get_size()}) 
	end; 
	qsort(results, "amt")
	
	results = {}; 
	for i, result in ipairs(findc("via.timeline.Timeline")) do 
		table.insert(results,{obj=result, amt=result:call("get_BindGameObjects"):get_size()}) 
	end; 
	qsort(results, "amt")
	]]
	
	if static_objs.scene_manager and not scene then 
		scene = sdk.call_native_func(static_objs.scene_manager, sdk.find_type_definition("via.SceneManager"), "get_CurrentScene") 
	end
	
	--if not (isRE8 or isRE2 or isRE3 or isDMC or isMHR) then return end
	
	if reframework:is_drawing_ui() then
		figure_mgr = (isRE8 and scene:call("findGameObject(System.String)", "GUIFigureList")) or (isDMC and scene:call("findGameObject(System.String)", "ModelViewerCamera")) or scene:call("findGameObject(System.String)", "FigureManager")	
		figure_mode = not not figure_mgr
		--[[if isRE8 then 
			figure_mode = find(isRE8 and "app.FigureDataHolder")[1]
			figure_mode = figure_mode and (held_transforms[figure_mode] or GameObject:new_AnimObject{xform=figure_mode}) or nil
		end]]
		
		if EMVSettings.cutscene_viewer and not cutscene_mode then --and (uptime - start_time) > 15 
			local schedule_obj
			if isRE2 or isRE3 then
				local schedule = scene:call("findGameObject(System.String)", "Schedule")
				schedule_obj = schedule and New_AnimObject({gameobj=schedule})
			end
			if (isDMC or (schedule_obj and not schedule_obj.bind_gameobjects)) and ((tics < 50) or random(50)) then
				--log.info("DMC5 scan")
				--[[local ev_objects = {}
				local results = scene:call("findComponents(System.Type)", sdk.typeof("app.CutScenePlaySetting"))
				results = results and results:add_ref()
				for i, element in ipairs(results.get_elements and results:get_elements() or {}) do
					local gameobj = get_GameObject(element)
					local xform = gameobj and gameobj:call("get_Transform")
					local object = held_transforms[xform] or New_AnimObject({gameobj=gameobj, xform=xform})
					held_transforms[xform] = object
					table.insert(ev_objects, object)
				end]]
				--table.sort (ev_objects, function (obj1, obj2) return #obj1.bind_gameobjects > #obj2.bind_gameobjects end)
				local results = {}
				for i, result in ipairs(findc((isDMC and "app.CutScenePlaySetting") or sdk.game_namespace("timeline.CutSceneMediator"))) do 
					if is_valid_obj(result) then
						local gameobj = get_GameObject(result)
						local timeline = gameobj and lua_find_component(gameobj, "via.timeline.Timeline")
						local amt = timeline and timeline:call("get_BindGameObjects")
						amt = amt and amt.get_size and amt:get_size()
						if amt then
							table.insert(results,{gameobj=gameobj, obj=result, amt=amt}) 
						end
					end
				end
				results = qsort(results, "amt")
				if results and results[1] and results[1].amt > 10 then
					ev_object = New_AnimObject({gameobj=results[1].gameobj})
				end
			end
		end
	end
	
	cutscene_mode = ev_object
	camera = sdk.get_primary_camera()
	camera = camera and camera:add_ref()
	if not camera or tics < 2 then return end
	camera = (tics > 10) and (camera and  get_anim_object(get_GameObject(camera)))
	
	--Take a global GameObject dubbed "forced_object" and turn it into forced_mode animation viewer object:
	if _G.forced_object then
		forced_object:activate_forced_mode()
		forced_object = nil
	end
	
	if ((figure_mode or forced_mode ) and not RN.loaded_resources) then--and (not (RN.motbank_resource_names or {})[3] or not next(RSCache.motbank_resources or {})))	then 
		--re.msg_safe("triggered", 325647)
		--res.reset()
		--EMVSettings.init_EMVSettings()
		--re.msg_safe("Starting res load", 314155)
		if (not RN.loaded_resources) and res and res.finished() then
			EMVCache = jsonify_table(EMVCache, true)
			RN.loaded_resources = true
			global_cached_banks = merge_tables(global_cached_banks, EMVCache.global_cached_banks)
		end
		if RN.loaded_resources then
			--not_loaded = nil
			if (isRE2 or isRE3 or isDMC or isRE8) and not next(global_cached_banks) then
				pre_cached_banks = {}
			end 
			EMV.static_funcs.loaded_json = true
			EMV.static_funcs.init_resources()
		end
		return
	end
	
	local center_gameobj = (static_objs.center and static_objs.center.gameobj or scene:call("findGameObject(System.String)", "dummy_Center"))
	if center_gameobj and not center_gameobj:call("get_Valid") then 
		center_gameobj, static_objs.center = nil 
	end
	
	if not cutscene_mode and center_gameobj then 
		--deferred_calls[center_gameobj] = {func="destroy", args=center_gameobj}
		for i, child in ipairs(get_children(center_gameobj:call("get_Transform")) or {}) do 
			local obj = (held_transforms[child] or GameObject:new_AnimObject{xform=child})
			obj:set_parent(obj.parent_org or obj.parent or 0)
		end
		static_objs.center = nil 
	end
	
	-- Begin EMV stuff ------------------------------------------------------------------------------------
	--Load + cache motions and build list of motion data:
	if pre_cached_banks then -- and RN.motbank_resource_names and RN.motbank_resource_names[3]  then
		log.info("Precache")
		local dummy_obj = get_anim_object(scene:call("findGameObject(System.String)", "dummy_AnimLoaderBody"), {body_part="Body"}) or create_gameobj( "dummy_AnimLoaderBody", {"via.motion.Motion"})
		if dummy_obj and not dummy_obj.motion then 
			local motion = lua_find_component(dummy_obj.gameobj, "via.motion.Motion")
			if motion then 
				local new_layer = motion and sdk.create_instance("via.motion.TreeLayer")
				new_layer = new_layer and new_layer:add_ref()
				if new_layer and new_layer:call(".ctor") then
					motion:call("setLayerCount", 1)
					motion:call("setLayer", 0, new_layer)
					dummy_obj = New_AnimObject({xform=dummy_obj.xform, body_part="Body"})
				end
			end
		end
		local obj_to_check = dummy_obj
		if obj_to_check then 
			log.info("obj to check")
			obj_to_check:pre_cache_all_banks() 
		end
	end
	
	if not (cutscene_mode or figure_mode or forced_mode) then
		return
	end
	
	if figure_mode and not RSCache.motbank_resources then 
		imgui.text("Enhanced Model Viewer: No resources found!")
		return
	end
	
	--Check cutscene mode AB loop and small updates to ev_object
	if ev_object then 
		ev_object.play_state = ev_object.timeline:call("get_PlayState")
		ev_object.frame = ev_object.timeline:call("get_Frame")
		if ev_object.loop_b and ev_object.frame > ev_object.loop_b then
			event_control_action(ev_object, ev_object.loop_a, false)
			for i, anim_object in ipairs(imgui_anims or {}) do 
				anim_object:reset_physics()
			end
		--elseif ev_object.frame < ev_object.loop_a then
		--	deferred_calls[ev_object.timeline] = { { func="set_Frame", args=ev_object.loop_a },{ func="set_PlayState", args=1 } }
		end
		
		--Setup cutscene cam:
		cutscene_cam = cutscene_mode and cutscene_cam
		if cutscene_mode then
			if isRE2 or isRE3 then
				cutscene_cam = get_anim_object(scene:call("findGameObject(System.String)", "EventCameraController"))
			elseif isDMC then
				cutscene_cam = ev_object.components_named.CutScenePlaySetting:get_field("<camera>k__BackingField")
				cutscene_cam = cutscene_cam and get_anim_object(get_GameObject(cutscene_cam))
			end
		end
	end
	
	total_objects = total_objects or {}
	imgui_anims = imgui_anims or {}
	imgui_others = imgui_others or {}
	
	--Build list of model viewer objects:
	if not forced_mode and (not total_objects[1] or not imgui_anims[1] or not imgui_others[1]) then -- and random(60) --or (#imgui_anims == 0 and this_figure_via_motions_count > 1)
		
		log.info("init create total objects")
		
		if not fig_mgr_name then
			fig_mgr_name, current_fig_name = nil, nil
			if cutscene_mode then
				fig_mgr_name = ev_object.name --"m20_220c_Root" 
				current_fig_name = ev_object.name
			elseif isRE8 then 
				fig_mgr_name = "GUIFigureList" --RE8
				current_fig_name = "gl%d.+_Figure"--"gl[%d%d%d%d]_Figure" --RE8
			elseif isRE2 then 
				fig_mgr_name = "IlluminationList" --"LocalCubemap"
				current_fig_name = "^Figure_%a%a%d"
			elseif isDMC then 
				fig_mgr_name = "GUIMesh"
				current_fig_name = "ui5005GUI"
			elseif isRE3 then 
				fig_mgr_name = "GuiBlackBox_Figure"
				current_fig_name = "^Figure_%d%d"
			end
		end
		
		if fig_mgr_name and not cutscene_mode and scene:call("findGameObject(System.String)", fig_mgr_name) then
			total_objects, imgui_anims, imgui_others = {}, {}, {}
			local total_args = {}
			local unique_xforms = {}
			local temp_objs = {}
			current_em_name = nil
			if selected and not is_valid_obj(selected.xform) then 
				selected = nil
			end
			--log.info("starting")
			--[[if isRE8 then 
				local figdata = figure_mode.components_named.FigureDataHolder
				figdata._ = figdata._ or create_REMgdObj(figdata)
				figlist = {}
				local list = merge_indexed_tables(lua_get_system_array(figdata.meshes), lua_get_system_array(figdata.physicsChains))
				list = merge_indexed_tables(list, lua_get_system_array(figdata.physicsCloths))
				list = merge_indexed_tables(list, lua_get_system_array(figdata.chains))
				for i, elem in ipairs(merge_indexed_tables(list, lua_get_system_array(figdata.gpuCloths))) do 
					local xform = get_GameObject(elem, 1)
					figlist[xform] = xform and (held_transforms[xform] or GameObject:new_AnimObject{xform=xform})
				end
			end]]
			--log.info("A")
			all_transforms = lua_get_system_array(scene:call("findComponents(System.Type)", sdk.typeof("via.Transform")) or {}, false, true)
			if all_transforms then --gather gameobjects for model viewer
				--log.info("B")
				local counter = 0
				for i, xform in ipairs(all_transforms) do
					counter = counter + 1
					if is_valid_obj(xform) then 
						local gameobj = get_GameObject(xform)
						if gameobj then 
							local name = gameobj:call("get_Name")
							local new_args = { gameobj=gameobj, xform=xform, index=i, name=name }
							if name:find(fig_mgr_name) then 
								log.info("BREAK at finding " .. name .. ", number " .. i)
								break  
							elseif name:find(current_fig_name) then 
								current_figure_name = (isDMC and total_args[#total_args]  and total_args[#total_args].name) or name
								table.insert(total_args, 1, new_args) -- Should be FIRST
							elseif name:find("[ep][ml]%d%d%d%d") then 
								local idx = name:find("em") or name:find("pl")
								current_em_name = idx and name:sub(idx, idx+5)
								table.insert(total_args, new_args)
							else
								table.insert(total_args, new_args)
							end
						end
					end
				end
				
				--total_args = reverse_table(total_args)
				for i, args in ipairs(total_args) do 
					local new_obj = held_transforms[args.xform] or New_AnimObject(args)
					if new_obj and not unique_xforms[new_obj.xform] then--not contains_xform(temp_objs, new_obj.xform) then
						table.insert(temp_objs, new_obj)
						unique_xforms[new_obj.xform] = #temp_objs
						local name = string.gsub(new_obj.name, '[ \t]+%f[\r\n%z]', '') 
						--[[while not is_unique_name(temp_objs, name) do
							name = name .. " "
						end]]
						if name ~= new_obj.name then 
							new_obj.name = name
							new_obj.gameobj:call("set_Name", name)
						end
						if new_obj.name == current_figure_name then 
							current_figure = new_obj
						end
						if new_obj.name == "UI5005GUI" then 
							dmc5_fig_mgr = new_obj
						end
						if new_obj.parent and not unique_xforms[new_obj.parent] and not contains_xform(total_args, new_obj.parent) then 
							unique_xforms[new_obj.xform] = #temp_objs
							table.insert(total_args, { xform=new_obj.parent })
						end
					end
				end
				for i, obj in ipairs(temp_objs) do --get children
					for i, child in ipairs(obj.children or {}) do 
						if not unique_xforms[child] and not contains_xform(temp_objs, child) then
							local new_obj = held_transforms[child] or New_AnimObject({xform=child})
							if new_obj then 
								table.insert(temp_objs, new_obj)
								unique_xforms[child] = #temp_objs
							end
						end
					end
				end
				for i, obj in ipairs(temp_objs) do
					obj.total_objects_idx = i
					table.insert(total_objects, obj) 
				end
			end
		end
		
		if ev_object and ev_object.bind_gameobjects then --and ev_object.bind_gameobjects then --collect missing actors
			for i, bind_object in ipairs(ev_object.bind_gameobjects) do 
				if not contains_xform(total_objects, bind_object.xform) then
					table.insert(total_objects, bind_object)
				end
			end
			--[[local animatables = scene:call("findComponents(System.Type)", sdk.typeof("via.motion.DummySkeleton"))
			animatables = animatables and animatables.get_elements and animatables:get_elements() or {}
			for i, comp in ipairs(animatables) do 
				animatables[i] = get_GameObject(comp, 1)
			end
			for i, xform in ipairs(animatables) do 
				if not contains_xform(total_objects, xform) then
					table.insert(total_objects, held_transforms[xform] or New_AnimObject({xform=xform})) 
					--if #total_objects > 50 then break end
				end
			end]]
		end
	end
	
	if ((#imgui_anims == 0) or (#imgui_others == 0)) or ((toks % 60) == 0) then
	
		lightsets = {}
		imgui_anims = {}
		imgui_others = {}
		lights = {}
		non_lights = {}
		temp_anims, temp_others, unique_names = {}, {}, {}
		for i, anim_object in ipairs(total_objects) do
			anim_object.total_objects_idx = i
			local name = anim_object.name_w_parent
			while unique_names[name] do
				local idx = name:find(" %-> ")
				name = idx and (name:sub(1, idx-1) .. "_" .. name:sub(idx, -1)) or (name .. "_")
			end
			unique_names[name] = true
			
			if not anim_object.is_AnimObject then 
				anim_object = New_AnimObject({xform=anim_object.xform}, anim_object)
			end
			
			if anim_object.layer and (anim_object.body_part ~= "Hair") then --or anim_object == re2_figure_container_obj then 
			--if (anim_object.layer and (anim_object.body_part ~= "Hair")) or (figure_mode and (num_anims == 0) and anim_object.mesh and (tics - figure_start_time > 100)) then --or anim_object == re2_figure_container_obj then 
				temp_anims[name] = anim_object
			else
				temp_others[name] = anim_object
			end
		end
		
		for i, anim_object in orderedPairs(temp_anims) do
			table.insert(imgui_anims, 1, anim_object)
		end
		
		for i, anim_object in orderedPairs(temp_others) do
			table.insert(imgui_others, 1, anim_object)
		end
		
		local old_disp = lightsets["No Light Set"] and lightsets["No Light Set"].display
		lightsets["No Light Set"] = { display=old_disp==nil and true, lights={}, lights_names={}, display_org=true }
		
		for i, light_obj in ipairs(imgui_others) do 
			if light_obj.is_light then
				table.insert(lights, light_obj)
				if light_obj.lightset_xform and not light_obj.lightset then --and (not forced_mode or forced_mode.xform ~= light_obj.lightset_xform) then 
					held_transforms[light_obj.lightset_xform] = held_transforms[light_obj.lightset_xform] or New_AnimObject({xform=light_obj.lightset_xform})
					if held_transforms[light_obj.lightset_xform] then 
						if held_transforms[light_obj.lightset_xform].name:find("ight") then --
							light_obj.lightset = held_transforms[light_obj.lightset_xform] or New_AnimObject({ xform=light_obj.lightset_xform })
							light_obj.lightset.lights = light_obj.lightset.lights or {}
							light_obj.lightset.lights[light_obj.name] = light_obj
							--light_obj.lightset.gameobj:call("set_UpdateSelf", false)
							if not contains_xform(total_objects, light_obj.lightset.xform) then
								table.insert(total_objects, light_obj.lightset)
							end
							lightsets[light_obj.lightset.name] = light_obj.lightset
						end
					else
						--EMV.clear_figures()
						--return nil
					end
				elseif not light_obj.lightset_xform then
					local idx = table.binsert(lightsets["No Light Set"].lights_names, light_obj.name)
					table.insert(lightsets["No Light Set"].lights, idx, light_obj)
				elseif light_obj.lightset then
					lightsets[light_obj.lightset.name] = light_obj.lightset
				end
			else--if not lightsets[ light_obj.name ] then
				table.insert(non_lights, light_obj)
				if light_obj.name:find("plane") == 1 then 
					background_objs = background_objs or {}
					background_objs[light_obj.xform] = light_obj
				end
			end
		end
		lightsets["No Light Set"].lights_names = nil
		if not lightsets["No Light Set"].lights[1] then 
			lightsets["No Light Set"] = nil 
		end
	end
	
	if total_objects[1] then
		
		if (imgui_anims[1] or imgui_others[1]) and reframework:is_drawing_ui() then 
			
			current_figure_name = current_figure_name or ""
			--current_figure = current_figure or ((current_figure_name ~= "") and scene:call("findGameObject(System.String)", current_figure_name)) or nil
			selected = selected or find_selected(imgui_anims) or base_mesh or imgui_anims[#imgui_anims]
			--if not selected then
			--	EMV.clear_figures()
			--	return
			--end
			
			if not base_mesh then 
				for i, anim_object in ipairs(reverse_table(imgui_anims)) do 
					if anim_object.display then 
						base_mesh = anim_object
						break
					end
				end
			end
			
			figure_start_time = figure_start_time or ((selected or imgui_anims[1]) and tics)
			
			if cutscene_mode and EMVSettings.detach_cs_viewer then
				if imgui.begin_window("Cutscene Viewer" , true, EMVSettings.transparent_bg and 129 or 1) == false then EMVSettings.detach_cs_viewer = false end
					cs_viewer()
				imgui.end_window()
			end
			
			if EMVSettings.detach_ani_viewer and (figure_mode or forced_mode) then
				if imgui.begin_window("Animation Controls" , true, EMVSettings.transparent_bg and 129 or 1) == false then EMVSettings.detach_ani_viewer = false end
					show_animation_controls(nil, 0)
				imgui.end_window()
			end
			
			if imgui.begin_window("Enhanced Model Viewer" .. (cutscene_mode and ": Cutscene Viewer" or ""), not not forced_mode or EMVSettings.cutscene_viewer or nil, EMVSettings.transparent_bg and 128) == false then
				--imgui.text("closing window!")
				if forced_mode then 
					for i, object in ipairs(imgui_anims) do --fix animated objects
						object.total_objects_idx = nil
						if object.mfsm2 then 
							--object.mfsm2:call("set_PuppetMode", false)
							deferred_calls[object.mfsm2] = {{func="set_PuppetMode", args=false}, {func="restartTree"}}
							if object.mbank_idx_orig and object.cached_banks[object.mbank_idx_orig] and object.mbank_idx ~= object.mbank_idx_orig then 
								object:set_motionbank(object.mbank_idx_orig)
								if object.old_dynamic_banks then 
									--object.motion:call("setDynamicMotionBankCount", #object.old_dynamic_banks)
									deferred_calls[object.motion] = {{func="setDynamicMotionBankCount", args=#object.old_dynamic_banks}}
									for i, dbank in ipairs(object.old_dynamic_banks) do
										table.insert(deferred_calls[object.motion], {func="setDynamicMotionBank", args={i-1, dbank}})
										--object.motion:call("setDynamicMotionBank", i-1, dbank)
									end
								end
							end
						end
					end
					forced_mode = nil
				else
					EMVSettings.cutscene_viewer = false
				end
				EMV.clear_figures()
			end
				imgui.text("																	" .. tostring(current_figure_name))
				
				show_emv_settings()
				if imgui.button("Restart EMV") then 
					forced_object = forced_mode
					EMV.clear_figures()
				end
				
				--[[if isRE8 and figure_mode then 
					imgui.text("\nFIGURE SETTINGS")
					imgui_anim_object_viewer(figure_mode)
				end]]
				
				if cutscene_mode then
					if not EMVSettings.detach_cs_viewer then
						imgui.text("\nCUTSCENE VIEWER")
						cs_viewer()
					else
						imgui.new_line()
					end
					imgui_anim_object_viewer(ev_object, "Cutscene Schedule")
				end
				
				local dummy_obj = scene:call("findGameObject(System.String)", "dummy_AnimLoaderBody")
				
				if (pre_cached_banks ~= nil) or dummy_obj then
					imgui.text("Caching motions, please wait... ")
					if not pre_cached_banks then
						deferred_calls[dummy_obj] = {func="destroy", args=dummy_obj}
					end
				elseif imgui_anims[1] then
					
					imgui.text(cutscene_mode and "\nACTORS" or "\nANIMATIONS")
					imgui.begin_rect()
						
						if not cutscene_mode and not EMVSettings.detach_ani_viewer then
							show_animation_controls()
							imgui.text("\n")
						end
						
						for i, anim_object in ipairs(reverse_table(imgui_anims)) do 		
							
							if not imgui_anims[1] then return end
							
							anim_object.selected = (selected == anim_object)
							
							local indent = {""}
							if not cutscene_mode then
								for part in anim_object.name_w_parent:gmatch("[%.]+") do
									table.insert(indent, "	")
								end
							end
							table.remove(indent, #indent)
							imgui.text(table.concat(indent))
							imgui.same_line()
							imgui.begin_rect()
								show_imgui_animation(anim_object, (not cutscene_mode and i))
							imgui.end_rect(0)
						end
						
						--do_prev, do_next, do_shuffle = false
						
					imgui.end_rect(5)
				end
				
				if isRE2 or isRE3 or isDMC then 
					imgui.text("\nCAMERA")
					if figure_mode and not figure_settings and not isDMC then
						for i, elem in ipairs(lua_get_system_array(scene:call("findComponents(System.Type)", sdk.typeof(sdk.game_namespace("FigureObjectBehavior")))) or {}) do 
							figure_settings = figure_settings or  elem:get_field("_FigureSetting")
							figure_behavior = elem
						end
					end
					imgui.begin_rect()
						if ev_object and ev_object.free_cam and cutscene_cam and cutscene_cam.components[2] then 
							changed, ev_object.zoom_level = imgui.drag_float("FOV Zoom", cutscene_cam.components[2]:call("get_FOV"), 0.1, 1, 190)
							if changed then
								deferred_calls[ cutscene_cam.components[2] ] = { func="set_FOV", args=ev_object.zoom_level }
							end
						end
						--[[if figure_settings and imgui.tree_node_ptr_id(figure_settings, "Camera Settings") then
							imgui.managed_object_control_panel(figure_settings)
							imgui.tree_pop()
						end]]
						if figure_behavior and imgui.tree_node("Figure Behavior") then 
							imgui.managed_object_control_panel(figure_behavior)
							imgui.tree_pop()
						end
						if cutscene_mode and cutscene_cam then 
							imgui_anim_object_figure_viewer(cutscene_cam, "Cutscene Camera")
						end
						imgui_anim_object_figure_viewer(camera, "Main Camera Components")
					imgui.end_rect(0)
					
				end
				
				if imgui_others[1] then
					
					if lights[1] and next(lightsets) then
						
						--[[local isRE3 = isRE3
						local isRE2 = isRE2
						if isRE3 and sdk.get_tdb_version() == 70 then
							isRE3 = false
							isRE2 = true
						end]]
						
						imgui.text("\nLIGHTS")
						local unlock_all_changed, move_light_set_changed, show_all_changed
						
						if figure_mode then
							unlock_all_changed, do_unlock_all_lights = imgui.checkbox("Unlock All Lights", do_unlock_all_lights)
							imgui.same_line()
							
							move_light_set_changed, do_move_light_set = imgui.checkbox("Rotate All", do_move_light_set)
							
							if isRE8 and move_light_set_changed then
								unlock_all_changed = true
								do_unlock_all_lights = do_move_light_set 
							end
							
							if unlock_all_changed or (isRE8 and do_move_light_set) then 
								for i, light in ipairs(lights) do
									if light.display then 
										light.unlock_light = do_unlock_all_lights 
									end
								end
							end
							imgui.same_line()
							
						elseif forced_mode and imgui.button("Resample") then
							forced_mode:activate_forced_mode()
						elseif cutscene_mode then
							move_light_set_changed, do_move_light_set = imgui.checkbox("Rotate All", do_move_light_set)
							imgui.same_line()
							if static_objs.center then 
								if is_valid_obj(static_objs.center.xform) then
									if do_move_light_set and static_objs.center then 
										local worldmat = static_objs.center.xform:call("get_WorldMatrix")
										changed, worldmat = draw.gizmo(static_objs.center.xform:get_address()+123, worldmat, nil, imgui.ImGuizmoMode.WORLD)
										if changed then 
											worldmat[3].w = 1
											static_objs.center:set_transform(mat4_to_trs(worldmat, true), isRE2 or isDMC or isRE3)
										end
									end
								else
									static_objs.center = nil
								end
							end
						end
						
						show_all_changed, do_show_all_lights = imgui.checkbox("Show Positions", do_show_all_lights)
						if figure_mode then
							imgui.same_line()
							changed, follow_figure = imgui.checkbox("Follow Figure", follow_figure); EMVSetting_was_changed = EMVSetting_was_changed or changed
						elseif cutscene_mode and do_move_light_set and imgui.tree_node("Center Dummy") then 
							imgui.managed_object_control_panel(static_objs.center.xform)
							imgui.tree_pop()
						end
						
						local unlocked_parent = (isRE8 and current_figure) or (isRE2 and base_mesh) or ((isRE3 or isDMC) and camera) or base_mesh or selected--or camera --(isRE3 and imgui_anims[#imgui_anims]) or camera
						
						if imgui.tree_node("Light Sets") then 
							
							if imgui.button("Reset All") then 
								for i, lightset in pairs(lightsets) do
									lightset.display = lightset.display_org
									if lightset.display then
										if lightset.toggle_display then 
											lightset:pre_fix_displays()
											lightset:toggle_display()
										end
										for j, light in pairs(lightset.lights) do
											if light.display then
												light:set_parent(light.parent_org or (light.parent_obj and light.parent_obj.name~="dummy_Center" and light.parent_obj.xform) or 0, true)
												light:set_transform(mat4_to_trs(light.init_worldmat, true), true)
												--write_transform(light, pos, rot, scale) 
												--deferred_calls[light.gameobj] = { lua_func=write_transform, args={light, pos, rot, scale} } --mat4_to_trs(light.init_worldmat)
											end
										end
									end
								end
								do_move_light_set = false
							end
							
							for name, lightset in orderedPairs(lightsets) do
								imgui.push_id(name .. "Id")
									
									changed, lightset.display = imgui.checkbox((lightset.xform and "") or "	*   No Light Set",  lightset.display)
									if changed and lightset.toggle_display then 
										lightset:pre_fix_displays()
										lightset.display = lightset.display
										lightset:toggle_display()
									end
									
									lightset.opened = nil
									if lightset.xform and not imgui.same_line() and imgui.tree_node(lightset.name) then
										lightset.opened = true
										imgui.text("	")
										imgui.same_line()
										imgui.managed_object_control_panel(lightset.xform)
										imgui.tree_pop()
									end
									if not lightset.display and lightset.closed_count and lightset.closed_count == #lightset.lights then
										lightset.opened = nil
									end
									
									if lightset.display or lightset.opened then 
										
										lightset.closed_count = 0
										for i, light_obj in orderedPairs(lightset.lights or {}) do
											
											lightset.opened = lightset.opened or light_obj.opened
											imgui.text("	"); imgui.same_line()
											imgui.begin_rect() 
											imgui.push_id(light_obj.xform:get_address()-2)
												if light_obj.IBL then 
													imgui_anim_object_figure_viewer(light_obj, nil, i)
												else
													local display_was_changed
													display_was_changed, light_obj.display = imgui.checkbox(light_obj.name,  light_obj.display)
													
													if light_obj.display or light_obj.opened or lightset.opened then
														if light_obj.display then
															imgui.push_id(light_obj.gameobj:get_address()+1)
																if cutscene_mode then
																	imgui.same_line()
																	changed, light_obj.keep_on = imgui.checkbox("Stay",  light_obj.keep_on)
																	if changed then 
																		light_obj.parent_forced = light_obj.keep_on and light_obj.parent
																	end
																	light_obj.keep_on = light_obj.keep_on or nil
																end
																imgui.same_line()
																
																if figure_mode and not light_obj.IBL then
																	changed, light_obj.unlock_light = imgui.checkbox("Unlock", (unlocked_parent and (light_obj.xform:call("get_Parent") == unlocked_parent.xform))) 
																	if changed then 
																		light_obj.pending_light_unlock_change = true 
																	end
																end
																light_obj.is_grabbed = (last_grabbed_object and last_grabbed_object.active and last_grabbed_object.xform == light_obj.xform) or nil
																imgui.same_line()
																if imgui.button(((last_grabbed_object and last_grabbed_object.active and last_grabbed_object.xform == light_obj.xform) and "Detach from Cam") or "Move to Cam") then
																	if figure_mode then 
																		light_obj.pressed_move_button = true
																		--if isRE8 then 
																			light_obj.unlock_light = true 
																			light_obj.pending_light_unlock_change = true 
																		--end
																	else --if cutscene_mode or forced_mode then
																		if _G.grab then --and not last_grabbed_object or last_grabbed_object.xform ~= light_obj.xform then 
																			--light_obj.xform:call("set_Parent", nil)
																			light_obj:set_parent(light_obj.parent_org or 0)
																			grab(light_obj.xform)
																			--light_obj.xform:call("set_Parent", light_obj.parent_org)
																		end
																	end
																end
															imgui.pop_id()
														end
														--imgui_anim_object_viewer(light_obj, "Object", i)
													else
														lightset.closed_count = lightset.closed_count + 1
													end
													
													if imgui.tree_node("Xform") then
														imgui.managed_object_control_panel(light_obj.xform)
														imgui.tree_pop()
													end
													
													if display_was_changed then 
														changed = true
														light_obj:toggle_display()
														--[[light_obj.xform:call("set_Parent", nil)
														light_obj.gameobj:write_byte(0x13, 0)
														light_obj.xform:call("set_Parent", light_obj.parent)]]
														--deferred_calls[light_obj.gameobj] = {lua_object=light_obj.gameobj, method=light_obj.gameobj.write_byte, args={0x13, bool_to_number[light_obj.display]} }
													end
												end
											imgui.pop_id()
											imgui.end_rect(3)
										end
									end
								imgui.pop_id()
							end
							imgui.tree_pop()
						end
						imgui.new_line()
						
						
						if move_light_set_changed  then
							
							local parent_xform = (isRE8 and base_mesh) or current_figure
							
							--local center
							if cutscene_mode then
								static_objs.center = static_objs.center or center_gameobj or create_gameobj("dummy_Center", nil, {worldmatrix=selected and selected.xform:call("get_WorldMatrix"),}, true)
								if not static_objs.center.xform then
									static_objs.center = held_transforms[static_objs.center:call("get_Transform")] or GameObject:new_AnimObject{gameobj=static_objs.center}
								end
								parent_xform = static_objs.center
							end
							
							fixed_figure = (cutscene_mode and static_objs.center) or (isDMC and base_mesh) or selected or base_mesh --re2_figure_container_obj or base_mesh
							
							if not isDMC then
								if fixed_figure.parent then 
									held_transforms[fixed_figure.parent] = held_transforms[fixed_figure.parent] or New_AnimObject({ xform=fixed_figure.parent })
								end
								while fixed_figure.parent and held_transforms[fixed_figure.parent].layer do 
									fixed_figure = held_transforms[fixed_figure.parent] 
								end
							end
							fixed_figure:pre_fix_displays()
							--current_figure:pre_fix_displays()
							--re2_figure_container_obj:pre_fix_displays()
							
							if do_move_light_set then --rotate all
								local position = parent_xform.xform:call("get_LocalPosition")
								--local last_pos = selected.xform:call("get_Position")
								--fixed_figure.xform:call("set_Parent", 0)--(isDMC and camera.xform) or 0)
								if not isRE8 then 
									for i, light_obj in ipairs(lights) do 
										if light_obj.display then
											if not light_obj.unlock_light then
												local wmatrix = light_obj.xform:call("get_WorldMatrix")
												light_obj:pre_fix_displays()
												light_obj:set_parent(parent_xform.xform or 0, isRE2 or isDMC)
												light_obj:set_transform( mat4_to_trs(wmatrix, true), isRE2 or isDMC)
												--deferred_calls[light_obj.gameobj] = { lua_func=write_transform, args={light_obj, pos, rot, scale} }
											end
										end
									end
								end
								if not cutscene_mode then
									fixed_figure:set_parent(0,  isRE2 or isDMC)
									if isDMC then deferred_calls[selected.xform] = {func="set_Position", args=selected.xform:call("get_Position")} end
									deferred_calls[parent_xform.xform] = { func="set_LocalPosition", args=position }
								end
							else
								if not isRE8 then 
									for i, light_obj in ipairs(lights) do 
										if light_obj.display and not light_obj.unlock_light then
											light_obj:set_parent((isRE3 and unlocked_parent.xform) or light_obj.parent_org or 0, isRE2 or isDMC)
											--light_obj.xform:call("set_Parent", (isRE3 and unlocked_parent.xform) or light_obj.parent_org or 0)
										end
									end
									if (isRE2 or isDMC or isRE3) and parent_xform then  --correct for new rotatation
										parent_xform.xform:call("set_Rotation", fixed_figure.xform:call("get_Rotation"))
										parent_xform.init_worldmat = parent_xform.init_worldmat or parent_xform.xform:call("get_WorldMatrix")
										if not cutscene_mode then
											local y_difference = parent_xform.init_worldmat[3].y - fixed_figure.init_worldmat[3].y
											local new_pos = parent_xform.init_worldmat and parent_xform.init_worldmat[3]
											fixed_figure.xform:call("set_Position", parent_xform.init_worldmat[3])
											if new_pos then 
												new_pos.y = new_pos.y - y_difference
												deferred_calls[fixed_figure.xform] = {func="set_Position", args=new_pos} 
											end -- ,{lua_object=parent_xform.gameobj, method=write_byte, args={0x12, 1} } }
										end
									end
								end
								fixed_figure:set_parent(fixed_figure.parent_org)
								--fixed_figure.xform:call("set_Parent", parent_xform.xform or 0) 
								if isRE3 then --else its offset
									for i, light_obj in ipairs(lights) do 
										if light_obj.display and not light_obj.unlock_light then
											light_obj:set_parent(light_obj.parent_org or 0, true)
											--deferred_calls[light_obj.xform] = {func="set_Parent", args=light_obj.parent_org or 0}
										end
									end
								end
							end
							fixed_figure:toggle_display()
							--re2_figure_container_obj:toggle_display()
						end
						
						local follow_figure_pos
						for i, light_obj in ipairs(lights) do
							if not is_valid_obj(light_obj.xform) then 
								lights = arrayRemove(lights, function(light_obj) return true; end)
							end
						end
						
						for i, light_obj in ipairs(lights) do 
							
							if light_obj.display then 
								if unlock_all_changed then 
									if do_unlock_all_lights and not light_obj.IBL then
										light_obj.unlock_light = true 
									else
										light_obj.unlock_light = false
									end
								end
								
								if light_obj.pending_light_unlock_change or unlock_all_changed or (isRE8 and move_light_set_changed) then
									if light_obj.unlock_light then
										light_obj:set_parent(unlocked_parent.xform or 0)
									else
										light_obj:set_parent(light_obj.parent_org or 0)
									end
									light_obj.pending_light_unlock_change = nil
								end
							end
							
							if selected and ((figure_mode and follow_figure) or light_obj.pressed_move_button) and not light_obj.IBL then 
								
								local target_obj = selected --re2_figure_container_obj or selected
								local pos_obj = target_obj.cog_joint or target_obj.xform
								local pos = is_valid_obj(pos_obj) and pos_obj:call("get_Position")-- target_obj.last_cog_pos
								follow_figure_pos =  follow_figure_pos or (isRE3 and follow_figure and target_obj.cog_joint and (pos - pos_obj:call("get_BaseLocalPosition")) or pos)
								--if not pos then 
									--pos = pos_obj:call("get_Position")
									--pos.y = pos.y + 0.75
									--draw_world_pos(pos)
								--end
								if pos then 
									local def_call = {} --RE3 must be done here and now, other games must be done as deferred calls...
									local par = light_obj.xform:call("get_Parent")
									
									if light_obj.pressed_move_button then
										if isRE3 then
											light_obj:set_transform(mat4_to_trs(camera.xform:call("get_WorldMatrix"), true))
										else
											light_obj:set_transform(mat4_to_trs(camera.xform:call("get_WorldMatrix"), true), true)
										end
										light_obj.display = true
										light_obj:pre_fix_displays()
										light_obj:toggle_display()
										light_obj.pressed_move_button = nil
									elseif follow_figure then
										if isRE3 then
											if light_obj.lightset then  
												--light_obj.lightset.xform:call("set_Position", target_obj.cog_joint and (pos - pos_obj:call("get_BaseLocalPosition")) or pos)
												
												light_obj.lightset:set_transform({follow_figure_pos}, true)
											end
										end
									end
									
									if isRE3 then
										light_obj.xform:call("lookAt(via.vec3, via.vec3)", pos, Vector3f.new(0,1,0))
									else
										deferred_calls[light_obj.xform] = deferred_calls[light_obj.xform] or {}
										table.insert(deferred_calls[light_obj.xform], { lua_object=light_obj, method=GameObject.set_parent, args=0})
										table.insert(deferred_calls[light_obj.xform], { func="lookAt(via.vec3, via.vec3)", args={pos, Vector3f.new(0,1,0)} } )
										table.insert(deferred_calls[light_obj.xform], { lua_object=light_obj, method=GameObject.set_parent, args=par})
									end
								end
							end	
							
							if (do_show_all_lights and light_obj.display and not light_obj.IBL and (not light_obj.lightset or light_obj.lightset.display)) then 
								draw_world_xform(light_obj) 
							end				
						end
					end
					
					imgui.text("\nOTHER OBJECTS")
					local function display_other()
						local others = {}
						for i, non_light in ipairs(non_lights) do others[non_light.name_w_parent] = non_light end
						for i, non_light in orderedPairs(non_lights) do 
							non_light.name_w_parent = non_light.name_w_parent or non_light.name
							local indent = {""}
							for part in non_light.name_w_parent:gmatch("[^ %-> ]+") do
								table.insert(indent, "	")
							end
							table.remove(indent, #indent)
							imgui.text(table.concat(indent))
							imgui.same_line()
							imgui_anim_object_figure_viewer(non_light, non_light.name_w_parent or non_light.name)
						end
					end

					--[[for name, non_light in orderedPairs(others) do --sort
						non_lights[i] = non_light
						i = i + 1
					end]]
					
					if #non_lights > 5 then 
						if imgui.tree_node("Others") then
							display_other()
							imgui.tree_pop()
						else
							imgui.text()
						end
						
					else
						display_other()
					end
				end
				
				if figure_mode and background_objs and next(background_objs) then  
					imgui.text("\nBACKGROUND")
					if imgui.tree_node("Background") then
						for xform, obj in orderedPairs(background_objs) do 
							if is_valid_obj(xform) then 
								imgui.begin_rect()
								--imgui.push_id(xform:get_address()-7)
									imgui_anim_object_figure_viewer(obj)
								--imgui.pop_id()
								imgui.end_rect(0)
							else
								background_objs[xform] = nil
							end
						end
						imgui.tree_pop()
					end
				end
				
				if EMVSetting_was_changed == true then 
					json.dump_file("EnhancedModelViewer\\EMVSettings.json", jsonify_table(EMVSettings))
				end
				
				--if figure_mode and not current_figure then
					--EMV.clear_figures()
				--end
				
				imgui.text("																	Script By alphaZomega")
			imgui.end_window()
		end
	else
		figure_start_time = nil
	end
	
end)