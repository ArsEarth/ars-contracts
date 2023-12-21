use starknet::ContractAddress;

#[derive(Model, Drop, Serde)]
struct LastCheck {
    #[key]
    player: ContractAddress,
    #[key]
    token_id: u256,
    last_id: u256,
}
