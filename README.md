# XAR.Space Contracts

**This repository includes the Cairo and Dojo code for the XAR.Space contracts.**

## Intro
XAR.Space is the Augmented World where Augmented Reality(AR) meets Blockchain. 

In this new version, we aim to support the Briq Protocol. That means stuffs you build using Briq can now be turned into blueprints in the AR World. Players can use these blueprints to construct creations and show them off in the real world. We demonstrated this gameplay with the Ducks Everywhere NFT Collection as an example. 

In AR World, everything is made with Voxels and Pigments. To get these materials, you gonna step into the real world to collect them. Then, enter the Blueprint Store in the game, build whatever you like, and show it off in the real world.

We're cooking up some fun ways for you to play around with these items in future updates, like maybe taking a shot at them!


## Directory Explanation
- xar_dojo  
  XAR' Dojo World
- asset  
  Contracts related to assets, temporarily independent of the dojo.  
  - build721  
  The blueprint contract obtained after build, adheres to ERC721 rules.
  - voxel1155  
  The asset contract for collecting voxels, adheres to ERC1155 rules.
  - core1155  
  The core asset contract collected, adheres to ERC1155 rules, which is not used for now.
## Complie Contracts
- xar_dojo
  ```
  sozo build
  sozo migrate
  ```
- Asset
  ```
  cd asset
  
  #compile
  starknet-compile build721/lib.cairo sierra/build721.json --single-file
  starknet-compile voxel1155/lib.cairo sierra/voxel1155.json --single-file
  starknet-compile core1155/lib.cairo sierra/core1155.json --single-file

  #declare
  starkli declare sierra/build721.json --rpc http://127.0.0.1:5050/ --account *** --keystore ***  --keystore-password ***
  starkli declare sierra/voxel1155.json --rpc http://127.0.0.1:5050/ --account *** --keystore ***  --keystore-password ***
  starkli declare sierra/core1155.json --rpc http://127.0.0.1:5050/ --account *** --keystore ***  --keystore-password ***

  #deploy
  #721
  starkli deploy 0x00db28d8e2eeb951bc15788b5bb0b4ef7e647c997d45270d2bc22a15a4a59e6f 0x5c47b38f788ec9d382b5079165bc96c0f49647250199a78d34c436d54d12217 0x0 0x0 --rpc http://127.0.0.1:5050/ --account *** --keystore *** --keystore-password ***
  #voxel
  starkli deploy 0x034d8ee4e0ebf84c0c63ff0d35778b39bb68f07ff63ee03ea5625b7beeb70fe9 0x5c47b38f788ec9d382b5079165bc96c0f49647250199a78d34c436d54d12217 0x0 --rpc http://127.0.0.1:5050/ --account *** --keystore ***  --keystore-password ***
  #core
  starkli deploy 0x064c532fbde75b0efcb690b3d59ead43dc98b5dea100afdff37d916b03d18b87 0x5c47b38f788ec9d382b5079165bc96c0f49647250199a78d34c436d54d12217 0x0 --rpc http://127.0.0.1:5050/ --account *** --keystore *** --keystore-password ***
  ```
## Pre-World Initialization Configuration
- Setup whitelist  
  Add the actions contract from dojo to the whitelists of build721, voxel1155, and core1155.
- Authorization in Dojo  
  ```
  cd ard_dojo
  bash scripts/default_auth.sh
  ```
- Initialize Configuration in the Dojo World  
  Request the set_voxel_id and set_voxel_num functions from the world_config contract in the Dojo, setting the Voxel ID and quantity of the consumed resources.

## Have try
IOS: https://testflight.apple.com/join/smDJLIHx

Android: https://drive.google.com/drive/folders/1oi8DtYikHiCDYonJnXAOW-r7PAfdoEJX

## Key Links
Website: https://XAR.Space/ 

Codex: https://codex.XAR.Space/

Twitter: https://twitter.com/XAR_Labs

Discord: https://discord.gg/CzrmueueNt
