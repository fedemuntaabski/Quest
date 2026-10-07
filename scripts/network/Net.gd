class_name Net
extends Object

## Net (coop-12): static access to the co-op session for gameplay code.
## Reads the NetSession autoload by node path (autoload names are not identifiers
## in `--script` tests). With no session or no peer the game is the local host:
## is_authority() is true and single player runs exactly as before.


static func session() -> CoopSession:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("NetSession") as CoopSession
	return null


## True when this process simulates the game: offline, or the co-op host.
static func is_authority() -> bool:
	var s := session()
	return s == null or s.is_authority()


## True while a co-op session (host or client) has a live peer.
static func is_online() -> bool:
	var s := session()
	return s != null and s.is_online()


## Local peer id (1 offline and on the host).
static func local_peer() -> int:
	var s := session()
	return s.local_peer() if s != null else 1
