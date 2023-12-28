use starknet::ContractAddress;

#[derive(Copy, Drop)]
struct ERC1155Receiver {
    contract_address: ContractAddress
}

trait ERC1155ReceiverTrait {
    fn on_erc1155_received(
        self: @ERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252;

    fn on_erc1155_batch_received(
        self: @ERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        ids: Array<u256>,
        values: Array<u256>,
        data: Span<felt252>
    ) -> felt252;
}

impl ERC1155ReceiverImpl of ERC1155ReceiverTrait {
    fn on_erc1155_received(
        self: @ERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        id: u256,
        value: u256,
        data: Span<felt252>
    ) -> felt252 {
        ''
    }

    fn on_erc1155_batch_received(
        self: @ERC1155Receiver,
        operator: ContractAddress,
        from: ContractAddress,
        ids: Array<u256>,
        values: Array<u256>,
        data: Span<felt252>
    ) -> felt252 {
        ''
    }
}