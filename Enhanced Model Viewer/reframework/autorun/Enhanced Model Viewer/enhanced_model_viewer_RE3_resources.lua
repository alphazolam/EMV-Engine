--Enhanced Model Viewer RE3 global resources
--by alphaZomega

local EMV = require("EMV Engine\\EMV Engine.lua")

local game_name = reframework.get_game_name()
local create_resource = EMV.create_resource
local orderedPairs = EMV.orderedPairs
local loaded_resources = false

--a dictionary of tables with 2-3 tables each, one for body and one for face and sometimes one to exclude
local alt_names = {
	["pl20"]= { body=table.pack("pl2[79]%d0"), face=table.pack("pl2[79]%d1"), },
	["pl27"]= { body=table.pack("pl2[09]%d0"), face=table.pack("pl2[09]%d1"), },
	["pl29"]= { body=table.pack("pl2[07]%d0"), face=table.pack("pl2[07]%d1"), },
	["pl00"]= { exclude=table.pack("ACTOR"), }, -- body=table.pack("pl84%d0"), face=table.pack("pl84%d1"),
	["em84"]= { body=table.pack("em0[01]"), face=table.pack("em0[01]"), },
	["em10"]= { body=table.pack("em0[01]"), face=table.pack("em0[01]"), },
}

re.on_application_entry("BeginRendering", function()
	
	if not loaded_resources and game_name == "re3" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		global_motbanks = {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000_facial.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000_jack.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000_jack_facial_pl00.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em0000/animation/bank/em0000_jack_facial_pl20.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em1000/animation/bank/em1000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3000/animation/bank/em3000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3000/animation/bank/em3000_jack.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3000/animation/bank/em3000_jack_facial_pl00.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3300/animation/bank/em3300.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3300/animation/bank/em3300_jack_facial_pl00.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3300/animation/bank/em3300_jack_facial_pl20.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3300/animation/bank/em3300_jack_pl.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3400/animation/bank/em3400.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3400/animation/bank/em3400_jack_facial_pl20.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3400/animation/bank/em3400_jack_pl.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3500/animation/bank/em3500.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3500/animation/bank/em3500_jack_facial_pl20.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3500/animation/bank/em3500_jack_pl.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em3600/animation/bank/em3600.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em4000/animation/bank/em4000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em4000/animation/bank/em4000_jack_facial_pl20.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em4000/animation/bank/em4000_jack_pl.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em7000/animation/bank/em7000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9000/animation/bank/em9000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9000/animation/bank/em9000_facial.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9000/animation/bank/em9000_jack.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9000/animation/bank/em9000_jack_facial_pl2000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9000/animation/bank/em9100.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9200/animation/bank/em9200.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9200/animation/bank/em9200_jack_facial_pl2000.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/animation/bank/em9300.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/animation/bank/em9300_jack.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/animation/bank/em9300_pl2000_facial.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/em9301/animation/bank/em9301.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/em9302/animation/bank/em9302.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9300/em9330/bank/em9330.motbank")
			table.insert(all_motbanks, "escape/character/enemy/em9400/animation/bank/em9400.motbank")
			table.insert(all_motbanks, "escape/character/player/common/animation/bank/espl_common_bk.motbank")
			table.insert(all_motbanks, "escape/character/player/common/animation/bank/espl_common_facial.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/barehand.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp0200.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp0300.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp2000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp2100.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp3000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp4500.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp6200.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/bank/wp6300.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/pl0000face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/barehand.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp0000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp0100.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp0300.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp0600.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp1000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp2000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp2100.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp3000.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp3100.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp4100.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp4510.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp4520.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp4600.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/bank/wp6200.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/pl2000body_cutscenes.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/pl2000face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2000/animation/pl2000face_cutscenes.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2700/animation/pl2700face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2900/animation/bank/barehand.motbank")
			table.insert(all_motbanks, "escape/character/player/pl2900/animation/bank/pl2900face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl4000/animation/pl4000face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl5000/animation/pl5000face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl8000/animation/pl8000face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl8010/animation/pl8010face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/pl0000body_cutscenes.motbank")
			table.insert(all_motbanks, "escape/character/player/pl8030/animation/pl8030face.motbank")
			table.insert(all_motbanks, "escape/character/player/pl0000/animation/pl0000face_cutscenes.motbank")
			table.insert(all_motbanks, "sectionroot/animation/player/common/pl_common_facial.motbank")
			
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
			table.insert(bgs, "escape/light/ibl/ibl_moon2.tex")
			table.insert(bgs, "escape/light/ibl/ibl_night00.tex")
			table.insert(bgs, "escape/light/ibl/ibl_night01.tex")
			table.insert(bgs, "escape/light/ibl/ibl_sunrise_01.tex")
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