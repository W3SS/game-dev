### standard walking kinematic character
### needs to be passed a reference to the Nav2D node
### walks to point of click
### includes rudimentary sprite flipping and camera follow, now working!
### 8/17/15
# TODO: should the player maybe just be an instance of this?

extends KinematicBody2D

var begin=Vector2()
var end=Vector2()
var path=[]
var destination
var is_moving

var spr
var nav
export(Texture) var front_texture
export(Texture) var back_texture

const SPEED=150.0

var stat = "awesome"

signal start_moving(from, to, path)
signal done_moving(at)
signal oriented(dir, at)

##### align_sprite
# temporary utility for flipping/swapping trace based on direction
# eventually going to be replaced by an animationplayer setup
# (waiting on sprite assets -- 8/15)

func align_sprite(spr, direction):
	if( direction.y > 0 ):
		spr.set_texture(front_texture)
		if( direction.x < 0 ):
			spr.set_flip_h(false)
		elif direction.x > 0:
			spr.set_flip_h(true)
	elif direction.y < 0:
		spr.set_texture(back_texture)
		if( direction.x < 0 ):
			spr.set_flip_h(true)
		elif direction.x > 0:
			spr.set_flip_h(false)

func orient(towards):
	var spr = get_node("Sprite")
	if( towards == "NW" or towards == "N" or towards == "W"):
		spr.set_texture(self["back_texture"])
		spr.set_flip_h(true)
	elif( towards == "NE" or towards == "E" ):
		spr.set_texture(self["back_texture"])
		spr.set_flip_h(false)
	elif( towards == "SE" or towards == "S" ):
		spr.set_texture(self["front_texture"])
		spr.set_flip_h(true)
	else:
		spr.set_texture(self["front_texture"])
		spr.set_flip_h(false)
	emit_signal("oriented", towards, get_global_pos())

	
func halt():
	set_fixed_process(false)
	path.clear()
	set_fixed_process(true)

func _fixed_process(delta):

	if (path.size()>1):
	
		var to_walk = delta*SPEED
		
		while(to_walk>0 and path.size()>=2):
			is_moving = true
		
			# prepare path segments
			var pfrom = path[path.size()-1]
			var pto = path[path.size()-2]
			var d = pfrom.distance_to(pto)
			
			# turn trace towards his destination
			var direction = ( pto - pfrom).normalized()
			align_sprite(spr, direction)
		
			if (d<=to_walk):
				path.remove(path.size()-1)
				to_walk-=d
			else:
				path[path.size()-1] = pfrom.linear_interpolate(pto,to_walk/d)
				to_walk=0
				
		var atpos = path[path.size()-1]
		move_to(atpos);
		
		# handle collisions
		if(is_colliding()):
			var n = get_collision_normal()
			var motion = n.slide(atpos - get_global_pos())
			move(motion)
			
		# reaching our destination
		if (path.size()<2):
			path=[]
			set_fixed_process(false)
			
			emit_signal("done_moving", get_global_pos())
			is_moving = false
				
	else:
		set_fixed_process(false)
		is_moving = false



func update_path(start, end, nav):
	# generate a path 
	# note: optimize = false to keep trace traveling along the iso grid
	var p = nav.get_simple_path(start, end, false) 
	
	path=Array(p) # convert Vector2Array to normal Array for ease of use
	path.invert() # not sure why it's done this way but it works
	
	destination = end
	#emit_signal("start_moving", start, end, path)
	set_fixed_process(true) # start walkin'



func _ready():
	#nav = get_node("/root/scene/env/nav")
	nav = get_tree().get_current_scene().find_node("nav")
	spr = get_node("Sprite")
	
	is_moving = false
	
	if( front_texture == null ):
		front_texture = spr.get_texture()
		
	# don't break if there is no back texture set
	if( back_texture == null):
		back_texture = front_texture
	
	if( ! get_tree().has_user_signal("start_moving") ):
		get_tree().add_user_signal("start_moving", ["from", "to", "path"])
	
	if( ! get_tree().has_user_signal("done_moving") ):
		get_tree().add_user_signal("done_moving", ["at"])
		
	if( ! get_tree().has_user_signal("oriented") ):
		get_tree().add_user_signal("oriented", ["dir", "at"])
		
	set_fixed_process(false)
