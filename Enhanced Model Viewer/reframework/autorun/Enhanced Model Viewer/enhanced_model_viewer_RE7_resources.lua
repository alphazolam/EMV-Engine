--Enhanced Model Viewer RE7 global resources
--by alphaZomega

--This file a placeholder for RE7 resources

local EMV = require("EMV Engine")

local game_name = reframework.get_game_name()
local create_resource = EMV.create_resource
local orderedPairs = EMV.orderedPairs
local loaded_resources = false

--a dictionary of tables with 2-3 tables each, one for body and one for face and sometimes one to exclude
local alt_names = {
	--[[["pl20"]= { body=table.pack("pl2[79]%d0"), face=table.pack("pl2[79]%d1"), },
	["pl27"]= { body=table.pack("pl2[09]%d0"), face=table.pack("pl2[09]%d1"), },
	["pl29"]= { body=table.pack("pl2[07]%d0"), face=table.pack("pl2[07]%d1"), },
	["pl00"]= { exclude=table.pack("ACTOR"), }, -- body=table.pack("pl84%d0"), face=table.pack("pl84%d1"),
	["em84"]= { body=table.pack("em0[01]"), face=table.pack("em0[01]"), },
	["em10"]= { body=table.pack("em0[01]"), face=table.pack("em0[01]"), },]]
}

re.on_application_entry("BeginRendering", function()
	
	if not loaded_resources and game_name == "re7" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		global_motbanks = {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000.motbank")
		end
		
		for i, bank_string in ipairs(all_motbanks) do 
			local bank
			local bank_name = bank_string --bank_string:match("^.+/(.+)%.motbank") or bank_string
			pcall(function()
				bank = create_resource(bank_string, "via.motion.MotionBankResource")
			end)
			if bank then
				global_motbanks[bank_name] = bank
			end
		end
		
		for bank_name, bank in pairs(global_motbanks) do 
			RSCache.motbank_resources[bank_name] = bank
		end
		for bank_name, bank in pairs(RSCache.motbank_resources) do 
			global_motbanks[bank_name] = bank
		end
		
		--[[for bank_name, bank in pairs(RSCache.motbank_resources) do 
			if bank_name ~= " " and not bank_name:find("not_set") then
				global_motbanks[bank_name] = bank
			end
		end]]
		
		local bgs = {}
		if true then			
			table.insert(bgs, "escape/light/ibl/ibl_ev580_sunrise.tex")
		end
		
		for i, bg_string in ipairs(bgs) do 
			local tex_resource = create_resource(bg_string, "via.render.TextureResource")
			if tex_resource then 
				--local bg_name = bg_string:match("^.+/(.+)%.tex") or bg_string
				local bg_name = tex_resource:call("ToString"):match("^.+%[@?(.+)%]")
				RSCache.tex_resources[bg_name] = tex_resource
			end
		end
		
		loaded_resources = true
	end
end)

local function finished()
	return loaded_resources
end

return {
	alt_names = alt_names,
	finished = finished,
}