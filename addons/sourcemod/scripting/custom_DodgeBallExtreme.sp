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




//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Hooks the events that we intend to use in our plugin
//	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
//	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
//	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
}


// This happens when a new map is loaded
public void OnMapStart()
{
	// Executes the configuration file containing the modification specific configurations
	ServerCommand("exec sourcemod/dodgeball_extreme/dodgeball_settings.cfg");

	// Removes all of the buy zones from the map
	RemoveEntityBuyZones();

	// Removes Hostage Rescue Points from the map
	RemoveEntityHostageRescuePoint();
}





////////////////
// - Events - //
////////////////


// This happens when a new round starts
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Removes all of the hostages from the map
	RemoveEntityHostage();
}





///////////////////////////
// - Regular Functions - //
///////////////////////////


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




////////////////////////////////
// - Return Based Functions - //
////////////////////////////////

