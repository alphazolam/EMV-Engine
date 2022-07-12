--RE2 and RE3 Enemy Spawner by alphazomega
--June 26, 2022
--if true then return end
local EMV = require("EMV Engine")

SettingsCache.loiter_by_default = true
spawned_prefabs = {}
local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene") 
local spawned_prefabs_folder = EMV.static_objs.spawned_prefabs_folder
if not spawned_prefabs_folder then return end
local spawned_enemies_count = 0
local ray_method = sdk.find_type_definition( "via.collision" ):get_method("find(via.Ray, via.Plane, via.vec3, System.Single, via.vec3)")
local last_camera_matrix = Matrix4x4f.new()
local prefabs = {}
local prefab_names = {}
local emmgr
local enemy_pfb_idx = 1
local player_pfb_idx = 1
local deferred_prefab_calls = {}
local add_pfb_text = ""
local spawned_lights = {} 
local last_camera_pos
local toks
local changed
local GameObject = EMV.GameObject
local is_valid_obj = EMV.is_valid_obj
local random = EMV.random
local random_range = EMV.random_range
local reverse_table = EMV.reverse_table
local orderedPairs = EMV.orderedPairs

local function get_enumerator(managed_object)
	local output = {}
	managed_object = managed_object:call("GetEnumerator") or managed_object
	local name = managed_object:get_type_definition():get_full_name()
	
	if name:find(">d") or name:find("Dictionary") or name:find("erable") then 
		--managed_object:call(".ctor", 0)
		while managed_object:call("MoveNext") do 
			local current = managed_object:call("get_Current")
			if current then 
				output[current:call("get_Key")] = current:call("get_Value")
			end
		end
	else
		while managed_object:call("MoveNext") do 
			table.insert(output, managed_object:get_field("mCurrent"))
		end
	end
	return output
end

function get_prefabs()
	local prefabs = { players={}, player_names={}, enemies={}, enemy_names={} }	
	if isDMC then 
		local enemy_manager = sdk.get_managed_singleton(sdk.game_namespace("EnemyManager"))
		local enemy_prefab_manager = enemy_manager and enemy_manager:get_field("PrefabManager")
		local prefabs_dotnet_list = enemy_prefab_manager and enemy_prefab_manager:get_field("EnemyPrefabInfoList")
		local items = prefabs_dotnet_list and prefabs_dotnet_list:get_field("mItems")
		local prefabs_list = items and items:get_elements()
		for i, prefab_info in ipairs(prefabs_list or {}) do
			local current_load_prefab = prefab_info:get_field("CurrentLoadPrefab")
			--if current_load_prefab == nil then
				local pfb = prefab_info:get_field("EnemyPrefab")
				local name=pfb:call("get_Path"):match("^.+/(.+)%.pfb") 
				if not string.find(name, "vergil") and not string.find(name, "dante") and not string.find(name, "gilgamesh") then
					prefab_info:call("requestLoad", false)
					prefab_info:call("update")
					prefabs.enemies[name:lower()] = { prefab=pfb, name=name }
					EMV.add_pfb_to_cache(pfb)
				end
			--end
		end
	else
		local dlc_folder = scene:call("findFolder", "RopewayContents_Rogue")
		if dlc_folder and dlc_folder:call("get_Active") == false then 
			dlc_folder:call("activate")
			return
		end
		local survivor_catalog = scene:call("findComponents(System.Type)", sdk.typeof(sdk.game_namespace("SurvivorRegister")))
		if survivor_catalog and survivor_catalog.get_elements then 
			for i, catalog in ipairs(reverse_table(survivor_catalog:get_elements()) or {}) do
				local userdata = catalog:get_field("UserData")
				local survivors = get_enumerator(userdata:get_field("SurvivorParamList"))
				for j, survivorparam in ipairs(survivors) do
					local survivor_prefabs = survivorparam:get_field("Prefabs")
					local pfbs = survivor_prefabs and {player=survivor_prefabs:get_field("Player"), npc=survivor_prefabs:get_field("Npc"), actor=survivor_prefabs:get_field("Actor")}
					for key, pfb in pairs(pfbs) do 
						local path = pfb:call("get_Path")
						if path and path ~= "" then 
							local name = path:match("^.+/(.+)%.pfb") .. "_" .. key
							prefabs.players[name:lower()] = { prefab=pfb, name=name, body_part_idx=1 }
							EMV.add_pfb_to_cache(pfb)
						end
					end
				end
			end
		end
		local costume_catalog = scene:call("findComponents(System.Type)", sdk.typeof(sdk.game_namespace("CostumeRegister")))
		
		if costume_catalog and costume_catalog.get_elements and isRE2 then 
			for i, catalog in ipairs(reverse_table(costume_catalog:get_elements())) do
				local userdata = catalog:get_field("UserData")
				local costumes = userdata:get_field("UserDataList"):get_elements()
				for j, costumeparam in ipairs(costumes) do
					local survivor_type = costumeparam:get_field("SurvivorType")
					local costume_params = costumeparam:get_field("CostumeParams")
					if costume_params then 
						for k, element in ipairs(costume_params:get_elements()) do
							local pfbs = { body=element:get_field("_Body"), face=element:get_field("_Face"), hair=element:get_field("_Hair"), other=element:get_field("_Other") } 
							for key, pfb in pairs(pfbs) do 
								local path = pfb:call("get_Path")
								if path and path ~= "" then 
									local name = path:match("^.+/(.+)%.pfb")
									local strings = table.pack("_player", "_npc", "_actor")
									for m=1, 3 do 
										local str = name:lower():sub(1,6) .. strings[m]
										if prefabs.players[str] then 
											prefabs.players[str].child_prefabs = prefabs.players[str].child_prefabs or {}
											prefabs.players[str].child_prefabs[key] = prefabs.players[str].child_prefabs[key] or {}
											prefabs.players[str].child_prefabs[key][name] = { prefab=pfb, name=name }
											EMV.add_pfb_to_cache(pfb)
										end
									end
								end
							end
						end
					end
				end
			end
			
			for key, prefab in pairs(prefabs.players) do --make alphabetical names lists for comboboxes
				local new_tbl = {}
				prefab.body_part_names = {}
				for body_part, child_prefabs_list in orderedPairs(prefab.child_prefabs) do 
					if not body_part:find("_names") then
						table.insert(prefab.body_part_names, body_part)
						local tbl = {}
						for name, packed_pfb in orderedPairs(child_prefabs_list) do
							table.insert(tbl, name)
						end
						new_tbl[body_part .. "_names"] = tbl
						child_prefabs_list.idx = 1
					end
				end
				for body_part_names, names_list in pairs(new_tbl) do --merge
					prefabs.players[key].child_prefabs[body_part_names] = names_list
				end
			end
			for pfb_name, pfb_packed in orderedPairs(prefabs.players) do
				table.insert(prefabs.player_names, pfb_name)
			end
		end
		
		local registers = scene:call("findComponents(System.Type)", sdk.typeof(sdk.game_namespace("EnemyDataManager")))
		registers = registers and registers.get_elements and registers:get_elements() or {}
		if not registers then return end
		
		for i, registry in ipairs(registers) do 
			local pfb_dict = get_enumerator(registry:call("get_EnemyDataTable"))
			for type_id, pfb_register in pairs(pfb_dict) do 
				local prefab_ref = pfb_register:get_field("Prefab")
				prefab_ref:call("set_DefaultStandby", true)
				local via_prefab = prefab_ref:get_field("PrefabField")
				local name = via_prefab:call("get_Path"):match("^.+/(.+)%.pfb")
				if not name:find("em0[678]00") then --no low-LOD zombies
					prefabs.enemies[name:lower()] = { prefab=via_prefab, name=name, type_id=type_id, ref=prefab_ref }
				end
			end
		end
	end
	for pfb_name, pfb_packed in orderedPairs(prefabs.enemies) do
		table.insert(prefabs.enemy_names, pfb_name)
	end
	return prefabs
end

local function clear_object(xform)
	EMV.clear_object(xform)
	spawned_lights[xform] = nil
	spawned_prefabs[xform] = nil
end

GameObject.clear_Spawn = function(self, xform, is_player)
	xform = xform or self.xform
	spawned_lights[xform] = nil
	spawned_prefabs[xform] = nil
	if is_player then
		spawned_prefabs, spawned_lights = {}, {}
		spawned_prefabs_folder:call("deactivate") --fixes infinite loading
		spawned_prefabs_folder:call("activate")
	end
end

local function spawn_zombie(pfb_name, pfb, folder)
	
	folder = folder or spawned_prefabs_folder 
	local pfb = pfb or (prefabs.players and prefabs.players[pfb_name] and prefabs.players[pfb_name].prefab) or (prefabs.enemies and prefabs.enemies[pfb_name] and prefabs.enemies[pfb_name].prefab) 
	if not pfb then return end
	pfb:call("set_Standby", true)
	local random_dir = Vector4f.new(math.random(-100,100)*0.01,  0.0, math.random(-100,100)*0.01, math.random(-100,100)*0.01):normalized():to_quat()
	local spawn_pos = last_impact_pos
	--if spawn_pos then spawn_pos.y = spawn_pos.y + 1 end
	local packed_pfb = (pfb and { prefab=pfb, name=pfb:call("get_Path"):match("^.+/(.+)%.pfb")}) or prefabs.players[pfb_name] or prefabs.enemies[pfb_name]
	deferred_prefab_calls[pfb] = { func_name="instantiate(via.vec3, via.Quaternion, via.Folder)", args=table.pack(spawn_pos or last_camera_pos, random_dir, folder), counter=0, packed_pfb=packed_pfb }
	if pfb_name and pfb_name:find("arasite") then 
		deferred_prefab_calls[pfb].zombie = { func_name="instantiate(via.vec3, via.Quaternion, via.Folder)", args=table.pack(spawn_pos or last_camera_pos, random_dir, folder), counter=0, packed_pfb=prefabs.enemies["em0000"] }
	end
	return deferred_prefab_calls[pfb]
end

local function spawn_deferred_prefab(packed_func_call)
	
	if not packed_func_call.packed_pfb or not packed_func_call.packed_pfb.prefab then 
		log.info("NO PFB")
		EMV.log_value(packed_func_call)
		return nil
	end
	
	local pfb = packed_func_call.packed_pfb.prefab
	local gameobj
	
	if not packed_func_call.already_exists then
		pfb:call("set_Standby", true)
		gameobj = pfb:call(packed_func_call.func_name, table.unpack(packed_func_call.args)) --spawn
		if isRE2 or isRE3 then
			local guid = ValueType.new(sdk.find_type_definition("System.Guid")):call("NewGuid")
			emmgr:call("requestInstantiate", guid, packed_func_call.packed_pfb.type_id, packed_func_call.packed_pfb.name, emmgr:get_field("<LastPlayerStaySceneID>k__BackingField"), packed_func_call.args[1], packed_func_call.args[2], true, nil, nil)
			emmgr:call("execInstantiateRequests")
		end
	end
	
	gameobj = gameobj or scene:call("findGameObject(System.String)", packed_func_call.packed_pfb.name) --NOT lowercase
	local xform = gameobj and gameobj:call("get_Transform")
	
	if xform then 
		local new_spawn = spawned_prefabs[xform] or GameObject:new{xform=xform}
		if not isDMC then
			new_spawn.is_loitering=SettingsCache.loiter_by_default
			for i, component in ipairs(new_spawn.components) do 
				local name = component:call("ToString()"):lower()
				if name:find("em%d%d") or name:find("enemy") and not name:find("hink") then
					if not pcall(sdk.call_object_func, component, "awake") then 
						log.info(name)
					end
				end
				if name:find("character") then 
					pcall(sdk.call_object_func, component, "warp")
				end
				if name:find("em%d%d%d%dparam") then
					pcall(sdk.call_object_func, component, "set_LoiteringEnable", true)
					new_spawn.emparam = component
				elseif name:find("loitering") then 
					if SettingsCache.loiter_by_default then 
						pcall(sdk.call_object_func, component, "requestLoitering")
					end
					new_spawn.loitering = component
				end
			end
		end
		
		packed_func_call.already_exists = true
		packed_func_call.counter = packed_func_call.counter + 1
		packed_func_call.xform = xform
		
		if packed_func_call.counter == 1 then -- awake+start the components two times
			deferred_prefab_calls[pfb] = nil
			--new_spawn.packed_xform = table.pack(packed_func_call.args[1], new_spawn.rot, new_spawn.scale)
		end
		--old_calls[pfb] = packed_func_call
		spawned_prefabs[xform] = new_spawn
		return new_spawn
	--elseif isDMC then 
	--	deferred_prefab_calls[pfb] = nil --dmc5 always works
	end
end
--spawn_pfb(F:/modmanager/REtool/mhrise_chunk_000/natives/stm/enemy/em001/07/prefab/em001_07.pfb.17
--prefab/leveldesign/orb/goldorb.pfb
function spawn_pfb(pfb) 
	prefab = pfb or (RSCache.pfb_resources and RSCache.pfb_resources[ RN.pfb_resource_names[all_pfb_idx] ])
	if type(pfb)=="string" then 
		local clean_path = (pfb:match("natives\\%w%w%w\\(.+%.pfb)") or pfb):gsub("\\", "/")
		EMV.add_pfb_to_cache(clean_path)
		prefab = RSCache.pfb_resources[clean_path]
	end
	if prefab and prefab:add_ref() then
		spawn_zombie(nil, prefab)
	end
	return prefab
end

--[[
for i, xform in ipairs(EMV.search("MyLight")) do 
	if xform then 
		spawned_lights[xform] = GameObject.new_GrabObject and GameObject:new_GrabObject{xform=xform} or GameObject:new{xform=xform}
	end
end
]]

local function spawn_light(position, type_name, short_name)
	local create_method = sdk.find_type_definition("via.GameObject"):get_method("create(System.String, via.Folder)")
	local gameobj = create_method:call(nil, "MyLight_" .. short_name .. "_" .. (get_table_size(spawned_lights)+1), 0)
	if gameobj then 
		gameobj:add_ref()
		gameobj:call(".ctor")
		local new_light_component = gameobj:call("createComponent(System.Type)", sdk.typeof(type_name))
		new_light_component:add_ref()
		new_light_component:call(".ctor")
		local light = GameObject:new_GrabObject{gameobj=gameobj}
		if short_name:find("Spot") then 
			light.xform:call("set_Parent", sdk.get_primary_camera():call("get_GameObject"):call("get_Transform"))
		end
		spawned_lights[light.xform] = light
		light.packed_xform = position
		--light = grab(light)
		return light
	end
end

local function show_light_spawner()
	if imgui.tree_node("Light Spawner") then 
		--if imgui.button("clear lights") then spawned_lights = {} end
		imgui.begin_rect()
			local names = {sdk.find_type_definition("via.render.IESLight"), sdk.find_type_definition("via.render.ProjectionSpotLight"), sdk.find_type_definition("via.render.SpotLight")}
			for i, name in ipairs(names) do 
				imgui.begin_rect()
				if imgui.button ("Spawn " .. name:get_name()) then 
					spawn_light(last_camera_matrix[3], name:get_full_name(), name:get_name())
				end
				imgui.end_rect(3)
				if i ~= #names then imgui.same_line() end
			end
			
			for xform, light in pairs(spawned_lights) do 
				if light.xform:read_qword(0x10) ~= 0 then
					if imgui.tree_node_ptr_id(light.xform, light.name) then
						if imgui.button("Mount to Camera") then
							--light.xform:call("set_Parent", 0)
							local cam_xform = sdk.get_primary_camera():call("get_GameObject"):call("get_Transform")
							light.xform:call("set_Parent", cam_xform)
							light.xform:call("set_LocalPosition", Vector3f.new(0,0,0))
							light.xform:call("set_Position", cam_xform:call("get_Position"))
							light.xform:call("set_Rotation", cam_xform:call("get_Rotation")) 
						end
						EMV.imgui_anim_object_viewer(light)
						imgui.tree_pop()
					end
				else
					clear_object(xform)
				end
			end--[[
			if imgui.button("Save Lights") then 
				saved_lights = {}
				for xform, light in pairs(spawned_lights) do 
					saved_lights[light.name] = jsonify_table(light.components_named)
				end
				json.dump_file("GravityGunAndConsole\\GGunSavedLights.json", saved_lights)
			end
			imgui.same_line()
			if imgui.button("Load Lights") then 
				
			end
			]]
		imgui.end_rect(0)
		imgui.tree_pop()
	end
end

--ray_impact_pos = Vector3f.new(0,2,0)

local function show_enemy_spawner()
	
	if imgui.tree_node("Enemy Spawner") then
		--[[local ray = sdk.create_instance("via.Ray", true):add_ref()
		ray:call(".ctor")
		ray:set_field("from", Vector3f.new(last_camera_matrix[3].x,last_camera_matrix[3].y,last_camera_matrix[3].z) )
		ray:set_field("dir", Vector3f.new(0,1,0)) --last_camera_matrix[3] - last_camera_matrix[2]
		local plane = sdk.create_instance("via.Plane", true):add_ref()
		plane:call(".ctor")	
		plane:set_field("dist", 1000.0)
		ray_impact_pos = last_camera_matrix[3]
		ray_method:call(ray, plane, last_camera_matrix[3], 1000.0, ray_impact_pos)
		]]
		
		if not _G.grab then 
			last_impact_pos = last_camera_matrix[3] - (last_camera_matrix[2] * 5.0)
		end
		
		if last_impact_pos then
			draw.world_text("X", last_impact_pos, 0xFF0000FF) --from gravity gun
		end
		
		if (isDMC or isRE2 or isRE3) and (not prefabs or not prefabs.enemies or not next(prefabs.enemies)) then 
			prefabs = get_prefabs()
		end
		
		--if random(32) then
			spawns = get_folders(spawned_prefabs_folder:call("get_Children"))
			--imgui.text(logv(spawns))
			for key, xform in pairs(spawns or {}) do
				if is_valid_obj(xform) then
					local obj = spawned_prefabs[xform] or GameObject:new{xform=xform}
					spawned_prefabs[xform] = obj and (obj.mfsm2 or (isRE8 and obj.components_named.EnemyUpdater)) and obj
				else
					if player and xform == player.xform then
						spawned_prefabs = {}
						spawned_prefabs_folder:call("deactivate") --fixes infinite loading
						spawned_prefabs_folder:call("activate")
						break
					end
					clear_object(xform)
				end
			end
		--end
		imgui.begin_rect()
			if next(prefabs or {}) then 
				imgui.begin_rect()
					if false and isRE2 then --not working, the game is deleting the main object and leaving the mesh objects orphaned
						changed, player_pfb_idx = imgui.combo("Player", player_pfb_idx, prefabs.player_names)
						local body_part_names = prefabs.players[ prefabs.player_names[player_pfb_idx] ].body_part_names
						changed, prefabs.players[ prefabs.player_names[player_pfb_idx] ].body_part_idx = imgui.combo("Player Body Part", prefabs.players[ prefabs.player_names[player_pfb_idx] ].body_part_idx or 1, body_part_names)
						local body_part = body_part_names[ prefabs.players[ prefabs.player_names[player_pfb_idx] ].body_part_idx ]
						local pfb_names = prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs[body_part .. "_names"]
						changed, prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs[body_part].idx = imgui.combo("Child Prefab", prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs[body_part].idx or 1, pfb_names )			
						if imgui.button("Spawn Player") then 
							local deferred_call = spawn_zombie(  prefabs.player_names[player_pfb_idx] )
							for body_part_name, body_part in pairs(prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs) do 
								if not body_part_name:find("_names") then
									local pfb_name = prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs[body_part_name .. "_names"][body_part.idx]
									local packed_pfb = prefabs.players[ prefabs.player_names[player_pfb_idx] ].child_prefabs[body_part_name][pfb_name]
									packed_pfb.prefab:call("set_Standby", true)
									deferred_prefab_calls[packed_pfb.prefab] = { func_name="instantiate(via.vec3, via.Quaternion, via.Folder)", args=deferred_call.args, counter=0, packed_pfb=packed_pfb, parent=deferred_call.packed_pfb.prefab }
								end
							end
						end
					end
					
					changed, enemy_pfb_idx = imgui.combo("Enemy", enemy_pfb_idx, prefabs.enemy_names)
					if imgui.button("Spawn Enemy") then 
						spawn_zombie(prefabs.enemy_names[enemy_pfb_idx])
					end
					
					if (isRE2 or isRE3) and not imgui.same_line() and imgui.button("Spawn Random Zombie") then
						local random_table = {}
						for i, name in ipairs(prefabs.enemy_names) do
							if name:find("em0") or name:find("em8") or name:find("arasite") then 
								table.insert(random_table, i)
							end
						end
						spawn_zombie(prefabs.enemy_names[random_table[random_range(1, #random_table)]])
					end
					
					imgui.same_line()
					if imgui.button("Spawn Random Enemy") then
						local name = prefabs.enemy_names[random_range(1, #prefabs.enemy_names)]
						if isRE2 or isRE3 then
							while name:find("em9000") or name:find("em7400") do
								name = prefabs.enemy_names[random_range(1, #prefabs.enemy_names)]
							end
						end
						spawn_zombie(name)
					end
					
					if isRE2 or isRE3 then 
						imgui.same_line()
						changed, SettingsCache.loiter_by_default = imgui.checkbox("Loiter", SettingsCache.loiter_by_default)
						if changed then 
							for xform, object in pairs(spawned_prefabs) do 
								object.is_loitering = SettingsCache.loiter_by_default
							end
						end
					end
				imgui.end_rect()
			end
			
			if next(RSCache.pfb_resources or {}) then
				if imgui.button("Spawn") then 
					spawn_pfb()
				end
				imgui.same_line()
				changed, all_pfb_idx = imgui.combo("All Prefabs", all_pfb_idx, RN.pfb_resource_names)
			end
			
			local full_txt = add_pfb_text:find("%.pfb$")
			local do_set = full_txt and (imgui.button("Add"))
			if full_txt then 
				imgui.same_line()
			end
			changed, add_pfb_text = imgui.input_text("Add PFB File", add_pfb_text)
			if do_set then 
				EMV.add_pfb_to_cache(add_pfb_text)
				if RSCache.pfb_resources[add_pfb_text] then
					all_pfb_idx = EMV.find_index(RN.pfb_resource_names, add_pfb_text)
					add_pfb_text = ""
				end
			end
			
			imgui.text("*Enemy/Prefab will spawn at the red 'X'")
			if imgui.button("Clear Spawns") then -- (Fix Infinite Loading)
				prefabs = {}
				spawned_prefabs_folder:call("deactivate")
				spawned_prefabs_folder:call("activate")
				if (isRE2 or isRE3) and emmgr then 
					emmgr:call("get_ActiveEnemyList"):call("TrimExcess") 
				end
				for xform, object in pairs(spawned_prefabs) do
					object.gameobj:call("destroy", object.gameobj)
					clear_object(xform)
				end
			end 
			
			if next(spawned_prefabs) and imgui.tree_node("Existing Spawns (" .. get_table_size(spawned_prefabs) .. ")") then 
				for xform, obj in pairs(spawned_prefabs) do 
					if is_valid_obj(xform) and imgui.tree_node_ptr_id(xform, obj.name .. " @ " .. xform:get_address()) then
						changed, obj.is_loitering = imgui.checkbox("Loiter", obj.is_loitering)
						--if changed and obj.is_loitering then tics = tics + 240 - (toks % 240) end 
						imgui.managed_object_control_panel(obj.xform)
						imgui.tree_pop()
					end
				end
				imgui.tree_pop()
			end
		imgui.end_rect(2)
		imgui.tree_pop()
	end
end

re.on_application_entry("UpdateMotion", function()
	
	local toks = math.floor(os.clock()*100)
	last_camera_matrix = sdk.get_primary_camera()
	if not last_camera_matrix then return end
	last_camera_matrix = last_camera_matrix:call("get_WorldMatrix")
	
	if next(deferred_prefab_calls) ~= nil then
		emmgr = emmgr or sdk.get_managed_singleton(sdk.game_namespace("EnemyManager"))
		for pfb, packed_func_call in orderedPairs(deferred_prefab_calls) do --enemy spawner, code to actually spawn it
			if packed_func_call then
				local spawn = (not packed_func_call.zombie or packed_func_call.zombie.xform) and spawn_deferred_prefab(packed_func_call)
				local zombie = packed_func_call.zombie and spawn_deferred_prefab(packed_func_call.zombie)
				if spawn and packed_func_call.zombie and packed_func_call.zombie.xform then 
					spawn.xform:call("set_Parent", packed_func_call.zombie.xform)
				end
				if spawn then 
					--if packed_func_call.global_varname then 
					--	_G[packed_func_call.global_varname] = spawn
					--end
					_G.last_spawn = spawn
					deferred_prefab_calls[pfb] = nil
				end
			end
		end
	end
	if next(spawned_prefabs) then
		--[[if rem_count > 5 then --if more than 5 were removed from touched_gameobjects in one frame, then it's probably been cleared and the game is reloading 
			is_calling_hooked_function = true
			for xform, object in pairs(spawned_prefabs) do
				object.gameobj:call("destroy")
				clear_object(xform)
			end
			is_calling_hooked_function = false
			spawned_prefabs = {}
			spawned_prefabs_folder:call("deactivate")
			spawned_prefabs_folder:call("activate")
		else]]
		if (isRE2 or isRE3) and (toks % 240 == 0) then
			for xform, obj in pairs(spawned_prefabs) do 
				if obj.is_loitering and random(3) then 
					if obj.emparam then  pcall(sdk.call_object_func, obj.emparam, "set_LoiteringEnable", true) end
					if obj.loitering then  pcall(sdk.call_object_func, obj.loitering, "requestLoitering") end 
				end
			end
		end
	end
end)

re.on_draw_ui(function()
	show_enemy_spawner()
	--show_light_spawner()
end)

return {
	show_light_spawner = show_light_spawner,
	show_enemy_spawner = show_enemy_spawner,
}