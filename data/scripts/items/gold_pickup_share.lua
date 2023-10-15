function item_pickup( entity_item, entity_who_picked, item_name )

	------------------------------------------------------------------------------------------------------------------------------
  	-- ADDS PICKED UP MONEY TO LEADER PLAYER (IF ACTIVE)

	local p1_ent = EntityGetWithTag( "player1_unit" )[1]
	local p2_ent = EntityGetWithTag( "player2_unit" )[1]
	active_player = ModSettingGet("CouchCoOp.player_mode")


	if(active_player == "1") then
		entity_who_picked = p1_ent
	elseif(active_player == "2") then
		entity_who_picked = p2_ent
	end

	------------------------------------------------------------------------------------------------------------------------------
	-- TRANSFERS GOLD TO LEADER (IF EXISTS) 

	-- CHECK IF CONTROLLER PLAYER HAS MONEY FOR PC PLAYER
	if(active_player == "1") then

		local wallet = EntityGetFirstComponent(p2_ent, "WalletComponent")
		local amount = ComponentGetValueInt(wallet, "money")

		if(amount > 0) then

			-- TRANSFER OLD MONEY TO LEADER PLAYER
			local wallet = EntityGetFirstComponent(p1_ent, "WalletComponent")
			local money = ComponentGetValueInt(wallet, "money")
			local player_money = money + amount
		
			edit_component(p1_ent, "WalletComponent", function(comp,vars)
				vars.money = player_money
			end)

			-- REMOVE OLD MONEY
			amount = amount * -1

			local wallet = EntityGetFirstComponent(p2_ent, "WalletComponent")
			local money = ComponentGetValueInt(wallet, "money")
			local player_money = money + amount
		
			edit_component(p2_ent, "WalletComponent", function(comp,vars)
				vars.money = player_money
			end)

		end

	-- CHECK IF PC PLAYER HAS MONEY FOR CONTROLLER PLAYER
	elseif(active_player == "2") then

		local wallet = EntityGetFirstComponent(p1_ent, "WalletComponent")
		local amount = ComponentGetValueInt(wallet, "money")

		if(amount > 0) then

			-- ADD OLD MONEY TO LEADER
			local wallet = EntityGetFirstComponent(p2_ent, "WalletComponent")
			local money = ComponentGetValueInt(wallet, "money")
			local player_money = money + amount
		
			edit_component(p2_ent, "WalletComponent", function(comp,vars)
				vars.money = player_money
			end)

			-- REMOVE OLD MONEY
			amount = amount * -1

			local wallet = EntityGetFirstComponent(p1_ent, "WalletComponent")
			local money = ComponentGetValueInt(wallet, "money")
			local player_money = money + amount
		
			edit_component(p1_ent, "WalletComponent", function(comp,vars)
				vars.money = player_money
			end)

		end


	end

	------------------------------------------------------------------------------------------------------------------------------

	
	local pos_x, pos_y = EntityGetTransform( entity_item )

	local money = 0
	local value = 10
	local hp_value = 0

	edit_component( entity_who_picked, "WalletComponent", function(comp,vars)
	money = ComponentGetValueInt( comp, "money")
	end)

	------------------------------------------------------------------------------------------------------------------------------
	-- load the gold_value from VariableStorageComponent

	local components = EntityGetComponent( entity_item, "VariableStorageComponent" )

	if ( components ~= nil ) then
	for key,comp_id in pairs(components) do 
		local var_name = ComponentGetValue( comp_id, "name" )
		if( var_name == "gold_value") then
			value = ComponentGetValueInt( comp_id, "value_int" )
		end
		if( var_name == "hp_value" ) then
			hp_value = ComponentGetValueFloat( comp_id, "value_float" )
		end
	end
	end


	------------------------------------------------------------------------------------------------------------------------------
	-- Different FX based on value

	if value > 500 then
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup_huge.xml", pos_x, pos_y, 0, 0 )
	elseif value > 40 then
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup_large.xml", pos_x, pos_y, 0, 0 )
	else
		shoot_projectile( entity_item, "data/entities/particles/gold_pickup.xml", pos_x, pos_y, 0, 0 )
	end

	------------------------------------------------------------------------------------------------------------------------------
	-- Extra Money?

	local extra_money_count = GameGetGameEffectCount( entity_who_picked, "EXTRA_MONEY" )

	if extra_money_count > 0 then
		for i=1,extra_money_count do
			value = value * 2
		end
	end

	money = money + value

	edit_component( entity_who_picked, "WalletComponent", function(comp,vars)
		vars.money = money
	end)

	if( hp_value > 0 ) then
		hp_value = hp_value * 0.5
	heal_entity( entity_who_picked, hp_value )

end



EntityKill( entity_item )
end