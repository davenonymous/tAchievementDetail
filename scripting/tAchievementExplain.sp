#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors>

#define PLUGIN_VERSION "1.0"
#define MAX_ACHIEVEMENTS 512
#define MSGSIZE 255

new Handle:g_hCvarEnabled = INVALID_HANDLE;
new Handle:g_hCvarDisplay = INVALID_HANDLE;

new Handle:g_hConfigParser = INVALID_HANDLE;

new bool:g_bEnabled = false;
new g_iDisplayMode = 0;
new g_iLastAchievement = -1;

enum achievement {
	id,
	String:shortname[MSGSIZE]
}

new g_oList[MAX_ACHIEVEMENTS][achievement];

new g_iCount = 0;

public Plugin:myinfo =
{
	name = "tAchievementExplain",
	author = "Thrawn",
	description = "Explains achievements in any game supporting achievements",
	version = PLUGIN_VERSION,
	url = "http://aaa.einfachonline.net"
}

public OnPluginStart()
{
	CreateConVar("sm_tachievementexplain_version", PLUGIN_VERSION, "Plugin version.", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY);

	g_hCvarEnabled = CreateConVar("sm_tachievementexplain_enabled", "1", "Enable tAchievementExplain", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCvarDisplay = CreateConVar("sm_tachievementexplain_display", "0", "How to display messages. 1 - Chat, 2 - Hint, 0 - No Messages", FCVAR_PLUGIN, true, 0.0, true, 2.0);

	HookConVarChange(g_hCvarEnabled, Cvar_Changed);
	HookConVarChange(g_hCvarDisplay, Cvar_Changed);

	HookEvent("achievement_earned", Event_Achievement);

	RegConsoleCmd("sm_setlast", Command_SetLastAchievement);

	RegConsoleCmd("sm_explain", Command_ExplainLastAchievement);
	RegConsoleCmd("say", Cmd_BlockTriggers);
	RegConsoleCmd("say_team", Cmd_BlockTriggers);

	g_hConfigParser = SMC_CreateParser();
	SMC_SetReaders(g_hConfigParser, NewSection, KeyValue, EndSection);
}

public LoadGameTranslations() {
	decl String:game[32];
	GetGameFolderName(game, sizeof(game));

	decl String:shortName[255];
	Format(shortName, 255, "tAchievementExplain.phrases.%s.txt", game);

	decl String:translationPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, translationPath, PLATFORM_MAX_PATH, "translations/%s", shortName);

	if(FileExists(translationPath)) {
		LoadTranslations(shortName);
	} else {
		SetFailState("No achievement translation file found. Game (%s) does not support achievements or has no english translation yet.", game);
	}
}

public OnConfigsExecuted() {
	g_bEnabled = GetConVarBool(g_hCvarEnabled);
	g_iDisplayMode = GetConVarInt(g_hCvarDisplay);
}

public Cvar_Changed(Handle:convar, const String:oldValue[], const String:newValue[]) {
	OnConfigsExecuted();
}

public Action:Cmd_BlockTriggers(iClient, iArgs)
{
	if (iClient < 1 || iClient > MaxClients) return Plugin_Continue;
	if (iArgs < 1) return Plugin_Continue;

	// Retrieve the first argument and check it's a valid trigger
	decl String:strArgument[64]; GetCmdArg(1, strArgument, sizeof(strArgument));
	if (StrEqual(strArgument, "!explain", true)) return Plugin_Handled;

	// If no valid argument found, pass
	return Plugin_Continue;
}

public OnMapStart() {
	ParseConfig();
	LoadGameTranslations();
}

public Reset() {
	for(new i = 0; i < g_iCount; i++) {
		g_oList[i][id] = 0;
		strcopy(g_oList[i][shortname],MSGSIZE,"");
	}

	g_iCount = 0;
}

public ParseConfig() {
	Reset();

	decl String:game[32];
	GetGameFolderName(game, sizeof(game));

	decl String:configPath[256];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/tAchievementExplain.%s.txt", game);

	if (!FileExists(configPath))
	{
		SetFailState("No achievement definition file (%s) found.", configPath);
		return;
	}

	new line;
	new SMCError:err = SMC_ParseFile(g_hConfigParser, configPath, line);
	if (err != SMCError_Okay)
	{
		decl String:error[256];
		SMC_GetErrorString(err, error, sizeof(error));
		LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
		LogError("Parser encountered error: %s", error);
	}

	return;
}

public SMCResult:NewSection(Handle:smc, const String:name[], bool:opt_quotes) {}

public SMCResult:KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
	g_oList[g_iCount][id] = StringToInt(key);
	strcopy(g_oList[g_iCount][shortname],MSGSIZE,value);

	g_iCount++;
}

public SMCResult:EndSection(Handle:smc)
{
	LogMessage("Found %i achievement explanations.", g_iCount);
}

public Action:Command_SetLastAchievement(client, args) {
	if(!g_bEnabled) {
		ReplyToCommand(client, "tAchievementExplain is disabled.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setlast <achievement_id>");
		return Plugin_Handled;
	}

	if (args == 1) {
		new String:arg1[64];
		GetCmdArg(1, arg1, sizeof(arg1));

		new iArg = StringToInt(arg1);

		if(iArg > -1 && iArg < g_iCount) {
			g_iLastAchievement = iArg;

			decl String:searchTitle[MSGSIZE];
			Format(searchTitle,MSGSIZE,"%s_Title", g_oList[g_iLastAchievement][shortname]);

			ReplyToCommand(client, "Last achievement set to: %T", searchTitle, client);
		}
	}

	return Plugin_Handled;
}


public Action:Command_ExplainLastAchievement(client, args) {
	if(!g_bEnabled) {
		ReplyToCommand(client, "tAchievementExplain is disabled.");
		return Plugin_Handled;
	}

	if(g_iLastAchievement == -1) {
		ReplyToCommand(client, "Last achievement is unknown.");
		return Plugin_Handled;
	}

	decl String:searchTitle[MSGSIZE];
	decl String:searchDesc[MSGSIZE];
	Format(searchTitle,MSGSIZE,"%s_Title", g_oList[g_iLastAchievement][shortname]);
	Format(searchDesc,MSGSIZE,"%s_Desc", g_oList[g_iLastAchievement][shortname]);

	CPrintToChat(client, "{olive}%T: {default}%T", searchTitle, client, searchDesc, client);

	return Plugin_Handled;
}

public Action:Event_Achievement(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!g_bEnabled) {
		return Plugin_Continue;
	}

	new iAchievement = GetEventInt(event, "achievement");

	g_iLastAchievement = -1;
	for(new i = 0; i < g_iCount; i++) {
		if(g_oList[i][id] == iAchievement) {
			g_iLastAchievement = i;
			break;
		}
	}

	if(g_iDisplayMode == 0 || g_iLastAchievement == -1) {
		return Plugin_Continue;
	}

	decl String:searchTitle[MSGSIZE];
	decl String:searchDesc[MSGSIZE];
	Format(searchTitle,MSGSIZE,"%s_Title", g_oList[g_iLastAchievement][shortname]);
	Format(searchDesc,MSGSIZE,"%s_Desc", g_oList[g_iLastAchievement][shortname]);


	if(g_iDisplayMode == 1) {
		CPrintToChatAll("{olive}%T: {default}%T", searchTitle, searchDesc);
	}

	if(g_iDisplayMode == 2) {
		PrintHintTextToAll("%T\n%T", searchTitle, searchDesc);
	}

	return Plugin_Continue;
}