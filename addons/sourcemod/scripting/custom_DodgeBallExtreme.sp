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


// This happens when a grenade is thrown
public void AttachTrail(int client, int entity)
{
	// Creates an array containing the red, green, blue and alpha valuees used for coloring and save it within our TrailColor variable
	int TrailColor[4] = {255, 0, 255, 255};

	// If the client is on the terrorist team then execute this section
	if(GetClientTeam(client) == 2)
	{
		// Sets the blue coloring value to 0
		TrailColor[2] = 0;
	}

	// If the client is on the counter-terrorist team then execute this section
	else if(GetClientTeam(client) == 3)
	{
		// Sets the red coloring value to 0
		TrailColor[0] = 0;
	}

	// Creates a temporary visual effect and attach it to the grenade entity
	TE_SetupBeamFollow(entity, SpriteSheet, SpriteSheet, 0.5, 5.0, 0.1, 1, TrailColor);

	// Display the temporary visiual effect to all players
	TE_SendToAll();
}



// This happens when a grenade is thrown
public void SetGrenadeModel(int client, int entity)
{
	// If the specified model is not already precached then execute this section
	if(!IsModelPrecached("models/DBE/props/ball.mdl"))
	{
		// Precache the model we intend to use
		PrecacheModel("models/DBE/props/ball.mdl");
	}

	// Changes the grenade's model
	SetEntityModel(entity, "models/DBE/props/ball.mdl");
}



// This happens when a grenade is thrown
public void SetGrenadeColor(int client, int entity)
{
	// If the client is on the terrorist team then execute this section
	if(GetClientTeam(client) == 2)
	{
		// Changes the grenade's color to red
		SetEntityRenderColor(entity, 255, 0, 0, 255);
	}

	// If the client is on the counter-terrorist team then execute this section
	else if(GetClientTeam(client) == 3)
	{
		// Changes the grenade's color to blue
		SetEntityRenderColor(entity, 0, 0, 255, 255);
	}
}



// This happens when a player spawns
public void RemoveAllWeapons(int client)
{
	for(int loop3 = 0; loop3 < 4 ; loop3++)
	{
		for(int WeaponNumber = 0; WeaponNumber < 24; WeaponNumber++)
		{
			int WeaponSlotNumber = GetPlayerWeaponSlot(client, WeaponNumber);

			if (WeaponSlotNumber != -1)
			{
				if (IsValidEdict(WeaponSlotNumber) && IsValidEntity(WeaponSlotNumber))
				{
					RemovePlayerItem(client, WeaponSlotNumber);

					AcceptEntityInput(WeaponSlotNumber, "Kill");
				}
			}
		}
	}
}



// This happens when a player throws a flashbang or when a player spawns
public void SetflashbangAmount(int client)
{
	// Changes the player's amount of flashbang grenades to 5
	SetEntProp(client, Prop_Send, "m_iAmmo", 5, _, 15);
}


// This happens when a player throws a decoy or when a player spawns
public void SetDecoyAmount(int client)
{
	// Changes the player's amount of decoy grenades to 5
	SetEntProp(client, Prop_Send, "m_iAmmo", 5, _, 18);
}



// This happens when we want to change a server variable
public void SetConVarInt2(const char[] ConvarName, int ConvarValue)
{
	// Obtains the name of the convar and store it within our ServerVariable
	ConVar ServerVariable = FindConVar(ConvarName);

	// If the ServerVariable is anything else than null then execute this section
	if(ServerVariable != null)
	{
		// Sets the server variable to an integer value
		ServerVariable.SetInt(ConvarValue);
	}
}



// This happens when a knife king is killed
public void PlaySoundForClient(int client, const char[] SoundName)
{
	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached(SoundName))
	{	
		// Precaches the sound file
		PrecacheSound(SoundName, true);
	}

	// Creates a variable called FullSoundName which we will use to store the sound's full name path within
	char FullSoundName[256];

	// Formats a message which we intend to use as a client command
 	Format(FullSoundName, sizeof(FullSoundName), "play */%s", SoundName);

	// Performs a clientcommand to play a sound only the clint can hear
	ClientCommand(client, FullSoundName);
}



// This happens when a new round starts 
public void RemoveEntityHostage()
{
	// Creates an integer named entity and sets it to INVALID_ENT_REFERENCE;
	int entity = INVALID_ENT_REFERENCE;
	
	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "hostage_entity")) != INVALID_ENT_REFERENCE)
	{
		// If the entity meets the criteria of validation then execute this section
		if(IsValidEntity(entity))
		{
			// Kills the entity, removing it from the game
			AcceptEntityInput(entity, "Kill");
		}
	}
}



// This happens when a new round starts 
public void RemoveEntityBuyzones()
{
	// Creates an integer named entity and sets it to INVALID_ENT_REFERENCE;
	int entity = INVALID_ENT_REFERENCE;
	
	// Loops through all of the entities and tries to find any matching the specified criteria
	while ((entity = FindEntityByClassname(entity, "func_buyzone")) != INVALID_ENT_REFERENCE)
	{
		// If the entity meets the criteria of validation then execute this section
		if(IsValidEntity(entity))
		{
			// Kills the entity, removing it from the game
			AcceptEntityInput(entity, "Kill");
		}
	}
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
