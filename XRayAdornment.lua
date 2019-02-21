local NATIVESCALE_VALUENAME = "MetadataScale"
local CLEAN_ON_ADORNEE_DESTROY = true
--[[
	Written by GollyGreg

	The intent of this module is to offer a 3D "adornment" similar to how Roblox handles PVHandleAdornments.
	This can be used for visual effects to point out objectives or important objects on screen with depth.
	(Regardless if there may be something obstructing the user's view.)

	There's some sample code towards the very bottom of these notes!

	NOTICES:
	1) FileMeshes will not properly render materials.
		This means MeshIds that will not render the material like normal parts or unions.

	2) This should work reasonably well with upwards to a few hundred parts.
		Don't quote me on this though if you decide to play on your mom's laptop though...

	3) Lower FOV ranges (usually anything less than 10) may experience "jittery" behavior.

	4) MeshParts are an interesting case. We have to use SpecialMeshes to scale parts because of the 0.05 hard minimum size limit.
		In order to resize visuals below this 0.05 limit, we use SpecialMeshes. However MeshIds from MeshParts currently
		do not have a way of allow the script to read what the native mesh scale was when it was uploaded.
		If you have meshparts you wish to adorn and they have been resized since they have been imported, insert a Vector3Value
		as a child of the MeshPart and name it whatever the NATIVESCALE_VALUENAME string happens to be. Otherwise you'll likely have
		"larger than life" XRayAdornments when wrapping meshparts.

		!! TIP !!
		To easily snag the original scale of your MeshParts, make a new blank MeshPart and pass on your MeshId. The MeshPart will
		automatically scale to the original resolution. Use the new generated size as your Vector3Value!

	5) Make sure you destroy these if you're done with them.
		I ain't your mother

	--=================----===================----=================--
	--=================--  PROPERTIES AND SUCH  --=================--
	--=================----===================----=================--
	XRayAdornment constructor:
		XRayAdornment.new(BasePart Adornee)
			- You can't do anything with this module until you call this constructor.
			- Adornee must be a BasePart (sans Terrian)
			- The following BaseParts are not supported and will be rendered as block parts:
				- TrussParts, UnionOperations, CornerWedgeParts

	XRayAdornment properties
		!! Set these properties like you would any other Roblox object. !!

		bool .Enabled < = true>
			- 	Determines whether or not the object will be displayed

		BasePart .Adornee < = nil>
			-	The BasePart the XRayAdornment is attached to. Determines both shape and screen position.

		BasePart .SelectionPart < = nil>
			- 	The visual BasePart the XRayAdornment creates. Parented to the Camera.
			- 	Use this to change the appearnce of the effect.

		float .ZIndex < = 0>
			- 	Affects the display order for overlapping adornments.

	XRayAdornment methods
		!! Call these methods like you would any other Roblox object. !!

		void :Destroy()
			-	"Takes care of" the XRayAdornment. Rubs em out. Gone.

	--Example code:
	The following example is rough and dirty, but gets the point across.
	This snippit will grant you a "silhoutte" effect when your camera is hidden behind walls
		NOTES
			- assuming PopperCam behavior is disabled for some reason
			-- otherwise you can walk behind a non-Collidable screen

	--=================----==================----=================--
	--=================--  EXAMPLE CODE BELOW  --=================--
	--=================----==================----=================--
	>>>>>>>>
	>>>>>>>> -- Put this in the Player's PlayerScript somehow
	>>>>>>>>
	>>>>>>>>
		local localPlayer = game:GetService("Players").LocalPlayer
		local myCharacter = localPlayer.Character or localPlayer.CharacterAppearanceLoaded:wait()
		local XRayAdornment = require(script.XRayAdornment)

		local myShadowAdornments = {}
		local function onNewCharacter(character)
			--pass on new character reference
			myCharacter = character
			--reset adornments from last character (should probably clean this on death instead)
			for _, oldAdornment in pairs(myShadowAdornments) do
				oldAdornment:Destroy()
			end
			myShadowAdornments = {}

			for _, Object in pairs(character:GetDescendants()) do
				if Object:IsA("BasePart") and Object.Transparency < 0.95 then
					local myXRayAdornment = XRayAdornment.new(Object)
					myXRayAdornment.SelectionPart.Color = BrickColor.new("Storm blue").Color
					table.insert(myShadowAdornments, myXRayAdornment)
				end
			end

		end
		localPlayer.CharacterAppearanceLoaded:connect(onNewCharacter)
		onNewCharacter(myCharacter)

		--this loop will only show shadows when we are hidden
		game:GetService("RunService"):BindToRenderStep("OcculsionCheck", Enum.RenderPriority.Character.Value, function()
			local primaryPart = myCharacter.PrimaryPart
			if primaryPart then
				local camera = workspace.CurrentCamera
				local occluded = false
				local objectList = camera:GetPartsObscuringTarget({primaryPart.Position}, {camera, myCharacter})
				for _, object in pairs(objectList) do
					if object.Transparency < 0.95 then
						occluded = true
						break
					end
				end
				for _, adornment in pairs(myShadowAdornments) do
					adornment.Enabled = occluded
				end
			end
		end)
	>>>>>>>>
	>>>>>>>>
	>>>>>>>>
	>>>>>>>>
	--=================----===================----=================--
	--=================--  END OF EXAMPLE CODE  --=================--
	--=================----===================----=================--
--]]
local RunService = game:GetService("RunService")

local stack = {}

RunService:BindToRenderStep("xRayAdornmentStep", Enum.RenderPriority.Last.Value - 1, function()
	local camera = workspace.CurrentCamera
	for index = #stack, 1, -1 do
		stack[index]:Update(camera)
	end
end)

local function resolveMesh(adornee)
	local childMesh = adornee:FindFirstChildWhichIsA("DataModelMesh")
	if childMesh then
		local mesh = childMesh:Clone()
		if mesh:IsA("SpecialMesh") then
			mesh.TextureId = ""
		end
		mesh.Offset = Vector3.new()
		return mesh
	else
		if adornee:IsA("Part") then
			if adornee.Shape == Enum.PartType.Block then
				local mesh = Instance.new("BlockMesh")
				return mesh
			elseif adornee.Shape == Enum.PartType.Ball then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				return mesh
			elseif adornee.Shape == Enum.PartType.Cylinder then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Cylinder
				return mesh
			end
		elseif adornee:IsA("WedgePart") then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Wedge
			return mesh
		elseif adornee:IsA("MeshPart") then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.FileMesh
			mesh.MeshId = adornee.MeshId
			return mesh
		else
			--seats, unions, trusses, cornerwedgeparts, etc
			local mesh = Instance.new("BlockMesh")
			return mesh
		end
	end
end

local XRayAdornment = {}
XRayAdornment.__index = XRayAdornment
XRayAdornment.ClassName = "XRayAdornment"

function XRayAdornment.new(adornee)
	assert(adornee:IsA("BasePart") == true and adornee:IsA("Terrain") == false,
		string.format("[XRayAdornment] - Invalid argument, must be a BasePart! Got %s instead.",
		adornee.ClassName)
	)
	local self = setmetatable({}, XRayAdornment)

	self._mesh = nil
	self._nativeScale = adornee:IsA("MeshPart") and adornee.Size or Vector3.new(1, 1, 1)

	local selectionPart = Instance.new("Part")
	selectionPart.Anchored = true
	selectionPart.CanCollide = false
	selectionPart.Size = Vector3.new(1, 1, 1)
	selectionPart.Material = Enum.Material.SmoothPlastic
	selectionPart.TopSurface = Enum.SurfaceType.Smooth
	selectionPart.BottomSurface = Enum.SurfaceType.Smooth

	self.Enabled = true
	self.Adornee = adornee
	self.SelectionPart = selectionPart
	self.ZIndex = 0
	self._mesh = resolveMesh(adornee)
	self._adorneeMesh = adornee:FindFirstChildOfClass("SpecialMesh")
	self._connections = {}

	local nativeValue = adornee:FindFirstChild(NATIVESCALE_VALUENAME)
	if nativeValue then
		self._nativeScale = nativeValue.Value
	end

	self._mesh.Parent = selectionPart
	table.insert(stack, self)

	selectionPart.Parent = workspace.CurrentCamera

	if CLEAN_ON_ADORNEE_DESTROY == true then
		table.insert(self._connections, adornee.AncestryChanged:Connect(function(_, newParent)
			if newParent == nil then
				self:Destroy()
			end
		end))
	end

	return self
end

function XRayAdornment:Destroy()
	for index, reference in pairs(stack) do
		if reference == self then
			table.remove(stack, index)
			break
		end
	end
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	self.SelectionPart:Destroy()
end

function XRayAdornment:Update(camera)
	local translatedZIndex = 0.2 + (10 - math.min(10, self.ZIndex)) / 10
	if self.Enabled then
		local adornee = self.Adornee
		local selectionPart = self.SelectionPart
		local deltaFromCamera = (adornee.Position - camera.CFrame.p)
		if self._adorneeMesh then
			self._mesh.Scale = self._adorneeMesh.Scale / (deltaFromCamera.magnitude) * translatedZIndex
		else
			self._mesh.Scale = adornee.Size / (deltaFromCamera.magnitude) / self._nativeScale * translatedZIndex
		end
		selectionPart.CFrame = CFrame.new(camera.CFrame.p + deltaFromCamera.unit * translatedZIndex)
			* (adornee.CFrame - adornee.CFrame.p)
		if selectionPart.Parent == nil then
			selectionPart.Parent = camera
		end
	else
		self.SelectionPart.Parent = nil
	end
end

return XRayAdornment
