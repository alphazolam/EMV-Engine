--BitStream Lua class for REFramework
--alphaZomega, July 22 2022

local game_name = reframework.get_game_name()
local tdb_ver = sdk.get_tdb_version()

BitStream = {
	
	fmts = {
		["Byte"] = "<b",
		["UByte"] = "<B",
		["Short"] = "<h",
		["UShort"] = "<H",
		["Int"] = "<i",
		["UInt"] = "<I",
		["i64"] = "<i8",
		["Int64"] = "<i8",
		["u64"] = "<I8",
		["UInt64"] = "<I8",
		["Float"] = "<f",
		["Double"] = "<d",
		["String"] = nil,
		["s"] = nil,
		["WString"] = false,
		["w"] = false,
		["ws"] = false,
	},
	
	fmtSizes = {
		["<b"] = 1,
		["<B"] = 1,
		["<h"] = 2,
		["<H"] = 2,
		["<i"] = 4,
		["<I"] = 4,
		["<i8"] = 8,
		["<I8"] = 8,
		["<f"] = 4,
		["<d"] = 8,
	},
	
	-- Static function, checks if a file exists at 'filepath'
	checkFileExists = function(filepath)
		local f=io.open(filepath,"r")
		if f~=nil then 
			io.close(f) 
			return true 
		end 
		return false
	end,
	
	-- Creates a new BitStream class by loading the file at 'filepath' or by using the existing Lua filestream 'givenFile', or by using 'filePath' as 'givenFile' if 'filePath' is a filestream
	new = function(self, filepath, givenFile)
		local o = {}
		local tmpFile = givenFile or (type(filepath)=="userdata" and filepath)
		o.file = tmpFile or io.tmpfile()
		if filepath and not tmpFile then
			o.filepath = filepath
			o.fileExists = false
			local file = io.open(filepath, 'rb')
			if file then
				o.file:write(file:read("*a"))
				file:close()
				o.file:seek("set", 0)
				o.fileExists = true
			end
		end
		self.fileSize(o)
		o.pos = 0
		self.__index = self
		return setmetatable(o, self)
	end,
	
	-- Moves to the given position in the stream, skips if relative, and inserts 00s up to 'pos' if insertIfEOF is true and 'pos' > fileSize
	seek = function(self, pos, relative, insertIfEOF)
		local newPos
		if relative then
			newPos = self.pos + pos
		else
			newPos = (pos=="end" and self.file:seek("end", 0)) or pos
		end
		if newPos > self.size then
			if insertIfEOF then 
				self.file:seek("end")
				local addString = {}
				for i=1, (newPos - self.size) do
					addString[i] = "\0"
				end
				self.file:write(table.concat(addString))
			else
				return false
			end
		end
		self.pos = newPos
		return self.file:seek("set", newPos)
	end,
	
	-- Moves 'numBytes' into the stream, relative to the current position
	skip = function(self, numBytes)
		return self:seek(numBytes, true)
	end,
	
	-- Returns the current position within the stream
	tell = function(self)
		return self.pos
	end,
	
	-- Returns the size of the stream (file)
	fileSize = function(self)
		self.size = self.file:seek("end")
		self.file:seek("set", self.pos)
		return self.size
	end,
	
	-- Returns the stream's bytes as a string or a table
	getBuffer = function(self, asTable)
		local result = {}
		self.file:seek("set", 0)
		if asTable then
			repeat
				local str = self.file:read(4*1024)
				for c in (str or ''):gmatch'.' do
					result[#result+1] = c:byte()
				end
			until not str
		else
			result = self.file:read("*a")
		end
		self.file:seek("set", self.pos)
		return result
	end,
	
	-- Saves the BitStream to a given filepath
	save = function(self, filepath)
		filepath = filepath or self.filepath
		if not filepath then return false end
		local file = io.open(filepath, 'w+b')
		self.file:seek("set", 0)
		file:write(self.file:read("*a"))
		file:close()
		return true
	end,
	
	-- Reads and returns a value of the format 'fmtString' at position 'pos' that is size 'numBytes', advancing 'numBytes' if 'doSkip' is true
	read = function(self, pos, numBytes, fmtString, doSkip)
		if pos < self.size then
			self.file:seek("set", pos)
			local strVal
			if numBytes then
				strVal = self.file:read(numBytes)
			else
				strVal = self.file:read(256)
				if strVal then
					if fmtString==false then --WStrings:
						strVal = strVal:match("^(.-)%z%z")
						strVal = strVal and strVal:gsub("%z", "")
						numBytes = (strVal and (strVal:len() * 2 + 1)) or 0
					else --Strings:
						strVal = strVal:match("^(.-)%z")
						numBytes = (strVal and strVal:len() + 1) or 0
					end
					
				end
			end
			if doSkip then 
				self.pos = self.pos + numBytes
			end
			return (fmtString and string.unpack(fmtString, strVal)) or strVal
		end
	end,
	
	-- Writes a value of the format 'fmtString' at position 'pos' that is size 'numBytes', advancing 'numBytes' if 'doSkip' is true
	write = function(self, pos, numBytes, fmtString, value, doSkip)
		if numBytes and pos + numBytes > self.size then 
			self.file:seek("end")
			self.file:write(string.pack("c" .. (pos + numBytes - self.size), "\0"))
			inserted = true
		end
		self.file:seek("set", pos)
		if fmtString then
			local strVal = string.pack(fmtString, value or 0)
			self.file:write(string.pack(fmtString, value))
		elseif fmtString==false then --WStrings:
			local wstr = {}
			for c in value:gmatch'.' do
				wstr[#wstr+1] = c .. "\0"
			end
			wstr[#wstr+1] = "\0\0"
			numBytes = (value:len()+1) * 2
			self.file:write(table.concat(wstr))
		else --Strings:
			numBytes = value:len() + 1
			self.file:write(value .. "\0\0")
		end
		if doSkip then 
			self.pos = self.pos + numBytes
		end
		if self.file:seek("cur") > self.size then
			self:fileSize()
		end
		self.file:seek("set", self.pos)
		return self.pos
	end,
	
	-- Writes a stringbuffer to the given or current position
	writeBytes = function(self, strBuffer, pos)
		local npos = pos or self.pos
		self.file:seek("set", npos) 
		self.file:write(strBuffer)
		self.file:seek("set", npos)
	end,
	
	-- Deletes 'numBytes' bytes at the given position 'pos' or current position
	removeBytes = function(self, numBytes, pos)
		local npos = pos or self.pos
		self.file:seek("set", 0) 
		local strBuffer = self.file:read(npos)
		self.file:seek("cur", numBytes)
		strBuffer = strBuffer .. self.file:read("*a")
		self.file = io.tmpfile():write(strBuffer)
		self.file:seek("set", npos)
	end,
	
	-- Inserts 'numBytes' bytes at the given position 'pos' or current position
	insertBytes = function(self, numBytes, pos)
		local npos = pos or self.pos
		self.file:seek("set", 0) 
		local strBuffer = self.file:read(npos) .. string.pack("c" .. numBytes, "\0") .. self.file:read("*a")
		self.file = io.tmpfile():write(strBuffer)
		if not pos then
			self:seek(npos + numBytes)
		end
	end,
	
	-- Returns a new Lua filestream of size 'numBytes' from the given position 'pos' (or current position)
	extractBytes = function(self, numBytes, pos)
		local npos = pos or self.pos
		self.file:seek("set", npos) 
		local strBuffer = self.file:read(numBytes)
		self.file:seek("set", self.pos) 
		return io.tmpfile():write(strBuffer)
	end,
	
	-- Returns the next address ahead of 'pos' or the current position that is aligned to the given 'alignment'
	getAlignedOffset = function(self, alignment, pos)
		local npos = pos or self.pos
		return npos + (npos % alignment)
	end,
	
	-- Seeks from 'pos' or the current position to the next address ahead that is aligned to the given 'alignment', inserting bytes to reach it if at End of File
	align = function(self, alignment, pos)
		local npos = pos or self.pos
		return self:seek(npos + (npos % alignment), nil, true)
	end,
	
	-- Reader wrappers
	readByte = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 1, "<b", not pos)
	end,
	readUByte = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 1, "<B", not pos)
	end,
	
	readShort = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 2, "<h", not pos)
	end,
	readUShort = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 2, "<H", not pos)
	end,
	
	readInt = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 4, "<i", not pos)
	end,
	readUInt = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 4, "<I", not pos)
	end,
	
	readInt64 = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 8, "<i8", not pos)
	end,
	readUInt64 = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 8, "<I8", not pos)
	end,
	
	readFloat = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 4, "<f", not pos)
	end,
	
	readDouble = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, 8, "<d", not pos)
	end,
	
	readString = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, nil, nil, not pos)
	end,
	
	readWString = function(self, pos)
		local npos = pos or self.pos
		return self:read(npos, nil, false, not pos)
	end,
	
	--Writer wrappers
	writeByte = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 1, "<b", value, not pos)
	end,
	writeUByte = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 1, "<B", value, not pos)
	end,
	
	writeShort = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 2, "<h", value, not pos)
	end,
	writeUShort = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 2, "<H", value, not pos)
	end,
	
	writeInt = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 4, "<i", value, not pos)
	end,
	writeUInt = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 4, "<I", value, not pos)
	end,
	
	writeInt64 = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 8, "<i8", value, not pos)
	end,
	writeUInt64 = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 8, "<I8", value, not pos)
	end,
	
	writeFloat = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 4, "<f", value, not pos)
	end,
	
	writeDouble = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, 8, "<d", value, not pos)
	end,
	
	writeString = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, nil, nil, value, not pos)
	end,
	
	writeWString = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(npos, nil, false, value, not pos)
	end,
	
	--Writes an array of variables of the same format
	writeArray = function(self, arrayTbl, fmtString, pos)
		if fmtString then
			local npos = pos or self.pos
			local size = 0
			local fmt = self.fmts[fmtString]
			fmtString = "<" .. fmtString:gsub("<", "")
			fmtSize = self.fmtSizes[fmt or fmtString]
			for i, element in ipairs(arrayTbl) do 
				local elemType = type(element)
				self:write(npos + size, fmtSize, fmt or ((elemType~="string") and fmtString) or fmt, element, not pos)
				size = size + (fmtSize or ((element:len()+1) * ((fmt==false and 2) or 1)))
			end
			return self:tell()
		end
	end,
	
	--Inserter wrappers
	insertByte = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(1, npos)
		return self:write(npos, 1, "<b", value, not pos)
	end,
	insertUByte = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(1, npos)
		return self:write(npos, 1, "<B", value, not pos)
	end,
	
	insertShort = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(2, npos)
		return self:write(npos, 2, "<h", value, not pos)
	end,
	insertUShort = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(2, npos)
		return self:write(npos, 2, "<H", value, not pos)
	end,
	
	insertInt = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(4, npos)
		return self:write(npos, 4, "<i", value, not pos)
	end,
	insertUInt = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(4, npos)
		return self:write(npos, 4, "<I", value, not pos)
	end,
	
	insertInt64 = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(8, npos)
		return self:write(npos, 8, "<i8", value, not pos)
	end,
	insertUInt64 = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(8, npos)
		return self:write(npos, 8, "<I8", value, not pos)
	end,
	
	insertFloat = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(4, npos)
		return self:write(npos, 4, "<f", value, not pos)
	end,
	
	insertDouble = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(8, npos)
		return self:write(npos, 8, "<d", value, not pos)
	end,
	
	insertString = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(value:len(), npos)
		return self:write(npos, nil, nil, value, not pos)
	end,
	
	insertWString = function(self, value, pos)
		local npos = pos or self.pos
		self:insertBytes(value:len() * 2, npos)
		return self:write(npos, nil, false, value, not pos)
	end,
	
	--RSZ reader wrappers:
	readRSZShort = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(2, npos), 2, "<h", not pos)
	end,
	readRSZUShort = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(2, npos), 2, "<H", not pos)
	end,
	
	readRSZInt = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(4, npos), 4, "<i", not pos)
	end,
	readRSZUInt = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(4, npos), 4, "<I", not pos)
	end,
	
	readRSZInt64 = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(8, npos), 8, "<i8", not pos)
	end,
	readRSZUInt64 = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(8, npos), 8, "<I8", not pos)
	end,
	
	readRSZFloat = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(4, npos), 4, "<f", not pos)
	end,
	
	readRSZDouble = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(8, npos), 8, "<d", not pos)
	end,
	
	readRSZString = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(4, npos) + 4, nil, nil, not pos)
	end,
	
	readRSZWString = function(self, pos)
		local npos = pos or self.pos
		return self:read(self:getAlignedOffset(4, npos) + 4, nil, false, not pos)
	end,
	
	--RSZ writer wrappers
	writeRSZShort = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(2, npos), 2, "<h", value, not pos)
	end,
	writeRSZUShort = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(2, npos), 2, "<H", value, not pos)
	end,
	
	writeRSZInt = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(4, npos), 4, "<i", value, not pos)
	end,
	writeRSZUInt = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(4, npos), 4, "<I", value, not pos)
	end,
	
	writeRSZInt64 = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(8, npos), 8, "<i8", value, not pos)
	end,
	writeRSZUInt64 = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(8, npos), 8, "<I8", value, not pos)
	end,
	
	writeRSZFloat = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(4, npos), 4, "<f", value, not pos)
	end,
	
	writeRSZDouble = function(self, value, pos)
		local npos = pos or self.pos
		return self:write(self:getAlignedOffset(4, npos), 8, "<d", value, not pos)
	end,
	
	writeRSZString = function(self, value, pos, doInsert)
		local orgPos = self.pos
		local npos = pos or orgPos
		if doInsert then 
			self:insertBytes(value:len() * 2 + 2, npos)
		end
		self:seek(npos + (npos % 4), nil, true)
		self:write(npos + (npos % 4), 4, "<I", value:len()+1, true)
		self:write(self.pos, nil, false, value, true)
		if pos then 
			self:seek(orgPos)
		end
		return self.pos
	end,
	
	writeRSZVec4 = function(self, value, pos)
		local npos = pos or self.pos
		return self:writeArray({value.x, value.y, value.z, value.w}, "Float", not pos)
	end,
	
	insertRSZString = function(self, value, pos)
		return self:writeRSZString(value, pos, true)
	end,
}

-- A class with important file methods shared by all resources:
REResource = {
	
	-- Creates a new Resource with a potential bitstream, filepath (and file if it is found), and a managed object
	newR = function(self, args, o)
		
		o = o or {}
		local newMT = {} --set mixed metatable of REResource and outer File class:
		for key, value in pairs(self) do newMT[key] = value end
		for key, value in pairs(getmetatable(o)) do newMT[key] = value end
		newMT.__index = newMT
		o = setmetatable(o, newMT)
		
		argsTbl = (type(args)=="table" and args) or {}
		o.filepath = argsTbl.filepath or (type(argsTbl[1])=="string" and argsTbl[1]) or (type(args)=="string" and args) or o.filepath
		o.mobject = argsTbl.mobject or (type(argsTbl[1])=="userdata" and argsTbl[1]) or (type(argsTbl[2])=="userdata" and argsTbl[2]) or (type(args)=="userdata" and args) or o.mobject
		o.bs = args.bs or BitStream:new(o.filepath) or o.bs
		o.offsets = {}
		
		return o
	end,
	
	seek = function(self, pos, relative)
		self.bs:seek(pos, relative)
	end,
	
	skip = function(self, numBytes)
		self.bs:skip(numBytes)
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
					table.insert(self.offsets, {ownerTbl=output, name=keyOrOffset, readAddress=self.bs:tell()-8, offsetTo=output[keyOrOffset], relativeStart=relativeOffset})
					if fieldTbl[3] then --read strings from string offsets:
						output[ fieldTbl[3][1] ] = self.bs[ "read" .. fieldTbl[3][2] ](self.bs, output[keyOrOffset] + (relativeOffset or 0))
						self.offsets[#self.offsets].dataType = fieldTbl[3][2]
						self.offsets[#self.offsets].dataName = fieldTbl[3][1]
						--self.offsets[#self.offsets].dataValue = output[ fieldTbl[3][1] ] 
					end
				end
			end
		end
		output.sizeOf = self.bs:tell() - output.startOf
		return output
	end,
	
	-- Writes a struct (in the order of the struct) using data from a Lua dictionary:
	writeStruct = function(self, structName, tableToWrite, startOf, relativeOffset, doInsert)
		self.bs:seek(startOf or tableToWrite.startOf)
		local methodType = (doInsert and "insert") or "write"
		local struct = self.structs[structName]
		for i, fieldTbl in ipairs(struct or {}) do 
			local methodName = fieldTbl[1]
			local keyOrOffset = fieldTbl[2]
			if methodName == "skip" then 
				if doInsert then
					self.bs:insertBytes(keyOrOffset)
				else
					self.bs:skip(keyOrOffset)
				end
			elseif methodName == "seek" then 
				if doInsert then
					self.bs:insertBytes((tableToWrite.startOf + keyOrOffset) - self.bs.pos)
				else
					self.bs:seek(tableToWrite.startOf + keyOrOffset)
				end
			elseif methodName == "align" then
				if doInsert then
					self.bs:insertBytes(self.bs:getAlignedOffset(keyOrOffset) - self.pos)
				else
					self.bs:align(keyOrOffset)
				end
			else
				self.bs[ methodType .. methodName ](self.bs, tableToWrite[keyOrOffset])
				local stringOffset = fieldTbl[3] and (tableToWrite[keyOrOffset] + (relativeOffset or 0))
				if stringOffset then --write strings from string offsets:
					self.bs:writeWString(tableToWrite[ fieldTbl[3][1] ], stringOffset)
				end
			end
		end
		return self.bs:tell()
	end,
	
	-- Inserts a new struct at the given position. If no startOffset is given, it inserts at the end (startOf + sizeOf) of the given dictionary
	insertStruct = function(self, structName, tableToWrite, startOf, relativeOffset)
		local orgSize = self.bs:fileSize()
		startOf = startOf or (tableToWrite.startOf + tableToWrite.sizeOf)
		self:writeStruct(structName, tableToWrite, startOf, relativeOffset, true)
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
}

-- Class for MDF Material files
MDFFile = {
	
	--MDF file extensions by game
	extensions = {
		re2 = ((tdb_ver==66) and ".10") or ".21",
		re3 = ((tdb_ver==67) and ".13") or ".21",
		re8 = ".19",
		re7 = ((tdb_ver==49) and ".6") or ".21",
		dmc5 =".11",
		mhrise = ".23",
	},
	
	-- Creates a new REResource.MDFFile
	new = function(self, args, o)
		o = o or {}
		self.__index = self
		o = REResource:newR(args, setmetatable(o, self))
		o.ext = self.extensions[game_name] or ".?"
		if o.bs.fileExists then
			o:read()
			o:updateStringsBuffer()
		end
		return o
	end,
	
	-- Reads the BitStream and packs the data into organized Lua tables
	read = function(self, start)
		self.bs:seek(start or 0)
		self.offsets = {}
		self.header = self:readStruct("Header")
		self.matCount = self.header.matCount
		self.bs:align(16)
		
		self.matHeaders = {}
		for m = 1, self.matCount do 
			self.matHeaders[m] = self:readStruct("MatHeader")
			self.matHeaders[m].name = self.matHeaders[m].matName
		end
		
		self.texHeaders = {}
		self.bs:seek(self.matHeaders[1].texHdrOffset)
		for m = 1, self.matCount do 
			self.texHeaders[m] = {name=self.matHeaders[m].name}
			for t = 1, self.matHeaders[m].texCount do 
				self.texHeaders[m][t] = self:readStruct("TexHeader")
				self.texHeaders[m][t].name = self.texHeaders[m][t].texType .. ": " .. self.texHeaders[m][t].texPath
				self.texHeaders[m][t].matIdx = m
			end
		end
		
		self.paramHeaders = {}
		self.bs:seek(self.matHeaders[1].paramHdrOffset)
		for m = 1, self.matCount do 
			self.paramHeaders[m] = {}
			for p = 1, self.matHeaders[m].paramCount do 
				local paramHdr = self:readStruct("ParamHeader")
				paramHdr.paramAbsOffset = self.matHeaders[m].paramsOffset + paramHdr.paramRelOffset
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
		self.stringsBuffer = BitStream:new(self.bs:extractBytes(self.stringsSize))
	end,
	
	-- Saves a new MDF file using data from owned Lua tables
	save = function(self, filepath, mesh)
		filepath = filepath or self.filepath:gsub("%.mdf2", "NEW.mdf2")
		if not BitStream.checkFileExists(filepath) then
			re.msg("Not found:\nreframework/data/" .. filepath)
			return false
		end
		self:writeStruct("Header", self.header, 0)
		self.bs:align(16)
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
			self:writeStruct("MatHeader", self.matHeaders[m])
			for t = 1, self.matHeaders[m].texCount do 
				self:writeStruct("TexHeader", self.texHeaders[m][t])
			end
			for p = 1, self.matHeaders[m].paramCount do 
				self:writeStruct("ParamHeader", self.paramHeaders[m][p])
				if self.paramHeaders[m][p].componentCount == 1 then 
					self.bs:writeFloat(self.paramHeaders[m][p].parameter, self.paramHeaders[m][p].paramAbsOffset)
				else
					self.bs:writeArray(self.paramHeaders[m][p].parameter, "Float", self.paramHeaders[m][p].paramAbsOffset)
				end
			end
		end
		self:updateStringsBuffer() --puts the new textures in the buffer for saving
		return (self.bs:save(filepath) and filepath)
	end,
	
	-- Recreates the strings buffer from the Lua tables so that each string is unique in the file
	updateStringsBuffer = function(self)
		local newStringsBuffer = BitStream:new()
		for i, offsetTbl in ipairs(self.offsets) do
			if offsetTbl.dataType == "WString" then
				self.bs:writeUInt64(self.stringsStart + newStringsBuffer:tell(), offsetTbl.readAddress)
				newStringsBuffer:writeWString(offsetTbl.ownerTbl[offsetTbl.dataName])
			end
		end
		log.info(newStringsBuffer:tell() .. " vs " .. self.stringsSize .. ", " ..  (newStringsBuffer:tell() % 16) .. " " .. ((self.stringsSize) % 16))
		while (newStringsBuffer:tell() % 16) ~= (self.stringsSize % 16) do 
			log.info(newStringsBuffer:tell() .. " vs " .. self.stringsSize .. ", " ..  (newStringsBuffer:tell() % 16) .. " " .. ((self.stringsSize) % 16))
			newStringsBuffer:writeByte(0)
		end
		local diff = newStringsBuffer:fileSize() - self.stringsSize
		self.bs:removeBytes(self.stringsSize, self.stringsStart)
		self.bs:insertBytes(newStringsBuffer:fileSize(), self.stringsStart)
		self.bs:writeBytes(newStringsBuffer:getBuffer(), self.stringsStart)
		self:scanFixStreamOffsets(0, self:fileSize(), self.stringsStart + self.stringsSize + diff - 16, self:fileSize() + diff, diff, 8)
		self:read() --reload the buffer into tables
	end,
	
	-- Structures comprising a MDF file:
	structs = {
		Header = {
			{"UInt", "magic"},
			{"Short", "mdfVersion"},
			{"Short", "matCount"},
		},
		
		MatHeader = {
			{"UInt64", "matNameOffset", {"matName", "WString"}},
			{"UInt", "matNameHash"},
			{"UInt", "paramsSize"},
			{"UInt", "paramCount"},
			{"UInt", "texCount"},
			{"UInt", "shaderType"},
			{"UByte", "alphaFlags"},
			{"skip", 3},
			{"UInt64", "paramHdrOffset"},
			{"UInt64", "texHdrOffset"},
			{"UInt64", "paramsOffset"},
			{"UInt64", "mmtrPathOffset", {"mmtrPath", "WString"}},
		},
		
		TexHeader = {
			{"UInt64", "texTypeOffset", {"texType", "WString"}},
			{"UInt", "hash"},
			{"UInt", "asciiHash"},
			{"UInt64", "texPathOffset", {"texPath", "WString"}},
		},
		
		ParamHeader = {
			{"UInt64", "paramNameOffset", {"paramName", "WString"}},
			{"UInt", "hash"},
			{"UInt", "asciiHash"},
			{"UInt", "componentCount"},
			{"UInt", "paramRelOffset"},
		},
	},
}

-- MDFFile struct adjustments for different TDB versions:
if sdk.get_tdb_version() >= 67 then --RE3R+
	table.insert(MDFFile.structs.TexHeader, {"skip", 8})
	MDFFile.structs.ParamHeader[4], MDFFile.structs.ParamHeader[5] = MDFFile.structs.ParamHeader[5], MDFFile.structs.ParamHeader[4]
end

if sdk.get_tdb_version() == 49 then --RE7
	table.insert(MDFFile.structs.MatHeader, 3, {"UInt64", "uknRE7"})
end

if sdk.get_tdb_version() >= 68 then --RE8+
	table.insert(MDFFile.structs.MatHeader, 11, {"UInt64", "firstMaterialNameOffset"})
	table.insert(MDFFile.structs.MatHeader, 6, {"skip", 8})
end


--[[function testInsert()
	MDF = MDFFile:new{"REResources\\pl0003.mdf2.10"}
	MDF:fixOffsets(0, MDF.bs:fileSize(), MDF.matHeaders[#MDF.matHeaders].startOf+MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.bs.size + MDF.matHeaders[#MDF.matHeaders].sizeOf, MDF.matHeaders[#MDF.matHeaders].sizeOf, 8) --
	MDF:insertStruct("MatHeader", MDF.matHeaders[#MDF.matHeaders])
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

return {
	BitStream = BitStream,
	REResource = REResource,
	MeshFile = MeshFile,
	MDFFile = MDFFile,
}