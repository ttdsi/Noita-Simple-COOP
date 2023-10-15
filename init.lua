dofile( "data/scripts/game_helpers.lua" )
dofile_once("data/scripts/lib/utilities.lua")
dofile_once( "data/scripts/perks/perk_list.lua")
dofile_once( "data/scripts/perks/perk.lua")


-- REPLACES VANILLA SCRIPTS WITH MULTIPLAYER FRIENDLY ONES
ModLuaFileAppend( "data/scripts/items/heart_fullhp.lua", "data/scripts/items/heart_fullhp_share.lua" )
ModLuaFileAppend( "data/scripts/items/heart_fullhp_temple.lua", "data/scripts/items/heart_fullhp_temple_share.lua" )
ModLuaFileAppend( "data/scripts/items/gold_pickup.lua", "data/scripts/items/gold_pickup_share.lua" )
ModLuaFileAppend( "data/scripts/perks/perk_pickup.lua", "data/scripts/items/perk_share.lua" )



if not async then
    -- guard against multiple inclusion to prevent
    -- loss of async coroutines
    dofile( "data/scripts/lib/coroutines.lua" )
end

-- APPLIES M-NEE BINDS
-- THIS IS NECESSARY DUE TO NO ADDITIONAL INPUT MAPPING FROM NOITA
if ModIsEnabled("mnee") then
	ModLuaFileAppend("mods/mnee/bindings.lua", "mods/CouchCoOp/mnee.lua")
	dofile_once("mods/mnee/lib.lua")
end

------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
------------------------------------------------------------------------------------------------------------------------------

hotbarArray = {}  -- ARRAY THAT REPRESENT THE HOTBAR -> (0 == No Item, 1 == Item)
action_pressed = false
location_prev_initalized = false
p1_x_prev = 0.0
p1_y_prev = 0.0
p2_x_prev = 0.0
p2_y_prev = 0.0
robe_red = { name =  "ARGB248_64_50", folder = "RGB248_64_50", cape_color = 0xFF3240f8, cape_color_edge = 0xFF1927df,}
robe_purple = { name =  "ARGB168_131_216", folder = "RGB168_131_216", cape_color = 0xFFd883a8, cape_color_edge = 0xFFbf6a8f,}
robe_green = { name =  "ARGB53_247_132", folder = "RGB53_247_132", cape_color = 0xFF84f735, cape_color_edge = 0xFF6bde1c,}
robe_lightblue = { name =  "ARGB50_164_162", folder = "RGB50_164_162", cape_color = 0xFFa2a432, cape_color_edge = 0xFF898b19,}
robe_blue = { name =  "ARGB50_116_205", folder = "RGB50_116_205", cape_color = 0xFFcd7432, cape_color_edge = 0xFFb45b19,}
robe_yellow = { name =  "ARGB244_246_90", folder = "RGB244_246_90", cape_color = 0xFF5af6f4, cape_color_edge = 0xFF41dddb,}

p1_color = ModSettingGet("CouchCoOp.p1_color")
p2_color = ModSettingGet("CouchCoOp.p2_color")

polymorphed_player = 0 -- 0 => none // 1 => P1 // 2 => P2

gameHook = 0
debug_mode = 1




------------------------------------------------------------------------------------------------------------------------------
-- FUNCTIONS
------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------
-- Function: PRINT ARRAY

function print_r(arr, indentLevel)
  local str = ""
  local indentStr = "#"

  if(indentLevel == nil) then
      print(print_r(arr, 0))
      return
  end

  for i = 0, indentLevel do
      indentStr = indentStr.."\t"
  end

  for index,value in pairs(arr) do
      if type(value) == "table" then
          str = str..indentStr..index..": \n"..print_r(value, (indentLevel + 1))
      else 
          str = str..indentStr..index..": "..value.."\n"
      end
  end
  return str
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GET PLAYER 1 ENTITY

function get_player1_obj()

  ------------------------------------------------------------------------------------------------------------------------------
  -- Check if Polymorphed (is_polymorphed -> bool, polymorphed_player -> int [id])

  local is_polymorphed, polymorphed_player =   IsPlayerPolymorphed()

  if(is_polymorphed == true) then
    if EntityGetWithTag( "player2_unit" )[1] ~= nil and EntityGetWithTag( "player1_unit" )[1] == nil then

      if debug_mode == 2 then
      print("p1 change -> id:" .. EntityGetName(polymorphed_player) .. polymorphed_player)
      end

      polymorphed_player = 1
      return polymorphed_player

    end
  else 

    if polymorphed_player == 1 then
      polymorphed_player = 0
    end

    return EntityGetWithTag( "player1_unit" )[1]

  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GET PLAYER 2 ENTITY

function get_player2_obj()
  return EntityGetWithTag( "player2_unit" )[1]
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: CHECK IF POLYMORPHED

function IsPlayerPolymorphed() -- returns bool, entityId/nil
  local polymorphed_entities = EntityGetWithTag("polymorphed")
  if (polymorphed_entities ~= nil) then
    for _, entity_id in ipairs(polymorphed_entities) do
      local is_player = false
      local game_stats_comp = EntityGetFirstComponent(entity_id, "GameStatsComponent")
      if (game_stats_comp ~= nil) then 
          is_player = ComponentGetValue2(game_stats_comp, "is_player")
      end

      if (is_player) then
          return true, entity_id
      else
        return false, nil
      end
    end
    -- GamePrint("Not polyed")
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GET ACTIVE SLOT (Thanks to Horscht on Noita Discord)

function get_active_slot()

  local active_item = ComponentGetValue2(player1_Inventory2Component, "mActiveItem")
  local ItemComponent = EntityGetComponentIncludingDisabled( active_item, "ItemComponent" )[1]
  local active_slot = ComponentGetValue2(ItemComponent, "inventory_slot")

  -- Get Hotbar Position
  if not is_wand(active_item) then
      -- Potions/Items start at 0, so add 4 to get the absolute position of the item in the inventory
      active_slot = active_slot + 4
  end

  return active_slot
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: SCROLL HOTBAR

function scroll_inventory(amount)

  -- Disable the controls component so we can set the state ourself instead of it getting it from the input device
  ComponentSetValue2(player1_ControlsComponent, "enabled", false)

  -- This allows us to simulate inventory scrolling
  -- Thanks to Lobzyr on the Noita discord for figuring this out
  ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemR", true)
  ComponentSetValue2(player1_ControlsComponent, "mButtonFrameChangeItemR", GameGetFrameNum() + 1)
  ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemR", amount)
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: IS WAND (check)

function is_wand(entity)

  local tags = EntityGetTags(entity)

  if string.find(tags, "wand") then
    return true
  else
    return false
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: IS WAND2 (check)

function is_wand2(entity)
  local ability_component = EntityGetFirstComponentIncludingDisabled(entity, "AbilityComponent")
  return ComponentGetValue2(ability_component, "use_gun_script") == true
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: IS ITEM (check)

function is_item(entity)

  local ability_component = EntityGetFirstComponentIncludingDisabled(entity, "AbilityComponent")
  local ending_mc_guffin_component = EntityGetFirstComponentIncludingDisabled(entity, "EndingMcGuffinComponent")
  return (not ability_component) or ending_mc_guffin_component or ComponentGetValue2(ability_component, "use_gun_script") == false
end


------------------------------------------------------------------------------------------------------------------------------
-- Function: GET INVENTORY + ACTIVE ITEM


---Returns a table of entity ids currently occupying the inventory, their index is their inventory position
---return table inventory In the form: { [0] = nil, [1] = 307, } etc
---return number active_item

function get_inventory_and_active_item()
  local inventory = get_inventory()
  inventory = EntityGetAllChildren(inventory) or {}
  local current_active_item = get_active_item()
  local inv_out = {}
  local active_item
  for i, entity_id in ipairs(inventory) do
      if entity_id == current_active_item then
          active_item = current_active_item
      end
      local item_component = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
      if item_component then
          local inventory_slot_x = ComponentGetValue2(item_component, "inventory_slot")
          local non_wand_offset = not is_wand(entity_id) and 4 or 0
          inv_out[inventory_slot_x+1 + non_wand_offset] = 1 --entity_id
      end
  end
  return inv_out, active_item
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GENERATE HOTBAR ARRAY (0 == No Item, 1 == Item)

function get_inventory()
  local player = get_player1_obj()
  if player then
      for i, child in ipairs(EntityGetAllChildren(player) or {}) do
          if EntityGetName(child) == "inventory_quick" then
              return child
          end
      end
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: Get active item

function get_active_item()
  local player = get_player1_obj()
  if player then
      local inventory2 = EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
      local mActualActiveItem = ComponentGetValue2(inventory2, "mActualActiveItem")
      return mActualActiveItem > 0 and mActualActiveItem or nil
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GENERATE HOTBAR ARRAY (0 == No Item, 1 == Item)

function quick_slot(desired_slot)
  -- Generate Hotbar-Array (0,1) represents if there is an item or not
  local inventory_slots, active_item = get_inventory_and_active_item()
  local active_item_item_comp = EntityGetFirstComponentIncludingDisabled(active_item, "ItemComponent")
  local currently_selected_slot = get_active_slot()

  -- Fill Array Gaps with value 0
  for i = 1, 8 do
    if inventory_slots[i] == nil then
      table.insert(inventory_slots, i, 0)
    end
  end

  if not active_item then
    currently_selected_slot = 0
  end

  local n = currently_selected_slot + 1
  local change_amount = 0

  -- Get amounts of skips
  while n ~= desired_slot do
    if n >= 9 then
      n = 1
      if n == desired_slot then
        break
      end
    end

    change_amount = change_amount + inventory_slots[n]
    n = n + 1
  end

  scroll_inventory(change_amount)
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: Translate Color

function get_color_list(color)
  if color == "green" then
    return robe_green
  elseif color == "red" then
    return robe_red
  elseif color == "yellow" then
    return robe_yellow
  elseif color == "purple" then
    return robe_purple
  elseif color == "blue" then
    return robe_blue
  elseif color == "lightblue" then
    return robe_lightblue
  else
    return robe_purple
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: Set Skin

function change_robe(player)

  if player == 2 then
    player_entity = get_player2_obj()
    loadout_choice = get_color_list(ModSettingGet("CouchCoOp.p2_color"))
  else 
    player_entity = get_player1_obj()
    loadout_choice = get_color_list(ModSettingGet("CouchCoOp.p1_color"))
  end 

  local cape = nil
  local player_arm = nil

  local loadout_cape_color = loadout_choice.cape_color
  local loadout_cape_color_edge = loadout_choice.cape_color_edge

  -- find the quick inventory, player cape and arm
  local player_child_entities = EntityGetAllChildren( player_entity )
  if ( player_child_entities ~= nil ) then
    for i,child_entity in ipairs( player_child_entities ) do
      local child_entity_name = EntityGetName( child_entity )
      
      if ( child_entity_name == "cape" ) then
        cape = child_entity
      end
      
      if ( child_entity_name == "arm_r" ) then
        player_arm = child_entity
      end
    end
  end

  -- set player sprite (since we change only one value, ComponentSetValue is fine)
  local player_sprite_component = EntityGetFirstComponent( player_entity, "SpriteComponent" )
  local player_sprite_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/player.xml"
  ComponentSetValue( player_sprite_component, "image_file", player_sprite_file )

  -- set player arm sprite
  local player_arm_sprite_component = EntityGetFirstComponent( player_arm, "SpriteComponent" )
  local player_arm_sprite_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/player_arm.xml"
  ComponentSetValue( player_arm_sprite_component, "image_file", player_arm_sprite_file )

  -- set player cape colour (since we're changing multiple variables, we'll use the edit_component() utility)
  edit_component( cape, "VerletPhysicsComponent", function(comp,vars) 
    vars.cloth_color = loadout_cape_color
    vars.cloth_color_edge = loadout_cape_color_edge
  end)

  -- set player ragdoll
  local player_ragdoll_component = EntityGetFirstComponent( player_entity, "DamageModelComponent" )
  local player_ragdoll_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/ragdoll/filenames.txt"
  ComponentSetValue( player_ragdoll_component, "ragdoll_filenames_file", player_ragdoll_file )

end




------------------------------------------------------------------------------------------------------------------------------
-- Function: Set P1 Controls

function setControlsP1(obj)

  local p1_location_x,p1_location_y = EntityGetTransform( get_player1_obj() )


  ------------------------------------------------------------------------------------------------------------------------------
  -- Vars
  ------------------------------------------------------------------------------------------------------------------------------
  -- Get Player Entity's (Save to variable)

  local player2_obj = get_player2_obj() -- Player 2 ID (Controller)
  local player1_obj = obj -- Player 1 ID (PC)
  ------------------------------------------------------------------------------------------------------------------------------
  -- PLAYER COMPONENTS

  local player2_ControlsComponent = get_control_components(player2_obj) --IF nil then probably polymorphed
  local player1_ControlsComponent = get_control_components(player1_obj) --IF nil then probably polymorphed


  if player1_ControlsComponent == nil then
    EntityAddComponent( player1_obj, "ControlsComponent" )
  end

  if EntityGetFirstComponent( obj, "PlatformShooterPlayerComponent" ) == nil then
    EntityAddComponent( obj, "PlatformShooterPlayerComponent", "mForceFireOnNextUpdate")
  else
    player1_PlatformShooterPlayerComponent = EntityGetFirstComponent( obj, "PlatformShooterPlayerComponent" )
  end
  

  ------------------------------------------------------------------------------------------------------------------------------
  -- PLAYER COORDINATES

  local p2_location_x,p2_location_y = EntityGetTransform( player2_obj )

  ------------------------------------------------------------------------------------------------------------------------------
  -- Click Information

  local lmb_pressed = ComponentGetValue2( player2_ControlsComponent, "mButtonDownLeftClick" )
  local rmb_pressed = ComponentGetValue2( player2_ControlsComponent, "mButtonDownRightClick" )
  ------------------------------------------------------------------------------------------------------------------------------
  -- MOUSE LOCATION

  local mouse_x,mouse_y = ComponentGetValue2( player2_ControlsComponent, "mMousePosition" )
  ------------------------------------------------------------------------------------------------------------------------------
  -- Aim Vector

  local p1_aim_vector_x = mouse_x-p1_location_x  --LUA Error when init due to P2 comp not existing when initializing new world
  local p1_aim_vector_y = mouse_y-p1_location_y


  ------------------------------------------------------------------------------------------------------------------------------
  -- SET CONTROLS FOR PC PLAYER
  ------------------------------------------------------------------------------------------------------------------------------

  -- CURSOR
  ComponentSetValue2( player1_ControlsComponent, "mMousePosition", mouse_x, mouse_y )
  ComponentSetValue2( player1_ControlsComponent, "mAimingVector", p1_aim_vector_x , p1_aim_vector_y )

  -- LEFT MOUSE BUTTON
  if lmb_pressed then
    ComponentSetValue2( player1_PlatformShooterPlayerComponent, "mForceFireOnNextUpdate", true )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeftClick", lmb_pressed )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownFire", lmb_pressed )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownFire2", lmb_pressed )
  else
    ComponentSetValue2( player1_PlatformShooterPlayerComponent, "mForceFireOnNextUpdate", false )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeftClick", lmb_pressed )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownFire", lmb_pressed )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownFire2", lmb_pressed )
  end

  -- RIGHT MOUSE BUTTON
  if rmb_pressed then
    ComponentSetValue2( player1_ControlsComponent, "mAimingVectorNormalized", p1_aim_vector_x , p1_aim_vector_y )
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownThrow", true )
    ComponentSetValue2( player1_ControlsComponent, "mButtonFrameThrow", GameGetFrameNum() + 1 )
  else
    ComponentSetValue2( player1_ControlsComponent, "mButtonDownThrow", false )
  end

  if ModIsEnabled("mnee") then

    -- LEFT MOUSE BUTTON KEYBIND
    if is_binding_down("key_left", "left", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeft", true )
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeft", false ) -- Lua arror: Assert failed item_pickup is not defined ? 
    end

    -- RIGHT MOUSE BUTTON KEYBIND
    if is_binding_down("key_right", "right", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownRight", true )
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownRight", false )
    end

    -- HOVER: SPACE / W KEYBIND
    ComponentSetValue2( player1_ControlsComponent, "mFlyingTargetY", p1_location_y-10 )
    if is_binding_down("key_jump_space", "jump_space", false, false, false, true) or is_binding_down("key_jump_w", "jump_w", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownUp", true )
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownJump", true )
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownFly", true )
      ComponentSetValue2( player1_ControlsComponent, "mButtonFrameFly", GameGetFrameNum() )
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownUp", false )
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownJump", false )
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownFly", false )
    end

    -- DOWN KEYBIND
    if is_binding_down("key_down", "down", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownDown", true)
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownEat", true)
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownDown", false)
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownEat", false)
    end

    -- NEXT ITEM KEYBIND
    if get_binding_pressed("key_next_item_r", "next_item_r") then
      local amount = 1
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemR", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameChangeItemR", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemR", amount)
      active_slot = get_active_slot()

    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemR", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemR", 0)
    end

    -- PREVIOUS ITEM KEYBIND
    if get_binding_pressed("key_next_item_l", "next_item_l") then
      local amount = 1
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemL", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameChangeItemL", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemL", amount)
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemL", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemL", 0)
    end

    -- F(KICK) KEYBIND
    if get_binding_pressed("key_kick", "kick") then
      GamePrint("kick")
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownKick", true);
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameKick", GameGetFrameNum()+1);
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownKick", false);
    end
  end

  print("player1_ControlsComponent: " .. player1_ControlsComponent)
  print("player2_ControlsComponent: " .. player2_ControlsComponent)

end

------------------------------------------------------------------------------------------------------------------------------
-- Function: Gets Control Components (Function Improves Error Handling!)

function get_control_components(obj)
  return EntityGetFirstComponent( obj, "ControlsComponent" ) --IF nil then probably polymorphed
end

function get_inventory2_component(obj)
  return EntityGetFirstComponent( obj, "Inventory2Component" ) --IF nil then probably polymorphed -> 0
end

function get_platform_shooter_component(obj)
  return EntityGetFirstComponent( obj, "PlatformShooterPlayerComponent" ) --IF nil then probably polymorphed
end


------------------------------------------------------------------------------------------------------------------------------
-- END OF FUNCTIONS
------------------------------------------------------------------------------------------------------------------------------




------------------------------------------------------------------------------------------------------------------------------
-- FILE INITIALIZATION: Zoom Level    Check out: (HD Noita mod)
------------------------------------------------------------------------------------------------------------------------------

if ModSettingGet("CouchCoOp.zoom_level") == "120%" then
  ModMagicNumbersFileAdd("mods/CouchCoOp/data/files/1_2_magic_numbers.xml" )
  ModTextFileSetContent("data/shaders/post_final.frag", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_2_post_final.frag"))
  ModTextFileSetContent("data/shaders/post_final.vert", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_2_post_final.vert"))  

elseif ModSettingGet("CouchCoOp.zoom_level") == "130%" then
  ModMagicNumbersFileAdd("mods/CouchCoOp/data/files/1_3_magic_numbers.xml" )
  ModTextFileSetContent("data/shaders/post_final.frag", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_3_post_final.frag"))
  ModTextFileSetContent("data/shaders/post_final.vert", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_3_post_final.vert"))  

elseif ModSettingGet("CouchCoOp.zoom_level") == "140%" then
  ModMagicNumbersFileAdd("mods/CouchCoOp/data/files/1_4_magic_numbers.xml" )
  ModTextFileSetContent("data/shaders/post_final.frag", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_4_post_final.frag"))
  ModTextFileSetContent("data/shaders/post_final.vert", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_4_post_final.vert"))  

elseif ModSettingGet("CouchCoOp.zoom_level") == "150%" then
  ModMagicNumbersFileAdd("mods/CouchCoOp/data/files/1_5_magic_numbers.xml" )
  ModTextFileSetContent("data/shaders/post_final.frag", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_5_post_final.frag"))
  ModTextFileSetContent("data/shaders/post_final.vert", ModTextFileGetContent("mods/CouchCoOp/data/shaders/1_5_post_final.vert"))  

else -- Assume we are on Normal
  ModMagicNumbersFileAdd("mods/hd_noita/data/files/1_0_magic_numbers.xml")
end













-- Called *every* time the game is about to start updating the world
------------------------------------------------------------------------------------------------------------------------------
--//////////  ON FRAME UPDATE   /////////////////////////////////////////////////////////////////////////////////////////////--
------------------------------------------------------------------------------------------------------------------------------
function OnWorldPreUpdate()
	wake_up_waiting_threads(1)


  -- Debug
  if debug_mode == 1 then
    gameHook = gameHook + 1
    if(polymorphed_player ~= 0)then
        print("polymorphed_player: " .. polymorphed_player)
    end
    if gameHook % 250 == 0 then
      print("tick: " .. gameHook)
    end
  end


  ------------------------------------------------------------------------------------------------------------------------------
  -- Get Player Entity's (Save to variable)

  local player2_obj = get_player2_obj() -- Player 2 ID (Controller)
  local player1_obj = get_player1_obj() -- Player 1 ID (PC)

  ------------------------------------------------------------------------------------------------------------------------------
  -- PLAYER COORDINATES

  local p2_location_x,p2_location_y = EntityGetTransform( player2_obj )
  local p1_location_x,p1_location_y = EntityGetTransform( player1_obj )

  ------------------------------------------------------------------------------------------------------------------------------
  -- GET Player Controls (Save Compononents to variable)

  player2_ControlsComponent = get_control_components(player2_obj) --IF nil then probably polymorphed
  player1_ControlsComponent = get_control_components(player1_obj) --IF nil then probably polymorphed

  player1_Inventory2Component =  get_inventory2_component(player1_obj) --IF nil then probably dead
  player1_PlatformShooterPlayerComponent = get_platform_shooter_component(player1_obj)

  ------------------------------------------------------------------------------------------------------------------------------
  -- ??? Prints out GameInformation of Player 1 ???

  local player1_GameEffectComponent = EntityGetComponent( player1_obj, "GameEffectComponent" )
  if player1_GameEffectComponent then
    GamePrint(tostring(type(player1_GameEffectComponent)))
  end

  ------------------------------------------------------------------------------------------------------------------------------
  -- CAMERA
  
  -- Camera Reactive to Middle of Player x-Pos and Middle of y-Pos P1: cam -> ComponentSetValue2(player1_PlatformShooterPlayerComponent, "mDesiredCameraPos", p1_location_x, p1_location_y ) 
  if get_binding_pressed("key_cam0", "cam0") and ModIsEnabled("mnee") then
    ModSettingSet("CouchCoOp.camera_mode", "0")
    ModSettingSetNextValue("CouchCoOp.camera_mode", "0", false)
  end
  if get_binding_pressed("key_cam1", "cam1") and ModIsEnabled("mnee") then
    ModSettingSet("CouchCoOp.camera_mode", "1")
    ModSettingSetNextValue("CouchCoOp.camera_mode", "1", false)
  end
  if get_binding_pressed("key_cam2", "cam2") and ModIsEnabled("mnee") then
    ModSettingSet("CouchCoOp.camera_mode", "2")
    ModSettingSetNextValue("CouchCoOp.camera_mode", "2", false)
  end
  if get_binding_pressed("key_cam3", "cam3") and ModIsEnabled("mnee") then
    ModSettingSet("CouchCoOp.camera_mode", "3")
    ModSettingSetNextValue("CouchCoOp.camera_mode", "3", false)
  end
  
  camera_mode = ModSettingGet("CouchCoOp.camera_mode")
  

  if (camera_mode == "0") then
    ComponentSetValue2(player1_PlatformShooterPlayerComponent, "mDesiredCameraPos", ( p1_location_x+p2_location_x)/2.0, (p1_location_y+p2_location_y)/2.0 )
  elseif (camera_mode == "1") then
    ComponentSetValue2(player1_PlatformShooterPlayerComponent, "mDesiredCameraPos", p1_location_x, p1_location_y ) 
  elseif (camera_mode == "2") then
    ComponentSetValue2(player1_PlatformShooterPlayerComponent, "mDesiredCameraPos", p2_location_x, p2_location_y )
  else
    -- No Camera Fix
  end

  ------------------------------------------------------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------
  -- SET CONTROLS FOR PC PLAYER
  ------------------------------------------------------------------------------------------------------------------------------
  setControlsP1(player1_obj)


  ------------------------------------------------------------------------------------------------------------------------------  
  -- M-NEE KEYBINDS
  ------------------------------------------------------------------------------------------------------------------------------

  if ModIsEnabled("mnee") then

    ------------------------------------------------------------------------------------------------------------------------------
    -- GUI Inventory

    local player1_InventoryGuiComponent = EntityGetComponent( player1_obj, "InventoryGuiComponent" )
    local player2_InventoryGuiComponent = EntityGetComponent( player2_obj, "InventoryGuiComponent" )

    if (not player1_InventoryGuiComponent) and (not player2_InventoryGuiComponent) then
      EntityAddComponent( player1_obj, "InventoryGuiComponent" )
      EntityAddComponent( player2_obj, "InventoryGuiComponent" )
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- P1 Inventory

    -- Hide Inventory2 if Inventory1 is open
    if player1_InventoryGuiComponent then
      if ComponentGetValue2(player1_InventoryGuiComponent[1], "mActive") then
        if player2_InventoryGuiComponent then
          EntityRemoveComponent( player2_obj, player2_InventoryGuiComponent[1] )
        end
      end
    end

    if player2_InventoryGuiComponent then
      if ComponentGetValue2(player2_InventoryGuiComponent[1], "mActive") then
        if player1_InventoryGuiComponent then
          EntityRemoveComponent( player1_obj, player1_InventoryGuiComponent[1] )
        end
      end
    end
    
 

    -- P1 Interact Keybind
    if is_binding_down("key_interact", "interact", false, false, false, true) then
      EntityRemoveComponent( player2_obj, player2_InventoryGuiComponent[1] ) -- Lua error (Deletes player2 spell inv so p1 can pick up spells)
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownInteract", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameInteract", GameGetFrameNum()+1)
    else
      if (not player2_InventoryGuiComponent) and (not ComponentGetValue2(player1_InventoryGuiComponent[1], "mActive")) then
        EntityAddComponent( player2_obj, "InventoryGuiComponent" )
      end
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownInteract", false); 
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- P2 Inventory

    -- Hide Inventory1 if Inventory2 is open
    if ComponentGetValue2(player2_ControlsComponent, "mButtonDownInteract") then
      EntityRemoveComponent( player1_obj, player1_InventoryGuiComponent[1] ) -- Lua error ?
      if not action_pressed then
        ComponentSetValue2( player2_ControlsComponent , "mButtonDownInteract" , true )
        ComponentSetValue2( player2_ControlsComponent , "mButtonFrameInteract" , GameGetFrameNum()+1 )
      end
      action_pressed = true
    else
      if (not player1_InventoryGuiComponent) and (not ComponentGetValue2(player2_InventoryGuiComponent[1], "mActive")) then
        EntityAddComponent( player1_obj, "InventoryGuiComponent" )
      end
      action_pressed = false
    end


    -- P2 Keybind Inventory
    if player1_Inventory2Component == nil or player1_Inventory2Component == 0 then
      if debug_mode == 2 then
        print("no p1 inv" .. gameHook)
      end
    else
      if get_binding_pressed("key_inventory", "inventory") then
        ComponentSetValue2(player1_ControlsComponent, "mButtonDownInventory", true);
        ComponentSetValue2(player1_ControlsComponent, "mButtonFrameInventory", GameGetFrameNum()+1);
        ComponentSetValue2(player1_Inventory2Component, "mForceRefresh", true);
      else
        ComponentSetValue2(player1_ControlsComponent, "mButtonDownInventory", false);
        ComponentSetValue2(player1_Inventory2Component, "mForceRefresh", false);
      end
    end
  
    ------------------------------------------------------------------------------------------------------------------------------
    -- Keybind Take Control

    if get_binding_pressed("key_take_control", "take_control") then
      GamePrint("take contol")
      ComponentSetValue2( player1_ControlsComponent, "enabled", false)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- Keybind Give Control

    if get_binding_pressed("key_give_control", "give_control") then
      GamePrint("give control")
      ComponentSetValue2( player1_ControlsComponent, "enabled", true)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- teleport if there is a change
    telport_distance = ModSettingGet("CouchCoOp.telport_distance")


    if location_prev_initalized == false then
      location_prev_initalized = true
    elseif (math.abs(p1_location_x-p1_x_prev) > telport_distance) or (math.abs(p1_location_y-p1_y_prev) > telport_distance) then
      EntitySetTransform( player2_obj , p1_location_x , p1_location_y )
    elseif (math.abs(p2_location_x-p2_x_prev) > telport_distance) or (math.abs(p2_location_y-p2_y_prev) > telport_distance) then
      EntitySetTransform( player1_obj , p2_location_x , p2_location_y )
    end

    --if(gameHook % 200 == 0)then
    --  print("Went through inv script")
    --end
    ------------------------------------------------------------------------------------------------------------------------------

    p1_x_prev = p1_location_x
    p1_y_prev = p1_location_y
    p2_x_prev = p2_location_x
    p2_y_prev = p2_location_y

    ------------------------------------------------------------------------------------------------------------------------------
    -- Keybind Teleport P1 -> P2

    if get_binding_pressed("key_p1_tp_to_p2", "p1_tp_to_p2") then
      EntitySetTransform( player1_obj , p2_location_x , p2_location_y )
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- Keybind Teleport P2 -> P1

    if get_binding_pressed("key_p2_tp_to_p1", "p2_tp_to_p1") then
      EntitySetTransform( player2_obj , p1_location_x , p1_location_y )
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 1

    if get_binding_pressed("key_slot1", "slot1") then
      quick_slot(1)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 2

    if get_binding_pressed("key_slot2", "slot2") then
      quick_slot(2)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 3

    if get_binding_pressed("key_slot3", "slot3") then
      quick_slot(3)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 4

    if get_binding_pressed("key_slot4", "slot4") then
      quick_slot(4)
    end
    
        ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 5

    if get_binding_pressed("key_slot5", "slot5") then
      quick_slot(5)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 6

    if get_binding_pressed("key_slot6", "slot6") then
      quick_slot(6)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 7

    if get_binding_pressed("key_slot7", "slot7") then
      quick_slot(7)
    end

    ------------------------------------------------------------------------------------------------------------------------------
    -- KEYBIND SLOT 8

    if get_binding_pressed("key_slot8", "slot8") then
      quick_slot(8)
    end

  ------------------------------------------------------------------------------------------------------------------------------
  end -- END OF M-NEE HOTKEYS
  ------------------------------------------------------------------------------------------------------------------------------
  
  if ModSettingGet("CouchCoOp.p1_color") ~= "disabled" then
    if ModSettingGet("CouchCoOp.p1_color") ~= p1_color or ModSettingGet("CouchCoOp.p2_color") ~= p2_color then
      change_robe(1)
      p1_color = ModSettingGet("CouchCoOp.p1_color")
      change_robe(2)
      p2_color = ModSettingGet("CouchCoOp.p2_color")
    end
  end
  


------------------------------------------------------------------------------------------------------------------------------
end -- END OF OnWorldPreUpdate()
------------------------------------------------------------------------------------------------------------------------------











------------------------------------------------------------------------------------------------------------------------------
--//////////  ON WORLD SPAWN   /////////////////////////////////////////////////////////////////////////////////////////////--
------------------------------------------------------------------------------------------------------------------------------
function OnPlayerSpawned(player_entity)

  local p1_location_x,p1_location_y = EntityGetTransform( player_entity )

  -- SPAWN PLAYER 2
  if not get_player2_obj() then
    EntityLoad( "data/entities/player2.xml" , p1_location_x + 110 , p1_location_y - 35 ) -- SPAWNS PLAYER 2
  end


  ------------------------------------------------------------------------------------------------------------------------------
  -- CONTROLLER PLAYER STARTS WITH LASER-AIM (once)
  start_perk_mode = ModSettingGet("CouchCoOp.start_perk")

  if(start_perk_mode == true) then
    if(GameHasFlagRun("PERK_PICKED_" .. "LASER_AIM") ~= true)then

      local startperk = perk_spawn( p1_location_x + 110 , p1_location_y - 30 , "LASER_AIM" )

      -- To pick up the perk instantly, you can continue:
      perk_pickup(startperk, get_player2_obj(), "LASER_AIM", false, false)
      EntityLoad( "data/entities/items/pickup/egg_monster.xml", 281, -84 )

      -- Apply Skins only at world start
      if ModSettingGet("CouchCoOp.p1_color") ~= "disabled" then
        change_robe(1)
        change_robe(2)
      end

    end
  end

------------------------------------------------------------------------------------------------------------------------------
end -- END OF OnPlayerSpawned()
------------------------------------------------------------------------------------------------------------------------------





------------------------------------------------------------------------------------------------------------------------------
--//////////  ON PLAYER DEATH   ////////////////////////////////////////////////////////////////////////////////////////////--
------------------------------------------------------------------------------------------------------------------------------

function OnPlayerDied(player1_obj)

  GamePrint("Player 1 Died!")
	local player_damage_model_id = EntityGetFirstComponent(get_player1_obj(), "DamageModelComponent")
	
	-- disable death
	ComponentSetValue(player_damage_model_id, "wait_for_kill_flag_on_death", "1") 


	--GameSetCameraFree(true)
	--ComponentSetValue2(EntityGetComponent(GameGetWorldStateEntity(), "WorldStateComponent")[1],"open_fog_of_war_everywhere", true)
end

function OnPlayerDied(player2_obj)

  GamePrint("Player 2 Died!")
  local player_damage_model_id = EntityGetFirstComponent(get_player2_obj(), "DamageModelComponent")
	
	-- disable death
	ComponentSetValue(player_damage_model_id, "wait_for_kill_flag_on_death", "1")

	--GameSetCameraFree(true)
	--ComponentSetValue2(EntityGetComponent(GameGetWorldStateEntity(), "WorldStateComponent")[1],"open_fog_of_war_everywhere", true)
end



