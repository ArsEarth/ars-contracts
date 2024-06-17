use starknet::ContractAddress;
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

trait AdminTrait {
    fn is_admin(self: IWorldDispatcher, addr: @ContractAddress) -> bool;
    fn only_admins(self: IWorldDispatcher, caller: @ContractAddress);
}


impl AdminTraitImpl of AdminTrait {
    fn is_admin(self: IWorldDispatcher, addr: @ContractAddress) -> bool {
        if self.is_owner(*addr, 0) { // 0 == world
            return true;
        }
        false
    }

    fn only_admins(self: IWorldDispatcher, caller: @ContractAddress) {
        assert(self.is_admin(caller), 'Not authorized');
    }
}

#[derive(Model, Drop, Serde)]
struct VoxelIdV1 {
    #[key]
    config_id: u8,
    base_voxel_id: u256,
    r_voxel_id: u256,
    g_voxel_id: u256,
    b_voxel_id: u256,
}

#[derive(Model, Drop, Serde)]
struct AssetContract {
    #[key]
    contract_key: u256,
    contract_type: felt252,
    contract_address: ContractAddress,
    contract_rate: u256,
}

#[starknet::interface]
trait ISetupWorld<ContractState> {
    fn set_voxel_id_v1(
        ref self: ContractState,
        base_voxel_id: u256,
        r_voxel_id: u256,
        g_voxel_id: u256,
        b_voxel_id: u256,
    );
    fn set_asset_contract(
        ref self: ContractState,
        keys: Array<u256>,
        types: Array<felt252>,
        address: Array<ContractAddress>,
        rate: Array<u256>,
    );
}


#[dojo::contract]
mod setup_world {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::{VoxelIdV1, AdminTrait, AssetContract};

    #[external(v0)]
    fn set_voxel_id_v1(
        ref self: ContractState,
        base_voxel_id: u256,
        r_voxel_id: u256,
        g_voxel_id: u256,
        b_voxel_id: u256,
    ) {
        let world = self.world_dispatcher.read();
        world.only_admins(@get_caller_address());
        let config_id: u8 = 1;

        set!(
            world,
            (VoxelIdV1 {
                config_id,
                base_voxel_id,
                r_voxel_id,
                g_voxel_id,
                b_voxel_id,
            })
        );
        return ();
    }

    #[external(v0)]
    fn set_asset_contract(
        ref self: ContractState,
        keys: Array<u256>,
        types: Array<felt252>,
        addresses: Array<ContractAddress>,
        rate: Array<u256>,
    ) {
        let world = self.world_dispatcher.read();
        world.only_admins(@get_caller_address());
        assert(keys.len() == types.len(), 'data error');
        assert(types.len() == addresses.len(), 'data error');
        
        let mut i: usize = 0;
        loop {
            if i == types.len() {
                break;
            }
            
            set!(
                world,
                (AssetContract {
                    contract_key: *keys.at(i),
                    contract_type: *types.at(i),
                    contract_address: *addresses.at(i),
                    contract_rate: *rate.at(i),
                })
            );
            i += 1;
        };
        return ();
    }
}