--BitStream Lua class for REFramework
--alphaZomega, July 22 2022

BitStream = {
	
	name = "BitStream",
	
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
			--re.msg("opened " .. filepath .. ", " .. tostring(file))
			if file then
				o.file:write(file:read("*a"))
				file:close()
				o.file:seek("set", 0)
				o.fileExists = true
			end
		end
		o.name = (o.filepath and (o.filepath:match("^.+/(.+)") or o.filepath))
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
				self:fileSize()
			else
				return false
			end
		end
		self.pos = newPos
		return self.file:seek("set", newPos)
	end,
	
	-- Moves 'numBytes' into the stream, relative to the current position
	skip = function(self, numBytes, insertIfEOF)
		return self:seek(numBytes, true, insertIfEOF)
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
		self.file:seek("set", pos or 0)
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
						strVal = ((strVal and strVal:match("^(.-%z%z%z)")) or '')
						numBytes = strVal:len()
						strVal = strVal:gsub("%z", "")
					else --Strings:
						strVal = strVal:match("^(.-%z)")
						numBytes = strVal:len()
						strVal = strVal:gsub("%z$", "")
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
		self.file:seek("set", pos)
		if fmtString then
			local strVal = string.pack(fmtString, value or 0)
			self.file:write(string.pack(fmtString, value))
		elseif fmtString==false then --WStrings:
			local wstr = {}
			for c in value:gmatch'.' do
				wstr[#wstr+1] = c .. "\0"
			end
			numBytes = (value:len()+1) * 2
			self.file:write(table.concat(wstr) .. "\0\0")
		else --Strings:
			numBytes = value:len() + 1
			self.file:write(value .. "\0\0")
		end
		
		if doSkip then 
			self.pos = self.pos + numBytes
		end
		
		self.size = self.file:seek("end")
		self.file:seek("set", self.pos)
		
		return self.pos
	end,
	
	-- Writes a stringbuffer (or creates one of the given size) to the given or current position
	writeBytes = function(self, strBufferOrSize, pos)
		local npos = pos or self.pos
		self.file:seek("set", npos) 
		if type(strBufferOrSize)=="number" then
			strBufferOrSize = string.pack("c" .. strBufferOrSize, "\0")
		end
		self.file:write(strBufferOrSize)
		if not pos then self.pos = self.file:seek("cur", 0) end
		self.size = self.file:seek("end")
		self.file:seek("set", self.pos)
	end,
	
	-- Deletes 'numBytes' bytes at the given position 'pos' or current position
	removeBytes = function(self, numBytes, pos)
		local npos = pos or self.pos
		self.file:seek("set", 0) 
		local strBuffer = self.file:read(npos)
		self.file:seek("cur", numBytes)
		strBuffer = strBuffer .. self.file:read("*a")
		self.file = io.tmpfile():write(strBuffer)
		self.size = self.file:seek("end")
		self.file:seek("set", npos)
	end,
	
	-- Inserts 'numBytes' bytes at the given position 'pos' or current position
	insertBytes = function(self, numBytes, pos)
		if numBytes <= 0 then return end
		local npos = pos or self.pos
		self.file:seek("set", 0) 
		local strBuffer = self.file:read(npos) .. string.pack("c" .. numBytes, "\0") .. self.file:read("*a")
		self.file = io.tmpfile():write(strBuffer)
		self.size = self.file:seek("end")
		if not pos then
			self:seek(npos + numBytes)
		end
	end,
	
	-- Returns a Lua table array of x bytes read from the current or given position
	readBytes = function(self, numBytes, pos)
		local npos = pos or self.pos
		local result = {}
		
		self.file:seek("set", npos)
		local str = self.file:read(numBytes)
		for c in (str or ''):gmatch'.' do
			result[#result+1] = c:byte()
		end
		self.file:seek("set", self.pos)
		
		if pos then 
			self:seek(pos + numBytes)
		end
		return result
	end,
	
	-- Returns a string buffer of size 'numBytes' from the given position 'pos' (or current position), or as a Lua filestream if 'asFileStream' is true
	extractBytes = function(self, numBytes, pos, asFileStream)
		local npos = pos or self.pos
		self.file:seek("set", npos) 
		local strBuffer = self.file:read(numBytes or "*a")
		self.file:seek("set", self.pos) 
		return (asFileStream and io.tmpfile():write(strBuffer)) or strBuffer
	end,
	
	-- Returns a new Lua filestream of size 'numBytes' from the given position 'pos' (or current position)
	extractStream = function(self, numBytes, pos)
		return self:extractBytes(numBytes, pos, true)
	end,
	
	copyFile = function(self, oldLocation, newLocation)
		oldLocation = oldLocation or self.filepath
		local bs = self:new(oldLocation)
		if bs and bs.fileExists then 
			bs:save(newLocation)
		end
	end,
	
	--[[extractTable = function(self, numBytes, pos)
		local fullTbl = self:getBuffer(true)
		local result = {}
		local npos = pos or self.pos
		for i=npos+1, npos+numBytes do
			table.insert(result, fullTbl[i])
		end
		return result
	end,]]
	
	-- Returns the next address ahead of 'pos' or the current position that is aligned to the given 'alignment'
	getAlignedOffset = function(self, alignment, pos)
		local npos = (pos or self.pos)-- + (self.alignShift or 0)
		local mod = npos % alignment
		return npos + ((mod > 0) and (alignment - mod) or 0)
	end,
	
	-- Seeks from 'pos' or the current position to the next address ahead that is aligned to the given 'alignment', inserting bytes to reach it if at End of File
	align = function(self, alignment, pos)
		local npos = (pos or self.pos)-- + (self.alignShift or 0)
		local mod = npos % alignment
		return self:seek(npos + ((mod > 0) and (alignment - mod) or 0), nil, true)
	end,
	
	--returns the next position (from a given position or the current position) aligned to 16bytes with the position 'targetPos'
	matchAlignment = function(self, targetPos, pos)
		local npos = pos or self.pos
		while npos % 16 ~= targetPos % 16 do 
			npos = npos + 1
		end
		return npos
	end,
	
	-- writes 00's from the given or current position to the next position aligned 16-bytes with 'targetPos'
	padToAlignment = function(self, targetPos, pos)
		local npos = pos or self.pos
		local alignedPos = self:matchAlignment(targetPos, npos)
		self:insertBytes(alignedPos - npos)
	end,
	
	-- returns if a float is likely at the given or current position
	detectedFloat = function(self, pos)
		local npos = pos or self.pos
		local float = self:readFloat(npos)
		lastPos = {self, npos}
		return (self:readUByte(npos+3) < 255 and (float==0 or (math.abs(float) > 0.0000001 and math.abs(float) < 10000000)))
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
	 
	readGUID = function(self, pos)
		local npos = pos or self.pos
		log.info("reading GUID at " .. self:tell())
		local output = self:read(npos, 16, nil, false)
		if not pos then 
			self.pos = self.pos+16
		end
		self:seek(self.pos)
		log.info("now at " .. self:tell())
		return output
	end,
	
	--Reads an array of 'numVars' variables of the same format from position 'pos' or the current position
	readArray = function(self, numVars, fmtString, pos, doSkip)
		local npos = pos or self.pos
		local size = 0
		local fmt = self.fmts[fmtString]
		fmtString = "<" .. fmtString:gsub("<", "")
		local fmtSize = self.fmtSizes[fmt or fmtString]
		local output = {}
		for i = 1, numVars do 
			output[i] = self:read(npos + size, fmtSize, fmt or ((elemType~="string") and fmtString) or fmt, doSkip or not pos)
			size = size + (fmtSize or ((element:len()+1) * ((fmt==false and 2) or 1)))
		end
		return output
	end,
	
	readMat4 = function(self, pos)
		local npos = pos or self.pos
		return Matrix4x4f.new(
			Vector4f.new(table.unpack(self:readArray(4, "Float", npos,    not pos))),
			Vector4f.new(table.unpack(self:readArray(4, "Float", npos+16, not pos))),
			Vector4f.new(table.unpack(self:readArray(4, "Float", npos+32, not pos))),
			Vector4f.new(table.unpack(self:readArray(4, "Float", npos+48, not pos)))
		)
	end,
	
	readVec4 = function(self, pos)
		local npos = pos or self.pos
		return Vector4f.new(table.unpack(self:readArray(4, "Float", npos, not pos)))
	end,
	
	readVec3 = function(self, pos)
		local npos = pos or self.pos
		return Vector3f.new(table.unpack(self:readArray(3, "Float", npos, not pos)))
	end,
	
	readVec2 = function(self, pos)
		local npos = pos or self.pos
		return Vector2f.new(table.unpack(self:readArray(2, "Float", npos, not pos)))
	end,
	
	readOBB = function(self, pos)
		local npos = pos or self.pos
		return self:readArray(20, "Float", npos, not pos)
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
	
	writeGUID = function(self, value, pos)
		local npos = pos or self.pos
		self:seek(npos)
		self.file:write(value)
		if not pos then 
			self.pos = self.pos+16
		end
		return self:seek(self.pos)
	end,
	
	--Writes an array of variables of the same format
	writeArray = function(self, arrayTbl, fmtString, pos, doSkip)
		local npos = pos or self.pos
		local size = 0
		local fmt = self.fmts[fmtString]
		fmtString = "<" .. fmtString:gsub("<", "")
		local fmtSize = self.fmtSizes[fmt or fmtString]
		for i, element in ipairs(arrayTbl) do 
			local elemType = type(element)
			self:write(npos + size, fmtSize, fmt or ((elemType~="string") and fmtString) or fmt, element, doSkip or not pos)
			size = size + (fmtSize or ((element:len()+1) * ((fmt==false and 2) or 1)))
		end
		return self:tell()
	end,
	
	writeMat4 = function(self, mat4, pos)
		local npos = pos or self.pos
		local out = self:writeArray((type(mat4)=="table" and mat4) or {
			mat4[0].x, mat4[0].y, mat4[0].z, mat4[0].w,
			mat4[1].x, mat4[1].y, mat4[1].z, mat4[1].w,
			mat4[2].x, mat4[2].y, mat4[2].z, mat4[2].w,
			mat4[3].x, mat4[3].y, mat4[3].z, mat4[3].w,
		}, "<f", npos, not pos)
		return out
	end,
	
	writeVec4 = function(self, vec4, pos)
		local npos = pos or self.pos
		return self:writeArray((type(vec4)=="table" and vec4) or {vec4.x, vec4.y, vec4.z, vec4.w}, "Float", npos, not pos)
	end,
	
	writeVec3 = function(self, vec3, pos)
		local npos = pos or self.pos
		return self:writeArray((type(vec3)=="table" and vec3) or {vec3.x, vec3.y, vec3.z}, "Float", npos, not pos)
	end,
	
	writeVec2 = function(self, vec2, pos)
		local npos = pos or self.pos
		return self:writeArray((type(vec2)=="table" and vec2) or {vec2.x, vec2.y}, "Float", npos, not pos)
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
	
	insertMat4 = function(self, mat4, pos)
		local npos = pos or self.pos
		self:insertBytes(64, npos)
		return self:writeArray((type(mat4)=="table" and mat4) or {
			mat4[0].x, mat4[0].y, mat4[0].z, mat4[0].w,
			mat4[1].x, mat4[1].y, mat4[1].z, mat4[1].w,
			mat4[2].x, mat4[2].y, mat4[2].z, mat4[2].w,
			mat4[3].x, mat4[3].y, mat4[3].z, mat4[3].w,
		}, npos, not pos)
	end,
	
	insertVec4 = function(self, vec4, pos)
		local npos = pos or self.pos
		self:insertBytes(16, npos)
		return self:writeArray((type(vec4)=="table" and vec4) or {vec4.x, vec4.y, vec4.z, vec4.w}, npos, not pos)
	end,
	
	insertVec3 = function(self, vec3, pos)
		local npos = pos or self.pos
		self:insertBytes(12, npos)
		return self:writeArray((type(vec3)=="table" and vec3) or {vec3.x, vec3.y, vec3.z}, npos, not pos)
	end,
	
	insertVec2 = function(self, vec2, pos)
		local npos = pos or self.pos
		self:insertBytes(8, npos)
		return self:writeArray((type(vec2)=="table" and vec2) or {vec2.x, vec2.y}, npos, not pos)
	end,
}

return {
	BitStream = BitStream,
}