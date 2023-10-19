dofile("data/scripts/lib/mod_settings.lua")

-- Use ModSettingGet() in the game to query settings.
local mod_id = "SimpleCoop"
mod_settings_version = 1
mod_settings = 
{
  {
    category_id = "SimpleCoop_settings",
    ui_name = "Simple Co - Op Settings",
    ui_description = "Various Settings",
    settings = 
    {
      {
        id = "perk_share",
        ui_name = "Perk Share",
        ui_description = "Should perks be shared",
        value_default = false,
        value_min = 0,
        value_max = 1,
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "regen_share",
        ui_name = "Spell/Health Refresh Share",
        ui_description = "Should Spells Refreshs and Fullheal-Hearts be shared",
        value_default = false,
        value_min = 0,
        value_max = 1,
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "camera_mode",
        ui_name = "Camera Mode",
        ui_description = "0 => Fixed between P1 & P2 (RELATIVE) \n1 => P1 Focus (PC-PLAYER) \n2 => P2 Focus (CONTROLLER)\n3 => Fixed on last Position (STATIC)",
        value_default = "0",
        values = { {"0","Fixed between P1 & P2 (RELATIVE)"}, {"1","P1 Focus (PC-PLAYER)"}, {"2","P2 Focus (CONTROLLER)"}, {"3","Fixed on last Position (STATIC)"} },
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "player_mode",
        ui_name = "Ruling Player",
        ui_description = "Decides which player gets the Coins, etc.",
        value_default = "1",
        values = { {"1","PC-Player"}, {"2","Controller Player"}, {"3","No Shared Coins"} },
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "zoom_level",
        ui_name = "Zoom Level",
        ui_description = "Changes the Virtual Resolution => Bigger Playing Field\n Checkout HD Noita in Steam Workshop for a better version",
        value_default = "130%",
        values = { {"100%","1x Zoom Level (Normal)"}, {"120%","1.2x Zoom Level"}, {"130%","1.3x Zoom Level (Recommended)"}, {"140%","1.4x Zoom Level"}, {"150%","1.5x Zoom Level"} },
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "telport_distance",
        ui_name = "Teleport Distance",
        ui_description = "The distance at the second player will telport aswell (220px recommended)",
        value_default = 220,
        value_min = 60,
        value_max = 1000,
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "start_perk",
        ui_name = "Aiming Start Perk",
        ui_description = "If setting is on the Controller Player will recieve Laser Aim",
        value_default = true,
        value_min = 0,
        value_max = 1,
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "p1_color",
        ui_name = "Player Color (bugged!)",
        ui_description = "Which Robe color the PC-Player gets. (Check out Random Robes Mod V2)",
        value_default = "purple",
        values = { {"disabled","No Custom Robe (requires Restart)"}, {"green","Green Robe"}, {"red","Red Robe"}, {"yellow","Yellow Robe"}, {"purple","Purple Robe"}, {"lightblue","LightBlue Robe"}, {"blue","Blue Robe"}},
        scope = MOD_SETTING_SCOPE_RUNTIME,
      },
      {
        id = "p2_color",
        ui_name = "Player2 Color",
        ui_description = "Which Robe color the Controller-Player gets. (Check out Random Robes Mod V2)",
        value_default = "purple",
        values = { {"green","Green Robe"}, {"red","Red Robe"}, {"yellow","Yellow Robe"}, {"purple","Purple Robe"}, {"lightblue","LightBlue Robe"}, {"blue","Blue Robe"}},
        scope = MOD_SETTING_SCOPE_RUNTIME,
      }
    }
  }
}

-- This function is called to ensure the correct setting values are visible to the game via ModSettingGet(). your mod's settings don't work if you don't have a function like this defined in settings.lua.
-- This function is called:
--		- when entering the mod settings menu (init_scope will be MOD_SETTINGS_SCOPE_ONLY_SET_DEFAULT)
-- 		- before mod initialization when starting a new game (init_scope will be MOD_SETTING_SCOPE_NEW_GAME)
--		- when entering the game after a restart (init_scope will be MOD_SETTING_SCOPE_RESTART)
--		- at the end of an update when mod settings have been changed via ModSettingsSetNextValue() and the game is unpaused (init_scope will be MOD_SETTINGS_SCOPE_RUNTIME)
function ModSettingsUpdate( init_scope )
	local old_version = mod_settings_get_version( mod_id ) -- This can be used to migrate some settings between mod versions.
	mod_settings_update( mod_id, mod_settings, init_scope )
end

-- This function should return the number of visible setting UI elements.
-- Your mod's settings wont be visible in the mod settings menu if this function isn't defined correctly.
-- If your mod changes the displayed settings dynamically, you might need to implement custom logic.
-- The value will be used to determine whether or not to display various UI elements that link to mod settings.
-- At the moment it is fine to simply return 0 or 1 in a custom implementation, but we don't guarantee that will be the case in the future.
-- This function is called every frame when in the settings menu.
function ModSettingsGuiCount()
	-- if (not DebugGetIsDevBuild()) then --if these lines are enabled, the menu only works in noita_dev.exe.
	-- 	return 0
	-- end

	return mod_settings_gui_count( mod_id, mod_settings )
end

function ModSettingsGui( gui, in_main_menu )
  mod_settings_gui( mod_id, mod_settings, gui, in_main_menu )
end