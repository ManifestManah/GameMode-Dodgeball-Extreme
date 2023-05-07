# [Game Mode: Dodgeball Extreme]
## About
Significantly changes the gameplay by turning the game in to a dodgeball match with two teams facing off against each other. Each player is given their own ball, which they can throw in the direction of their opponents. If the ball hits an enemy player, that player will die. If the ball hits a wall, an object or already has hit another person, then the ball is considered inactive, and will not be able to kill anybody that it hits thereafter.
Players can press their inspect key, F by default, to catch nearby active balls thrown by enemies. If the player manages to catch an opponent's ball, then the opponent that threw the ball will die.
Players can press their use key, E by default, to perform a dash that temporarily increases their movement speed, which allow players to perform epic moves in the form of surprising throws and catches. 
The first team to eliminate all of the players on the opposing team wins the round.


## About Game Levels / Maps
This game mode comes with a total of 5 unique maps, specifically designed for the dodgeball extreme game mode.
The dodgeball arenas are all set in different and unique locations. Three of the arenas takes place in modified areas of known maps. One takes place in a gym hall, and the last is in an orange and grey dev based area. The dodgeball arenas varies in size depending on the map, and although these maps are made for the game mode, there is nothing preventing you from using any other regular maps when playing Dodgeball xtreme.
The available custom maps are as follows:
- db_dev_mani
- db_gym_mani
- db_dust_mani
- db_mirage_mani
- db_nuke_mani


## Settings & Configuration Information
In the csgo/cfg/sourcemod/dodgeball_extreme/ directory you will find a file called "dodgeball_convars" which contains all of the convar settings the game mode provides. Below is a list of convar settings and what they do.
- DBE_DodgeballRecoveryTime - Determines how long time, in seconds, after the player threw their ball before they receive a new ball. 
- DBE_FirstDodgeBall - Determines how long time, in seconds, after the freeze time before players receive their first ball.
- DBE_CatchFeature - If set to 1, players can catch other people's grenades by pressing their inspect key [F].
- DBE_CatchCooldownTime - Defines how long time it takes before the player can attempt to catch a ball after they tried to last time.
- DBE_DashFeature - If set to 1 players can use a dash, briefly increasing their movement speed.
- DBE_DashEffects - If set to 1 visual effects will be applied to the player as they us their dash.
- DBE_DashDuration - Specifies for how long, in seconds, the dash should last.
- DBE_DashCooldownTime -Defines how long time, in seconds, before the player can use their dash again.
- DBE_GrenadeTrails - If set to 1 then trails will be added to the thrown dodgeballs.
- DBE_GrenadeTrailsTeamColors - If set to 1 then the trails will be colored in blue, and red depending on the thrower's team.
- DBE_GrenadeTeamColors - If set to 1 the dodgeball's colors will be colored blue and red depending on the thrower's team.
- DBE_IntroductionMenu - If set to 1 then players will be met with an introduction menu explaining how to play the game mode.
- DBE_DisableMiniMap - If set to 1 the player's minimap / radar hud element will be disabled.


## Requirements
In order for the plugin to work, you must have the following installed:
- [SourceMod](https://www.sourcemod.net/downloads.php?branch=stable) 


## Installation
1) Download the contents and open the downloaded zip file.
2) Drag the files in to your server's csgo/ directory.
3) Edit the files in cfg/sourcemod/dodgeball_extreme/ to match your preferences
4) Compress and add the contents of the resource folder to your fast download server.
5) Restart your server.


## Known Bugs & Issues
- None.


## Future development plans
- [ ] Fix any bugs/issues that gets reported.


## Bug Reports, Problems & Help
This plugin has been tested and used on a server, there should be no bugs or issues aside from the known ones found here.
Should you run in to a bug that isn't listed here, then please report it in by creating an issue here on GitHub.
