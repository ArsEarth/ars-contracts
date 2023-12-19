use starknet::ContractAddress;


#[derive(Model, Drop, Serde)]
struct LastCheck {
    #[key]
    player: ContractAddress,
    #[key]
    token_id: u256,
    last_id: u256,
}

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
