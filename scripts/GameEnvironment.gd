extends Node2D

class_name GameEnvironment

# Scene references
@onready var map_manager: MapManager = $MapManager
@onready var player: CharacterBody2D = $MapManager/Player
var hud: HUDController

# Test enemy
var test_enemy: CharacterStats

func _ready():
	print("\n=== QUEST - Game Environment Initializing ===\n")
	
	# Wait a frame for autoloads to be ready
	await get_tree().process_frame
	
	# Find HUD
	hud = get_tree().root.get_node_or_null("GameEnvironment/HUD")
	if hud:
		print("GameEnvironment: HUD found")
	
	# Get player stats
	var player_stats = player.get_node("Stats")
	if player_stats:
		print("GameEnvironment: Player stats found")
		# Update HUD with initial stats
		if hud:
			hud.update_stats(player_stats)
	
	# Create test enemy
	_create_test_enemy()
	
	# Setup test skill cards
	_setup_test_cards()
	
	print("\n=== Game Ready - You are in EXPLORATION mode ===")
	print("Use WASD to move the player toward the enemy at (2, 2)")
	print("When you enter the enemy cell, combat will be initiated.")
	print("\n")

func _create_test_enemy() -> void:
	"""Create a test enemy and place it on the map"""
	test_enemy = CharacterStats.new()
	test_enemy.initialize(
		"Goblin",
		"Goblin",
		8,
		0,   # strength_modifier
		0,   # magic_modifier
		0    # dexterity_modifier
	)
	
	# Place enemy at grid position (2, 2) which is world position (4, 4)
	var enemy_world_pos = Vector2(4, 4)
	map_manager.register_enemy(enemy_world_pos, test_enemy)
	print("GameEnvironment: Test enemy '%s' placed at world position %v" % [test_enemy.character_name, enemy_world_pos])

func _setup_test_cards() -> void:
	"""Setup test skill cards in the HUD"""
	if not hud:
		return
	
	# Create test cards
	var test_cards = [
		{
			"name": "Slash",
			"description": "A basic sword attack",
			"stat": GameManager.STRENGTH,
			"base_damage": 2
		},
		{
			"name": "Magic Missile",
			"description": "Arcane projectile",
			"stat": GameManager.MAGIC,
			"base_damage": 1
		},
		{
			"name": "Dodge",
			"description": "Quick evasion",
			"stat": GameManager.DEXTERITY,
			"base_damage": 0
		}
	]
	
	# Add cards to container
	for card_data in test_cards:
		if hud.add_card_to_container(card_data):
			print("GameEnvironment: Test card added - '%s'" % card_data.get("name"))

# Handle combat test attacks from console (for testing)
func test_attack() -> void:
	"""Console test function to trigger an attack"""
	if TurnManager.current_state != TurnManager.State.PLAYER_COMBAT:
		print("Not in combat!")
		return
	
	var equipped_cards = hud.get_equipped_cards()
	if equipped_cards.size() == 0:
		print("No equipped cards!")
		return
	
	# Create a SkillCard from first equipped card data
	var card_data = equipped_cards[0]
	var skill_card = SkillCard.new()
	skill_card.setup(
		card_data.get("name", ""),
		card_data.get("description", ""),
		card_data.get("stat", GameManager.STRENGTH),
		card_data.get("base_damage", 1)
	)
	
	# Execute attack via TurnManager
	TurnManager.player_attack(skill_card)
