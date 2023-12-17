#!/bin/bash
if [ -f "config_player.xml" ]; then
    echo "RUNNING MOD MANAGER"
    if [[ $SERVER_REMOVE_MODS != 1 ]]; then
        if [ "${STEAM_COLLECTION}" != "" ]; then
            python3 ModManager/ModManager.py -s "steamcmd/steamcmd.sh" -t "ModManager" --backup "12" "Daedalic Entertainment GmbH/Barotrauma/Multiplayer" -c $STEAM_COLLECTION "LocalMods"
        else
            python3 ModManager/ModManager.py -s "steamcmd/steamcmd.sh" -t "ModManager" --backup "12" "Daedalic Entertainment GmbH/Barotrauma/Multiplayer" -o "LocalMods"
        fi
    else
        echo -e "\033[0;31mMOD REMOVAL ENGAGED!!!!!\033[0m"
        python3 ModManager/ModManager.py -s "steamcmd/steamcmd.sh" -t "ModManager" --backup "12" "Daedalic Entertainment GmbH/Barotrauma/Multiplayer" -o "LocalMods" --removemods
    fi
fi
