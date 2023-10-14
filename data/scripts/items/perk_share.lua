dofile( "data/scripts/game_helpers.lua" )
dofile_once("data/scripts/lib/utilities.lua")
dofile( "data/scripts/perks/perk.lua" )

function item_pickup( entity_item, entity_who_picked, item_name )
	local kill_other_perks = true
    local p1 = EntityGetWithTag( "player1_unit" )[1]
    local p2 = EntityGetWithTag( "player2_unit" )[1]
	local components = EntityGetComponent( entity_item, "VariableStorageComponent" )
	
	if ( components ~= nil ) then
		for key,comp_id in pairs(components) do 
			local var_name = ComponentGetValue( comp_id, "name" )
			if( var_name == "perk_dont_remove_others") then
				if( ComponentGetValueBool( comp_id, "value_bool" ) ) then
					kill_other_perks = false
				end
			end
		end
	end

    perk_share_mode = ModSettingGet("CouchCoOp.perk_share")
    
	perk_pickup( entity_item, entity_who_picked, item_name, true, kill_other_perks )

    if(perk_share_mode == true) then
        if (entity_who_picked == p1) then
            perk_pickup( entity_item, p2, item_name, true, kill_other_perks )
        end

        if (entity_who_picked == p2) then
            perk_pickup( entity_item, p1, item_name, true, kill_other_perks )
        end
    end
    
end