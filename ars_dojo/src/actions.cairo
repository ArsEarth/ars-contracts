use starknet::ContractAddress;


// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn test_demo(
        self: @TContractState,
        player: ContractAddress,
        value: u256,
    );

    fn mint_voxel_by_checks(
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

    fn mint_build_with_checks(
        self: @TContractState,
        from_tid: felt252,
        contract_build_address: ContractAddress,
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

    fn mint_build (
        self: @TContractState,
        from_tid: felt252,
        contract_build_address: ContractAddress,
        contract_voxel_address: ContractAddress,
    );
}

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use integer::u256_from_felt252;
    use dojo_ars::utils::{util_mint_voxel_by_checks, util_mint_build};
    use super::IActions;
    use dojo_ars::models::{LastCheck};
    use dojo_ars::utils::{ICalleeVoxel1155Dispatcher, ICalleeVoxel1155DispatcherTrait};
    use dojo_ars::utils::{ICalleeCore1155Dispatcher, ICalleeCore1155DispatcherTrait};

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
        fn mint_voxel_by_checks(
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
            util_mint_voxel_by_checks(
                world,
                contract_voxel_address,
                contract_core_address,
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                t721id,
                remove_block,
                r,
                s,
            )
        }

        fn mint_build_with_checks(
            self: @ContractState,
            from_tid: felt252,
            contract_build_address: ContractAddress,
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
            util_mint_voxel_by_checks(
                world,
                contract_voxel_address,
                contract_core_address,
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                t721id,
                remove_block,
                r,
                s,
            );

            util_mint_build(world, contract_build_address, contract_voxel_address, from_tid)
        }

        fn mint_build (
            self: @ContractState,
            from_tid: felt252,
            contract_build_address: ContractAddress,
            contract_voxel_address: ContractAddress,
        ) {
            let world = self.world_dispatcher.read();
            
            util_mint_build(world, contract_build_address, contract_voxel_address, from_tid)
        }
    }
}

