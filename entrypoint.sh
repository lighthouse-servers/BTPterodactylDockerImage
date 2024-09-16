#!/bin/bash

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Set environment for Steam Proton
if [ -f "/usr/local/bin/proton" ]; then
    if [ ! -z ${SRCDS_APPID} ]; then
	    mkdir -p /home/container/.steam/steam/steamapps/compatdata/${SRCDS_APPID}
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="/home/container/.steam/steam"
        export STEAM_COMPAT_DATA_PATH="/home/container/.steam/steam/steamapps/compatdata/${SRCDS_APPID}"
    else
        echo -e "----------------------------------------------------------------------------------"
        echo -e "WARNING!!! Proton needs variable SRCDS_APPID, else it will not work. Please add it"
        echo -e "Server stops now"
        echo -e "----------------------------------------------------------------------------------"
        exit 0
        fi
fi

# Switch to the container's working directory
cd /home/container || exit 1

## just in case someone removed the defaults.
if [ "${STEAM_USER}" == "" ]; then
    echo -e "steam user is not set.\n"
    echo -e "Using anonymous user.\n"
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo -e "user set to ${STEAM_USER}"
fi

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then 
    # Update Source Server
    if [ ! -z ${SRCDS_APPID} ]; then
	    if [ "${STEAM_USER}" == "anonymous" ]; then
            ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} $( [[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
	    else
            numactl --physcpubind=+0 ./steamcmd/steamcmd.sh +force_install_dir /home/container +login ${STEAM_USER} ${STEAM_PASS} ${STEAM_AUTH} $( [[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows' ) +app_update ${SRCDS_APPID} $( [[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}" ) $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) $( [[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}" ) $( [[ -z ${VALIDATE} ]] || printf %s "validate" ) +quit
	    fi
    else
        echo -e "No appid set. Starting Server"
    fi

else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

echo "Downloading latest version of LuaCsForBarotrauma"
wget -N  -q --show-progress https://github.com/evilfactory/LuaCsForBarotrauma/releases/download/latest/luacsforbarotrauma_patch_linux_server.zip -O luacsforbarotrauma_patch_linux_server.zip
unzip -qo luacsforbarotrauma_patch_linux_server.zip

pterodactylfix=" LuaUserData.RegisterType('System.Console')
local Console = LuaUserData.CreateStatic('System.Console')
Hook.Patch('System.Console', 'get_IsOutputRedirected', function(self, ptable)
    ptable.PreventExecution = true
        return true
end)
Hook.Patch('System.Console', 'get_IsInputRedirected', function(self, ptable)
        ptable.PreventExecution = false
        return true
end)
Hook.Add('think', 'ConsoleInput', function()
    if Console.KeyAvailable then
                Game.ExecuteCommand(Console.ReadLine())
    end
end)"
echo "$pterodactylfix" >> Lua/ModLoader.lua

# ModManager download and update
echo "Downloading Mod Manager"
wget -N -q --show-progress https://github.com/Milord-ThatOneModder/Barotrauma-ModManager/releases/latest/download/ModManager.zip -O ModManager.zip
unzip -qo ModManager.zip
wget -N -q --show-progress https://raw.githubusercontent.com/lighthouse-servers/BTPterodactylDockerImage/master/mod_manager.sh -O mod_manager.sh
chmod +x mod_manager.sh

touch custom_script.sh
chmod +x custom_script.sh

## if SERVER_NAME is not set or to "" set it from the file
if [ -z "$SERVER_NAME" ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_NAME=$(xmllint -xpath 'string(/serversettings/@name)' "serversettings.xml")
    else
        SERVER_NAME="Server"
    fi
    export SERVER_NAME
fi
if [ "${SERVER_NAME_PREFIX}" != "" ]; then
    if [[ $SERVER_NAME != *$SERVER_NAME_PREFIX* ]]; then
        SERVER_NAME="${SERVER_NAME_PREFIX} - ${SERVER_NAME}"
    fi
fi
## if SERVER_PUBLIC is not set
if [ -z ${CAN_BE_PRIVATE} ] || [[ $CAN_BE_PRIVATE == 1 ]]; then
    if [ -z "$SERVER_PUBLIC" ]; then
        if [ -f "serversettings.xml" ]; then
            SERVER_PUBLIC=$(xmllint -xpath 'string(/serversettings/@IsPublic)' "serversettings.xml")
        else
            SERVER_PUBLIC="True"
        fi
        export SERVER_PUBLIC
    fi
else
    SERVER_PUBLIC="True"
    export SERVER_PUBLIC
fi

## if CAN_BE_PASSWORDED is not set or if its 1 (true)
if [ -z ${CAN_BE_PASSWORDED} ] || [[ $CAN_BE_PASSWORDED == 1 ]]; then
    ## if SERVER_PASSWORD is not set
    if [ -z ${SERVER_PASSWORD} ]; then
        if [ -f "serversettings.xml" ]; then
            SERVER_PASSWORD=$(xmllint -xpath 'string(/serversettings/@password)' "serversettings.xml")
        else
            SERVER_PASSWORD=""
        fi
    fi
    export SERVER_PASSWORD
else
    SERVER_PASSWORD=""
    export SERVER_PASSWORD
fi
## if SERVER_MAXPLAYERS is not set
if [ -z ${SERVER_MAXPLAYERS} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_MAXPLAYERS=$(xmllint -xpath 'string(/serversettings/@MaxPlayer)' "serversettings.xml")
    else
        SERVER_MAXPLAYERS="16"
    fi
    export SERVER_MAXPLAYERS
fi
## if SERVER_PLAYSTYLE is not set
if [ -z ${SERVER_PLAYSTYLE} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_PLAYSTYLE=$(xmllint -xpath 'string(/serversettings/@PlayStyle)' "serversettings.xml")
    else
        SERVER_PLAYSTYLE="Casual"
    fi
    export SERVER_PLAYSTYLE
fi
## if SERVER_BANAFTERWRONGPASSWORD is not set
if [ -z ${SERVER_BANAFTERWRONGPASSWORD} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_BANAFTERWRONGPASSWORD=$(xmllint -xpath 'string(/serversettings/@BanAfterWrongPassword)' "serversettings.xml")
    else
        SERVER_BANAFTERWRONGPASSWORD="True"
    fi
    export SERVER_BANAFTERWRONGPASSWORD
fi
## if SERVER_KARMA is not set
if [ -z ${SERVER_KARMA} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_KARMA=$(xmllint -xpath 'string(/serversettings/@KarmaEnabled)' "serversettings.xml")
    else
        SERVER_KARMA="False"
    fi
    export SERVER_KARMA
fi
## if SERVER_KARMAPRESET is not set
if [ -z ${SERVER_KARMAPRESET} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_KARMAPRESET=$(xmllint -xpath 'string(/serversettings/@KarmaPreset)' "serversettings.xml")
    else
        SERVER_KARMAPRESET="default"
    fi
    export SERVER_KARMAPRESET
fi
## if SERVER_LANGUAGE is not set
if [ -z ${SERVER_LANGUAGE} ]; then
    if [ -f "serversettings.xml" ]; then
        SERVER_LANGUAGE=$(xmllint -xpath 'string(/serversettings/@Language)' "serversettings.xml")
    else
        SERVER_LANGUAGE="English"
    fi
    export SERVER_LANGUAGE
fi


# Replace Startup Variables
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
# echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
