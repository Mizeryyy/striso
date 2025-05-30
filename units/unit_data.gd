# res://units/unit_data.gd
extends Resource
class_name UnitData

# Enum for broad action categories. Specifics like damage/range are separate.
# This helps in UI and high-level logic.
enum ActionCategory {
	NONE,
	ATTACK,
	HEAL,
	BUILD,
	BUFF,
	DEBUFF,
	GATHER,
	SPECIAL # For unique actions not fitting above
}

@export_group("Identification & Display")
@export var unit_id: StringName = &""  # Unique internal ID, e.g., "worker", "soldier_melee"
@export var unit_name: String = "Unnamed Unit" # Display name, e.g., "Worker", "Footman"
@export var description: String = "A standard unit."
@export var icon: Texture2D # For UI elements
@export var model_scene: PackedScene # The 3D model/scene for this unit in the game world

@export_group("Grid & Placement")
@export var footprint_size: Vector2i = Vector2i(1, 1) # How many tiles the unit occupies (width, depth)

@export_group("Core Stats")
@export var max_health: int = 100
@export var movement_range: int = 3  # In grid tiles
@export var defense_rating: int = 0   # Flat damage reduction, or basis for % reduction

@export_group("Primary Action") # The most common action this unit performs
@export var primary_action_category: ActionCategory = ActionCategory.NONE
@export var primary_action_name: String = "Action" # e.g., "Attack", "Heal", "Build"
@export var primary_action_power: int = 10 # Damage for attack, heal amount, build speed factor etc.
@export var primary_action_range: int = 1  # In grid tiles (1 for melee)
@export var primary_action_ap_cost: int = 1 # Action Points cost for this action

# More actions can be defined as an array of more complex "ActionAbility" resources later
# For now, we can list identifiers for special abilities that components will handle.
@export_group("Special Abilities")
@export var special_ability_ids: Array[StringName] = [] # e.g., [&"repair", &"charge", &"overwatch"]

@export_group("Economy & Production")
@export var resource_cost: Dictionary = {"gold": 50} # e.g., {"gold": 100, "wood": 25}
@export var build_time_seconds: float = 5.0 # Time to produce this unit
@export var supply_cost: int = 1 # How much "supply" or "population cap" this unit takes

@export_group("Tags & Classification")
@export var unit_tags: Array[StringName] = [] # e.g., [&"infantry", &"melee", &"human", &"builder"]

# You can add more fields as needed, like:
# @export var vision_range: int = 5
# @export var attack_animation_name: StringName = &"attack"
# @export var move_sfx: AudioStream
# @export var attack_sfx: AudioStream
# @export var death_effect_scene: PackedScene


func _init(p_id := &"", p_name := "Default", p_health := 10, p_move := 1, p_footprint := Vector2i(1,1)):
	unit_id = p_id
	unit_name = p_name
	max_health = p_health
	movement_range = p_move
	footprint_size = p_footprint
	# Initialize other defaults if necessary
