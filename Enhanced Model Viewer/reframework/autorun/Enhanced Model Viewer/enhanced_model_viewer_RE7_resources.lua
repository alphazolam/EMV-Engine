--Enhanced Model Viewer RE7 global resources
--by alphaZomega

--This file a placeholder for RE7 resources

local EMV = require("EMV Engine")

local game_name = reframework.get_game_name()
local create_resource = EMV.create_resource
local orderedPairs = EMV.orderedPairs
local loaded_resources = false
local bgs = {}

--a dictionary of tables with 2-3 tables each, one for body and one for face and sometimes one to exclude
--The mesh name of the object is searched for the key
local alt_names = {
	--["em5801"]= { Body=table.pack("ch13_00"), Face=table.pack("asdf"), exclude=table.pack("ch07_20") } --example
}

re.on_application_entry("BeginRendering", function()
	
	if not loaded_resources and game_name == "re7" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		global_motbanks = global_motbanks or {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		EMVSettings.init_EMVSettings()
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000.motbank")
		end
		
		for i, bank_string in ipairs(all_motbanks) do 
			local bank
			local bank_name = bank_string:lower() --bank_string:match("^.+/(.+)%.motbank") or bank_string
			--pcall(function()
				bank = create_resource(bank_string, "via.motion.MotionBankResource")
			--end)
			if bank then
				global_motbanks[bank_name] = bank
				RSCache.motbank_resources[bank_name] = bank
			end
		end
		
		for bank_name, bank in pairs(RSCache.motbank_resources) do 
			global_motbanks[bank_name] = bank
		end
		
		--[[for bank_name, bank in pairs(RSCache.motbank_resources) do 
			if bank_name ~= " " and not bank_name:find("not_set") then
				global_motbanks[bank_name] = bank
			end
		end]]
		
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

local function reset()
	loaded_resources = false
end

return {
	backgrounds = bgs,
	alt_names = alt_names,
	finished = finished,
	reset = reset,
}