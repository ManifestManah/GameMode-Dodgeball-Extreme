// List of Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <cstrike>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Dodgeball Extreme",
	author		= "Manifest @Road To Glory",
	description	= "Players have a chance to drop a health kit upon their death.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


//////////////////////////
// - Global Variables - //
//////////////////////////

// Global Integers (Material Files)
int SpriteSheet = 0;

bool GrenadeHasBounced[2049] = {false,...};


//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Sets the specific settings required in order for the game mode to work as intended
	GameModeSpecificSettings();

	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();

	// Allows the modification to be loaded while the server is running, without giving gameplay issues
	LateLoadSupport();
}


// This happens when a new map is loaded
public void OnMapStart()
{
	// Sets the specific settings required in order for the game mode to work as intended
	GameModeSpecificSettings();

	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();
}



// This happens when a new map is loaded and when the plugin is loaded
public void GameModeSpecificSettings()
{
	// Changes the mp_free_armor to 0 to remove the player's base armor value
	SetConVarInt2("mp_free_armor", 0);

	// Changes the mp_playercashawards & mp_teamcashawards to 0 to remove cash related messages and the hud element
	SetConVarInt2("mp_playercashawards", 0);
	SetConVarInt2("mp_teamcashawards", 0);

	// Removes radio messages, to avoid the "fire in the hole" chat spam
	SetConVarInt2("sv_ignoregrenaderadio", 1);

	// Changes the amount of grenades a player can carry
	SetConVarInt2("ammo_grenade_limit_default",10);
	SetConVarInt2("ammo_grenade_limit_flashbang",10);
	SetConVarInt2("ammo_grenade_limit_total", 10);
}




////////////////
// - Events - //
////////////////






///////////////////////////
// - Regular Functions - //
///////////////////////////



public Action LateLoadSupport()
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// Hooks the WeaponCanUse function to check when the player is eligible to pick up a weapon
		SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);

		// Hooks the OnTakeDamage function to check when the player takes damage
		SDKHook(client, SDKHook_OnTakeDamage, Hook_TakeDamage);
	}

	return Plugin_Continue;
}


// This happen when the plugin is loaded and when a new map starts
public void DownloadAndPrecacheFiles()
{
	AddFileToDownloadsTable("materials/sprites/laser.vmt");
	AddFileToDownloadsTable("materials/sprites/laser.vtf");

	SpriteSheet = PrecacheModel("sprites/laser.vmt");



	// Adds the model related files to the download table
	AddFileToDownloadsTable("sound/Manifest/dodgeball_extreme/hit.mp3");
	AddFileToDownloadsTable("sound/Manifest/dodgeball_extreme/whistle.mp3");



	AddFileToDownloadsTable("models/items/healthkit.dx90.vtx");
	AddFileToDownloadsTable("models/items/healthkit.mdl");
	AddFileToDownloadsTable("models/items/healthkit.phy");
	AddFileToDownloadsTable("models/items/healthkit.sw.vtx");
	AddFileToDownloadsTable("models/items/healthkit.vvd");
	AddFileToDownloadsTable("materials/models/items/healthkit01.vtf");
	AddFileToDownloadsTable("materials/models/items/healthkit01.vmt");
	AddFileToDownloadsTable("materials/models/items/healthkit01_mask.vtf");


	// Precaches the model which we intend to use
	PrecacheModel("models/items/healthkit.mdl", true);


	// Precaches the sound which we intend to use
	PrecacheSound("sound/Manifest/dodgeball_extreme/hit.mp3", true);
	PrecacheSound("sound/Manifest/dodgeball_extreme/whistle.mp3", true);
}



///////////////////////////////
// - Timer Based Functions - //
///////////////////////////////


// This happens 0.25 seconds after a player spawns
public Action Timer_GiveWeapons(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Gives the player the specified weapon
	GivePlayerItem(client, "weapon_flashbang");

	// Gives the player the specified weapon
	GivePlayerItem(client, "weapon_decoy");

	// Changes the player's amount of flashbang grenades to 5
	SetflashbangAmount(client);

	// Changes the player's amount of decoys to 5
	SetDecoyAmount(client);

	return Plugin_Continue;
}


// This happens 0.1 seconds after a player throws a decoy or flashbang grenade
public Action Timer_PreventExplosion(Handle Timer, int entity)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// Changes the entity's explosion status
	SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);

	return Plugin_Continue;
}


// This happens 0.1 seconds after a player throws a decoy grenade
public Action Timer_RefillDecoys(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Changes the player's amount of decoys to 5
	SetDecoyAmount(client);

	return Plugin_Continue;
}



// This happens 0.1 seconds after a player throws a flashbang grenade
public Action Timer_RefillFlashBangs(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Changes the player's amount of flashbang grenades to 5
	SetflashbangAmount(client);

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
