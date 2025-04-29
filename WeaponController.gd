extends Node3D

signal weapon_changed
signal update_ammo
signal update_weapon_stack
signal hit_successfull
signal add_signal_to_hud
signal connect_weapon_to_hud

@export var animation_player: AnimationPlayer
@export var melee_hitbox: ShapeCast3D
@export var max_weapons: int = 3
@export var default_weapons: Array[WeaponSlot] = []

@onready var bullet_point = get_node("%BulletPoint")
@onready var debug_bullet = preload("res://Player_Controller/Spawnable_Objects/hit_debug.tscn")
@onready var weapon_model = $WeaponModel

var next_weapon: WeaponSlot
var spray_profiles: Dictionary = {}
var _count = 0
var shot_tween
var weapon_stack: Array[WeaponSlot] = []
var current_weapon_slot: WeaponSlot = null
var current_skin_indices: Dictionary = {}  # Stores skin index for each weapon

func _ready() -> void:
    # Load saved weapons and skins
    load_saved_weapons()
    
    if weapon_stack.is_empty() and not default_weapons.is_empty():
        weapon_stack = default_weapons.duplicate()
    
    if weapon_stack.is_empty():
        push_error("Weapon Stack is empty, please populate with weapons")
    else:
        animation_player.animation_finished.connect(_on_animation_finished)
        for i in weapon_stack:
            initialize(i)
        current_weapon_slot = weapon_stack[0]
        if check_valid_weapon_slot():
            enter()
            update_weapon_stack.emit(weapon_stack)

func load_saved_weapons():
    if SaveSystem.has_saved_data("weapons"):
        var saved_data = SaveSystem.load_data("weapons")
        weapon_stack = saved_data.weapon_stack
        current_skin_indices = saved_data.skin_indices

func save_current_weapons():
    var save_data = {
        "weapon_stack": weapon_stack,
        "skin_indices": current_skin_indices
    }
    SaveSystem.save_data("weapons", save_data)

func apply_weapon_skin(weapon_name: String, skin_index: int):
    if weapon_name in current_skin_indices:
        current_skin_indices[weapon_name] = skin_index
    else:
        current_skin_indices[weapon_name] = skin_index
    
    # Update current weapon if it's the one being skinned
    if current_weapon_slot and current_weapon_slot.weapon.weapon_name == weapon_name:
        update_weapon_model()

func update_weapon_model():
    if not current_weapon_slot or not current_weapon_slot.weapon:
        return
    
    # Clear current model
    for child in weapon_model.get_children():
        child.queue_free()
    
    # Instantiate new model with skin
    var weapon_scene = current_weapon_slot.weapon.weapon_scene.instantiate()
    weapon_model.add_child(weapon_scene)
    
    # Apply skin if available
    var weapon_name = current_weapon_slot.weapon.weapon_name
    if weapon_name in current_skin_indices:
        var skin_index = current_skin_indices[weapon_name]
        weapon_scene.apply_skin(skin_index)

func add_weapon_to_stack(weapon_slot: WeaponSlot, skin_index: int = 0):
    if weapon_stack.size() >= max_weapons:
        return false
    
    weapon_stack.append(weapon_slot)
    current_skin_indices[weapon_slot.weapon.weapon_name] = skin_index
    initialize(weapon_slot)
    update_weapon_stack.emit(weapon_stack)
    return true

func remove_weapon_from_stack(weapon_slot: WeaponSlot):
    var index = weapon_stack.find(weapon_slot)
    if index != -1:
        weapon_stack.remove_at(index)
        current_skin_indices.erase(weapon_slot.weapon.weapon_name)
        update_weapon_stack.emit(weapon_stack)
        return true
    return false

# ... (rest of the existing functions remain the same, with additions for skin support)

func enter() -> void:
    animation_player.queue(current_weapon_slot.weapon.pick_up_animation)
    weapon_changed.emit(current_weapon_slot.weapon.weapon_name)
    update_ammo.emit([current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo])
    update_weapon_model()
