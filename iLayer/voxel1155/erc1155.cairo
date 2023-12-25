use starknet::ContractAddress;

#[starknet::interface]
trait IERC1155<TContractState> {
    fn owner_of(self: @TContractState) -> ContractAddress;
    fn balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;
    fn account_balances_of(self: @TContractState, account: ContractAddress, ids: Array<u256>) -> Array<u256>;
    fn balance_of_batch(self: @TContractState, accounts: Array<ContractAddress>, ids: Array<u256>) -> Array<u256>;
    fn is_approved_for_all(self: @TContractState, account: ContractAddress, operator: ContractAddress) -> bool;
    fn last_checks(self: @TContractState, account: ContractAddress, tid: u256) -> u256;
    
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

    fn set_uri(
        ref self: TContractState,
        uri: felt252
    );
    fn set_owner(
        ref self: TContractState,
        owner: ContractAddress
    );
    fn set_whitelist(
        ref self: TContractState,
        address: ContractAddress
    );
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
    
    #[storage]
    struct Storage {
        _owner: ContractAddress,
        _uri: felt252,
        _balances: LegacyMap::<(u256, ContractAddress), u256>,
        _operator_approvals: LegacyMap::<(ContractAddress, ContractAddress), bool>,
        _lastCheckId: LegacyMap::<(u256, ContractAddress), u256>,
        _whitelistMap:LegacyMap::<ContractAddress, u8>,
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
            balancesNumber
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

        fn set_whitelist(ref self: ContractState, address: ContractAddress) {
            let owner = self._owner.read();
            assert(owner == get_caller_address(), 'not owner');
            self._set_whitelist(address);
        }

        fn mint(
            ref self: ContractState,
            to: ContractAddress,
            id: u256,
            amount: u256,
        ) {
            let caller = get_caller_address();
            assert(self._whitelistMap.read(caller) == 1, 'not in whitelist');
            
            self._mint(to, id, amount, ArrayTrait::new().span());
        }

        fn burn_batch(
            ref self: ContractState,
            from: ContractAddress,
            ids: Array<u256>,
            amounts: Array<u256>
        ) {
            let caller = get_caller_address();
            assert(self._whitelistMap.read(caller) == 1, 'not in whitelist');

            self._burn_batch(from, ids, amounts);
        }

    }

    #[external(v0)]
    fn uri(self: @ContractState) -> felt252 {
        self._uri.read()
    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
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

        fn _set_whitelist(ref self: ContractState, address: ContractAddress) {
            self._whitelistMap.write(address, 1);
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