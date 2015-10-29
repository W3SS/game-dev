# active-partials/npcs/npc.gd
# General interaction-based NPC base
# In use since 8/21 (updated 10/27)
# Related: message-ui, quest

#extends Node2D
extends "res://types/approachable.gd"

# instance-specific vars
export(String) var id
export(String) var label
export(Texture) var portrait



# npc_type: Is this a person, an object, 
# a simpler object, or just something in the background?
# ( not currently implemented )
export(int, "Character", "Complex", "Simple", "Overheard") var npc_type = 0


# trigger_mode: How does the player initiate this interaction?
# ( not currently implemented, but likely to be )
export(int, "Direct", "Proximity", "Line of sight", "Unique") var trigger_mode = 0


# conversation roots
var greeting = "Hey, Tr4ce. Anything to report?" 
var fallback_dialogue = "Can this wait? I'm in the middle of some calibrations."


const T_CHAR = 0
const T_COMPLEX = 1
const T_SIMPLE = 2
const T_OH = 3


const TRIGGER_DIRECT = 0
const TRIGGER_PROX = 1
const TRIGGER_LOS = 2
const TRIGGER_UNIQUE = 3

const STAGE_CLASS = preload("res://active-partials/environment/walkable-area.gd")


var dialog_branches
var has_branches
var branch_root_text = greeting
var active_branch
	
#var player_nearby = false
var can_interact = true
var is_interacting = false


var _
var game
var utils = preload("res://scripts/utils.gd")
var MUI = preload("res://active-partials/message-ui/message-ui.xml").instance()

var body_node
var floor_layer
var footprint
var attractors = Array() 
var is_attracting         # bool

#var player
var quest_loader

var x
var n
var clickable

signal player_redirected(successful, expected, actual)


func _init():
	dialog_branches = Array()


func set_MUI_portrait(portrait_path):
	var pic = ImageTexture.new()
	pic.load(portrait_path)
	pic = portrait
	MUI.make_portrait(pic)



func setup_MUI(portrait_path=null, labeltext=""):
	if portrait_path != null:
		set_MUI_portrait(portrait_path)
	
	

# TODO: fix this --------------
#	if labeltext != "":
#		label = labeltext
#		
#	MUI.make_dialogue(n)
#	
#	MUI.make_portrait(null)




func i_should_go():
	MUI.clear()
	MUI.make_dialogue(n)
	MUI.make_dialogue(fallback_dialogue)
	MUI.make_close_button()
	MUI.open()
	
# alias for the in-joke name
func decline_conversation():
	i_should_go()


#################
# present_conversations(dialog_branches)
# handles any number of dialog/quest situations
# TODO: needs a little refactoring to clean out old methods
func present_conversations(dialog_branches):

	var options = []
	
	if( dialog_branches.size() == 1 ):
		var branch = dialog_branches[0]
		init_branch(branch)
		MUI.open()
	
	elif( dialog_branches.size() > 1 ):
		for branch in dialog_branches:
			var response = {}
			if branch.get("label"):
				response["text"] = branch["label"]
			elif branch.get("Q_ID"):
				response["text"] = branch["Q_ID"]   # just in case
				
			
		#### this should get refactored into a proper init_branch method
		# either on NPC or MUI (or on Quest/Branch, maybe)
			response["actions"] = [
				{ fn = "clear",
				target = MUI,
				args = []},
				{ fn = "init_branch",
				target = self,
				args = [branch]}
			]
	
			options.append(response)
		
		MUI.clear()
		MUI.make_dialogue(n)
		MUI.make_dialogue(branch_root_text)
		MUI.make_responses(options, false);

		MUI.open()



#################
# init_branch(branch)
# TODO: clean this up
# stub until branches are set up
func init_branch(branch):
	var quest = branch.owned_by
	var s = quest.get("current_state")
	MUI.clear()
	#MUI.make_dialogue(n)
	
	if( branch.text_at_state(s) == null or branch.responses_at_state(s) == null ):
		print("No responses. Awkward.")
		MUI.close()
		return false
		
	MUI.make_dialogue(branch.text_at_state(s))
	for response in branch.responses_at_state(s):
		branch.build_response(response)
	MUI.open()


#################
# set_attractors()
# look for our "footprint" polygon and set any tiles under its points
# to "attractor" status
# these tiles make the player turn to face them upon stopping nearby
func set_attractors():

	if ( footprint == null ):
		print("nothing to attract towards, add a footprint polygon")
		return
		
	# hopefully this series of checks is no longer needed, 
	# but just in case:
	if( floor_layer == null ):
		print("no floor layer, refreshing paths...")
		set_paths()
		
	if( !floor_layer.has_method("tile_at")):
		print("can't use that as a floor layer, it's ", floor_layer.get_name() )
		return

	
	
	# define where to place the attractor tiles,
	# using our "footprint" polygon child 
	# ( get_polygon returns an array of the vertexes as Vector2s )
	var attract_points = footprint.get_polygon()
	
	for i in attract_points :
		var data = {}
		var pt = i 
		pt = pt + get_global_pos()
		
		# cache the current tile so we can put it back later if the npc moves
		data["point"] = pt
		data["replacing"] = floor_layer.tile_at(pt)
		
		var mappt = floor_layer.tiles.world_to_map(pt)
		floor_layer.tiles.set_cell(mappt.x, mappt.y, floor_layer.TILE_ATTRACT);
		attractors.append(data)
		is_attracting = true
		

#################
# stop_attracting()
# turn off the charm and put tiles back to the way you found them
# could be useful if we ever have npcs that move around
func stop_attracting():
	var i = 0
	if( is_attracting ):
		while i < attractors.size():
			var entry = attractors[i]
			floor_layer.set_tile(entry["replacing"])
			i = i+1
	attractors.clear()
	is_attracting = false



func redirect_player(player, destination):

	player.set_fixed_process(false)
	
	var offset = destination.get_global_pos()
	offset = get_canvas_transform().xform(offset)
	utils.fake_click(offset, 1)
	
	yield(player, "oriented")
	emit_signal("player_redirected", player_nearby, destination, player.get_global_pos())



#func _on_body_enter(body_id, body_obj, body_shape_id, area_shape_id):
#	if( body_obj == player ):
#		player_nearby = true
#
#
#func _on_body_exit(body_id, body_obj, body_shape_id, area_shape_id):
#	if( body_obj == player ):
#		player_nearby = false;
#
#
#func player_is_nearby():
#	return player_nearby

#
#func _on_click():
#	
#	player.set("path", Array())
#	check_for_player()
#	if( !player_nearby ):
#		redirect_player(player, x)
#		yield(player, "done_moving")
#		
#		if( player_nearby ):
#			get_tree().set_input_as_handled()
#			start_interaction()
#		else:
#			return
#			
#	else:
#		get_tree().set_input_as_handled()
#		start_interaction()

#
func _on_click():
	
	player.set("path", Array())
	check_for_player()
	if( !player_nearby ):
		redirect_player(player, x)
		


func _stopped_nearby(body):
	get_tree().set_input_as_handled()
	start_interaction()


func start_interaction():
	setup_MUI(null, label)
	var pause = utils.wait(0.5)
	add_child(pause)
	pause.start()
	yield(pause, "timeout")
	check_branches()
	
	if( dialog_branches.empty() ):
		print("no dialogs!")
		i_should_go()
	else:
		for i in range(0, dialog_branches.size() -1):
			var branch_ = dialog_branches[i]
			if( ! has_conversation(branch_)  ):
				MUI.close()
				dialog_branches.remove(i)
			else:
				continue
		present_conversations(dialog_branches)



# Check whether this actor has anything to say
# on a particular dialog branch, at its current state
func has_conversation(branch_ = null):
	if( branch_ == null ):
		return false
	else:
		var branch_quest = branch_.get("owned_by")
		var branch_state = branch_quest.get("current_state")
		if( branch_._at_state(branch_state) == null ):
			return false
		return true


func set_branches():
	if( quest_loader == null ):
		return
	else:
		yield(quest_loader, "quests_loaded")
		check_branches()



func check_branches():
	dialog_branches = Array()
	var nodes = get_child_count()
	for n in range(0, nodes-1):
		if ( get_child(n).has_method( "_at_state" )):
			dialog_branches.append(get_child(n))
			has_branches = true
			continue



func set_paths():
	_ = get_node("/root/_")
	utils = get_node("/root/utils")
	game = get_node("/root/game")
	body_node = get_node("body")
	x = get_node("X")
	clickable = get_node("body/Sprite")
	player =_.get("player")
	MUI = _.get("MUI")
	if( MUI != null ):
		n = MUI.make_formatted_name(label)
		
	floor_layer = get_owner()
	footprint = get_node("footprint")
	
#	
#func set_signals():
#	body_node.connect("body_enter_shape", self, "_on_body_enter")
#	body_node.connect("body_exit_shape", self, "_on_body_exit")
#

func npc_ready():
	pass
	

func _ready():
	set_process(true)
	set_paths()
#	set_signals()
	set_branches()
	npc_ready()


func _enter_tree():
	check_branches()