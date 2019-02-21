# rbx-XRayAdornment
The intent of this module is to offer a 3D "adornment" similar to how Roblox handles PVHandleAdornments.
This can be used for visual effects to point out objectives or important objects on screen with depth.
(Regardless if there may be something obstructing the user's view.)

*There's some sample code towards the very bottom of these notes!*

# Notices:
1. FileMeshes will not properly render materials.
  * This means MeshIds that will not render the material like normal parts or unions.
2. This should work reasonably well with upwards to a few hundred parts.
  * Don't quote me on this though if you decide to play on your mom's laptop though...
3. Lower FOV ranges (usually anything less than 10) may experience "jittery" behavior.
4. MeshParts are an interesting case. 
  * We have to use SpecialMeshes to scale parts because of the 0.05 hard minimum size limit.
In order to resize visuals below this 0.05 limit, we use SpecialMeshes. However MeshIds from MeshParts currently
do not have a way of allow the script to read what the native mesh scale was when it was uploaded.
If you have meshparts you wish to adorn and they have been resized since they have been imported, insert a Vector3Value
as a child of the MeshPart and name it whatever the NATIVESCALE_VALUENAME string happens to be. Otherwise you'll likely have
"larger than life" XRayAdornments when wrapping meshparts.

**TIP**
To easily snag the original scale of your MeshParts, make a new blank MeshPart and pass on your MeshId. The MeshPart will
automatically scale to the original resolution. Use the new generated size as your Vector3Value!

5) Make sure you destroy these if you're done with them.
I ain't your mother

# API Docs
XRayAdornment constructor:
	XRayAdornment.new(BasePart Adornee)
		- You can't do anything with this module until you call this constructor.
		- Adornee must be a BasePart (sans Terrian)
		- The following BaseParts are not supported and will be rendered as block parts:
			- TrussParts, UnionOperations, CornerWedgeParts

## Properties ##
	**!! Set these properties like you would any other Roblox object. !!**

	bool .Enabled < = true>
		- 	Determines whether or not the object will be displayed

	BasePart .Adornee < = nil>
		-	The BasePart the XRayAdornment is attached to. Determines both shape and screen position.

	BasePart .SelectionPart < = nil>
		- 	The visual BasePart the XRayAdornment creates. Parented to the Camera.
		- 	Use this to change the appearnce of the effect.

	float .ZIndex < = 0>
		- 	Affects the display order for overlapping adornments.

## Methods ##
	**!! Call these methods like you would any other Roblox object. !!**

	void :Destroy()
		-	"Takes care of" the XRayAdornment. Rubs em out. Gone.


# Examples
The following example is rough and dirty, but gets the point across.
This snippet will grant you a "silhoutte" effect when your camera is hidden behind walls
	**NOTES**
		- assuming PopperCam behavior is disabled for some reason
		-- otherwise you can walk behind a non-Collidable screen
 
```
  -- Put this in the Player's PlayerScript somehow
	local localPlayer = game:GetService("Players").LocalPlayer
	local myCharacter = localPlayer.Character or localPlayer.CharacterAppearanceLoaded:wait()
	local XRayAdornment = require(script.XRayAdornment)

	local myShadowAdornments = {}
	local function onNewCharacter(character)
		-- pass on new character reference
		myCharacter = character
		-- reset adornments from last character (should probably clean this on death instead)
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

	-- this loop will only show shadows when we are hidden
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
	end)```
