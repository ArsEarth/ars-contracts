use starknet::ContractAddress;

// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn test_demo(
        self: @TContractState,
        player: ContractAddress,
        value: u256,
    );

    fn mint_from_checks(
        self: @TContractState,
        contract_voxel_address: ContractAddress,
        contract_core_address: ContractAddress,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: Array<felt252>,
        startid: Array<felt252>,
        endid: Array<felt252>,
        amt: Array<felt252>,
        t721id: Array<felt252>,
        remove_block: Array<felt252>,
        r: Array<felt252>,
        s: Array<felt252>,
    );
}

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use integer::u256_from_felt252;
    use dojo_ars::models::{LastCheck};
    use dojo_ars::utils::verifySign;
    use super::IActions;
    use dojo_ars::models::{ICalleeVoxel1155Dispatcher, ICalleeVoxel1155DispatcherTrait};
    use dojo_ars::models::{ICalleeCore1155Dispatcher, ICalleeCore1155DispatcherTrait};

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn test_demo(
            self: @ContractState,
            player: ContractAddress,
            value: u256,
        ) {
            let world = self.world_dispatcher.read();
            // set!(world, (ArsDemo { player: player, value: value } ));
            set!(world, (LastCheck { player: player, token_id: 100000, last_id: value } ));
        }

        // ContractState is defined by system decorator expansion
        fn mint_from_checks(
            self: @ContractState,
            contract_voxel_address: ContractAddress,
            contract_core_address: ContractAddress,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: Array<felt252>,
            startid: Array<felt252>,
            endid: Array<felt252>,
            amt: Array<felt252>,
            t721id: Array<felt252>,
            remove_block: Array<felt252>,
            r: Array<felt252>,
            s: Array<felt252>,
        ) {
            let world = self.world_dispatcher.read();
            let mut i: usize = 0;

            let _tid = tid.clone();
            let _startid = startid.clone();
            let _endid = endid.clone();
            let _amt = amt.clone();
            let _r = r.clone();
            let _s = s.clone();
            let _t721id = t721id.clone();
            let _rblock = remove_block.clone();
            loop {
                if i >= tid.len() {
                    break;
                }
                let tokenid = u256_from_felt252(*_tid.at(i));
                let last_check = get!(world, (receiver, tokenid), (LastCheck));
                assert(verifySign(last_check.last_id, public_key, issuer, receiver, *_tid.at(i), *_startid.at(i), *_endid.at(i), *_amt.at(i), *_t721id.at(i), *_rblock.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

                let endchecksid = u256_from_felt252(*_endid.at(i));
                let amount = u256_from_felt252(*_amt.at(i));
                if tokenid == 10001 || tokenid == 10002 || tokenid == 10003  {
                    ICalleeCore1155Dispatcher { contract_address: contract_core_address }.mint(receiver, tokenid, amount);
                } else {
                    ICalleeVoxel1155Dispatcher { contract_address: contract_voxel_address }.mint(receiver, tokenid, amount);
                }
                set!(world, (LastCheck { player: receiver, token_id: tokenid, last_id: endchecksid } ));
                i += 1;
            };
        }
    }
}

