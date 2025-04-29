extends Resource
class_name WeaponResource

@export var weapon_name: String = "Weapon"
@export var weapon_scene: PackedScene  # Each weapon has its own scene
@export var menu_icon: Texture2D  # Icon for menu selection
@export var skins: Array[Texture2D] = []  # Available skins for this weapon
@export var default_skin_index: int = 0

# ... (rest of existing weapon properties)
