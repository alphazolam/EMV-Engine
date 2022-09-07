--REResource.lua
--REFramework Script for managed RE Engine files 
--by alphaZomega
--July 27 2022

local EMV = require("EMV Engine")

local bool_to_number = { [true]=1, [false]=0 }
local number_to_bool = { [1]=true, [0]=false }
local game_name = reframework.get_game_name()
local tdb_ver = sdk.get_tdb_version()
local isOldVer = tdb_ver <= 67
local addFontSize = 3
local nativesFolderType = ((tdb_ver <= 67) and "x64") or "stm"
local changed

local CHINESE_GLYPH_RANGES = {
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0x2000, 0x206F, -- General Punctuation
    0x3000, 0x30FF, -- CJK Symbols and Punctuations, Hiragana, Katakana
    0x31F0, 0x31FF, -- Katakana Phonetic Extensions
    0xFF00, 0xFFEF, -- Half-width characters
    0x4e00, 0x9FAF, -- CJK Ideograms
    0,
}

local utf16_font = imgui.load_font("NotoSansJP-Regular.otf", imgui.get_default_font_size() + addFontSize, CHINESE_GLYPH_RANGES)


-- Core resource class with important file methods shared by all specific resource types:
REResource = {
	
	typeNamesToSizes = {
		UByte=1,
		Byte=1,
		UShort=1,
		Short=2,
		Int=4,
		UInt=4,
		Int64=8,
		UInt64=8,
		Vec2=8,
		Vec3=16,
		Vec4=16,
		GUID=16,
	},
	
	-- Creates a new Resource with a potential bitstream, filepath (and file if it is found), and a managed object
	newResource = function(self, args, o)
		
		o = o or {}
		
		local newMT = {} --set mixed metatable of REResource and outer File class:
		for key, value in pairs(self) do newMT[key] = value end
		for key, value in pairs(getmetatable(o)) do newMT[key] = value end
		newMT.__index = newMT
		o = setmetatable(o, newMT)
		--"E:\\SteamLibrary\\steamapps\\common\\RESIDENT EVIL 2  BIOHAZARD RE2\\reframework\\data\\rsz\\rszre2.json"
		argsTbl = (type(args)=="table" and args) or {}
		o.filepath = argsTbl.filepath or (type(argsTbl[1])=="string" and argsTbl[1]) or (type(args)=="string" and args) or o.filepath
		o.mobject = argsTbl.mobject or (type(argsTbl[1])=="userdata" and argsTbl[1]) or (type(argsTbl[2])=="userdata" and argsTbl[2]) or (type(args)=="userdata" and args) or o.mobject
		o.bs = args.bs or BitStream:new(o.filepath, args.file) or o.bs
		o.offsets = {}
		
		o.ext = o.extensions and o.extensions[game_name] or ".?"
		if o.isRSZ then
			if not rsz_parser then 
				re.msg("Failed to locate reframework\\data\\plugins\\rsz_parser_REF" .. ".dll !\n")
				o.bs = BitStream:new()
			elseif not rsz_parser.IsInitialized() then 
				rsz_parser.ParseJson("reframework\\data\\rsz\\rsz" .. reframework.get_game_name() .. ".json")
				if not rsz_parser.IsInitialized() then 
					re.msg("Failed to locate reframework\\data\\rsz\\rsz" .. reframework.get_game_name() .. ".json !\nDownload this file from https://github.com/alphazolam/RE_RSZ")
					o.bs = BitStream:new()
				end
			end
		end
		
		return o
	end,
	
	seek = function(self, pos, relative, insertIfEOF)
		return self.bs:seek(pos, relative, insertIfEOF)
	end,
	
	skip = function(self, numBytes)
		return self.bs:skip(numBytes)
	end,
	
	tell = function(self)
		return self.bs:tell()
	end,
	
	fileSize = function(self)
		return self.bs:fileSize()
	end,
	
	-- Reads a struct and returns it as a dictionary:
	readStruct = function(self, structName, relativeOffset)
		local output = {startOf = self.bs:tell()}
		local struct = self.structs[structName]
		for i, fieldTbl in ipairs(struct or {}) do 
			local methodName = fieldTbl[1]
			local keyOrOffset = fieldTbl[2]
			if methodName == "skip" then 
				self.bs:skip(keyOrOffset)
			elseif methodName == "seek" then 
				self.bs:seek(output.startOf + keyOrOffset)
			elseif methodName == "align" then
				self.bs:align(keyOrOffset)
			else
				output[ keyOrOffset ] = self.bs[ "read" .. methodName ](self.bs)
				if fieldTbl.isOffset or fieldTbl[3] or keyOrOffset:find("Offse?t?") then
					local pos = self.bs:tell()
					table.insert(self.offsets, {ownerTbl=output, name=keyOrOffset, readAddress=self.bs:tell()-8, offsetTo=output[keyOrOffset], relativeStart=relativeOffset})
					if fieldTbl[3] then --read strings from string offsets:
						output[ fieldTbl[3][2] ] = self.bs[ "read" .. fieldTbl[3][1] ](self.bs, output[keyOrOffset])-- + (relativeOffset or 0))
						self.offsets[#self.offsets].dataType = fieldTbl[3][1]
						self.offsets[#self.offsets].dataName = fieldTbl[3][2]
						--self.offsets[#self.offsets].dataValue = output[ fieldTbl[3][2] ] 
					end
					self.bs:seek(pos)
				end
			end
		end
		output.sizeOf = self.bs:tell() - output.startOf
		return output
	end,
	
	-- Writes a struct (in the order of the struct) using data from a Lua dictionary:
	writeStruct = function(self, structName, tableToWrite, startOf, bs, relativeOffset, structs, doInsert)
		
		bs = bs or self.bs
		local methodType = (doInsert and "insert") or "write"
		structs = structs or self.structs
		local struct = structs[structName]
		local begin = bs:tell()
		
		if startOf then
			bs:seek(startOf)
		end
		
		tableToWrite.startOf = bs:tell()
		for i, fieldTbl in ipairs(struct or {}) do 
			local methodName = fieldTbl[1]
			local keyOrOffset = fieldTbl[2]
			if methodName == "skip" then 
				if doInsert then
					bs:insertBytes(keyOrOffset)
				else
					bs:skip(keyOrOffset, true)  
				end
			elseif methodName == "seek" then 
				if doInsert then
					bs:insertBytes((tableToWrite.startOf + keyOrOffset) - bs.pos)
				else
					bs:seek(tableToWrite.startOf + keyOrOffset, true)
				end
			elseif methodName == "align" then
				if doInsert then
					bs:insertBytes(bs:getAlignedOffset(keyOrOffset) - self.pos)
				else
					bs:align(keyOrOffset)
				end
			else
				--last = {struct, keyOrOffset, methodType, methodName, tableToWrite[keyOrOffset], structName, tableToWrite, startOf, bs, relativeOffset, doInsert}
				local valueToWrite = tableToWrite[keyOrOffset] or 0
				if fieldTbl[3] and type(tableToWrite[ fieldTbl[3][2] ])=="string" then
					self.stringsToWrite = self.stringsToWrite or {}
					table.insert(self.stringsToWrite, {offset=bs:tell(), string=tableToWrite[ fieldTbl[3][2] ]})
				end
				bs[ methodType .. methodName ](bs, valueToWrite)
			end
		end
		tableToWrite.sizeOf = bs:tell() - tableToWrite.startOf
		if startOf then 
			self:seek(begin)
		end
		return bs
	end,
	
	-- Inserts a new struct at the given position. If no startOffset is given, it inserts at the end (startOf + sizeOf) of the given dictionary
	insertStruct = function(self, structName, tableToWrite, startOf, bs, relativeOffset, structs)
		local orgSize = self.bs:fileSize()
		startOf = startOf or (tableToWrite.startOf + tableToWrite.sizeOf)
		self:writeStruct(structName, tableToWrite, startOf, bs, relativeOffset, structs, true)
		self:scanFixStreamOffsets(startOf, startOf + tableToWrite.sizeOf, startOf, self.bs:fileSize(), tableToWrite.sizeOf, 8)
		return self.bs:tell(), (self.bs.size - orgSize)
	end,
	
	-- Scans bytes of the stream within a range from startAt to endAt, checking UInt64s or UInts for offsets > than the insertPoint and < maxOffset, and adding +addedSz if so
	scanFixStreamOffsets = function(self, startAt, endAt, insertPoint, maxOffset, addedSz, intSize)
		intSize = ((intSize==4) and 4) or 8
		maxOffset = maxOffset or (self.bs:fileSize() + addedSz)
		log.info("\nScanning bitstream from address " .. startAt .. " to " .. endAt .. ", checking for " .. intSize .. "-byte offsets >= " .. insertPoint .. " and < " ..maxOffset .. " in which to add size +" .. addedSz)
		if startAt > endAt then return log.info("Cannot fix offsets: start of range is after end of range")	end
		local offset
		local bs = self.bs
		local returnToAddress = bs:tell()
		bs:seek(startAt)
		while bs:tell() + intSize <= endAt do
			if bs.pos + intSize > bs.size then break end
			if intSize == 4 then 
				offset = bs:readUInt()
			else
				offset = bs:readUInt64()
			end
			if offset >= insertPoint and offset <= maxOffset then
				log.info("@ position " .. (bs.pos - intSize) .. ": " .. offset .. " " .. " >= " .. insertPoint .. "(limit " .. maxOffset .. "), added +" .. addedSz .. ", new offset: " .. (offset + addedSz))
				if intSize == 4 then
					bs:writeUInt(offset + addedSz, bs.pos - 4)
				else
					bs:writeUInt64(offset + addedSz, bs.pos - 8)
				end
			end
		end
		bs:seek(returnToAddress)
	end,
	
	-- Scans "self.offsets" (table of known offsets) for entries with a readAddress ranging from startAt to endAt, checking for offsetTo's > than the insertPoint and < maxOffset, and adding +addedSz if so
	fixOffsets = function(self, startAt, endAt, insertPoint, maxOffset, addedSz)
		maxOffset = maxOffset or (self.bs:fileSize() + addedSz)
		log.info("\nUpdating known offsets in bitstream from address " .. startAt .. " to " .. endAt .. ", checking for offsets >= " .. insertPoint .. " and < " ..maxOffset .. " in which to add size +" .. addedSz)
		if startAt > endAt then return log.info("Cannot fix offsets: start of range is after end of range") end
		for i, offsetTbl in ipairs(self.offsets) do 
			local relStart = (offsetTbl.relativeStart or 0)
			local offset = offsetTbl.offsetTo-- + relStart
			local readAddress = offsetTbl.readAddress
			if (readAddress >= startAt) and (readAddress < endAt) and (offset >= insertPoint) and (offset <= maxOffset) then 
				log.info("@ position " .. readAddress .. ": " .. offset .. " " .. " >= " .. insertPoint .. " (limit " .. maxOffset .. "), added +" .. addedSz .. ", new offset: " .. (offset + addedSz))
				offset = offset + addedSz
				self.bs:writeUInt64(offset, readAddress)
			end
			relStart = (relStart > insertPoint) and (relStart + addedSz) or relStart
			offsetTbl.readAddress = (offsetTbl.readAddress > insertPoint and offsetTbl.readAddress + addedSz) or offsetTbl.readAddress
			offsetTbl.offsetTo = offset-- - relStart
			offsetTbl.relativeStart = offsetTbl.relativeStart and relStart
		end
	end,
	
	displayInstance = function(self, instance, displayName, parentField, parentFieldListIdx, rszBufferFile)
		
		local id = imgui.get_id(parentFieldListIdx or "") .. displayName
		if imgui.tree_node_str_id(id, displayName) then 
			--[[if imgui.tree_node("[Lua]") then
				EMV.read_imgui_element(instance)
				imgui.tree_pop()
			end]]
			
			if parentField then
				if parentFieldListIdx then --lists
					imgui.push_id(id .. "f")
						changed, parentField.objectIndex[parentFieldListIdx] = imgui.combo("ObjectIndex", parentField.objectIndex[parentFieldListIdx], self.instanceNames)
						if (parentField.isNative and EMV.editable_table_field(parentFieldListIdx, parentField.objectIndex[parentFieldListIdx], parentField.objectIndex, "ObjectIndex?")==1) or changed then
							parentField.value[parentFieldListIdx] = rszBufferFile.rawData[ parentField.objectIndex[parentFieldListIdx] ].sortedTbl
							parentField.rawField.value[parentFieldListIdx] = parentField.objectIndex[parentFieldListIdx]
						end
					imgui.pop_id()
				else --singles
					changed, parentField.objectIndex = imgui.combo("ObjectIndex", parentField.objectIndex, self.instanceNames)
					if (EMV.editable_table_field("objectIndex", parentField.objectIndex, parentField, "ObjectIndex")==1) or changed then --parentField.isNative and 
						parentField.value = rszBufferFile.rawData[parentField.objectIndex].sortedTbl
						parentField.rawField.value = parentField.objectIndex
					end
				end
				imgui.spacing()
			end
			
			imgui.begin_rect()
				if instance.fields and instance.fields[1] then
					for f, field in ipairs(instance.fields) do 
						imgui.push_id(field.name .. f)
							if field.count then 
								if imgui.tree_node("List (" .. field.fieldTypeName .. ") " .. field.name) then
									-- Add/Remove List operations:
									imgui.text("Count: " .. field.count)
									local toInsert, toRemove
									if not field.value[1] and imgui.button("+") then 
										toInsert = 1
									end
									local rawF = field.rawField
									
									for e, element in ipairs(field.value) do
										imgui.push_id(f .. e)
											if imgui.button("+") then 
												toInsert = e
											end
											imgui.same_line()
											if imgui.button("-") then 
												toRemove = e
											end
										imgui.pop_id()
										imgui.same_line()
										if type(element)=="table" and field.objectIndex then
											--local dispName = element.name--(e .. ". " .. field.fieldTypeName .. " " .. field.name)
											self:displayInstance(element, element.name, field, e, rszBufferFile)
										elseif EMV.editable_table_field(e, element, field.value, e .. ". " .. field.fieldTypeName .. " " .. field.name)==1 then
											if rawF then rawF.value[e] = field.value[e] end
										end
									end
									if toInsert or toRemove then
										if toInsert then 
											local newItem = rawF.value[toInsert]
											if rawF.value[toInsert]==nil then 
												newItem = rszBufferFile:makeFieldTable(rawF.typeId, rawF.index, true, true).value
											elseif type(newItem)=="table" then
												newItem = EMV.deep_copy(newItem)
											end
											if field.objectIndex then 
												newItem = (newItem~=0 and newItem) or instance.rawDataTbl.index-1
												table.insert(rawF.value, toInsert, newItem)
												table.insert(field.value, toInsert, rszBufferFile.rawData[newItem].sortedTbl )
												field.objectIndex = EMV.deep_copy(rawF.value)
											else
												table.insert(rawF.value, toInsert, newItem)
											end
										end
										if toRemove then 
											if field.objectIndex then 
												table.remove(rawF.value, toRemove)
												table.remove(field.value, toRemove)
												field.objectIndex = EMV.deep_copy(rawF.value)
											else
												table.remove(rawF.value, toRemove)
											end
										end
										if rawF then rawF.value = field.objectIndex or field.value end
										field.count = #rawF.value
									end
									imgui.tree_pop()
								end
							elseif field.objectIndex then
								self:displayInstance(field.value, field.fieldTypeName .. " " .. field.name, field, nil, rszBufferFile)
							elseif rawF and rawF.is4ByteArray and #field.value <= 4 and (rawF.LuaTypeName=="Float" or rawF.LuaTypeName=="Int") then
								field.vecType = field.vecType or "Vector" .. #field.value .. "f"
								field.vecValue = field.vecValue or _G[field.vecType].new(table.unpack(field.value))
								changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, (field.LuaTypeName=="Int"), 0.01)
								if changed then 
									field.value = {field.vecValue.x, field.vecValue.y, field.vecValue.z, field.vecValue.w}
									rawF.value = field.value
								end
							elseif rawF and (rawF.fieldTypeName=="Vec4" or rawF.fieldTypeName=="Data16") then
								changed, field.value = EMV.show_imgui_vec4(field.value, field.name, false, 0.01)
							elseif rawF and rawF.fieldTypeName=="Vec3" then
								field.vecValue = field.vecValue or field.value:to_vec3()
								changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, false, 0.01)
								if changed then field.value = field.vecValue:to_vec4() end
							elseif rawF and rawF.fieldTypeName=="Vec2" then
								field.vecValue = field.vecValue or field.value:to_vec2()
								changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, false, 0.01)
								if changed then field.value = field.vecValue:to_vec4() end
							elseif EMV.editable_table_field("value", field.value, field, field.fieldTypeName .. " " .. field.name)==1 then
								if rawF then rawF.value = field.value end
							end
						imgui.pop_id()
					end
				elseif instance.userdataFile then
					if instance.userdataFile.displayImgui then
						instance.userdataFile:displayImgui()
					else
						imgui.text(instance.userdataFile)
					end
				end
			imgui.end_rect(2)
			imgui.spacing()
			imgui.tree_pop()
		end
	end,
			
	showAddInstanceMenu = function(self, rszBufferFile, parentTable, gameObjectInfo)
		
		local newlyCreated
		local instanceHolder = parentTable or self
		if not instanceHolder.newInstance and imgui.button("Add " .. (gameObjectInfo and "Component" or "Instance")) then 
			instanceHolder.newInstance = false
			newlyCreated = true
		end
		
		if instanceHolder.newInstance ~= nil then

			if not RSZFile.json_dump_components then
				rszBufferFile:loadJson()
			end
			
			local names_list = (gameObjectInfo and RSZFile.json_dump_components) or RSZFile.json_dump_names
			
			local label = "New " .. (gameObjectInfo and "Component" or "Instance") .. " Type"
			changed, self.newInstanceIdx = imgui.combo(label, self.newInstanceIdx or 1, names_list)
			self.newTypeName = names_list[self.newInstanceIdx]

			
			self.newInstanceIdx = self.newInstanceIdx or 1
			self.newTypeName = self.newTypeName or names_list[self.newInstanceIdx] or ""
			
			if EMV.editable_table_field("newTypeName", self.newTypeName, self, label)==1 then
				self.newInstanceIdx = (sdk.find_type_definition(self.newTypeName) and EMV.find_index(names_list, self.newTypeName)) or self.newInstanceIdx
			end
			
			if changed or not instanceHolder.newInstance then
				instanceHolder.newInstanceIsRSZObject = nil
				instanceHolder.newInstance = rszBufferFile:createInstance(self.newTypeName)
				newlyCreated = true
			end
			
			if not self.newInstanceInsertIdxList then 
				self.newInstanceInsertIdxList = {}
				for i=1, #rszBufferFile.rawData+1 do 
					self.newInstanceInsertIdxList[i] = tostring(i) 
				end
			end
			
			if parentTable then
				self.newInstanceInsertIdx = self.newInstanceInsertIdx or parentTable[#parentTable].rawDataTbl.index+1
				if self.newInstanceInsertIdx > parentTable[#parentTable].rawDataTbl.index+1 then self.newInstanceInsertIdx = parentTable[#parentTable].rawDataTbl.index+1 end
				if self.newInstanceInsertIdx < parentTable[1].rawDataTbl.index then self.newInstanceInsertIdx = parentTable[1].rawDataTbl.index end
				instanceHolder.newInstance.name = self.newTypeName .. "[" .. self.newInstanceInsertIdx .. "]"
			end
			
			changed, self.newInstanceInsertIdx = imgui.combo("Insertion Point", self.newInstanceInsertIdx or #self.newInstanceInsertIdxList, self.newInstanceInsertIdxList)
			
			changed, instanceHolder.newInstanceIsRSZObject = imgui.checkbox("Add To ObjectTable", instanceHolder.newInstanceIsRSZObject 
				or (isRSZObject or not not (gameObjectInfo or sdk.find_type_definition(instanceHolder.newInstance.name):is_a("via.Component"))))
			isRSZObject = instanceHolder.newInstanceIsRSZObject
			
			--instanceHolder.jsonCount = instanceHolder.jsonCount or {#names_list}
			--imgui.text(instanceHolder.jsonCount[1] .. " " .. instanceHolder.jsonCount[2])
			
			if self.newInstanceIdx and imgui.button("OK") then 
				if not gameObjectInfo and self.gameObjectInfos and isRSZObject then 
					for g, gInfo in ipairs(self.gameObjectInfos) do 
						for c, component in ipairs(gInfo.gameObject.components) do
							if gInfo.gameObject.gameobj.rawDataTbl.index  >= self.newInstanceInsertIdx or component.rawDataTbl.index >=  self.newInstanceInsertIdx  then
								gameObjectInfo = gInfo
								re.msg("Added Component to GameObject: " .. gInfo.name)
								goto exit
							end
						end
					end
					::exit::
				end
				
				if gameObjectInfo then
					gameObjectInfo.componentCount = gameObjectInfo.componentCount + 1
				end
				instanceHolder.newInstanceIsRSZObject = nil
				
				local objectTblInsertPt = rszBufferFile:addInstance(self.newTypeName, self.newInstanceInsertIdx, instanceHolder.newInstance, isRSZObject)
				
				if self.gameObjectInfos and objectTblInsertPt and isRSZObject then
					for g, gInfo in ipairs(self.gameObjectInfos or {}) do 
						if gInfo.objectId >= objectTblInsertPt-1 then gInfo.objectId = gInfo.objectId+1 end
						if gInfo.parentId >= objectTblInsertPt-1 then gInfo.parentId = gInfo.parentId+1 end
					end
					for f, fInfo in ipairs(self.folderInfos or {}) do 
						if fInfo.objectId >= objectTblInsertPt-1 then fInfo.objectId = fInfo.objectId+1 end
						if fInfo.parentId >= objectTblInsertPt-1 then fInfo.parentId = fInfo.parentId+1 end
					end
					for f, uInfo in ipairs(self.userdataInfos or {}) do 
						--last = {uInfo, objectTblInsertPt}
						if uInfo.id >= objectTblInsertPt-1 then uInfo.id = uInfo.id+1 end
					end
					for f, pInfo in ipairs(self.prefabInfos or {}) do 
						if pInfo.parentId >= objectTblInsertPt-1 then pInfo.parentId = pInfo.parentId+1 end
					end
				end
				--test = self
				self:save(nil, true) --save all data to the buffer
				self:read() --refresh Lua tables from the buffer
				self.instanceNames = nil
				self.newInstanceInsertIdxList = nil
				self.showBigComboBox = nil
				instanceHolder.newInstance = nil
			end
			
			if (newlyCreated or (not imgui.same_line() and imgui.button("Cancel"))) then
				if not newlyCreated then 
					instanceHolder.newInstance = nil
				end
			end
			
			imgui.same_line()
			if imgui.button("Reload JSON") then 
				rszBufferFile:loadJson(nil, true)
			end
			
			if instanceHolder.newInstance then
				self:displayInstance(instanceHolder.newInstance, instanceHolder.newInstance.index .. ". " .. instanceHolder.newInstance.name, nil, nil, rszBufferFile)
			end
		end
	end,
	
	displayGameObject = function(self, gameObject, displayName, rszBufferFile)
	
		if imgui.tree_node(displayName) then 
			
			local gameObjectInfo = gameObject.gInfo or gameObject.fInfo --GameObject or Folder
			
			-- set Gameobject parent:
			if not gameObject.parents_list or not gameObject.imguiParentIdx or self.gameobjTableResetAction then 
				gameObject.parents_list = {}
				local function setupParent(infosList)
					for i, gInfo in ipairs(infosList) do 
						
						local listName = (gInfo==gameObjectInfo and " ") or (gInfo.name ) or "" --.. "[" .. (gInfo.gameObject or gInfo.folder).idx .. "]"
						local parentGInfo, isParentOfThis = self.gameObjectInfosIdMap[gInfo.objectId], false
						
						while self.gameObjectInfosIdMap[parentGInfo.parentId] and parentGInfo.parentId~=parentGInfo.objectId do 
							if parentGInfo.parentId == gameObjectInfo.objectId then
								listName = listName .. " (CHILD)"; break
							end
							parentGInfo = self.gameObjectInfosIdMap[parentGInfo.parentId]
						end
						
						table.insert(gameObject.parents_list, listName)
						if (gInfo.objectId == gameObjectInfo.parentId) or (gInfo==gameObjectInfo and not gameObject.parent) then  --gInfo.parentId == -1
							gameObject.imguiParentIdx = i
						--else
						--	log.info(gameObject.name .. " no find parent " .. i .. ", objectId: " .. gameObjectInfo.objectId .. ", parentId: " .. gameObjectInfo.parentId .. ", gInfoObjectId: " .. gInfo.objectId .. ", gInfoParentId: " .. gInfo.parentId .. " " ..
						--	gInfo.name)
						end
					end
				end
				setupParent(self.folderInfos or {})
				setupParent(self.gameObjectInfos)
			end
			
			-- change parent:
			changed, gameObject.imguiParentIdx = imgui.combo("Select Parent", gameObject.imguiParentIdx or 0, gameObject.parents_list)
			
			if changed then 
				
				local merged_tables = (self.folderInfos and EMV.merge_indexed_tables(self.folderInfos, self.gameObjectInfos, true)) or self.gameObjectInfos
				local objsTbl = (gameObject.fInfo and self.folders) or self.gameObjects
				local parentInfo = merged_tables[gameObject.imguiParentIdx]
				local obj = parentInfo and (parentInfo.gameObject or parentInfo.folder)
				
				local parentChildListIdx = gameObject.parent and EMV.find_index(gameObject.parent.children, gameObject)
				if parentChildListIdx then 
					self.gameobjTableRemoveAction = {"remove", gameObject.parent.children, parentChildListIdx}
				end
				
				if not merged_tables[gameObject.imguiParentIdx] or merged_tables[gameObject.imguiParentIdx]==gameObjectInfo or obj==gameObject then
					gameObjectInfo.parentId = -1
					self.gameobjTableAddAction = {"insert", objsTbl, #objsTbl+1, gameObject}
					gameObject.parent = nil
				else
					if not gameObject.parents_list[gameObject.imguiParentIdx]:find("CHILD") then
						if not parentChildListIdx then
							self.gameobjTableRemoveAction = {"remove", objsTbl, EMV.find_index(objsTbl, gameObject)}
						end
						local insertIdx = #obj.children+1
						for g, gobj in ipairs(obj.children) do
							if gobj.idx > gameObject.idx then insertIdx = g; break end
						end
						self.gameobjTableAddAction = {"insert", obj.children, insertIdx, gameObject}
						gameObjectInfo.parentId = parentInfo.objectId
						gameObject.parent = obj
					end
				end
				gameObject.imguiParentIdx = nil --reset list
			end
			
			imgui.same_line()
			if imgui.tree_node("[Lua]") then
				EMV.read_imgui_element(gameObject)
				imgui.tree_pop()
			end
			imgui.spacing()
			
			if gameObject.gameobj then --GameObjects
				
				imgui.begin_rect()
					imgui.text("	")
					imgui.same_line()
					imgui.begin_rect()
						self:showAddInstanceMenu(rszBufferFile, gameObject.components, gameObjectInfo)
					imgui.end_rect(2)
					
					self:displayInstance(gameObject.gameobj, "via.GameObject[" .. gameObject.gameobj.rawDataTbl.index .. "]", nil, nil, rszBufferFile)
					for i, sortedInstance in ipairs(gameObject.components) do
						self:displayInstance(sortedInstance, i .. ". " .. sortedInstance.name)
					end

					if gameObject.children and gameObject.children[1] and imgui.tree_node("Children") then
						for c, childObject in ipairs(gameObject.children) do
							self:displayGameObject(childObject, c .. ". " .. childObject.name, rszBufferFile)
						end
						imgui.tree_pop()
					end
				imgui.end_rect(2)
				
			elseif gameObject.fInfo and ((gameObject.folders and gameObject.folders[1]) or (gameObject.gameObjects and gameObject.gameObjects[1])) then --Folders
				imgui.text("	")
				imgui.same_line()
				imgui.begin_rect()
					self:displayInstance(gameObject.instance, gameObject.instance.name, nil, nil, rszBufferFile) --"via.Folder[" .. gameObject.instance.rawDataTbl.index .. "]"
					if gameObject.children and gameObject.children[1] and imgui.tree_node("Children") then
						for c, childFolder in ipairs(gameObject.children) do
							self:displayGameObject(childFolder, c .. ". " .. childFolder.name, rszBufferFile)
						end
						imgui.tree_pop()
					end
				imgui.end_rect(2)
			end
			imgui.tree_pop()
		end
	end,
	
	-- Displays a REResource in imgui with editable fields, showing only the important structs of the file. Contains special functions for RSZ data
	displayImgui = function(self)
		
		local display_struct
		local font_succeeded = pcall(imgui.push_font, utf16_font)
		
		if self.filepath then
			if imgui.button("Save File") then--imgui.button(((self.isMDF and "Inject") or "Save") .. " File") then
				self:save()
			end
			
			imgui.same_line()
			if EMV.editable_table_field("filepath", self.filepath, self, "FilePath")==1 and self.filepath:find("%$natives\\") and not self.filepath:find(nativesFolderType) then
				self.filepath = self.filepath:gsub("%$natives\\", "$natives\\" .. nativesFolderType .. "\\")
			end
			imgui.tooltip("Access files in the 'REFramework\\data\\' folder.\nStart with '$natives\\' to access files in the natives folder", "fpath")
			
			if imgui.button("Refresh") then
				self:save(nil, true)
				self:read()
			end
			
			if self.saveAsPFB and not imgui.same_line() and imgui.button("Save as PFB") then
				local path = self.filepath:match("^(.+)%.") .. ".pfb" .. PFBFile.extensions[game_name]
				self:saveAsPFB(path:gsub("%.scn", ""))
			end
			
			if self.saveAsSCN and not imgui.same_line() and imgui.button("Save as SCN") then
				local path = self.filepath:match("^(.+)%.") .. ".scn" .. SCNFile.extensions[game_name]
				self:saveAsSCN(path:gsub("%.pfb", ""))
			end
			
			imgui.same_line()
			if imgui.tree_node_str_id(self.filepath, "[Lua]") then 
				EMV.read_imgui_element(self)
				imgui.tree_pop()
			end
		end
		
		local function display_struct(s, struct, structPrototype, structName, doExpand)
			
			local doExpand = doExpand or (#structPrototype == 1)
			if doExpand or imgui.tree_node(s .. ". " .. (struct.name or "")) then
				imgui.begin_rect()
				imgui.push_id(s .. "Struct")
				for f, fieldTbl in ipairs(structPrototype) do
					local key = (fieldTbl[3] and fieldTbl[3][2]) or fieldTbl[2]
					--imgui.text(structName .. ", " .. key .. ", " .. tostring(struct[key]))
					if type(key)=="string" and not key:find("Offset$") then
						EMV.editable_table_field(key, struct[key], struct, ((doExpand and s .. ". ") or "") .. key)
					end
				end
				if self.customStructDisplayFunction then 
					self:customStructDisplayFunction(struct, s)
				end
				imgui.pop_id()
				imgui.end_rect(2)
				if not doExpand then imgui.tree_pop() end
			end
		end
		
		local function displayStructList(structList, structPrototype, structName)
			
			local toRemoveIdx, toAddIdx
			for s, struct in ipairs(structList or {}) do
				imgui.push_id(s.."Del")
					if imgui.button("-") then 
						toRemoveIdx = s
					end
					imgui.same_line()
					if imgui.button("+") then 
						toAddIdx = s
					end
				imgui.pop_id()
				imgui.same_line()
				--[[if not struct.name then 
					if imgui.tree_node("Struct " .. s) then 
						for ss, substruct in ipairs(struct) do 
							display_struct(ss, substruct, structPrototype, structName)
						end
						imgui.tree_pop()
					end
				else]]
					display_struct(s, struct, structPrototype, structName)
				--end
			end
			
			if toRemoveIdx then 
				table.remove(structList, toRemoveIdx)
			end
			
			if toAddIdx or (#structList==0 and imgui.button("Add " .. structName)) then
				local newStruct = structList[ #structList ] and EMV.merge_tables({}, (structList[ #structList ]))
				if not newStruct then 
					newStruct = {}
					for i, tbl in ipairs(structPrototype) do
						newStruct[ tbl[2] ] = (tbl[1]:find("tring") and "") or 0 
						if tbl[3] then newStruct[ tbl[3][2] ] = "" end
					end
				end
				if toAddIdx then
					table.insert(structList, toAddIdx, newStruct)
				else
					table.insert(structList, newStruct)
				end
			end
		end	
		
		for i, structName in ipairs(self.structs.structOrder) do 
			local structPrototype = self.structs[structName]
			local pluralName = (self[structName] and structName) or structName.."s"
			if pluralName and imgui.tree_node(pluralName) then
				
				if pluralName==structName and structName ~= "objectTable" then
					display_struct(pluralName, self[pluralName], structPrototype, structName, true)
				else
					local thisInfos, isList = self[pluralName], nil
					displayStructList(thisInfos, structPrototype, structName)
				end
				imgui.tree_pop()
			end
		end
		
		local RSZ = self.RSZ or (self.isRSZ and self)
		
		if RSZ then
			
			if not self.instanceNames then 
				self.instanceNames = {}
				for i, dataTbl in ipairs(RSZ.rawData) do 
					self.instanceNames[i] = dataTbl.name
				end
			end
			
			--RawData:
			if self.RSZ and imgui.tree_node("RSZ") then
				self.RSZ:displayImgui()
				imgui.tree_pop()
			end
			
			if self.rawData and imgui.tree_node("RawData") then
				imgui.text("	")
				imgui.same_line()
				imgui.begin_rect()
					self:showAddInstanceMenu(RSZ)
				imgui.end_rect(2)
				if imgui.tree_node("[Unformatted]") then
					for i, instance in ipairs(RSZ.rawData) do
						self:displayInstance(instance, i .. ". " .. instance.name, nil, nil, RSZ)
					end
					imgui.tree_pop()
				end
				for i, instance in ipairs(RSZ.rawData) do
					--[[if imgui.button("X") then 
						--delete the instance
					end
					imgui.same_line()]]
					self:displayInstance(instance.sortedTbl, i .. ". " .. instance.name, nil, nil, RSZ)
				end
				imgui.tree_pop() 
			end
			
			--Organized Data:
			imgui.spacing()
			if self.gameObjects then 
				
				if self.gameObjects[1] and imgui.tree_node("GameObjects") then
					for i, gameObject in ipairs(self.gameObjects) do
						self:displayGameObject(gameObject, i .. ". " .. gameObject.name, RSZ)
					end
					imgui.text()
					imgui.tree_pop()
				end
				
				if self.folders and self.folders[1] and imgui.tree_node("Folders") then
					
					for i, folder in ipairs(self.folders) do
						self:displayGameObject(folder, i .. ". " .. (folder.name or ""), RSZ)
					end
					imgui.text()
					imgui.tree_pop()
				end
				
				self.gameobjTableResetAction = nil
				if self.gameobjTableAddAction then 
					table[self.gameobjTableAddAction[1]](self.gameobjTableAddAction[2], self.gameobjTableAddAction[3], self.gameobjTableAddAction[4])
					self.gameobjTableAddAction = nil
				end
				if self.gameobjTableRemoveAction then 
					table[self.gameobjTableRemoveAction[1]](self.gameobjTableRemoveAction[2],self.gameobjTableRemoveAction[3])
					self.gameobjTableRemoveAction = nil
					self.gameobjTableResetAction = true
				end
				
			elseif self.objects then 
				if imgui.tree_node("Objects") then
					for i, object in ipairs(self.objects) do
						self:displayInstance(object, object.name, nil, nil, RSZ)
					end
				imgui.tree_pop()
				end
			end
		end
		
		if font_succeeded then
			imgui.pop_font()
		end
		
	end,
}

-- Class for managing embedded files with "RSZ" magic:
RSZFile = {
	
	--[[typeIds = {
		ukn_error = {"", 1},
		ukn_type = {"", 1},
		not_init = {"", 1},
		class_not_found = {"", 1},
		out_of_range = {"", 1},
		Undefined_tid = {"", 1},
		Object_tid = {"", 1},
		Action_tid = {"", 1},
		Struct_tid = {"", 1},
		NativeObject_tid = {"", 1},
		Resource_tid = {"", 1},
		UserData_tid = {"", 1},
		Bool_tid = {"UByte", 1},
		C8_tid = {"", 1},
		C16_tid = {"", 1},
		S8_tid = {"Byte", 1},
		U8_tid = {"UByte", 1},
		S16_tid = {"Short", 1},
		U16_tid = {"UShort", 1},
		S32_tid = {"Int", 1},
		U32_tid = {"UInt", 1},
		S64_tid = {"Int64", 1},
		U64_tid = {"UInt64", 1},
		F32_tid = {"Float", 1},
		F64_tid = {"Double", 1},
		String_tid = {"String", 1},
		MBString_tid = {"", 1},
		Enum_tid = {"UInt", 1},
		Uint2_tid = {"UInt", 2},
		Uint3_tid = {"UInt", 3},
		Uint4_tid = {"Uint", 4},
		Int2_tid = {"Int", 2},
		Int3_tid = {"Int", 3},
		Int4_tid = {"Int", 4},
		Float2_tid = {"Float", 2},
		Float3_tid = {"Float", 3},
		Float4_tid = {"Float", 4},
		Float3x3_tid = {"Float", 9},
		Float3x4_tid = {"Float", 12},
		Float4x3_tid = {"Float", 12},
		Float4x4_tid = {"Float", 16},
		Half2_tid = {"", 1},
		Half4_tid = {"", 1},
		Mat3_tid = {"Float", 12},
		Mat4_tid = {"Mat4", 1},
		Vec2_tid = {"Vec2", 1},
		Vec3_tid = {"Vec3", 1},
		Vec4_tid = {"Vec4", 1},
		VecU4_tid = {"", 1},
		Quaternion_tid = {"Vec4", 1},
		Guid_tid = {"", 1},
		Color_tid = {"UInt", 1},
		DateTime_tid = {"", 1},
		AABB_tid = {"", 1},
		Capsule_tid = {"", 1},
		TaperedCapsule_tid = {"", 1},
		Cone_tid = {"", 1},
		Line_tid = {"", 1},
		LineSegment_tid = {"", 1},
		OBB_tid = {"", 1},
		Plane_tid = {"", 1},
		PlaneXZ_tid = {"", 1},
		Point_tid = {"", 1},
		Range_tid = {"", 1},
		RangeI_tid = {"", 1},
		Ray_tid = {"", 1},
		RayY_tid = {"", 1},
		Segment_tid = {"", 1},
		Size_tid = {"UInt", 1},
		Sphere_tid = {"", 1},
		Triangle_tid = {"", 1},
		Cylinder_tid = {"", 1},
		Ellipsoid_tid = {"", 1},
		Area_tid = {"", 1},
		Torus_tid = {"", 1},
		Rect_tid = {"", 1},
		Rect3D_tid = {"", 1},
		Frustum_tid = {"", 1},
		KeyFrame_tid = {"", 1},
		Uri_tid = {"", 1},
		GameObjectRef_tid = {"", 1},
		RuntimeType_tid = {"String", 1},
		Sfix_tid = {"", 1},
		Sfix2_tid = {"", 1},
		Sfix3_tid = {"", 1},
		Sfix4_tid = {"", 1},
		Position_tid = {"", 1},
		F16_tid = {"", 1},
		End_tid = {"", 1},
		Data_tid
	} ]]

	typeNames = {
		Object = "UInt",
		UserData = "UInt",
		U32 = "UInt",
		S32 = "Int",
		U64 = "UInt64",
		S64 = "Int64",
		Bool = "UByte",
		String = "WString",
		Resource = "WString",
		F32 = "Float",
		F64 = "Double",
		Vec2 = "Vec4",
		Vec3 = "Vec4",
		Vec4 = "Vec4",
		OBB = "OBB",
		Guid = "GUID",
	},
	
	sizesToTypeNames = {
		[1] = "UByte",
		[2] = "Short",
		[4] = "Int",
		[8] = "Int64",
		[12] = "Vec4",
		[16] = "Vec4",
	},
	
	isRSZ = true,

	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newResource(args, setmetatable(o, self))
		o.startOf = args.startOf
		o.bs.alignShift = o.bs:getAlignedOffset(16, o.startOf) - o.startOf
		
		if o.bs:fileSize() > 0 then
			o:readBuffer()
		end
		
		o.save = o.writeBuffer
		o.read = o.readBuffer
		
		o:seek(0)
		return o
	end,
	
	-- Recreates the RSZ file buffer using data from owned Lua tables
	writeBuffer = function(self)
		local bs = BitStream:new()
		self.bs = bs
		
		bs:writeBytes(48)
		for i, objectTblObj in ipairs(self.objectTable) do
			bs:writeInt(objectTblObj.objectId)
		end 
		
		self.header.instanceOffset = self:tell()
		self:writeStruct("instanceInfo", self.instanceInfos[0])
		for i, instanceInfo in ipairs(self.instanceInfos) do
			self:writeStruct("instanceInfo", instanceInfo)
		end 
		
		bs:align(16)
		self.header.userdataOffset = self:tell()
		for i, RSZUserDataInfo in ipairs(self.RSZUserDataInfos) do
			self:writeStruct("RSZUserDataInfo", RSZUserDataInfo)
		end
		
		bs:align(16)
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			bs:writeUInt64(self:tell(), wstringTbl.offset)
			bs:writeWString(wstringTbl.string)
		end
		self.stringsToWrite = nil
		
		--embedded userdata
		if tdb_ver <= 67 then 
			for i, RSZUserDataInfo in ipairs(self.RSZUserDataInfos) do
				bs:align(16)
				RSZUserDataInfo.RSZOffset = bs:tell()
				RSZUserDataInfo.RSZData.startOfs = bs:tell() + (self.startOfs or 0)
				RSZUserDataInfo.RSZData:writeBuffer()
				bs:writeBytes(RSZUserDataInfo.RSZData.bs:getBuffer())
				bs:writeUInt64(RSZUserDataInfo.RSZOffset, RSZUserDataInfo.startOf+16)
			end
		end
		
		bs:align(16)
		self.header.dataOffset = self:tell()
		for i, instance in ipairs(self.rawData) do
			if not instance.userdataFile then 
				for f, field in ipairs(instance.fields) do 
					self:writeRSZField(field)
				end
			end
		end 
		
		self.header.objectCount = #self.objectTable
		self.header.instanceCount = #self.instanceInfos+1
		self.header.userdataCount = #self.RSZUserDataInfos
		self:seek(0)
		self:writeStruct("header", self.header)
		
		return bs
	end,
	
	-- Reads the data from the BitStream into owned Lua tables
	readBuffer = function(self, start, noRawData)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("header")
		
		self.objectTable = {}
		for i = 1, self.header.objectCount do
			self.objectTable[i] = self:readStruct("objectTable")
		end
		
		self:seek(self.header.instanceOffset)
		self.instanceInfos = {}
		for i = 0, self.header.instanceCount-1 do
			self.instanceInfos[i] = self:readStruct("instanceInfo")
			self.instanceInfos[i].name = rsz_parser.GetRSZClassName(self.instanceInfos[i].typeId)
		end
		
		self:seek(self.header.userdataOffset)
		self.RSZUserDataInfos = {}
		local usedRSZUserDataInstances = {}
		for i = 1, self.header.userdataCount do
			self.RSZUserDataInfos[i] = self:readStruct("RSZUserDataInfo")
			self.RSZUserDataInfos[i].name = rsz_parser.GetRSZClassName(self.RSZUserDataInfos[i].typeId)
			usedRSZUserDataInstances[self.RSZUserDataInfos[i].instanceId] = i --self.RSZUserDataInfos[i].name
		end
		
		--embedded userdatas:
		if self.header.userdataCount > 0 and tdb_ver <= 67 then
			for i, rszInfo in ipairs(self.RSZUserDataInfos) do
				--test = {self, rszInfo, self.bs:readString(rszInfo.RSZOffset)}
				self:seek(rszInfo.RSZOffset)
				local stream = self.bs:extractStream(rszInfo.dataSize)--rszInfo.RSZOffset, rszInfo.dataSize)
				rszInfo.RSZData = RSZFile:new({file=stream, startOf=rszInfo.RSZOffset + self.startOf})
			end
		end
		
		if not noRawData then
			self:seek(self.header.dataOffset)
			self.rawData = {}
			for i=1, self.header.instanceCount-1 do 
				local typeId = self.instanceInfos[i].typeId
				local instance = {
					name = rsz_parser.GetRSZClassName(typeId)  .. "[" .. i .. "]",
					typeId = typeId,
					fieldCount = rsz_parser.GetFieldCount(typeId),
					RSZUserDataIdx = usedRSZUserDataInstances[i],
					startOf = self:tell(),
					index = i,
				}
				if instance.RSZUserDataIdx then 
					instance.userdataFile = ((tdb_ver > 67) and self.RSZUserDataInfos[instance.RSZUserDataIdx].path) or self.RSZUserDataInfos[instance.RSZUserDataIdx].RSZData
				else
					instance.fields = {}
					for index=1, instance.fieldCount do 
						local field = self:readRSZField(typeId, index-1)
						if index == 1 then instance.startOf = field.startOf or instance.startOf end
						table.insert(instance.fields, field)
					end
					instance.sizeOf = self:tell() - instance.startOf
				end
				self.rawData[i] = instance
			end
			
			for i, rd in ipairs(self.rawData) do
				rd.sortedTbl = self:sortRSZInstance(rd)
			end
			
			self.objects = {}
			self.objectTable.names = {}
			for i, objectIndexTbl in ipairs(self.objectTable) do
				self.objects[i] = self.rawData[objectIndexTbl.objectId].sortedTbl
				self.objectTable.names[i] = self.objects[i].name
			end
			self.objectTable.names[#self.objectTable.names+1] = " "
		end
	end,
	
	sortRSZField = function(self, field, instance)
		
		local function sortField(field, sortedField, elementIdx)
			local value = sortedField.value
			local objectIndex = sortedField.objectIndex
			if elementIdx then 
				value = sortedField.value[elementIdx]
				if sortedField.objectIndex then
					objectIndex = sortedField.objectIndex[elementIdx]
				end
			end
			if field.fieldTypeName=="Bool" or (field.fieldTypeName=="Data1" and math.abs(value) <= 1) then
				value = number_to_bool[value]
				if field.fieldTypeName~="Bool" then
					field.LuaTypeName = "UByte"
					field.fieldTypeName = "Bool"
				end
			elseif objectIndex then --is "true" if not a list, is the objectIndex if a list
				if not elementIdx then objectIndex = value end
				value = (self.rawData[objectIndex] and self.rawData[objectIndex].sortedTbl) or {}
			end
			if elementIdx then 
				sortedField.value[elementIdx] = value
				if objectIndex then 
					sortedField.objectIndex[elementIdx] = objectIndex
				end
			else
				sortedField.value = value
				sortedField.objectIndex = objectIndex
			end
		end
		
		local sortedField = {value=(type(field.value)=="table" and EMV.deep_copy(field.value)) or field.value, name=field.name, fieldTypeName=field.fieldTypeName, count=field.count, rawField=field, isNative=field.isNative}
		local fieldValue = (type(field.value)=="table" and field.value[1]) or field.value
		
		sortedField.objectIndex = field.fieldTypeName=="Object" or (field.isNative and (field.LuaTypeName=="Int" and type(fieldValue)=="number") and (fieldValue < instance.index) and (fieldValue > instance.index - 101)) or nil
		if sortedField.objectIndex then sortedField.fieldTypeName = "Data4 (Object?)" end
		sortedField.objectIndex = sortedField.objectIndex or (self.rawData[sortedField.value]~=nil and (field.fieldTypeName=="Object") or (field.fieldTypeName=="UserData")) or nil
		
		if field.isList then 
			sortedField.objectIndex = sortedField.objectIndex and EMV.deep_copy(field.value)
			for e, element in ipairs(sortedField.value) do
				sortField(field, sortedField, e)
			end
		else
			sortField(field, sortedField)
		end
		
		if not instance.title and field.fieldTypeName=="String" and type(field.value)=="string" and field.value:len() > 1 then
			instance.title = field.value
		end
		
		return sortedField
	end,
	
	-- Creates an organized heirarchy of an RSZ class instance from RawData
	sortRSZInstance = function(self, instance)
		
		local sortedInstance = { userdataFile=instance.userdataFile, fields={}, rawDataTbl=instance }
		
		for i, field in ipairs(instance.fields or {}) do 
			sortedField = self:sortRSZField(field, instance)
			sortedInstance.fields[i] = setmetatable(sortedField, {name=field.name})
		end
		
		sortedInstance.name = instance.name
		if instance.title then 
			sortedInstance.name = sortedInstance.name .. " -- " .. instance.title
		end
		return setmetatable(sortedInstance, {name=instance.name})
	end,
	
	-- Writes a RSZ field with proper alignment from a Lua field table in rawData
	writeRSZField = function(self, field, bs)
		bs = bs or self.bs
		
		--field.elementSize = REResource.typeNamesToSizes[field.fieldTypeName] or field.elementSize
		
		local function writeFieldValue(value)
			local absStart = self.bs:getAlignedOffset(((field.isList and 4) or field.alignment), self:tell() + self.startOf)
			local pos = bs:tell()
			--log.info("Writing  " .. field.name .. " value " .. tostring(value) .. " at " .. pos .. " using " .. ("write" .. field.LuaTypeName) .. ", elemSize: " .. field.elementSize) 
			if field.is4ByteArray then
				bs:writeArray(value, field.LuaTypeName)
			elseif field.LuaTypeName == "WString" then 
				if value:len() <= 1 then
					bs:writeUInt(0)
				else
					--log.info("writing string " .. value .. " @ " .. self.startOf+bs:tell() .. " " .. value:len()+1)
					bs:writeUInt(value:len()+1)
					bs:writeWString(value)
				end
			else
				bs["write" .. field.LuaTypeName](bs, value)
			end
			
			if field.LuaTypeName ~= "WString" then
				self:seek(pos + field.elementSize)
			end
			
		end
		
		if field.isList then 
			bs:align(4)
			bs:writeUInt(#field.value) --count
			for i, value in ipairs(field.value) do 
				bs:align(field.alignment)
				writeFieldValue(value)
			end
		else
			bs:align(field.alignment)
			writeFieldValue(field.value)
		end
	end,
	
	-- Reads a RSZ field from the BitStream into a Lua table
	readRSZField = function(self, typeId, index, parentListField)
		
		if parentListField then 
			
			if parentListField.LuaTypeName == "WString" then 
				local charCount = self.bs:readUInt()
				local stringStart = self:tell()
				local value = ""
				if charCount > 0 then
					value = self.bs:readWString()
					self:seek(stringStart + charCount * 2)
				end
				
				return value
			else
				local startPos = self:tell()
				local output = self.bs["read" .. parentListField.LuaTypeName](self.bs)
				self:seek(startPos + parentListField.elementSize)
				return output
			end
		end
		
		local fieldTbl = self:makeFieldTable(typeId, index)
		
		fieldTbl.startOfAbs = self.bs:getAlignedOffset(((fieldTbl.isList and 4) or fieldTbl.alignment), self:tell() + self.startOf)
		self:skip(fieldTbl.startOfAbs  - self.startOf - self:tell())
		
		if fieldTbl.isList then 
			fieldTbl.count = self.bs:readUInt()
			fieldTbl.value = {}
			if fieldTbl.count > 0 then 
				local arraySkipAmt = self.bs:getAlignedOffset(fieldTbl.alignment, self:tell() + self.startOf) - self.startOf - self:tell()
				self:skip(arraySkipAmt)
				if fieldTbl.count <= 1024 then
					for i=1, fieldTbl.count do 
						fieldTbl.value[i] = self:readRSZField(typeId, index, fieldTbl)
					end
				end
			end
		else
			--last = {fieldTbl, typeId, index, parentListField}
			local startPos = self:tell()
			if fieldTbl.is4ByteArray then
				fieldTbl.value = self.bs:readArray(math.floor(fieldTbl.elementSize / 4), fieldTbl.LuaTypeName, self:tell(), true)
			elseif fieldTbl.LuaTypeName == "WString" then 
				self.charCount = self.bs:readUInt()
				local pos = self:tell()
				fieldTbl.value = ''
				if self.bs:readUByte(pos+1) ~= 0 then 
				--	log.info("Broken string at " .. pos .. " " .. EMV.logv(fieldTbl))
				end
				if self.bs:readUShort(pos) > 0 and self.charCount > 0 then
					fieldTbl.value = self.bs:readWString(pos)
					--log.info("read wstring " .. fieldTbl.value .. " @ position " .. pos .. ", " .. self.charCount .. " chars")
				end
				self:seek(pos + self.charCount * 2)
			elseif fieldTbl.LuaTypeName then 
				--if "read" .. fieldTbl.LuaTypeName == "readGUID" then re.msg("guid at " .. self:tell()) end
				fieldTbl.value = self.bs["read" .. fieldTbl.LuaTypeName](self.bs)
			else
				fieldTbl.value = self.bs:readBytes(fieldTbl.elementSize)
			end
			if fieldTbl.LuaTypeName ~= "WString" then 
				self:seek(startPos + fieldTbl.elementSize)
			end
			
		end
		
		if fieldTbl.fieldTypeName=="Data" then
			fieldTbl.fieldTypeName = fieldTbl.fieldTypeName .. fieldTbl.elementSize
		end
		
		fieldTbl.sizeOf = self:tell() - fieldTbl.startOfAbs + self.startOf
		
		return fieldTbl
	end,
	
	loadJson = function(self, doAll, force)
		RSZFile.json_dump_names = json.load_file("rsz\\TypeNames.json")
		RSZFile.json_dump_map = json.load_file("rsz\\TypeNamesMap.json")
		RSZFile.json_dump_components = json.load_file("rsz\\ComponentNames.json")
		if not RSZFile.json_dump_map or force then
			re.msg("Creating data from JSON dumps, this may take a few minutes...")
			RSZFile.json_dump_names, RSZFile.json_dump_map, RSZFile.json_dump_components = {}, {}, {}
			local json_dump = json.load_file("rsz\\rsz"..game_name..".json")
			for hash, tbl in pairs(json_dump) do
				local simpleName =  (doAll and tbl.name) or tbl.name:match("^(.-%..-%..-)$")
				if simpleName and #tbl.fields > 0 and not simpleName:find("[<>`,%[%(]") and simpleName:sub(1,7)~="System." then 
					table.insert(RSZFile.json_dump_names, simpleName)
					local td = sdk.find_type_definition(simpleName)
					if td and td:is_a("via.Component") then 
						table.insert(RSZFile.json_dump_components, simpleName)
					end
					RSZFile.json_dump_map[simpleName] = tonumber("0x"..hash) 
				end
			end
			table.sort(RSZFile.json_dump_names)
			table.sort(RSZFile.json_dump_components)
			json.dump_file("rsz\\TypeNames.json", RSZFile.json_dump_names)
			json.dump_file("rsz\\TypeNamesMap.json", RSZFile.json_dump_map)
			json.dump_file("rsz\\ComponentNames.json", RSZFile.json_dump_components)
		end
	end,
	
	getFieldLuaTypeName = function(self, fieldTbl, fieldTypeName)
		fieldTbl.fieldTypeName = fieldTypeName or fieldTbl.fieldTypeName
		fieldTbl.LuaTypeName = self.typeNames[fieldTbl.fieldTypeName]
		--log.info(tostring(fieldTbl.LuaTypeName) .. " " .. fieldTbl.fieldTypeName)
		if not fieldTbl.LuaTypeName then 
			fieldTbl.LuaTypeName = self.sizesToTypeNames[fieldTbl.elementSize]
			if fieldTbl.elementSize == 64 then 
				fieldTbl.LuaTypeName = "Mat4"
			elseif fieldTbl.elementSize == 16 then 
				if fieldTbl.alignment == 8 then fieldTbl.LuaTypeName = "GUID" else fieldTbl.LuaTypeName = "Vec4" end
			elseif fieldTbl.elementSize == 4 or fieldTbl.elementSize % 4 == 0 then 
				fieldTbl.LuaTypeName = (self:tell() +4 <= self:fileSize()) and (self.bs:detectedFloat() and "Float") or "Int"
				if fieldTbl.elementSize > 4 then 
					fieldTbl.is4ByteArray = true
				end
			end
		end
		return fieldTbl.LuaTypeName
	end,
	
	makeFieldTable = function(self, typeId, index, generateBlankFields, skipList)
		local fieldTbl = {
			name=rsz_parser.GetFieldName(typeId, index),
			index = index,
			typeId = typeId,
			fieldTypeName = rsz_parser.GetFieldTypeName(typeId, index),
			fieldType = rsz_parser.GetFieldType(typeId, index),
			elementSize = rsz_parser.GetFieldSize(typeId, index),
			alignment = rsz_parser.GetFieldAlignment(typeId, index),
			isList = rsz_parser.GetFieldArrayState(typeId, index),
			orgTypeName = rsz_parser.GetFieldOrgTypeName(typeId, index),
			isNative = rsz_parser.IsFieldNative(typeId, index),
		}
		fieldTbl.LuaTypeName = self:getFieldLuaTypeName(fieldTbl)
		if generateBlankFields then
			if fieldTbl.isList and not skipList then 
				fieldTbl.count = 0
				fieldTbl.value = {}
			elseif fieldTbl.LuaTypeName=="WString" then
				fieldTbl.value = ""
			elseif fieldTbl.LuaTypeName =="Vec4" then
				fieldTbl.value = Vector4f.new(0,0,0,0)
			elseif fieldTbl.is4ByteArray then
				fieldTbl.value = {}
				fieldTbl.LuaTypeName = "Float"
				for i=1, math.floor(fieldTbl.elementSize/4) do
					fieldTbl.value[i] = 0
				end
			else
				fieldTbl.value = 0
			end
		end
		return fieldTbl
	end,
	
	createInstance = function(self, typeName, atIndex)
		if not RSZFile.json_dump_map then 
			self:loadJson() 
		end
		local typeId = RSZFile.json_dump_map[typeName]
		if typeId then
			local newInstance = {
				name = rsz_parser.GetRSZClassName(typeId),
				crc = tonumber("0x"..rsz_parser.GetRSZClassCRC(typeId)),
				typeId = typeId,
				fieldCount = rsz_parser.GetFieldCount(typeId),
				startOf = self:fileSize(),
				index = atIndex or #self.rawData,
				fields = {},
			}
			for index = 1, newInstance.fieldCount do 
				self.bs:seek(0)
				table.insert(newInstance.fields, self:makeFieldTable(typeId, index-1, true))
			end
			return newInstance
		end
	end,
	
	addInstance = function(self, typeName, atIndex, newInstance, isRSZObject)
		if not RSZFile.json_dump_names then 
			self:loadJson()
		end
		
		typeName = (newInstance and newInstance.typeName) or typeName
		local typeId = (newInstance and newInstance.typeId) or RSZFile.json_dump_map[typeName]
		
		if typeId then
			atIndex = atIndex or #self.instanceInfos
			local typedef = sdk.find_type_definition(typeName)
			local objectTblInsertPt
			
			for i, objectTblObj in ipairs(self.objectTable) do 
				if objectTblObj.objectId >= atIndex then 
					objectTblInsertPt = objectTblInsertPt or i
					objectTblObj.objectId =  objectTblObj.objectId+1
				end
			end
			
			objectTblInsertPt = objectTblInsertPt or #self.objectTable+1
			for i, instance in ipairs(self.rawData) do
				for f, field in ipairs(instance.fields or {}) do 
					if field.fieldTypeName:find("Object^(Ref)") then 
						if type(field.value)=="table" then
							for o, objId in ipairs(field.value) do
								if objId >= atIndex then 
									field.value[o] = field.value[o] + 1
								end
							end
						else
							--test = {field, atIndex}
							if field.value >= atIndex then
								field.value = field.value + 1 --correct objectIds in RSZ
							end
						end
					end
				end
			end
			
			if isRSZObject or typedef:is_a("via.Component") then
				table.insert(self.objectTable, objectTblInsertPt, { objectId=atIndex })
			end
			
			table.insert(self.instanceInfos, atIndex, { typeId=typeId, CRC=tonumber("0x"..rsz_parser.GetRSZClassCRC(typeId)), })
			
			local new_instance = newInstance or self:createInstance(typeName, atIndex)
			table.insert(self.rawData, atIndex, new_instance)
			
			self.startOf = self.bs:getAlignedOffset(16, self.startOf) --make sure every RSZ buffer rewritten is 16 bytes aligned, and every container file
			self:writeBuffer()
			--self.bs:save("test97.scn")
			self:readBuffer()
			return objectTblInsertPt
		end
	end,
	
	customStructDisplayFunction = function(self, struct)
		if struct.RSZData and imgui.tree_node("RSZ Data") then 
			struct.RSZData:displayImgui()
			imgui.tree_pop()
		end
	end,
	
	-- Structures comprising a RSZ file:
	structs = {
		
		header = {
			{"UInt", "magic"},
			{"UInt", "version"},
			{"UInt", "objectCount"},
			{"UInt", "instanceCount"},
			{"UInt64", "userdataCount"},
			--{"skip", 4}, --reserved
			{"UInt64", "instanceOffset"},
			{"UInt64", "dataOffset"},
			{"UInt64", "userdataOffset"},
		},
		
		objectTable = {
			{"UInt", "objectId"},
		},
		
		instanceInfo = {
			{"UInt", "typeId"},
			{"UInt", "CRC"},
		},
		
		RSZUserDataInfo = tdb_ver > 67 and {
			{"UInt", "instanceId"},
			{"UInt", "typeId"},
			{"UInt64", "pathOffset", {"WString", "path"}},
		} or {
			{"UInt", "instanceId"},
			{"UInt", "typeId"},
			{"UInt", "jsonPathHash"},
			{"UInt", "dataSize"},
			{"UInt64", "RSZOffset"},
		},
		
		structOrder = { "header", "objectTable", "instanceInfo", "RSZUserDataInfo" }	
	},
}

SCNFile = {
	
	--SCN file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".19") or ".20",
		re3 = ".20",
		re8 = ".20",
		re7 = ((tdb_ver==49) and ".18") or ".20",
		dmc5 =".19",
		mhrise = ".20",
	},
	
	isSCN = true,

	-- Creates a new REResource SCNFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newResource(args, setmetatable(o, self))
		if o.bs:fileSize() > 0 then
			o:read()
		end
		o:seek(0)
		return o
	end,
	
	read = function(self, start)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("header")
		
		self.gameObjectInfos = {}
		self.gameObjectInfosIdMap = {}
		for i = 1, self.header.infoCount do 
			self.gameObjectInfos[i] = self:readStruct("gameObjectInfo")
			self.gameObjectInfosIdMap[self.gameObjectInfos[i].objectId] = self.gameObjectInfos[i]
		end
		
		self:seek(self.header.folderInfoOffset)
		self.folderInfos = {}
		for i = 1, self.header.folderCount do 
			self.folderInfos[i] = self:readStruct("folderInfo")
			self.gameObjectInfosIdMap[self.folderInfos[i].objectId] = self.folderInfos[i]
		end
		
		self:seek(self.header.resourceInfoOffset)
		self.resourceInfos = {}
		for i = 1, self.header.resourceCount do 
			self.resourceInfos[i] = self:readStruct("resourceInfo")
			self.resourceInfos[i].name = self.resourceInfos[i].resourcePath
		end
		
		self:seek(self.header.prefabInfoOffset)
		self.prefabInfos = {}
		for i = 1, self.header.prefabCount do 
			self.prefabInfos[i] = self:readStruct("prefabInfo")
			self.prefabInfos[i].name = self.prefabInfos[i].prefabPath
		end
		
		self:seek(self.header.userdataInfoOffset)
		self.userdataInfos = {}
		for i = 1, self.header.userdataCount do 
			self.userdataInfos[i] = self:readStruct("userdataInfo")
			self.userdataInfos[i].name = rsz_parser.GetRSZClassName(self.userdataInfos[i].typeId) .. " - " .. self.userdataInfos[i].userdataPath
		end
		
		self:seek(self.header.dataOffset)
		local stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset})
		
		if self.RSZ.objectTable then
			self:setupGameObjects()
		end
	end,
	
	-- Updates the SCNFile and RSZFile bitstreams from data in owned Lua tables and saves the result to a new file
	save = function(self, filepath, onlyUpdateBuffer)
		
		if not filepath or filepath == self.filepath then 
			filepath = (filepath or self.filepath):gsub("%.scn", ".NEW.scn")
		end
		self.bs = BitStream:new()
		
		self.bs:writeBytes(64)
		
		for i, gameObjectInfo in ipairs(self.gameObjectInfos) do
			self:writeStruct("gameObjectInfo", gameObjectInfo)
		end
		
		if self.folderInfos and self.folderInfos[1] then
			self.bs:align(16)
			self.header.folderInfoOffset = self:tell()
			for i, folderInfo in ipairs(self.folderInfos or {}) do
				self:writeStruct("folderInfo", folderInfo)
			end
		end
		
		self.bs:align(16)
		self.header.resourceInfoOffset = self:tell()
		for i, resourceInfo in ipairs(self.resourceInfos) do
			self:writeStruct("resourceInfo", resourceInfo)
		end
		
		if self.prefabInfos and self.prefabInfos[1] then
			self.bs:align(16)
			self.header.prefabInfoOffset = self:tell()
			for i, prefabInfo in ipairs(self.prefabInfos or {}) do
				self:writeStruct("prefabInfo", prefabInfo)
			end
		end
		
		if self.userdataInfos and self.userdataInfos[1] then
			self.bs:align(16)
			self.header.userdataInfoOffset = self:tell()
			for i, userdataInfo in ipairs(self.userdataInfos) do
				self:writeStruct("userdataInfo", userdataInfo)
			end
		end
		
		self.bs:align(16)
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			self.bs:writeUInt64(self:tell(), wstringTbl.offset)
			self.bs:writeWString(wstringTbl.string)
		end
		
		self.stringsToWrite = nil
		
		self.bs:align(16)
		self.header.dataOffset = self:tell()
		
		self:seek(0)
		self.header.infoCount = #self.gameObjectInfos
		self.header.resourceCount = #self.resourceInfos
		self.header.folderCount = self.folderInfos and #self.folderInfos
		self.header.prefabCount = self.prefabInfos and #self.prefabInfos
		self.header.userdataCount = #self.userdataInfos
		self:writeStruct("header", self.header)
		
		self:seek(self.header.dataOffset)
		self.RSZ.startOfs = self.header.dataOffset
		self.RSZ:writeBuffer()
		self.bs:writeBytes(self.RSZ.bs:getBuffer())
		
		if not onlyUpdateBuffer then
			self.bs:save(filepath)
			re.msg("Saved to " .. filepath)
		end
	end,
	
	saveAsPFB = function(self, filepath)
		if self.folders and self.folders[1] then 
			re.msg("Cannot convert a file with via.Folders!")
			return nil
		end
		self.structs = PFBFile.structs
		self.header.magic = 4343376 --"PFB"
		PFBFile.save(self, filepath)
		self.header.magic = 5129043 --"SCN"
		self.structs = nil
	end,
	
	setupGameObjects = function(self)
		
		local folderIdxMap = {}
		if self.folderInfos then
			self.folders = {}
			for i, info in ipairs(self.folderInfos) do
				info.folder = {
					fInfo = info,
					gameObjects = {},
					folders = {},
					children = {},
					instance = self.RSZ.rawData[ self.RSZ.objectTable[info.objectId+1].objectId ].sortedTbl,
					idx = i,
				}
				info.folder.name = info.folder.instance.name
				info.name = info.folder.name
				
				if info.parentId == -1 then 
					table.insert(self.folders, info.folder)
				end
				folderIdxMap[info.objectId] = info.folder
			end
		end
		
		self.gameObjects = {}
		local gameObjParentMap = {}
		for i, info in ipairs(self.gameObjectInfos) do 
			local gameObject = { 
				gameobj = self.RSZ.rawData[ self.RSZ.objectTable[info.objectId+1].objectId ].sortedTbl, 
				components = {}, 
				children = {}, 
				idx = i, 
				gInfo=info 
			}
			for j=info.objectId + 2, (info.objectId + info.componentCount + 1) do
				table.insert(gameObject.components, self.RSZ.rawData[ self.RSZ.objectTable[j].objectId ].sortedTbl) --
			end
			gameObjParentMap[info.objectId] = gameObject
			info.gameObject = gameObject
			if info.parentId == -1 then
				table.insert(self.gameObjects, gameObject)
			end
			info.name = gameObject.gameobj.fields[1].value --(type(gameObject.gameobj.fields[1].value)=="string" and gameObject.gameobj.fields[1].value) or info.name or ""
			gameObject.name = info.name .. "[" .. gameObject.idx .. "]"
		end
		
		for i, info in ipairs(self.gameObjectInfos) do 
			if gameObjParentMap[info.parentId] then
				table.insert(gameObjParentMap[info.parentId].children, info.gameObject)
				info.gameObject.parent = gameObjParentMap[info.parentId]
			end
			if self.folders and folderIdxMap[info.parentId] then 
				table.insert(folderIdxMap[info.parentId].gameObjects, info.gameObject)
				table.insert(folderIdxMap[info.parentId].children, info.gameObject)
				info.gameObject.parent = folderIdxMap[info.parentId]
			end
		end
		
		for i, info in ipairs(self.folderInfos or {}) do
			if folderIdxMap[info.parentId] then 
				table.insert(folderIdxMap[info.parentId].folders, info.folder)
				table.insert(folderIdxMap[info.parentId].children, info.folder)
				info.folder.parent = folderIdxMap[info.parentId]
			end
		end
	end,
	
	customStructDisplayFunction = function(self, struct, idx)
		if struct.userdataPath and not struct.CRC then 
			changed, struct.newUserDataIdx = imgui.combo("Userdata Instance", struct.newUserDataIdx or EMV.find_index(self.instanceNames, struct.userdataPath) or 1, self.instanceNames)
			if changed then 
				struct.typeId = self.RSZ.instanceInfos[struct.newUserDataIdx].typeId
				struct.CRC = self.RSZ.instanceInfos[struct.newUserDataIdx].CRC
			end
		elseif struct.folderInfo then
			changed, struct.newFolderIdx = imgui.combo("Folder Instance", struct.newFolderIdx or 1, self.instanceNames)
		elseif self.RSZ then
			if struct.objectId then
				changed, struct.newObjectId = imgui.combo("Object Instance", struct.newObjectId or struct.objectId+1, self.RSZ.objectTable.names) -- EMV.find_index(self.RSZ.objectTable, self.objectId, "objectId")
				if changed then 
					struct.objectId = struct.newObjectId-1 
				end
			end
			if struct.parentId then
				struct.newParentId = struct.newParentId or  (struct.parentId==-1 and #self.RSZ.objectTable+1) or struct.parentId+1 
				
				changed, struct.newParentId = imgui.combo("Parent Instance", struct.newParentId, self.RSZ.objectTable.names)
				if changed then 
					if struct.newObjectId == #self.RSZ.objectTable.names then struct.parentId = -1 else struct.parentId = struct.newObjectId-1  end
				end
				
				if struct.gameObject then
					self:displayGameObject(struct.gameObject, "GameObject")
					imgui.tree_pop()
				end
			end
		end
	end,
	
	-- Structures comprising a SCN file:
	structs = {
		header = {
			{"UInt", "magic"},
			{"UInt", "infoCount"},
			{"UInt", "resourceCount"},
			{"UInt", "folderCount"},
			{"UInt", "prefabCount"},
			{"UInt", "userdataCount"},
			{"UInt64", "folderInfoOffset"},
			{"UInt64", "resourceInfoOffset"},
			{"UInt64", "prefabInfoOffset"},
			{"UInt64", "userdataInfoOffset"},
			{"UInt64", "dataOffset"},
		},
		
		gameObjectInfo = {
			{"GUID", "guid"},
			{"Int", "objectId"},
			{"Int", "parentId"},
			{"Short", "componentCount"},
			{"Short", "ukn"},
			{"Int", "prefabId"},
		},
		
		folderInfo = {
			{"Int", "objectId"},
			{"Int", "parentId"},
		},
		
		resourceInfo = {
			{"UInt64", "pathOffset", {"WString", "resourcePath"}},
		},
		
		prefabInfo = {
			{"UInt", "pathOffset", {"WString", "prefabPath"}},
			{"Int", "parentId"},
		},
		
		userdataInfo = {
			{"UInt", "typeId"},
			{"UInt", "CRC"},
			{"UInt64", "pathOffset", {"WString", "userdataPath"}},
		},

		structOrder = { "header", "gameObjectInfo", "folderInfo", "resourceInfo", "prefabInfo", "userdataInfo", }
	},
}

if tdb_ver <= 67 then
	SCNFile.structs.header[5], SCNFile.structs.header[6] = SCNFile.structs.header[6], SCNFile.structs.header[5]
end

PFBFile = {
	
	--PFB file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".16") or ".17",
		re3 = ".17",
		re8 = ".17",
		re7 = ((tdb_ver==49) and ".16") or ".17",
		dmc5 =".16",
		mhrise = ".17",
	},
	
	isPFB = true,

	-- Creates a new REResource PFBFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newResource(args, setmetatable(o, self))
		if o.bs:fileSize() > 0 then
			o:read()
		end
		o:seek(0)
		return o
	end,
	
	read = function(self, start)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("header")
		self.gameObjectInfos = {}
		self.gameObjectInfosIdMap = {}
		for i = 1, self.header.infoCount do 
			self.gameObjectInfos[i] = self:readStruct("gameObjectInfo")
			self.gameObjectInfosIdMap[self.gameObjectInfos[i].objectId] = self.gameObjectInfos[i]
		end
		
		self:seek(self.header.resourceInfoOffset)
		self.resourceInfos = {}
		for i = 1, self.header.resourceCount do 
			self.resourceInfos[i] = self:readStruct("resourceInfo")
			self.resourceInfos[i].name = self.resourceInfos[i].resourcePath
		end
		
		if self.header.userdataInfoOffset then
			self:seek(self.header.userdataInfoOffset)
			self.userdataInfos = {}
			for i = 1, self.header.userdataCount do 
				self.userdataInfos[i] = self:readStruct("userdataInfo")
				self.userdataInfos[i].name = rsz_parser.GetRSZClassName(self.userdataInfos[i].typeId) .. " - " .. self.userdataInfos[i].userdataPath
			end
		end
		
		self:seek(self.header.dataOffset)
		local stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset})
		
		if self.RSZ.objectTable then
			SCNFile.setupGameObjects(self)
		end
	end,
	
	-- Updates the PFBFile and RSZFile BitStreams with data from owned Lua tables, and saves the result to a new file
	save = function(self, filepath, onlyUpdateBuffer)
		
		if not filepath or filepath == self.filepath then 
			filepath = (filepath or self.filepath):gsub("%.pfb", ".NEW.pfb")
		end
		
		self.bs = BitStream:new()
		self.bs:writeBytes(PFBFile.structSizes["header"])
		
		for i, gameObjectInfo in ipairs(self.gameObjectInfos) do
			self:writeStruct("gameObjectInfo", gameObjectInfo)
		end
		
		self.bs:align(16)
		self.header.resourceInfoOffset = self:tell()
		for i, resourceInfo in ipairs(self.resourceInfos) do
			self:writeStruct("resourceInfo", resourceInfo)
			if isOldVer then self.bs:skip(-2) end
		end
		
		if self.userdataInfos and self.userdataInfos[1] then
			self.bs:align(16)
			self.header.userdataInfoOffset = self:tell()
			for i, userdataInfo in ipairs(self.userdataInfos) do
				self:writeStruct("userdataInfo", userdataInfo)
			end
		end
		
		self.bs:align(16)
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			self.bs:writeUInt64(self:tell(), wstringTbl.offset)
			self.bs:writeWString(wstringTbl.string)
		end
		self.stringsToWrite = nil
		
		self.bs:align(16)
		self.header.dataOffset = self:tell()
		
		self.RSZ.startOfs = self.header.dataOffset
		self.RSZ:writeBuffer()
		self.bs:writeBytes(self.RSZ.bs:getBuffer())
		
		self:seek(0)
		self.header.infoCount = #self.gameObjectInfos
		self.header.resourceCount = #self.resourceInfos
		self.header.uknPFBInfoCount = self.uknPFBInfos and #self.uknPFBInfos
		self.header.userdataCount = #self.userdataInfos
		self:writeStruct("header", self.header)
		if not onlyUpdateBuffer then
			self.bs:save(filepath)
			re.msg("Saved to " .. filepath)
		end
	end,
	
	saveAsSCN = function(self, filepath)
		self.structs = SCNFile.structs
		SCNFile.save(self, filepath)
		self.structs = nil
	end,
	
	customStructDisplayFunction = SCNFile.customStructDisplayFunction,
	
	-- Structures comprising a PFB file:
	structs = {
		header = {
			{"UInt", "magic"},
			{"UInt", "infoCount"},
			{"UInt", "resourceCount"},
			{"UInt", "uknPFBInfoCount"},
			{"UInt64", "userdataCount"}, --{"skip", 4},
			{"UInt64", "uknPFBInfoInfoOffset"},
			{"UInt64", "resourceInfoOffset"},
			{"UInt64", "userdataInfoOffset"},
			{"UInt64", "dataOffset"},
		},
		
		gameObjectInfo = {
			{"Int", "objectId"},
			{"Int", "parentId"},
			{"Int", "componentCount"},
		},
		
		resourceInfo = {
			{"UInt64", "pathOffset", {"WString", "resourcePath"}},
		},
		
		userdataInfo = {
			{"UInt", "typeId"},
			{"UInt", "CRC"},
			{"UInt64", "pathOffset", {"WString", "userdataPath"}},
		},
		
		structOrder = {"header", "gameObjectInfo", "resourceInfo", "userdataInfo"}
	},
}

if tdb_ver <= 67 then 
	table.remove(PFBFile.structs.header, 8)
	table.remove(PFBFile.structs.header, 5)
	table.remove(PFBFile.structs.structOrder, 4)
	PFBFile.structs.resourceInfo = { {"WString", "resourcePath"}, }
end

--pfb = PFBFile:new("REResources\\em1240deadbody.pfb.17")

UserFile = {
	
	--User file extensions by game
	extensions = {
		re2 = ".2",
		re3 = ".2",
		re8 = ".2",
		re7 = ".2",
		dmc5 = ".2",
		mhrise = ".2",
	},
	
	isUser = true,

	-- Creates a new REResource.UserFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newResource(args, setmetatable(o, self))
		if o.bs:fileSize() > 0 then
			o:read()
		end
		o:seek(0)
		return o
	end,
	
	read = function(self, start)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("header")
		
		self:seek(self.header.resourceInfoOffset)
		self.resourceInfos = {}
		for i = 1, self.header.resourceCount do 
			self.resourceInfos[i] = self:readStruct("resourceInfo")
			self.resourceInfos[i].name = self.resourceInfos[i].path
		end
		
		self:seek(self.header.userdataInfoOffset)
		self.userdataInfos = {}
		for i = 1, self.header.userdataCount do 
			self.userdataInfos[i] = self:readStruct("userdataInfo")
			self.userdataInfos[i].name = rsz_parser.GetRSZClassName(self.userdataInfos[i].typeId)
		end
		
		self:seek(self.header.dataOffset)
		stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset})
		
	end,
	
	-- Updates the UserFile and RSZFile BitStreams with data from owned Lua tables, and saves the result to a new file
	save = function(self, filepath)
		
		if not filepath or filepath == self.filepath then 
			filepath = (filepath or self.filepath):gsub("%.user", ".NEW.user")
		end
		self.bs = BitStream:new()
		
		self.bs:writeBytes(40)
		
		self.bs:align(16)
		self.header.resourceInfoOffset = self:tell()
		for i, resourceInfo in ipairs(self.resourceInfos) do
			self:writeStruct("resourceInfo", resourceInfo)
		end
		
		self.bs:align(16)
		self.header.userdataInfoOffset = self:tell()
		for i, userdataInfo in ipairs(self.userdataInfos) do
			self:writeStruct("userdataInfo", userdataInfo)
		end
		
		self.bs:align(16)
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			self.bs:writeUInt64(self:tell(), wstringTbl.offset)
			self.bs:writeWString(wstringTbl.string)
		end
		self.stringsToWrite = nil
		
		self.bs:align(16)
		self.header.dataOffset = self:tell()
		
		self.RSZ.startOfs = self.header.dataOffset
		self.RSZ:writeBuffer()
		self.bs:writeBytes(self.RSZ.bs:getBuffer())
		
		self:seek(0)
		self.header.resourceCount = #self.resourceInfos
		self.header.userdataCount = #self.userdataInfos
		self:writeStruct("header", self.header)
		
		if (self.bs:save(filepath) and filepath) then
			re.msg("Saved to " .. filepath)
			return true
		end
	end,
	
	-- Structures comprising a User.2 file:
	structs = {
		header = {
			{"UInt", "magic"},
			{"UInt", "resourceCount"},
			{"UInt", "userdataCount"},
			{"UInt", "infoCount"},
			{"UInt64", "resourceInfoOffset"},
			{"UInt64", "userdataInfoOffset"},
			{"UInt64", "dataOffset"},
		},
		
		resourceInfo = {
			{"UInt64", "pathOffset", {"WString", "resourcePath"}},
		},
		
		userdataInfo = {
			{"UInt", "typeId"},
			{"UInt", "CRC"},
			{"UInt64", "pathOffset", {"WString", "userdataPath"}},
		},
		
		structOrder = {"header", "resourceInfo", "userdataInfo"}
	},
}

-- Class for MDF Material files
MDFFile = {
	
	--MDF file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".10") or ".21",
		re3 = ((tdb_ver==68) and ".13") or ".21",
		re8 = ".19",
		re7 = ((tdb_ver==49) and ".6") or ".21",
		dmc5 =".10",
		mhrise = ".23",
	},
	
	isMDF = true,
	
	-- Creates a new REResource.MDFFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newResource(args, setmetatable(o, self))
		if o.bs:fileSize() > 0 then
			o:read()
		end
		o:seek(0)
		return o
	end,
	
	-- Reads the BitStream and packs the data into organized Lua tables
	read = function(self, start)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("header")
		self.matCount = self.header.matCount
		self.bs:align(16)
		
		self.matHeaders = {}
		for m = 1, self.matCount do 
			self.matHeaders[m] = self:readStruct("matHeader")
			self.matHeaders[m].name = self.matHeaders[m].matName
		end
		
		self.texHeaders = {}
		self.bs:seek(self.matHeaders[1].texHdrOffset)
		
		for m = 1, self.matCount do 
			self.texHeaders[m] = {name=self.matHeaders[m].name}
			for t = 1, self.matHeaders[m].texCount do 
				self.texHeaders[m][t] = self:readStruct("texHeader")
				self.texHeaders[m][t].name = self.texHeaders[m][t].texType .. ": " .. self.texHeaders[m][t].texPath
				self.texHeaders[m][t].matIdx = m
			end
		end
		
		self.paramHeaders = {}
		self.bs:seek(self.matHeaders[1].paramHdrOffset)
		for m = 1, self.matCount do 
			
			self.paramHeaders[m] = {}
			for p = 1, self.matHeaders[m].paramCount do 
				local paramHdr = self:readStruct("paramHeader")
				paramHdr.paramAbsOffset = self.matHeaders[m].paramsOffset + paramHdr.paramRelOffset
				--log.info("Reading param " .. p .. " for mat " .. m .. " at " .. paramHdr.paramAbsOffset)
				if paramHdr.componentCount == 4 then
					paramHdr.parameter = { self.bs:readFloat(paramHdr.paramAbsOffset), self.bs:readFloat(paramHdr.paramAbsOffset+4), self.bs:readFloat(paramHdr.paramAbsOffset+8), self.bs:readFloat(paramHdr.paramAbsOffset+12) }
				else
					paramHdr.parameter = self.bs:readFloat(paramHdr.paramAbsOffset)
				end
				paramHdr.name = paramHdr.paramName
				self.paramHeaders[m][p] = paramHdr
			end
			self.paramHeaders[m].name = self.matHeaders[m].name
		end
		
		self.stringsStart = self.bs:tell()
		self.stringsSize = self.matHeaders[1].paramsOffset - self.stringsStart
	end,
	
	-- Saves a new MDF file using data from owned Lua tables
	save = function(self, filepath, mesh)
		
		if not filepath or filepath == self.filepath then
			filepath = (filepath or self.filepath):gsub("%.mdf2", ".NEW.mdf2")
		end
		
		self.bs = BitStream:new()
		self:writeStruct("header", self.header, 0)
		self.bs:align(16, 1)
		
		--load REF data into Lua tables for write
		local vars = {}
		mesh = mesh or self.mobject
		if mesh then 
			for m = 1, self.matCount do 
				local matID = m - 1
				local varNum = mesh:call("getMaterialVariableNum", matID)
				for p=1, varNum do
					local type_of = mesh:call("getMaterialVariableType", matID, p - 1)
					if type_of == 1 then 
						self.paramHeaders[m][p].parameter = mesh:call("getMaterialFloat", matID, p - 1)
					elseif type_of == 4 then 
						local vec4 = mesh:call("getMaterialFloat4", matID, p - 1)
						self.paramHeaders[m][p].parameter = {vec4.x, vec4.y, vec4.z, vec4.w}
					end
				end
				for t=1, mesh:call("getMaterialTextureNum", matID) do
					local tex = mesh:call("getMaterialTexture", matID, t-1)
					local texPath = (tex and tex:call("ToString()"):match("^.+%[@?(.+)%]"))
					self.texHeaders[m][t].texPath = texPath or self.texHeaders[m][t].texPath
				end
			end
		end
		
		for m = 1, self.matCount do
			self:writeStruct("matHeader", self.matHeaders[m])
		end
		
		for m = 1, self.matCount do
			self.matHeaders[m].texHdrOffset = self:tell()
			for t = 1, self.matHeaders[m].texCount do 
				self:writeStruct("texHeader", self.texHeaders[m][t])
			end
		end
		
		for m = 1, self.matCount do
			self.matHeaders[m].paramHdrOffset = self:tell()
			for p = 1, self.matHeaders[m].paramCount do 
				self:writeStruct("paramHeader", self.paramHeaders[m][p])
			end
		end
		
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			self.bs:writeUInt64(self:tell(), wstringTbl.offset)
			self.bs:writeWString(wstringTbl.string)
		end
		self.stringsToWrite = nil
		
		
		for m = 1, self.matCount do
			self.bs:align(16)
			self.matHeaders[m].paramsOffset = self:tell()
			local start = self:tell()
			for p = 1, self.matHeaders[m].paramCount do 
				if self.paramHeaders[m][p].componentCount == 1 then 
					self.bs:writeFloat(self.paramHeaders[m][p].parameter)
				else
					self.bs:writeArray(self.paramHeaders[m][p].parameter, "Float")
				end
				self.paramHeaders[m][p].paramRelOffset = self:tell() - start
				--self:writeStruct("paramHeader", self.paramHeaders[m][p], self.paramHeaders[m][p].startOf)
			end
			self:writeStruct("matHeader", self.matHeaders[m], self.matHeaders[m].startOf)
		end
		
		if (self.bs:save(filepath) and filepath) then
			re.msg("Saved to " .. filepath)
			return true
		end
	end,
	
	-- Recreates the strings buffer from the Lua tables so that each string is unique in the file
	--[[updateStringsBuffer = function(self)
		local newStringsBuffer = BitStream:new()
		for i, offsetTbl in ipairs(self.offsets) do
			if offsetTbl.dataType == "WString" then
				self.bs:writeUInt64(self.stringsStart + newStringsBuffer:tell(), offsetTbl.readAddress)
				newStringsBuffer:writeWString(offsetTbl.ownerTbl[offsetTbl.dataName])
			end
		end
		newStringsBuffer:padToAlignment(self.stringsSize) 
		local diff = newStringsBuffer:fileSize() - self.stringsSize
		self.bs:removeBytes(self.stringsSize, self.stringsStart)
		self.bs:insertBytes(newStringsBuffer:fileSize(), self.stringsStart)
		self.bs:writeBytes(newStringsBuffer:getBuffer(), self.stringsStart)
		self:scanFixStreamOffsets(0, self:fileSize(), self.stringsStart + self.stringsSize + diff - 16, self:fileSize() + diff, diff, 8)
		self:read() --reload the buffer into tables
	end,]]
	
	--Is used during displayImgui to add extra stuff to structs 
	customStructDisplayFunction = function(self, struct)
		if struct.parameter then 
			if struct.componentCount == 4 then--struct.paramName:find("olor") then 
				local vecForm = Vector4f.new(struct.parameter[1], struct.parameter[2], struct.parameter[3], struct.parameter[4])
				changed, vecForm = EMV.show_imgui_vec4(vecForm, struct.name, nil, 0.01)
				struct.parameter = {vecForm.x, vecForm.y, vecForm.z, vecForm.w}
			else
				changed, struct.parameter = imgui.drag_int(struct.name, struct.parameter, 1, -9999999, 9999999)
			end
		end
	end,
	
	-- Structures comprising a MDF file:
	structs = {
		header = {
			{"UInt", "magic"},
			{"Short", "mdfVersion"},
			{"Short", "matCount"},
		},
		
		matHeader = {
			{"UInt64", "matNameOffset", {"WString", "matName"}},
			{"UInt", "matNameHash"},
			{"UInt", "paramsSize"},
			{"UInt", "paramCount"},
			{"UInt", "texCount"},
			{"UInt", "shaderType"},
			{"UInt", "alphaFlags"},
			--{"skip", 3},
			{"UInt64", "paramHdrOffset"},
			{"UInt64", "texHdrOffset"},
			{"UInt64", "paramsOffset"},
			{"UInt64", "mmtrPathOffset", {"WString", "mmtrPath"}},
		},
		
		texHeader = {
			{"UInt64", "texTypeOffset", {"WString", "texType"}},
			{"UInt", "hash"},
			{"UInt", "asciiHash"},
			{"UInt64", "texPathOffset", {"WString", "texPath"}},
		},
		
		paramHeader = {
			{"UInt64", "paramNameOffset", {"WString", "paramName"}},
			{"UInt", "hash"},
			{"UInt", "asciiHash"},
			{"UInt", "componentCount"},
			{"UInt", "paramRelOffset"},
		},
		
		structOrder = {"header", "matHeader", "texHeader", "paramHeader"}
	},
}

-- MDFFile struct adjustments for different TDB versions:
if tdb_ver >= 69 then --RE8+
	table.insert(MDFFile.structs.matHeader, 10, {"UInt64", "firstMaterialNameOffset"})
	table.insert(MDFFile.structs.matHeader, 6, {"skip", 8})
end

if tdb_ver >= 68 then --RE3R+
	table.insert(MDFFile.structs.texHeader, {"skip", 8})
	MDFFile.structs.paramHeader[4], MDFFile.structs.paramHeader[5] = MDFFile.structs.paramHeader[5], MDFFile.structs.paramHeader[4]
end

if tdb_ver == 49 then --RE7
	table.insert(MDFFile.structs.matHeader, 3, {"UInt64", "uknRE7"})
end


--setup struct sizes:
for className, class in pairs({RSZFile, PFBFile, SCNFile, UserFile, MDFFile}) do
	class.structSizes = {}
	for name, structArray in pairs(class.structs) do
		local totalBytes = 0
		for i, fieldTbl in ipairs(structArray) do 
			totalBytes = totalBytes + (REResource.typeNamesToSizes[ fieldTbl[1] ] or 0)
		end
		class.structSizes[name] = totalBytes
	end
end


--scn:saveAsPFB("REResources\\st11_020_kitchen_in2f.pfb.17")
--user = UserFile:new("em1000configuration.user.2")
--system_difficulty_rate_data.user.2
--$natives\\stm\\REResources\\evc0010_Character.pfb.17
--scn = SCNFile:new("REResources\\evc3009_Character.scn.20")

--scn = SCNFile:new("REResources\\st11_076_BasementB_In1B.scn.20")
--scn = SCNFile:new("REResources\\st11_020_kitchen_in2f.scn.20")
--scn.RSZ:addInstance("via.motion.Motion")
--scn:save()
--scn.RSZ:addInstance("via.physics.Colliders")
--scn = SCNFile:new("REResources\\ItemBox.scn.20")
--scn = SCNFile:new("REResources\\em1302pool.scn.20")
--buffer = scn.RSZ:writeBuffer()
--buffer:save("test99.scn")

--[[function testInsert()
	MDF = MDFFile:new{"REResources\\pl0003.mdf2.10"}
	MDF:fixOffsets(0, MDF.bs:fileSize(), MDF.matHeaders[#MDF.matHeaders].startOf+MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.bs.size + MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.matHeaders[#MDF.matHeaders].sizeOf, 8) --
	MDF:insertStruct("matHeader", MDF.matHeaders[#MDF.matHeaders])
	MDF:read()
	MDF.header.matCount = MDF.header.matCount + 1
	MDF:save("REResources\\saved.mdf2.10")
end]]

--[[
MeshFile = {
	
	new = function(self, args, o)
		
		o = o or {}
		o.filepath = args.filepath or (type(args[1])=="string" and args[1]) or (type(args)=="string" and args) or o.filepath
		args = type(args)=="table" and args
		o.bs = args.bs or (o.filepath and BitStream:new(o.filepath)) or o.bs
		
		if not o.bs then 
			for k, v in pairs(args or {}) do 
				o[k] = v
			end
			self.__index = self
			return setmetatable(o, self) --write mode
		end
		
		local bs = o.bs
		o.mesh = args.mesh or (type(args[2])=="userdata" and args[2]) or o.mesh
		o.header = self.readHeader(o)
		
		--bones
		bs:seek(o.header.bonesOffs)
		o.bnHeader = self.readBonesHeader(o)
		
		o.numMats = bs:readByte(o.header.LODOffs + 1) 
		o.localMats = {}
		o.globalMats = {}
		o.inverseMats = {}
		o.matNames = {}
		o.boneNames = {}
		
		bs:seek(o.header.namesOffs)
		log.info(bs:tell())
		for i = 1, o.numMats do 
			o.matNames[i] = bs:readString(bs:readUInt64())
			log.info(o.matNames[i])
		end
		
		for i = 1, o.bnHeader.numBones do 
			o.boneNames[i] = bs:readString(bs:readUInt64())
			log.info(o.boneNames[i])
		end
		
		bs:seek(o.bnHeader.localTrnsMtxOffs)
		for i, key in ipairs({"localMats", "globalMats", "inverseMats"}) do 
			for b = 1, o.bnHeader.numBones do
				o[key][#o[key]+1] = Matrix4x4f.new(
					Vector4f.new((bs:readFloat()), (bs:readFloat()), (bs:readFloat()), (bs:readFloat())),
					Vector4f.new((bs:readFloat()), (bs:readFloat()), (bs:readFloat()), (bs:readFloat())),
					Vector4f.new((bs:readFloat()), (bs:readFloat()), (bs:readFloat()), (bs:readFloat())),
					Vector4f.new((bs:readFloat()), (bs:readFloat()), (bs:readFloat()), (bs:readFloat())))
				o[key][ o.boneNames[i] .. "Map" ] = o[key][#o[key]+1]
			end
		end
		
		self.__index = self
		return setmetatable(o, self)
	end,
	
	readHeader = function(self)
		local h = {}
		local bs = self.bs
		h.magic = bs:readUInt()
		h.meshVersion = bs:readUInt()
		h.fileSize = bs:readUInt()
		h.LODGroupHash = bs:readUInt()
		h.flag = bs:readUByte()
		h.solvedOffset = bs:readUByte()
		h.numNodes = bs:readUShort()
		bs:skip(4)
		h.LODOffs = bs:readUInt64()
		h.shadowLODOffs = bs:readUInt64()
		h.occluderMeshOffs = bs:readUInt64()
		h.bonesOffs = bs:readUInt64()
		h.topologyOffs = bs:readUInt64()
		h.bsHeaderOffs = bs:readUInt64()
		h.BBHeaderOffs = bs:readUInt64()
		h.vert_buffOffs = bs:readUInt64()
		h.ukn = bs:readUInt64()
		h.matIndicesOffs = bs:readUInt64()
		h.boneIndicesOffs = bs:readUInt64()
		h.bsIndicesOffs = bs:readUInt64()
		h.namesOffs = bs:readUInt64()
		return h
	end,
	
	readBonesHeader = function(self)
		local bh = {start=self.bs:tell()}
		bh.numBones = self.bs:readUInt()
		bh.boneMapCount = self.bs:readUInt()
		self.bs:skip(8)
		bh.hierarchyOffs = self.bs:readUInt64()
		bh.localTrnsMtxOffs = self.bs:readUInt64()
		bh.globalTrnsMtxOffs = self.bs:readUInt64()
		bh.inverseGlobalTrnsMtxOffs = self.bs:readUInt64()
		return bh
	end,
	
	writeBoneMatrices = function(self, mesh, facial_only)
		
		local xform = mesh and mesh:call("get_GameObject"):call("get_Transform")
		mesh = mesh or self.mesh
		self.mesh = mesh
		local bs = self.bs
		
		if xform and xform:read_qword(0x10)~=0 then
			for b, bnName in ipairs(self.boneNames) do
				local joint = xform:call("getJointByName", bnName)
				if joint and b > 6 then 
					local jointParent = joint:call("get_Parent")
					local mats = {}
					mats.globalMat = joint:call("get_WorldMatrix")--xform:calculate_base_transform(joint)
					mats.inverseMat = (Matrix4x4f.new(mats.globalMat[0], mats.globalMat[1], mats.globalMat[2], mats.globalMat[3])):inverse()
					mats.localMat = Matrix4x4f.new(mats.globalMat[0], mats.globalMat[1], mats.globalMat[2], mats.globalMat[3])
					if jointParent then 
						mats.localMat = mats.localMat * ((xform:calculate_base_transform(jointParent))):inverse()
					end
					

					
					--for i, key in ipairs({"localMat", "globalMat", "inverseMat"}) do 
						--local bnMat = mats[key]
						--if bnMat then --and i==1 then
							if jointParent then
								--local bnMat = mats.localMat
								bs:seek(self.bnHeader.localTrnsMtxOffs + ((b-1) * 64))
								
								local bnMat = joint:call("get_LocalMatrix") --joint:call("get_BaseLocalRotation"):to_mat4()
								--local pos = joint:call("get_BaseLocalPosition")
								--bnMat[3] = pos:to_vec4()
								log.info(bnName .. " Local " .. bs:tell() .. EMV.mat4_to_string(bnMat))
								bs:writeFloat(bnMat[0].x); bs:writeFloat(bnMat[0].y); bs:writeFloat(bnMat[0].z); bs:writeFloat(0.0)
								bs:writeFloat(bnMat[1].x); bs:writeFloat(bnMat[1].y); bs:writeFloat(bnMat[1].z); bs:writeFloat(0.0)
								bs:writeFloat(bnMat[2].x); bs:writeFloat(bnMat[2].y); bs:writeFloat(bnMat[2].z); bs:writeFloat(0.0)
								
								--bs:writeFloat(pos.x); bs:writeFloat(pos.y); bs:writeFloat(pos.z); bs:writeFloat(1.0)
								bs:writeFloat(bnMat[3].x); bs:writeFloat(bnMat[3].y); bs:writeFloat(bnMat[3].z); bs:writeFloat(1.0)
							end
							local bnMat = mats.globalMat
							bs:seek(self.bnHeader.globalTrnsMtxOffs + ((b-1) * 64))
							log.info(bnName .. " Global " .. bs:tell() .. EMV.mat4_to_string(bnMat))
							bs:writeFloat(bnMat[0].x); bs:writeFloat(bnMat[0].y); bs:writeFloat(bnMat[0].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[1].x); bs:writeFloat(bnMat[1].y); bs:writeFloat(bnMat[1].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[2].x); bs:writeFloat(bnMat[2].y); bs:writeFloat(bnMat[2].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[3].x); bs:writeFloat(bnMat[3].y); bs:writeFloat(bnMat[3].z); bs:writeFloat(1.0)
							
							local bnMat = mats.inverseMat
							bs:seek(self.bnHeader.inverseGlobalTrnsMtxOffs + ((b-1) * 64))
							log.info(bnName .. " Inverse " .. bs:tell() .. EMV.mat4_to_string(bnMat))
							bs:writeFloat(bnMat[0].x); bs:writeFloat(bnMat[0].y); bs:writeFloat(bnMat[0].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[1].x); bs:writeFloat(bnMat[1].y); bs:writeFloat(bnMat[1].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[2].x); bs:writeFloat(bnMat[2].y); bs:writeFloat(bnMat[2].z); bs:writeFloat(0.0)
							bs:writeFloat(bnMat[3].x); bs:writeFloat(bnMat[3].y); bs:writeFloat(bnMat[3].z); bs:writeFloat(1.0)
						--end
					--end
				end
			end
		end
	end,
}
]]

--MDF = MDFFile:new("REResources/ch02_0201_gpucloth.mdf2.19")


--[[
local function imgui_file_picker()
	imgui.begin_window("File Picker")
		local current_dir = ""
	imgui.end_window()
	local glob = fs.glob
end]]



--re.on_frame(function()
	--[[if imgui.tree_node(scn.filepath) then
		scn:displayImgui()
		--imgui_file_picker()
		imgui.tree_pop()
	end]]
	
	--[[if imgui.tree_node(MDF.filepath) then
		MDF:displayImgui()
		--imgui_file_picker()
		imgui.tree_pop()
	end]]
	--[[if not folderTree then
		for i, filepath in pairs(fs.glob(".*")) do
			generateFolderTree(filepath)
		end
	end]]
--end)