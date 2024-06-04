use starknet::ContractAddress;
use dojo_ars::utils::{PackedShapeItem, FTSpec};

// define the interface
#[starknet::interface]
trait IActions<TContractState> {
    fn init_checks(
        self: @TContractState,
        receiver: ContractAddress,
        tid: Array<felt252>,
    );

    fn mint_voxel_by_checks_v1(
        self: @TContractState,
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
    fn mint_new_core_with_checks (
        self: @TContractState,
        from_tid: u256,
        amount: u256,
        fts: Array<FTSpec>,
        shape: Array<PackedShapeItem>,
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
    fn mint_new_core (
        self: @TContractState,
        from_tid: u256,
        amount: u256,
        fts: Array<FTSpec>,
        shape: Array<PackedShapeItem>,
    );
    fn rebuild_core_with_checks (
        self: @TContractState,
        from_tid: u256,
        amount: u256,
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
    fn rebuild_core (
        self: @TContractState,
        from_tid: u256,
        amount: u256,
    );
}

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address};
    use integer::u256_from_felt252;
    use dojo_ars::utils::{PackedShapeItem, FTSpec};
    use dojo_ars::utils::{util_mint_voxel_by_checks_v1, util_mint_build_v1, debug_init_checks, mint_new_core, rebuild_core};
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

        fn mint_voxel_by_checks_v1(
            self: @ContractState,
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
            )
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

        fn mint_new_core_with_checks (
            self: @ContractState,
            from_tid: u256,
            amount: u256,
            fts: Array<FTSpec>,
            shape: Array<PackedShapeItem>,
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
            mint_new_core(world, from_tid, amount, fts, shape)
        }

        fn mint_new_core (
            self: @ContractState,
            from_tid: u256,
            amount: u256,
            fts: Array<FTSpec>,
            shape: Array<PackedShapeItem>,
        ) {
            let world = self.world_dispatcher.read();
            mint_new_core(world, from_tid, amount, fts, shape)
        }

        fn rebuild_core_with_checks (
            self: @ContractState,
            from_tid: u256,
            amount: u256,
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
            rebuild_core(world, from_tid, amount)
        }

        fn rebuild_core (
            self: @ContractState,
            from_tid: u256,
            amount: u256,
        ) {
            let world = self.world_dispatcher.read();
            rebuild_core(world, from_tid, amount)
        }
    }
}

