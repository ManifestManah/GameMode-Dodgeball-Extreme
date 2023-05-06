// List of Includes
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

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

ConVar cvar_CooldownCatchTime;
ConVar cvar_CooldownDashTime;


//////////////////////////
// - Global Variables - //
//////////////////////////

// Global Booleans
bool isPlayerDucking[MAXPLAYERS + 1] = {false,...};
bool isPlayerAlreadyStruck[MAXPLAYERS + 1] = {false,...};
bool isPlayerRecentlyConnected[MAXPLAYERS + 1] = {false,...};
bool decoyHasBounced[2049] = {false,...};
bool isPlayerFeaturesAvailable = true;

// Global Integers
int effectSpriteSheet = -1;

// Global Floats
float playerCooldownDash[MAXPLAYERS + 1] = {0.0,...};
float playerCooldownCatch[MAXPLAYERS + 1] = {0.0,...};

// Global Characters
char hudMessage[1024];


//////////////////////////
// - Forwards & Hooks - //
//////////////////////////


// This happens when the plugin is loaded
public void OnPluginStart()
{
	// Creates the names and assigns values to the ConVars the modification will be using 
	CreateModSpecificConvars();

	// Hooks the events that we intend to use in our plugin
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	// Adds a command istener for when a player inspects their weapon
	AddCommandListener(CommandListener_Inspect, "+lookatweapon");

	// Removes any unowned weapon and item entities from the map every 2.0 seconds
	CreateTimer(2.0, Timer_CleanFloor, _, TIMER_REPEAT);

	// Creates a timer that will update the player's cooldown hud every 0.1 second
	CreateTimer(0.1, Timer_PlayerCooldownHud, _, TIMER_REPEAT);

	// Allows the modification to be loaded while the server is running, without causing gameplay issues
	LateLoadSupport();

	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();

	// Fixes an issue with the hint area not displaying html colors
	AllowHtmlHintMessages();
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

	// Adds files to the download list, and precaches them
	DownloadAndPrecacheFiles();
}


// This happens once all post authorizations have been performed and the client is fully in-game
public void OnClientPostAdminCheck(int client)
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return;
	}

	// Sets the client's recently connected status true
	isPlayerRecentlyConnected[client] = true;

	// Adds a hook to the client which will let us track when the player is eligible to pick up a weapon
	SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);

	// Adds a hook to the client which will let us track when the player takes damage
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
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

	// Removes the hook that we had added to the client to track when the player took damage
	SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
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

	// Kills the weapon entity, removing it from the game
	AcceptEntityInput(weapon, "Kill");

	return Plugin_Handled;
}


// This happens when the player takes damage
public Action Hook_OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype) 
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the attacker does not meet our validation criteria then execute this section
	if(!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}

	// If the inflictor is not a valid entity then execute this section
	if(!IsValidEntity(inflictor))
	{
		return Plugin_Continue;
	}

	// If the victim and attacker is on the same team
	if(GetClientTeam(client) == GetClientTeam(attacker))
	{
		return Plugin_Continue;
	}

	// Creates a variable to store our data within
	char className[64];

	// Obtains the classname of the inflictor entity and store it within our classname variable
	GetEdictClassname(inflictor, className, sizeof(className));

	// If the inflictor entity is not a decoy projectile then execute this section
	if(!StrEqual(className, "decoy_projectile", false))
	{
		return Plugin_Continue;
	}

	// If the decoy inflictor's has bounced already then execute this section
	if(decoyHasBounced[inflictor])
	{
		// Changes the amount of damage to 0.0
		damage = 0.0;

		return Plugin_Changed;
	}

	// Creates a variable to store our data within
	char nameOfClient[64];

	// Creates a variable to store our data within
	char nameOfAttacker[64];

	// Obtains the name of the client and store it within the nameOfClient variable
	GetClientName(client, nameOfClient, sizeof(nameOfClient));

	// Obtains the name of the attacker and store it within the nameOfAttacker variable
	GetClientName(attacker, nameOfAttacker, sizeof(nameOfAttacker));

	// Sends a message to the client in the chat area
	PrintToChat(client, "You were struck and killed by %s's dodgeball.", nameOfAttacker);

	// Sends a message to the attacker in the chat area
	PrintToChat(attacker, "Your dodgeball struck and killed %s.", nameOfClient);

	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav"))
	{	
		// Precaches the sound file
		PrecacheSound("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", true);
	}

	// Emits a sound to the specified client that only they can hear
	EmitSoundToClient(client, "manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	// Sets the client's struck status true
	isPlayerAlreadyStruck[client] = true;

	// Changes the amount of damage to 500.0
	damage = 500.0;

	return Plugin_Changed;
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

		// Creates a colored beam trail effect and attaches it to the decoy entity
		CreateGrenadeTrail(client, entity, 160, 0, 0, 210);
	}

	// If the client is on the counter-terrorist team then execute this section
	else if(GetClientTeam(client) == 3)
	{
		// Changes the color of the entity to the specified RGB color
		DispatchKeyValue(entity, "rendercolor", "0 0 180");

		// Creates a colored beam trail effect and attaches it to the decoy entity
		CreateGrenadeTrail(client, entity, 0, 0, 180, 210);
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

		// Removes the hook that we had attached to the grenade
		SDKUnhook(entity, SDKHook_TouchPost, Hook_DecoyTouchPost);
	}

	// If the client meets our validation criteria then execute this section
	else
	{
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

	// If the player is pressing their USE button then execute this section
	if(buttons & IN_USE)
	{
		// If the client's dash is blocked then execute this section
		if(!isPlayerFeaturesAvailable)
		{
			return Plugin_Continue;
		}

		// If the player's Dash is on cooldown then execute this section
		if(playerCooldownDash[client])
		{
			return Plugin_Continue;
		}

		// Changes the player's dash to be on cooldown
		playerCooldownDash[client] = GetConVarFloat(cvar_CooldownDashTime);

		// Changes the client's movement speed to a high value
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 3.25);

		// Creates a variable which we will use to store data within
		char soundFilePath[64];

		// If the randomly chosen number is 0 then execute this section
		if(GetRandomInt(0, 1) == 0)
		{
			// Changes the contents stored within our soundFilePath variable
			soundFilePath = "manifest/dodgeball_extreme/sfx_dash1.wav";
		}

		// If the randomly chosen number is 0 then execute this section
		else
		{
			// Changes the contents stored within our soundFilePath variable
			soundFilePath = "manifest/dodgeball_extreme/sfx_dash2.wav";
		}

		// If the sound is not already precached then execute this section
		if(!IsSoundPrecached(soundFilePath))
		{	
			// Precaches the sound file
			PrecacheSound(soundFilePath, true);
		}

		// Emits a sound to the specified client that only they can hear
		EmitSoundToClient(client, soundFilePath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

		AttachVisualParticleEffects(client, 10.0);
		AttachVisualParticleEffects(client, 16.0);
		AttachVisualParticleEffects(client, 22.0);
		AttachVisualParticleEffects(client, 28.0);
		AttachVisualParticleEffects(client, 34.0);
		AttachVisualParticleEffects(client, 40.0);

		// Changes the client's movement speed back to normal after a short time
		CreateTimer(0.25, Timer_ResetPlayerSpeed, client, TIMER_FLAG_NO_MAPCHANGE);
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


// This happens when a player tries to inspect their weapon
public Action CommandListener_Inspect(int client, const char[] command, int argc)
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

	// If the client's catch is blocked then execute this section
	if(!isPlayerFeaturesAvailable)
	{
		return Plugin_Continue;
	}

	// If the player's catch is on cooldown then execute this section
	if(playerCooldownCatch[client])
	{
		return Plugin_Continue;
	}

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

		// If the client and attacker are on the same then execute this section
		if(GetClientTeam(client) == GetClientTeam(attacker))
		{
			continue;
		}

		// Creates a variable which we will use to store data within
		float playerPosition[3];

		// Creates a variable which we will use to store data within
		float entityPosition[3];

		// Obtain's the position of the client and store it within our playerPosition variable
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", playerPosition);

		// Obtain's the position of the entity and store it within our entityPosition variable
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPosition);

		// Modifies the coordinate position on the z-axis
		playerPosition[2] += 10.0;

		// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
		float distance = GetVectorDistance(entityPosition, playerPosition);

		// If the distance is lower than 31 then execute this section
		if(distance < 31.0)
		{
			// Inflicts damage upon the client that threw the ball
			inflictDamageCatch(client, entity, attacker);

			return Plugin_Continue;
		}

		// Modifies the coordinate position on the z-axis
		playerPosition[2] += 11.0;

		// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
		distance = GetVectorDistance(entityPosition, playerPosition);

		// If the distance is lower than 31 then execute this section
		if(distance < 31.0)
		{
			// Inflicts damage upon the client that threw the ball
			inflictDamageCatch(client, entity, attacker);

			return Plugin_Continue;
		}

		// Modifies the coordinate position on the z-axis
		playerPosition[2] += 11.0;

		// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
		distance = GetVectorDistance(entityPosition, playerPosition);

		// If the distance is lower than 31 then execute this section
		if(distance < 31.0)
		{
			// Inflicts damage upon the client that threw the ball
			inflictDamageCatch(client, entity, attacker);

			return Plugin_Continue;
		}

		// Modifies the coordinate position on the z-axis
		playerPosition[2] += 11.0;

		// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
		distance = GetVectorDistance(entityPosition, playerPosition);

		// If the distance is lower than 31 then execute this section
		if(distance < 31.0)
		{
			// Inflicts damage upon the client that threw the ball
			inflictDamageCatch(client, entity, attacker);

			return Plugin_Continue;
		}

		// If the client's ducking status is set to false then execute this section
		if(!isPlayerDucking[client])
		{
			// Modifies the coordinate position on the z-axis
			playerPosition[2] += 11.0;

			// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
			distance = GetVectorDistance(entityPosition, playerPosition);

			// If the distance is lower than 31 then execute this section
			if(distance < 31.0)
			{
				// Inflicts damage upon the client that threw the ball
				inflictDamageCatch(client, entity, attacker);

				return Plugin_Continue;
			}

			// Modifies the coordinate position on the z-axis
			playerPosition[2] += 11.0;

			// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
			distance = GetVectorDistance(entityPosition, playerPosition);

			// If the distance is lower than 31 then execute this section
			if(distance < 31.0)
			{
				// Inflicts damage upon the client that threw the ball
				inflictDamageCatch(client, entity, attacker);

				return Plugin_Continue;
			}
		}
	}

	// Sends a message to the client in the chat area
	PrintToChat(client, "There were no active ball within your range for you to catch.");

	// Changes the player's catch to be on cooldown
	playerCooldownCatch[client] = GetConVarFloat(cvar_CooldownCatchTime);

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
	
		// Creates a variable which we will use to store data within
		float entityPosition[3];

		// Obtain's the position of the entity and store it within our entityPosition variable
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

			// If the client's struck status is true then execute this section
			if(isPlayerAlreadyStruck[client])
			{
				continue;
			}

			// Creates a variable which we will use to store data within
			float entityVelocity[3];

			// Obtains the velocity of the entity and store it within the entityVelocity variable 
			GetEntPropVector(entity, Prop_Data, "m_vecVelocity", entityVelocity);

			// If the velocity is currently 0.0 then execute this section
			if(GetVectorLength(entityVelocity) == 0.0)
			{
				continue;
			}

			// Creates a variable which we will use to store data within
			float playerPosition[3];

			// Obtain's the position of the client and store it within our playerPosition variable
			GetEntPropVector(client, Prop_Data, "m_vecOrigin", playerPosition);

			// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
			float distance = GetVectorDistance(entityPosition, playerPosition);

			// If the client's ducking status is false then execute this section
			if(!isPlayerDucking[client])
			{
				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 6.0;

				// If the distance is over 50 then execute this section
				if(distance < 16.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 12.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.0)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 16.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 18.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
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
				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 7.0;

				// If the distance is over 50 then execute this section
				if(distance < 16.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 17.50)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
				playerPosition[2] += 14.0;

				// Obtains the dsitance from the decoy entity to the client and store it within the distance variable
				distance = GetVectorDistance(entityPosition, playerPosition);

				// If the distance is over 50 then execute this section
				if(distance < 18.25)
				{
					inflictdamage(client, entity, attacker);

					continue;
				}

				// Modifies the coordinate position on the z-axis
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

	// If the client's struck status is true then execute this section
	if(isPlayerAlreadyStruck[other])
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

	// Creates a variable which we will use to store data within
	float entityVelocity[3];

	// Obtains the velocity of the entity and store it within the entityVelocity variable 
	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", entityVelocity);

	// If the velocity is currently 0.0 then execute this section
	if(GetVectorLength(entityVelocity) == 0.0)
	{
		return;
	}

	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav"))
	{	
		// Precaches the sound file
		PrecacheSound("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", true);
	}

	// Emits a sound to the specified client that only they can hear
	EmitSoundToClient(other, "manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	// Applies 500 club damage to the client from the attacker with a decoy grenade entity
	SDKHooks_TakeDamage(other, entity, attacker, 500.0, (1 << 7), entity, NULL_VECTOR, NULL_VECTOR);

	// Creates a variable to store our data within
	char nameOfClient[64];

	// Creates a variable to store our data within
	char nameOfAttacker[64];

	// Obtains the name of the client and store it within the nameOfClient variable
	GetClientName(other, nameOfClient, sizeof(nameOfClient));

	// Obtains the name of the attacker and store it within the nameOfAttacker variable
	GetClientName(attacker, nameOfAttacker, sizeof(nameOfAttacker));

	// Sends a message to the client in the chat area
	PrintToChat(other, "You were struck and killed by %s's dodgeball.", nameOfAttacker);

	// Sends a message to the attacker in the chat area
	PrintToChat(attacker, "Your dodgeball struck and killed %s.", nameOfClient);
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

	// Sets the client's struck status false
	isPlayerAlreadyStruck[client] = false;

	// Removes all the weapons from the client
	RemoveAllWeapons(client);

	// Gives the client a decoy grenade
	GiveDecoyGrenade(client);

	// Creates and sends a menu with introduction information to the client
	IntroductionMenu(client);

	// Disables CS:GO's built-in minimap / radar hud element
	CreateTimer(0.0, Timer_HideMinimap, client, TIMER_FLAG_NO_MAPCHANGE);
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

	// Resets the cooldown of all the clients
	ResetCooldowns();

	// Disables the usage of dash and catch
	isPlayerFeaturesAvailable = false;
}


// This happens when a new round starts and the freeze time has expired
public void Event_RoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// If the client is a bot then execute this section
		if(IsFakeClient(client))
		{
			continue;
		}

		// Gives the client a decoy grenade after 0.1 seconds
		CreateTimer(0.1, Timer_GiveDecoyGrenade, client, TIMER_FLAG_NO_MAPCHANGE);

		// Plays the whistle blowing sound after 0.1 seconds
		CreateTimer(0.1, Timer_BlowWhistle, client, TIMER_FLAG_NO_MAPCHANGE);
	}

	// Enables the usage of dash and catch
	isPlayerFeaturesAvailable = true;
}



///////////////////////////
// - Regular Functions - //
///////////////////////////


// This happens when the plugin is loaded
public void CreateModSpecificConvars()
{
	///////////////////////////////
	// - Configuration Convars - //
	///////////////////////////////

	cvar_CooldownCatchTime = 			CreateConVar("DBE_CatchCooldownTime", 			"5.00",	 	"How many seconds should it take before a player can attempt to catch a ball again? - [Default = 5.00]");
	cvar_CooldownDashTime = 			CreateConVar("DBE_DashCooldownTime", 			"8.00",	 	"How many seconds should it take before a player can use their dash again? - [Default = 8.00]");


	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "dodgeball_convars", "sourcemod/dodgeball_extreme");
}


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

		// Adds a hook to the client which will let us track when the player takes damage
		SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}


// This happens every frame / tick if a player is within range of an enemy's active dodgeball 
public void inflictdamage(int client, int entity, int attacker)
{
	// Sets the decoy entity's bounce status to true
	decoyHasBounced[entity] = true;

	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav"))
	{	
		// Precaches the sound file
		PrecacheSound("manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", true);
	}

	// Creates a variable to store our data within
	char nameOfClient[64];

	// Creates a variable to store our data within
	char nameOfAttacker[64];

	// Obtains the name of the client and store it within the nameOfClient variable
	GetClientName(client, nameOfClient, sizeof(nameOfClient));

	// Obtains the name of the attacker and store it within the nameOfAttacker variable
	GetClientName(attacker, nameOfAttacker, sizeof(nameOfAttacker));

	// Sends a message to the client in the chat area
	PrintToChat(client, "You were struck and killed by %s's dodgeball.", nameOfAttacker);

	// Sends a message to the attacker in the chat area
	PrintToChat(attacker, "Your dodgeball struck and killed %s.", nameOfClient);

	// Emits a sound to the specified client that only they can hear
	EmitSoundToClient(client, "manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	// Applies 500 club damage to the client from the attacker with a decoy grenade entity
	SDKHooks_TakeDamage(client, entity, attacker, 500.0, (1 << 7), entity, NULL_VECTOR, NULL_VECTOR);
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
	// If the client's dash is blocked then execute this section
	if(!isPlayerFeaturesAvailable)
	{
		return;
	}

	// Gives the client the specified weapon
	GivePlayerItem(client, "weapon_decoy");

	// If the client has 1 decoy then execute this section
	if(GetEntProp(client, Prop_Send, "m_iAmmo", _, 18) == 1)
	{
		return;
	}

	// Changes the client's amount of decoy grenades to 1
	SetEntProp(client, Prop_Send, "m_iAmmo", 1, _, 18);
}


// This happens when a player spawns
public void IntroductionMenu(int client)
{
	// If the client's recently connected status is false then execute this section
	if(!isPlayerRecentlyConnected[client])
	{
		return;
	}

	// Sets the client's recently connected status false
	isPlayerRecentlyConnected[client] = false;

	// Creates a menu and connects it to a menu handler
	Menu introductionMenu = new Menu(introductionMenu_Handler);

	// Adds a title to our menu
	introductionMenu.SetTitle("Dodgeball Extreme - How to play\n---------------------------------------\nWin the round by eliminating all\nof the players on the opposing\nteam, by hitting them with your\ndodgeball, or by catching their\nball before it touches anything.\n \n- [E] grants a burst of speed\n- [F] catch a nearby enemy's ball\n ", "Introduction");

	// Adds an item to our menu
	introductionMenu.AddItem("Introduction", "I am ready to have fun!", ITEMDRAW_DEFAULT);

	// Disables the menu's exit option 
	introductionMenu.ExitButton = false;

	// Sends the menu with all of its contents to the client
	introductionMenu.Display(client, MENU_TIME_FOREVER);
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
	}
}


// This happens when a new round starts
public void ResetCooldowns()
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// If the client is a bot then execute this section
		if(IsFakeClient(client))
		{
			continue;
		}

		// Resets the cooldown of the player's dash
		playerCooldownDash[client] = 0.0;

		// Resets the cooldown of the player's catch
		playerCooldownCatch[client] = 0.0;
	}
}


// This happens when a decoy grenade projectile has been spawned
public void CreateGrenadeTrail(int client, int entity, int red, int green, int blue, int alpha)
{
	// Creates an array containing 4 values
	int TrailColor[4];

	// Changes the first value to the value equals to our red variable
	TrailColor[0] = red;

	// Changes the first value to the value equals to our green variable
	TrailColor[1] = green;

	// Changes the first value to the value equals to our blue variable
	TrailColor[2] = blue;

	// Changes the first value to the value equals to our alpha variable
	TrailColor[3] = alpha;

	// Creates a temporary visual effect beam and attaches it to the grenade entity
	TE_SetupBeamFollow(entity, effectSpriteSheet, effectSpriteSheet, 0.65, 12.0, 0.1, 0, TrailColor);

	// Displays the temporary visiual effect to all players
	TE_SendToAll();
}


// This happens when a player uses their dash
public void AttachVisualParticleEffects(int client, float height)
{
	// Creates a particle system and store it within our entity variable
	int entity = CreateEntityByName("info_particle_system");

	// If the entity does not meet our criteria of validation then execute this section
	if(!IsValidEntity(entity))
	{
		return;
	}

	// Creates a variable which we will use to store data within
	float playerLocation[3];

	// Obtains the player's location and store it within our playerLocation variable
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", playerLocation);

	// Modifies the player's location on the z-axis by the amount specified by our height variable
	playerLocation[2] += height;

	// If the client is on the terrorist team then execute this section
	if(GetClientTeam(client) == 2)
	{
		// Sets the name of the particle system we want to use
		DispatchKeyValue(entity, "effect_name", "Manifest_Dash_Trail_T");
	}

	// If the client is on the counter-terrorist team then execute this section
	else if(GetClientTeam(client) == 3)
	{
		// Sets the name of the particle system we want to use
		DispatchKeyValue(entity, "effect_name", "Manifest_Dash_Trail_CT");
	}
	
	// Spawns the entity
	DispatchSpawn(entity);

	// Activates our entity
	ActivateEntity(entity);
	
	// Starts our particle entity system
	AcceptEntityInput(entity, "Start");

	// Moves the particle system to the player's location
	TeleportEntity(entity, playerLocation, NULL_VECTOR, NULL_VECTOR);

	// Changes the variantstring to activator
	SetVariantString("!activator");

	// Sets the client to be the parent of the entity
	AcceptEntityInput(entity, "SetParent", client, entity, 0);

	// Removes the particle effect from the game after 0.5 seconds
	CreateTimer(0.5, Timer_RemoveParticleEffect, entity, TIMER_FLAG_NO_MAPCHANGE);
}


// This happens every frame / tick if a player is within range of an enemy's active dodgeball 
public void inflictDamageCatch(int client, int entity, int attacker)
{
	// Sets the decoy entity's bounce status to true
	decoyHasBounced[entity] = true;

	// Creates a variable to store our data within
	char nameOfClient[64];

	// Creates a variable to store our data within
	char nameOfAttacker[64];

	// Obtains the name of the client and store it within the nameOfClient variable
	GetClientName(client, nameOfClient, sizeof(nameOfClient));

	// Obtains the name of the attacker and store it within the nameOfAttacker variable
	GetClientName(attacker, nameOfAttacker, sizeof(nameOfAttacker));

	// If the attacker is alive then execute this section
	if(IsPlayerAlive(attacker))
	{
		// Applies 500 club damage to the attacker from the client with a decoy grenade entity
		SDKHooks_TakeDamage(attacker, entity, client, 500.0, (1 << 7), entity, NULL_VECTOR, NULL_VECTOR);

		// Sends a message to the attacker in the chat area
		PrintToChat(attacker, "You died because %s caught your ball.", nameOfClient);

		// Sends a message to the client in the chat area
		PrintToChat(client, "You killed player %s by catching their ball.", nameOfAttacker);

		// If the sound is not already precached then execute this section
		if(!IsSoundPrecached("music/nemesis.wav"))
		{	
			// Precaches the sound file
			PrecacheSound("music/nemesis.wav", true);
		}

		// Emits a sound to the specified attacker that only they can hear
		EmitSoundToClient(attacker, "music/nemesis.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}

	// If the client is not alive then execute this section
	else
	{
		// Sends a message to the client in the chat area
		PrintToChat(attacker, "%s caught your ball, but you were already dead.", nameOfClient);

		// Sends a message to the client in the chat area
		PrintToChat(client, "You Caught player %s's ball but they were already dead.", nameOfAttacker);
	}

	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached("manifest/dodgeball_extreme/sfx_catch.wav"))
	{	
		// Precaches the sound file
		PrecacheSound("manifest/dodgeball_extreme/sfx_catch.wav", true);
	}

	// Emits a sound to the specified client that only they can hear
	EmitSoundToClient(client, "manifest/dodgeball_extreme/sfx_catch.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	// Changes the player's catch to be on cooldown
	playerCooldownCatch[client] = GetConVarFloat(cvar_CooldownCatchTime);

	// If the entity does not meet the criteria of validation then execute this section
	if(!IsValidEntity(entity))
	{
		return;
	}

	// Kills the entity, removing it from the game
	AcceptEntityInput(entity, "Kill");
}


// This happen when the plugin is loaded and when a new map starts
public void DownloadAndPrecacheFiles()
{
	// Adds the specified file to the download table
	AddFileToDownloadsTable("materials/manifest/dodgeball_extreme/laser_white.vmt");
	AddFileToDownloadsTable("materials/manifest/dodgeball_extreme/laser_white.vtf");
	AddFileToDownloadsTable("materials/manifest/dodgeball_extreme/laser.vmt");
	AddFileToDownloadsTable("materials/manifest/dodgeball_extreme/laser.vtf");
	AddFileToDownloadsTable("sound/manifest/dodgeball_extreme/sfx_catch.wav");
	AddFileToDownloadsTable("sound/manifest/dodgeball_extreme/sfx_dash1.wav");
	AddFileToDownloadsTable("sound/manifest/dodgeball_extreme/sfx_dash2.wav");
	AddFileToDownloadsTable("sound/manifest/dodgeball_extreme/sfx_dodgeball_impact.wav");
	AddFileToDownloadsTable("sound/manifest/dodgeball_extreme/sfx_refereewhistle_blown.wav");
	AddFileToDownloadsTable("particles/manifest/dodgeball_extreme/dodgeball_extreme.pcf");

	// Precaches the specified model / texture
	effectSpriteSheet = PrecacheModel("manifest/dodgeball_extreme/laser.vmt");

	// Precaches the specified sound
	PrecacheGeneric("particles/manifest/dodgeball_extreme/dodgeball_extreme.pcf", true);
	PrecacheSound("sound/manifest/dodgeball_extreme/sfx_catch.wav", true);
	PrecacheSound("sound/manifest/dodgeball_extreme/sfx_dash1.wav", true);
	PrecacheSound("sound/manifest/dodgeball_extreme/sfx_dash2.wav", true);
	PrecacheSound("sound/manifest/dodgeball_extreme/sfx_dodgeball_impact.wav", true);
	PrecacheSound("sound/manifest/dodgeball_extreme/sfx_refereewhistle_blown.wav", true);
	PrecacheSound("music/nemesis.wav", true);
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


// This happens once every 0.1 seconds and updates the player's cooldown HUD element
public Action Timer_PlayerCooldownHud(Handle timer)
{
	// Loops through all of the clients
	for (int client = 1; client <= MaxClients; client++)
	{
		// Resets the contents of the hudMessage variable
		hudMessage = "";

		// If the client does not meet our validation criteria then execute this section
		if(!IsValidClient(client))
		{
			continue;
		}

		// If the client is a bot then execute this section
		if(IsFakeClient(client))
		{
			continue;
		}

		// If the player's Dash is on cooldown then execute this section
		if(playerCooldownDash[client] > 0.0)
		{
			// Modifies the contents stored within the hudMessage variable
			Format(hudMessage, 1024, "%s\n<font color='#fbb227'>[E] Dash:</font><font color='#5fd6f9'> %0.2f seconds cooldown</font>", hudMessage, playerCooldownDash[client]);

			// Subtracts 0.1 from the current value of playerCooldownDash[client]
			playerCooldownDash[client] -= 0.1;
		}

		// If the player's Dash is not on cooldown then execute this section
		else
		{
			// Changes the player's dash to be off cooldown
			playerCooldownDash[client] = 0.0;

			// Modifies the contents stored within the hudMessage variable
			Format(hudMessage, 1024, "%s\n<font color='#fbb227'>[E] Dash:</font><font color='#5fd6f9'> Ready</font>", hudMessage);
		}

		// If the player's catch is on cooldown then execute this section
		if(playerCooldownCatch[client] > 0.0)
		{
			// Modifies the contents stored within the hudMessage variable
			Format(hudMessage, 1024, "%s\n<font color='#fbb227'>[F] Catch:</font><font color='#5fd6f9'> %0.2f seconds cooldown</font>", hudMessage, playerCooldownCatch[client]);

			// Subtracts 0.1 from the current value of playerCooldownCatch[client]
			playerCooldownCatch[client] -= 0.1;
		}

		// If the player's catch is not on cooldown then execute this section
		else
		{
			// Changes the player's catch to be off cooldown
			playerCooldownCatch[client] = 0.0;

			// Modifies the contents stored within the hudMessage variable
			Format(hudMessage, 1024, "%s\n<font color='#fbb227'>[F] Catch:</font><font color='#5fd6f9'> Ready</font>", hudMessage);
		}

		// Displays the contents of our hudMessage variable to the client in the hint text area of the screen 
		PrintHintText(client, hudMessage);
	}

	return Plugin_Continue;
}


// This happens when a player uses their dash
public Action Timer_RemoveParticleEffect(Handle Timer, int entity)
{
	// If the entity does not meet our criteria validation then execute this section
	if(!IsValidEntity(entity))
	{
		return Plugin_Continue;
	}

	// Stops the entity from being active
	AcceptEntityInput(entity, "Stop");

	// Kills the entity, removing it from the game
	AcceptEntityInput(entity, "Kill");

	return Plugin_Continue;
}


// This happens when a player spawns
public Action Timer_HideMinimap(Handle timer, int client) 
{
	// If the client does not meet our validation criteria then execute this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the player is anything but a bot then execute this section
	if(IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	//Disables CS:GO's built-in minimap / radar hud element
	SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | 4096);

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


// This happens shortly after a player fires their weapon
public Action Timer_BlowWhistle(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// If the sound is not already precached then execute this section
	if(!IsSoundPrecached("manifest/dodgeball_extreme/sfx_refereewhistle_blown.wav"))
	{	
		// Precaches the sound file
		PrecacheSound("manifest/dodgeball_extreme/sfx_refereewhistle_blown.wav", true);
	}

	// Emits a sound to the specified client that only they can hear
	EmitSoundToClient(client, "manifest/dodgeball_extreme/sfx_refereewhistle_blown.wav", SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.00, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

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


// This happens 0.5 seconds after a player presses their dash button
public Action Timer_ResetPlayerSpeed(Handle Timer, int client)
{
	// If the player does not meet our validation criteria then execut this section
	if(!IsValidClient(client))
	{
		return Plugin_Continue;
	}

	// Changes the client's movement speed back to normal
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

	return Plugin_Continue;
}



////////////////////////////////
// - Return Based Functions - //
////////////////////////////////


// Returns true if the client meets the validation criteria. elsewise returns false
public bool IsValidClient(int client)
{
	if(!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


// This happens when a player interacts with the introuction menu
public int introductionMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	return;
}



////////////////////////////////////
// - Functions By Other Authors - //
////////////////////////////////////


/*	Thanks to Phoenix (˙·٠●Феникс●٠·˙) and Franc1sco franug 
	for their Fix Hint Color Message plugin release. The code
	below is practically identical to their release, and was
	included in this plugin simply to make the life easier for
	the users of the game mode. The original plugin can be
	found as a stand alone at the link below:
	- https://github.com/Franc1sco/FixHintColorMessages 	*/

UserMsg g_TextMsg;
UserMsg g_HintText;
UserMsg g_KeyHintText;

public void AllowHtmlHintMessages()
{
	g_TextMsg = GetUserMessageId("TextMsg");
	g_KeyHintText = GetUserMessageId("KeyHintText");
	g_HintText = GetUserMessageId("HintText");
	
	HookUserMessage(g_KeyHintText, HintTextHook, true);
	HookUserMessage(g_HintText, HintTextHook, true);
}


public Action HintTextHook(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
	char szBuf[2048];
	
	if(msg_id == g_KeyHintText)
	{
		msg.ReadString("hints", szBuf, sizeof szBuf, 0);
	}
	else
	{
		msg.ReadString("text", szBuf, sizeof szBuf);
	}
	
	if(StrContains(szBuf, "</") != -1)
	{
		DataPack hPack = new DataPack();
		
		hPack.WriteCell(playersNum);
		
		for(int i = 0; i < playersNum; i++)
		{
			hPack.WriteCell(players[i]);
		}
		
		hPack.WriteString(szBuf);
		
		hPack.Reset();
		
		RequestFrame(HintTextFix, hPack);
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


public void HintTextFix(DataPack hPack)
{
	int iCountNew = 0, iCountOld = hPack.ReadCell();
	
	int iPlayers[MAXPLAYERS+1];
	
	for(int i = 0, iPlayer; i < iCountOld; i++)
	{
		iPlayer = hPack.ReadCell();
		
		if(IsClientInGame(iPlayer))
		{
			iPlayers[iCountNew++] = iPlayer;
		}
	}
	
	if(iCountNew != 0)
	{
		char szBuf[2048];
		
		hPack.ReadString(szBuf, sizeof szBuf);
		
		Protobuf hMessage = view_as<Protobuf>(StartMessageEx(g_TextMsg, iPlayers, iCountNew, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
		
		if(hMessage)
		{
			hMessage.SetInt("msg_dst", 4);
			hMessage.AddString("params", "#SFUI_ContractKillStart");
			
			Format(szBuf, sizeof szBuf, "</font>%s<script>", szBuf);
			hMessage.AddString("params", szBuf);
			
			hMessage.AddString("params", NULL_STRING);
			hMessage.AddString("params", NULL_STRING);
			hMessage.AddString("params", NULL_STRING);
			
			EndMessage();
		}
	}
	
	hPack.Close();
}