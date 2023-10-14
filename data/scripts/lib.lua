------------------------------------------------------------------------------------------------------------------------------
-- Custom: GET PLAYER GOLD

function getPlayerGold(player_entity)
	

	local wallet = EntityGetFirstComponent(player_entity, "WalletComponent")
	local money = ComponentGetValueInt(wallet, "money")

	return money
end

------------------------------------------------------------------------------------------------------------------------------
-- Custom: ADD PLAYER GOLD

function addPlayerGold(player_entity, amount)

	local wallet = EntityGetFirstComponent(player_entity, "WalletComponent")
	local money = ComponentGetValueInt(wallet, "money")
	local player_money = money + amount

	edit_component(player_entity, "WalletComponent", function(comp,vars)
		vars.money = player_money
	end)
end

------------------------------------------------------------------------------------------------------------------------------
-- Custom: Check for Perks

function has_perk(perk_id)
  return GameHasFlagRun("PERK_PICKED_" .. perk_id)
end

------------------------------------------------------------------------------------------------------------------------------

function copy_perks(perk_id, player_id)

  -- Simply spawn the entity in world at the player's location
  local x, y = EntityGetTransform(player_id)
  local perk = perk_spawn(x, y, perk_id)
  -- To pick up the perk instantly, you can continue:
  perk_pickup(perk, player_id, EntityGetName(perk), false, false)

end

------------------------------------------------------------------------------------------------------------------------------
-- Function: Check if Polymorphed

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
            end
        end
        return false, nil
    end
end

------------------------------------------------------------------------------------------------------------------------------