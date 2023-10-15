
dofile( "data/scripts/game_helpers.lua" )
dofile_once("data/scripts/lib/utilities.lua")
dofile_once( "data/scripts/perks/perk_list.lua")
dofile_once( "data/scripts/perks/perk.lua")


-- REPLACES VANILLA SCRIPTS WITH MULTIPLAYER FRIENDLY ONES
ModLuaFileAppend( "data/scripts/items/heart_fullhp.lua", "data/scripts/items/heart_fullhp_share.lua" )
ModLuaFileAppend( "data/scripts/items/heart_fullhp_temple.lua", "data/scripts/items/heart_fullhp_temple_share.lua" )
ModLuaFileAppend( "data/scripts/items/gold_pickup.lua", "data/scripts/items/gold_pickup_share.lua" )
ModLuaFileAppend( "data/scripts/perks/perk_pickup.lua", "data/scripts/items/perk_share.lua" )
ModLuaFileAppend( "data/scripts/biomes/temple_altar.lua", "data/scripts/RespawnFunc.lua" )


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
else
  while true do
    GamePrint("Enable Mnee To Play")
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- VARIABLES
------------------------------------------------------------------------------------------------------------------------------


local location_prev_initalized = false
local p1_x_prev = 0.0
local p1_y_prev = 0.0
local p2_x_prev = 0.0
local p2_y_prev = 0.0
local robe_red = { name =  "ARGB248_64_50", folder = "RGB248_64_50", cape_color = 0xFF3240f8, cape_color_edge = 0xFF1927df,}
local robe_purple = { name =  "ARGB168_131_216", folder = "RGB168_131_216", cape_color = 0xFFd883a8, cape_color_edge = 0xFFbf6a8f,}
local robe_green = { name =  "ARGB53_247_132", folder = "RGB53_247_132", cape_color = 0xFF84f735, cape_color_edge = 0xFF6bde1c,}
local robe_lightblue = { name =  "ARGB50_164_162", folder = "RGB50_164_162", cape_color = 0xFFa2a432, cape_color_edge = 0xFF898b19,}
local robe_blue = { name =  "ARGB50_116_205", folder = "RGB50_116_205", cape_color = 0xFFcd7432, cape_color_edge = 0xFFb45b19,}
local robe_yellow = { name =  "ARGB244_246_90", folder = "RGB244_246_90", cape_color = 0xFF5af6f4, cape_color_edge = 0xFF41dddb,}

local p1_color = ModSettingGet("CouchCoOp.p1_color")
local p2_color = ModSettingGet("CouchCoOp.p2_color")





------------------------------------------------------------------------------------------------------------------------------
-- Function: GET PLAYER ENTITY

function get_player1_obj()
    return EntityGetWithTag( "player1_unit" )[1]
end
function get_player2_obj()
  return EntityGetWithTag( "player2_unit" )[1]
end
function get_player3_obj()
  return EntityGetWithTag( "player3_unit" )[1]
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: CHECK IF POLYMORPHED

function IsPlayerPolymorphed() -- returns bool, entityId/nil
  local polymorphed_entities = EntityGetWithTag("polymorphed")
  if (polymorphed_entities ~= nil) then
    for _, entity_id in ipairs(polymorphed_entities) do
      local is_player = false
      local game_stats_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "GameStatsComponent")
      if (game_stats_comp ~= nil) then 
          is_player = ComponentGetValue2(game_stats_comp, "is_player")
      end
      if (is_player) then
          return true, entity_id
      else
        return false, nil
      end
    end
    GamePrint("Not polyed")
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GET ACTIVE SLOT (Thanks to Horscht on Noita Discord)

function get_active_slot(player)
  local ControlsComponent = EntityGetFirstComponentIncludingDisabled( player, "ControlsComponent" ) --IF nil then probably polymorphed
  local active_item = ComponentGetValue2(ControlsComponent, "mActiveItem")
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

function scroll_inventory(player,amount)
  local ControlsComponent = EntityGetFirstComponentIncludingDisabled( player, "ControlsComponent" ) --IF nil then probably polymorphed
  -- Disable the controls component so we can set the state ourself instead of it getting it from the input device
  ComponentSetValue2(ControlsComponent, "enabled", false)

  -- This allows us to simulate inventory scrolling
  -- Thanks to Lobzyr on the Noita discord for figuring this out
  ComponentSetValue2(ControlsComponent, "mButtonDownChangeItemR", true)
  ComponentSetValue2(ControlsComponent, "mButtonFrameChangeItemR", GameGetFrameNum() + 1)
  ComponentSetValue2(ControlsComponent, "mButtonCountChangeItemR", amount)
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
  local ability_component = EntityGetFirstComponentIncludingDisabledIncludingDisabled(entity, "AbilityComponent")
  return ComponentGetValue2(ability_component, "use_gun_script") == true
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: IS ITEM (check)

function is_item(entity)

  local ability_component = EntityGetFirstComponentIncludingDisabledIncludingDisabled(entity, "AbilityComponent")
  local ending_mc_guffin_component = EntityGetFirstComponentIncludingDisabledIncludingDisabled(entity, "EndingMcGuffinComponent")
  return (not ability_component) or ending_mc_guffin_component or ComponentGetValue2(ability_component, "use_gun_script") == false
end


------------------------------------------------------------------------------------------------------------------------------
-- Function: GET INVENTORY + ACTIVE ITEM


---Returns a table of entity ids currently occupying the inventory, their index is their inventory position
---return table inventory In the form: { [0] = nil, [1] = 307, } etc
---return number active_item

function get_inventory_and_active_item(player)
  local inventory = get_inventory(player)
  inventory = EntityGetAllChildren(inventory) or {}
  local current_active_item = get_active_item()
  local inv_out = {}
  local active_item
  for i, entity_id in ipairs(inventory) do
      if entity_id == current_active_item then
          active_item = current_active_item
      end
      local item_component = EntityGetFirstComponentIncludingDisabledIncludingDisabled(entity_id, "ItemComponent")
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

function get_inventory(player)
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

function get_active_item(player)
  if player then
      local inventory2 = EntityGetFirstComponentIncludingDisabledIncludingDisabled(player, "Inventory2Component")
      local mActualActiveItem = ComponentGetValue2(inventory2, "mActualActiveItem")
      return mActualActiveItem > 0 and mActualActiveItem or nil
  end
end

------------------------------------------------------------------------------------------------------------------------------
-- Function: GENERATE HOTBAR ARRAY (0 == No Item, 1 == Item)

function quick_slot(player,desired_slot)
  -- Generate Hotbar-Array (0,1) represents if there is an item or not
  local inventory_slots, active_item = get_inventory_and_active_item()
  local active_item_item_comp = EntityGetFirstComponentIncludingDisabledIncludingDisabled(active_item, "ItemComponent")
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

  scroll_inventory(player,change_amount)
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
  local player_sprite_component = EntityGetFirstComponentIncludingDisabled( player_entity, "SpriteComponent" )
  local player_sprite_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/player.xml"
  ComponentSetValue( player_sprite_component, "image_file", player_sprite_file )

  -- set player arm sprite
  local player_arm_sprite_component = EntityGetFirstComponentIncludingDisabled( player_arm, "SpriteComponent" )
  local player_arm_sprite_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/player_arm.xml"
  ComponentSetValue( player_arm_sprite_component, "image_file", player_arm_sprite_file )

  -- set player cape colour (since we're changing multiple variables, we'll use the edit_component() utility)
  edit_component( cape, "VerletPhysicsComponent", function(comp,vars) 
    vars.cloth_color = loadout_cape_color
    vars.cloth_color_edge = loadout_cape_color_edge
  end)

  -- set player ragdoll
  local player_ragdoll_component = EntityGetFirstComponentIncludingDisabled( player_entity, "DamageModelComponent" )
  local player_ragdoll_file = "mods/CouchCoOp/data/skins/".. loadout_choice.folder .."/ragdoll/filenames.txt"
  ComponentSetValue( player_ragdoll_component, "ragdoll_filenames_file", player_ragdoll_file )

end




------------------------------------------------------------------------------------------------------------------------------
----------PLAYER1 MEMORY
local InventoryOpen = false
function setControlsP1()
  GamePrint("P1")
  local player3_obj = get_player3_obj() -- Player 2 ID (Controller)
  local player3_ControlsComponent = EntityGetFirstComponentIncludingDisabled( player3_obj, "ControlsComponent" ) --IF nil then probably polymorphed
  local player1_obj = get_player1_obj() -- Player 1 ID (PC)

  local player1_ControlsComponent = EntityGetFirstComponentIncludingDisabled( player1_obj, "ControlsComponent" ) --IF nil then probably polymorphed
  local player1_InventoryComponent =  EntityGetFirstComponentIncludingDisabled( player1_obj, "Inventory2Component" ) --IF nil then probably dead
  local player1_InventoryGuiComponent = EntityGetFirstComponentIncludingDisabled( player1_obj, "InventoryGuiComponent" )
  local player1_PlatformShooterPlayerComponent =  EntityGetFirstComponentIncludingDisabled( player1_obj, "PlatformShooterPlayerComponent" )

  if player1_ControlsComponent == nil then
    EntityAddComponent( player1_obj, "ControlsComponent" )
    return
  end
  if player1_InventoryComponent == nil then
    EntityAddComponent( player1_obj, "Inventory2Component" )
    return
  end
  if player1_InventoryGuiComponent == nil then
    EntityAddComponent( player1_obj, "InventoryGuiComponent" )
    GamePrint("noGUI")
   return
  end
  if player1_PlatformShooterPlayerComponent == nil then
    EntityAddComponent( player1_obj, "PlatformShooterPlayerComponent", "mForceFireOnNextUpdate")
    return
  end


  ------------------------------------------------------------------------------------------------------------------------------
  -- PLAYER AIMING

  local p2_location_x,p2_location_y,p2_Rotation,p2_Scale_x,p2_Scale_y= EntityGetTransform( player1_obj )
  local Stick_vector_x, Stick_vector_y = InputGetJoystickAnalogStick(0,1)


  if Stick_vector_x > 0 and p2_Scale_x < 0 then
    EntitySetTransform (player1_obj,p2_location_x,p2_location_y,p2_Rotation,1)
    GamePrint("setright")
  end
  if Stick_vector_x < 0 and p2_Scale_x > 0 then
    EntitySetTransform (player1_obj,p2_location_x,p2_location_y,p2_Rotation,-1)
    GamePrint("setleft")
  end
  if Stick_vector_x ~=0 or Stick_vector_y ~=0 then
    RestVectorx = Stick_vector_x
    RestVectory = Stick_vector_y
  end

  local p1_location_x,p1_location_y = EntityGetTransform( player1_obj )

  local lmb_pressed = ComponentGetValue2( player3_ControlsComponent, "mButtonDownLeftClick" )
  local rmb_pressed = ComponentGetValue2( player3_ControlsComponent, "mButtonDownRightClick" )
  local mouse_x,mouse_y = ComponentGetValue2( player3_ControlsComponent, "mMousePosition" )


  local p1_aim_vector_x = mouse_x-p1_location_x --LUA Error when init due to P3 comp not existing when initializing new world
  local p1_aim_vector_y = mouse_y-p1_location_y



  ComponentSetValue2( player1_ControlsComponent, "mAimingVector", p1_aim_vector_x , p1_aim_vector_y )
  ComponentSetValue2( player1_ControlsComponent, "mMousePosition", mouse_x, mouse_y )

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

  ------------------------------------------------------------------------------------------------------
  if ModIsEnabled("mnee") then

    -- LEFT 
    if is_binding_down("Keyboard", "Left", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeft", true )
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownLeft", false ) -- Lua arror: Assert failed item_pickup is not defined ? 
    end

    -- RIGHT 
    if is_binding_down("Keyboard", "Right", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownRight", true )
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownRight", false )
    end

    -- HOVER: SPACE / W KEYBIND
    if is_binding_down("Keyboard", "Up", false, false, false, true)  then
      ComponentSetValue2( player1_ControlsComponent, "mFlyingTargetY", p2_location_y-10 )
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
    if is_binding_down("Keyboard", "Down", false, false, false, true) then
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownDown", true)
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownEat", true)
    else
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownDown", false)
      ComponentSetValue2( player1_ControlsComponent, "mButtonDownEat", false)
    end

    -- NEXT ITEM KEYBIND
    if get_binding_pressed("Keyboard", "NextItem") then
      local amount = 1
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemR", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameChangeItemR", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemR", amount)
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemR", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemR", 0)
    end

    -- PREVIOUS ITEM KEYBIND
    if get_binding_pressed("Keyboard", "PrevItem") then
      local amount = 1
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemL", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameChangeItemL", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemL", amount)
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownChangeItemL", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonCountChangeItemL", 0)
    end

    -- F(KICK) KEYBIND
    if get_binding_pressed("Keyboard", "Kick") then
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownRightClick", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameRightClick", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownKick", true);
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameKick", GameGetFrameNum()+1);
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownRightClick", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownKick", false);
    end
    ------------------------------INVENTORY
    if get_binding_pressed("Keyboard", "Inventory") then
      if InventoryOpen == false then
        InventoryOpen = true
      elseif InventoryOpen == true then
        InventoryOpen = false
      end
      ComponentSetValue2(player1_InventoryGuiComponent, "mActive", InventoryOpen)
      --ComponentSetValue2(player1_ControlsComponent, "mButtonFrameInventory", GameGetFrameNum()+1
    end
    ------------------------------ACTION
    if get_binding_pressed("Keyboard", "Interact", false, false, false, true) then
      GamePrint("Interact")  
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownAction", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameAction", GameGetFrameNum()+1)
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownInteract", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameInteract", GameGetFrameNum()+1)
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownAction", false)
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownInteract", false)
    end

    if is_binding_down("Keyboard", "Interact", false, false, false, true) then
      GamePrint("Its Down")  
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownLeftClick", true)
      ComponentSetValue2(player1_ControlsComponent, "mButtonFrameLeftClick", GameGetFrameNum()+1)
    else
      ComponentSetValue2(player1_ControlsComponent, "mButtonDownLeftClick", false)
    end

  end
end


----------PLAYER2 MEMORY
local RestVectorx = 1
local RestVectory = 1
local InventoryOpen = false
function setControlsP2()
  GamePrint("P2")
  local player3_obj = get_player3_obj() -- Player 2 ID (Controller)
  local player3_ControlsComponent = EntityGetFirstComponentIncludingDisabled( player3_obj, "ControlsComponent" ) --IF nil then probably polymorphed
  local player2_obj = get_player2_obj() -- Player 1 ID (PC)

  local player2_ControlsComponent = EntityGetFirstComponentIncludingDisabled( player2_obj, "ControlsComponent" ) --IF nil then probably polymorphed
  local player2_InventoryComponent =  EntityGetFirstComponentIncludingDisabled( player2_obj, "Inventory2Component" ) --IF nil then probably dead
  local player2_InventoryGuiComponent = EntityGetFirstComponentIncludingDisabled( player2_obj, "InventoryGuiComponent" )
  local player2_PlatformShooterPlayerComponent =  EntityGetFirstComponentIncludingDisabled( player2_obj, "PlatformShooterPlayerComponent" )

  if player2_ControlsComponent == nil then
    EntityAddComponent( player2_obj, "ControlsComponent" )
    return
  end
  if player2_InventoryComponent == nil then
    EntityAddComponent( player2_obj, "Inventory2Component" )
    return
  end
  if player2_InventoryGuiComponent == nil then
    EntityAddComponent( player2_obj, "InventoryGuiComponent" )
    GamePrint("noGUI")
   return
  end
  if player2_PlatformShooterPlayerComponent == nil then
    EntityAddComponent( player2_obj, "PlatformShooterPlayerComponent", "mForceFireOnNextUpdate")
    return
  end


  ------------------------------------------------------------------------------------------------------------------------------
  -- PLAYER AIMING

  local p2_location_x,p2_location_y,p2_Rotation,p2_Scale_x,p2_Scale_y= EntityGetTransform( player2_obj )
  local Stick_vector_x, Stick_vector_y = InputGetJoystickAnalogStick(0,1)


  if Stick_vector_x > 0 and p2_Scale_x < 0 then
    EntitySetTransform (player2_obj,p2_location_x,p2_location_y,p2_Rotation,1)
    GamePrint("setright")
  end
  if Stick_vector_x < 0 and p2_Scale_x > 0 then
    EntitySetTransform (player2_obj,p2_location_x,p2_location_y,p2_Rotation,-1)
    GamePrint("setleft")
  end
  if Stick_vector_x ~=0 or Stick_vector_y ~=0 then
    RestVectorx = Stick_vector_x
    RestVectory = Stick_vector_y
    
  end

  local target_x = p2_location_x+(10*RestVectorx)
  local target_y = p2_location_y+(10*RestVectory)

  local dir_x = (target_x - p2_location_x)
  local dir_y = (target_y - p2_location_y)

  local len_sq = dir_x*dir_x + dir_y*dir_y

  if len_sq ~= 0 then
    local len = math.sqrt(len_sq)
    local dir_x2 = dir_x / len
    local dir_y2 = dir_y / len

   ComponentSetValue2(player2_ControlsComponent, "mAimingVector", dir_x2, dir_y2)
   ComponentSetValue2( player2_ControlsComponent, "mMousePositionRaw",target_x, target_y)
   ComponentSetValue2( player2_ControlsComponent, "mGamePadCursorInWorld",target_x, target_y)
   ComponentSetValue2( player2_ControlsComponent, "mGamepadIndirectAiming",target_x, target_y)
  end
  --------------------------P2 MOUSE CURSOR
  local mouse_x,mouse_y = ComponentGetValue2( player3_ControlsComponent, "mMousePosition" )
  local xx,yy = ComponentGetValue2( player2_ControlsComponent, "mMousePositionRaw" ) --Need to render p2's mouse cursor
  local xx1,yy1 = ComponentGetValue2( player2_ControlsComponent, "mGamePadCursorInWorld" ) --Need to render p2's mouse cursor
  local xx2,yy2 = ComponentGetValue2( player2_ControlsComponent, "mGamepadIndirectAiming" ) --Need to render p2's mouse cursor
  local xx3,yy3 = ComponentGetValue2( player2_ControlsComponent, "mMousePosition" ) --Need to render p2's mouse cursor

  local Spritee = EntityGetFirstComponentIncludingDisabled(player2_obj,"SpriteComponent","Cursor")
  ComponentSetValue2( Spritee, "offset_x",(200*-RestVectorx)+16.500)
  ComponentSetValue2( Spritee, "offset_y",(200*-RestVectory)+38)
 -- ComponentSetValue2( Spritee, "special_scale_x",(0.7*len_sq))
 -- ComponentSetValue2( Spritee, "special_scale_y",(0.7*len_sq))

 local target_x = p2_location_x+(10*Stick_vector_x)
 local target_y = p2_location_y+(10*Stick_vector_y)

 local dir_x = (target_x - p2_location_x)
 local dir_y = (target_y - p2_location_y)

 local Alfa = dir_x*dir_x + dir_y*dir_y ---NORMALIZE FOR CIRCLE AIMING

  ComponentSetValue2( Spritee, "alpha",(1.5*Alfa))
  ComponentSetValue2( player2_ControlsComponent, "mMousePositionRaw",target_x, target_y)


  --DEBUG_MARK( xx, yy,"", 35,27,80)
  --DEBUG_MARK( xx1, yy1,"a", 35,27,80)
 -- DEBUG_MARK( xx2, yy2,"b", 35,27,80)
  --DEBUG_MARK( xx3, yy3,"c", 35,27,80)



  ------------------------------------------------------------------------------------------------------
  if ModIsEnabled("mnee") then
  -- shoot
  if is_binding_down("Gamepad", "Shoot", false, false, false, true) then
    ComponentSetValue2( player2_PlatformShooterPlayerComponent, "mForceFireOnNextUpdate", true )
  else
    ComponentSetValue2( player2_PlatformShooterPlayerComponent, "mForceFireOnNextUpdate", false )

  end

  -- Throw
  if is_binding_down("Gamepad", "Throw", false, false, false, true) then
    ComponentSetValue2( player2_ControlsComponent, "mAimingVectorNormalized", dir_x , dir_y )
    ComponentSetValue2( player2_ControlsComponent, "mButtonDownThrow", true )
    ComponentSetValue2( player2_ControlsComponent, "mButtonFrameThrow", GameGetFrameNum() + 1 )
  else
    ComponentSetValue2( player2_ControlsComponent, "mButtonDownThrow", false )
  end

    -- LEFT 
    if is_binding_down("Gamepad", "Left", false, false, false, true) then
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownLeft", true )
    else
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownLeft", false ) -- Lua arror: Assert failed item_pickup is not defined ? 
    end

    -- RIGHT 
    if is_binding_down("Gamepad", "Right", false, false, false, true) then
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownRight", true )
    else
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownRight", false )
    end

    -- HOVER: SPACE / W KEYBIND
    if is_binding_down("Gamepad", "Up", false, false, false, true)  then
      ComponentSetValue2( player2_ControlsComponent, "mFlyingTargetY", p2_location_y-10 )
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownUp", true )
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownJump", true )
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownFly", true )
      ComponentSetValue2( player2_ControlsComponent, "mButtonFrameFly", GameGetFrameNum() )
    else
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownUp", false )
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownJump", false )
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownFly", false )
    end

    -- DOWN KEYBIND
    if is_binding_down("Gamepad", "Down", false, false, false, true) then
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownDown", true)
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownEat", true)
    else
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownDown", false)
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownEat", false)
    end

    -- NEXT ITEM KEYBIND
    if get_binding_pressed("Gamepad", "NextItem") then
      local amount = 1
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownChangeItemR", true)
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameChangeItemR", GameGetFrameNum()+1)
      ComponentSetValue2(player2_ControlsComponent, "mButtonCountChangeItemR", amount)
    else
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownChangeItemR", false)
      ComponentSetValue2(player2_ControlsComponent, "mButtonCountChangeItemR", 0)
    end

    -- PREVIOUS ITEM KEYBIND
    if get_binding_pressed("Gamepad", "PrevItem") then
      local amount = 1
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownChangeItemL", true)
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameChangeItemL", GameGetFrameNum()+1)
      ComponentSetValue2(player2_ControlsComponent, "mButtonCountChangeItemL", amount)
    else
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownChangeItemL", false)
      ComponentSetValue2(player2_ControlsComponent, "mButtonCountChangeItemL", 0)
    end

    -- F(KICK) KEYBIND
    if get_binding_pressed("Gamepad", "Kick") then
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownRightClick", true)
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameRightClick", GameGetFrameNum()+1)
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownKick", true);
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameKick", GameGetFrameNum()+1);
    else
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownRightClick", false)
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownKick", false);
    end
    ------------------------------INVENTORY
    if get_binding_pressed("Gamepad", "Inventory") then
      if InventoryOpen == false then
        InventoryOpen = true
      elseif InventoryOpen == true then
        InventoryOpen = false
      end
      ComponentSetValue2(player2_InventoryGuiComponent, "mActive", InventoryOpen)
      --ComponentSetValue2(player2_ControlsComponent, "mButtonFrameInventory", GameGetFrameNum()+1
    end

    ------------------------------ACTION
    if is_binding_down("Gamepad", "Interact", false, false, false, true) then
      GamePrint("Interact")  
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownAction", true)
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameAction", GameGetFrameNum()+1)
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownInteract", true)
      ComponentSetValue2(player2_ControlsComponent, "mButtonFrameInteract", GameGetFrameNum()+1)
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownLeftClick", true )
    else
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownAction", false)
      ComponentSetValue2(player2_ControlsComponent, "mButtonDownInteract", false)
      ComponentSetValue2( player2_ControlsComponent, "mButtonDownLeftClick", false )
    end


  end
end














---------Universal Keybinds
function UniversalControl()
  local player3_obj = get_player3_obj() -- Player 2 ID (Controller)
  local player3_ControlsComponent = EntityGetFirstComponentIncludingDisabled( player3_obj, "ControlsComponent" )
  if player3_ControlsComponent == nil then
    EntityAddComponent( player3_obj, "ControlsComponent")

  end
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


end



function IsPlayerDead(PlayerTag)

	local Status = PlayerTag
  if Status == nil then
    return true
  elseif Status ~= nil then
    return false
  end

end




function HideInv()
  local player2_obj = get_player2_obj() -- Player 2 ID (Controller)
  local player1_obj = get_player1_obj() -- Player 1 ID (PC)


  local player1_InventoryGuiComponent = EntityGetFirstComponentIncludingDisabled( player1_obj, "InventoryGuiComponent" )
  local player2_InventoryGuiComponent = EntityGetFirstComponentIncludingDisabled( player2_obj, "InventoryGuiComponent" )

   -- Hide Inventory1 if Inventory2 is open
   if ComponentGetValue2(player1_InventoryGuiComponent, "mActive") then
    EntitySetComponentIsEnabled( player2_obj, player2_InventoryGuiComponent, false )
   else
    EntitySetComponentIsEnabled( player2_obj, player2_InventoryGuiComponent, true )
   end

   if ComponentGetValue2(player2_InventoryGuiComponent, "mActive") then
    EntitySetComponentIsEnabled( player1_obj, player1_InventoryGuiComponent, false )
   else
    EntitySetComponentIsEnabled( player1_obj, player1_InventoryGuiComponent, true )
   end
end












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


------------------------------------------------------------------------------------------------------------------------------
--//////////  ON FRAME UPDATE   /////////////////////////////////////////////////////////////////////////////////////////////--
------------------------------------------------------------------------------------------------------------------------------
local Initalized = false
function OnWorldPreUpdate()
	wake_up_waiting_threads(1)

  local player3_obj = get_player3_obj() -- Player 3 ID (PC)
  local player2_obj = get_player2_obj() -- Player 2 ID (Controller)
  local player1_obj = get_player1_obj() -- Player 1 ID (PC)

  local player3_PlatformShooterPlayerComponent = EntityGetFirstComponentIncludingDisabled( player1_obj, "PlatformShooterPlayerComponent" )

  local p2_location_x,p2_location_y = EntityGetTransform( player2_obj )
  local p1_location_x,p1_location_y = EntityGetTransform( player1_obj )
  local Camx,Camy = GameGetCameraPos()
  EntitySetTransform(player3_obj,Camx,Camy)

  if p1_location_x == nil then
    p1_location_x,p1_location_y = p1_x_prev,p1_location_y
  end
  if p2_location_x == nil then
    p2_location_x,p2_location_y = p2_x_prev,p2_location_y
  end



  local telport_distance = ModSettingGet("CouchCoOp.telport_distance")






  local camera_mode = ModSettingGet("CouchCoOp.camera_mode")


  UniversalControl()
  
  if IsPlayerDead(get_player1_obj()) == false then
    setControlsP1()
    p1_x_prev = p1_location_x
    p1_y_prev = p1_location_y
  end

  if IsPlayerDead(get_player2_obj()) == false then
    setControlsP2()
    p2_x_prev = p2_location_x
    p2_y_prev = p2_location_y
  
  end

  if IsPlayerDead(get_player1_obj()) == false and IsPlayerDead(get_player2_obj()) == true then
    camera_mode = "1"
    ComponentSetValue2(player3_PlatformShooterPlayerComponent, "mDesiredCameraPos", p1_location_x, p1_location_y ) 
  elseif IsPlayerDead(get_player1_obj()) == true and IsPlayerDead(get_player2_obj()) == false then
    camera_mode = "2"
  elseif IsPlayerDead(get_player1_obj()) == false and IsPlayerDead(get_player2_obj()) == false then
    camera_mode = "0"
    HideInv()
  elseif IsPlayerDead(get_player1_obj()) == true and IsPlayerDead(get_player2_obj()) == true and Initalized == true then
    camera_mode = "4"
    GameTriggerGameOver()
  end



  if (camera_mode == "0") then
    GameSetCameraPos(( p1_location_x+p2_location_x)/2.0, (p1_location_y+p2_location_y)/2.0 )
    ComponentSetValue2(player3_PlatformShooterPlayerComponent, "mDesiredCameraPos", ( p1_location_x+p2_location_x)/2.0, (p1_location_y+p2_location_y)/2.0 )
  elseif (camera_mode == "1") then
    GameSetCameraPos(p1_location_x, p1_location_y )
  elseif (camera_mode == "2") then

    GameSetCameraPos(p2_location_x, p2_location_y )
  else
    GameSetCameraPos(0, 0)
  end

--GamePrint(camera_mode)

end

------------------------------------------------------------------------------------------------------------------------------
--//////////  ON WORLD SPAWN   /////////////////////////////////////////////////////////////////////////////////////////////--
------------------------------------------------------------------------------------------------------------------------------

function OnPlayerSpawned(player_entity)
  Initalized = true
  local p1_location_x,p1_location_y = EntityGetTransform( player_entity )

  -- SPAWN PLAYER 3 & 3
  if not get_player3_obj() then
    EntityLoad( "data/entities/player3.xml" , p1_location_x + 130 , p1_location_y - 45 ) -- SPAWNS PLAYER 3
  end

  if not get_player2_obj() and EntityHasTag(get_player1_obj(),"Inti") == false then
    EntityLoad( "data/entities/player2.xml" , p1_location_x + 110 , p1_location_y - 35 ) -- SPAWNS PLAYER 2
    EntityAddTag(get_player1_obj(),"Inti")
    local p2_location_x,p2_location_y = EntityGetTransform( player_entity )
    local startperk = perk_spawn( p2_location_x , p2_location_y , "LASER_AIM" )
    -- To pick up the perk instantly, you can continue:
    perk_pickup(startperk, get_player2_obj(), "LASER_AIM", false, false)

  end

      EntityLoad( "data/entities/items/pickup/egg_monster.xml", 281, -84 )
      -- Apply Skins only at world start
      if ModSettingGet("CouchCoOp.p1_color") ~= "disabled" then
        change_robe(1)
        change_robe(2)
      end




end

