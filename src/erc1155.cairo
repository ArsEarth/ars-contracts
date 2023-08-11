use starknet::ContractAddress;


#[starknet::interface]
trait IERC1155<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;
    fn balance_of_batch(self: @TContractState, accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256>;
    fn is_approved_for_all(self: @TContractState, account: ContractAddress, operator: ContractAddress) -> bool;
    fn test_validate_sign(self: @TContractState, message_hash: felt252, public_key: felt252, r: felt252, s: felt252) -> felt252;
    fn test_pedersen1(self: @TContractState, a: felt252, b: ContractAddress) -> felt252;
    fn test_pedersen2(self: @TContractState, a: felt252, b: felt252, c: felt252) -> felt252;
    fn test_pedersen3(self: @TContractState, a: felt252, b: felt252, c: felt252, d: felt252) -> felt252;
    fn test_pedersen(self: @TContractState, a: felt252, b: felt252, c: felt252, d: felt252, e: felt252) -> felt252;

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
        checksid: felt252,
        amt: felt252,
        r: felt252,
        s: felt252,
    ) -> felt252;

    fn mulMint(
        ref self: TContractState,
        public_key: felt252,
        issuer: felt252,
        receiver: ContractAddress,
        tid: Array<felt252>,
        checksid: Array<felt252>,
        amt: Array<felt252>,
        r: Array<felt252>,
        s: Array<felt252>,
    ) -> felt252;
}

#[starknet::contract]
mod erc_1155 {
    use clone::Clone;
    use array::SpanTrait;
    use array::ArrayTrait;
    use array::ArrayTCloneImpl;
    use zeroable::Zeroable;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::contract_address_to_felt252;
    use ecdsa::check_ecdsa_signature;
    use integer::u256_from_felt252;

    use super::super::erc1155_receiver::ERC1155Receiver;
    use super::super::erc1155_receiver::ERC1155ReceiverTrait;
    
    #[storage]
    struct Storage {
        _uri: felt252,
        _balances: LegacyMap::<(u256, ContractAddress), u256>,
        _operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        _lastCheckId: LegacyMap::<(u256, ContractAddress), u256>,
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
        uri_: felt252
    ) {
        self._set_uri(uri_);
    }

    #[external(v0)]
    impl IERC1155impl of super::IERC1155<ContractState> {
        fn balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
            assert(!account.is_zero(), 'query for the zero address');
            self._balances.read((id, account))
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
        fn test_validate_sign(self: @ContractState, message_hash: felt252, public_key: felt252, r: felt252, s: felt252) -> felt252 {

            // Verify ECDSA signature
            assert(
                check_ecdsa_signature(
                    message_hash: message_hash,
                    public_key: public_key,
                    signature_r: r,
                    signature_s: s,
                ),
                'INVALID_SIGNATURE',
            );

            starknet::VALIDATED // Return validation status
        }
        fn test_pedersen1(self: @ContractState, a: felt252, b: ContractAddress) -> felt252 {
            pedersen(a, contract_address_to_felt252(b))
        }
        fn test_pedersen2(self: @ContractState, a: felt252, b: felt252, c: felt252) -> felt252 {
            pedersen(pedersen(a, b),c)
        }
        fn test_pedersen3(self: @ContractState, a: felt252, b: felt252, c: felt252, d: felt252) -> felt252 {
            pedersen(pedersen(pedersen(a, b),c),d)
        }
        fn test_pedersen(self: @ContractState, a: felt252, b: felt252, c: felt252, d: felt252, e: felt252) -> felt252 {
            pedersen(pedersen(pedersen(pedersen(a, b),c),d),e)
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
            checksid: felt252,
            amt: felt252,
            r: felt252,
            s: felt252,
        ) -> felt252 {
            assert(self._verifySign(public_key, issuer, receiver, tid, checksid, amt, r, s) == starknet::VALIDATED, 'valid failed');
            let tokenid = u256_from_felt252(tid);
            let thischecksid = u256_from_felt252(checksid);
            let amount = u256_from_felt252(amt);
            self._mint(receiver, tokenid, amount, ArrayTrait::new().span());
            self._lastCheckId.write((tokenid, receiver), thischecksid);
            starknet::VALIDATED // Return validation status
        }

        fn mulMint(
            ref self: ContractState,
            public_key: felt252,
            issuer: felt252,
            receiver: ContractAddress,
            tid: Array<felt252>,
            checksid: Array<felt252>,
            amt: Array<felt252>,
            r: Array<felt252>,
            s: Array<felt252>,
        ) -> felt252 {
            let mut i: usize = 0;

            let _tid = tid.clone();
            let _checksid = checksid.clone();
            let _amt = amt.clone();
            let _r = r.clone();
            let _s = s.clone();
            loop {
                if i >= tid.len() {
                    break;
                }

                assert(self._verifySign(public_key, issuer, receiver, *_tid.at(i), *_checksid.at(i), *_amt.at(i), *_r.at(i), *_s.at(i)) == starknet::VALIDATED, 'valid failed');

                let tokenid = u256_from_felt252(*_tid.at(i));
                let thischecksid = u256_from_felt252(*_checksid.at(i));
                let amount = u256_from_felt252(*_amt.at(i));
                self._mint(receiver, tokenid, amount, ArrayTrait::new().span());
                self._lastCheckId.write((tokenid, receiver), thischecksid);
                i += 1;
            };

            starknet::VALIDATED // Return validation status
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
            checksid: felt252,
            amt: felt252,
            r: felt252,
            s: felt252
        ) -> felt252 {
            let tokenid = u256_from_felt252(tid);
            let thischecksid = u256_from_felt252(checksid);
            let lastId = self._lastCheckId.read((tokenid, receiver));
            assert(lastId + 1 == thischecksid, 'CHECKS ID NOT VALID');
            let message_hash = pedersen(pedersen(pedersen(pedersen(issuer, contract_address_to_felt252(receiver)), tid), checksid), amt);
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
    }
}