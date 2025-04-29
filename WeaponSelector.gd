extends Control
class_name WeaponSelector

signal weapon_selected(weapon_slot: WeaponSlot)
signal skin_selected(weapon_name: String, skin_index: int)

var available_weapons: Array[WeaponSlot] = []
var weapon_skins: Dictionary = {}  # Format: { "weapon_name": [texture1, texture2, ...] }

@onready var weapon_grid = $WeaponGrid
@onready var skin_grid = $SkinGrid
@onready var weapon_preview = $WeaponPreview

func _ready():
    load_available_weapons()
    load_weapon_skins()
    populate_weapon_grid()

func load_available_weapons():
    # Load all weapon resources from a directory
    var dir = DirAccess.open("res://Weapons/Resources/")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".tres"):
                var weapon_resource = load("res://Weapons/Resources/" + file_name)
                if weapon_resource is WeaponResource:
                    var slot = WeaponSlot.new()
                    slot.weapon = weapon_resource
                    available_weapons.append(slot)
            file_name = dir.get_next()

func load_weapon_skins():
    # Example structure - you would load this from a config file or directory
    weapon_skins = {
        "Pistol": [
            preload("res://Weapons/Skins/pistol_default.png"),
            preload("res://Weapons/Skins/pistol_gold.png")
        ],
        "Rifle": [
            preload("res://Weapons/Skins/rifle_default.png"),
            preload("res://Weapons/Skins/rifle_camo.png")
        ]
    }

func populate_weapon_grid():
    for weapon_slot in available_weapons:
        var button = TextureButton.new()
        button.texture_normal = weapon_slot.weapon.menu_icon
        button.custom_minimum_size = Vector2(100, 100)
        button.pressed.connect(_on_weapon_selected.bind(weapon_slot))
        weapon_grid.add_child(button)

func _on_weapon_selected(weapon_slot: WeaponSlot):
    weapon_selected.emit(weapon_slot)
    show_skins_for_weapon(weapon_slot.weapon.weapon_name)
    update_weapon_preview(weapon_slot)

func show_skins_for_weapon(weapon_name: String):
    clear_skin_grid()
    
    if weapon_name in weapon_skins:
        for i in range(weapon_skins[weapon_name].size()):
            var button = TextureButton.new()
            button.texture_normal = weapon_skins[weapon_name][i]
            button.custom_minimum_size = Vector2(50, 50)
            button.pressed.connect(_on_skin_selected.bind(weapon_name, i))
            skin_grid.add_child(button)

func clear_skin_grid():
    for child in skin_grid.get_children():
        child.queue_free()

func update_weapon_preview(weapon_slot: WeaponSlot):
    # This would show a 3D preview of the weapon with current skin
    weapon_preview.update_preview(weapon_slot)

func _on_skin_selected(weapon_name: String, skin_index: int):
    skin_selected.emit(weapon_name, skin_index)
    # Update preview with new skin
