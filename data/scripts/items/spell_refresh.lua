dofile( "data/scripts/game_helpers.lua" )

function item_pickup( entity_item, entity_who_picked, name )
	local x, y = EntityGetTransform( entity_item )
	EntityLoad("data/entities/particles/image_emitters/spell_refresh_effect.xml", x, y-12)
	GamePrintImportant( "$itemtitle_spell_refresh", "$itemdesc_spell_refresh" )
	
    -- Share Spell Refresh in Case of active Setting 
    local p1_ent = EntityGetWithTag( "player1_unit" )[1]
	local p2_ent = EntityGetWithTag( "player2_unit" )[1]
    regen_share = ModSettingGet("CouchCoOp.regen_share")



    if(regen_share == true) then
        GamePrint("Shared Refresh")
        if (entity_who_picked == p1_ent) then
            GameRegenItemActionsInPlayer( p2_ent )
        end

        if (entity_who_picked == p2_ent) then
            GameRegenItemActionsInPlayer( p1_ent )
        end
    end

	GameRegenItemActionsInPlayer( entity_who_picked )


	

	-- remove the item from the game
	EntityKill( entity_item )
end