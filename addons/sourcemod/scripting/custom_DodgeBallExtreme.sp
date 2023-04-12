// List of Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Dodgeball Extreme",
	author		= "Manifest @Road To Glory",
	description	= "Changes the gameplay into a dodgeball match.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};




/////////////////
// - Convars - //
/////////////////




//////////////////////////
// - Global Variables - //
//////////////////////////

// Global Booleans
bool isPlayerDucking[MAXPLAYERS + 1] = {false,...};
bool decoyHasBounced[2049] = {false,...};



//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Hooks the events that we intend to use in our plugin
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
//	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	// Removes any unowned weapon and item entities from the map every 2.0 seconds
	CreateTimer(2.0, Timer_CleanFloor, _, TIMER_REPEAT);

	// Allows the modification to be loaded while the server is running, without causing gameplay issues
	LateLoadSupport();
}


// This happens when a new map is loaded
public void OnMapStart()
{
	// Executes the configuration file containing the modification specific configurations
	ServerCommand("exec sourcemod/dodgeball_extreme/dodgeball_settings.cfg");

	// Removes all of the buy zones from the map
	RemoveEntityBuyZones();

	// Removes all of the bomb sites from the map
	RemoveEntityBombSites();

	// Removes Hostage Rescue Points from the map
	RemoveEntityHostageRescuePoint();
}


// This happens once all post authorizations have been performed and the client is fully in-game
public void OnClientPostAdminCheck(int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Adds a hook to the client which will let us track when the player is eligible to pick up a weapon
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}


// This happens when a player disconnects
public void OnClientDisconnect(int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Removes the hook that we had added to the client to track when he was eligible to pick up weapons
	SDKUnhook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}


// This happens when a player can pick up a weapon
public Action Hook_WeaponCanUse(int client, int weapon)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the weapon that was picked up our entity criteria of validation then execute this section
	if(!IsValidEntity(weapon))
	{
		return Plugin_Continue;
	}

	// Creates a variable called ClassName which we will store the weapon entity's name within
	char className[64];

	// Obtains the classname of the weapon entity and store it within our ClassName variable
	GetEntityClassname(weapon, className, sizeof(className));

	// If the weapon's entity name is that of a decoy grenade's then execute this section
	if(StrEqual(className, "weapon_decoy", false))
	{
		return Plugin_Continue;
	}

	PrintToChatAll("%s is restricted", className);

	// Kills the weapon entity, removing it from the game
	AcceptEntityInput(weapon, "Kill");

	return Plugin_Handled;
}


// This happens when a new entity is created
public void OnEntityCreated(int entity, const char[] className)
{
	// If the created entity is not a decoy_projectile then execute this section
	if(!StrEqual(className, "decoy_projectile", false))
	{
		return;
	}

	// Adds a hook to the decoy grenade after it has been spawned allowing us to alter the grenade's behavior
	SDKHook(entity, SDKHook_SpawnPost, Hook_DecoySpawnPost);
}


// This happens when a decoy grenade projectile has been spawned
public Action Hook_DecoySpawnPost(int entity)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// Disables the decoy's sound emitting and explosion functionality
	CreateTimer(0.1, Timer_DisableDecoyFunctionality, entity, TIMER_FLAG_NO_MAPCHANGE);
	
	// Removes the decoy grenade from the game after 10 seconds has passed
	CreateTimer(10.0, Timer_RemoveDecoyGrenade, entity, TIMER_FLAG_NO_MAPCHANGE);

	// Obtains and stores the entity owner offset within our client variable 
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the client is not alive then execute this section
	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	// Sets the decoy entity's bounce status to false
	decoyHasBounced[entity] = false;

	// If the model is not precached already then execute this section
	if(!IsModelPrecached("models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl"))
	{
		// Precaches the specified model
		PrecacheModel("models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl");
	}

	// Changes the entity's model to the specified one
	SetEntityModel(entity, "models/props/de_dust/hr_dust/dust_soccerball/dust_soccer_ball001.mdl");

	// If the client is on the terrorist team then execute this section
	if(GetClientTeam(client) == 2)
	{
		// Changes the color of the entity to the specified RGB color
		DispatchKeyValue(entity, "rendercolor", "160 0 0");
	}

	// If the client is on the counter-terrorist team then execute this section
	else if(GetClientTeam(client) == 3)
	{
		// Changes the color of the entity to the specified RGB color
		DispatchKeyValue(entity, "rendercolor", "0 0 180");
	}

	// Adds a hook to our grenade entity to notify of us when the grenade will touch something
	SDKHook(entity, SDKHook_TouchPost, Hook_DecoyTouchPost);

	// Adds a hook to our grenade entity to notify of us when the grenade will start to touch something
	SDKHook(entity, SDKHook_StartTouch, Hook_DecoyStartTouch);

	return Plugin_Continue;
}


// This happens when a high explosive grenade touches something while a king possesses the sticky grenade power
public Action Hook_DecoyTouchPost(int entity, int client)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		// Sets the decoy entity's bounce status to true
		decoyHasBounced[entity] = true;

		PrintToChatAll("Debug - Grenade bounced on something that was not a player");

		// Removes the hook that we had attached to the grenade
		SDKUnhook(entity, SDKHook_TouchPost, Hook_DecoyTouchPost);
	}

	// If the client meets our validation criteria then execute this section
	else
	{
		PrintToChatAll("Debug - Grenade bounced on a player");

		// Obtains and stores the entity owner offset within our decoyOwner variable 
		int decoyOwner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

		// If the client meets our validation criteria then execute this section
		if(!IsValidClient(decoyOwner))
		{
			return Plugin_Continue;
		}

		// If the client hit by the decoy is on the opposite team of the owner of the grenade then execute this section
		if(GetClientTeam(client) != GetClientTeam(decoyOwner))
		{
			return Plugin_Continue;
		}

		// Sets the decoy entity's bounce status to true
		decoyHasBounced[entity] = true;

		// Removes the hook that we had attached to the grenade
		SDKUnhook(entity, SDKHook_TouchPost, Hook_DecoyTouchPost);

		PrintToChatAll("Debug - Grenade bounced on a friendly player");
	}

	return Plugin_Continue;
}


// This happens when a player presses a button
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
	// If the player meets our criteria for validation then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the client is not alive then execute this section
	if(!IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	if(buttons & IN_DUCK)
	{
		// If the client's ducking status is true then execute this section
		if(isPlayerDucking[client])
		{
			return Plugin_Continue;
		}

		// Sets the client's ducking status true
		isPlayerDucking[client] = true;
	}

	else
	{
		// If the client's ducking status is false then execute this section
		if(!isPlayerDucking[client])
		{
			return Plugin_Continue;
		}

		// Sets the client's ducking status true
		isPlayerDucking[client] = false;
	}

	return Plugin_Continue;
}


// This happens every frame / tick
public void OnGameFrame()
{
	// Creates a variable named entity with a value of -1
	int entity = -1;
	
	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "decoy_projectile")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// If the decoy entity's has bounced already then execute this section
		if(decoyHasBounced[entity])
		{
			continue;
		}

		// obtains the index of the player that threw the grenade and store it within the attacker variable
		int attacker = GetEntPropEnt(entity, Prop_Send, "m_hThrower");

		// If the client meets our validation criteria then execute this section
		if(!IsValidClient(attacker))
		{
			continue;
		}
	

		float entityPosition[3];

		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPosition);

		// Loops through all of the clients
		for (int client = 1; client <= MaxClients; client++)
		{
			// If the client does not meet our validation criteria then execute this section
			if(!IsValidClient(client))
			{
				continue;
			}

			// If the client is also the attacker then execute this section
			if(client == attacker)
			{
				continue;
			}

			// If the client is not alive then execute this section
			if(!IsPlayerAlive(client))
			{
				continue;
			}

			// If the client and attacker are on the same then execute this section
			if(GetClientTeam(client) == GetClientTeam(attacker))
			{
				continue;
			}

			float playerPosition[3];

			GetEntPropVector(client, Prop_Data, "m_vecOrigin", playerPosition);

			// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
			float distance = GetVectorDistance(entityPosition, playerPosition);

			// If the client's ducking status is false then execute this section
			if(!isPlayerDucking[client])
			{
				playerPosition[2] += 6.0;

				// If the distance is over 50 then execute this section
				if(distance < 16.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 12.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.0)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 16.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 18.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 16.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 13.0)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}
			}

			// If the client's ducking status is true then execute this section
			else
			{
				// 
				playerPosition[2] += 7.0;

				// If the distance is over 50 then execute this section
				if(distance < 16.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 18.25)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 13.0)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}
			}
		}
	}
}





public void inflictdamage(int client, int entity, int attacker)
{
	// Sets the decoy entity's bounce status to true
	decoyHasBounced[entity] = true;

//	float damageForce[3];

//	float entityPosition[3];

//	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", damageForce);

//	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPosition);

	// Applies 500 club damage to the client from the attacker with a decoy grenade entity
	SDKHooks_TakeDamage(client, entity, attacker, 500.0, (1 << 7), entity, NULL_VECTOR, NULL_VECTOR);

	PrintToChatAll("Debug - Radius Within Range Of A Target");
}



public void Hook_DecoyStartTouch(int entity, int other)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return;
	}

	// If the decoy entity's bounce status is set to true then execute this section
	if(decoyHasBounced[entity])
	{
		return;
	}

	// If the entity that the throwing knife collided with is not a player index then execute this section
	if(other < 0 || other > MaxClients)
	{
		return;
	}

	// If the client meets our validation criteria then execute this section
	if(!IsValidClient(other))
	{
		return;
	}

	// obtains the index of the player that threw the grenade and store it within the attacker variable
	int attacker = GetEntPropEnt(entity, Prop_Send, "m_hThrower");

	// If the client meets our validation criteria then execute this section
	if(!IsValidClient(attacker))
	{
		return;
	}

	if(attacker == other)
	{
		return;
	}

	float damageForce[3];

	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", damageForce);

	if(GetVectorLength(damageForce) == 0.0)
	{
		return;
	}

	PrintToChat(attacker, "Physically Hit A Player");

	// Applies 500 club damage to the client from the attacker with a decoy grenade entity
	SDKHooks_TakeDamage(other, entity, attacker, 500.0, (1 << 7), entity, NULL_VECTOR, NULL_VECTOR);
}



////////////////
// - Events - //
////////////////


// This happens when a player spawns
public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the client's userid and converts it to an index and store it within our client variable
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Removes all the weapons from the client
	RemoveAllWeapons(client);

	// Gives the client a decoy grenade
	GiveDecoyGrenade(client);
}


// This happens when a player fires their weapon
public void Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	// Obtains the client's userid and converts it to an index and store it within our client variable
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	PrintToChat(client, "Debug - Weapon Fired!");

	/* NOTE: Using any lower time gap will cause the player to be unable to
			 fully receive the decoy grenade, and render them unable to see
			 the view model, as well as throw the grenade. */

	// Gives the client a decoy grenade after 0.8 seconds
	CreateTimer(0.8, Timer_GiveDecoyGrenade, client, TIMER_FLAG_NO_MAPCHANGE);
}


// This happens when a new round starts
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Removes all of the hostages from the map
	RemoveEntityHostage();
}



///////////////////////////
// - Regular Functions - //
///////////////////////////


// This happens when the plugin is loaded
public void LateLoadSupport()
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// Adds a hook to the client which will let us track when the player is eligible to pick up a weapon
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
	}
}


// This happens when a player spawns
public void RemoveAllWeapons(int client)
{
	for(int loop3 = 0; loop3 < 4; loop3++)
	{
		for(int WeaponNumber = 0; WeaponNumber < 24; WeaponNumber++)
		{
			int WeaponSlotNumber = GetPlayerWeaponSlot(client, WeaponNumber);

			if(WeaponSlotNumber == -1)
			{
				continue;
			}

			if(!IsValidEdict(WeaponSlotNumber) || !IsValidEntity(WeaponSlotNumber))
			{
				continue;
			}

			RemovePlayerItem(client, WeaponSlotNumber);

			AcceptEntityInput(WeaponSlotNumber, "Kill");
		}
	}
}


// This happens when a player spawns
public void GiveDecoyGrenade(int client)
{
	// Gives the client the specified weapon
	GivePlayerItem(client, "weapon_decoy");

	PrintToChat(client, "Debug - Carrying %i Decoys", GetEntProp(client, Prop_Send, "m_iAmmo", _, 18));

	// If the client has 1 decoy then execute this section
	if(GetEntProp(client, Prop_Send, "m_iAmmo", _, 18) == 1)
	{
		return;
	}

	// Changes the client's amount of decoy grenades to 1
	SetEntProp(client, Prop_Send, "m_iAmmo", 1, _, 18);
}


// This happens when a new round starts 
public void RemoveEntityBuyZones()
{
	// Creates a variable named entity with a value of -1
	int entity = -1;
	
	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "func_buyzone")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Kills the entity, removing it from the game
		AcceptEntityInput(entity, "Kill");

		PrintToChatAll("Debug - A Buyzone has been removed from the map :%i", entity);
	}
}


// This happens when a new round starts 
public void RemoveEntityBombSites()
{
	// Creates a variable named entity with a value of -1
	int entity = -1;
	
	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "func_bomb_target")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Kills the entity, removing it from the game
		AcceptEntityInput(entity, "Kill");

		PrintToChatAll("Debug - A Bomb Target has been removed from the map :%i", entity);
	}
}


// This happens when a new map is loaded
public void RemoveEntityHostageRescuePoint()
{
	// Creates a variable named entity with a value of -1
	int entity = -1;

	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "func_hostage_rescue")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Kills the entity, removing it from the game
		AcceptEntityInput(entity, "Kill");

		PrintToChatAll("Debug - A Hostage Rescue Point has been removed from the map :%i", entity);
	}
}


// This happens when a new round starts 
public void RemoveEntityHostage()
{
	// Creates a variable named entity with a value of -1
	int entity = -1;

	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "hostage_entity")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Kills the entity, removing it from the game
		AcceptEntityInput(entity, "Kill");

		PrintToChatAll("Debug - A Hostage has been removed from the map :%i", entity);
	}

	// Changes the value of the entity variable to -1
	entity = -1;

	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "info_hostage_spawn")) != -1)
	{
		// If the entity does not meet the criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Kills the entity, removing it from the game
		AcceptEntityInput(entity, "Kill");

		PrintToChatAll("Debug - A Hostage Spawn has been removed from the map :%i", entity);
	}
}



///////////////////////////////
// - Timer Based Functions - //
///////////////////////////////


// This happens every 2.0 seconds and is used to remove items and weapons lying around in the map
public Action Timer_CleanFloor(Handle timer)
{
	// Loops through all entities that are currently in the game
	for (int entity = MaxClients + 1; entity <= GetMaxEntities(); entity++)
	{
		// If the entity does not meet our criteria of validation then execute this section
		if(!IsValidEntity(entity))
		{
			continue;
		}

		// Creates a variable which we will use to store data within
		char className[64];

		// Obtains the entity's class name and store it within our className variable
		GetEntityClassname(entity, className, sizeof(className));

		// If the className contains neither weapon_ nor item_ then execute this section
		if((StrContains(className, "weapon_") == -1 && StrContains(className, "item_") == -1))
		{
			continue;
		}

		// If the entity has an ownership relation then execute this section
		if(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") != -1)
		{
			continue;
		}

		// Removes the entity from the map 
		AcceptEntityInput(entity, "Kill");
	}

	return Plugin_Continue;
}


// This happens shortly after a player fires their weapon
public Action Timer_GiveDecoyGrenade(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Gives the client a decoy grenade
	GiveDecoyGrenade(client);

	return Plugin_Continue;
}


// This happens 0.1 seconds after a decoy_projectile is spawned
public Action Timer_DisableDecoyFunctionality(Handle Timer, int entity)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// Changes the entity's explosion status
	SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);

	return Plugin_Continue;
}


// This happens 10.0 seconds after a decoy_projectile is spawned
public Action Timer_RemoveDecoyGrenade(Handle Timer, int entity)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// Kills the entity, removing it from the game
	AcceptEntityInput(entity, "Kill");

	return Plugin_Continue;
}



////////////////////////////////
// - Return Based Functions - //
////////////////////////////////


// Returns true if the client meets the validation criteria. elsewise returns false
public bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


