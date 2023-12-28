use starknet::ContractAddress;

#[starknet::interface]
trait ICallee<TContractState> {
    fn transfer_test(self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256);
}

#[starknet::interface]
trait IERC1155<TContractState> {
    fn owner_of(self: @TContractState) -> ContractAddress;
    fn balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;
    fn balance_of_synthesis(self: @TContractState, account: ContractAddress, id: u256) -> Array<u256>;
    fn account_balances_of(self: @TContractState, account: ContractAddress, ids: Array<u256>) -> Array<u256>;
    fn balance_of_batch(self: @TContractState, accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256>;
    fn is_approved_for_all(self: @TContractState, account: ContractAddress, operator: ContractAddress) -> bool;
    fn last_checks(self: @TContractState, account: ContractAddress, tid: u256) -> u256;
    fn synthesis_map(self: @TContractState, fromTid: u256, toTid: u256) -> u256;

    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    // Span<felt252> here is for bytes in Solidity
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
        data: Span<felt252>
    );
    fn safe_batch_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Array<u256>,
        amounts: Array<u256>,
        data: Span<felt252>
    );
    fn set_synthesisMap(
        ref self: TContractState,
        fromTid: u256,
        toTid: u256,
        uniteNum: u256
    );
    fn set_uri(
        ref self: TContractState,
        uri: felt252
    );
    fn set_owner(
        ref self: TContractState,
        owner: ContractAddress
    );
    fn validate_sign(
        ref self: TContractState,
        message_hash: felt252,
        r: felt252,
        s: felt252
    ) -> felt252;
    fn mint(
        ref self: TContractState,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: felt252,
        startid: felt252,
        endid: felt252,
        amt: felt252,
        r: felt252,
        s: felt252,
    );

    fn mulMint(
        ref self: TContractState,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: Array<felt252>,
        startid: Array<felt252>,
        endid: Array<felt252>,
        amt: Array<felt252>,
        r: Array<felt252>,
        s: Array<felt252>,
    );

    fn synthesis_with_one_check(
        ref self: TContractState,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: felt252,
        startid: felt252,
        endid: felt252,
        amt: felt252,
        r: felt252,
        s: felt252,
        fromTid: u256,
        toTid: u256,
        number: u256,
    );

    fn synthesis_with_checks(
        ref self: TContractState,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: Array<felt252>,
        startid: Array<felt252>,
        endid: Array<felt252>,
        amt: Array<felt252>,
        r: Array<felt252>,
        s: Array<felt252>,
        fromTid: u256,
        toTid: u256,
        number: u256,
    );

    fn synthesis(
        ref self: TContractState,
        fromTid: u256,
        toTid: u256,
        number: u256,
    );

    fn erc20_transfer(ref self: TContractState, call_contract_address: ContractAddress, sender: ContractAddress, recipient: ContractAddress, amount: u256);
}

#[starknet::contract]
mod erc_1155 {
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

    use super::super::erc1155_receiver::ERC1155Receiver;
    use super::super::erc1155_receiver::ERC1155ReceiverTrait;
    use super::{ICalleeDispatcher, ICalleeDispatcherTrait};
    
    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _uri: felt252,
        _balances: LegacyMap::<(u256, ContractAddress), u256>,
        _operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        _lastCheckId: LegacyMap::<(u256, ContractAddress), u256>,
        _synthesisMap: LegacyMap::<(u256, u256), u256>,
        _synthesisStartNumber: LegacyMap::<(u256, ContractAddress), u256>,
        _synthesisStartTime:LegacyMap::<(u256, ContractAddress), u64>,
        _synthesisEndTime:LegacyMap::<ContractAddress, u64>,
        _synthesisInterval: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransferSingle: TransferSingle,
        TransferBatch: TransferBatch,
        ApprovalForAll: ApprovalForAll,
        URI: URI,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferSingle {
        #[key]
        operator: ContractAddress,
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        id: u256,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TransferBatch {
        #[key]
        operator: ContractAddress,
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        ids: Array<u256>,
        values: Array<u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        account: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct URI {
        value: felt252,
        id: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        uri_: felt252
    ) {
        self._set_uri(uri_);
        self._set_owner(owner);
        self._set_synthesisInterval(30);
        self._set_synthesisMap(4, 12, 1352);
        self._set_synthesisMap(4, 13, 1352);
        self._set_synthesisMap(4, 14, 968);
        self._set_synthesisMap(4, 15, 160);
        self._set_synthesisMap(4, 16, 156);
        self._set_synthesisMap(4, 17, 296);
        self._set_synthesisMap(4, 18, 296);

        self._set_synthesisMap(7, 19, 1352);
        self._set_synthesisMap(7, 20, 1352);
        self._set_synthesisMap(7, 21, 968);
        self._set_synthesisMap(7, 22, 160);
        self._set_synthesisMap(7, 23, 156);
        self._set_synthesisMap(7, 24, 296);
        self._set_synthesisMap(7, 25, 296);

        self._set_synthesisMap(11, 26, 1352);
        self._set_synthesisMap(11, 27, 1352);
        self._set_synthesisMap(11, 28, 36);
        self._set_synthesisMap(11, 29, 32);
        self._set_synthesisMap(11, 30, 520);
        self._set_synthesisMap(11, 31, 296);

        self._set_synthesisMap(10, 401, 1352);
        self._set_synthesisMap(10, 501, 296);
        self._set_synthesisMap(9, 34, 512);
    }

    #[external(v0)]
    impl IERC1155impl of super::IERC1155<ContractState> {
        fn owner_of(self: @ContractState) -> ContractAddress {
            let owner = self._owner.read();
            owner
        }

        fn balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
            assert(!account.is_zero(), 'query for the zero address');
            let balancesNumber = self._balances.read((id, account));
            let synthesisNumber = self._synthesisStartNumber.read((id, account));
            let mut synthesisingNumber: u256 = 0;
            if synthesisNumber > 0 {
                let synthesisTime = self._synthesisStartTime.read((id, account));
                let timeIntevalNumber = U64IntoU256::into((get_block_timestamp() - synthesisTime) / self._synthesisInterval.read());
                if timeIntevalNumber < synthesisNumber {
                    synthesisingNumber = synthesisNumber - timeIntevalNumber;
                } 
            }
            
            balancesNumber - synthesisingNumber
        }

        fn balance_of_synthesis(self: @ContractState, account: ContractAddress, id: u256) -> Array<u256> {
            assert(!account.is_zero(), 'query for the zero address');
            let mut synthesis_data = ArrayTrait::new();
            
            let synthesisNumber = self._synthesisStartNumber.read((id, account));
            let mut synthesisingNumber: u256 = 0;
            if synthesisNumber > 0 {
                synthesis_data.append(synthesisNumber);
                
                let synthesisEndTime = self._synthesisEndTime.read(account);
                let currentTime = get_block_timestamp();
                if currentTime < synthesisEndTime {
                    let timeIntevalNumber = U64IntoU256::into((currentTime - self._synthesisStartTime.read((id, account))) / self._synthesisInterval.read());
                    synthesis_data.append(timeIntevalNumber);
                    synthesis_data.append(U64IntoU256::into(synthesisEndTime - currentTime));
                } else {
                    synthesis_data.append(synthesisNumber);
                    synthesis_data.append(0);
                }
            }
            
            synthesis_data
        }

        fn account_balances_of(self: @ContractState, account: ContractAddress, ids: Array<u256>) -> Array<u256> {
            assert(!account.is_zero(), 'query for the zero address');
            let mut batch_balances = ArrayTrait::new();

            let mut i: usize = 0;
            loop {
                if i >= ids.len() {
                    break;
                }
                batch_balances.append(IERC1155impl::balance_of(self, account, *ids.at(i)));
                i += 1;
            };

            batch_balances
        }

        fn balance_of_batch(self: @ContractState, accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256> {
            assert(accounts.len() == ids.len(), 'accounts and ids len mismatch');
            let mut batch_balances = ArrayTrait::new();

            let mut i: usize = 0;
            loop {
                if i >= accounts.len() {
                    break;
                }
                batch_balances.append(IERC1155impl::balance_of(self, *accounts.at(i), *ids.at(i)));
                i += 1;
            };

            batch_balances
        }

        fn is_approved_for_all(self: @ContractState, account: ContractAddress, operator: ContractAddress) -> bool {
            self._operator_approvals.read((account, operator))
        }
        fn last_checks(self: @ContractState,  account: ContractAddress, tid: u256) -> u256 {
            assert(!account.is_zero(), 'query for the zero address');
            self._lastCheckId.read((tid, account))
        }
        fn synthesis_map(self: @ContractState, fromTid: u256, toTid: u256) -> u256 {
            self._synthesisMap.read((fromTid, toTid))
        }

        fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
            self._set_approval_for_All(get_caller_address(), operator, approved)
        }
        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            amount: u256,
            data: Span<felt252>
        ) {
            assert((from == get_caller_address()) | (IERC1155impl::is_approved_for_all(@self, from, get_caller_address())),
                 'caller is not owner | approved');
            self._safe_transfer_from(from, to, id, amount, data);
        }
        fn safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>,
            data: Span<felt252>
        ) {
            assert(
                (from == get_caller_address()) | (IERC1155impl::is_approved_for_all(@self, from, get_caller_address())), 
                'caller is not owner | approved');
            self._safe_batch_transfer_from(from, to, ids, amounts, data);
        }

        fn set_synthesisMap(ref self: ContractState, fromTid: u256, toTid: u256, uniteNum: u256) {
            let owner = self._owner.read();
            assert(owner == get_caller_address(), 'not owner');
            self._set_synthesisMap(fromTid, toTid, uniteNum);
        }

        fn set_uri(ref self: ContractState, uri: felt252) {
            let owner = self._owner.read();
            assert(owner == get_caller_address(), 'not owner');
            self._set_uri(uri);
        }

        fn set_owner(ref self: ContractState, owner: ContractAddress) {
            let owner = self._owner.read();
            assert(owner == get_caller_address(), 'not owner');
            self._set_owner(owner);
        }

        fn validate_sign(
            ref self: ContractState,
            message_hash: felt252,
            r: felt252,
            s: felt252
        ) -> felt252 {
            assert(starknet::get_caller_address().is_zero(), 'INVALID_CALLER');
            // Verify ECDSA signature
            assert(
                check_ecdsa_signature(
                    message_hash: message_hash,
                    public_key: starknet::contract_address_to_felt252(starknet::get_caller_address()),
                    signature_r: r,
                    signature_s: s,
                ),
                'INVALID_SIGNATURE',
            );

            starknet::VALIDATED // Return validation status
        }

        fn mint(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: felt252,
            startid: felt252,
            endid: felt252,
            amt: felt252,
            r: felt252,
            s: felt252,
        ) {
            self._mint_from_checks(
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                r,
                s,
            );
        }

        fn mulMint(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: Array<felt252>,
            startid: Array<felt252>,
            endid: Array<felt252>,
            amt: Array<felt252>,
            r: Array<felt252>,
            s: Array<felt252>,
        ) {
            self._mul_mint_from_checks(
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                r,
                s,
            );
        }

        fn synthesis_with_one_check(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: felt252,
            startid: felt252,
            endid: felt252,
            amt: felt252,
            r: felt252,
            s: felt252,
            fromTid: u256,
            toTid: u256,
            number: u256,
        ) {
            let uniteNum = self._verify_synthesis(fromTid, toTid);
            
            self._mint_from_checks(
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                r,
                s,
            );

            self._synthesis(fromTid, uniteNum, number, toTid);
        }

        fn synthesis_with_checks(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: Array<felt252>,
            startid: Array<felt252>,
            endid: Array<felt252>,
            amt: Array<felt252>,
            r: Array<felt252>,
            s: Array<felt252>,
            fromTid: u256,
            toTid: u256,
            number: u256,
        ) {
            let uniteNum = self._verify_synthesis(fromTid, toTid);

            self._mul_mint_from_checks(
                public_key,
                issuer,
                receiver,
                tid,
                startid,
                endid,
                amt,
                r,
                s,
            );

            self._synthesis(fromTid, uniteNum, number, toTid);
        }

        fn synthesis(
            ref self: ContractState,
            fromTid: u256,
            toTid: u256,
            number: u256,
        ) {
            let uniteNum = self._verify_synthesis(fromTid, toTid);

            self._synthesis(fromTid, uniteNum, number, toTid);
        }

        fn erc20_transfer(ref self: ContractState, call_contract_address: ContractAddress, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            ICalleeDispatcher { contract_address: call_contract_address }.transfer_test(sender, recipient, amount);
        }

    }

    #[external(v0)]
    fn uri(self: @ContractState) -> felt252 {
        self._uri.read()
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
            r: felt252,
            s: felt252
        ) -> felt252 {
            let tokenid = u256_from_felt252(tid);
            let thischecksid = u256_from_felt252(starkid);
            let lastId = self._lastCheckId.read((tokenid, receiver));
            assert(lastId + 1 == thischecksid, 'CHECKS ID NOT VALID');
            let message_hash = pedersen(pedersen(pedersen(pedersen(pedersen(issuer, contract_address_to_felt252(receiver)), tid), starkid), endid), amt);
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

        fn _mint(
            ref self: ContractState,
            to: ContractAddress,
            id: u256,
            amount: u256,
            data: Span<felt252>
        ) {
            assert(!to.is_zero(), 'mint to the zero address');
            let operator = get_caller_address();
            self._beforeTokenTransfer(
                operator,
                contract_address_const::<0>(),
                to,
                self._as_singleton_array(id),
                self._as_singleton_array(amount),
                data.clone()
            );
            self._balances.write((id, to), self._balances.read((id, to)) + amount);
            self.emit(Event::TransferSingle(
                TransferSingle {
                    operator,
                    from: contract_address_const::<0>(),
                    to,
                    id,
                    value: amount
                }
            ));
            self._do_safe_transfer_acceptance_check(operator, contract_address_const::<0>(), to, id, amount, data.clone());
        }

        fn _mint_batch(
            ref self: ContractState,
            to: ContractAddress, 
            ids: Array<u256>, 
            amounts: Array<u256>, 
            data: Span<felt252>
        ) {
            assert(!to.is_zero(), 'mint to the zero address');
            assert(ids.len() == amounts.len(), 'length mismatch');

            let operator = get_caller_address();
            self._beforeTokenTransfer(
                operator, 
                contract_address_const::<0>(),
                to,
                ids.clone(),
                amounts.clone(),
                data.clone()
            );

            let mut i: usize = 0;

            let _ids = ids.clone();
            let _amounts = amounts.clone();
            loop {
                if i >= _ids.len() {
                    break;
                }

                self._balances.write((*_ids.at(i), to), 
                    self._balances.read((*_ids.at(i), to)) + *_amounts.at(i));

                i += 1;
            };

            let _ids = ids.clone();
            let _amounts = amounts.clone();
            self.emit(Event::TransferBatch(
                TransferBatch {
                    operator,
                    from: contract_address_const::<0>(),
                    to: contract_address_const::<0>(),
                    ids: _ids,
                    values: _amounts
                }
            ));

            self._do_safe_batch_transfer_acceptance_check(
                operator, 
                contract_address_const::<0>(), 
                to, 
                ids.clone(), 
                amounts.clone(), 
                data.clone()
            );
        }

        fn _burn(ref self: ContractState, from: ContractAddress, id: u256, amount: u256) {
            assert(!from.is_zero(), 'burn from the zero address');
            let operator = get_caller_address();
            self._beforeTokenTransfer(
                operator, 
                from, 
                contract_address_const::<0>(),
                self._as_singleton_array(id),
                self._as_singleton_array(amount),
                ArrayTrait::<felt252>::new().span()
            );

            let from_balance = self._balances.read((id, from));
            assert(from_balance >= amount, 'burn amount exceeds balance');
            self._balances.write((id, from), from_balance - amount);
            self.emit(Event::TransferSingle(
                TransferSingle {
                    operator,
                    from,
                    to: contract_address_const::<0>(),
                    id,
                    value: amount
                }
            ));
        }

        fn _burn_batch(ref self: ContractState, from: ContractAddress, ids: Array<u256>, amounts: Array<u256>) {
            assert(!from.is_zero(), 'burn from the zero address');
            assert(ids.len() == amounts.len(), 'ids and amounts length mismatch');

            let operator = get_caller_address();
            self._beforeTokenTransfer(
                operator, 
                from, 
                contract_address_const::<0>(),
                ids.clone(), 
                amounts.clone(), 
                ArrayTrait::<felt252>::new().span()
            );

            let mut i: usize = 0;
            let _ids = ids.clone();
            let _amounts = amounts.clone();
            loop {
                if i >= _ids.len() {
                    break;
                }
                let id = *_ids.at(i);
                let amount = *_amounts.at(i);

                let from_balance = self._balances.read((id, from));
                assert(from_balance >= amount, 'burn amount exceeds balance');
                self._balances.write((id, from), from_balance - amount);

                i += 1;
            };
            self.emit(Event::TransferBatch(
                TransferBatch {
                    operator,
                    from,
                    to: contract_address_const::<0>(),
                    ids,
                    values: amounts
                }
            ));
        }

        fn _safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            amount: u256,
            data: Span<felt252>
        ) {
            assert(!to.is_zero(), 'transfer to the zero address');
            let operator = get_caller_address();
            self._beforeTokenTransfer(
                operator,
                from,
                to,
                self._as_singleton_array(id),
                self._as_singleton_array(amount),
                data.clone()
            );
            let from_balance = self._balances.read((id, from));
            assert(from_balance >= amount, 'insufficient balance');
            self._balances.write((id, from), from_balance - amount);
            self._balances.write((id, to), self._balances.read((id, to)) + amount);
            self.emit(Event::TransferSingle(
                TransferSingle {
                    operator,
                    from,
                    to,
                    id,
                    value: amount
                }
            ));
            self._do_safe_transfer_acceptance_check(operator, from, to, id, amount, data.clone());
        }

        fn _safe_batch_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>,
            data: Span<felt252>
        ) {
            assert(ids.len() == amounts.len(), 'length mismatch');
            assert(!to.is_zero(), 'transfer to the zero address');

            let operator = get_caller_address();
            self._beforeTokenTransfer(operator, from, to, ids.clone(), amounts.clone(), data.clone());

            let _ids = ids.clone();
            let _amounts = amounts.clone();
            let mut i: usize = 0;
            loop {
                if i >= _ids.len() {
                    break;
                }

                let id = *_ids.at(i);
                let amount = *_amounts.at(i);

                let from_balance = self._balances.read((id, from));
                assert(from_balance >= amount, 'insufficient balance');
                self._balances.write((id, from), from_balance - amount);
                self._balances.write((id, to), self._balances.read((id, to)) + amount);

                i += 1;
            };

            let _ids = ids.clone();
            let _amounts = amounts.clone();
            self.emit(Event::TransferBatch(
                TransferBatch {
                    operator,
                    from,
                    to,
                    ids: _ids,
                    values: _amounts
                }
            ));

            self._do_safe_batch_transfer_acceptance_check(
                operator,
                from,
                to,
                ids,
                amounts,
                data.clone()
            )
        }

        fn _set_uri(ref self: ContractState, newuri: felt252) {
            self._uri.write(newuri);
        }

        fn _set_owner(ref self: ContractState, owner: ContractAddress) {
            self._owner.write(owner);
        }

        fn _set_synthesisInterval(ref self: ContractState, diff: u64) {
            self._synthesisInterval.write(diff);
        }

        fn _set_synthesisMap(ref self: ContractState, tid: u256, newTid: u256, uniteNum: u256) {
            self._synthesisMap.write((tid, newTid), uniteNum);
        }

        fn _set_synthesisStart(ref self: ContractState, tid: u256, address: ContractAddress, num: u256) {
            self._synthesisStartTime.write((tid, address), get_block_timestamp());
            self._synthesisStartNumber.write((tid, address), num);
            let num64: u64 = U256TryIntoU64::try_into(num).unwrap();
            self._synthesisEndTime.write(address, get_block_timestamp() + (self._synthesisInterval.read() * num64));
        }

        fn _set_approval_for_All(
            ref self: ContractState,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool,
        ) {
            assert(owner != operator, 'ERC1155: self approval');
            self._operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { account: owner, operator, approved });
        }

        fn _beforeTokenTransfer(
            ref self: ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>,
            data: Span<felt252>,
        ) {}

        fn _do_safe_transfer_acceptance_check(
            ref self: ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            amount: u256,
            data: Span<felt252>
        ) {
            ERC1155Receiver { contract_address: to }.
                on_erc1155_received(operator, from, id, amount, data);
        }

        fn _do_safe_batch_transfer_acceptance_check(
            ref self: ContractState,
            operator: ContractAddress,
            from: ContractAddress,
            to: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>,
            data: Span<felt252>
        ) {
            ERC1155Receiver { contract_address: to }.
                on_erc1155_batch_received(operator, from, ids, amounts, data);
        }

        fn _as_singleton_array(self: @ContractState, element: u256) -> Array<u256> {
            let mut args = ArrayTrait::new();
            args.append(element);
            args
        }

        fn _mint_from_checks(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: felt252,
            startid: felt252,
            endid: felt252,
            amt: felt252,
            r: felt252,
            s: felt252,
        ) {
            assert(self._verifySign(public_key, issuer, receiver, tid, startid, endid, amt, r, s) == starknet::VALIDATED, 'valid failed');
            let tokenid = u256_from_felt252(tid);
            let endchecksid = u256_from_felt252(endid);
            let amount = u256_from_felt252(amt);
            self._mint(receiver, tokenid, amount, ArrayTrait::new().span());
            self._lastCheckId.write((tokenid, receiver), endchecksid);
        }

        fn _mul_mint_from_checks(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: Array<felt252>,
            startid: Array<felt252>,
            endid: Array<felt252>,
            amt: Array<felt252>,
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
            loop {
                if i >= tid.len() {
                    break;
                }

                assert(self._verifySign(public_key, issuer, receiver, *_tid.at(i), *_startid.at(i), *_endid.at(i), *_amt.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

                let tokenid = u256_from_felt252(*_tid.at(i));
                let endchecksid = u256_from_felt252(*_endid.at(i));
                let amount = u256_from_felt252(*_amt.at(i));
                self._mint(receiver, tokenid, amount, ArrayTrait::new().span());
                self._lastCheckId.write((tokenid, receiver), endchecksid);
                i += 1;
            };
        }

        fn _synthesis(
            ref self: ContractState,
            fromTid: u256,
            uniteNum: u256,
            number: u256,
            toTid: u256,
        ) {
            let newNum = self._balances.read((fromTid, get_caller_address()));
            assert(newNum >= uniteNum * number, 'balance not enough');
            self._mint(get_caller_address(), toTid, number, ArrayTrait::new().span());
            self._burn(get_caller_address(), fromTid, uniteNum * number);
            self._set_synthesisStart(toTid, get_caller_address(), number);
        }

        fn _verify_synthesis (
            ref self: ContractState,
            fromTid: u256,
            toTid: u256,
        ) -> u256 {
            let uniteNum = self._synthesisMap.read((fromTid, toTid));
            assert(uniteNum > 0, 'data error');

            let synthesisEndTime = self._synthesisEndTime.read(get_caller_address());
            assert(synthesisEndTime < get_block_timestamp(), 'still synthesis');
            uniteNum
        }

    }
}