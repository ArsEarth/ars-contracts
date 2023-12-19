use starknet::ContractAddress;
use integer::u256_from_felt252;
use ecdsa::check_ecdsa_signature;
use starknet::contract_address_to_felt252;

fn verifySign(
    last_check: u256,
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
    assert(last_check + 1 == thischecksid, 'CHECKS ID NOT VALID');
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
