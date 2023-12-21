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
    fn execute(
        ref self: ContractState,
        tokenid: felt252,
        block_num: u256,
        r_num: u256,
        g_num: u256,
        b_num: u256,
        black_num: u256,
    );
}


#[dojo::contract]
mod setup_world {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::{ResourcesCost, AdminTrait};

    #[external(v0)]
    fn execute(
        ref self: ContractState,
        tokenid: felt252,
        block_num: u256,
        r_num: u256,
        g_num: u256,
        b_num: u256,
        black_num: u256,
    ) {
        let world = self.world_dispatcher.read();
        world.only_admins(@get_caller_address());

        set!(
            world,
            (ResourcesCost {
                tokenid,
                block_num,
                r_num,
                g_num,
                b_num,
                black_num,
            })
        );
        return ();
    }
}