--REResource.lua
--REFramework Script for managed RE Engine files 
--by alphaZomega
--July 27 2022

local EMV = require("EMV Engine")

local bool_to_number = { [true]=1, [false]=0 }
local number_to_bool = { [1]=true, [0]=false }
local game_name = (isSF6 and "sf6") or reframework.get_game_name()
local tdb_ver = sdk.get_tdb_version()
local rt_suffix = ((game_name=="re2" or game_name=="re3") and tdb_ver > 69 and "rt") or ""
local isOldVer = tdb_ver <= 67
local addFontSize = 3
local nativesFolderType = ((tdb_ver <= 67) and "x64") or "stm"
local shift_key_down
local copyBuffer = {}
local changed
local re23ConvertJson
local re23ConvertJsonPath
ResourceEditor = nil

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

local function generateRandomGuid()
	local uptime = math.floor(os.clock() * 100)
	local result = {}
	for i=1, 16 do
		math.randomseed(uptime + i)
		if i==4 or i==6 or i==8 or i==10 then 
			table.insert(result, "-")
		end
		table.insert(result, string.format("%x", math.random(128, 256)-1))
	end
	return table.concat(result)
end

local function getWStringSize(value)
	local ctr = 1
	for p, c in utf8.codes(value) do 
		if not c or c==0 then break end
		ctr = ctr + 1
	end
	return ctr
end

if rsz_parser and not rsz_parser.IsInitialized() then 
	rsz_parser.ParseJson("reframework\\data\\rsz\\rsz" .. game_name .. rt_suffix .. ".json")
end

local displayStruct
local displayStructList

-- Core resource class with important file methods shared by all specific resource types:
RE_Resource = {
	
	typeNamesToSizes = {
		UByte=1,
		Byte=1,
		UShort=2,
		Short=2,
		Int=4,
		UInt=4,
		Int64=8,
		UInt64=8,
		Vec2=8,
		Vec3=16,
		Vec4=16,
		GUID=16,
		Float=4,
		Float3=12,
		Float4=16,
		Float5=20,
	},
	
	validExtensions = {},
	
	-- Creates a new Resource with a potential bitstream, filepath (and file if it is found), and a managed object
	newResource = function(self, args, o)
		
		o = o or {}
		
		local newMT = {} --set mixed metatable of RE_Resource and outer File class:
		for key, value in pairs(self) do newMT[key] = value end
		for key, value in pairs(getmetatable(o)) do newMT[key] = value end
		newMT.__index = newMT
		o = setmetatable(o, newMT)
		
		argsTbl = (type(args)=="table" and args) or {}
		o.filepath = argsTbl.filepath or (type(argsTbl[1])=="string" and argsTbl[1]) or (type(args)=="string" and args) or o.filepath
		o.mobject = argsTbl.mobject or (type(argsTbl[1])=="userdata" and argsTbl[1]) or (type(argsTbl[2])=="userdata" and argsTbl[2]) or (type(args)=="userdata" and args) or o.mobject
		o.bs = args.bs or BitStream:new(o.filepath, args.file) or o.bs
		o.offsets = {}
		
		o.ext = o.extensions and o.extensions[game_name] or ".?"
		if o.isRSZ then
			if not rsz_parser then 
				re.msg("Failed to locate reframework\\data\\plugins\\rsz_parser_REF.dll !\n")
				o.bs = BitStream:new()
			elseif not rsz_parser.IsInitialized() then 
				rsz_parser.ParseJson("reframework\\data\\rsz\\rsz" .. game_name .. rt_suffix .. ".json")
				if not rsz_parser.IsInitialized() then 
					re.msg("Failed to locate reframework\\data\\rsz\\rsz" .. game_name .. rt_suffix .. ".json !\nDownload this file from https://github.com/alphazolam/RE_RSZ")
					o.bs = BitStream:new()
				end
			end
			if isRE2 or isRE3 then
				if BitStream.checkFileExists("rsz\\rsz" .. ((isRE2 and "re3") or "re2") .. rt_suffix .. ".json") then
					re23ConvertJsonPath = "rsz\\rsz" .. ((isRE2 and "re3") or "re2") .. rt_suffix .. ".json"
				--else
				--	re.msg("reframework\\data\\rsz\\rsz" .. ((isRE2 and "re3") or "re2") .. rt_suffix .. ".json\n NOT FOUND")
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
				--asdfg = {self, keyOrOffset, structName, methodName}
				output[ keyOrOffset ] = self.bs[ "read" .. methodName ](self.bs)
				if fieldTbl.isOffset or fieldTbl[3] or keyOrOffset:find("Offse?t?") then
					local pos = self.bs:tell()
					table.insert(self.offsets, {ownerTbl=output, name=keyOrOffset, readAddress=self.bs:tell()-8, offsetTo=output[keyOrOffset], relativeStart=relativeOffset})
					if fieldTbl[3] then --read strings from string offsets:
						output[ fieldTbl[3][2] ] = output[keyOrOffset] > 0 and self.bs[ "read" .. fieldTbl[3][1] ](self.bs, output[keyOrOffset]) or "" -- + (relativeOffset or 0))
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
				local valueToWrite = tableToWrite[keyOrOffset] or (fieldTbl[1] == "GUID" and generateRandomGuid()) or (fieldTbl[1] == "WString" and "") or 0
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
	
	checkOpenResource = function(self, path, fieldTbl, fieldIdx)
		if type(path) ~= "string" then return end
		path = path:lower():gsub("/", "\\")
		local ext = path:match("^.+%.(.+)$")
		if ext and path:find("%\\") then
			fieldTbl.isResource = true
			if RE_Resource.validExtensions[ext] then 
				if not tonumber(ext) and RE_Resource.validExtensions[ext] then
					path = path .. RE_Resource.validExtensions[ext].extensions[game_name]
				end
				fieldTbl.cleanPath = "$natives\\" .. nativesFolderType .. "\\" .. path
				if not ResourceEditor.previousItems[fieldTbl.cleanPath] and BitStream.checkFileExists(fieldTbl.cleanPath) then
					if fieldIdx then 
						fieldTbl.canOpen = fieldTbl.canOpen or {}
						fieldTbl.canOpen[fieldIdx] = fieldTbl.cleanPath
					else
						fieldTbl.canOpen = fieldTbl.cleanPath
					end
				end
			end
		end
	end,
	
	openResource = function(path, noPrompt)
		
		if not path then return end
		local lowerC = path:lower():gsub("/", "\\")
		local ext = lowerC:match("^.+%.(.+)$")
		local numberExt = ""
		if not tonumber(ext) and RE_Resource.validExtensions[ext] then
			numberExt = RE_Resource.validExtensions[ext].extensions[game_name]
			lowerC = lowerC .. numberExt
		end
		
		if lowerC:sub(1,1)=="$" and not BitStream.checkFileExists(lowerC) and BitStream.checkFileExists(lowerC:sub(14,-1)) then 
			lowerC = lowerC:sub(14,-1)
		end
		
		local currentItem = nil
		if lowerC:find("%.mdf2") then 
			currentItem = MDFFile:new(lowerC)
		elseif lowerC:find("%.pfb") then
			currentItem = PFBFile:new(lowerC)
		elseif lowerC:find("%.scn") then
			currentItem = SCNFile:new(lowerC)
		elseif lowerC:find("%.user") then 
			currentItem = UserFile:new(lowerC)
		elseif lowerC:find("%.chain") then 
			currentItem = ChainFile:new(lowerC)
		end
		
		currentItem = (currentItem and currentItem.bs.fileExists and currentItem.bs.size > 0 and currentItem) or nil
		ResourceEditor.textBox = lowerC
		
		if currentItem and currentItem.filepath ~= "" then --(force or not ResourceEditor.previousItems[currentItem.filepath])
			ResourceEditor.previousItems[currentItem.filepath] = currentItem
			if EMV.insert_if_unique(ResourceEditor.recentFiles, ((currentItem.filepath:match("^.+" .. nativesFolderType .. "\\(.+)$") or currentItem.filepath) .. numberExt)) then
				ResourceEditor.recentItemIdx = #ResourceEditor.recentFiles
			end
			json.dump_file("rsz\\recent_files.json", ResourceEditor.recentFiles)
			if not noPrompt then
				re.msg("Opened File: " .. currentItem.filepath)
			end
			return true
		else
			re.msg("File not found!")
		end
	end,
	
	displayInstance = function(self, instance, displayName, parentField, parentFieldListIdx, rszBufferFile)
		
		local copied, pasted, pasted_with_children
		local id = imgui.get_id(parentFieldListIdx or "") .. (displayName or "[Invalid ObjectId]")
		
		local tree_opened = imgui.tree_node_str_id(id, displayName or "")
		if imgui.begin_popup_context_item(displayName) then  
			copied = imgui.menu_item("Copy")
			pasted = copyBuffer.instance and imgui.menu_item("Paste" .. (shift_key_down and " after" or ""))
			pasted_with_children = copyBuffer.instance and imgui.menu_item("Paste with children after")
			imgui.end_popup() 
		end
		imgui.same_line()
		imgui.text_colored(instance.title or (parentField and parentField.objectIndex and instance.name) or "", 0xFFE0853D)
		
		if tree_opened then 
			--[[if imgui.tree_node("[Lua]") then
				EMV.read_imgui_element(instance)
				imgui.tree_pop()
			end]]
			 
			if parentField then
				local was_changed
				if parentFieldListIdx then --lists
					imgui.push_id(id .. "f")
						if parentField.isNative then
							was_changed = EMV.editable_table_field(parentFieldListIdx, parentField.objectIndex[parentFieldListIdx], parentField.objectIndex, "", {hide_type=true, width=64})==1
							imgui.same_line()
						end
						changed, parentField.objectIndex[parentFieldListIdx] = imgui.combo("ObjectIndex", parentField.objectIndex[parentFieldListIdx], self.instanceNames)
						if changed or was_changed then
							parentField.value[parentFieldListIdx] = (rszBufferFile.rawData[ parentField.objectIndex[parentFieldListIdx] ] and rszBufferFile.rawData[ parentField.objectIndex[parentFieldListIdx] ].sortedTbl) or {}
							parentField.rawField.value[parentFieldListIdx] = parentField.objectIndex[parentFieldListIdx]
						end
					imgui.pop_id()
				else --singles
					was_changed = EMV.editable_table_field("objectIndex", parentField.objectIndex, parentField, "", {hide_type=true, width=64})==1
					imgui.same_line()
					changed, parentField.objectIndex = imgui.combo("ObjectIndex", parentField.objectIndex, self.instanceNames)
					if changed or was_changed then
						parentField.value = (rszBufferFile.rawData[parentField.objectIndex] and rszBufferFile.rawData[parentField.objectIndex].sortedTbl) or {}
						parentField.rawField.value = parentField.objectIndex
					end
				end
				imgui.spacing()
			end
			
			imgui.begin_rect()
				
				if instance.fields and instance.fields[1] then
					
					for f, field in ipairs(instance.fields) do 
						imgui.push_id(field.name .. f)
							
							local rawF = field.rawField or field
							
							if field.count then 
								if imgui.tree_node_colored(field.name, "List [" .. field.fieldTypeName .. "] ", field.name .. " (" .. field.count .. " elements)", 0xFFE0853D) then
								--if imgui.tree_node_str_id(field.name, "List [" .. field.fieldTypeName .. "] " .. field.name .. " (" .. field.count .. " elements)") then
									-- Add/Remove List operations:
									imgui.text("Count: " .. field.count)
									local toInsert, toRemove
									if not field.value[1] and imgui.button("+") then 
										toInsert = 1
									end
									
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
										else
											if rawF.canOpen and rawF.canOpen[e] and not ResourceEditor.previousItems[ rawF.canOpen[e] ] then
												if imgui.button("Open") then 
													RE_Resource.openResource(rawF.canOpen[e])
												end
												imgui.same_line()
											end
											if EMV.editable_table_field(e, element, field.value, e .. ". " .. field.fieldTypeName .. " " .. field.name, {color_text={e .. ". " .. field.fieldTypeName, field.name, nil}})==1 then
												rawF.value[e] = field.value[e]
											end
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
										rawF.value = field.objectIndex or field.value
										field.count = #rawF.value
									end
									imgui.tree_pop()
								end
							elseif field.objectIndex and field.value then
							
								self:displayInstance(field.value, field.fieldTypeName .. " " .. field.name, field, nil, rszBufferFile)
								
							elseif rawF.is4ByteArray and (rawF.LuaTypeName=="Float" or rawF.LuaTypeName=="Int") then
								if #field.value <= 4 then 
									field.vecType = field.vecType or ("Vector" .. #field.value .. "f")
									field.vecValue = field.vecValue or _G[field.vecType].new(table.unpack(field.value))
									changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, (field.LuaTypeName=="Int"), 0.01)
									if changed then 
										field.value = {field.vecValue.x, field.vecValue.y, field.vecValue.z, field.vecValue.w}
										rawF.value = field.value
									end
								elseif imgui.tree_node(field.fieldTypeName .. " " .. field.name) then --OBBs and other unusual sized values
									local increment = (rawF.LuaTypeName=="Float" and 0.01) or 1
									local methodName = "drag_" .. rawF.LuaTypeName:lower()
									for ff, elem in ipairs(field.value) do
										changed, field.value[ff] = imgui[methodName](ff, elem, increment, -10000000, 10000000)
										if changed then
											rawF.value = field.value
										end
									end
									imgui.tree_pop()
								end
							elseif (rawF.fieldTypeName=="Vec4" or rawF.fieldTypeName=="Quaternion" or rawF.fieldTypeName=="Data16") then
								changed, field.value = EMV.show_imgui_vec4(field.value, field.name, false, 0.01)
								if changed then 
									rawF.value = {field.value.x, field.value.y, field.value.z, field.value.w} 
								end
							elseif rawF.fieldTypeName=="Vec3" then
								field.vecValue = field.vecValue or field.value:to_vec3()
								changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, false, 0.01)
								if changed then 
									field.value = field.vecValue:to_vec4() 
									rawF.value = {field.vecValue.x, field.vecValue.y, field.vecValue.z, field.vecValue.w}
								end
							elseif rawF.fieldTypeName=="Vec2" then
								field.vecValue = field.vecValue or field.value:to_vec2()
								changed, field.vecValue = EMV.show_imgui_vec4(field.vecValue, field.name, false, 0.01)
								if changed then 
									field.value = field.vecValue:to_vec4() 
									rawF.value = {field.vecValue.x, field.vecValue.y, field.vecValue.z, field.vecValue.w}
								end
							else
								if rawF.canOpen and not ResourceEditor.previousItems[rawF.canOpen] then
									if imgui.button("Open") then 
										RE_Resource.openResource(rawF.canOpen)
									end
									imgui.same_line()
								end
								if EMV.editable_table_field("value", field.value, field, field.fieldTypeName .. " " .. field.name, {color_text={field.fieldTypeName, field.name, nil}})==1 then --hide_type=true
									if type(field.value)=="string" and field.value:find("/") and not EMV.find_index(rszBufferFile.owner.resourceInfos or {}, field.value, "resourcePath") then
										table.insert(rszBufferFile.owner.resourceInfos, {name=field.value, resourcePath=field.value})
									end
									rawF.value = (type(field.value)=="boolean" and bool_to_number[field.value]) or field.value
								end
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
		
		if copied then
			copyBuffer.instance = instance.rawDataTbl or instance
		end
		

		
		if pasted or pasted_with_children then
			
			local function find_child_instances(sorted_instance)
				local children = {}
				for i, value in ipairs(sorted_instance.fields) do
					local values = (value.count and value.value) or {value.value}
					local objIDs = (value.objectIndex and value.count and value.objectIndex) or {value.objectIndex}
					for j, field_value in ipairs(values) do
						if not children[objIDs[j] ] and type(field_value) == "table" and field_value.fields then
							children[objIDs[j] ] = field_value.rawDataTbl
							children = EMV.merge_tables(children, find_child_instances(field_value))
						end
					end
				end
				return children
			end
		
			local owner = self.owner or self
			local instance = instance.rawDataTbl or instance
			local newInstance = EMV.merge_tables({}, copyBuffer.instance.rawDataTbl or copyBuffer.instance)
			local isRSZObject = EMV.find_index(rszBufferFile.objectTable, newInstance.index, "instanceId")
			local addAmt = (shift_key_down or pasted_with_children) and 1 or 0
			local uniqueInstances = (pasted_with_children and EMV.merge_tables({[newInstance.index]=newInstance}, find_child_instances(newInstance.sortedTbl))) or {[newInstance.index]=newInstance}
			local newInstances, newTypenames = {}, {}
			for i, instance in pairs(uniqueInstances) do 
				table.insert(newInstances, instance) 
			end
			table.sort(newInstances, function(a, b) return a.index < b.index end)
			for i, instance in ipairs(newInstances) do 
				table.insert(newTypenames, rsz_parser.GetRSZClassName(instance.typeId)) 
			end
			local objectTblInsertPt = rszBufferFile:addInstance(newTypenames, instance.index+addAmt, newInstances, isRSZObject)
			if parentField.count then
				parentField.count = parentField.count + 1
				table.insert(parentField.rawField.value, instance.index + #newInstances)
			end
			local RSZ = self.RSZ or self
			RSZ:writeBuffer()
			RSZ:readBuffer()
			owner:updateSCNObjectIds(objectTblInsertPt, instance.index+addAmt, isRSZObject)
			owner:save(nil, true)
			owner:read()
		end
		
		
		
	end,
	
	updateSCNObjectIds = function(self, objectTblInsertPt, newInstanceInsertIdx)
		
		if self.gameObjectInfos and objectTblInsertPt then
			
			for g, gInfo in ipairs(self.gameObjectInfos or {}) do 
				if gInfo.parentId >= objectTblInsertPt-1 then gInfo.parentId = gInfo.parentId+1 end
				if gInfo.objectId >= objectTblInsertPt-1 then 
					gInfo.objectId = gInfo.objectId+1
				elseif addedComponent==false then 
					for c, component in ipairs(gInfo.gameObject.components) do
						if (gInfo.gameObject.gameobj.rawDataTbl.index+1 >= newInstanceInsertIdx) or (component.rawDataTbl.index+1 >= newInstanceInsertIdx) then
							gInfo.componentCount = gInfo.componentCount + 1
							addedComponent = true
							--re.msg("Added Component to GameObject: " .. gInfo.name .. " " .. newInstanceInsertIdx .. ", " .. objectTblInsertPt)
							break
						end
					end
				end
			end
			
			for f, fInfo in ipairs(self.folderInfos or {}) do 
				if fInfo.objectId >= objectTblInsertPt-1 then fInfo.objectId = fInfo.objectId+1 end
				if fInfo.parentId >= objectTblInsertPt-1 then fInfo.parentId = fInfo.parentId+1 end
			end
			
			for f, pInfo in ipairs(self.prefabInfos or {}) do 
				if pInfo.parentId >= objectTblInsertPt-1 then pInfo.parentId = pInfo.parentId+1 end
			end
			
			for f, grInfo in ipairs(self.gameObjectRefInfos or {}) do 
				if grInfo.objectID >= objectTblInsertPt-1 then grInfo.objectID = grInfo.objectID+1 end
				if grInfo.targetId >= objectTblInsertPt-1 then grInfo.targetId = grInfo.targetId+1 end
			end
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
			
			if EMV.editable_table_field("newTypeName", self.newTypeName, self, label .. " ", {hide_type=true})==1 and sdk.find_type_definition(self.newTypeName) then
				self.newInstanceIdx = (sdk.find_type_definition(self.newTypeName) and EMV.find_index(names_list, self.newTypeName)) or self.newInstanceIdx
				changed = true
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
				
				instanceHolder.newInstanceIsRSZObject = nil
				
				local objectTblInsertPt = rszBufferFile:addInstance(self.newTypeName, self.newInstanceInsertIdx, instanceHolder.newInstance, isRSZObject)
				
				self:updateSCNObjectIds(isRSZObject and objectTblInsertPt, self.newInstanceInsertIdx, isRSZObject)
				
				local RSZ = self.RSZ or self
				RSZ:writeBuffer()
				RSZ:readBuffer()
				self:save(nil, true) --save all data to the buffer
				self:read() --refresh Lua tables from the buffer
				
				self.instanceNames = nil
				self.newInstanceInsertIdxList = nil
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
		
		local function context_menu()
			if imgui.begin_popup_context_item(displayName .. "GO") then  
				
				if imgui.menu_item("Copy") then 
					copyBuffer.gameObject = EMV.deep_copy(gameObject)
					copyBuffer.gameObject.children = {}
					copyBuffer.RSZ = self.RSZ
				end 
				
				if gameObject.children[1] and imgui.menu_item("Copy With Children") then 
					copyBuffer.gameObject = EMV.deep_copy(gameObject)
					copyBuffer.RSZ = self.RSZ
				end 
				
				if copyBuffer.gameObject then 
					--[[if imgui.menu_item("Save Json") then
						json.dump_file("RE_Resources\\Saved\\"..copyBuffer.gameObject.name..".json", EMV.jsonify_table(copyBuffer.gameObject))
					end]]
					
					if imgui.menu_item("Paste") then-- .. (shift_key_down and " after" or "")) then 
						
						local insertionGObj = gameObject
						local thisInfo = insertionGObj.gInfo or insertionGObj.fInfo
						local copyInfo = copyBuffer.gameObject.gInfo or copyBuffer.gameObject.fInfo
						local owner = self.owner or self
						local thisGobjInstanceId = owner.RSZ.objectTable[thisInfo.objectId] and owner.RSZ.objectTable[thisInfo.objectId].instanceId
						local atIdx = #owner.RSZ.rawData+1 --(thisGobjInstanceId and thisGobjInstanceId+1) or 1
						--if shift_key_down then
						--	atIdx = ((owner.gameObjects[insertionGObj.idx+1] and owner.RSZ.objectTable[owner.gameObjects[insertionGObj.idx+1].gInfo.objectId].instanceId) or #owner.RSZ.rawData)+1
						--end
						
						local newInstances = {}
						local newNames = {}
						local newObjects = {}
						local newGInfos = {}
						local newFInfos = {}
						local usedGUIDs = {}
						
						if owner.isSCN then
							for i, gInfo in ipairs(owner.gameObjectInfos) do 
								usedGUIDs[gInfo.guid] = gInfo.guid
							end
						end
						
						local function recurse(go)
							local info = go.gInfo or go.fInfo
							local startIdx = copyBuffer.RSZ.objectTable[info.objectId+1].instanceId
							local compCtr, i = 0, 0
							if info.componentCount  then
								while compCtr <= info.componentCount do
									local newInstance = copyBuffer.RSZ.rawData[startIdx + i]
									i = i + 1
									if newInstance.objectId then 
										table.insert(newObjects, newInstance)
										compCtr = compCtr + 1 
									end
									newNames[#newNames+1] = rsz_parser.GetRSZClassName(newInstance.typeId)
									newInstances[#newInstances+1] = newInstance
								end
							else
								newInstances[1] = copyBuffer.RSZ.rawData[startIdx]
							end
							
							if go.fInfo then 
								table.insert(newFInfos, go.fInfo)
							else
								table.insert(newGInfos, info)
							end
							
							for i, childFolder in ipairs(go.folders or {}) do 
								recurse(childFolder)
							end
							for i, childObj in ipairs(go.children) do 
								recurse(childObj)
							end
						end
						
						recurse(copyBuffer.gameObject)
						
						local objTblDiff = #rszBufferFile.objectTable
						local objectTblInsertPt = rszBufferFile:addInstance(newNames, atIdx, newInstances)
						objTblDiff = #rszBufferFile.objectTable - objTblDiff
						
						--Add missing ResourceInfos
						for rPath, none in pairs(rszBufferFile.newResources) do 
							if not EMV.find_index(self.resourceInfos, rPath, "resourcePath") then
								table.insert(self.resourceInfos, { pathOffset=0, resourcePath = rPath})
							end
						end
						
						--Add missing prefabInfos
						if self.prefabInfos and rszBufferFile.newPrefabs[1] then 
							for i, pInfo in ipairs(rszBufferFile.newPrefabs) do 
								if not EMV.find_index(self.prefabInfos, pInfo.prefabPath, "prefabPath") then 
									table.insert(self.prefabInfos, pInfo)
								end
							end
							for i, pInfo in ipairs(rszBufferFile.newPrefabs) do
								pInfo.parentId = pInfo.parentId or EMV.find_index(self.prefabInfos, pInfo.parentPath, "prefabPath") or -1
							end
						end
						
						--Add missing UserDataInfos: 
						if self.userdataInfos then
							for i, uInfo in ipairs(rszBufferFile.newUserDatas) do 
								if not EMV.find_index(self.userdataInfos, uInfo.path, "userdataPath") then 
									table.insert(self.userdataInfos, {
										typeId = uInfo.typeId,
										CRC = 0,
										pathOffset = 0, 
										userdataPath = uInfo.path,
									})
								end
							end
						end
						
						--Correct original GameObjectInfos:
						local newGInfoInsertPt
						for i, gInfo in ipairs(owner.gameObjectInfos) do 
							if gInfo.objectId >= objectTblInsertPt-1 then 
								newGInfoInsertPt = newGInfoInsertPt or i
								gInfo.objectId = gInfo.objectId + objTblDiff
							end
							if gInfo.parentId >= objectTblInsertPt-1 then 
								gInfo.parentId = gInfo.parentId + objTblDiff
							end
						end
						newGInfoInsertPt = newGInfoInsertPt or #owner.gameObjectInfos+1
						
						--Correct original FolderInfos:
						local newFInfoInsertPt
						if owner.folderInfos then
							for i, fInfo in ipairs(owner.folderInfos) do 
								if fInfo.objectId >= objectTblInsertPt-1 then 
									newFInfoInsertPt = newFInfoInsertPt or i
									fInfo.objectId = fInfo.objectId + objTblDiff
								end
								if fInfo.parentId >= objectTblInsertPt-1 then 
									fInfo.parentId = fInfo.parentId + objTblDiff
								end
							end
							newFInfoInsertPt = newFInfoInsertPt or #owner.folderInfos+1
						end
						
						--Correct original PrefabInfos:
						for i, pInfo in ipairs(owner.prefabInfos or {}) do 
							if pInfo.parentId >= objectTblInsertPt-1 then
								pInfo.parentId = pInfo.parentId + objTblDiff
							end
						end
						
						--Insert new GameObjectInfos:
						for i, newGInfo in ipairs(newGInfos) do 
							local newInstanceId = EMV.find_index(rszBufferFile.newInstances, newGInfo.gameObject.gameobj.rawDataTbl.id, "id")
							newGInfo.objectId = EMV.find_index(rszBufferFile.objectTable, newInstanceId, "instanceId")-1
							--[[if newGInfo.objectId then 
								if not pcall(function()
									log.debug("Found objectId " .. newGInfo.objectId+1 .. " for " .. rszBufferFile.rawData[rszBufferFile.objectTable[newGInfo.objectId+1].instanceId ].title 
									.. " with ID " .. rszBufferFile.rawData[rszBufferFile.objectTable[newGInfo.objectId+1].instanceId ].id .. " matching sourceID " 
									.. newGInfo.gameObject.gameobj.rawDataTbl.id .. " (" .. newGInfo.gameObject.gameobj.rawDataTbl.title .. ")")
								end) then log.debug("Failed to print objectId debug") end
							end]]
							if newGInfo.parentId ~= -1 then 
								local oldParent = copyBuffer.RSZ.rawData[copyBuffer.RSZ.objectTable[newGInfo.parentId+1].instanceId]
								local newParentInstanceId = oldParent and oldParent.id and EMV.find_index(rszBufferFile.newInstances, oldParent.id, "id")
								newGInfo.parentId = (EMV.find_index(rszBufferFile.objectTable, newParentInstanceId, "instanceId") or 0) - 1
								--[[if oldParent and newGInfo.parentId then 
									if not pcall(function()
										log.debug("Found parentId " .. newGInfo.parentId+1 .. " for " .. rszBufferFile.rawData[rszBufferFile.objectTable[newGInfo.parentId+1].instanceId ].title 
										.. " with ID " .. rszBufferFile.rawData[rszBufferFile.objectTable[newGInfo.parentId+1].instanceId ].id .. " matching sourceID " .. oldParent.id .. " (" .. oldParent.title .. ")")
									end) then log.debug("Failed to print parentId debug") end
								end]]
							end
							
							--Find old prefab:
							newGInfo.prefabId = ((self.prefabInfos and newGInfo.prefab and EMV.find_index(self.prefabInfos, newGInfo.prefab.prefabPath, "prefabPath")) or 0) - 1
							
							if not newGInfo.guid or usedGUIDs[newGInfo.guid] or newGInfo.guid == "" then 
								newGInfo.guid = ValueType.new(sdk.find_type_definition("System.Guid")):call("NewGuid()"):call("ToString()"):lower() --randomize GUID
							end
							table.insert(owner.gameObjectInfos, newGInfoInsertPt+i-1, newGInfo)
						end
						
						--Insert new FolderInfos:
						for i, newFInfo in ipairs(newFInfos) do 
							local newInstanceId = EMV.find_index(rszBufferFile.newInstances, newFInfo.folder.instance.rawDataTbl.id, "id")
							--testee = {i, newFInfo, newFInfo.folder.instance.rawDataTbl.id, newInstanceId, EMV.find_index(rszBufferFile.objectTable, newInstanceId, "instanceId"), rszBufferFile.newInstances}
							newFInfo.objectId = EMV.find_index(rszBufferFile.objectTable, newInstanceId, "instanceId")-1
							if newFInfo.parentId ~= -1 then 
								local oldParent = copyBuffer.RSZ.rawData[copyBuffer.RSZ.objectTable[newFInfo.parentId+1].instanceId]
								local newParentInstanceId = oldParent and oldParent.id and EMV.find_index(rszBufferFile.newInstances, oldParent.id, "id")
								newFInfo.parentId = (EMV.find_index(rszBufferFile.objectTable, newParentInstanceId, "instanceId") or 0) - 1
							end
							table.insert(owner.folderInfos, newFInfoInsertPt+i-1, newFInfo)
						end
						
						copyInfo.parentId = thisInfo.parentId
						
						--tester = {copyBuffer.gameObject, rszBufferFile.rawData, objectTblInsertPt, newInstances, newNames, newObjects, newGInfos, newFInfos, tostring(newGInfoInsertPt), tostring(newFInfoInsertPt), owner.gameObjectInfos }
						
						--Flush RSZ buffer:
						rszBufferFile:writeBuffer()
						--rszBufferFile.bs:save("test97.scn")
						rszBufferFile:readBuffer()
						
						--Save SCN/PFB file
						owner:save(nil, true)
						owner:read()
						copyBuffer.gameObject = nil
					end
					--imgui.tooltip("Hold shift to paste after", 0)
				end
				imgui.end_popup() 
			end
		end
	
		if imgui.tree_node(displayName) then 
			
			context_menu()
			
			local gameObjectInfo = gameObject.gInfo or gameObject.fInfo --or {idx=-1} --GameObject or Folder
			
			-- set Gameobject parent:
			if not gameObject.parents_list or not gameObject.imguiParentIdx or self.gameobjTableResetAction then 
				gameObject.parents_list = {}
				local function setupParent(infosList)
					for i, gInfo in ipairs(infosList) do 
						
						--if not (gInfo.gameObject or gInfo.folder) then
						--	self:setupGameObjects()
						--end
						
						local listName = (gInfo==gameObjectInfo and " ") or (gInfo.name .. "[" .. (gInfo.gameObject or gInfo.folder).idx .. "]") or "" --
						local parentGInfo = self.gameObjectInfosIdMap[gInfo.objectId]
						--local isParentOfThis = false
						while parentGInfo and self.gameObjectInfosIdMap[parentGInfo.parentId] and parentGInfo.parentId~=parentGInfo.objectId do 
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
						self:displayInstance(sortedInstance, i .. ". " .. sortedInstance.name, nil, nil, rszBufferFile)
					end

					if gameObject.children and gameObject.children[1] and imgui.tree_node("Children") then
						for c, childObject in ipairs(gameObject.children) do
							self:displayGameObject(childObject, c .. ". " .. childObject.name, rszBufferFile)
						end
						imgui.tree_pop()
					end
					
				imgui.end_rect(2)
				
			elseif gameObject.fInfo then --Folders
				imgui.text("	")
				imgui.same_line()
				imgui.begin_rect()
					self:displayInstance(gameObject.instance, gameObject.instance.name, nil, nil, rszBufferFile) --"via.Folder[" .. gameObject.instance.rawDataTbl.index .. "]"
					if gameObject.children and gameObject.children[1] then
						if gameObject.children and gameObject.children[1] and imgui.tree_node("Children") then
							for c, childFolder in ipairs(gameObject.children) do
								self:displayGameObject(childFolder, c .. ". " .. childFolder.name, rszBufferFile)
							end
							imgui.tree_pop()
						end
					end
				imgui.end_rect(2)
			end
			imgui.tree_pop()
		else
			context_menu()
		end
	end,
	
	-- Displays a RE_Resource in imgui with editable fields, showing only the important structs of the file. Contains special functions for RSZ data
	displayImgui = function(self)
		
		local font_succeeded = pcall(imgui.push_font, utf16_font)
		
		if self.filepath then
			
			if EMV.editable_table_field("filepath", self.filepath, self, "FilePath")==1 then
				self.filepath = self.filepath:lower():gsub("/", "\\")
				if self.filepath:find("%$natives\\") and not self.filepath:find(nativesFolderType) then
					self.filepath = self.filepath:gsub("%$natives\\", "$natives\\" .. nativesFolderType .. "\\")
				end
			end
			
			imgui.tooltip("Access files in the 'REFramework\\data\\' folder.\nStart with '$natives\\' to access files in the natives folder")
			
			if imgui.button("Save") then--imgui.button(((self.isMDF and "Inject") or "Save") .. " File") then
				self:save(self.filepath, nil, true)
			end
			imgui.tooltip("Save to the same filepath, overwriting")
			imgui.same_line()
			
			if imgui.button("Save Copy") then--imgui.button(((self.isMDF and "Inject") or "Save") .. " File") then
				self:save()
			end
			imgui.tooltip("Save to a new filepath")
			imgui.same_line()
			
			local fullExt = self.ext2 .. self.ext
			local backupPath = self.filepath:gsub(fullExt, ".BAK" .. fullExt)
			
			if imgui.button("Backup") then
				if BitStream.copyFile(self.filepath, backupPath) and BitStream.checkFileExists(backupPath) then 
					re.msg("Backed up to " .. backupPath)
				end
			end
			imgui.tooltip("Make a backup copy of this file")
			imgui.same_line()
			
			if imgui.button("Restore") and BitStream.checkFileExists(backupPath) then
				if BitStream.copyFile(backupPath, self.filepath) then
					re.msg("Restored from " .. backupPath)
					RE_Resource.openResource(self.filepath, true)
				end
			end
			imgui.tooltip("Restore this file from an existing backup")
			imgui.same_line()
			
			if imgui.button("Revert") then
				re.msg("Reloaded from " .. self.filepath)
				RE_Resource.openResource(self.filepath, true)
			end
			imgui.tooltip("Reload this file from disk")
			imgui.same_line()
			
			if imgui.button("Refresh Buffer") then
				self:save(nil, true)
				self:read()
			end
			imgui.tooltip("Update the file's internal buffer and refresh Lua data")
			
			--[[if self.backup then
				if not imgui.same_line() and imgui.button("Undo") then
					self.bs = self.backup
					self:save(nil, true)
					self:read()
				end
				imgui.tooltip("Revert the file to its previous state")
			end]]
			
			if spawn_pfb and self.isPFB and not imgui.same_line() and imgui.button("Spawn PFB") then 
				local path = "$natives\\"..nativesFolderType.."\\RE_Resource\\temp.pfb"..PFBFile.extensions[game_name]--self.filepath:match("^(.+)%."):gsub(".pfb", "") .. ".NEW.pfb"
				if self.saveAsPFB then
					self:saveAsPFB(path, true)
				else
					self:save(path, nil, nil, true)
				end
				if BitStream.checkFileExists(path) then
					spawn_pfb("RE_Resource/temp.pfb")
				end
			end
			
			if self.saveAsPFB and not imgui.same_line() and imgui.button("Save as PFB") then
				local path = self.filepath:match("^(.+)%.") .. ".NEW.pfb" .. PFBFile.extensions[game_name]
				self:saveAsPFB(path:gsub("%.scn", ""), false)
			end
			
			if self.saveAsSCN and not imgui.same_line() and imgui.button("Save as SCN") then
				local path = self.filepath:match("^(.+)%.") .. ".NEW.scn" .. SCNFile.extensions[game_name]
				self:saveAsSCN(path:gsub("%.pfb", ""))
			end
			
			--test stuff to change RE2 RSZ to RE3 and back
			if re23ConvertJsonPath and not imgui.same_line() and imgui.button("Save as " .. (isRE2 and "RE3" or "RE2")) then
				
				if not re23ConvertJson then
					local json = json.load_file(re23ConvertJsonPath)
					re23ConvertJson = {}
					for hash, tbl in pairs(json) do
						tbl.hash = hash
						re23ConvertJson[tbl.name] = tbl
					end
				end
				
				local oldInstanceInfos = self.RSZ.instanceInfos
				local oldRSZUserDataInfos = self.RSZ.RSZUserDataInfos
				local oldUserdataInfos = self.userdataInfos
				local oldRawData = self.RSZ.rawData
				local newInstanceInfos = EMV.deep_copy(self.RSZ.instanceInfos)
				local newRSZUserDataInfos = EMV.deep_copy(self.RSZ.RSZUserDataInfos)
				local newUserdataInfos = self.userdataInfos and EMV.deep_copy(self.userdataInfos)
				local newRawData = EMV.deep_copy(self.RSZ.rawData, 2)
				--goto exit
				rsz_parser.ParseJson("reframework\\data\\rsz\\rsz" .. (isRE2 and "re3" or "re2") .. rt_suffix .. ".json")
				
				for i, instanceInfo in ipairs(newInstanceInfos) do
					local otherGameInstance = re23ConvertJson[instanceInfo.name:gsub("app.ropeway", "offline")]
					if not otherGameInstance then
						re.msg("Failed to Convert: \n" .. instanceInfo.name:gsub("app.ropeway", "offline") .. "\n not found in " .. (isRE2 and "RE3" or "RE2") .. " JSON!")
						goto exit
					else
						local rszUserDataInfoIdx = EMV.find_index(self.RSZ.RSZUserDataInfos, i, "instanceId")
						if rszUserDataInfoIdx then
							newRSZUserDataInfos[rszUserDataInfoIdx].typeId = tonumber("0x"..otherGameInstance.hash)
							local newUserdataInfoIdx = newUserdataInfos and EMV.find_index(newUserdataInfos, newRSZUserDataInfos[rszUserDataInfoIdx].path, "userdataPath")
							if newUserdataInfoIdx then 
								newUserdataInfos[newUserdataInfoIdx].typeId = tonumber("0x"..otherGameInstance.hash)
							end
						end
						instanceInfo.name = otherGameInstance.name
						instanceInfo.typeId = tonumber("0x"..otherGameInstance.hash)
						instanceInfo.CRC = tonumber("0x"..otherGameInstance.crc)
						local oldInstance, newInstance = self.RSZ.rawData[i], newRawData[i]
						newInstance.fields = {}
						for f, fieldTbl in ipairs(otherGameInstance.fields) do
							local idx = EMV.find_index(oldInstance.fields, fieldTbl.name, "name")
							if idx then
								table.insert(newInstance.fields, oldInstance.fields[idx])
							else
								table.insert(newInstance.fields, self.RSZ:makeFieldTable(instanceInfo.typeId, f-1, true))
							end
						end
					end
				end
				
				self.RSZ.instanceInfos = newInstanceInfos
				self.RSZ.RSZUserDataInfos = newRSZUserDataInfos
				self.userdataInfos = newUserdataInfos
				self.RSZ.rawData = newRawData
				self:save()
				self.RSZ.instanceInfos = oldInstanceInfos
				self.RSZ.RSZUserDataInfos = oldRSZUserDataInfos
				self.userdataInfos = oldUserdataInfos
				self.RSZ.rawData = oldRawData
				
				::exit::
				rsz_parser.ParseJson("reframework\\data\\rsz\\rsz" .. (isRE2 and "re2" or "re3") .. rt_suffix .. ".json")
			end
			
			imgui.same_line()
			if imgui.tree_node_str_id(self.filepath, "[Lua]") then 
				EMV.read_imgui_element(self)
				imgui.tree_pop()
			end
			imgui.tooltip("View debug information")
		end
		

		
		displayStruct = function(s, struct, structPrototype, structName, doExpand)
			local function contextMenu()
				if imgui.begin_popup_context_item(structName .. s) then 
					if imgui.menu_item("Copy data") then 
						copyBuffer.structData = EMV.deep_copy(struct)
					end
					if copyBuffer.structData and imgui.menu_item("Paste data") then 
						for key, value in pairs(struct) do
							if copyBuffer.structData[key] ~= nil then
								struct[key] = copyBuffer.structData[key]
							end
						end
					end 
					imgui.end_popup() 
				end
			end
			local doExpand = doExpand or (#structPrototype == 1)
			if doExpand or imgui.tree_node(s .. ". " .. (struct.name or "")) then
				imgui.begin_rect()
				imgui.push_id(s .. "Struct")
				for f, fieldTbl in ipairs(structPrototype) do
					local key = (fieldTbl[3] and fieldTbl[3][2]) or fieldTbl[2]
					--imgui.text(structName .. ", " .. key .. ", " .. tostring(struct[key]))
					if type(key)=="string" and not key:find("Offset$") then
						EMV.editable_table_field(key, struct[key], struct, ((doExpand and s .. ".") or "") .. key)
						contextMenu()
					end
				end
				if self.customStructDisplayFunction then 
					self:customStructDisplayFunction(struct, s)
				end
				imgui.pop_id()
				imgui.end_rect(2)
				if not doExpand then imgui.tree_pop() end
			end
			contextMenu()
		end
		
		displayStructList = function(structList, structPrototype, structName)
			
			local toRemoveIdx, toAddIdx
			for s, struct in ipairs(structList or {}) do
				--[[if imgui.tree_node(struct.name .. " Lua") then
					EMV.read_imgui_element({struct, structList, structPrototype, structName})
					imgui.tree_pop()
				end]]
				if type(struct[1])=="table" then
					if imgui.tree_node(s .. ". " .. struct.name) then
						displayStructList(struct, structPrototype, structName)
						imgui.tree_pop()
					end
				else
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
					displayStruct(s, struct, structPrototype, structName)
				end
			end
			
			if toRemoveIdx then 
				table.remove(structList, toRemoveIdx)
				--[[if structName == "instanceInfo" then
					table.remove(self.rawData, toRemoveIdx)
					--self:updateSCNObjectIds(nil, toRemoveIdx, -1)
				end]]
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
		
		local RSZ = self.RSZ or (self.isRSZ and self)
		
		if not RSZ or imgui.tree_node("Infos") then
			for i, structName in ipairs(self.structs.structOrder) do 
				local structPrototype = self.structs[structName]
				local pluralName = (self[structName] and structName) or structName.."s"
				
				if pluralName and self[pluralName] and imgui.tree_node(pluralName) then
					
					if pluralName==structName and structName ~= "objectTable" then
						displayStruct(pluralName, self[pluralName], structPrototype, structName, true)
					else
						local thisInfos, isList = self[pluralName], false
						displayStructList(thisInfos, structPrototype, structName)
					end
					imgui.tree_pop()
				end
			end
			if RSZ then 
				imgui.tree_pop()
			end
		end
		
		if RSZ then
			
			if not self.instanceNames or #self.instanceNames ~= #RSZ.instanceInfos then 
				self.instanceNames = {[0]=" "}
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
						self:displayGameObject(folder, i .. ". " .. (folder.Name or folder.name or ""), RSZ)
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
						self:displayInstance(object, i-1 .. ". " .. object.name, nil, nil, RSZ)
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
		o = RE_Resource:newResource(args, setmetatable(o, self))
		o.startOf = args.startOf
		o.bs.alignShift = o.bs:getAlignedOffset(16, o.startOf) - o.startOf
		o.owner = args.owner
		
		if o.bs:fileSize() > 0 then
			if o:readBuffer() then
				o:writeBuffer()
			end
		end
		
		o.save = o.writeBuffer
		o.read = o.readBuffer
		o:seek(0)
		
		--o.bs.file:close()
		return o
	end,
	
	-- Recreates the RSZ file buffer using data from owned Lua tables
	writeBuffer = function(self)
		
		local bs = BitStream:new()
		if not bs then return re.msg("Failed to create tmpfile") end
		self.bs = bs
		
		bs:writeBytes(self.structSizes["header"])
		for i, objectTblObj in ipairs(self.objectTable) do
			bs:writeInt(objectTblObj.instanceId)
		end 
		
		self.header.instanceOffset = self:tell()
		self:writeStruct("instanceInfo", self.instanceInfos[0])
		for i, instanceInfo in ipairs(self.instanceInfos) do
			self:writeStruct("instanceInfo", instanceInfo)
		end 
		
		bs:align(16)
		--log.info("Pos " .. bs:tell() .. ", " .. (bs:tell()%16))
		self.header.userdataOffset = bs:tell()
		for i, RSZUserDataInfo in ipairs(self.RSZUserDataInfos) do
			self:writeStruct("RSZUserDataInfo", RSZUserDataInfo)
		end
		
		bs:align(16)
		for i, wstringTbl in ipairs(self.stringsToWrite or {}) do
			bs:writeUInt64(bs:tell(), wstringTbl.offset)
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
				bs:writeInt(RSZUserDataInfo.RSZData:fileSize(), RSZUserDataInfo.startOf+12) 
				bs:writeUInt64(RSZUserDataInfo.RSZOffset, RSZUserDataInfo.startOf+16)
			end
		end
		
		bs:align(16)
		self.header.dataOffset = bs:tell()
		
		for i, instance in ipairs(self.rawData) do
			if not instance.userdataFile then 
				for f, field in ipairs(instance.fields or {}) do 
					self:writeRSZField(field)
				end
			end
		end 
		log.info("finished writing fields")
		
		self.header.objectCount = #self.objectTable
		self.header.instanceCount = #self.instanceInfos+1
		self.header.userdataCount = #self.RSZUserDataInfos
		self:seek(0)
		self:writeStruct("header", self.header)
		self.bs:seek(0)
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
			if self.instanceInfos[i].name == "Unknown Class!" and i > 0 then
				re.msg("TypeId not found: " .. self.instanceInfos[i].typeId)
				return false
			end
		end
		
		if tdb_ver <= 67 then
			for i, rInfo in ipairs(self.RSZUserDataInfos or {}) do
				if rInfo.RSZData then rInfo.RSZData.bs:close() end
			end
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
				self:seek(rszInfo.RSZOffset)
				rszInfo.RSZData = RSZFile:new({file=self.bs:extractStream(), startOf=rszInfo.RSZOffset + self.startOf, owner=self})
			end
		end
		
		if not noRawData then
			self:seek(self.header.dataOffset)
			self.rawData = { [0]={} }
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
					instance.RSZUserData = (not isOldVer and self.RSZUserDataInfos[instance.RSZUserDataIdx]) or self.RSZUserDataInfos[instance.RSZUserDataIdx]
					instance.userdataFile = instance.RSZUserData and (instance.RSZUserData.path or instance.RSZUserData.RSZData) or nil
				else
					instance.fields = {}
					for index=1, instance.fieldCount do 
						if self.bs:tell() > self.bs:fileSize() then 
							--self.bs:save("test92.scn")
							re.msg("Buffer overflow!")
							goto exit
						end
						local field = self:readRSZField(typeId, index-1)
						if index == 1 then 
							instance.startOf = field.startOf or instance.startOf 
						end
						table.insert(instance.fields, field)
					end
					::exit::
					instance.sizeOf = self:tell() - instance.startOf
				end
				--log.debug("Read instance " .. logv(instance))
				instance.id = imgui.get_id(tostring(instance))
				self.rawData[i] = instance
			end
			--self.bs:seek(0)
			--self.bs = BitStream:new(self.bs:extractStream())
			
			for i, rd in ipairs(self.rawData) do
				rd.sortedTbl = self:sortRSZInstance(rd)
			end
			
			self.objects = {}
			self.objectTable.names = {}
			for i, objectIndexTbl in ipairs(self.objectTable) do
				self.objects[i] = self.rawData[objectIndexTbl.instanceId].sortedTbl
				self.objects[i].rawDataTbl.objectId = i-1
				self.objectTable.names[i] = self.objects[i].name .. ((self.objects[i].title and " (" .. self.objects[i].title .. ")") or "")
			end
			
			self.objectTable.names[#self.objectTable.names+1] = " "
		end
		return true
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
		
		sortedField.objectIndex = field.fieldTypeName=="Object" or (field.isNative and (field.LuaTypeName=="Int" and type(fieldValue)=="number") and (fieldValue < instance.index) and (fieldValue > instance.index - 101) and (fieldValue > 3)) or nil
		if sortedField.objectIndex then 
			sortedField.fieldTypeName = "Data4 (Object?)" 
			field.fieldTypeName = sortedField.fieldTypeName 
		end
		sortedField.objectIndex = sortedField.objectIndex or (self.rawData[sortedField.value]~=nil and (field.fieldTypeName=="Object") or (field.fieldTypeName=="UserData")) or nil
		
		if field.isList then 
			sortedField.objectIndex = sortedField.objectIndex and EMV.deep_copy(field.value)
			for e, element in ipairs(sortedField.value) do
				sortField(field, sortedField, e)
			end
		else
			sortField(field, sortedField)
		end
		
		--log.debug("Sorted Field " .. field.name)
		
		if not instance.title then 
			if type(field.value)=="string" and field.value:len() > 1 then --field.fieldTypeName=="String" and
				instance.title = field.value
			end
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
		sortedInstance.title = instance.title
		
		return setmetatable(sortedInstance, {name=instance.name})
	end,
	
	-- Writes a RSZ field with proper alignment from a Lua field table in rawData
	writeRSZField = function(self, field, bs)
		bs = bs or self.bs
		
		--field.elementSize = RE_Resource.typeNamesToSizes[field.fieldTypeName] or field.elementSize
		
		local function writeFieldValue(value)
			local absStart = self.bs:getAlignedOffset(((field.isList and 4) or field.alignment), self:tell() + self.startOf)
			local pos = bs:tell()
			--log.info("Writing  " .. field.name .. " value " .. tostring(value) .. " at " .. pos .. " using " .. ("write" .. field.LuaTypeName) .. ", elemSize: " .. field.elementSize) 
			if field.is4ByteArray then
				bs:writeArray(value, field.LuaTypeName)
			elseif field.LuaTypeName == "WString" then 
				if value:len() <= 1 then
					bs:writeUInt(value:len())
					if value == " " then
						bs:writeUShort(0)
					elseif value:len() == 1 then
						bs:writeUShort(string.byte(value))
					end
				else
					--log.info("writing string " .. value .. " @ " .. self.startOf+bs:tell() .. " " .. value:len()+1)
					bs:writeUInt(getWStringSize(value)) --value:len()+1
					bs:writeWString(value)
				end
			elseif field.LuaTypeName == "OBB" then
				bs:writeArray(value, "<f")
			else
				last = {field, value}
				bs["write" .. field.LuaTypeName](bs, value)
			end
			--log.info("wrote field")
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
		
		--fieldTbl.startOf =  self.bs:getAlignedOffset(((fieldTbl.isList and 4) or fieldTbl.alignment), self:tell())
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
						self:checkOpenResource(fieldTbl.value[i], fieldTbl)
					end
				end
			end
		else
			
			local startPos = self:tell()
			if fieldTbl.is4ByteArray then
				fieldTbl.value = self.bs:readArray(math.floor(fieldTbl.elementSize / 4), fieldTbl.LuaTypeName, self:tell(), true)
			elseif fieldTbl.LuaTypeName == "WString" then 
				self.charCount = self.bs:readUInt()
				local pos = self:tell()
				fieldTbl.value = ''
				
				if self.bs:readUByte(pos+1) ~= 0 then 
					log.info("Broken string at " .. pos )--.. " " .. EMV.logv(fieldTbl))
				end
				
				--last = {fieldTbl, typeId, index, parentListField, pos, self}
				
				if self.charCount > 0 then --and self.bs:readUShort(pos) > 0
					fieldTbl.value = self.bs:readWString(pos)
					if self.charCount == 1 and self.bs:readUShort(pos) == 0 then
						fieldTbl.value = " "
					end
					--log.info("read wstring " .. fieldTbl.value .. " @ position " .. pos .. ", " .. self.charCount .. " chars")
				end
				
				self:checkOpenResource(fieldTbl.value, fieldTbl)
				self:seek(pos + self.charCount * 2)
				
			elseif fieldTbl.LuaTypeName then 
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
			local json_dump = json.load_file("rsz\\rsz"..game_name..rt_suffix..".json")
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
		
		if not fieldTbl.LuaTypeName then 
			fieldTbl.LuaTypeName = self.sizesToTypeNames[fieldTbl.elementSize]
			if fieldTbl.elementSize == 64 then 
				fieldTbl.LuaTypeName = "Mat4"
			elseif fieldTbl.elementSize == 16 then 
				if fieldTbl.alignment == 8 then fieldTbl.LuaTypeName = "GUID" else fieldTbl.LuaTypeName = "Vec4" end
			elseif fieldTbl.elementSize == 8 then
				if fieldTbl.alignment == 8 then fieldTbl.LuaTypeName = "Int64" else fieldTbl.LuaTypeName = "Vec2" end
			elseif fieldTbl.elementSize == 4 or fieldTbl.elementSize % 4 == 0 then
				local tell = self.bs:tell()
				local listCount = fieldTbl.isList and self.bs:readInt(tell)
				local countSize = (listCount and 4) or 0
				fieldTbl.LuaTypeName = (tell+4+countSize <= self:fileSize() and (not listCount or (listCount > 0 and listCount < 2500)) and self.bs:detectedFloat(tell+countSize) and fieldTbl.fieldTypeName ~= "Color" and "Float") or "Int"
				fieldTbl.is4ByteArray = (fieldTbl.elementSize > 4) or nil
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
	
	addInstance = function(self, typeNames, atIndex, newInstances, gameObjObjectId)
		
		local objectTblInsertPt
		atIndex = atIndex or #self.instanceInfos+1
		if type(typeNames) ~= "table" then typeNames = {typeNames} end
		if type(newInstances) ~= "table" or not newInstances[1] then newInstances = {newInstances} end
		newInstances[1] = newInstances[1] or (typeNames[1] and self:createInstance(typeNames[1], atIndex))
		newInstances = EMV.deep_copy(newInstances) --purge all references
		
		local addAmt = #newInstances --0
		--for i, newInstance in ipairs(newInstances) do 
		--	if gameObjObjectId or newInstance.objectId then addAmt = addAmt + 1 end 
		--end
		
		for i, objectTblObj in ipairs(self.objectTable) do 
			if objectTblObj.instanceId >= atIndex then 
				objectTblInsertPt = objectTblInsertPt or i
				objectTblObj.instanceId = objectTblObj.instanceId + addAmt
			end
		end
		
		objectTblInsertPt = objectTblInsertPt or #self.objectTable + 1
		
		--Correct ObjectIds in target file:
		for i, instance in ipairs(self.rawData) do
			for f, field in ipairs(instance.fields or {}) do 
				if field.fieldTypeName:find("Object%??[^R]") then --or field.fieldTypeName == "UserData" then 
					if type(field.value)=="table" then --lists of objects
						for o, objId in ipairs(field.value) do
							if objId >= atIndex then 
								field.value[o] = field.value[o] + addAmt
							end
						end
					else
						if field.value >= atIndex then
							field.value = field.value + addAmt --correct objectIds in RSZ
						end
					end
				end
			end
		end
		
		for i, RSZUserDataInfo in ipairs(self.RSZUserDataInfos) do
			if RSZUserDataInfo.instanceId >= atIndex then 
				RSZUserDataInfo.instanceId = RSZUserDataInfo.instanceId + addAmt
			end
		end
		
		self.newResources = {}
		self.newInstances = {}
		self.newPrefabs = {}
		self.newUserDatas = {}
		
		for i, instance in ipairs(self.rawData) do 
			table.insert(self.newInstances, {}) --create a fake newInstances holder to search-through for imguiIDs (while ignoring target file's imguiIDs)
		end
		
		for i, newInstance in ipairs(newInstances) do
			local typeId = newInstance.typeId or RSZFile.json_dump_map[ newInstance.name:match("^(.-)%[") or typeNames[1] ]
			if typeId then
				table.insert(self.instanceInfos, atIndex+i-1, { typeId=typeId, CRC=tonumber("0x"..rsz_parser.GetRSZClassCRC(typeId)), })
				table.insert(self.rawData, atIndex+i-1, newInstance)
				table.insert(self.newInstances, atIndex+i-1, newInstance)
			end
		end
		
		local function addRSZUserData(instance, instanceId)
			local newRSZUData = EMV.merge_tables({}, instance.RSZUserData)
			newRSZUData.instanceId = instanceId
			table.insert(self.RSZUserDataInfos, newRSZUData)
			table.insert(self.newUserDatas, newRSZUData)
		end
		
		--Correct ObjectIDs in copied instances to point to their new ObjectIndexes:
		for i, instance in ipairs(self.newInstances) do
			for f, sfield in ipairs((instance.sortedTbl and instance.sortedTbl.fields) or {}) do
				local field = sfield.rawField
				local isUserData = (sfield.fieldTypeName == "UserData")
				if isUserData or sfield.fieldTypeName:find("Object%??[^R]") then
					if type(field.value)=="table" then
						for o, objId in ipairs(field.value) do
							field.value[o] = EMV.find_index(self.newInstances, objId, "index") or 0
							if isUserData then addRSZUserData(self.newInstances[ field.value[o] ], field.value[o]) end
						end
					else
						field.value = EMV.find_index(self.newInstances, field.value, "index") or 0
						if isUserData and field.value ~= 0 then addRSZUserData(self.newInstances[field.value], field.value) end
					end
				elseif field.isResource then 
					if type(field.value)=="table" then
						for l, listItem in ipairs(field.value) do self.newResources[listItem] = true end
					else
						self.newResources[field.value] = true
					end
				end
				instance.fields[f] = field
				
				if type(field.value)=="string" and field.value:find("/") and not EMV.find_index(self.owner.resourceInfos or {}, field.value, "resourcePath") then
					table.insert(self.owner.resourceInfos, {name=field.value, resourcePath=field.value})
				end
			end
		end
		
		local objectsAdded = 0
		local toAddRSZUDidx = nil
		
		for i, newInstance in ipairs(newInstances) do 
			
			local typeName = newInstance.name:match("^(.-)%[") or typeNames[1]
			local typedef = sdk.find_type_definition(typeName)
			local typeId = newInstance.typeId or RSZFile.json_dump_map[typeName]
			
			if typeId and typedef then
				if gameObjObjectId or newInstance.objectId then
					table.insert(self.objectTable, objectTblInsertPt+objectsAdded, { instanceId=atIndex+i-1 })
					objectsAdded = objectsAdded + 1
				end
			end
			
			--Prepare new prefabInfos:
			if newInstance.gInfo and newInstance.gInfo.prefab then 
				self.newPrefabs[#self.newPrefabs+1] = EMV.deep_copy(newInstance.gInfo.prefab)
			end
		end
		
		self.startOf = self.bs:getAlignedOffset(16, self.startOf) --make sure every RSZ buffer written is 16 bytes aligned, and every container file
		self.instanceNames = nil
		
		return objectTblInsertPt
	end,
	
	customStructDisplayFunction = function(self, struct)
		if struct.RSZData and imgui.tree_node("RSZ Data") then 
			struct.RSZData:displayImgui()
			imgui.tree_pop()
		elseif next(struct)=="instanceId" then --objectTable
			changed, struct.instanceId = imgui.combo("Instance", struct.instanceId, self.instanceNames)
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
			{"UInt", "instanceId"},
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
		re4 = ".20",
		re8 = ".20",
		re7 = ((tdb_ver==49) and ".18") or ".20",
		dmc5 =".19",
		mhrise = ".20",
		sf6 = ".20",
	},
	
	isSCN = true,
	
	ext2 = ".scn",

	-- Creates a new RE_Resource SCNFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
			self.resourceInfos[i].name = tostring(self.resourceInfos[i].resourcePath)
		end
		
		self:seek(self.header.prefabInfoOffset)
		self.prefabInfos = {}
		for i = 1, self.header.prefabCount do 
			self.prefabInfos[i] = self:readStruct("prefabInfo")
			self.prefabInfos[i].name = tostring(self.prefabInfos[i].prefabPath)
			self.prefabInfos[i].parentPath = self.prefabInfos[self.prefabInfos[i].parentId] and self.prefabInfos[self.prefabInfos[i].parentId].prefabPath
		end
		
		self:seek(self.header.userdataInfoOffset)
		self.userdataInfos = {}
		for i = 1, self.header.userdataCount do 
			self.userdataInfos[i] = self:readStruct("userdataInfo")
			self.userdataInfos[i].name = rsz_parser.GetRSZClassName(self.userdataInfos[i].typeId) .. " - " .. self.userdataInfos[i].userdataPath
		end
		
		self:seek(self.header.dataOffset)
		if self.RSZ then self.RSZ.bs:close() end
		local stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset, owner=self})
		
		if self.RSZ.objectTable then
			self:setupGameObjects()
		end
		
		--self.RSZ.bs:save("test93.scn")
	end,
	
	-- Updates the SCNFile and RSZFile bitstreams from data in owned Lua tables and saves the result to a new file
	save = function(self, filepath, onlyUpdateBuffer, doOverwrite, noPrompt)
		
		if not doOverwrite and (not filepath or filepath == self.filepath) then 
			filepath = (filepath or self.filepath):gsub("%.scn", ".NEW.scn")
		end
		filepath = filepath or self.filepath
		
		self.bs = BitStream:new()
		self.bs.filepath = onlyUpdateBuffer and self.filepath or filepath
		self.bs.fileExists = BitStream.checkFileExists(filepath)
		
		self.bs:writeBytes(64) --header
		
		for i, gameObjectInfo in ipairs(self.gameObjectInfos) do
			self:writeStruct("gameObjectInfo", gameObjectInfo)
			if self.isPFB then 
				self.bs:writeInt(-1, gameObjectInfo.startOf+28)
			end
		end
		
		if self.folderInfos then --and self.folderInfos[1] then
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
		
		if self.prefabInfos then --and self.prefabInfos[1] then
			self.bs:align(16)
			self.header.prefabInfoOffset = self:tell()
			for i, prefabInfo in ipairs(self.prefabInfos or {}) do
				self:writeStruct("prefabInfo", prefabInfo)
			end
		end
		
		if self.userdataInfos then-- and self.userdataInfos[1] then
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
		self.header.userdataCount = self.userdataInfos and #self.userdataInfos
		self:writeStruct("header", self.header)
		
		self:seek(self.header.dataOffset)
		self.RSZ.startOfs = self.header.dataOffset
		
		self.RSZ:writeBuffer()
		
		self.bs:writeBytes(self.RSZ.bs:getBuffer())
		
		
		--self.backup = self.bs
		
		if not onlyUpdateBuffer then
			self.bs:save(filepath)
			if not noPrompt then re.msg("Saved to " .. filepath) end
			ResourceEditor.textBox = filepath
		end
		--self.RSZ.bs:save("test94.scn")
	end,
	
	saveAsPFB = function(self, filepath, noPrompt)
		--if self.folders and self.folders[1] then 
			--re.msg("Cannot convert a file with via.Folders!")
			--return nil
		--end
		self.structs = PFBFile.structs
		self.header.magic = 4343376 --"PFB"
		PFBFile.save(self, filepath, nil, nil, noPrompt)
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
					instance = self.RSZ.rawData[ self.RSZ.objectTable[info.objectId+1].instanceId ].sortedTbl,
					idx = i,
				}
				info.folder.name = tostring(info.folder.instance.name)
				info.folder.Name = tostring(info.folder.instance.fields[1].value)
				info.name =  info.folder.name
				
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
				gameobj = self.RSZ.rawData[ self.RSZ.objectTable[info.objectId+1].instanceId ].sortedTbl, 
				--parentObj = self.RSZ.rawData[ self.RSZ.objectTable[info.parentId+1].instanceId ].sortedTbl,
				components = {}, 
				children = {}, 
				idx = i, 
				gInfo=info 
			}
			for j=info.objectId + 2, (info.objectId + info.componentCount + 1) do
				--testee = {gameObject.components, self.RSZ.rawData, j, self.RSZ.objectTable, self.RSZ.objectTable[j]}
				table.insert(gameObject.components, self.RSZ.rawData[ self.RSZ.objectTable[j].instanceId ].sortedTbl) --
			end
			
			info.prefab = info.prefabId and info.prefabId >= 0 and self.prefabInfos[info.prefabId+1]
			gameObject.gameobj.rawDataTbl.gInfo = info
			gameObjParentMap[info.objectId] = gameObject
			info.gameObject = gameObject
			
			if info.parentId == -1 then
				table.insert(self.gameObjects, gameObject)
			end
			info.name = tostring(gameObject.gameobj.fields[1].value) --(type(gameObject.gameobj.fields[1].value)=="string" and gameObject.gameobj.fields[1].value) or info.name or ""
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
				changed, struct.newObjectId = imgui.combo("Object Instance", struct.newObjectId or struct.objectId+1, self.RSZ.objectTable.names) -- EMV.find_index(self.RSZ.objectTable, self.objectId, "instanceId")
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
		re4 = ".17",
		re8 = ".17",
		re7 = ((tdb_ver==49) and ".16") or ".17",
		dmc5 =".16",
		mhrise = ".17",
		sf6 = ".17",
	},
	
	isPFB = true,
	
	ext2 = ".pfb",

	-- Creates a new RE_Resource PFBFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
		
		self:seek(self.header.gameObjectRefInfoOffset)
		self.gameObjectRefInfos = {}
		for i = 1, self.header.gameObjectRefInfoCount or 0 do 
			self.gameObjectRefInfos[i] = self:readStruct("gameObjectRefInfo")
		end
		
		self:seek(self.header.resourceInfoOffset)
		self.resourceInfos = {}
		for i = 1, self.header.resourceCount do 
			self.resourceInfos[i] = self:readStruct("resourceInfo")
			self.resourceInfos[i].name = tostring(self.resourceInfos[i].resourcePath)
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
		if self.RSZ then self.RSZ.bs:close() end
		local stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset, owner=self})
		
		if self.RSZ.objectTable then
			SCNFile.setupGameObjects(self)
		end
		
		for i, gRefInfo in ipairs(self.gameObjectRefInfos) do
			--pcall(function()
				gRefInfo.name = self.RSZ.objectTable.names[gRefInfo.objectID+1] .. "  ...  " .. self.RSZ.objectTable.names[gRefInfo.targetId+1]
			--end)
		end
		--self.RSZ.bs:save("test93.pfb")
	end,
	
	-- Updates the PFBFile and RSZFile BitStreams with data from owned Lua tables, and saves the result to a new file
	save = function(self, filepath, onlyUpdateBuffer, doOverwrite, noPrompt)
		
		if not doOverwrite and (not filepath or filepath == self.filepath) then 
			filepath = (filepath or self.filepath):gsub("%.pfb", ".NEW.pfb")
		end
		
		self.bs = BitStream:new()
		self.bs.filepath = (onlyUpdateBuffer and self.filepath) or filepath
		filepath = filepath or self.bs.filepath or self.filepath
		if not filepath then return re.msg("No File") end
		
		self.bs.fileExists = BitStream.checkFileExists(filepath)
		
		self.bs:writeBytes(PFBFile.structSizes["header"])
		
		for i, gameObjectInfo in ipairs(self.gameObjectInfos) do
			self:writeStruct("gameObjectInfo", gameObjectInfo)
		end
		
		if self.header.gameObjectRefInfoCount and self.header.gameObjectRefInfoCount > 0 then 
			--self.bs:align(16)
			self.header.gameObjectRefInfoOffset = self:tell()
			for i, gameObjectRefInfo in ipairs(self.gameObjectRefInfos) do
				self:writeStruct("gameObjectRefInfo", gameObjectRefInfo)
			end
		end
		
		self.bs:align(16)
		self.header.resourceInfoOffset = self:tell()
		for i, resourceInfo in ipairs(self.resourceInfos) do
			self:writeStruct("resourceInfo", resourceInfo)
			--if isOldVer then self.bs:skip(-2) end
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
		self.header.gameObjectRefInfoCount = self.gameObjectRefInfos and #self.gameObjectRefInfos
		self.header.userdataCount = self.userdataInfos and #self.userdataInfos
		self:writeStruct("header", self.header)
		if not onlyUpdateBuffer then
			self.bs:save(filepath)
			if not noPrompt then re.msg("Saved to " .. filepath) end
			ResourceEditor.textBox = filepath
		end
		--self.backup = self.bs
		--self.RSZ.bs:save("test94.pfb")
	end,
	
	saveAsSCN = function(self, filepath)
		self.structs = SCNFile.structs
		self.header.magic = 5129043 --"SCN"
		SCNFile.save(self, filepath)
		self.header.magic = 4343376 --"PFB"
		self.structs = nil
	end,
	
	customStructDisplayFunction = function(self, struct, idx)
		SCNFile.customStructDisplayFunction(self, struct, idx)
		if struct.targetId then
			changed, struct.newObjectId = imgui.combo("Object Instance", struct.newObjectId or struct.objectID+1, self.RSZ.objectTable.names)
			if changed then
				struct.objectID = struct.newObjectId-1
			end
			changed, struct.newTargetId = imgui.combo("Target Instance", struct.newTargetId or struct.targetId+1, self.RSZ.objectTable.names)
			if changed then
				struct.targetId = struct.newTargetId-1
			end
		end
	end,
	
	-- Structures comprising a PFB file:
	structs = {
		header = {
			{"UInt", "magic"},
			{"UInt", "infoCount"},
			{"UInt", "resourceCount"},
			{"UInt", "gameObjectRefInfoCount"},
			{"UInt64", "userdataCount"}, --{"skip", 4},
			{"UInt64", "gameObjectRefInfoOffset"},
			{"UInt64", "resourceInfoOffset"},
			{"UInt64", "userdataInfoOffset"},
			{"UInt64", "dataOffset"},
		},
		
		gameObjectInfo = {
			{"Int", "objectId"},
			{"Int", "parentId"},
			{"Int", "componentCount"},
		},
		
		gameObjectRefInfo = {
			{"UInt", "objectID"},
			{"Int", "propertyId"},
			{"Int", "arrayIndex"},
			{"UInt", "targetId"},
		},
		
		resourceInfo = {
			{"UInt64", "pathOffset", {"WString", "resourcePath"}},
		},
		
		userdataInfo = {
			{"UInt", "typeId"},
			{"UInt", "CRC"},
			{"UInt64", "pathOffset", {"WString", "userdataPath"}},
		},
		
		structOrder = {"header", "gameObjectInfo", "gameObjectRefInfo", "resourceInfo", "userdataInfo"}
	},
}

if isOldVer then 
	table.remove(PFBFile.structs.header, 8)
	table.remove(PFBFile.structs.header, 5)
	table.remove(PFBFile.structs.structOrder, 5)
	PFBFile.structs.resourceInfo = { {"WString", "resourcePath"}, }
end

--pfb = PFBFile:new("RE_Resources\\em1240deadbody.pfb.17")

UserFile = {
	
	--User file extensions by game
	extensions = {
		re2 = ".2",
		re3 = ".2",
		re4 = ".2",
		re8 = ".2",
		re7 = ".2",
		dmc5 = ".2",
		mhrise = ".2",
		sf6 = ".2",
	},
	
	sf6_cmd_param_names = {
		"CustomizeColors",
		"Emissive",
		"Cloth_DetailA_AOColor",
		"ClothAniso_PrimalySpecularColor",
		"FakeCloth_Color",
		"Stitch_A_AOColor",
		"Stitch_B_AOColor",
		"OcclutionColor",
		"PrimalySpecularColor",
		"SecondarySpecularColor",
		"PrimalyColorOffset",
		"SecondaryColorOffset",
		"Rimlight_Color",
		"SpecularIntensity",
		"PrimalySpec_Sharpness",
		"SecondSpec_Sharpness",
	},
	
	isUser = true,
	
	ext2 = ".user",

	-- Creates a new RE_Resource.UserFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
		if self.RSZ then self.RSZ.bs:close() end
		local stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset, owner=self})
		
	end,
	
	-- Updates the UserFile and RSZFile BitStreams with data from owned Lua tables, and saves the result to a new file
	save = function(self, filepath, onlyUpdateBuffer, doOverwrite, noPrompt, cmd_materials)
		
		if not doOverwrite and (not filepath or filepath == self.filepath) then 
			filepath = (filepath or self.filepath):gsub("%.user", ".NEW.user")
		end
		
		self.bs = BitStream:new()
		self.bs.filepath = onlyUpdateBuffer and self.filepath or filepath
		self.bs.fileExists = BitStream.checkFileExists(filepath)
		
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
		
		--Saves a Street Fighter 6 "CMD" color file using "materials" table from an EMV GameObject
		if cmd_materials then
			
			local material, recurse
			
			local fn = EMV.static_funcs.calc_color
			
			local function process_field_tbl(field_value, val_to_find, val_to_save)
				if field_value[1] then
					for i, entry in ipairs(field_value) do
						if type(entry) == "table" and entry.rawDataTbl then
							if recurse(entry, val_to_find, val_to_save) then 
								return true 
							end
						end
					end
				elseif field_value.rawDataTbl then
					return recurse(field_value, val_to_find, val_to_save)
				end
			end
			
			recurse = function(rsz_instance, to_find, passed_value)
				for i, field in ipairs(rsz_instance.fields or {}) do
					if field.name == to_find then
						
						local idx = material.var_names_dict[to_find] or 0
						local emv_var = passed_value or material.variables[idx]
						local is_customize_colors = (to_find == "CustomizeColors")
						
						if is_customize_colors or emv_var ~= nil then 	
							if is_customize_colors or (type(field.value) == "table" and field.value.rawDataTbl) then
								if is_customize_colors then
									for c, cc_field in ipairs(field.value) do
										local cc_idx = material.var_names_dict["CustomizeColor_"..c-1] 
										print("CC_IDX: "..tostring(cc_idx))
										if material.variables[cc_idx] then
											if material.variables[cc_idx] ~= material.orig_vars[cc_idx] then
												cc_field.fields[1].value, cc_field.fields[1].rawField.value = true, 1
											end
											process_field_tbl(cc_field, "Color", material.variables[cc_idx])
										end
										local met_idx = material.var_names_dict["CustomizeMetal_"..c-1] 
										if material.variables[met_idx] and material.variables[met_idx] ~= material.orig_vars[met_idx] then
											process_field_tbl(cc_field.fields[3].value.fields[1].value, "Enable", true)
											process_field_tbl(cc_field.fields[3].value.fields[1].value, "_Value", material.variables[met_idx])
										end
										local rgh_idx = material.var_names_dict["CustomizeRoughness_"..c-1] 
										if material.variables[rgh_idx] and material.variables[rgh_idx] ~= material.orig_vars[rgh_idx] then
											process_field_tbl(cc_field.fields[3].value.fields[2].value, "Enable", true)
											process_field_tbl(cc_field.fields[3].value.fields[2].value, "_Value", material.variables[rgh_idx])
										end
										local blend_idx = material.var_names_dict["CustomizeColor_"..(c-1).. "_BlendRate"] 
										if material.variables[blend_idx] and material.variables[blend_idx] ~= material.orig_vars[blend_idx] then
											process_field_tbl(cc_field.fields[3].value.fields[3].value, "Enable", true)
											process_field_tbl(cc_field.fields[3].value.fields[3].value, "_Value", material.variables[blend_idx])
										end
									end
								elseif idx==0 or material.variables[idx] ~= material.orig_vars[idx] then
									process_field_tbl(field.value, "Enable", true)
									if to_find == "Emissive" then
										process_field_tbl(field.value, "_Value", emv_var)
									elseif EMV.can_index(emv_var) then
										if to_find:find("Color") then
											process_field_tbl(field.value, "Value", emv_var)
										else
											process_field_tbl(field.value, "_ValueX", emv_var.x)
											process_field_tbl(field.value, "_ValueY", emv_var.y)
											process_field_tbl(field.value, "_ValueZ", emv_var.z)
											process_field_tbl(field.value, "_ValueW", emv_var.w)
										end
									else
										if not process_field_tbl(field.value, "Value", emv_var) then
											process_field_tbl(field.value, "_Value", emv_var)
										end
									end
									return true
								end
							else
								local new_value = emv_var
								if EMV.can_index(emv_var)  then
									new_value = string.unpack("<i", string.pack("<BBBB", fn(emv_var.x), fn(emv_var.y), fn(emv_var.z), fn(emv_var.w)))
								end
								field.value = new_value
								if type(new_value) == "boolean" then
									field.rawField.value = bool_to_number[new_value]
								else
									field.rawField.value = new_value
								end
							end
						end
					elseif type(field.value) == "table" then
						process_field_tbl(field.value, to_find, passed_value)
					end
				end
			end
			
			for i, body_part in ipairs(self.RSZ.objects[1].fields[1].value) do
				for j, cluster in ipairs(body_part.fields[2].value) do
					local mat_idx = EMV.find_index(cmd_materials, cluster.title, "name")
					material = mat_idx and cmd_materials[mat_idx]
					if material then
						for k, var_name in ipairs(self.sf6_cmd_param_names) do 
							recurse(cluster, var_name)
						end
					end
				end
			end
		end
		
		self.RSZ:writeBuffer()
		self.bs:writeBytes(self.RSZ.bs:getBuffer())
		
		self:seek(0)
		self.header.resourceCount = #self.resourceInfos
		self.header.userdataCount = #self.userdataInfos
		self:writeStruct("header", self.header)
		
		if not onlyUpdateBuffer and (self.bs:save(filepath) and filepath) then
			if not noPrompt then re.msg("Saved to " .. filepath) end
			ResourceEditor.textBox = filepath
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
--[[
FCharFile = {
	extensions = {
		sf6 = ".31",
	},
	
	isFCH = true,
	
	ext2 = ".fchar",

	-- Creates a new RE_Resource.UserFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
		if self.RSZ then self.RSZ.bs:close() end
		stream = self.bs:extractStream()
		self.RSZ = RSZFile:new({file=stream, startOf=self.header.dataOffset, owner=self})
		
	end,
	
	-- Structures comprising a fchar file:
	structs = {
		header = {
			{"UInt", "version"},
			{"UInt", "magic"},
			{"UInt64", "idTblOffs"},
			{"UInt64", "parentIdTblOffs"},
			{"UInt64", "actionListTblOffsOffs"},
			{"UInt64", "DataIdTblOffs"},
			{"UInt64", "DataListTblOffsOffs"},
			{"UInt64", "stringsObjectsOffs"},
			{"UInt64", "StringsOffs"},
			{"UInt64", "objectTblRSZOffset"},
			{"UInt64", "objectTblRSZEnd"},
			{"UInt", "objCount"},
			{"UInt", "styleCount"},
			{"UInt", "dataCount"},
			{"UInt", "StringsCount"},
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
]]
-- Class for MDF Material files
MDFFile = {
	
	--MDF file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".10") or ".21",
		re3 = ((tdb_ver==68) and ".13") or ".21",
		re4 = ".32",
		re8 = ".19",
		re7 = ((tdb_ver==49) and ".6") or ".21",
		dmc5 =".10",
		mhrise = ".23",
		sf6 = ".31",
	},
	
	isMDF = true,
	ext2 = ".mdf2",
	
	-- Creates a new RE_Resource.MDFFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
	save = function(self, filepath, onlyUpdateBuffer, doOverwrite, noPrompt, mesh)
		
		if not doOverwrite and (not filepath or filepath == self.filepath) then
			filepath = (filepath or self.filepath):gsub("%.mdf2", ".NEW.mdf2")
		end
		
		self.bs = BitStream:new()
		self.bs.filepath = onlyUpdateBuffer and self.filepath or filepath
		self.bs.fileExists = BitStream.checkFileExists(filepath)
		
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
		--self.backup = self.bs
		
		if not onlyUpdateBuffer and (self.bs:save(filepath) and filepath) then
			if not noPrompt then re.msg("Saved to " .. filepath) end
			ResourceEditor.textBox = filepath
			return true
		end
	end,
	
	--Is used during displayImgui to add extra stuff to structs 
	customStructDisplayFunction = function(self, struct)
		if struct.parameter then 
			if struct.componentCount == 4 then--struct.paramName:find("olor") then 
				local vecForm = Vector4f.new(struct.parameter[1], struct.parameter[2], struct.parameter[3], struct.parameter[4])
				changed, vecForm = EMV.show_imgui_vec4(vecForm, struct.name, nil, 0.01)
				struct.parameter = {vecForm.x, vecForm.y, vecForm.z, vecForm.w}
			else
				changed, struct.parameter = imgui.drag_float(struct.name, struct.parameter, 0.001, -9999999, 9999999)
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

-- Class for Chain physics files
ChainFile = {
	
	--Chain file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".21") or ".46",
		re3 = ((tdb_ver==68) and ".39") or ".46",
		re4 = ".53",
		re8 = ".39",
		re7 = ((tdb_ver==49) and ".5") or ".46",
		dmc5 =".21",
		mhrise = ".48",
		sf6 = ".52",
	},
	
	isChain = true,
	ext2 = ".chain",
	
	-- Creates a new RE_Resource.ChainFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = RE_Resource:newResource(args, setmetatable(o, self))
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
		
		self.chainSettings = {}
		for m = 1, self.header.settingCount do 
			self.bs:seek(self.header.settingsOffset + self.structSizes.chainSetting * (m-1))
			self.chainSettings[m] = self:readStruct("chainSetting")
			self.chainSettings[m].name = "ChainSetting -- ID: " .. tostring(self.chainSettings[m].id)
		end
		
		self.chainCollisions = {}
		for m = 1, self.header.modelCollisionCount do 
			self.bs:seek(self.header.modelCollisionsOffset + self.structSizes.chainCollision * (m-1))
			self.chainCollisions[m] = self:readStruct("chainCollision")
			self.chainCollisions[m].name = "Collision -- " .. self.chainCollisions[m].jointNameHash .. (self.chainCollisions[m].pairJointNameHash~=0 and (" to " .. self.chainCollisions[m].pairJointNameHash) or "")
		end
		
		self.chainGroups = {}
		for m = 1, self.header.groupCount do 
			self.bs:seek(self.header.groupsOffset + self.structSizes.chainGroup * (m-1))
			self.chainGroups[m] = self:readStruct("chainGroup")
			self.chainGroups[m].name = "ChainGroup -- " .. self.chainGroups[m].terminalNodeName
			self.chainGroups[m].nodes = {}
			for g = 1, self.chainGroups[m].nodeCount do 
				self.bs:seek(self.chainGroups[m].nodesOffset + self.structSizes.chainNode * (g-1))
				self.chainGroups[m].nodes[g] = self:readStruct("chainNode")
				self.chainGroups[m].nodes[g].name = (g == self.chainGroups[m].nodeCount and self.chainGroups[m].terminalNodeName) or self.chainGroups[m].terminalNodeName:gsub("_end", "_"..string.format("%02d", g-1))
				if self.chainGroups[m].nodes[g].jiggleData and self.chainGroups[m].nodes[g].jiggleData > 0 then
					self.bs:seek(self.chainGroups[m].nodes[g].jiggleData)
					self.chainGroups[m].nodes[g].jiggle = self:readStruct("chainJiggle")
					self.chainGroups[m].nodes[g].jiggle.name = "ChainJiggle"
				end
			end
		end
		
		self.windSettings = {}
		for m = 1, self.header.windSettingCount do 
			self.bs:seek(self.header.windSettingsOffset + self.structSizes.windSetting * (m-1))
			self.windSettings[m] = self:readStruct("windSetting")
			self.windSettings[m].name = "WindSetting -- ID: " .. tostring(self.windSettings[m].id) --self.windSettings[m].matName
		end
		
		self.chainLinks = {}
		for m = 1, self.header.linkCount do 
			self.bs:seek(self.header.linksOffset + self.structSizes.chainLink * (m-1))
			self.chainLinks[m] = self:readStruct("chainLink")
			self.chainLinks[m].name = "ChainLink -- " .. tostring(self.chainLinks[m].terminalNodeNameAHash)
			self.chainLinks[m].chainLinkNodes = {}
			for c = 1, self.chainLinks[m].nodesCount do 
				self.bs:seek(self.chainLinks[m].nodesOffset + self.structSizes.chainLinkNode * (c-1))
				self.chainLinks[m].chainLinkNodes[c] = self:readStruct("chainLinkNode")
				self.chainLinks[m].chainLinkNodes[c].name = tostring("ChainLinkNode -- " .. self.chainLinks[m].chainLinkNodes[c].collisionRadius)
			end
		end
	end,
	
	-- Saves a new Chain file using data from owned Lua tables
	save = function(self, filepath, onlyUpdateBuffer, doOverwrite, noPrompt, chainObjTbl)
		
		if not doOverwrite and (not filepath or filepath == self.filepath) then
			filepath = (filepath or self.filepath):gsub("%.chain", ".NEW.chain")
		end
		
		self.bs = BitStream:new()
		self.bs.filepath = onlyUpdateBuffer and self.filepath or filepath
		self.bs.fileExists = BitStream.checkFileExists(filepath)
		
		self:writeStruct("header", self.header)
		self.bs:align(16)
		print("start\n\n\n")
		if chainObjTbl then --apply chain settings from EMV
			for i, cgroup in ipairs(chainObjTbl.cgroups) do
				if not cgroup.settings then 
					cgroup:change_custom_setting()
				end
				local fileChainSettings = cgroup.settings and self.chainSettings[EMV.find_index(self.chainSettings, cgroup.settings_id, "id") or 0]
				--bb = fileChainSettings or bb
				if fileChainSettings then
					cgroup.settings._ = cgroup.settings._ or EMV.create_REMgdObj(cgroup.settings)
					for key, tbl in pairs(cgroup.settings._.props_named) do
						local fileKey = key:gsub("^_", ""); fileKey = fileKey:sub(1,1):lower()..fileKey:sub(2, -1)
						--print(tostring(fileChainSettings[fileKey]) .. " " .. tostring(fileKey) .. " " .. tostring(key))
						if fileChainSettings[fileKey] ~= nil then
							--re.msg(fileKey .. " " .. key)
							--print(fileKey .. " is found")
							fileChainSettings[fileKey] = tbl.value
						elseif i == 1 then 
							print(fileKey .. " is missing")
						end
					end
				end
			end
		end
		
		self.header.settingsOffset = self.bs:tell()
		for m = 1, self.header.settingCount do
			self:writeStruct("chainSetting", self.chainSettings[m])
		end
		self.bs:align(16)
		
		self.header.modelCollisionsOffset = self.bs:tell()
		for m = 1, self.header.modelCollisionCount do 
			self:writeStruct("chainCollision", self.chainCollisions[m])
		end
		self.bs:align(16)
		
		self.header.groupsOffset = self.bs:tell()
		for m = 1, self.header.groupCount do 
			self:writeStruct("chainGroup", self.chainGroups[m])
		end
		self.bs:align(16)
		
		
		for m = 1, self.header.groupCount do 
			self.chainGroups[m].terminalNodeNameOffset = self.bs:tell()
			if m > 1 then
				self.chainGroups[m-1].nextChainNameOffset = self.bs:tell()
			end
			self.bs:writeWString(self.chainGroups[m].terminalNodeName)
			self.bs:align(16)
			self.chainGroups[m].nodesOffset = self.bs:tell() 
			for i, node in ipairs(self.chainGroups[m].nodes) do
				self:writeStruct("chainNode", node)
			end
			self.bs:align(16)
			for i, node in ipairs(self.chainGroups[m].nodes) do
				if node.jiggle then
					node.jiggleData = self.bs:tell()
					self:writeStruct("chainJiggle", node.jiggle)
					self:writeStruct("chainNode", node, node.startOf) --rewrite with offset
				end
			end
			self.bs:align(16)
		end
		self.bs:align(16)
		
		self.chainGroups[#self.chainGroups].nextChainNameOffset = self.bs:tell()
		self.header.windSettingsOffset = self.bs:tell()
		
		for m = 1, self.header.windSettingCount do 
			self:writeStruct("windSetting", self.windSettings[m])
		end
		self.bs:align(16)
		
		self.header.linksOffset = self.bs:tell()
		for m = 1, self.header.linkCount do 
			self:writeStruct("chainLink", self.chainLinks[m])
		end
		self.bs:align(16)
		
		for m = 1, self.header.linkCount do 
			if self.chainLinks[m].chainLinkNodes[1] then
				self.chainLinks[m].nodesOffset = self.bs:tell()
				for c, chainLinkNode in ipairs(self.chainLinks[m].chainLinkNodes) do 
					self:writeStruct("chainLinkNode", chainLinkNode)
				end
			end
		end
		
		self.bs:seek(0) 
		self:writeStruct("header", self.header) --rewrite header now with offsets
		
		self.bs:seek(self.header.groupsOffset) 
		for m = 1, self.header.groupCount do 
			self:writeStruct("chainGroup", self.chainGroups[m]) --rewrite chainGroups now with offsets
		end
		
		self.bs:seek(self.header.linksOffset) 
		for m = 1, self.header.linkCount do 
			self:writeStruct("chainLink", self.chainLinks[m]) --rewrite chainLinks now with offsets
		end
		
		if not onlyUpdateBuffer and (self.bs:save(filepath) and filepath) then
			if not noPrompt then re.msg("Saved to " .. filepath) end
			ResourceEditor.textBox = filepath
			return true
		end
	end,
	
	--Is used during displayImgui to add extra stuff to structs 
	customStructDisplayFunction = function(self, struct)
		if struct.nodeCount and imgui.tree_node("Nodes") then 
			displayStructList(struct.nodes, self.structs.chainNode, "chainNodes")
			imgui.tree_pop()
		end
		if struct.jiggle then 
			displayStruct(1, struct.jiggle, self.structs.chainJiggle, "chainJiggle", false)
		end
		if struct.chainLinkNodes and imgui.tree_node("Chain Link Nodes") then 
			displayStructList(struct.chainLinkNodes, self.structs.chainLinkNode, "chainLinkNodes")
			imgui.tree_pop()
		end
	end,
	
	-- Structures comprising a MDF file:
	structs = {
		header = {
			{"UInt", "version"},
			{"UInt", "magic"},
			{"UInt", "ErrFlags"},
			{"UInt", "masterSize"},
			{"UInt64", "collisionAttrAssetOffset", {"WString", "collisionAttrAsset"}},
			{"UInt64", "modelCollisionsOffset"},
			{"UInt64", "extraDataOffset", {"WString", "extraData"}},
			{"UInt64", "groupsOffset"},
			{"UInt64", "linksOffset"},
			--if version >= 53
			--	{"UInt64", "uknTbl"},
			{"UInt64", "settingsOffset"},
			{"UInt64", "windSettingsOffset"},
			{"UByte", "groupCount"},
			{"UByte", "settingCount"},
			{"UByte", "modelCollisionCount"},
			{"UByte", "windSettingCount"},
			{"UByte", "linkCount"},
			{"Byte", "execOrderMax"},
			{"Byte", "defaultSettingIdx"},
			{"Byte", "calculateMode"},
			{"UInt", "ChainAttrFlags"},
			{"UInt", "parameterFlag"},
			{"Float", "calculateStepTime"},
			{"Byte", "modelCollisionSearch"},
			{"Byte", "LegacyVersion"},
			{"Short", "Padding"},
			{"UInt64", "collisionFilterHit"},
		},
		
		
		chainSetting = {
			{"UInt64", "colliderFilterInfoPathOffset", {"WString", "colliderFilterInfoPath"}},
			{"Float", "sprayArc"},
			{"Float", "sprayFrequency"},
			{"Float", "sprayCurve1"},
			{"Float", "sprayCurve2"},
			{"UInt", "id"},
			{"Byte", "chainType"},
			{"Byte", "SettingAttrFlags"},
			{"Byte", "muzzleDirection"},
			{"Byte", "windId"},
			
			{"Float3", "gravity"},
			{"Float3", "muzzleVelocity"},
			
			{"Float", "damping"},
			{"Float", "secondDamping"},
			{"Float", "secondDampingSpeed"},
			--[[if (version >= 24)
				{"Float", "minDamping"},
				{"Float", "secondMinDamping"},
				{"Float", "dampingPow"},
				{"Float", "secondDampingPow"},
				{"Float", "collideMaxVelocity"},
			]]
			{"Float", "springForce"},
			--[[if (version >= 24)
				{"Float", "springLimitRate"},
				{"Float", "springMaxVelocity"},
				{"Byte", "springCalcType"},
				{"Byte", "padding0"},
				{"Byte", "padding1"},
				{"Byte", "padding2"},
			if (version >= 53)
				{"Float", "unknChainSettingValue2"},
				{"Float", "unknChainSettingValue3"},]]
			
			{"Float", "reduceDistance"},
			{"Float", "secondReduceDistance"},
			{"Float", "secondReduceDistanceSpeed"},
			{"Float", "friction"},
			{"Float", "shockAbsorptionRate"},
			{"Float", "elasticCoef"},
			{"Float", "coefOfExternalForces"},
			{"Float", "stretchInteractionRatio"},
			{"Float", "angleLimitInteractionRatio"},
			{"Float", "shootingElasticLimitRate"},
			{"UInt", "groupDefaultAttr"},
			{"Float", "envWindEffectCoef"},
			{"Float", "velocityLimit"},
			{"Float", "hardness"},
			--[[if (version >= 46)
				{"Float", "ukn00"},
				{"Float", "ukn01"},
			if (version >= 52)	
				{"Float", "ukn02"},
				{"Float", "ukn03"},]]
		},
		
		chainCollision = {
			{"UInt64", "subDataTbl"},
			{"Float3", "pos"},
			{"Float3", "pairPos"},
			--[[if (version >= 35)	
				{"Vec4", "rotOffset"},
			if (version ~= 35)	
				{"Float", "ukn"},]]
			{"UInt", "jointNameHash"},
			{"UInt", "pairJointNameHash"},
			{"Float", "radius"},
			{"Float", "lerp"},
			--if version >= 48
			--	{"Float", "ukn"},
			{"UByte", "shape"},
			{"UByte", "div"},
			{"UByte", "subDataCount"},
			{"UByte", "empty0"},
			{"Int", "collisionFilterFlags"},
			--if version == 39 || version == 46 || version == 44
			--	{"UInt", "ukn1"},
		},
		
		chainGroup = {
			{"UInt64", "terminalNodeNameOffset", {"WString", "terminalNodeName"}},
			{"UInt64", "nodesOffset"},
			{"UInt", "settingID"},
			{"UByte", "nodeCount"},
			{"UByte", "execOrder"},
			{"UByte", "autoBlendCheckNodeNo"},
			{"UByte", "windID"},
			{"UInt", "terminalNameHash"},
			{"UInt", "attrFlags"},
			{"Int", "collisionFilterFlags"},
			{"Float3", "extraNodeLocalPos"},
			--[[if (version >= 35)
				{"Vec4", "tags"},
				{"Float", "dampingNoise"},
				{"Float", "dampingNoise"},
				{"Float", "endRotConstMax"},
				{"UByte", "tagCount"},
				{"UByte", "angleLimitDirectionMode"},
				{"Short", "padding0"},
			if (version >= 48)
				{"UByte", "unknownBoneHash"},
				{"UByte", "unknown"},
				{"UByte", "unknownI64"},
			if (version >= 52)
				{"UByte", "ukn"},
			if (version >= 44)
				{"UInt64", "nextChainNameOffset", {"WString", "nextChainName"}},]]
		},
		
		
		chainNode = {
			{"Vec4", "angleLimitDirection"},
			{"Float", "angleLimitRad"},
			{"Float", "angleLimitDistance"},
			{"Float", "angleLimitRestitution"},
			{"Float", "angleLimitRestituteStopSpeed"},
			{"Float", "collisionRadius"},
			{"Int", "collisionFilterFlags"},
			{"Float", "capsuleStretchRate1"},
			{"Float", "capsuleStretchRate2"},
			{"UInt", "attributeFlag"},
			{"UInt", "constraintJntNameHash"},
			{"Float", "windCoef"},
			{"Byte", "angleMode"},
			{"Byte", "collisionShape"},
			{"Byte", "attachType"},
			{"Byte", "rotationType"},
			--[[if (version >= 35)
				{"UInt64", "jiggleData"},
				{"Float", "ukn0"},
				{"Float", "ukn1"},]]
		},
		
		chainJiggle = {
			{"Vec4", "range"},
			{"Vec4", "rangeOffset"},
			{"Vec4", "rangeAxis"},
			{"UInt", "rangeShape"},
			{"Float", "springForce"},
			{"Float", "gravityCoef"},
			{"Float", "damping"},
			{"UInt", "flags"},
			--{"UInt", "padding"},
			{"Float", "ukn"},
		},
		
		windSetting = {
			{"UInt", "id"},
			{"Byte", "windDirection"},
			{"Byte", "windCount"},
			{"Byte", "windType"},
			{"Byte", "padding"},
			{"Float", "randomDamping"},
			{"Float", "randomDampingCycle"},
			{"Float", "randomCycleScaling"},
			{"UInt", "reserved"},
			{"Float3", "direction0"},
			{"Float3", "direction1"},
			{"Float3", "direction2"},
			{"Float3", "direction3"},
			{"Float3", "direction4"},
			{"Float5", "min"},
			{"Float5", "max"},
			{"Float5", "phaseShift"},
			{"Float5", "cycle"},
			{"Float5", "interval"},
		},
		
		chainLink = {
			{"UInt64", "nodesOffset"},
			{"UInt", "terminalNodeNameAHash"},
			{"UInt", "terminalNodeNameBHash"},
			{"Float", "distanceShrinkLimitCoef"},
			{"Float", "distanceExpandLimitCoef"},
			
			{"UByte", "LinkMode"},
			{"Byte", "connectFlags"},
			{"Short", "linkAttrFlags"},
			
			{"UByte", "nodesCount"},
			{"UByte", "skipGroupA"},
			{"UByte", "skipGroupB"},
			{"UByte", "linkOrder"},
		},
		
		chainLinkNode = {
			{"Float", "collisionRadius"},
			{"Int", "collisionFilterFlags"},
		},
		
		structOrder = {"header", "chainSetting", "chainCollision", "chainGroup", "chainJiggle", "windSetting", "chainLink", "chainLinkNode"}
	},
}

-- ChainFile struct adjustments for different TDB versions:
if tdb_ver >= 66  then --RE2+
	local x24 = 66
	local x35 = 66
	local x44 = 66
	local x46 = 66
	local x48 = 66
	local x52 = 66
	local x53 = 72
	
	--header
	if tdb_ver > x53 then
		table.insert(ChainFile.structs.header, 10, {"UInt64", "uknTbl"})
	end
	
	--chainSettings
	if tdb_ver >= x46 then
		table.insert(ChainFile.structs.chainSetting, {"Float", "ukn00"})
		table.insert(ChainFile.structs.chainSetting, {"Float", "ukn01"})
		if tdb_ver >= x52 then
			table.insert(ChainFile.structs.chainSetting, {"Float", "ukn02"})
			table.insert(ChainFile.structs.chainSetting, {"Float", "ukn03"})
		end
	end
	local idx = EMV.find_index(ChainFile.structs.chainSetting, "secondDampingSpeed", 2)+1
	if tdb_ver >= x53 then
		table.insert(ChainFile.structs.chainSetting, idx+1, {"Float", "unknChainSettingValue2"})
		table.insert(ChainFile.structs.chainSetting, idx+1, {"Float", "unknChainSettingValue1"})
	end
	table.insert(ChainFile.structs.chainSetting, idx+1, {"UInt", "springCalcType"})
	table.insert(ChainFile.structs.chainSetting, idx+1, {"Float", "springMaxVelocity"})
	table.insert(ChainFile.structs.chainSetting, idx+1, {"Float", "springLimitRate"})
	table.insert(ChainFile.structs.chainSetting, idx, {"Float", "collideMaxVelocity"})
	table.insert(ChainFile.structs.chainSetting, idx, {"Float", "secondDampingPow"})
	table.insert(ChainFile.structs.chainSetting, idx, {"Float", "dampingPow"})
	table.insert(ChainFile.structs.chainSetting, idx, {"Float", "secondMinDamping"})
	table.insert(ChainFile.structs.chainSetting, idx, {"Float", "minDamping"})
	
	--chainCollisions
	if tdb_ver >= x35 then
		if tdb_ver >= x48 then
			table.insert(ChainFile.structs.chainCollision, 8, {"Float", "ukn1"})
		end
		table.insert(ChainFile.structs.chainCollision, 4, {"Vec4", "rotOffset"})
		table.insert(ChainFile.structs.chainCollision, 4, {"Float", "ukn0"})
		if tdb_ver == x39 or tdb_ver == x46 or tdb_ver == x44 then
			table.insert(ChainFile.structs.chainCollision, 4, {"UInt", "ukn1"})
		end
	end
	
	--chainGroups
	if tdb_ver >= x35 then
		if tdb_ver >= x44 then
			table.insert(ChainFile.structs.chainGroup, 12, {"UInt64", "nextChainNameOffset", {"WString", "nextChainName"}})
		end
		if tdb_ver >= x52 then
			table.insert(ChainFile.structs.chainGroup, 12, {"Int64", "ukn"})
		end
		if tdb_ver >= x48 then
			table.insert(ChainFile.structs.chainGroup, 12, {"UInt64", "unknownI64"})
			table.insert(ChainFile.structs.chainGroup, 12, {"UInt", "unknown"})
			table.insert(ChainFile.structs.chainGroup, 12, {"UInt", "unknownBoneHash"})
			table.insert(ChainFile.structs.chainGroup, 12, {"UInt64", "uknI64_00"})
		end
		table.insert(ChainFile.structs.chainGroup, 12, {"Short", "padding0"})
		table.insert(ChainFile.structs.chainGroup, 12, {"UByte", "angleLimitDirectionMode"})
		table.insert(ChainFile.structs.chainGroup, 12, {"UByte", "tagCount"})
		table.insert(ChainFile.structs.chainGroup, 12, {"Float", "endRotConstMax"})
		table.insert(ChainFile.structs.chainGroup, 12, {"Float", "dampingNoise"})
		table.insert(ChainFile.structs.chainGroup, 12, {"Float", "dampingNoise"})
		table.insert(ChainFile.structs.chainGroup, 12, {"Vec4", "tags"})
	end
	--chainNodes
	if tdb_ver >= x35 then
		table.insert(ChainFile.structs.chainNode, {"UInt64", "jiggleData"})
		table.insert(ChainFile.structs.chainNode, {"Float", "ukn0"})
		table.insert(ChainFile.structs.chainNode, {"Float", "ukn1"})
	end
end

--setup struct sizes:
for i, class in ipairs({RSZFile, PFBFile, SCNFile, UserFile, MDFFile, ChainFile}) do
	class.structSizes = {}
	for name, structArray in pairs(class.structs) do
		local totalBytes = 0
		for i, fieldTbl in ipairs(structArray) do 
			totalBytes = totalBytes + (RE_Resource.typeNamesToSizes[ fieldTbl[1] ] or 0)
		end
		class.structSizes[name] = totalBytes
	end
end


--scn:saveAsPFB("RE_Resources\\st11_020_kitchen_in2f.pfb.17")
--user = UserFile:new("em1000configuration.user.2")
--system_difficulty_rate_data.user.2
--$natives\\stm\\RE_Resources\\evc0010_Character.pfb.17
--scn = SCNFile:new("RE_Resources\\evc3009_Character.scn.20")

--scn = SCNFile:new("RE_Resources\\st11_076_BasementB_In1B.scn.20")
--scn = SCNFile:new("RE_Resources\\st11_020_kitchen_in2f.scn.20")
--scn.RSZ:addInstance("via.motion.Motion")
--scn:save()
--scn.RSZ:addInstance("via.physics.Colliders")
--scn = SCNFile:new("RE_Resources\\ItemBox.scn.20")
--scn = SCNFile:new("RE_Resources\\em1302pool.scn.20")
--buffer = scn.RSZ:writeBuffer()
--buffer:save("test99.scn")

--[[function testInsert()
	MDF = MDFFile:new{"RE_Resources\\pl0003.mdf2.10"}
	MDF:fixOffsets(0, MDF.bs:fileSize(), MDF.matHeaders[#MDF.matHeaders].startOf+MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.bs.size + MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.matHeaders[#MDF.matHeaders].sizeOf, 8) --
	MDF:insertStruct("matHeader", MDF.matHeaders[#MDF.matHeaders])
	MDF:read()
	MDF.header.matCount = MDF.header.matCount + 1
	MDF:save("RE_Resources\\saved.mdf2.10")
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

RE_Resource.validExtensions = {
	["scn"] = SCNFile,
	["pfb"] = PFBFile,
	["user"] = UserFile,
	["mdf2"] = MDFFile,
	["chain"] = ChainFile,
}

local function imgui_file_picker()
	imgui.begin_window("File Picker")
		local current_dir = ""
	imgui.end_window()
	local glob = fs.glob
end

-- Resource Editor UI
ResourceEditor = {
	textBox = "",
	currentItemIdx = nil,
	recentItemIdx = nil,
	previousItems = {},
	paths = json.load_file("rsz\\resource_list.json"),
	recentFiles = json.load_file("rsz\\recent_files.json") or {""}
}

ResourceEditor.paths = ResourceEditor.paths and ResourceEditor.paths[game_name] or {}

EMV.displayResourceEditor = function()
	
	imgui.begin_rect()
	--imgui.push_font(utf16_font)
		ResourceEditor.textBox = ResourceEditor.textBox or ""
		--imgui.text((ResourceEditor.previousItems[ResourceEditor.textBox:lower()] and "  ") or " ?")
		--imgui.same_line()
		if not rsz_parser then 
			imgui.text_colored("Failed to locate reframework\\data\\plugins\\rsz_parser_REF.dll!", 0xFF0000FF)
		elseif not rsz_parser.IsInitialized() then 
			imgui.text_colored("Failed to locate reframework\\data\\rsz\\rsz" .. game_name .. rt_suffix .. ".json !\nDownload this file from https://github.com/alphazolam/RE_RSZ", 0xFF0000FF)
		end
		
		local lastIdx, doOpen = ResourceEditor.recentItemIdx
		changed, ResourceEditor.recentItemIdx = imgui.combo("Recent Files", ResourceEditor.recentItemIdx or 1, ResourceEditor.recentFiles)
		
		if changed and lastIdx ~= ResourceEditor.recentItemIdx then 
			ResourceEditor.textBox = "$natives\\" .. nativesFolderType .. "\\" .. ResourceEditor.recentFiles[ResourceEditor.recentItemIdx]
			ResourceEditor.currentItemIdx = EMV.find_index(ResourceEditor.paths, ResourceEditor.recentFiles[ResourceEditor.recentItemIdx]) or ResourceEditor.currentItemIdx
			doOpen = true
		end
		
		if ResourceEditor.recentFiles[2] then 
			if not imgui.same_line() and imgui.button("Clear") then 
				ResourceEditor.recentFiles = {""}
				ResourceEditor.recentItemIdx = 1
				json.dump_file("rsz\\recent_files.json", ResourceEditor.recentFiles)
			end
			if not imgui.same_line() and imgui.button("Sort") then 
				local last = ResourceEditor.recentFiles[ResourceEditor.recentItemIdx]
				table.sort(ResourceEditor.recentFiles)
				ResourceEditor.recentItemIdx = EMV.find_index(ResourceEditor.recentFiles, last)
			end
		end
		
		lastIdx = ResourceEditor.currentItemIdx
		changed, ResourceEditor.currentItemIdx = imgui.combo("Path", ResourceEditor.currentItemIdx or 1, ResourceEditor.paths)
		
		imgui.tooltip("Edit \"reframework\\data\\rsz\\resource_list.json\" to make this list have files from your natives folder")
		
		if changed and lastIdx ~= ResourceEditor.currentItemIdx then 
			ResourceEditor.textBox = "$natives\\" .. nativesFolderType .. "\\" .. ResourceEditor.paths[ResourceEditor.currentItemIdx]
			doOpen = true
		end

		if doOpen or (EMV.editable_table_field("textBox", ResourceEditor.textBox, ResourceEditor, "Input SCN/PFB/USER/MDF/Chain File", {always_show=false})==1 and ResourceEditor.textBox and ResourceEditor.textBox:lower():find("%.[psmuc][fcdsh][bnfea][2ri]?")) then 
			RE_Resource.openResource(ResourceEditor.textBox)
		end
		
		imgui.tooltip("Access files in the 'REFramework\\data\\' folder.\nStart with '$natives\\' to access files in the natives folder")
		
		if next(ResourceEditor.previousItems) and imgui.tree_node("Opened Files") then 
			for path, item in orderedPairs(ResourceEditor.previousItems) do
				local id = imgui.get_id(path)
				imgui.push_id(id)
					local do_clear = imgui.button("X")
				imgui.pop_id()
				imgui.same_line()
				if imgui.tree_node(path) then
					item:displayImgui()
					imgui.tree_pop()
				end
				if do_clear then
					ResourceEditor.previousItems[path] = nil
				end
			end
			imgui.tree_pop()
		end
	--imgui.pop_font()
	imgui.end_rect()
end

--[[local folderTree

local function generateFolderTree(filepath)
    local parts = {}
    for part in filepath:gmatch("[^\\]+") do
        table.insert(parts, part)
    end
    local global = folderTree
    for i, part in ipairs(parts) do
        if not global[part] then
            global[part] = {}
        end
        global = global[part]
    end
    if global ~= folderTree then
        local static_class = static_class or generateFolderTree(filepath)
        for k, v in pairs(static_class) do
            global[k] = v
			if not dont_double then 
				global[v] = k
			end
        end
    end
end]]

local last_tbl_sz = 0
local last_timer = 0
openedFiles = {}
local old_tmpfile = io.tmpfile
io.tmpfile = function()
	local tmp_file = old_tmpfile()
	if tmp_file then 
		openedFiles[tmp_file] = tmp_file
		return tmp_file
	end
end

--should_setup_dlcs = ((isRE2 or isRE3) and EMV.calln("via.Application", "get_UpTimeSecond()") < 60.0) or nil

re.on_frame(function()
	
	shift_key_down = EMV.check_key_released(via.hid.KeyboardKey.Shift, 0.0)
	
	--for i, file in ipairs(openedFiles) do 
	--	file:close()
	--end
	local tblsize = EMV.get_table_size(openedFiles)
	if tblsize > last_tbl_sz or (os.clock() - last_timer) > 5 then 
		last_timer = os.clock()
		last_tbl_sz = tblsize
	end
	--imgui.text(last_tbl_sz-1)
	--openedFiles = {}
	--[[if not folderTree then
		for i, filepath in pairs(fs.glob("$natives.*")) do
			generateFolderTree(filepath)
		end
	end]]
	--[[local ctr = 1
	local tmp = io.tmpfile()
	while tmp and ctr < 1000 do 
		ctr = ctr + 1
		tmp = io.tmpfile()
	end
	imgui.text("Max tmpfiles: " .. ctr)]] --509 max tmpfiles in one frame
	
end)