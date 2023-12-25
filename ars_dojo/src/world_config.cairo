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
struct VoxelId {
    #[key]
    config_id: u8,
    base_voxel_id: u256,
    r_voxel_id: u256,
    g_voxel_id: u256,
    b_voxel_id: u256,
    balck_voxel_id: u256,
}

#[derive(Model, Drop, Serde)]
struct ResourcesCost {
    #[key]
    tokenid: felt252,
    block_num: u256,
    r_num: u256,
    g_num: u256,
    b_num: u256,
    black_num: u256,
}

#[starknet::interface]
trait ISetupWorld<ContractState> {
    fn set_voxel_num(
        ref self: ContractState,
        tokenid: felt252,
        block_num: u256,
        r_num: u256,
        g_num: u256,
        b_num: u256,
        black_num: u256,
    );
    fn set_voxel_id(
        ref self: ContractState,
        base_voxel_id: u256,
        r_voxel_id: u256,
        g_voxel_id: u256,
        b_voxel_id: u256,
        balck_voxel_id: u256,
    );
}


#[dojo::contract]
mod setup_world {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::{ResourcesCost, VoxelId, AdminTrait};

    #[external(v0)]
    fn set_voxel_num(
        ref self: ContractState,
        tokenid: Array<felt252>,
        block_num: Array<u256>,
        r_num: Array<u256>,
        g_num: Array<u256>,
        b_num: Array<u256>,
        black_num: Array<u256>,
    ) {
        let world = self.world_dispatcher.read();
        world.only_admins(@get_caller_address());
        assert(tokenid.len() == block_num.len(), 'data error');

        let mut i: usize = 0;
        loop {
            if i == tokenid.len() {
                break;
            }
            
            set!(
                world,
                (ResourcesCost {
                    tokenid: *tokenid.at(i),
                    block_num: *block_num.at(i),
                    r_num: *r_num.at(i),
                    g_num: *g_num.at(i),
                    b_num: *b_num.at(i),
                    black_num: *black_num.at(i),
                })
            );
            i += 1;
        };
        return ();
    }

    #[external(v0)]
    fn set_voxel_id(
        ref self: ContractState,
        base_voxel_id: u256,
        r_voxel_id: u256,
        g_voxel_id: u256,
        b_voxel_id: u256,
        balck_voxel_id: u256,
    ) {
        let world = self.world_dispatcher.read();
        world.only_admins(@get_caller_address());
        let config_id: u8 = 1;

        set!(
            world,
            (VoxelId {
                config_id,
                base_voxel_id,
                r_voxel_id,
                g_voxel_id,
                b_voxel_id,
                balck_voxel_id,
            })
        );
        return ();
    }
}