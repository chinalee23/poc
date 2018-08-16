--------------------------------------------------------------------------------
--      Copyright (c) 2015 , Tipcat Interactive.
--      All rights reserved.
--------------------------------------------------------------------------------
require "common/PageIDs"
require "maincity/MainCityCamera"
require "maincity/MainCityPlayerView"

MainCity = 
{
	prefab_name = 'map_scene/maincity_day_new',
	prefab_night_name = 'map_scene/maincity_night_new',
	prefab_sunset_name = 'map_scene/maincity_sunset_new',
	level_name = 'maincity_day_new',
	level_night_name = 'maincity_night_new',
	level_sunset_name = 'maincity_sunset_new',
	root_name = "Root3D",
	
	maincityState = 1, -- 0-night, 1-Daily, 2-sunset
	
	root = nil,
	openElementId = 0,
	
	camera = nil,
	listenerIds = {},
	
	bIsInitialized = false;
	
	isMainCity = true, -- 是否在主城状态, 否则在世界地图
	
	-- Build Ids
	IdGangKou = 100,
	IdShop = 101,
	IdJiuGuang = 102,
	IdGongHui = 103,
	IdJingJiChang = 104,
	IdShip=105;
	
	playerView = nil,
	
	Instance = nil,

	ShipBuildingGo=nil,
	ArenaBuildingGo=nil,
	GuildBuildingGo=nil,
	ShopBuildingGo=nil,
	DrawCardBuildingGo=nil,

	bCanUpdate=false,
	temp_time=0,
	bGetRedPointState=false,
	
	prefab_city_npc = nil,
	bNight = false,		--是否为夜景
	sceneRainPref = nil,
	huoPref = nil,
	camRainPref = nil,
	smallRainPref = nil,
	city_floor = nil,
	
	isSmallRaining = false,
	beginSmallRainTime = 0,
	
	city_npc_go = nil,
	loadnpccity_taskid = 0,
	rained = false,
	needStop = false,

    timeSinceSwitchCity = -1,
    curCitySwitchState = -1,
}

local _mt = {}
_mt.__index = MainCity

function MainCity.New()
	local wmap = {}
	setmetatable(wmap, _mt);
	return wmap;
end

function MainCity.Init()
	if(MainCity.Instance == nil) then
		MainCity.Instance = MainCity.New()
	end
end

function MainCity.SwitchMaincity()	
	MainCity.Instance.maincityState = (MainCity.Instance.maincityState + 1) % 3;	

	MainCity.Instance.isMainCity = true;
  Log.W("set maincity flag " .. tostring(MainCity.Instance.isMainCity) .. " \r\n" .. debug.traceback())
	if WorldMap.Instance ~= nil then 
		WorldMap.Instance:Clean(); 
		WorldMap.Instance:CleanCam();
	end
	
	MainCity.Instance:Clean(false,false);
	MainCity.Instance:CleanCam();
	
	local jsParam = JSONObject.New()
	jsParam:AddField("to", 1)
	jsParam:AddField("from", 0)

	UIManager.Instance:OpenScreen(LuaPageIDs.PID_LOADING_SCREEN, jsParam);
end

function MainCity:Open(param)

	--Log.d("Hello MainCity:Open...");

	self.openElementId = 0;
	self.openFrom = 0;
	
	MainCity.Instance.isMainCity = true;
  Log.W("set maincity flag " .. tostring(MainCity.Instance.isMainCity) .. " \r\n" .. debug.traceback())
	
	if (param ~= nil) then
	 	if param:HasField('openId') then self.openElementId = param:GetField('openId').n; end
		if param:HasField('from') then self.openFrom = param:GetField('from').n; end
	end
	
	if not GameMgr.Instance:HasLoadedScene("MainCity") then
		if CheckScriptAsset('LevelChangeName') then
			MainCity.Instance.maincityState = 2;
		else
			MainCity.Instance.maincityState = (MainCity.Instance.maincityState + 1) % 3;
		end
		
		ResMgr.Instance:LoadLevelAsync("MainCity", self, DelegateFactory.LuaLevelCallback(self.OnMainLevelLoaded));
	else
		self:OnMainLevelLoaded();
	end
	
	self.listenerIds[GameEventIDs.EID_MAP_CHECK] = EventMgr.Instance:AddListener(GameEventIDs.EID_MAP_CHECK, self, DelegateFactory.LuaCoreEventCallback(self.OnRefreshBuildTitle));

	self.listenerIds[LuaEventIDs.EID_GET_PLAYERS] = EventMgr.Instance:AddListener(LuaEventIDs.EID_GET_PLAYERS,self,DelegateFactory.LuaCoreEventCallback(self.OnGetMainCityPlayer));
	self.listenerIds[LuaEventIDs.EID_Arena_Close] = EventMgr.Instance:AddListener(LuaEventIDs.EID_Arena_Close, self, DelegateFactory.LuaCoreEventCallback(self.OnRefreshAreanRedPoint));
	self.listenerIds[GameEventIDs.EID_SHIP_RED_POINT_REFRESH] = EventMgr.Instance:AddListener(GameEventIDs.EID_SHIP_RED_POINT_REFRESH, self, DelegateFactory.LuaCoreEventCallback(self.OnRefreshShipRedPoint));
	self.listenerIds[GameEventIDs.EID_GEM_OPEN_BOX] = EventMgr.Instance:AddListener(GameEventIDs.EID_GEM_OPEN_BOX, self, DelegateFactory.LuaCoreEventCallback(self.OnRefreshShopRedPoint));
	self.listenerIds[GameEventIDs.EID_MAINCITY_CAMERA_CLEAN] = EventMgr.Instance:AddListener(GameEventIDs.EID_MAINCITY_CAMERA_CLEAN, self, DelegateFactory.LuaCoreEventCallback(self.OnClean));
end

function MainCity:CleanCam()
	if(self.camera ~= nil) then
		self.camera:Dispose();
	end
	
	self.camera = nil;
end

function MainCity:Clean(NoCleanPlayer,cleanCityNpc)
	--Log.e("MainCity disposed!")
	--Log.d(">>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<Hello MainCity:Clean..1.");
	for k, v in pairs(self.listenerIds) do
		EventMgr.Instance:RemoveListener(k, v);
	end
	
	--Log.d(">>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<Hello MainCity:Clean..2.");
	
	self.listenerIds = {}
	self.elements = {} 
	self.paths = {}
	self.ShipBuildingGo=nil;
	self.ArenaBuildingGo=nil;
	self.GuildBuildingGo=nil;
	self.ShopBuildingGo=nil;
	self.DrawCardBuildingGo=nil;
	
	self.prefab_city_npc = nil;
	self.bNight = false;		--是否为夜景
	self.sceneRainPref = nil;
	self.huoPref = nil;
	self.camRainPref = nil;
	self.smallRainPref = nil;
	self.city_floor = nil;
	
	self.isSmallRaining = false;
	self.beginSmallRainTime = 0;
	
	if self.loadnpccity_taskid > 0 then
		ResMgr.Instance:CancelLoadGameObjectAsset(self.loadnpccity_taskid);
		self.loadnpccity_taskid = 0;
	end
	
	if cleanCityNpc then
		if self.city_npc_go ~=nil then
			GameObject.Destroy(self.city_npc_go);
		end
		self.city_npc_go = nil;
	end 
	--Log.d(">>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<Hello MainCity:Clean..3.");
	
	if self.playerView ~= nil and not NoCleanPlayer then
		self.playerView:Dispose();
		self.playerView = nil;
	end

	--Log.d(">>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<Hello MainCity:Clean..4.");	
	UIUtility.SetOceanEnabled(0);
	UpdateBeat:Remove(self.Update, self);
end

function MainCity:OnMainLevelLoaded()
	-- Load MainCity real level info.
	local maincity_asset = GameObject.Find('assets_city');
	if maincity_asset == nil then
		if CheckScriptAsset('LevelChangeName') then
			self.maincityState = 2;
		else
			local hour = TimeSync.LocalDateTime.Hour;
			if(hour>=6 and hour<=16) then
				self.maincityState = 1;
			elseif (hour > 16 and hour < 18) then
				self.maincityState = 2;
			else
				self.maincityState = 0;
			end

            -- Log.d("Hello delta: {0} / {1}", TimeSync.LocalDateTime.Ticks / 10000000 - MainCity.timeSinceSwitchCity, MainCity.timeSinceSwitchCity)
            if MainCity.timeSinceSwitchCity < 0 then
                MainCity.timeSinceSwitchCity = TimeSync.LocalDateTime.Ticks / 10000000
                MainCity.curCitySwitchState = self.maincityState
            elseif (TimeSync.LocalDateTime.Ticks / 10000000 - MainCity.timeSinceSwitchCity) > 30 * 60 then
                self.maincityState = (MainCity.curCitySwitchState + 1) % 3
                MainCity.curCitySwitchState = self.maincityState
                MainCity.timeSinceSwitchCity = TimeSync.LocalDateTime.Ticks / 10000000
            end
		end
		
		if self.maincityState == 0 then
			Log.w("MainCity: self.maincityState = 0");
			self.bNight = true;
			self.prefab_city_npc = "NPC_city_night";
			-- ResMgr.Instance:LoadLevelAdditiveAsync(self.prefab_night_name, self.level_night_name, self, DelegateFactory.LuaLevelCallback(self.OnLevelLoaded));
			ResMgr.Instance:LoadLevelAdditiveAsync(nil, self.level_night_name, self, DelegateFactory.LuaLevelCallback(self.OnLevelLoaded))
		elseif self.maincityState == 1 then
			Log.w("MainCity: self.maincityState = 1");
			self.bNight = false;
			self.prefab_city_npc = "NPC_city_day";
			ResMgr.Instance:LoadLevelAdditiveAsync(self.prefab_name, self.level_name, self, DelegateFactory.LuaLevelCallback(self.OnLevelLoaded));
		elseif self.maincityState == 2 then
			Log.w("MainCity: self.maincityState = 2");
			self.bNight = false;
			self.prefab_city_npc = "NPC_city_day";
			ResMgr.Instance:LoadLevelAdditiveAsync(self.prefab_sunset_name, self.level_sunset_name, self, DelegateFactory.LuaLevelCallback(self.OnLevelLoaded));
		end
	else
		self:OnLevelLoaded();
	end
end

function MainCity:OnLightMapObj()
	--ResMgr.Instance:LoadGameObjectAsset("lightmap/maincityprefab", "maincity", self, DelegateFactory.LuaGoLoaderCallback(self.OnLevelLoaded));
end

function MainCity:OnLevelLoaded()
	if self.camera ~= nil then
		self.camera:ClearAllEvents();
	end
	
	--Log.w("MainCity OnLevelLoaded ChangeLightMap");
	self.camera = MainCityCamera.New()
		
	self:Initialize()
	
	--[[
		如果有初始剧情， 需要加载预设。。。
	]]
	--Log.w("MainCity OnLevelLoaded LoadPreloadAssets");	
	if CheckScriptAsset('Levelmain_01') then
		ResMgr.Instance:LoadGameObjectAsset("monster/jack_guochang_01", "jack_guochang_01", self, 
      DelegateFactory.LuaGoLoaderCallback(self.OnGuochangeLoaded))
	elseif CheckScriptAsset('LevelChangeName') then
		ResMgr.Instance:LoadPreLoadAssets('map/levelchangename_preload', 'levelchangename_preload', self, DelegateFactory.LuaLevelCallback(self.OnPreloadLoaded));
	else
		coroutine.start(self.OpenMainScreen, self, 0)
	end
	
	--夜景情况下，控制下雨等处理
	if self.bNight then
		self:SetRainStat();
	end
	
	--加载主城移动的NPC
	if self.city_npc_go ==  nil then
		self.loadnpccity_taskid = ResMgr.Instance:LoadGameObjectAsset("map/npc_city", self.prefab_city_npc, self, DelegateFactory.LuaGoLoaderCallback(self.OnCityNpcLoaded));
	end
	
  UIUtility.SetShadownLightByQuality(nil)
  
	EventMgr.Instance:DispatchEvent(CoreEvent.New(LuaEventIDs.EID_SWITCH_MAINCITY, 0));
end

function MainCity:SetRainStat()
	if self.city_floor == nil then
		self.city_floor = GameObject.Find("assets_city/patrs/city_floor");
	end
	if self.sceneRainPref == nil then
		self.sceneRainPref = GameObject.Find("FX_night/rain");
	end
	if self.huoPref == nil then
		self.huoPref = GameObject.Find("FX_night/huopeng");
	end
	
	if self.camRainPref == nil then 
		self.camRainPref = GameObject.Find("CameraContainer/Camera/EFX_dayu_prefab");
	end
	
	if self.smallRainPref == nil then
		self.smallRainPref = GameObject.Find("CameraContainer/Camera/EFX_xiaoyu_prefab");
	end

	local deltaRainTime = (TimeSync.LocalDateTime.Ticks - GameMgr.Instance.BeginRainTime)/10000000;
	local deltaStopRainTime = (TimeSync.LocalDateTime.Ticks - GameMgr.Instance.StopRainTime)/10000000;
	local force = deltaStopRainTime < 0 or deltaRainTime < 0;
	if force or (deltaStopRainTime > 2*60*60 and ((GameMgr.Instance.IsRaining and deltaRainTime < 60*60) or not GameMgr.Instance.IsRaining)) then
		local rand = math.Random(0,100);
		if rand >= 50 and rand<=60 then
			if not GameMgr.Instance.IsRaining then
				GameMgr.Instance.BeginRainTime = TimeSync.LocalDateTime.Ticks;
			end
			self.isSmallRaining = false;
			
			if self.camRainPref~=nil then
				self.camRainPref:SetActive(true);
			end
			if self.sceneRainPref~= nil then
				self.sceneRainPref:SetActive(true);
			end
			if self.huoPref~=nil then
				self.huoPref:SetActive(false);
			end
			GameMgr.Instance.IsRaining = true;
			UIUtility.ChangeCityFloorRefPart(self.city_floor,-0.3);
			if self.city_npc_go ~= nil then
				UIUtility.SetSceneMoveNpcVis(self.city_npc_go,false);
			end
			self.rained = true;
			rand = math.Random(0,100);
			if rand >= 20 and rand<=30 then
				self.needStop = true;
			else
				self.needStop = false;
			end
		else
			self:StopRain();
			UIUtility.ChangeCityFloorRefPart(self.city_floor,-1);
			self.rained = false;
		end
		
	else
		self:StopRain();
		UIUtility.ChangeCityFloorRefPart(self.city_floor,-1);
		self.rained = false;
	end
end

function MainCity:OnCityNpcLoaded(go)
	self.loadnpccity_taskid = 0;
	if go == nil then
		return;
	end
	
	self.city_npc_go = go;
	if GameMgr.Instance.IsRaining then
		UIUtility.SetSceneMoveNpcVis(self.city_npc_go,false);
	end
	go.transform.localPosition = Vector3.New(0,0,0);
end

function MainCity:OnGuochangeLoaded(go)
  self.jackGuochangeGo = go
  if go ~= nil then
    go:SetActive(false)
  end
  --BattleShareData.CleanTmpBundles()
  coroutine.start(self.OpenMainScreen, self, 0)
end

function MainCity:OnPreloadLoaded()
	-- PreLoad Assets Loaded...
	coroutine.start(self.OpenMainScreen, self, 0)
end

function MainCity:Initialize()

	local doChangeName = CheckScriptAsset('LevelChangeName')
	if not doChangeName then
		self.playerView = MCPlayerView.New();
	end

	self.bIsInitialized = true;
end

function MainCity:InitPlayerView()
	if self.playerView ~= nil then
		self.playerView:Init()
	end
end


--this is a coroutine
function MainCity:OpenMainScreen(delay)
	--等待初始化
	--while not self.bIsInitialized do
	--	coroutine.step(1, self)
	--end
	coroutine.wait(delay)
	--初始化完成打开界面

	UpdateBeat:Add(self.Update, self);
	-- Open Main Screen --
	local argv = nil
	if self.openElementId > 0 or self.openFrom > 0 then
		argv = JSONObject.New()
		argv:AddField("openId", self.openElementId)
		argv:AddField("from", self.openFrom)
	end
	
	if argv == nil then
		argv = JSONObject.New()
	end
	argv:AddBoolField("showMiniChat",true);
	UIManager.Instance:OpenScreen(LuaPageIDs.PID_MAIN_SCREEN, argv)

	self:SetBuildingTitle()
end

function MainCity:GetBuildingRedPointInfo()
	coroutine.start(self.GetRedPointInfo, self);
end

function MainCity:GetRedPointInfo()
	if not self.bGetRedPointState then
		local localPlayer = GameMgr.Instance.LocalPlayerInfo;

		--***只为获取小红点状态
		TaskMgr.Instance:RequestGetTaskScoreState()
		coroutine.step(1)
		localPlayer.SignIn:RequestSignInInfo()
		coroutine.step(1)
		localPlayer.GemMgr:RequestBoxInfo();
		coroutine.step(1)
		LuaMethodTrans.Instance:GetLotteryStatus()
		coroutine.step(1)
		localPlayer.GuildMgr:RequestGuildInfo();
		while localPlayer.GuildMgr.IsRequesting do coroutine.step(1); end
		if localPlayer.GuildMgr.CurGuildItem~=nil then
			LuaMethodTrans.Instance:GetTrainingState();
			localPlayer.GuildMgr.CurGuildItem:RequestAllianceHonourPublicTaskList();
			while localPlayer.GuildMgr.CurGuildItem.IsRequesting do coroutine.step(1); end
			localPlayer.GuildMgr.CurGuildItem:RequestAllianceHonourDailyTaskList();
			while localPlayer.GuildMgr.CurGuildItem.IsRequesting do coroutine.step(1); end
			localPlayer.GuildMgr.CurGuildItem:RequestAllianceWeeklyRewardStatus();
			while localPlayer.GuildMgr.CurGuildItem.IsRequesting do coroutine.step(1); end
			localPlayer.GuildMgr.CurGuildItem:RequestAllianceDailyRewardStatus();
		end
		coroutine.step(1)

		LuaMethodTrans.Instance:GetMonthCardStatus();
		if UIManager.Instance:CheckFunction(FunctionID.Arena) then
			ArenaData.GetInstance():RequestArenaBaseInfo(false)
			while (ArenaData.GetInstance():GetRequesting()) do coroutine.step(1); end
			--ArenaData.GetInstance():ConfigHonourTab()
			--while (ArenaData.GetInstance():GetRequesting()) do coroutine.step(1); end	
			--ArenaData.GetInstance():RequestHonourState()
			--while (ArenaData.GetInstance():GetRequesting()) do coroutine.step(1); end
		end

		self.bGetRedPointState=true
	end

	if self.ShipBuildingGo ~= nil then
		local parentGo = self.ShipBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_SHIPYARD);
	end

	if self.ArenaBuildingGo ~= nil and ArenaData.GetInstance().IsLoadBaseInfo then
		parentGo = self.ArenaBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_ARENA);
	end

	if self.ShopBuildingGo ~= nil then
		parentGo = self.ShopBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_SHOP);
	end

	self.bCanUpdate=true;
end

function MainCity:OnRefreshBuildTitle(evt)
	if evt.Data==0 then
		self:SetBuildingTitle()
	end
end

function MainCity:SetBuildingTitle()
	local buildingNameGo = GameObject.Find("UI_buildingname");
	if buildingNameGo~=nil then
		self.ShipBuildingGo = buildingNameGo.transform:Find("BuildShip/lookforcamera")
		self.ArenaBuildingGo = buildingNameGo.transform:Find("BuildArena/lookforcamera")
		self.GuildBuildingGo = buildingNameGo.transform:Find("BuildGuild/lookforcamera")
		self.ShopBuildingGo = buildingNameGo.transform:Find("BuildShop/lookforcamera")
		self.DrawCardBuildingGo = buildingNameGo.transform:Find("BuildDrawCard/lookforcamera")
		local PortBuildingGo = buildingNameGo.transform:Find("BuildPort")
		if self.ShipBuildingGo~=nil then
			local LockGo=self.ShipBuildingGo:Find("ImgLock")
			local TitleImg=self.ShipBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			local BackgroundGo=self.ShipBuildingGo:Find("background")
			if UIManager.Instance:CheckFunction(FunctionID.Ship) then
				LockGo.gameObject:SetActive(false)
				TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
				UIUtility.FillDefaultMaterial(TitleImg)
			else
				UIUtility.FillGreyMaterialWithMask(TitleImg)
				LockGo.gameObject:SetActive(true)
			end
		end
		if self.ArenaBuildingGo~=nil then
			local LockGo=self.ArenaBuildingGo:Find("ImgLock")
			local TitleImg=self.ArenaBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			local BackgroundGo=self.ArenaBuildingGo:Find("background")
			if UIManager.Instance:CheckFunction(FunctionID.Arena) then
				LockGo.gameObject:SetActive(false)
				TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
				UIUtility.FillDefaultMaterial(TitleImg)
			else
				UIUtility.FillGreyMaterialWithMask(TitleImg)
				LockGo.gameObject:SetActive(true)
			end
		end
		if self.GuildBuildingGo~=nil then
			local LockGo=self.GuildBuildingGo:Find("ImgLock")
			local TitleImg=self.GuildBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			local BackgroundGo=self.GuildBuildingGo:Find("background")
			if UIManager.Instance:CheckFunction(FunctionID.Guild) then
				LockGo.gameObject:SetActive(false)
				TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
				UIUtility.FillDefaultMaterial(TitleImg)
			else
				UIUtility.FillGreyMaterialWithMask(TitleImg)
				LockGo.gameObject:SetActive(true)
			end
		end
		if self.ShopBuildingGo~=nil then
			local LockGo=self.ShopBuildingGo:Find("ImgLock")
			local TitleImg=self.ShopBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			local BackgroundGo=self.ShopBuildingGo:Find("background")
			if UIManager.Instance:CheckFunction(FunctionID.Shop) then
				LockGo.gameObject:SetActive(false)
				TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
				UIUtility.FillDefaultMaterial(TitleImg)
			else
				UIUtility.FillGreyMaterialWithMask(TitleImg)
				LockGo.gameObject:SetActive(true)
			end
		end
		if self.DrawCardBuildingGo~=nil then
			local LockGo=self.DrawCardBuildingGo:Find("ImgLock")
			local TitleImg=self.DrawCardBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			local BackgroundGo=self.DrawCardBuildingGo:Find("background")
			LockGo.gameObject:SetActive(false)
			TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
		end
		if PortBuildingGo~=nil then
			PortBuildingGo.gameObject:SetActive(false)
			--local LockGo=PortBuildingGo:Find("ImgLock")
			--local TitleImg=PortBuildingGo:Find("title"):GetComponent(UnityEngine.SpriteRenderer.GetClassType())
			--local BackgroundGo=PortBuildingGo:Find("background")
			--LockGo.gameObject:SetActive(false)
			--TitleImg.gameObject.transform.localPosition = BackgroundGo.gameObject.transform.localPosition
		end
	end
end

function MainCity:OnGetMainCityPlayer(evt)
	if self.playerView == nil then
		return;
	end
	
	self.playerView:ShowPlayers();
end

function MainCity:OnRefreshAreanRedPoint(evt)
	if evt.Data==0 and self.ArenaBuildingGo~=nil and ArenaData.GetInstance().IsLoadBaseInfo then
		local parentGo = self.ArenaBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_ARENA);
	end
end
function MainCity:OnRefreshShipRedPoint(evt)
	if evt.Data==0 and self.ShipBuildingGo~=nil then
		local parentGo = self.ShipBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_SHIPYARD);
	end
end
function MainCity:OnRefreshShopRedPoint(evt)
	if evt.Data==0 and self.ShopBuildingGo~=nil  then
		local parentGo = self.ShopBuildingGo:Find("background")
		RedPointMgr.Instance:AddMainCityBuildingRedPoint(parentGo.gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_SHOP);
	end
end

function MainCity:OnClean(evt)
	if evt.Data==0 then
		 MainCity.Instance:Clean(false,false);
		 MainCity.Instance:CleanCam();
	end
end

function MainCity:Update()
	if self~=nil and self.bCanUpdate then
		self.temp_time = self.temp_time + Time.deltaTime;
		if self.temp_time > 2 then
			if self.GuildBuildingGo ~= nil then
				RedPointMgr.Instance:AddMainCityBuildingRedPoint(self.GuildBuildingGo:Find("background").gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_GUILD);
			end
			if self.DrawCardBuildingGo ~= nil then
				RedPointMgr.Instance:AddMainCityBuildingRedPoint(self.DrawCardBuildingGo:Find("background").gameObject,ERedPointIDs.ERD_MAIN_CITY_BUILDING_PUB);
			end
			self.temp_time=0
		end
	end
	
	self:UpdateRain();
end

function MainCity:UpdateRain()
	if not GameMgr.Instance.IsRaining then
		if self.rained then
			local deltaStopRainTime = (TimeSync.LocalDateTime.Ticks - GameMgr.Instance.StopRainTime)/10000000;
			if deltaStopRainTime <= 5 then
				local val = -0.5 - deltaStopRainTime*0.5/5; 
				if val > -0.5 then
					val = -1;
				end
				UIUtility.ChangeCityFloorRefPart(self.city_floor,val);
			end
		end
		return;
	end
	
	if not self.needStop then
		return;
	end
	
	local deltaRainTime = (TimeSync.LocalDateTime.Ticks - GameMgr.Instance.BeginRainTime)/10000000;
	
	--超过1小时，停止下雨
	if deltaRainTime >= 16*60 then
		self:StopRain();
	--超过半小时，变成下雨
	elseif deltaRainTime >= 15*60 then
		if not self.isSmallRaining then
			self.beginSmallRainTime = Time.time;
			self.isSmallRaining = true;

		    if self.smallRainPref ~= nil then
		    	self.smallRainPref:SetActive(true);
		    end
		
		    if self.camRainPref~=nil then
		    	self.camRainPref:SetActive(false);
    		end
		end
	end
	
	if self.isSmallRaining and (Time.time - self.beginSmallRainTime) <= 4 then
		local val = -0.3 - (Time.time - self.beginSmallRainTime)*0.2/4; 
		UIUtility.ChangeCityFloorRefPart(self.city_floor,val);
	end
end

function MainCity:StopRain()
	self.isSmallRaining = false;
	
	if GameMgr.Instance.IsRaining then
		GameMgr.Instance.StopRainTime = TimeSync.LocalDateTime.Ticks;
		GameMgr.Instance.IsRaining  = false;
	end
		
	if self.smallRainPref ~= nil then
		self.smallRainPref:SetActive(false);
	end
	
	if self.camRainPref~=nil then
		self.camRainPref:SetActive(false);
	end
	
	if self.sceneRainPref~= nil then
		self.sceneRainPref:SetActive(false);
	end
	
	if self.huoPref~=nil then
		self.huoPref:SetActive(true);
	end
	
	if self.city_npc_go~=nil then
		UIUtility.SetSceneMoveNpcVis(self.city_npc_go,true);
	end
end

function MainCity:SetDragEnable(b)
  local dragGo = GameObject.Find("Wall");
  if dragGo ~= nil then
    dragGo:SetActive(b)
  end
end

function MainCity:SetBuildingEnable(b)
  local buildingName = GameObject.Find("UI_buildingname");
  if buildingName ~= nil then
    buildingName:SetActive(b)
  end
  
  local sceneHolder = GameObject.Find("SceneHolder");
  if sceneHolder ~= nil then
    sceneHolder:SetActive(b)
  end
end
