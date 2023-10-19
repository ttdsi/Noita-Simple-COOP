

function spawn_hp( x, y )
	EntityLoad( "data/entities/items/pickup/heart_fullhp_temple.xml", x-16, y )
	EntityLoad( "data/entities/buildings/music_trigger_temple.xml", x-16, y )
	EntityLoad( "data/entities/items/pickup/spell_refresh.xml", x+16, y )
	EntityLoad( "data/entities/buildings/coop_respawn.xml", x, y )

    if EntityGetWithTag( "player1_unit" )[1] == nil then
     EntityLoad( "data/entities/player.xml" , x , y )
    end
    if EntityGetWithTag( "player2_unit" )[1] == nil then 
        EntityLoad( "data/entities/player2.xml" , x , y )
        OnPlayerSpawned(EntityGetWithTag( "player2_unit" )[1])
    end
    if EntityGetWithTag( "player3_unit" )[1] == nil then 
        EntityLoad( "data/entities/player3.xml" , x , y )
        print("-------------------------------------------------------------------PLAYER 3 MISSING WHY!!!!!")
    end


end