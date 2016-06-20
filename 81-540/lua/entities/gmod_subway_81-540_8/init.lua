AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

ENT.BogeyDistance = 650 -- Needed for gm trainspawner

--------------------------------------------------------------------------------
function ENT:Initialize()
	-- Defined train information
	self.SubwayTrain = {
		Type = "540",
		Name = "81-540.8",
	    WagType = 1,
	}

	-- Set model and initialize
	self:SetModel("models/train/Russian/81-540.mdl")
	self.BaseClass.Initialize(self)
	self:SetPos(self:GetPos() + Vector(0,0,140))
	
	-- Create seat entities
	self.DriverSeat = self:CreateSeat("driver",Vector(410,-0,85)) 
	self.InstructorsSeat = self:CreateSeat("instructor",Vector(410,40,85))

	-- Hide seats
	self.DriverSeat:SetColor(Color(0,0,0,0))
	self.DriverSeat:SetRenderMode(RENDERMODE_TRANSALPHA)
	self.InstructorsSeat:SetColor(Color(0,0,0,0))
	self.InstructorsSeat:SetRenderMode(RENDERMODE_TRANSALPHA)

	
	-- Create Bogeys
	self.FrontBogey = self:CreateBogey(Vector( 485-120,0,28),Angle(0,180,0),true) 
	self.RearBogey = self:CreateBogey(Vector(-490+155,0,28),Angle(0,0,0),false)
	
	-- Initialize key mapping
	self.KeyMap = {
		[KEY_W] = "Drive", 
		[KEY_S] = "Brake", 
		[KEY_R] = "Reverse",
		[KEY_L] = "HornEngage",
		[KEY_BACKSPACE] = "EmergencyBrake",
		}
	
end

	
		-- Generate bogey sounds
	local jerk = math.abs((self.Acceleration - (self.PrevAcceleration or 0)) / self.DeltaTime)
	self.PrevAcceleration = self.Acceleration

	if jerk > (2.0 + self.Speed/15.0) then
		self.PrevTriggerTime1 = self.PrevTriggerTime1 or CurTime()
		self.PrevTriggerTime2 = self.PrevTriggerTime2 or CurTime()

		if ((math.random() > 0.00) or (jerk > 10)) and (CurTime() - self.PrevTriggerTime1 > 1.5) then
			self.PrevTriggerTime1 = CurTime()
			self.FrontBogey:EmitSound("subway_trains/chassis_"..math.random(1,3)..".wav", 70, math.random(90,110))
		end
		if ((math.random() > 0.00) or (jerk > 10)) and (CurTime() - self.PrevTriggerTime2 > 1.5) then
			self.PrevTriggerTime2 = CurTime()
			self.RearBogey:EmitSound("subway_trains/chassis_"..math.random(1,3)..".wav", 70, math.random(90,110))
		end
	end

--------------------------------------------------------------------------------
function ENT:Think()
	local retVal = self.BaseClass.Think(self)
	return retVal
end

--------------------------------------------------------------------------------

	-- Exchange some parameters between engines, pneumatic system, and real world
	self.Engines:TriggerInput("Speed",self.Speed)
	if IsValid(self.FrontBogey) and IsValid(self.RearBogey) then
		self.FrontBogey.MotorForce = 78500
		self.FrontBogey.Reversed = (self.RKR.Value > 2.5)
		self.RearBogey.MotorForce  = 78500
		self.RearBogey.Reversed = (self.RKR.Value < 1.5)

		-- These corrections are required to beat source engine friction at very low values of motor power
		local A = 2*self.Engines.BogeyMoment
		local P = math.max(0,1.04449 + 2.06879*math.abs(A) - 1.465729*A^2)
		if math.abs(A) > 1.4 then P = math.abs(A) end
		if math.abs(A) < 1.05 then P = 0 end
		if self.Speed < 30 then P = P*(1.0 + 0.5*(10.0-self.Speed)/10.0) end
		self.RearBogey.MotorPower  = P*0.5*((A > 0) and 1 or -1)
		self.FrontBogey.MotorPower = P*0.5*((A > 0) and 1 or -1)
		--self.RearBogey.MotorPower  = P*0.5
		--self.FrontBogey.MotorPower = P*0.5

		--self.Acc = (self.Acc or 0)*0.95 + self.Acceleration*0.05
		--print(self.Acc)

		-- Apply brakes
		self.FrontBogey.PneumaticBrakeForce = 40000.0
		self.FrontBogey.BrakeCylinderPressure = self.Pneumatic.BrakeCylinderPressure
		self.FrontBogey.BrakeCylinderPressure_dPdT = -self.Pneumatic.BrakeCylinderPressure_dPdT
		self.FrontBogey.ParkingBrake = self.ParkingBrake.Value > 0.5
		self.RearBogey.PneumaticBrakeForce = 40000.0
		self.RearBogey.BrakeCylinderPressure = self.Pneumatic.BrakeCylinderPressure
		self.RearBogey.BrakeCylinderPressure_dPdT = -self.Pneumatic.BrakeCylinderPressure_dPdT
		--self.RearBogey.ParkingBrake = self.ParkingBrake.Value > 0.5
	end


function ENT:OnCouple(train,isfront)
	self.BaseClass.OnCouple(self,train,isfront)

	if isfront then
		self.FrontBrakeLineIsolation:TriggerInput("Open",1.0)
		self.FrontTrainLineIsolation:TriggerInput("Open",1.0)
	else
		self.RearBrakeLineIsolation:TriggerInput("Open",1.0)
		self.RearTrainLineIsolation:TriggerInput("Open",1.0)
	end
end
function ENT:OnButtonPress(button)
	if button:find(":") then
		button = string.Explode(":",button)[2]
	end
	if string.find(button,"PneumaticBrakeSet") then
		self.Pneumatic:TriggerInput("BrakeSet",tonumber(button:sub(-1,-1)))
		return
	end
	if button == "FrontDoor" then
		self.FrontDoor = not self.FrontDoor
		if self.FrontDoor then self:PlayOnce("door_open_tor") else self:PlayOnce("door_close_tor") end
	end
	if button == "RearDoor" then
		self.RearDoor = not self.RearDoor
		if self.RearDoor then self:PlayOnce("door_open_tor") else self:PlayOnce("door_close_tor") end
	end

	if button == "DriverValveDisconnectToggle" then
		if self.DriverValveDisconnect.Value == 1.0 then
			if self.Pneumatic.ValveType == 2 then
				self:PlayOnce("pneumo_disconnect2","cabin",0.9)
			end
		else
			self:PlayOnce("pneumo_disconnect1","cabin",0.9)
		end
		return
	end
	if string.find(button,"PneumaticBrakeSet") then
		self.Pneumatic:TriggerInput("BrakeSet",tonumber(button:sub(-1,-1)))
		return
	end
end

function ENT:OnButtonRelease(button)
	if button:find(":") then
		button = string.Explode(":",button)[2]
	end
	if (button == "PneumaticBrakeDown") and (self.Pneumatic.DriverValvePosition == 1) then
		self.Pneumatic:TriggerInput("BrakeSet",2)
	end
	if self.Pneumatic.ValveType == 1 then
		if (button == "PneumaticBrakeUp") and (self.Pneumatic.DriverValvePosition == 5) then
			self.Pneumatic:TriggerInput("BrakeSet",4)
		end
	end
end
