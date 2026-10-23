extends CharacterBody3D

@export var move_speed: float = 5.2
@export var jump_velocity: float = 4.5
var move_vector: Vector2 = Vector2.ZERO
var camera_yaw: float = 0.0
var camera_pitch: float = -0.18
var aiming: bool = false
var gravity: float = 12.0
var camera_pivot: Node3D
var camera: Camera3D
var bow: Node3D
var arm_left: MeshInstance3D
var arm_right: MeshInstance3D

func _ready() -> void:
    name = "Survivor"
    collision_layer = 1
    collision_mask = 1
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.34
    capsule.height = 1.85
    var collision := CollisionShape3D.new()
    collision.shape = capsule
    collision.position.y = 0.93
    add_child(collision)
    _make_body()
    camera_pivot = Node3D.new()
    camera_pivot.position = Vector3(0, 1.55, 0)
    add_child(camera_pivot)
    var spring := SpringArm3D.new()
    spring.spring_length = 4.2
    spring.margin = 0.25
    camera_pivot.add_child(spring)
    camera = Camera3D.new()
    camera.position = Vector3(0, 0.15, 0)
    camera.current = true
    camera.fov = 72.0
    spring.add_child(camera)
    _make_bow()

func _make_body() -> void:
    var shirt := _material(Color(0.24, 0.31, 0.22))
    var pants := _material(Color(0.25, 0.22, 0.17))
    var skin := _material(Color(0.62, 0.42, 0.29))
    var pack := _material(Color(0.15, 0.19, 0.14))
    _part(CapsuleMesh.new(), shirt, Vector3(0, 1.22, 0), Vector3(0.56, 0.75, 0.38))
    _part(BoxMesh.new(), pack, Vector3(0, 1.34, 0.24), Vector3(0.42, 0.55, 0.20))
    _part(SphereMesh.new(), skin, Vector3(0, 1.91, 0), Vector3(0.34, 0.36, 0.32))
    var hair := _part(SphereMesh.new(), _material(Color(0.12, 0.10, 0.08)), Vector3(0, 2.04, 0.01), Vector3(0.35, 0.20, 0.33))
    for side in [-1.0, 1.0]:
        _part(CapsuleMesh.new(), pants, Vector3(side * 0.15, 0.48, 0), Vector3(0.23, 0.63, 0.25))
        _part(BoxMesh.new(), _material(Color(0.10, 0.09, 0.07)), Vector3(side * 0.15, 0.12, -0.04), Vector3(0.22, 0.18, 0.34))
        var arm := _part(CapsuleMesh.new(), shirt, Vector3(side * 0.37, 1.32, -0.02), Vector3(0.19, 0.55, 0.20))
        if side < 0:
            arm_left = arm
        else:
            arm_right = arm

func _part(mesh: Mesh, material: Material, pos: Vector3, scale_value: Vector3) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = material
    node.position = pos
    node.scale = scale_value
    add_child(node)
    return node

func _material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.88
    return m

func _make_bow() -> void:
    bow = Node3D.new()
    bow.name = "Bow"
    bow.position = Vector3(0.42, 1.35, -0.38)
    add_child(bow)
    var arc := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.20
    torus.outer_radius = 0.235
    arc.mesh = torus
    arc.material_override = _material(Color(0.35, 0.19, 0.08))
    arc.rotation.x = deg_to_rad(90)
    arc.scale = Vector3(0.75, 1.25, 0.75)
    bow.add_child(arc)
    var string_mesh := MeshInstance3D.new()
    var line := CylinderMesh.new()
    line.top_radius = 0.008
    line.bottom_radius = 0.008
    line.height = 0.52
    string_mesh.mesh = line
    string_mesh.material_override = _material(Color(0.85, 0.79, 0.62))
    string_mesh.position.z = -0.01
    string_mesh.rotation.z = deg_to_rad(90)
    bow.add_child(string_mesh)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif velocity.y < 0:
        velocity.y = 0
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    var input_dir := move_vector
    if input_dir.length() < 0.05:
        input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    if direction.length() > 0.01:
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
    camera_pivot.rotation.y = camera_yaw
    camera_pivot.rotation.x = camera_pitch
    camera.fov = lerp(camera.fov, 52.0 if aiming else 72.0, delta * 8.0)
    bow.visible = true
    move_and_slide()

func rotate_camera(delta_x: float, delta_y: float) -> void:
    camera_yaw -= delta_x * 0.006
    camera_pitch = clamp(camera_pitch - delta_y * 0.004, -0.85, 0.38)

func set_aiming(value: bool) -> void:
    aiming = value

func get_aim_origin() -> Vector3:
    return camera.global_position

func get_aim_direction() -> Vector3:
    return -camera.global_transform.basis.z
