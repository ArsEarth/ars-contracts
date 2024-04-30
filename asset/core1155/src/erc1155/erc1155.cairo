#[starknet::contract]
mod ERC1155 {
  use array::{ Span, ArrayTrait, SpanTrait, ArrayDrop, SpanSerde };
  use option::OptionTrait;
  use traits::{ Into, TryInto };
  use zeroable::Zeroable;
  use starknet::ContractAddress;
  use starknet::get_caller_address;
  use starknet::contract_address::ContractAddressZeroable;
  use integer::u256_from_felt252;
  use integer::u128_to_felt252;
  use core1155::introspection::src5::SRC5;
  use core1155::introspection::interface::{ ISRC5, ISRC5Camel };

  // Dispatchers
  use core1155::introspection::dual_src5::{ DualCaseSRC5, DualCaseSRC5Trait };
  use core1155::erc1155::dual_erc1155_receiver::{ DualCaseERC1155Receiver, DualCaseERC1155ReceiverTrait };

  // local
  use core1155::erc1155::interface;
  use core1155::erc1155::interface::IERC1155;
  use core1155::utils::storage::StoreSpanFelt252;
  use core1155::types::{ShapeItem, PackedShapeItem, FTSpec, ShapePacking, check_fts_and_shape_match};

    #[derive(Drop, Serde, starknet::Store)]
    struct CostData {
        base_block: u256,
        color_r: u256,
        color_g: u256,
        color_b: u256,
        core_id: u256,
    }

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _balances: LegacyMap<(u256, ContractAddress), u256>,
    _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
    _uri: Span<felt252>,
    _whitelistMap:LegacyMap::<ContractAddress, u8>,
    _owner: ContractAddress,
    _counter: u256,
    _costMap:LegacyMap::<u256, CostData>,
    _lastest_token_id:LegacyMap::<ContractAddress, u256>,
  }

  //
  // Events
  //

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
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    id: u256,
    value: u256,
  }

  #[derive(Drop, starknet::Event)]
  struct TransferBatch {
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    ids: Span<u256>,
    values: Span<u256>,
  }

  #[derive(Drop, starknet::Event)]
  struct ApprovalForAll {
    account: ContractAddress,
    operator: ContractAddress,
    approved: bool,
  }

  #[derive(Drop, starknet::Event)]
  struct URI {
    value: Span<felt252>,
    id: u256,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState, owner: ContractAddress, uri_: Span<felt252>) {
    self.initializer(uri_);
    self._set_owner(owner);
    self._set_counter(100000000);
  }
  // #[constructor]
  // fn constructor(ref self: ContractState) {
  //   self.initializer();
  // }

  //
  // IERC1155 impl
  //

  #[external(v0)]
  impl IERC1155Impl of interface::IERC1155<ContractState> {
    fn balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
      self._balances.read((id, account))
    }

    fn balance_of_batch(
      self: @ContractState,
      accounts: Span<ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
      assert(accounts.len() == ids.len(), 'ERC1155: bad accounts & ids len');

      let mut batch_balances = array![];

      let mut i: usize = 0;
      let len = accounts.len();
      loop {
        if (i >= len) {
          break ();
        }

        batch_balances.append(self.balance_of(*accounts.at(i), *ids.at(i)));
        i += 1;
      };

      batch_balances.span()
    }

    fn is_approved_for_all(
      self: @ContractState,
      account: ContractAddress,
      operator: ContractAddress
    ) -> bool {
      self._operator_approvals.read((account, operator))
    }

    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
      let caller = starknet::get_caller_address();

      self._set_approval_for_all(caller, operator, approved);
    }

    fn safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(account: from, operator: caller),
        'ERC1155: caller not allowed'
      );

      self._safe_transfer_from(from, to, id, amount, data);
    }

    fn safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(account: from, operator: caller),
        'ERC1155: caller not allowed'
      );

      self._safe_batch_transfer_from(from, to, ids, amounts, data);
    }

    fn transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(account: from, operator: caller),
        'ERC1155: caller not allowed'
      );

      self._transfer_from(from, to, id, amount);
    }

    fn batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(account: from, operator: caller),
        'ERC1155: caller not allowed'
      );

      self._batch_transfer_from(from, to, ids, amounts);
    }

  }

  //
  // IERC1155 Camel impl
  //

  #[external(v0)]
  impl IERC1155CamelOnlyImpl of interface::IERC1155CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
      self.balance_of(account, id)
    }

    fn balanceOfBatch(
      self: @ContractState,
      accounts: Span<ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
      self.balance_of_batch(accounts, ids)
    }

    fn isApprovedForAll(
      self: @ContractState,
      account: ContractAddress,
      operator: ContractAddress
    ) -> bool {
      self.is_approved_for_all(account, operator)
    }

    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
      self.set_approval_for_all(operator, approved);
    }

    fn safeTransferFrom(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      self.safe_transfer_from(from, to, id, amount, data);
    }

    fn safeBatchTransferFrom(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      self.safe_batch_transfer_from(from, to, ids, amounts, data);
    }

    fn transferFrom(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      self.transfer_from(from, to, id, amount);
    }

    fn batchTransferFrom(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      self.batch_transfer_from(from, to, ids, amounts);
    }
  }

  //
  // IERC1155 Metadata impl
  //

  #[external(v0)]
  impl IERC1155MetadataImpl of interface::IERC1155Metadata<ContractState> {
    fn uri(self: @ContractState, token_id: u256) -> Span<felt252> {
      self._uri.read()
    }
  }

  //
  // ISRC5 impl
  //

  #[external(v0)]
  impl ISRC5Impl of ISRC5<ContractState> {
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      if (
        (interface_id == interface::IERC1155_ID) |
        (interface_id == interface::IERC1155_METADATA_ID) |
        (interface_id == interface::OLD_IERC1155_ID)
      ) {
        true
      } else {
        let src5_self = SRC5::unsafe_new_contract_state();

        src5_self.supports_interface(:interface_id)
      }
    }
  }

  //
  // ISRC5 Camel impl
  //

  #[external(v0)]
  impl ISRC5CamelImpl of ISRC5Camel<ContractState> {
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
      self.supports_interface(interface_id: interfaceId)
    }
  }

  #[external(v0)]
  fn get_costdata(
        self: @ContractState,
        token_id: u256,
  ) -> CostData {
        let costdata = self._costMap.read(token_id);
        costdata      
  }

  #[external(v0)]
  fn get_lastest_token_id(
        self: @ContractState,
        from: ContractAddress,
  ) -> u256 {
        let new_id = self._lastest_token_id.read(from);
        new_id      
  }

  #[external(v0)]
  fn token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
        let urilist = self._uri.read();
        let mut uri_ = ArrayTrait::new();
        
        let mut i: usize = 0;
        loop {
            if i == urilist.len() {
                break;
            }
            uri_.append(*urilist.at(i));
            i += 1;
        };

        uri_.append(u128_to_felt252(token_id.low));
        uri_.append('.json');
        uri_.span()
  }

  #[external(v0)]
  fn mint(
        ref self: ContractState,
        to: ContractAddress,
        id: u256,
        amount: u256,
  ) {
        let caller = get_caller_address();
        assert(self._whitelistMap.read(caller) == 1, 'not in whitelist');
        self._unsafe_mint(to, id, amount);            
  }

  #[external(v0)]
  fn mint_new(
        ref self: ContractState,
        from: ContractAddress,
        from_id: u256,
        amount: u256,
        fts: Array<FTSpec>,
        shape: Array<PackedShapeItem>,
  ) -> u256 {
        let caller = get_caller_address();
        assert(self._whitelistMap.read(caller) == 1, 'not in whitelist');

        let last_counter = self._counter.read();
        check_fts_and_shape_match(fts.span(), shape.span());
        let mut costdata = CostData{
            base_block: 0,
            color_r: 0,
            color_g: 0,
            color_b: 0,
            core_id: from_id,
        };
        let mut i: usize = 0;
        loop {
            if i == shape.len() {
                break;
            }
            let sitem = ShapePacking::unpack(*shape.at(i));
            let tmp_r = u256_from_felt252(sitem.color_r) * 1000000000000000;
            let tmp_g = u256_from_felt252(sitem.color_g) * 1000000000000000;
            let tmp_b = u256_from_felt252(sitem.color_b) * 1000000000000000;
            costdata.color_r = costdata.color_r + tmp_r;
            costdata.color_g = costdata.color_g + tmp_g;
            costdata.color_b = costdata.color_b + tmp_b;
            costdata.base_block = costdata.base_block + 1000000000000000000;
            i += 1;
        };

        let new_id = last_counter + 1;
        self._costMap.write(new_id, costdata);
        self._burn(from, from_id, amount);
        self._unsafe_mint(from, new_id, amount);
        self._set_counter(new_id);
        self._set_lastest_token_id(from, new_id);
        new_id     
  }

  #[external(v0)]
  fn set_costdata(
        ref self: ContractState,
        token_id: u256,
        base_block: u256,
        color_r: u256,
        color_g: u256,
        color_b: u256,
  ) {
        let caller = get_caller_address();
        let owner = self._owner.read();
        assert(self._whitelistMap.read(caller) == 1 || caller == owner, 'no permission');

        let mut costdata = CostData{
            base_block: base_block,
            color_r: color_r,
            color_g: color_g,
            color_b: color_b,
            core_id: 0,
        };

        self._costMap.write(token_id, costdata);
  }

  #[external(v0)]
  fn set_base_uri(ref self: ContractState,uri_: Span<felt252>) {
    self.initializer(uri_);
  }

  #[external(v0)]
  fn set_whitelist(ref self: ContractState, address: ContractAddress) {
        let owner = self._owner.read();
        assert(owner == get_caller_address(), 'not owner');
        self._whitelistMap.write(address, 1);
  }

  #[external(v0)]
  fn burn(
        ref self: ContractState,
        from: ContractAddress,
        id: u256,
        amount: u256,
  ) {
        let caller = get_caller_address();
        assert(self._whitelistMap.read(caller) == 1, 'not in whitelist');
        self._burn(from, id, amount);            
  }

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(ref self: ContractState, uri_: Span<felt252>) {
        self._set_uri(uri_);
    }
    // // example, change to your own nft json url
    // fn initializer(ref self: ContractState) {
      
    //   let mut uri_ = ArrayTrait::new();
    //   uri_.append('https://ipfs.io/ipfs/bafkrei');
    //   uri_.append('cmeharxprhocrmxfdeemw7r57vid');
    //   uri_.append('hbbsuapuy7qgdnmhtxwnx7v4');
    //   self._set_uri(uri_.span());
    // }

    fn _mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256, data: Span<felt252>) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
    }

    fn _unsafe_mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(Zeroable::zero(), to, ids, amounts);
    }

    fn _mint_batch(
      ref self: ContractState,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
    }

    // Burn

    fn _burn(ref self: ContractState, from: ContractAddress, id: u256, amount: u256) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    fn _burn_batch(ref self: ContractState, from: ContractAddress, ids: Span<u256>, amounts: Span<u256>) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    // Setters

    fn _set_uri(ref self: ContractState, new_uri: Span<felt252>) {
      self._uri.write(new_uri);
    }

    fn _set_owner(ref self: ContractState, owner: ContractAddress) {
      self._owner.write(owner);
    }

    fn _set_lastest_token_id(ref self: ContractState, owner: ContractAddress, token_id: u256) {
        self._lastest_token_id.write(owner, token_id);
    }

    fn _set_counter(ref self: ContractState, n: u256) {
      self._counter.write(n);
    }

    fn _set_approval_for_all(
      ref self: ContractState,
      owner: ContractAddress,
      operator: ContractAddress,
      approved: bool
    ) {
      assert(owner != operator, 'ERC1155: self approval');

      self._operator_approvals.write((owner, operator), approved);

      // Events
      self.emit(
        Event::ApprovalForAll(
          ApprovalForAll { account: owner, operator, approved }
        )
      );
    }

    // Balances update

    fn _safe_update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      self._update(from, to, ids, amounts);

      let operator = starknet::get_caller_address();

      // Safe transfer check
      if (to.is_non_zero()) {
        if (ids.len() == 1) {
          let id = *ids.at(0);
          let amount = *amounts.at(0);

          self._do_safe_transfer_acceptance_check(operator, from, to, id, amount, data);
        } else {
          self._do_safe_batch_transfer_acceptance_check(operator, from, to, ids, amounts, data);
        }
      }
    }

    fn _update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(ids.len() == amounts.len(), 'ERC1155: bad ids & amounts len');

      let operator = starknet::get_caller_address();

      let mut i: usize = 0;
      let len = ids.len();
      loop {
        if (i >= len) {
          break ();
        }

        let id = *ids.at(i);
        let amount = *amounts.at(i);

        // Decrease sender balance
        if (from.is_non_zero()) {
          let from_balance = self._balances.read((id, from));
          assert(from_balance >= amount, 'ERC1155: insufficient balance');

          self._balances.write((id, from), from_balance - amount);
        }

        // Increase recipient balance
        if (to.is_non_zero()) {
          let to_balance = self._balances.read((id, to));
          self._balances.write((id, to), to_balance + amount);
        }

        i += 1;
      };

      // Transfer events
      if (ids.len() == 1) {
        let id = *ids.at(0);
        let amount = *amounts.at(0);

        self.emit(
          Event::TransferSingle(
            TransferSingle { operator, from, to, id, value: amount }
          )
        );
      } else {
        self.emit(
          Event::TransferBatch(
            TransferBatch { operator, from, to, ids, values: amounts }
          )
        );
      }
    }

    // Safe transfers

    fn _safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._safe_update(from, to, ids, amounts, data);
    }

    fn _safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._safe_update(from, to, ids, amounts, data);
    }

    // Unsafe transfers

    fn _transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._update(from, to, ids, amounts);
    }

    fn _batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._update(from, to, ids, amounts);
    }

    // Safe transfer check

    fn _do_safe_transfer_acceptance_check(
      ref self: ContractState,
      operator: ContractAddress,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let SRC5 = DualCaseSRC5 { contract_address: to };

      if (SRC5.supports_interface(interface::IERC1155_RECEIVER_ID)) {
        
        let ERC1155Receiver = DualCaseERC1155Receiver { contract_address: to };

        let response = ERC1155Receiver.on_erc1155_received(operator, from, id, amount, data);
        assert(response == interface::ON_ERC1155_RECEIVED_SELECTOR, 'ERC1155: safe transfer failed');
      } else {
        assert(SRC5.supports_interface(interface::ISRC6_ID), 'ERC1155: safe transfer failed');
      }
    }

    fn _do_safe_batch_transfer_acceptance_check(
      ref self: ContractState,
      operator: ContractAddress,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let SRC5 = DualCaseSRC5 { contract_address: to };

      if (SRC5.supports_interface(interface::IERC1155_RECEIVER_ID)) {
        
        let ERC1155Receiver = DualCaseERC1155Receiver { contract_address: to };

        let response = ERC1155Receiver.on_erc1155_batch_received(operator, from, ids, amounts, data);
        assert(response == interface::ON_ERC1155_BATCH_RECEIVED_SELECTOR, 'ERC1155: safe transfer failed');
      } else {
        assert(SRC5.supports_interface(interface::ISRC6_ID), 'ERC1155: safe transfer failed');
      }
    }

    fn _as_singleton_spans(self: @ContractState, element1: u256, element2: u256) -> (Span<u256>, Span<u256>) {
      (array![element1].span(), array![element2].span())
    }
  }
}