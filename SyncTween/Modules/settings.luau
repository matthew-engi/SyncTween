--!strict

local settings = {
	-- Global Settings
	COLLECTION_TAG = "SyncTween",

	SUPPORTED_TYPES = {
		"number",
		"boolean",
		"CFrame",
		"Rect",
		"Color3",
		"UDim",
		"UDim2",
		"Vector2",
		"Vector2int16",
		"Vector3",
		"EnumItem"
	},

	-- Synchronized Tween Settings
	FPS = -1,
} :: { [string]: any }

return settings