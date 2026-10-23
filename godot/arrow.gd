extends Area3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 34.0
var lifetime: float = 2.5
var damage: int = 1
var shooter: Node

func _ready() -> void:
    var shaft := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.018
    mesh.bottom_radius = 0.012
    mesh.height = 0.72
    shaft.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.53, 0.36, 0.18)
    shaft.material_override = mat
    shaft.rotation.x = PI / 2.0
    add_child(shaft)
    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.12
    shape.shape = sphere
    add_child(shape)
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)
    monitoring = true

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    if direction.length() > 0.01:
        look_at(global_position + direction, Vector3.UP)
    lifetime -= delta
    if lifetime <= 0:
        queue_free()

func _on_body_entered(body: Node3D) -> void:
    if body == shooter:
        return
    if body.has_method("take_damage"):
        body.take_damage(damage)
    queue_free()

func _on_area_entered(area: Area3D) -> void:
    if area.has_method("take_damage"):
        area.take_damage(damage)
    queue_free()
