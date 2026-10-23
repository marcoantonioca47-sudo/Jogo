extends CharacterBody3D

@export var health: int = 2
@export var patrol_radius: float = 4.0
@export var detection_range: float = 13.0
@export var move_speed: float = 1.8
var player: Node3D
var home: Vector3
var phase: float = 0.0
var gravity: float = 12.0
var alerted: bool = false

func _ready() -> void:
    add_to_group("enemies")
    home = global_position
    var shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.3
    capsule.height = 1.7
    shape.shape = capsule
    shape.position.y = 0.85
    add_child(shape)
    _make_part(CapsuleMesh.new(), Color(0.28, 0.30, 0.22), Vector3(0, 1.08, 0), Vector3(0.53, 0.68, 0.35))
    _make_part(SphereMesh.new(), Color(0.52, 0.34, 0.23), Vector3(0, 1.72, 0), Vector3(0.32, 0.34, 0.30))
    _make_part(BoxMesh.new(), Color(0.12, 0.13, 0.11), Vector3(0.27, 1.16, -0.28), Vector3(0.12, 0.12, 0.55))

func _make_part(mesh: Mesh, color: Color, pos: Vector3, scale_value: Vector3) -> void:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    node.scale = scale_value
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    node.material_override = material
    add_child(node)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    var target := home
    if is_instance_valid(player):
        var distance := global_position.distance_to(player.global_position)
        if distance < detection_range:
            alerted = true
        if alerted and distance > 2.2:
            target = player.global_position
    phase += delta
    if not alerted:
        target = home + Vector3(sin(phase * 0.55) * patrol_radius, 0, cos(phase * 0.4) * patrol_radius)
    var offset := target - global_position
    offset.y = 0
    if offset.length() > 0.35:
        var dir := offset.normalized()
        velocity.x = dir.x * move_speed
        velocity.z = dir.z * move_speed
        rotation.y = atan2(-dir.x, -dir.z)
    if is_instance_valid(player) and global_position.distance_to(player.global_position) < 1.7:
        if player.has_method("take_damage"):
            player.take_damage(8)
    else:
        velocity.x = move_toward(velocity.x, 0.0, delta * 4.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 4.0)
    move_and_slide()

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        queue_free()
