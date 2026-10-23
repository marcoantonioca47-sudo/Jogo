extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const ENEMY_SCRIPT = preload("res://enemy.gd")
const ARROW_SCRIPT = preload("res://arrow.gd")

var player: CharacterBody3D
var health: int = 100
var arrows: int = 12
var mission_stage: int = 0
var enemies_total: int = 5
var hud_label: Label
var mission_label: Label
var health_label: Label
var arrow_label: Label
var toast_label: Label
var stick: Control
var stick_center: Vector2
var camera_touch_id: int = -1
var last_touch_position: Vector2
var touch_points: Dictionary = {}
var aiming: bool = false
var shoot_cooldown: float = 0.0
var mission_marker: Vector3 = Vector3(0, 0, -25)

func _ready() -> void:
    _build_environment()
    _build_world()
    _spawn_player()
    _spawn_enemies()
    _build_hud()
    _update_hud()

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.sky.sky_material = ProceduralSkyMaterial.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.58, 0.65, 0.55)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env.environment = env
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -32, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

func _build_world() -> void:
    _make_box("Terrain", Vector3(0, -0.6, -18), Vector3(120, 1, 120), Color(0.24, 0.34, 0.22))
    _make_box("Trail", Vector3(0, -0.03, -15), Vector3(4.0, 0.08, 45), Color(0.43, 0.36, 0.24))
    _make_box("CampGround", Vector3(0, -0.02, -27), Vector3(20, 0.1, 16), Color(0.30, 0.31, 0.23))
    _build_hut(Vector3(0, 0, -31))
    _build_fence()
    var rng := RandomNumberGenerator.new()
    rng.seed = 426
    for i in range(105):
        var x := rng.randf_range(-48, 48)
        var z := rng.randf_range(-66, 26)
        if abs(x) < 7 and z < -5 and z > -42:
            continue
        _build_tree(Vector3(x, 0, z), rng.randf_range(0.75, 1.45))
    for i in range(12):
        var x := -32.0 + float(i) * 5.8
        _build_mountain(Vector3(x, 1.5, -67.0 - (i % 3) * 4.0), 7.0 + float(i % 4) * 2.0, 14.0 + float(i % 5) * 3.0)

func _make_box(label_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = label_name
    body.position = pos
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    if label_name == "Terrain":
        mesh_node.material_override = _terrain_material()
    elif label_name == "Trail" or label_name == "CampGround":
        mesh_node.material_override = _soil_material()
    elif label_name == "Hut" or label_name == "FencePost" or label_name == "FenceRail":
        mesh_node.material_override = _wood_material(color)
    else:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.95
        mesh_node.material_override = mat
    body.add_child(mesh_node)
    var collision := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size
    collision.shape = box_shape
    body.add_child(collision)
    add_child(body)
    return body

func _build_tree(pos: Vector3, scale_value: float) -> void:
    var tree := Node3D.new()
    tree.position = pos
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.16 * scale_value
    trunk_mesh.bottom_radius = 0.28 * scale_value
    trunk_mesh.height = 2.6 * scale_value
    trunk.mesh = trunk_mesh
    trunk.position.y = 1.3 * scale_value
    trunk.material_override = _wood_material(Color(0.28, 0.19, 0.11))
    tree.add_child(trunk)
    for i in range(3):
        var crown := MeshInstance3D.new()
        var cone := PrismMesh.new()
        cone.size = Vector3(2.2 * scale_value, 2.0 * scale_value, 2.2 * scale_value)
        crown.mesh = cone
        crown.position.y = (2.3 + i * 0.58) * scale_value
        crown.material_override = _foliage_material([Color(0.10, 0.24, 0.13), Color(0.14, 0.29, 0.16), Color(0.18, 0.32, 0.18)][i])
        tree.add_child(crown)
    add_child(tree)

func _build_mountain(pos: Vector3, radius: float, height: float) -> void:
    var mountain := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = radius
    cone.height = height
    mountain.mesh = cone
    mountain.position = pos + Vector3(0, height * 0.5, 0)
    mountain.material_override = _mat(Color(0.35, 0.40, 0.36))
    add_child(mountain)

func _build_hut(pos: Vector3) -> void:
    _make_box("Hut", pos + Vector3(0, 1.1, 0), Vector3(4.5, 2.2, 3.5), Color(0.34, 0.24, 0.14))
    var roof := MeshInstance3D.new()
    var roof_mesh := PrismMesh.new()
    roof_mesh.size = Vector3(5.4, 1.5, 4.4)
    roof.mesh = roof_mesh
    roof.position = pos + Vector3(0, 2.8, 0)
    roof.material_override = _mat(Color(0.18, 0.15, 0.11))
    add_child(roof)
    var door := _make_box("HutDoor", pos + Vector3(0, 0.8, -1.78), Vector3(1.0, 1.6, 0.12), Color(0.12, 0.10, 0.07))
    door.collision_layer = 0

func _build_fence() -> void:
    for i in range(17):
        _make_box("FencePost", Vector3(-9.0 + i * 1.1, 0.65, -22.0), Vector3(0.14, 1.3, 0.14), Color(0.30, 0.20, 0.11))
        _make_box("FenceRail", Vector3(-9.0 + i * 1.1, 0.9, -22.0), Vector3(1.12, 0.12, 0.12), Color(0.36, 0.25, 0.14))

func _mat(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    return material

func _terrain_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_pos;
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_pos.xz * 0.32;
    float broad = noise2(p * 0.22);
    float fine = noise2(p * 2.2);
    float detail = noise2(p * 8.0);
    vec3 grass_dark = vec3(0.075, 0.14, 0.065);
    vec3 grass_mid = vec3(0.16, 0.25, 0.10);
    vec3 grass_light = vec3(0.29, 0.34, 0.15);
    vec3 base = mix(grass_dark, grass_mid, smoothstep(0.18, 0.72, broad));
    base = mix(base, grass_light, smoothstep(0.66, 0.94, fine) * 0.34);
    base *= 0.86 + detail * 0.26;
    ALBEDO = base;
    ROUGHNESS = 0.98;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _soil_material() -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
float h(vec2 p) { return fract(sin(dot(p, vec2(41.7, 289.3))) * 15731.743); }
float n(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(h(i),h(i+vec2(1.0,0.0)),f.x),mix(h(i+vec2(0.0,1.0)),h(i+vec2(1.0,1.0)),f.x),f.y);
}
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    float grain=n(world_pos.xz*2.8);
    float pebble=n(world_pos.xz*13.0);
    vec3 soil=mix(vec3(0.18,0.12,0.07),vec3(0.36,0.25,0.14),grain);
    soil=mix(soil,vec3(0.43,0.36,0.25),smoothstep(0.65,0.9,pebble)*0.32);
    ALBEDO=soil; ROUGHNESS=1.0;
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _wood_material(base_color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = base_color
    material.roughness = 0.94
    material.metallic = 0.0
    material.uv1_scale = Vector3(1.0, 3.5, 1.0)
    return material

func _foliage_material(base_color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = base_color
    material.roughness = 0.98
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func _spawn_player() -> void:
    player = PLAYER_SCRIPT.new()
    player.position = Vector3(0, -0.1, 8)
    add_child(player)

func _spawn_enemies() -> void:
    var positions := [Vector3(-5, 0.1, -18), Vector3(4, 0.1, -22), Vector3(-7, 0.1, -29), Vector3(6, 0.1, -34), Vector3(1, 0.1, -39)]
    for pos in positions:
        var enemy = ENEMY_SCRIPT.new()
        enemy.position = pos
        enemy.player = player
        add_child(enemy)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "MobileHUD"
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    layer.add_child(root)
    health_label = _label(root, "VIDA 100", Vector2(14, 10), Vector2(150, 34), 18)
    arrow_label = _label(root, "FLECHAS 12", Vector2(170, 10), Vector2(170, 34), 18)
    mission_label = _label(root, "MISSÃO 1: Vá até o acampamento", Vector2(14, 52), Vector2(330, 58), 15)
    toast_label = _label(root, "", Vector2(0, 90), Vector2(500, 38), 16)
    toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var move_pad := Panel.new()
    move_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    move_pad.position = Vector2(18, -170)
    move_pad.size = Vector2(150, 150)
    move_pad.modulate = Color(1, 1, 1, 0.28)
    move_pad.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(move_pad)
    stick = Control.new()
    stick.position = Vector2.ZERO
    stick.size = move_pad.size
    stick.mouse_filter = Control.MOUSE_FILTER_STOP
    move_pad.add_child(stick)
    stick.gui_input.connect(_on_stick_input)
    var camera_zone := Control.new()
    camera_zone.anchor_left = 0.42
    camera_zone.anchor_right = 1.0
    camera_zone.anchor_top = 0.18
    camera_zone.anchor_bottom = 0.76
    camera_zone.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(camera_zone)
    camera_zone.gui_input.connect(_on_camera_input)
    var buttons := [
        ["PULAR", Vector2(-92, -170), Vector2(78, 60), Callable(self, "_jump")],
        ["MIRAR", Vector2(-182, -100), Vector2(78, 60), Callable(self, "_aim")],
        ["FLECHA", Vector2(-95, -94), Vector2(88, 72), Callable(self, "_shoot")],
        ["USAR", Vector2(-185, -28), Vector2(78, 50), Callable(self, "_interact")]
    ]
    for entry in buttons:
        var button := Button.new()
        button.text = entry[0]
        button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        button.position = entry[1]
        button.size = entry[2]
        button.add_theme_font_size_override("font_size", 15)
        button.add_theme_color_override("font_color", Color.WHITE)
        button.add_theme_color_override("font_hover_color", Color.WHITE)
        button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.16, 0.12, 0.9)))
        button.add_theme_stylebox_override("pressed", _button_style(Color(0.30, 0.42, 0.20, 0.95)))
        root.add_child(button)
        button.button_down.connect(entry[3])
        if entry[0] == "MIRAR":
            button.button_up.connect(func(): _aim_release())

func _label(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, font_size: int) -> Label:
    var label := Label.new()
    label.text = text_value
    label.position = pos
    label.size = size_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_color_override("font_shadow_color", Color.BLACK)
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    parent.add_child(label)
    return label

func _button_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.78, 0.86, 0.65, 0.8)
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    return style

func _on_stick_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            stick_center = event.position
            player.move_vector = Vector2.ZERO
        else:
            player.move_vector = Vector2.ZERO
    elif event is InputEventScreenDrag:
        var local: Vector2 = event.position - stick_center
        player.move_vector = Vector2(clamp(local.x / 55.0, -1.0, 1.0), clamp(local.y / 55.0, -1.0, 1.0))

func _on_camera_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            camera_touch_id = event.index
            last_touch_position = event.position
        elif event.index == camera_touch_id:
            camera_touch_id = -1
    elif event is InputEventScreenDrag and event.index == camera_touch_id:
        var delta_pos: Vector2 = event.position - last_touch_position
        player.rotate_camera(delta_pos.x, delta_pos.y)
        last_touch_position = event.position

func _jump() -> void:
    Input.action_press("jump")
    await get_tree().create_timer(0.12).timeout
    Input.action_release("jump")

func _aim() -> void:
    aiming = true
    player.set_aiming(true)

func _aim_release() -> void:
    aiming = false
    player.set_aiming(false)

func _shoot() -> void:
    if arrows <= 0 or shoot_cooldown > 0:
        _toast("Sem flechas ou recarregando.")
        return
    arrows -= 1
    shoot_cooldown = 0.55
    var arrow = ARROW_SCRIPT.new()
    arrow.shooter = player
    arrow.direction = player.get_aim_direction().normalized()
    arrow.global_position = player.get_aim_origin() + arrow.direction * 0.9
    add_child(arrow)
    _toast("Flecha disparada!")
    _update_hud()

func _interact() -> void:
    if player.global_position.distance_to(mission_marker) < 5.5:
        mission_stage = 1
        mission_marker = Vector3(0, 0, 8)
        _toast("Cabana investigada! Retorne ao ponto inicial.")
    elif mission_stage == 1 and player.global_position.distance_to(Vector3(0, 0, 8)) < 5.5:
        mission_stage = 2
        _toast("Missão concluída! Explore a ilha.")
    else:
        _toast("Siga a trilha até a cabana e toque USAR.")

func _process(delta: float) -> void:
    shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
    if is_instance_valid(player):
        var alive_enemies := get_tree().get_nodes_in_group("enemies").size()
        if mission_stage == 0 and alive_enemies == 0:
            mission_marker = Vector3(0, 0, -31)
            mission_label.text = "MISSÃO 1: Guardas eliminados. Investigue a cabana."
        elif mission_stage == 1:
            mission_label.text = "MISSÃO 2: Volte ao início da trilha."
        elif mission_stage >= 2:
            mission_label.text = "MISSÃO CONCLUÍDA — Explore livremente."
        _update_hud()

func _update_hud() -> void:
    if is_instance_valid(health_label):
        health_label.text = "VIDA %d" % (player.health if is_instance_valid(player) else health)
    if is_instance_valid(arrow_label):
        arrow_label.text = "FLECHAS %d" % arrows

func _toast(message: String) -> void:
    if not is_instance_valid(toast_label):
        return
    toast_label.text = message
    await get_tree().create_timer(2.0).timeout
    if is_instance_valid(toast_label):
        toast_label.text = ""
