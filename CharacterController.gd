extends CharacterBody3D

## Настройки движения
@export_category("Movement Settings")
@export var walk_speed := 4.0
@export var run_speed := 7.0
@export var crouch_speed := 2.5
@export var acceleration := 10.0
@export var deceleration := 15.0
@export var air_acceleration := 3.0
@export var jump_velocity := 6.5
@export var crouch_jump_reduction := 0.7
@export var direction_change_smoothness := 0.2 # Плавность изменения направления
@export var stopping_inertia_factor := 0.3 # Фактор инерции при остановке

## Настройки системы усталости
@export_category("Stamina System")
@export var max_stamina := 100.0
@export var stamina_depletion_rate := 20.0 # Скорость расходования при беге
@export var stamina_recovery_rate := 15.0 # Скорость восстановления
@export var stamina_recovery_delay := 1.5 # Задержка перед восстановлением
@export var exhausted_speed_multiplier := 0.6 # Множитель скорости при усталости

## Настройки камеры
@export_category("Camera Settings")
@export var mouse_sensitivity := 0.1
@export var camera_pitch_limit := 89.0
@export var camera_shake_intensity := 0.5 # Интенсивность тряски при падениях

## Настройки реалистичных эффектов
@export_category("Realism Effects")
@export var head_bob_frequency := 2.0
@export var head_bob_amplitude := 0.05
@export var fov_change_amount := 10.0
@export var footstep_sounds: Array[AudioStream]
@export var landing_sounds: Array[AudioStream]
@export var jump_sounds: Array[AudioStream]
@export var breathing_sounds: Array[AudioStream]
@export var exhausted_breathing_sounds: Array[AudioStream]

## Компоненты
@onready var camera := $Camera3D
@onready var animation_player := $AnimationPlayer
@onready var footstep_audio := $FootstepAudio
@onready var jump_land_audio := $JumpLandAudio
@onready var breathing_audio := $BreathingAudio
@onready var crouch_raycast := $CrouchRayCast
@onready var standing_collision := $StandingCollision
@onready var crouching_collision := $CrouchingCollision
@onready var stamina_recovery_timer := $StaminaRecoveryTimer

## Переменные состояния
var current_speed: float
var is_running := false
var is_crouching := false
var is_grounded := true
var was_grounded := true
var movement_dir := Vector3.ZERO
var head_bob_time := 0.0
var current_fov: float
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
var stamina := max_stamina
var is_exhausted := false
var last_movement_direction := Vector3.ZERO
var current_velocity_horizontal := Vector3.ZERO
var camera_shake_time := 0.0
var camera_shake_duration := 0.0
var fall_impact := 0.0

func _ready():
    current_speed = walk_speed
    current_fov = camera.fov
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    stamina_recovery_timer.wait_time = stamina_recovery_delay

func _input(event):
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
        camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-camera_pitch_limit), deg_to_rad(camera_pitch_limit))
    
    if event is InputEventKey and event.keycode == KEY_ESCAPE:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
    handle_movement_input()
    handle_stamina(delta)
    apply_gravity(delta)
    handle_jumping()
    handle_crouching()
    apply_movement(delta)
    update_camera_effects(delta)
    check_landing()
    
    was_grounded = is_grounded
    is_grounded = is_on_floor()

func handle_movement_input():
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var target_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Плавное изменение направления движения
    if target_dir.length() > 0.1:
        movement_dir = movement_dir.lerp(target_dir, direction_change_smoothness)
        last_movement_direction = movement_dir
    else:
        # Инерция при остановке
        movement_dir = movement_dir.lerp(Vector3.ZERO, stopping_inertia_factor)
    
    # Бег с учетом усталости
    is_running = Input.is_action_pressed("sprint") and not is_crouching and is_grounded and not is_exhausted
    var speed_multiplier = exhausted_speed_multiplier if is_exhausted else 1.0
    current_speed = run_speed * speed_multiplier if is_running else (crouch_speed if is_crouching else walk_speed)
    
    # Плавное изменение FOV
    var target_fov = current_fov + (fov_change_amount if is_running and movement_dir != Vector3.ZERO else 0)
    camera.fov = lerp(camera.fov, target_fov, 0.1)

func handle_stamina(delta):
    if is_running and movement_dir.length() > 0.1:
        stamina = max(stamina - stamina_depletion_rate * delta, 0)
        stamina_recovery_timer.start()
        
        if stamina <= 0:
            is_exhausted = true
            play_random_sound(exhausted_breathing_sounds, breathing_audio)
    else:
        if stamina_recovery_timer.is_stopped() and stamina < max_stamina:
            stamina = min(stamina + stamina_recovery_rate * delta, max_stamina)
            
            if stamina > max_stamina * 0.3:
                is_exhausted = false
    
    # Звуки дыхания
    if is_running and breathing_audio.playing == false and randf() < 0.1:
        play_random_sound(breathing_sounds, breathing_audio)

func apply_gravity(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta

func handle_jumping():
    if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
        velocity.y = jump_velocity * (crouch_jump_reduction if is_crouching else 1.0)
        play_random_sound(jump_sounds, jump_land_audio)

func handle_crouching():
    var want_to_crouch = Input.is_action_pressed("crouch")
    
    if is_crouching and not want_to_crouch:
        crouch_raycast.force_raycast_update()
        if crouch_raycast.is_colliding():
            return
    
    if want_to_crouch != is_crouching:
        is_crouching = want_to_crouch
        standing_collision.disabled = is_crouching
        crouching_collision.disabled = not is_crouching
        
        var target_height = 0.8 if is_crouching else 1.6
        animation_player.play("crouch_transition", -1, 5.0)
        animation_player.queue("RESET")

func apply_movement(delta):
    var target_velocity = movement_dir * current_speed
    
    # Сохраняем текущую горизонтальную скорость для плавности
    current_velocity_horizontal = Vector3(velocity.x, 0, velocity.z)
    var acceleration_rate = acceleration if is_on_floor() else air_acceleration
    var deceleration_rate = deceleration if is_on_floor() else air_acceleration
    
    if target_velocity.length() > 0.1:
        current_velocity_horizontal = current_velocity_horizontal.lerp(target_velocity, acceleration_rate * delta)
    else:
        current_velocity_horizontal = current_velocity_horizontal.move_toward(Vector3.ZERO, deceleration_rate * delta)
    
    velocity.x = current_velocity_horizontal.x
    velocity.z = current_velocity_horizontal.z
    
    move_and_slide()

func update_camera_effects(delta):
    # Эффект покачивания головы
    if is_on_floor() and velocity.length() > 1.0:
        head_bob_time += delta * velocity.length() * (0.5 if is_crouching else 1.0)
        var head_bob = Vector3(
            sin(head_bob_time * head_bob_frequency) * head_bob_amplitude,
            cos(head_bob_time * head_bob_frequency * 2) * head_bob_amplitude * 0.5,
            0
        )
        camera.position = head_bob
    else:
        camera.position = camera.position.lerp(Vector3.ZERO, 10.0 * delta)
        head_bob_time = 0.0
    
    # Наклон при движении вбок
    var tilt_amount = -velocity.x * 0.01 if is_on_floor() else 0.0
    camera.rotation.z = lerp(camera.rotation.z, tilt_amount, 10.0 * delta)
    
    # Тряска камеры при падениях
    if camera_shake_duration > 0:
        camera_shake_time += delta
        camera_shake_duration -= delta
        
        var shake_amount = fall_impact * camera_shake_intensity
        var shake_offset = Vector3(
            randf_range(-shake_amount, shake_amount),
            randf_range(-shake_amount, shake_amount),
            0
        ) * (camera_shake_duration / fall_impact)
        
        camera.position += shake_offset
    else:
        camera_shake_time = 0

func check_landing():
    if not was_grounded and is_grounded:
        fall_impact = clamp(abs(velocity.y) / jump_velocity, 0.2, 2.0)
        
        if fall_impact > 0.8:
            play_random_sound(landing_sounds, jump_land_audio)
            animation_player.play("land_impact", -1, 2.0 * fall_impact)
            animation_player.queue("RESET")
            
            # Тряска камеры пропорциональная силе падения
            camera_shake_duration = fall_impact * 0.5

func play_random_sound(sounds: Array[AudioStream], audio_player: AudioStreamPlayer3D):
    if sounds.size() > 0:
        audio_player.stream = sounds[randi() % sounds.size()]
        audio_player.pitch_scale = randf_range(0.9, 1.1)
        audio_player.play()
