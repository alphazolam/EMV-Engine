--Enhanced Model Viewer RE3 global resources
--by alphaZomega

local EMV = require("EMV Engine")

local game_name = isSF6 and "sf6" or reframework.get_game_name()
local create_resource = EMV.create_resource
local orderedPairs = EMV.orderedPairs
local loaded_resources = false
local bgs = {}

--a dictionary of tables with 2-3 tables each, one for body and one for face and sometimes one to exclude
local alt_names = {
	--["ch13_01"]= { Body=table.pack("ch13_00"), Face=table.pack("asdf"), exclude=table.pack("ch07_20") }
}

re.on_application_entry("BeginRendering", function()
	
	if not loaded_resources and game_name == "sf6" and EMVSettings and RSCache and (figure_mode or forced_mode) then 
		
		global_motbanks = global_motbanks or {}
		RSCache.motbank_resources = RSCache.motbank_resources or {}
		RSCache.tex_resources = RSCache.tex_resources or {}
		EMVSettings.init_EMVSettings()
		local all_motbanks = {}
		if true then 
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8000_00_fce_10401_000_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8000_00_om10401_000_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8001_00_fce_10401_001_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8001_00_om10401_001_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8001_01_fce_10401_002_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8001_01_om10401_002_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8002_00_fce_10401_004_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8002_00_om10401_004_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8003_00_fce_10401_005_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8003_00_om10401_005_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8003_02_fce_10401_007_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8003_02_om10401_007_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8004_01_fce_10401_006_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8004_01_om10401_006_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8005_00_fce_10401_008_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8005_00_om10401_008_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8006_00_fce_10401_009_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8006_00_om10401_009_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8008_00_fce_10401_010_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8008_00_om10401_010_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_00_fce_10400_002_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_00_om10400_002_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_01_fce_10400_001_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_01_om10400_001_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_02_fce_10400_003_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_02_om10400_003_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_03_fce_10400_004_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8016_03_om10400_004_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8069_00_fce_10100_001_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8069_00_om10100_001_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8069_50_fce_10100_000_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8069_50_om10100_000_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_00_fce_10100_002_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_00_om10100_002_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_01_fce_10100_003_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_01_om10100_003_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_50_fce_10100_004_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_50_om10100_004_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_51_fce_10100_005_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8070_51_om10100_005_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_00_fce_10300_001_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_00_om10300_001_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_50_fce_10300_000_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_50_om10300_000_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_51_fce_10300_002_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8073_51_om10300_002_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8074_00_fce_10300_003_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8074_00_om10300_003_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8075_00_fce_10300_005_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8075_00_om10300_005_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8075_50_fce_10300_004_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8075_50_om10300_004_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8077_00_fce_10300_007_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8077_00_om10300_007_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8077_50_fce_10300_008_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8077_50_om10300_008_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_02_fce_10300_900_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_02_om10300_900_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_03_fce_10300_900_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_03_om10300_900_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_50_fce_10300_900_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_50_om10300_900_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_53_fce_10300_900_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8078_53_om10300_900_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8090_00_fce_14000_008_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8090_00_om14000_008_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_03_om14000_001_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_04_fce_14000_002_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_04_om14000_002_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_06_fce_10400_000_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_06_fce_14000_005_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_06_om10400_000_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_06_om14000_005_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_07_fce_14000_006_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_07_om14000_006_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_08_fce_14000_007_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_08_om14000_007_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_09_fce_14000_009_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_09_om14000_009_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_10_fce_14000_010_motionbank_2mh.motbank")
			table.insert(all_motbanks, "product/animation/bakeasset/2mesh/npc8990_10_om14000_010_motionbank_2m.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf000/v00/esf000v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/esf001v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf001/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/esf002v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf002/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/esf003v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf003/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/esf004v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf004/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/esf010v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf010/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/esf016v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf016/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/esf018v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf018/v00/fbx/etc/demo/esf018_dem_select_secondary.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/esf021v00_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/fce_battle.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/fce_battle_en.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/fce_winlose.motbank")
			table.insert(all_motbanks, "product/animation/esf/esf021/v00/fce_winlose_en.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10300/om10300_202/om10300_202_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10400/om10400_201/om10400_201_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10400/om10400_208/om10400_208_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_003/fce_10401_003.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_003/om10401_003_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_200/om10401_200_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_202/om10401_202_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_203/om10401_203_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_206/om10401_206_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_210/om10401_210_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_221/om10401_221_motionbank,.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om10401/om10401_222/om10401_222_motionbank,.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om14000/om14000_003/fce_14000_003_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om14000/om14000_003/om14000_003_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om14000/om14000_004/om14000_004_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/fg/om/om14000/om14000_200/om14000_200_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob004/om10401_100_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob007/om10800_104_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob012/om10200_101_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob014/om10400_103_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob022/om10200_102_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob025/om10200_104_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob029/mob029_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob029/om10400_100_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob031/mob031_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob031/om10700_100_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/mob/mob033/om10200_105_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5000/fce_npc5000_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5000/fce_npc5000_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5000/npc5000_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5000/npc5000_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5200/fce_npc5200_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5200/fce_npc5200_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5200/npc5200_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5200/npc5200_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5300/fce_npc5300_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5300/fce_npc5300_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5300/npc5300_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5300/npc5300_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5500/fce_npc5500_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5500/fce_npc5500_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5500/npc5500_audience_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5500/npc5500_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5900/npc5900_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5900/npc5902_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5900/npc5903_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc/npc5900/npc5904_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_l/npc0002/npc0002_tutorial_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_l/npc0018/fce_npc0018_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_l/npc0018/npc0018_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc1000/npc1000_tutorial_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc1003/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc1003/fce_npc1003_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc1003/npc1003_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc4000/npc4000_tutorial_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/npc_s/npc4001/npc4001_tutorial_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/fce_init.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/fce_wpl100_equip_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/fce_wpl100_mainmenu_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/fce_wpl100_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/fce_wpl100_profile_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl100_equip_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl100_mainmenu_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl100_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl100_profile_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl100_tutorial_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl100/wpl101_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl200/wpl200_mainmenu_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl200/wpl200_motionbank.motbank")
			table.insert(all_motbanks, "product/animation/wtm/pl/wpl200/wpl201_motionbank.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_056_durm/sm05_056_durm_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_056_durm/sm05_056_durm_03_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_067_fence/sm05_067_fence_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_067_fence/sm05_067_fence_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_067_fence/sm05_067_fence_02_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_067_fence/sm05_067_fence_03_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_220_flag/sm05_220_flag_00.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_221_flag/sm05_221_flag_00.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_221_flag/sm05_221_flag_01.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_248_manhole/sm05_248_manhole_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_250_light/sm05_250_light_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_251_garbage/sm05_251_garbage_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_251_garbage/sm05_251_garbage_03_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_252_roof/sm05_252_roof_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_254_rubble/sm05_254_rubblr_00.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_277_rope/sm05_277_rope_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_305_pot/sm05_305_pot_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_305_pot/sm05_305_pot_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_305_pot/sm05_305_pot_02_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_312_bicycle/sm05_312_bicycle_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_312_bicycle/sm05_312_bicycle_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_313_stall/sm05_313_stall_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_313_stall/sm05_313_stall_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_313_stall/sm05_313_stall_02_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_313_stall/sm05_313_stall_03_ml.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_314_product/sm05_314_product_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_314_product/sm05_314_product_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_314_product/sm05_314_product_02_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_314_product/sm05_314_product_03_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_315_car/sm05_315_car_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_315_car/sm05_315_car_01_ml.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_318_lantern/sm05_318_lantern_01_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_318_lantern/sm05_318_lantern_02_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_318_lantern/sm05_318_lantern_03_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_320_banner/sm05_320_banner_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_321_flag/sm05_321_flag_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_323_lantern/sm05_323_lantern_00_mb.motbank")
			table.insert(all_motbanks, "product/environment/props/resource/sm0x/sm05/sm05_323_lantern/sm05_323_lantern_01_mb.motbank")
			table.insert(all_motbanks, "product/vfx/environment/om/cityom/om019000/animation/bh_holo_motionbank.motbank")
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
			table.insert(bgs, "product/light/ibl/ess/ess0100_00/mondarrain_3.tex")
			table.insert(bgs, "product/light/ibl/wtc/wtc0101/wtc0101_day.tex")
			table.insert(bgs, "product/light/ibl/wtc/wtc5000/wtc5000_day.tex")
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