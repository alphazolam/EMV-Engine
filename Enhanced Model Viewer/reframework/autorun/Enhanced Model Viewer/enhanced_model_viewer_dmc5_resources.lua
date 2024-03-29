--Enhanced Model Viewer DMC5 global resources
--by alphaZomega
--if true then return {} end
local EMV = require("EMV Engine")

local game_name = reframework.get_game_name()
local ran_once = false
local create_resource = EMV.create_resource
local orderedPairs = EMV.orderedPairs
local loaded_resources = false
local bgs = {}

--a dictionary of tables with 2-3 tables each, one for Body and one for Face and sometimes one to exclude
local alt_names = { 
	["em5800"]= { exclude=table.pack("em5801", "em5802", "em5800_%d%d") },
	["em5801"]= { exclude=table.pack("em5800", "em5802", "em5801_%d%d") },
	["em5802"]= { exclude=table.pack("em5800", "em5801", "em5802_%d%d") },
}

re.on_application_entry("UpdateMotion", function()
	
	if not ran_once and game_name == "dmc5" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		global_motbanks = global_motbanks or {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		ran_once = true
		EMVSettings.init_EMVSettings()
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "animation/enemy/em6000/em6000.motbank")
			table.insert(all_motbanks, "animation/enemy/em5700/em5700_king_cerberus.motbank")
			table.insert(all_motbanks, "animation/player/pl0800/pl0800.motbank")
			table.insert(all_motbanks, "props/mesh/sm1083_weightfloor_c/level/sm1083_weightfloor_c.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_12/motbank/em5801_12_02.motbank")
			table.insert(all_motbanks, "animation/player/pl0300_vergil/pl0300_01_head/pl0300_01_head.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission15/etc/v/pl0200_ev.motbank")
			table.insert(all_motbanks, "props/mesh/sm0502_steelplate/level/sm0502_steelplate.motbank")
			table.insert(all_motbanks, "event/mission02/m02_110c/motionbank/m02_110c_pl0400_11_ev01.motbank")
			table.insert(all_motbanks, "event/mission02/m02_110c/motionbank/m02_110c_pl0400_ev01.motbank")
			table.insert(all_motbanks, "props/mesh/sm0151_qliphothshutterdoor01/level/sm0151_qliphothshutterdoor01_level.motbank")
			table.insert(all_motbanks, "animation/enemy/em2100/em2100_minelauncher.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em6000.motbank")
			table.insert(all_motbanks, "animation/enemy/wpem5900_01/wpem5900_01.motbank")
			table.insert(all_motbanks, "animation/enemy/wpem5900_02/wpem5900_02.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_15/em5801_15.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_12/motbank/em5801_12.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_11/motbank/em5801_11.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_10/motbank/em5801_10.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_09/motbank/em5801_09.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_08/em5801_08.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_07/em5801_07.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_06/motbank/em5801_06.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_05/motbank/em5801_05.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_03/em5801_03.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_02/em5801_02.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801_00/wp5801_00.motbank")
			table.insert(all_motbanks, "animation/enemy/em5400/em5400_11_gilgamesh_r_hand.motbank")
			table.insert(all_motbanks, "animation/enemy/em5400/em5400_10_gilgamesh_l_hand.motbank")
			table.insert(all_motbanks, "animation/enemy/em5300_00/em5300_00_artemis_bit.motbank")
			table.insert(all_motbanks, "animation/enemy/em5200_02/em5200_02_nidhogg_tentacle.motbank")
			table.insert(all_motbanks, "animation/enemy/em5200_01/em5200_01_nidhogg_body.motbank")
			table.insert(all_motbanks, "animation/enemy/em5000/shl5000_000_suction.motbank")
			table.insert(all_motbanks, "animation/enemy/em5100/em5100_00/em5100_00_witches.motbank")
			table.insert(all_motbanks, "animation/enemy/em0000_00/em0000_00.motbank")
			table.insert(all_motbanks, "animation/enemy/em5400/em5400_20/em5400_20_homing.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_006/wp01_006_01.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_008_01/motbank/wp01_008_01.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_008_00/motbank/wp01_008_00.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_003/wp01_003.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_001_01/wp01_001_01.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_001_00/wp01_001_00.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_009/motbank/wp01_009_emperor_l.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_009/motbank/wp01_009_emperor_r.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_007/motbank/wp01_007_cerberus_triplet.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_007/motbank/wp01_007_cerberus_pole.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_007/motbank/wp01_007_cerberus_nunchaku.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_004/wp01_004.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_006_00/motbank/wp01_006_00.motbank")
			table.insert(all_motbanks, "animation/weapon/wp01_005/motbank/wp01_005_spada.motbank")
			table.insert(all_motbanks, "animation/player/pl0200_v/pl0200_03/pl0200_03.motbank")
			table.insert(all_motbanks, "animation/player/pl0200_v/pl0200_01_head/pl0200_01_head.motbank")
			table.insert(all_motbanks, "animation/player/pl0100_dante/pl0100_01_head/pl0100_01_head.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_07_wingl/pl0010_07_closedwingl.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_06_wingr/pl0010_06_closedwingr.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_09_wirel/pl0010_09_wirel.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_08_wirer/pl0010_08_wirer.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_21_busterarml/pl0010_21_busterarml.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_20_busterarmr/pl0010_20_busterarmr.motbank")
			table.insert(all_motbanks, "animation/player/pl0000_nero/pl0000_01_head/pl0000_01.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_002/wp00_002.motbank")
			table.insert(all_motbanks, "animation/weapon/wp000/wp000.motbank")
			table.insert(all_motbanks, "event/gimmick/m20_010c/motionbank/m20_010c_wp01_006_ev01.motbank")
			table.insert(all_motbanks, "event/gimmick/m20_010c/motionbank/m20_010c_pl0100_11_ev01.motbank")
			table.insert(all_motbanks, "event/gimmick/m20_010c/motionbank/m20_010c_pl0100_ev01.motbank")
			table.insert(all_motbanks, "props/mesh/sm0906_m14finaldoor/level/motion/sm0906_014finaldoor.motbank")
			table.insert(all_motbanks, "animation/enemy/em2001/em2001_summonedtable_03.motbank")
			table.insert(all_motbanks, "animation/enemy/em2000/em2000_summonedtable.motbank")
			table.insert(all_motbanks, "animation/enemy/em5600_02/em5600_02_helltree_l_tentacle.motbank")
			table.insert(all_motbanks, "animation/enemy/em5600_00/em5600_00_helltree_l_tentacle.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_021/wp00_021.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_017/wp00_017.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_016/wp00_016.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_015/wp00_015.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_014/wp00_014.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_013/wp00_013.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_012/wp00_012.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_011/wp00_011.motbank")
			table.insert(all_motbanks, "animation/enemy/em5900/em5900_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5901_02/em5901_02_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5901_01/em5901_01_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5901/em5901_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_09/em5902_09_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_07/em5902_07_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_06/em5902_06_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_05/em5902_05_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_04/em5902_04_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_02/em5902_02_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_01/em5902_01_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902_00/em5902_00_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5902/em5902_urizen.motbank")
			table.insert(all_motbanks, "animation/enemy/em5700/em5700_00_king_cerberus_head.motbank")
			table.insert(all_motbanks, "animation/enemy/em5600/em5600_helltree_l.motbank")
			table.insert(all_motbanks, "animation/enemy/em5501/em5501_angelo_gabriello.motbank")
			table.insert(all_motbanks, "animation/enemy/em5500/em5500_00.motbank")
			table.insert(all_motbanks, "animation/enemy/em5500/em5501_weapon/em5501_geryon_weapon.motbank")
			table.insert(all_motbanks, "animation/enemy/em5500/em5501/em5501_geryon_angelo_gabriello.motbank")
			table.insert(all_motbanks, "animation/enemy/em5500/em5500_geryon.motbank")
			table.insert(all_motbanks, "animation/enemy/em5400/em5400_gilgamesh.motbank")
			table.insert(all_motbanks, "animation/enemy/em5300/em5300_artemis.motbank")
			table.insert(all_motbanks, "animation/enemy/em5200/em5200_nidhogg.motbank")
			table.insert(all_motbanks, "animation/enemy/em5100/em5100/em5100_malphas.motbank")
			table.insert(all_motbanks, "animation/enemy/em5000/em5000_goliath.motbank")
			table.insert(all_motbanks, "animation/enemy/em1000/em1000_hell_tree_s.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0801.motbank")
			table.insert(all_motbanks, "animation/enemy/em0801/em0801_fire_byakhee.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0800.motbank")
			table.insert(all_motbanks, "animation/enemy/em0800/em0800_byakhee.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0700.motbank")
			table.insert(all_motbanks, "animation/enemy/em0700/em0700_sin_scissors.motbank")
			table.insert(all_motbanks, "animation/enemy/em0601/em0601_proto_angelo.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0600.motbank")
			table.insert(all_motbanks, "animation/enemy/em0600/em0600_scudo_angelo.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0500.motbank")
			table.insert(all_motbanks, "animation/enemy/em0500/em0500_nobody.motbank")
			table.insert(all_motbanks, "animation/enemy/em0400/em0400_behemoth.motbank")
			table.insert(all_motbanks, "animation/enemy/em0301/em0301_lusachia.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0300.motbank")
			table.insert(all_motbanks, "animation/enemy/em0300/em0300_baphomet.motbank")
			table.insert(all_motbanks, "animation/enemy/em0202/em0202_riot_red.motbank")
			table.insert(all_motbanks, "animation/enemy/em0201/em0201_riot_slasher.motbank")
			table.insert(all_motbanks, "animation/enemy/em0200/em0200_riot.motbank")
			table.insert(all_motbanks, "animation/enemy/em0103/em0103_empusa_soldier.motbank")
			table.insert(all_motbanks, "animation/enemy/em0102/em0102_empusa_keeper.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0101.motbank")
			table.insert(all_motbanks, "animation/enemy/em0101/em0101_empusa_medic.motbank")
			table.insert(all_motbanks, "animation/enemy/em0100/em0100_empusa_scout.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans_em0002.motbank")
			table.insert(all_motbanks, "animation/enemy/em0002/em0002_hell_judecca.motbank")
			table.insert(all_motbanks, "animation/enemy/em0001/em0001_hell_antenora.motbank")
			table.insert(all_motbanks, "animation/enemy/commondamage/commondamagetrans.motbank")
			table.insert(all_motbanks, "animation/enemy/em0000/em0000_hell_caina.motbank")
			table.insert(all_motbanks, "animation/weapon/wp00_010/wp00_010.motbank")
			table.insert(all_motbanks, "props/mesh/sm0150_qliphothstepbox01_01/level/sm0150_qliphothstepbox01_01_level.motbank")
			table.insert(all_motbanks, "event/gimmick/m21_110c/motionbank/m21_110c_pl0400_11_ev01.motbank")
			table.insert(all_motbanks, "event/gimmick/m21_110c/motionbank/m21_110c_pl0400_ev01.motbank")
			table.insert(all_motbanks, "animation/player/pl0500_lady/pl0500_01_head/pl0500_01_head.motbank")
			table.insert(all_motbanks, "animation/player/pl0300/pl0300.motbank")
			table.insert(all_motbanks, "animation/enemy/em5802/em5802_nightmare.motbank")
			table.insert(all_motbanks, "animation/enemy/em5801/em5801_shadow.motbank")
			table.insert(all_motbanks, "animation/enemy/em5800/em5800_griffon.motbank")
			table.insert(all_motbanks, "animation/player/pl0200/pl0200.motbank")
			table.insert(all_motbanks, "animation/player/pl0110/fbx/pl0110_01_head/pl0110_01_head.motbank")
			table.insert(all_motbanks, "animation/player/pl0100/pl0100.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_05_wingl/pl0010_05_wingl.motbank")
			table.insert(all_motbanks, "animation/player/pl0010/pl0010_04_wingr/pl0010_04_wingr.motbank")
			table.insert(all_motbanks, "animation/player/pl0000/pl0000_catch.motbank")
			table.insert(all_motbanks, "animation/player/commondamage/commondamagetrans.motbank")
			table.insert(all_motbanks, "animation/player/pl0000/pl0000.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission10/npc/pl0500/m10_wp01_008_00.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission10/npc/pl0500/m10_wp05_008.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission10/npc/pl0600/m10_pl0600.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission10/npc/pl0500/m10_pl0500.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission01/mob/pl0400_ev01/m01_it1006_ev01.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission01/mob/pl0400_ev01/m01_pl0400_11_ev01.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission01/mob/pl0400_ev01/m01_pl0400_ev01.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission01/mob/pl2000_ev01/m01_pl2000_11_ev01.motbank")
			table.insert(all_motbanks, "leveldesign/mission/mission01/mob/pl2000_ev01/m01_pl2000_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/em5801_shadow/em5801_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/em5800_griffin/em5800_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0700_morrison/pl0700_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0700_morrison/pl0700_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0600_trish/pl0610_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0600_trish/pl0600_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0600_trish/pl0600_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0540_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0540_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0520_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0520_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0510_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0500_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0500_lady/pl0500_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0400_nico/pl0400_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0400_nico/pl0400_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0300_vergil/pl0300_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0300_vergil/pl0300_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0200_v/pl0200_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0200_v/pl0200_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0100_dante/pl0130_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0100_dante/pl0130_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0000_nero/pl0000_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0000_nero/pl0000_11_ev01.motbank")
			table.insert(all_motbanks, "menu/mission/animation/menuenv_tariler.motbank")
			table.insert(all_motbanks, "menu/mission/animation/pl0400_nico/nico_face_cutscenes.motbank")
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
		
		if true then
			table.insert(bgs, "scene/menu/gallery/viewer/greenscreen.tex")
			table.insert(bgs, "light/shop/cubemap/ibl_shop_bright.tex")
			table.insert(bgs, "light/gallery/modelviewer/cubemap/ibl_modelviewer.tex")
			table.insert(bgs, "light/mission22/cubemap/ibl_m22_02.tex")
			table.insert(bgs, "light/mission22/cubemap/ibl_m22_01.tex")
			table.insert(bgs, "light/mission20/cubemap/ibl_m20_add.tex")
			table.insert(bgs, "light/mission20/cubemap/ibl_m20.tex")
			table.insert(bgs, "light/mission19/cubemap/ibl_m19_add.tex")
			table.insert(bgs, "light/mission19/cubemap/ibl_m19.tex")
			table.insert(bgs, "light/mission18/cubemap/ibl_m18.tex")
			table.insert(bgs, "light/mission17/cubemap/ibl_m17_01.tex")
			table.insert(bgs, "light/mission17/cubemap/ibl_m17.tex")
			table.insert(bgs, "light/mission16/cubemap/ibl_m16_02.tex")
			table.insert(bgs, "light/mission15/cubemap/ibl_m15.tex")
			table.insert(bgs, "light/mission09/cubemap/ibl_m09_add.tex")
			table.insert(bgs, "light/mission09/cubemap/ibl_m09.tex")
			table.insert(bgs, "light/mission08/cubemap/ibl_m08.tex")
			table.insert(bgs, "light/mission06/cubemap/ibl_m06_add_03.tex")
			table.insert(bgs, "light/mission06/cubemap/ibl_m06_06.tex")
			table.insert(bgs, "light/mission06/cubemap/ibl_m06.tex")
			table.insert(bgs, "light/mission03/cubemap/ibl_m03_add.tex")
			table.insert(bgs, "light/mission03/cubemap/ibl_m03.tex")
			table.insert(bgs, "light/mission02/cubemap/ibl_m02_01_add.tex")
			table.insert(bgs, "light/mission02/cubemap/ibl_m02_01.tex")
			table.insert(bgs, "light/mission02/cubemap/ibl_m02_00_add.tex")
			table.insert(bgs, "light/mission02/cubemap/ibl_m02_00.tex")
			table.insert(bgs, "light/mission01/cubemap/ibl_m01_00_add.tex")
			table.insert(bgs, "light/mission01/cubemap/ibl_m01_00.tex")
			table.insert(bgs, "light/location63/cubemap/ibl_l63.tex")
			table.insert(bgs, "light/location62/cubemap/ibl_l62.tex")
			table.insert(bgs, "light/location60/cubemap/ibl_l60.tex")
			table.insert(bgs, "light/location57/cubemap/ibl_l57.tex")
			table.insert(bgs, "light/location56/cubemap/ibl_l56.tex")
			table.insert(bgs, "light/location55/cubemap/ibl_l55.tex")
			table.insert(bgs, "light/location52/cubemap/ibl_l52.tex")
			table.insert(bgs, "light/location51/cubemap/ibl_l51_add.tex")
			table.insert(bgs, "light/location51/cubemap/ibl_l51.tex")
			table.insert(bgs, "light/location50/cubemap/ibl_l50.tex")
			table.insert(bgs, "light/gallery/trailer/cubemap/ibl_gallery_trailer.tex")
			table.insert(bgs, "light/mission07/cubemap/ibl_07_eventbossarea_add_02.tex")
			table.insert(bgs, "light/mission07/cubemap/ibl_07_eventbossarea.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_12_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_11_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_10_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_09_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_07_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_05_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_04_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_03_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_02_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_01_hires.tex")
			table.insert(bgs, "prefab/leveldesign/secretmissionwarp/localcubemap/lc_secret_00.tex")
			table.insert(bgs, "light/mission17/cubemap/lc_l17_01_sunny_hires.tex")
			table.insert(bgs, "light/mission17/cubemap/lc_l17_01_hires.tex")
			table.insert(bgs, "scene/menu/menuenvironment/secretmissionmenu/light/cubemap/lc_l04_01_outside_02_hires.tex")
			table.insert(bgs, "ui/mesh/creditglassreflection/tex/creditglass_localcubemap.tex")
			table.insert(bgs, "streaming/environments/location/textures/l16_cubemap_albm.tex")
			table.insert(bgs, "light/mission01/cubemap/ibl_m01_add.tex")
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