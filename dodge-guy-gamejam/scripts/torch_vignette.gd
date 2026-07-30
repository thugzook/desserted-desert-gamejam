extends ColorRect
## Full-screen torch-light vignette. This script's only job is to aim the
## shader's light at the Torch's flame every frame — every feel knob (radius,
## softness, colors, flicker) is a shader parameter on this node's Material
## in the Inspector. See assets/shaders/torch_vignette.gdshader.

@export var torch: Node2D ## The node the light emanates from (a Torch's origin is its flame). Clear it to pin the light to screen center.


func _process(_delta: float) -> void:
	if torch == null:
		return
	var screen_pos := torch.get_global_transform_with_canvas().origin
	var uv := screen_pos / get_viewport_rect().size
	(material as ShaderMaterial).set_shader_parameter("center", uv)
