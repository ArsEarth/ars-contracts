use starknet::ContractAddress;
use super::list::StoreFelt252Array;
use dict::Felt252DictTrait;

#[starknet::interface]
trait ICalleeVoxel1155<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        id: u256,
        amount: u256,
    );

    fn burn_batch(
        ref self: TContractState,
        from: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>
    );
}

#[starknet::interface]
trait ICalleeCore1155<TContractState> {
    fn mint(
        ref self: TContractState,
        to: ContractAddress,
        id: u256,
        amount: u256,
    );
}

#[derive(Drop, Serde, starknet::Store)]
struct BuildInfo {
    H: u64,
    S: u64,
    B: u64,
    size: u64,
    root: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct RYBWK {
    R: u64,
    Y: u64,
    B: u64,
    W: u64,
    K: u64,
}

#[starknet::interface]
trait ICalleeErc721<TContractState> {
    fn mint_and_publish(
        ref self: TContractState, 
        recipient: ContractAddress,
        buildData: BuildInfo,
    )->u256;
}

#[starknet::interface]
trait System<TContractState> {
    fn last_check(self: @TContractState, t_id: u256, address: ContractAddress) -> u256;
    fn calcRYBWKByHSB(self: @TContractState, H: u64, S: u64, B:u64) -> RYBWK;
    fn checkBlockVoxelMap(self: @TContractState, b_id: felt252) -> u256;
    fn checkamount(self: @TContractState, buildData: BuildInfo, block_ids: Array<felt252>, amounts: Array<u64>) -> (Array<u256>, Array<u256>);

    fn mul_mint_from_checks(
        ref self: TContractState,
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

    fn mint_build(
        ref self: TContractState,
        contract_voxel_address: ContractAddress, 
        contract_core_address: ContractAddress,
        contract_721_address: ContractAddress, 
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
        buildData: BuildInfo, 
        block_ids: Array<felt252>, 
        amounts: Array<u64>,
    );

}

#[starknet::contract]
mod system {
    use option::OptionTrait;
    use clone::Clone;
    use array::SpanTrait;
    use array::ArrayTrait;
    use array::ArrayTCloneImpl;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::contract_address_const;
    use starknet::contract_address_to_felt252;
    use ecdsa::check_ecdsa_signature;
    use integer::u256_from_felt252;
    use integer::U64IntoU256;
    use integer::U256TryIntoU64;
    use traits::{Into, TryInto, DivRem};

    use super::{ICalleeVoxel1155Dispatcher, ICalleeVoxel1155DispatcherTrait};
    use super::{ICalleeCore1155Dispatcher, ICalleeCore1155DispatcherTrait};
    use super::{ICalleeErc721Dispatcher, ICalleeErc721DispatcherTrait};
    use super::{BuildInfo};
    use super::{RYBWK};

    #[storage]
    struct Storage {
        _lastCheckId: LegacyMap::<(u256, ContractAddress), u256>,
        _blockVoxelMap: LegacyMap::<felt252, u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState
    ) {
        self._set_blockVoxelMap(9, 9);
        self._set_blockVoxelMap(10, 10);
        self._set_blockVoxelMap(11, 11);
    }

    #[external(v0)]
    impl Systemimpl of super::System<ContractState> {
        fn last_check(self: @ContractState, t_id: u256, address: ContractAddress) -> u256 {
            let last_id = self._lastCheckId.read((t_id, address));
            last_id
        }

        fn calcRYBWKByHSB(self: @ContractState, H: u64, S: u64, B:u64) -> RYBWK {
            self._calcRYBWKByHSB(H, S, B)
        }

        fn checkBlockVoxelMap(self: @ContractState, b_id: felt252) -> u256 {
            self._blockVoxelMap.read(b_id)
        }
        
        fn checkamount(self: @ContractState, buildData: BuildInfo, block_ids: Array<felt252>, amounts: Array<u64>) -> (Array<u256>, Array<u256>) {
            let mut i: usize = 0;

            let bc: BuildInfo = buildData;
            let mut voxel_ids: Array<u256> = ArrayTrait::new();
            let mut burn_amounts: Array<u256> = ArrayTrait::new();
            let multiple: u64 = buildData.size * buildData.size * buildData.size;
            let _block_ids = block_ids.clone();
            let _amounts = amounts.clone();
            let mut total_amount: u256 = 0;
            loop {
                if i >= _block_ids.len() {
                    break;
                }

                voxel_ids.append(self._blockVoxelMap.read(*_block_ids.at(i)));
                burn_amounts.append(U64IntoU256::into(*_amounts.at(i) * multiple));
                total_amount = total_amount + U64IntoU256::into(*_amounts.at(i));
                i += 1;
            };

            let clr = self._calcRYBWKByHSB(buildData.H, buildData.S, buildData.B);
            voxel_ids.append(35);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.R));
            voxel_ids.append(36);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.Y));
            voxel_ids.append(37);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.B));
            voxel_ids.append(38);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.W));
            voxel_ids.append(39);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.K));
            (voxel_ids, burn_amounts)
        }

        fn mul_mint_from_checks(
            ref self: ContractState,
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
            self._mul_mint_from_checks(contract_voxel_address, contract_core_address, public_key, issuer, receiver, tid, startid, endid, amt, t721id, remove_block, r, s);
        }

        fn mint_build(
            ref self: ContractState, 
            contract_voxel_address: ContractAddress,
            contract_core_address: ContractAddress,
            contract_721_address: ContractAddress, 
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
            buildData: BuildInfo,
            block_ids: Array<felt252>, 
            amounts: Array<u64>,
        ) {
            assert(block_ids.len() == amounts.len(), 'data error');
            self._mul_mint_from_checks(contract_voxel_address, contract_core_address, public_key, issuer, receiver, tid, startid, endid, amt, t721id, remove_block, r, s);

            let mut i: usize = 0;

            let bc: BuildInfo = buildData;
            let mut voxel_ids: Array<u256> = ArrayTrait::new();
            let mut burn_amounts: Array<u256> = ArrayTrait::new();
            let multiple: u64 = buildData.size * buildData.size * buildData.size;
            let _block_ids = block_ids.clone();
            let _amounts = amounts.clone();
            let mut total_amount: u256 = 0;
            loop {
                if i >= _block_ids.len() {
                    break;
                }

                voxel_ids.append(self._blockVoxelMap.read(*_block_ids.at(i)));
                burn_amounts.append(U64IntoU256::into(*_amounts.at(i) * multiple));
                total_amount = total_amount + U64IntoU256::into(*_amounts.at(i));
                i += 1;
            };

            let clr = self._calcRYBWKByHSB(buildData.H, buildData.S, buildData.B);
            voxel_ids.append(35);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.R));
            voxel_ids.append(36);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.Y));
            voxel_ids.append(37);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.B));
            voxel_ids.append(38);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.W));
            voxel_ids.append(39);
            burn_amounts.append(total_amount * U64IntoU256::into(clr.K));

            ICalleeVoxel1155Dispatcher { contract_address: contract_voxel_address }.burn_batch(get_caller_address(), voxel_ids, burn_amounts);
            let token_id = ICalleeErc721Dispatcher { contract_address: contract_721_address }.mint_and_publish(get_caller_address(), buildData);
        }

    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn _verifySign(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: felt252,
            starkid: felt252,
            endid: felt252,
            amt: felt252,
            t721id: felt252,
            remove_block: felt252,
            r: felt252,
            s: felt252
        ) -> felt252 {
            let tokenid = u256_from_felt252(tid);
            let thischecksid = u256_from_felt252(starkid);
            let lastId = self._lastCheckId.read((tokenid, receiver));
            assert(lastId + 1 == thischecksid, 'CHECKS ID NOT VALID');
            let message_hash = pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(pedersen::pedersen(issuer, contract_address_to_felt252(receiver)), tid), starkid), endid), amt), t721id), remove_block);
            assert(
                check_ecdsa_signature(
                    message_hash: message_hash,
                    public_key: public_key,
                    signature_r: r,
                    signature_s: s,
                ),
                'INVALID_SIGNATURE',
            );
            starknet::VALIDATED
        }
        
        fn _mul_mint_from_checks(
            ref self: ContractState,
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

                assert(self._verifySign(public_key, issuer, receiver, *_tid.at(i), *_startid.at(i), *_endid.at(i), *_amt.at(i), *_t721id.at(i), *_rblock.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

                let tokenid = u256_from_felt252(*_tid.at(i));
                let endchecksid = u256_from_felt252(*_endid.at(i));
                let amount = u256_from_felt252(*_amt.at(i));
                if tokenid == 10001 || tokenid == 10002 {
                    ICalleeCore1155Dispatcher { contract_address: contract_core_address }.mint(receiver, tokenid, amount);
                } else {
                    ICalleeVoxel1155Dispatcher { contract_address: contract_voxel_address }.mint(receiver, tokenid, amount);
                }
                self._lastCheckId.write((tokenid, receiver), endchecksid);
                i += 1;
            };
        }

        fn _calcRYBWKByHSB(
            self: @ContractState, H: u64, S: u64, B:u64
        ) -> RYBWK {
            let mut clr = RYBWK{
                R: 0,
                Y: 0,
                B: 0,
                W: 0,
                K: 0,
            };

            if H <= 30 {
                clr.R = 6;
                clr.Y = 0;
                clr.B = 0;
            } else if H <= 60 {
                clr.R = 4;
                clr.Y = 2;
                clr.B = 0;
            } else if H <= 90 {
                clr.R = 3;
                clr.Y = 3;
                clr.B = 0;
            } else if H <= 120 {
                clr.R = 2;
                clr.Y = 4;
                clr.B = 0;
            } else if H <= 150 {
                clr.R = 0;
                clr.Y = 6;
                clr.B = 0;
            } else if H <= 180 {
                clr.R = 0;
                clr.Y = 4;
                clr.B = 2;
            } else if H <= 210 {
                clr.R = 0;
                clr.Y = 3;
                clr.B = 3;
            } else if H <= 240 {
                clr.R = 0;
                clr.Y = 2;
                clr.B = 4;
            } else if H <= 270 {
                clr.R = 0;
                clr.Y = 0;
                clr.B = 6;
            } else if H <= 300 {
                clr.R = 2;
                clr.Y = 0;
                clr.B = 4;
            } else if H <= 330 {
                clr.R = 3;
                clr.Y = 0;
                clr.B = 3;
            } else {
                clr.R = 4;
                clr.Y = 0;
                clr.B = 2;
            }

            let mut s: u64 = 0;
            if S <= 14 {
                s = 6;
            } else if S <= 29 {
                s = 5;
            } else if S <= 43 {
                s = 4;
            } else if S <= 57 {
                s = 3;
            } else if S <= 72 {
                s = 2;
            } else if S <= 86 {
                s = 1;
            }

            if B <= 14 {
                clr.W = 0;
                clr.K = 6;
            } else if B <= 29 {
                clr.W = 1;
                clr.K = 5;
            } else if B <= 43 {
                clr.W = 2;
                clr.K = 4;
            } else if B <= 57 {
                clr.W = 3;
                clr.K = 3;
            } else if B <= 72 {
                clr.W = 4;
                clr.K = 2;
            } else if B <= 86 {
                clr.W = 5;
                clr.K = 1;
            } else {
                clr.W = 6;
                clr.K = 0;
            }

            if clr.R == 0 {
                clr.R = s;
            }
            if clr.Y == 0 {
                clr.Y = s;
            }
            if clr.B == 0 {
                clr.B = s;
            }

            clr
        }

        fn _set_blockVoxelMap(ref self: ContractState, block_id: felt252, voxel_id: u256) {
            self._blockVoxelMap.write(block_id, voxel_id);
        }
    }
}