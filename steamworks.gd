extends Node

func _ready() -> void:
	initialize_steam()
	print(Steam.getFriendPersonaName(Steam.getSteamID()))
	#print(Steam.getUserSteamFriends())

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s" % initialize_response)

	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialize_response)
		get_tree().quit()
