// SPDX-License-Identifier: MIT

#[starknet::contract]
mod MyToken {
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ClassHash;
    use integer::u256_from_felt252;
    use integer::u128_to_felt252;
    use xar_asset::types::{ShapeItem, PackedShapeItem, FTSpec, ShapePacking, check_fts_and_shape_match};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly = ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl = OwnableComponent::OwnableCamelOnlyImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        _whitelistMap:LegacyMap::<ContractAddress, u8>,
        _costMap:LegacyMap::<u256, CostData>,
        _token_base_uri: (felt252, felt252, felt252, felt252),
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct CostData {
        base_block: u256,
        color_r: u256,
        color_g: u256,
        color_b: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer('ARSBuild', 'AB');
        self.ownable.initializer(owner);
    }

    #[generate_trait]
    #[external(v0)]
    impl ExternalImpl of ExternalTrait {
        fn name(self: @ContractState) -> felt252 {
            self.erc721.ERC721_name.read()
        }

        /// Returns the NFT symbol.
        fn symbol(self: @ContractState) -> felt252 {
            self.erc721.ERC721_symbol.read()
        }


        fn get_costdata(self: @ContractState, token_id: u256) -> CostData {
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            let costdata = self._costMap.read(token_id);
            costdata
        }

        fn burn(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            assert(self.erc721._is_approved_or_owner(caller, token_id), ERC721Component::Errors::UNAUTHORIZED);
            self.erc721._burn(token_id);
        }

        fn safe_mint(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            fts: Array<FTSpec>,
            shape: Array<PackedShapeItem>,
            data: Span<felt252>,
            token_uri: felt252,
        ) {
            let caller = get_caller_address();
            self.ownable.assert_only_owner();
            check_fts_and_shape_match(fts.span(), shape.span());
            let mut costdata = CostData{
                base_block: 0,
                color_r: 0,
                color_g: 0,
                color_b: 0,
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

            self._costMap.write(token_id, costdata);
            self.erc721._mint(recipient, token_id);
            //assert(1 == 0, 'Bad ordering44');
            self.erc721._set_token_uri(token_id, token_uri);
        }

        fn safeMint(
            ref self: ContractState,
            recipient: ContractAddress,
            tokenId: u256,
            fts: Array<FTSpec>,
            shape: Array<PackedShapeItem>,
            data: Span<felt252>,
            tokenURI: felt252,
        ) {
            self.safe_mint(recipient, tokenId, fts, shape, data, tokenURI);
        }

        fn set_whitelist(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self._whitelistMap.write(address, 1);
        }

        fn set_base_uri(ref self: ContractState, uri1: felt252, uri2: felt252, uri3: felt252, uri4: felt252) {
            self.ownable.assert_only_owner();
            self._token_base_uri.write((uri1, uri2, uri3, uri4));
        }

        fn token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
            assert(self.erc721._exists(token_id), ERC721Component::Errors::INVALID_TOKEN_ID);
            let (_base_uri1, _base_uri2, _base_uri3, _base_uri4)  = self._token_base_uri.read();
            let _token_uri = self.erc721.ERC721_token_uri.read(token_id);

            let mut uri_ = ArrayTrait::new();
            uri_.append(_base_uri1);
            uri_.append(_base_uri2);
            uri_.append(_base_uri3);
            uri_.append(_base_uri4);
            if _token_uri == '' {
                uri_.append(u128_to_felt252(token_id.low));
                uri_.append('.json');
            } else {
                uri_.append(_token_uri);
            }
            uri_.span()
        }

    }

    #[external(v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }
}
