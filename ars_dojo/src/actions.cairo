use starknet::ContractAddress;


// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn init_checks(
        self: @TContractState,
        receiver: ContractAddress,
        tid: Array<felt252>,
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

    fn mint_build_with_checks_v1(
        self: @TContractState,
        from_tid: u256,
        from_contract: ContractAddress,
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
    fn mint_build_v1 (
        self: @TContractState,
        from_tid: u256,
        from_contract: ContractAddress,
    );
}

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use integer::u256_from_felt252;
    use dojo_ars::utils::{util_mint_voxel_by_checks, util_mint_build, util_mint_voxel_by_checks_v1, util_mint_build_v1, debug_init_checks};
    use super::IActions;
    use dojo_ars::models::{LastCheck};
    use dojo_ars::utils::{ICalleeVoxel1155Dispatcher, ICalleeVoxel1155DispatcherTrait};
    use dojo_ars::utils::{ICalleeCore1155Dispatcher, ICalleeCore1155DispatcherTrait};
    use dojo_ars::world_config::{AdminTrait};

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn init_checks(
            self: @ContractState,
            receiver: ContractAddress,
            tid: Array<felt252>,
        ) {
            let world = self.world_dispatcher.read();
            world.only_admins(@get_caller_address());
            debug_init_checks(world, receiver, tid);
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

        fn mint_build_with_checks_v1(
            self: @ContractState,
            from_tid: u256,
            from_contract: ContractAddress,
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
            util_mint_voxel_by_checks_v1(
                world,
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

            util_mint_build_v1(world, from_contract, from_tid)
        }

        fn mint_build_v1 (
            self: @ContractState,
            from_tid: u256,
            from_contract: ContractAddress,
        ) {
            let world = self.world_dispatcher.read();
            
            util_mint_build_v1(world, from_contract, from_tid)
        }
    }
}

