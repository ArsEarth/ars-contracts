use starknet::ContractAddress;

#[derive(Model, Drop, Serde)]
struct LastCheck {
    #[key]
    player: ContractAddress,
    #[key]
    token_id: u256,
    last_id: u256,
}

#[derive(Model, Drop, Serde)]
struct LastBuildId {
    #[key]
    player: ContractAddress,
    last_id: u256,
}

#[derive(Model, Drop, Serde)]
struct BuildData {
    #[key]
    player: ContractAddress,
    #[key]
    build_id: u256,
    from_id: u256,
    build_type: u64,
}
