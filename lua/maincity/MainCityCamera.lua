--------------------------------------------------------------------------------
--      Copyright (c) 2015 , Tipcat Interactive.
--      All rights reserved.
--------------------------------------------------------------------------------
require "tutorial/TutorialDialog"

MainCityCamera = 
{
	evtListeners = {},
	Mathf = UnityEngine.Mathf,
	camera = nil,
	viewSize = { x = 0, y = 0},
	viewBound = {minX = 0, minY = 0, maxX = 1, maxY = 1},
	animLength = 0.0,
	firstRounter = 3.5,		--第一屏的动画节点
	secondRounter = 7.7,		--第二屏的动画节点
	thirdRounter = 11.40,		--第三屏的动画节点
	cameraRouter = 3.5,
	oldCameraRouter = 0.0,
	fromCameraRouter = 0.0,		--开启的router
	toCameraRouter = 0.0,		--结束的router
	cameraContro = nil;
	dragTime = 0.0,
	dragIn = true,
	buildForcus = {
		{Vector3.New(-46.6, 19.4, 108.54), Vector3.New(11.729, 167.63, 357.45)},
		{Vector3.New(3.9, 19.4, 101.53), Vector3.New(11.729, 192.27, 357.45)},
		{Vector3.New(-29.23, 19.4, 101.53), Vector3.New(11.729, 167.63, 357.45)},
		{Vector3.New(39.4, 19.4, 101.53), Vector3.New(11.729, 192.27, 357.45)},
		{Vector3.New(63.8, 42.1, 34.9), Vector3.New(11.729, 176.12, 357.45)},
	},
	
	curCameraPos = Vector3.zero,
	curCameraRotation = Vector3.zero,
	temp_time = 0,
	bDrag = false,
	firstIn = true,
	iCurrentScreen = 0,
	iPrevScreen = 0,
	
	CanClickBuilding = true,
	mEndDragTime = 0,
	mScaleFov = false,
	mScaleFovEndTime = 0,
	mEnableCheckAnim = true,
	mDeltaX = 0,
	maxRouter = 11.40,
}

local _mt = {}
_mt.__index = MainCityCamera

function MainCityCamera.New()
	local wmap = {}
	setmetatable(wmap, _mt);
	
	wmap:Init();
	
	return wmap;
end

function MainCityCamera:Init()
	self:ClearAllEvents();
	self.uiMgr = UIManager.Instance
	self.pointsDistance = 0;
	self.cameraFov = 0;
	
	UpdateBeat:Add(self.Update, self);
	
	--Log.d("Hello MainCityCamera:Init")
	
	local go = GameObject.Find("CameraContainer");
	self.camera = go.transform;
	-- self.camera.localPosition = Vector3.New(-1.54, 5.06, -23.37);
	-- self.camera.localEulerAngles = Vector3.New(351.9, 7.68, 0);
	-- local anim = self.camera:GetComponent(UnityEngine.Animation.GetClassType());
	--self.cameraContro = go:AddComponent(CameraController.GetClassType());
	-- anim.enabled = true;
	-- self.animClip = anim.clip;
	-- self.animLength = anim.clip.length;
	-- if self.animClip ~= nil then
	-- 	self:SampleAnim();
	-- end
	
	local real_camera = self.camera.transform:Find('Camera');
	real_camera.gameObject:SetActive(true);

	-- self.evtListeners[GameEventIDs.EID_MAP_DRAG] = EventMgr.Instance:AddListener(GameEventIDs.EID_MAP_DRAG, self, DelegateFactory.LuaCoreEventCallback(self.OnDrag));
	-- self.evtListeners[GameEventIDs.EID_MAP_END_DRAG] = EventMgr.Instance:AddListener(GameEventIDs.EID_MAP_END_DRAG, self, DelegateFactory.LuaCoreEventCallback(self.OnEndDrag));
	self.evtListeners[GameEventIDs.EID_MODLE_CLICK] = EventMgr.Instance:AddListener(GameEventIDs.EID_MODLE_CLICK, self, DelegateFactory.LuaCoreEventCallback(self.OnClickBuilding));
	self.evtListeners[GameEventIDs.EID_BACKTOSCREEN] = EventMgr.Instance:AddListener(GameEventIDs.EID_BACKTOSCREEN, self, DelegateFactory.LuaCoreEventCallback(self.OnBackToScreen));
	
	--Log.d("Hello MainCityCamera:Init -- {0}", self.camera)
end

function MainCityCamera:Dispose()
	self:ClearAllEvents();
	local camContainer = GameObject.Find('CameraContainer');
	if camContainer ~= nil then
		local real_camera = self.camera.transform:Find('Camera');
		real_camera.gameObject:SetActive(false);
	end
end


--清理所有注册事件
function MainCityCamera:ClearAllEvents()
	UpdateBeat:Remove(self.Update, self);
	
	for i, v in pairs(self.evtListeners) do
		EventMgr.Instance:RemoveListener(i, v);
	end
	
	self.evtListeners = {};
end

function MainCityCamera:Update()
	if not self.bDrag and not self.firstIn and self.mEnableCheckAnim then
		if self.animClip ~= nil and self.fromCameraRouter~=self.toCameraRouter then
			if self.temp_time < 1 then
				self.temp_time = self.temp_time + Time.deltaTime*3;
				self.cameraRouter=UnityEngine.Mathf.Lerp(self.fromCameraRouter,self.toCameraRouter,self.temp_time)
				self:SampleAnim();
			end
		end
	end
	
	if not self.CanClickBuilding then
		local deltaTime = Time.time - self.mEndDragTime;
		if deltaTime > 0.5 then
			self.CanClickBuilding = true;
		end
	end
end

function MainCityCamera:SampleAnim()
	local camRouter = self.cameraRouter;
	if camRouter >= self.maxRouter then
		camRouter = self.maxRouter;
	end
	self.animClip:SampleAnimation(self.camera.gameObject, camRouter);
end

function MainCityCamera:OnBackToScreen(evt)
end

function MainCityCamera:OnClickBuilding(evt)
	if UIManager.Instance.IsSkipUIAction then return end

	if not self.CanClickBuilding then
		return;
	end
	
	
	
	local id = evt.Data;
	
	self.curCameraPos = self.camera.transform.localPosition;
	self.curCameraRotation = self.camera.transform.localEulerAngles;
		
	coroutine.start(self.DelayDoClickEvent, self, id);
	
end

function MainCityCamera:TweenEulerAngles(go, duration, euler)
	
	local b = go.transform.localEulerAngles;
	local t = duration;
	
	if duration == 0 then
		go.transform.localEulerAngles = euler;
		return;
	end
	
	b = Quaternion.Euler(b.x, b.y, b.z);
	local e = Quaternion.Euler(euler.x, euler.y, euler.z);
	
	--Log.d("Hello from {0} to {1}", b, e);
	
	while duration > 0 do
		go.transform.localRotation = Quaternion.Lerp(b, e, (t - duration) / t);
		coroutine.step(1);
		
		duration = duration - UnityEngine.Time.deltaTime;
	end
	
	go.transform.localEulerAngles = euler;
end

function MainCityCamera:DelayDoClickEvent(id)
	--print(id)
	--coroutine.wait(0.25);
	coroutine.step(1);

	if id == MainCity.Instance.IdGangKou then
		--self:OnClickGangKou();
	elseif id == MainCity.Instance.IdShop then
		self:OnClickShop();
	elseif id == MainCity.Instance.IdJiuGuang then
		self:OnClickJiuGuang();
	elseif id == MainCity.Instance.IdGongHui then
		self:OnClickGongHui();
	elseif id == MainCity.Instance.IdJingJiChang then
		self:OnClickJingJiChang();
	elseif id == MainCity.Instance.IdShip then
		self:OnClickShip();
	end
end

function MainCityCamera:OnClickGangKou()
	MainCity.Instance.isMainCity = false;
	Log.W("set maincity flag " .. tostring(MainCity.Instance.isMainCity) .. " \r\n" .. debug.traceback())
	local jsParam = JSONObject.New()
	jsParam:AddField("to", 2)
	jsParam:AddField("from", 99)

	UIManager.Instance:OpenScreen(LuaPageIDs.PID_LOADING_SCREEN, jsParam);
end

function MainCityCamera:OnClickShop()
	if UIManager.Instance:CheckFunction(FunctionID.Shop) then
		UIManager.Instance:CloseAllOpenedPages()
		
		jsonShopType = JSONObject.New()
	    jsonShopType:AddField("shopType", 1);
	    --UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_MAIl_LIST,nil)
	    UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_SHOP, jsonShopType);
	else
		UIManager.Instance:MessagePopUp(GameMgr.Instance.LocalPlayerInfo.FunctionOpen:FunctionSpecUnLockDes(FunctionID.Shop));
		
	end
end

function MainCityCamera:OnClickJiuGuang()
	UIManager.Instance:CloseAllOpenedPages()
	
	UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_DRAW_CARD, nil);
end

function MainCityCamera:OnClickGongHui()
	if UIManager.Instance:CheckFunction(FunctionID.Guild) then
		if(GameMgr.Instance.LocalPlayerInfo.GuildMgr.CurGuildItem==nil)then
			if (GameMgr.Instance.LocalPlayerInfo.GuildID~=0 )then
				--GameMgr.Instance.LocalPlayerInfo.GuildMgr:RequestGuildInfo(GuildData.FRESH_AND_OPEN)
				UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_GUILD, nil);
			else
	            UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_CREATE_GUILD, nil);
		    end
		else			
			UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_GUILD, nil)
		end
	else
		
		UIManager.Instance:MessagePopUp(GameMgr.Instance.LocalPlayerInfo.FunctionOpen:FunctionSpecUnLockDes(FunctionID.Guild));
		
		
	end
	--UIManager.Instance:OpenPage(UIPageIDs.PAGE_ID_GUILD_AD, nil)
end

function MainCityCamera:OnClickJingJiChang()
	--print("OnClickJingJiChang")
	if UIManager.Instance:CheckFunction(FunctionID.Arena) then
	--if(true)then
		UIManager.Instance:CloseAllOpenedPages()
		
		UIManager.Instance:OpenPage(LuaPageIDs.PID_ARENA_MAIN_PAGE, nil)
	else
		local des=GameMgr.Instance.LocalPlayerInfo.FunctionOpen:FunctionSpecUnLockDes(FunctionID.Arena)
		
		UIManager.Instance:MessagePopUp(des);
		
	end
end
function MainCityCamera:OnClickShip()
	if UIManager.Instance:CheckFunction(FunctionID.Ship) then
		UIManager.Instance:CloseAllOpenedPages()
		--if GameMgr.Instance.LocalPlayerInfo.Ship.AllShips.Count>0 then
			UIManager.Instance:OpenPage(UIPageIDs.PID_SHIP_DETAIL, nil)
		--end
	else
		UIManager.Instance:MessagePopUp(GameMgr.Instance.LocalPlayerInfo.FunctionOpen:FunctionSpecUnLockDes(FunctionID.Ship));
	end
end

--往右滑动
function MainCityCamera:SampleNextAnim()
	if self.cameraRouter < self.firstRounter then
		self.fromCameraRouter = self.cameraRouter;
		self.toCameraRouter = self.firstRounter;
		self.iCurrentScreen=0;
		MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
	elseif self.cameraRouter<self.secondRounter then
		self.fromCameraRouter = self.cameraRouter;
		self.toCameraRouter = self.secondRounter;
		self.iCurrentScreen=1;
		MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
	elseif self.cameraRouter<self.thirdRounter or self.iCurrentScreen ==2 then
		if self.iCurrentScreen ~=2 then
			self.fromCameraRouter = self.cameraRouter;
			self.toCameraRouter = self.thirdRounter;
			self.iCurrentScreen=2;
			MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
		else
			self.bDrag = true;
		end
	elseif self.cameraRouter == self.thirdRounter then
		self.bDrag = true;	
	end
end

--往左滑动
function MainCityCamera:SamplePrevAnim()
	if self.cameraRouter>self.secondRounter then
		self.fromCameraRouter = self.cameraRouter;
		self.toCameraRouter = self.secondRounter;
		self.iCurrentScreen = 1;
		MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
	elseif self.cameraRouter > self.firstRounter then
		self.fromCameraRouter = self.cameraRouter;
		self.toCameraRouter = self.firstRounter;
		self.iCurrentScreen = 0;
		MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
	else
		self.fromCameraRouter = self.firstRounter;
		self.toCameraRouter = self.firstRounter;
		self.bDrag = true;	
		self.iCurrentScreen = 0;
		MainCity.Instance.playerView:ChangeScreen(0);
	end
end

function MainCityCamera:SampleOtherAnim()
	if self.cameraRouter < self.firstRounter then
		if self.mDeltaX < 0 then
			self.fromCameraRouter = self.cameraRouter;
			self.toCameraRouter = self.firstRounter;
			self.iCurrentScreen=0;
			MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
		elseif self.mDeltaX > 0 then
			self.bDrag = true;
		end
	elseif self.cameraRouter< self.secondRounter then
		if self.mDeltaX < 0 then
			self.fromCameraRouter = self.cameraRouter;
			self.toCameraRouter = self.secondRounter;
			self.iCurrentScreen=1
			MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
		elseif self.mDeltaX > 0 then
			self.fromCameraRouter = self.cameraRouter;
			self.toCameraRouter = self.firstRounter;
			self.iCurrentScreen = 0;
			MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
		end
	elseif self.cameraRouter<self.thirdRounter then
		if self.mDeltaX < 0 then
			if self.iCurrentScreen~=2 then
				self.fromCameraRouter = self.cameraRouter;
				self.toCameraRouter = self.thirdRounter;
				self.iCurrentScreen=2;
				MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
			else
				self.bDrag = true;
			end
		elseif self.mDeltaX > 0 then
			self.fromCameraRouter = self.cameraRouter;
			self.toCameraRouter = self.secondRounter;
			self.iCurrentScreen=1;
			MainCity.Instance.playerView:ChangeScreen(self.iCurrentScreen);
		end
	end
end

function MainCityCamera:OnEndDrag(evt)
	local mouseEvt = evt.Data;
	
	self.pointsDistance = 0;
	self.bDrag = false;
	self.temp_time = 0;
	self.mEndDragTime = Time.time;
	
	if self.mScaleFov then
		self.mScaleFovEndTime = Time.time;
		return;
	end
	
	--Log.w("self.cameraRouter:{0}",self.cameraRouter);
	if MainCity.Instance.playerView ~= nil then
		if self.cameraRouter < self.thirdRounter then
			if self.cameraRouter>self.oldCameraRouter then
				self:SampleNextAnim();
			elseif self.cameraRouter<self.oldCameraRouter then
				self:SamplePrevAnim();
			else 
				self:SampleOtherAnim();
			end
		else
			self.fromCameraRouter = self.thirdRounter;
			self.toCameraRouter =self.thirdRounter;
		end
	end
	
	--Log.w("from={0},to={1}",self.fromCameraRouter,self.toCameraRouter);
	
	self.dragIn=true;
end


function MainCityCamera:OnDrag(evt)
	Log.e('11111111111')
	-- 做教程的时候，不能拖动屏幕
	if TutorialDialog.GetInstance():IsDoingTutorial() or UIManager.Instance.IsSkipUIAction then return end

	self.bDrag = true;
	self.firstIn = false;
	self.dragTime = self.dragTime + Time.deltaTime;
	
	-- UnityEngine.EventSystems.PointerEventData
	-- eventData.delta (Vector2)
	local mouseEvt = evt.Data;
	
	local touchPoints = InputAgent.Instance.TouchPoints;
	self.mScaleFov = touchPoints.Length>1;
	--Log.w("Hello MainCityCamera:OnDrag(evt): {0}", touchPoints.Length)
	if touchPoints.Length == 2 then
		self.mEnableCheckAnim = false;
		local dist = Vector2.New(touchPoints[0].x - touchPoints[1].x, touchPoints[0].y - touchPoints[1].y);
		local real_camera = self.camera:Find('Camera'):GetComponent(UnityEngine.Camera.GetClassType());
		local mag = dist:Magnitude();
		if self.pointsDistance == 0 then
			--Log.w("Hello reset pointsDistance");
			self.pointsDistance = mag;
			self.cameraFov = real_camera.fieldOfView;
			return;
		end

		--Log.w("Hello 2 camera fieldOfView: {0} - {1}:{2}", real_camera.fieldOfView, mag, mag - self.pointsDistance);
		
		real_camera.fieldOfView = real_camera.fieldOfView - 0.0425 * (mag - self.pointsDistance);
		real_camera.fieldOfView = math.min(60, math.max(30, real_camera.fieldOfView));
		self.pointsDistance = mag;
		self.CanClickBuilding = false;
		return;
	end
	
	local deltaScaleFovTime = Time.time - self.mScaleFovEndTime;
	if deltaScaleFovTime >= 0.5 then
		self.mEnableCheckAnim = true;	
		self.mDeltaX = mouseEvt.delta.x;		
		self.cameraRouter = self.cameraRouter - self.mDeltaX / 200;
		
		if self.cameraRouter < 0 then
			self.cameraRouter = 0;
		elseif self.cameraRouter>=self.maxRouter then
			self.cameraRouter = self.maxRouter;
		end
			
		if self.animClip ~= nil then
			if self.camera ~= nil then
				self:SampleAnim();
			else
				local go = GameObject.Find("CameraContainer");
				self.camera = go.transform;
				self:SampleAnim();
			end
			if self.dragIn == true then
				self.CanClickBuilding = false;
				self.oldCameraRouter = self.cameraRouter;
				self.dragIn = false;
			end
		end
	end
	
	
end

function MainCityCamera:UpdatePosition()
	if self.animClip ~= nil then
		self:SampleAnim();
	end
end
