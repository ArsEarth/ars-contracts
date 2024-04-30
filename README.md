
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
  - account  
  Modified from the OpenZeppelin Wallet contract version 0.8.0, the account contract supports two sets of public and private keys and allows for the modification of the public key.
  - xar20  
  Based on the OpenZeppelin ERC20 contract.  
  - blueprint721  
  The blueprint contract obtained after build, adheres to ERC721 rules.
  - blueprint721_offical  
  Official Blueprint Contract.
  - core1155  
  The core asset contract collected, adheres to ERC1155 rules.
## Complie Contracts
- xar_dojo
  ```
  sozo build
  sozo migrate
  ```
- Asset
  ```
  cd asset
  # The operation is the same for each folder. Enter a folder
  #compile
  scarb build

  #declare
  starkli declare target/dev/*.contract_class.json --rpc http://127.0.0.1:5050/ --account *** --keystore ***  --keystore-password ***

  #deploy
  starkli deploy classhash (constructor arguments) --rpc http://127.0.0.1:5050/ --account *** --keystore *** --keystore-password ***
  ```
## Software tool version
```
sozo --version
sozo 0.5.1

scarb --version
scarb 2.3.1 (0c8def3aa 2023-10-31)
cairo: 2.3.1 (https://crates.io/crates/cairo-lang-compiler/2.3.1)
sierra: 1.3.0

starkli --version
0.1.20 (e4d2307)
```
## Pre-World Initialization Configuration
- Authorization in Dojo  
  ```
  cd ard_dojo
  bash scripts/default_auth.sh
  ```
- Initialize Configuration in the Dojo World  
  Request the set_voxel_id and set_voxel_num functions from the world_config contract in the Dojo, setting the Voxel ID and quantity of the consumed resources.

## Have try
IOS: https://testflight.apple.com/join/smDJLIHx

Android: https://resources.x.ar/apk/XAR.apk

## Useful links:
Website: https://www.x.ar/

X: https://twitter.com/XAR_Labs

Mirror: https://mirror.xyz/xarlabs.eth

Youtube: https://www.youtube.com/@XARLABS

Litepaper: https://xar.gitbook.io/litepaper


