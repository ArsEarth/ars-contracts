#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export RPC_URL="http://localhost:5050";

export WORLD_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.world.address')

export ACTIONS_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts[] | select(.name == "dojo_ars::actions::actions" ).address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS 
echo " "
echo actions : $ACTIONS_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> component authorizations
COMPONENTS=("LastCheck" "LastBuildId" "BuildData" )

for component in ${COMPONENTS[@]}; do
    echo "sozo auth writer $component $ACTIONS_ADDRESS --world $WORLD_ADDRESS --rpc-url $RPC_URL"
    sozo auth writer $component $ACTIONS_ADDRESS --world $WORLD_ADDRESS --rpc-url $RPC_URL
    sleep 1
done

echo "Default authorizations have been successfully set."