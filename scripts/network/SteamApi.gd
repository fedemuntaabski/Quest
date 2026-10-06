class_name SteamApi
extends RefCounted

## SteamApi (multijugador-11): the only way scripts reach GodotSteam. Never write the
## `Steam` identifier or the `SteamMultiplayerPeer` type directly: when the extension
## is missing (e.g. a fresh clone without the gitignored .dll) they are parse errors
## and the whole menu fails to load, offline included. Values below were read from
## GodotSteam 4.22.1 (ClassDB) so they exist even without the extension.

const RESULT_OK: int = 1
const AUTH_SESSION_RESPONSE_OK: int = 0
const BEGIN_AUTH_SESSION_RESULT_OK: int = 0
const LOBBY_TYPE_FRIENDS_ONLY: int = 1
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS: int = 1
const AVATAR_MEDIUM: int = 2
const PERSONA_CHANGE_AVATAR: int = 64


## The GodotSteam singleton, or null when the extension is not loaded.
static func steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


static func has_extension() -> bool:
	return Engine.has_singleton("Steam")


## A new SteamMultiplayerPeer, or null when the extension is not loaded.
static func new_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	return ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
