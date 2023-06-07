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
	--["em5800"]= { exclude=table.pack("em5801", "em5802", "em5800_%d%d") },
	--["em5801"]= { exclude=table.pack("em5800", "em5802", "em5801_%d%d") },
	--["em5802"]= { exclude=table.pack("em5800", "em5801", "em5802_%d%d") },
}

local fig_names = {
    FigureModel_Figure00_010 = "cha0",
    FigureModel_Figure00_020 = "cha0",
    FigureModel_Figure00_040 = "cha1",
    FigureModel_Figure00_050 = "cha1",
    FigureModel_Figure00_070 = "cha3",
    FigureModel_Figure00_080 = "cha2",
    FigureModel_Figure00_090 = "chb2",
    FigureModel_Figure00_100 = "cha6",
    FigureModel_Figure00_110 = "cha7",
    FigureModel_Figure00_120 = "chb0",
    FigureModel_Figure00_130 = "chg0",
    FigureModel_Figure00_140 = "chb9",
    FigureModel_Figure01_010 = "chc0",
    FigureModel_Figure01_020 = "chc0",
    FigureModel_Figure01_030 = "chc0",
    FigureModel_Figure01_040 = "chc0",
    FigureModel_Figure01_050 = "chc0",
    FigureModel_Figure01_060 = "chc0",
    FigureModel_Figure01_070 = "chc0",
    FigureModel_Figure01_080 = "chc0",
    FigureModel_Figure01_090 = "chc0",
    FigureModel_Figure01_100 = "chc0",
    FigureModel_Figure01_110 = "chc0",
    FigureModel_Figure01_120 = "chc0",
    FigureModel_Figure01_130 = "che2",
    FigureModel_Figure01_140 = "che3",
    FigureModel_Figure01_150 = "chc0",
    FigureModel_Figure01_160 = "che0",
    FigureModel_Figure01_170 = "chc0",
    FigureModel_Figure01_200 = "chc0",
    FigureModel_Figure01_220 = "chd2",
    FigureModel_Figure01_230 = "chd0",
    FigureModel_Figure01_250 = "chd3",
    FigureModel_Figure01_260 = "chd4",
    FigureModel_Figure01_270 = "chd5",
    FigureModel_Figure01_280 = "chf1",
    FigureModel_Figure01_290 = "chf0",
    FigureModel_Figure01_300 = "chf0",
    FigureModel_Figure01_310 = "chb5",
    FigureModel_Figure01_320 = "chf4",
    FigureModel_Figure01_330 = "chf4",
    FigureModel_Figure01_350 = "chf2",
    FigureModel_Figure01_360 = "chb6",
    FigureModel_Figure01_370 = "chf6",
    FigureModel_Figure01_380 = "chb7",
    FigureModel_Figure01_390 = "chf7",
    FigureModel_Figure01_410 = "chf8",
    FigureModel_Figure01_430 = "chd2",
    FigureModel_Figure01_440 = "chd6",
    FigureModel_Figure01_460 = "chd0",
    FigureModel_Figure10_010 = "cha0",
    FigureModel_Figure10_040 = "cha0",
    FigureModel_Figure10_050 = "cha1",
    FigureModel_Figure10_060 = "cha1",
}

re.on_application_entry("UpdateMotion", function()
	
	if not ran_once and game_name == "re4" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		global_motbanks = global_motbanks or {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		ran_once = true
		EMVSettings.init_EMVSettings()
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_jack.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4000.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4001.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4002.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4003.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4004.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4100.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4101.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4102.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4200.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4201.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4202.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4400.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4401.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4402.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4500.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4501.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4502.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4600.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4700.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4900.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp4902.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp5400.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha0/motbank/cha0_wp5402.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/facial/motbank/cha1_facial.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/facial/motbank/cha1_npc_facial.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_chap0-1.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_chap0-2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_chap2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_chap3.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_chap5.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_npc.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_npc_costume03.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_npc_wp5004.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha1/motbank/cha1_npc_wp5005.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha3/facial/motbank/cha3_facial.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha3/motbank/cha3.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha3/motbank/cha3_wp4002.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/cha7/motbank/cha7.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chb5/motbank/chb5.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chb7/facial/motbank/chb7_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chb7/facial/motbank/chb7_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chb7/motbank/chb7.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/chc0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/chc0_facial_npc.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/chc0_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/chc8_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/chd1_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/e_chc0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/facial/motbank/s_chc0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/motbank/chc0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc0/motbank/chd1.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc4/motbank/chc4.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc5/motbank/chc5.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chc8/motbank/chc8.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd0/facial/motbank/chd0_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd0/motbank/chd0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd0/motbank/chd0_10.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd2/facial/motbank/chd2_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd2/motbank/chd2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd3/facial/motbank/chd3_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd3/motbank/chd3.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd4/facial/motbank/chd4_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd4/motbank/chd4.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd6/facial/motbank/chd6_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chd6/motbank/chd6.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che0/facial/motbank/che0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che0/facial/motbank/che0_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che0/facial/motbank/e_che0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che0/facial/motbank/s_che0_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che0/motbank/che0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che2/motbank/che2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che3/motbank/che3.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/che4/motbank/che4.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf0/facial/motbank/chf0_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf0/motbank/chf0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/facial/motbank/chf1_facial_jack_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/facial/motbank/chf1_player_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/motbank/boat.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/motbank/ch1f_jack_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/motbank/chf1.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf1/motbank/chf1_player.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf2/facial/motbank/chf2_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf2/motbank/chf2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf4/facial/motbank/chf4_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf4/facial/motbank/chf4_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf4/motbank/chf4.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf5/facial/motbank/chf5_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf5/facial/motbank/chf5_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf5/motbank/chf5.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf6/facial/motbank/chf6_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf6/motbank/chf6.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf6/motbank/chf6_10.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf6/motbank/chf6_20.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf7/facial/motbank/chf7_facial_em.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf7/facial/motbank/chf7_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf7/motbank/chf7.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf8/facial/motbank/chf8_facial_pl.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf8/motbank/chf8.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf8/motbank/chf8_eye.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chf8/motbank/chfd.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chfc/motbank/chfc.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chg0/motbank/chg0.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chg2/motbank/chg2.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chg3/motbank/chg3.motbank")
			table.insert(all_motbanks, "_chainsaw/Animation/ch/chga/motbank/chga.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/lipsync/motbank/cha800_10_facial.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp4000.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp4200.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp4401.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp5000.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp6100.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/cha8/motbank/cha8_wp6102.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chc0_facial_chi1_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chc0_facial_chi2_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chc8_facial_chi1_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chc8_facial_chi2_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chd1_facial_chi1_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/facial/motbank/chd1_facial_chi2_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch3a8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch3a8jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i0jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i1jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i2jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_ch6i3jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chc0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch3a8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch3a8jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i0jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i1jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i2jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_ch6i3jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chd1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc0/motbank/chk0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc4/motbank/chc4_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc5/motbank/chc5_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch3a8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch3a8jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i0jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i1jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i2jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_ch6i3jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chc8/motbank/chc8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/facial/motbank/chd0_facial_chi1_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/facial/motbank/chd0_facial_chi2_pl.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_cha8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_cha8jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi0jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi1jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi2jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_chi3jack_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chd0/motbank/chd0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_ch3a8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_ch6i0_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_ch6i1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_ch6i2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_ch6i3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che3/motbank/che3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che4/motbank/che4_cha8_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che4/motbank/che4_chi1_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che4/motbank/che4_chi2_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/che4/motbank/che4_chi3_mc.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi0/motbank/chi0.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi0/motbank/chi0_jack.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi1/motbank/chi1.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi1/motbank/chi1_jack.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi1/motbank/chi1_wp4002.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_jack.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_wp4200.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_wp5000.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_wp5400.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_wp5402.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi2/motbank/chi2_wp6304.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi3/motbank/chi3.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi3/motbank/chi3_jack.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi3/motbank/chi3_knife.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi4/motbank/chi4_wp5000.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi4/motbank/chi4_wp5400.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi5/motbank/chi5.motbank")
			table.insert(all_motbanks, "_mercenaries/animation/ch/chi5/motbank/chi5_jack.motbank")
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
			--table.insert(bgs, "scene/menu/gallery/viewer/greenscreen.tex")
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
	fig_names = fig_names,
	finished = finished,
	reset = reset,
}