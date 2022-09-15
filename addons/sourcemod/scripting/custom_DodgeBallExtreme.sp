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
	description	= "Players have a chance to drop a health kit upon their death.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


//////////////////////////
// - Global Variables - //
//////////////////////////

// Global Integers (Material Files)
int SpriteSheet = 0;



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
