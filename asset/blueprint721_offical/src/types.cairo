use starknet::storage_access::{Store, StorePacking};
use serde::Serde;
use traits::{TryInto, Into};
use option::OptionTrait;
use xar_asset::felt_math::{FeltBitAnd, FeltDiv, FeltOrd};

#[derive(Copy, Drop, Serde,)]
struct FTSpec {
    token_id: felt252,
    qty: u128,
}

#[derive(Copy, Drop, Serde, Store)]
struct ShapeItem {
    // ASCII short string
    material: u64,
    x: felt252,
    y: felt252,
    z: felt252,
}

#[derive(Copy, Drop, Serde, Store)]
struct PackedShapeItem {
    material: u64,
    x_y_z: felt252,
}

const TWO_POW_64: felt252 = 0x10000000000000000;
const TWO_POW_32: felt252 = 0x100000000;
const TWO_POW_31: felt252 = 0x80000000;

const TWO_POW_64_MASK: felt252 = 0xFFFFFFFFFFFFFFFF;
const TWO_POW_32_MASK: felt252 = 0xFFFFFFFF;

impl ShapePacking of StorePacking<ShapeItem, PackedShapeItem> {
    fn pack(value: ShapeItem) -> PackedShapeItem {
        PackedShapeItem {
            material: value.material,
            x_y_z: (value.z + TWO_POW_31) + (
                (value.y + TWO_POW_31) * TWO_POW_32) + (
                (value.x + TWO_POW_31) * TWO_POW_64
            ),
        }
    }

    fn unpack(value: PackedShapeItem) -> ShapeItem {
        ShapeItem {
            material: value.material,
            x: (value.x_y_z / TWO_POW_32 / TWO_POW_32 & TWO_POW_32_MASK) - TWO_POW_31,
            y: (value.x_y_z / TWO_POW_32 & TWO_POW_32_MASK) - TWO_POW_31,
            z: (value.x_y_z & TWO_POW_32_MASK) - TWO_POW_31,
        }
    }
}

impl PackedShapeItemOrd of PartialOrd<PackedShapeItem> {
    #[inline(always)]
    fn le(lhs: PackedShapeItem, rhs: PackedShapeItem) -> bool {
        lhs.x_y_z <= rhs.x_y_z
    }
    #[inline(always)]
    fn ge(lhs: PackedShapeItem, rhs: PackedShapeItem) -> bool {
        lhs.x_y_z >= rhs.x_y_z
    }
    #[inline(always)]
    fn lt(lhs: PackedShapeItem, rhs: PackedShapeItem) -> bool {
        lhs.x_y_z < rhs.x_y_z
    }
    #[inline(always)]
    fn gt(lhs: PackedShapeItem, rhs: PackedShapeItem) -> bool {
        lhs.x_y_z > rhs.x_y_z
    }
}

fn check_fts_and_shape_match(mut fts: Span<FTSpec>, mut shape: Span<PackedShapeItem>) {
    let mut balances: Felt252Dict<u128> = Default::default();
    let mut nb_materials = 0;
    let mut last_shape = Option::<PackedShapeItem>::None;
    loop {
        match shape.pop_front() {
            Option::Some(data) => {
                let shape_item = ShapePacking::unpack(*data);
                let bl = balances.get(shape_item.material.into());
                if bl == 0 {
                    nb_materials += 1;
                }
                balances.insert(shape_item.material.into(), bl + 1);
                if last_shape.is_some() {
                    // assert(last_shape.unwrap() < *data, 'Bad ordering111');
                }
                last_shape = Option::Some(*data);
            },
            Option::None => { break; }
        };
    };
    assert(fts.len() == nb_materials, 'Bad FTS');
    loop {
        match fts.pop_front() {
            Option::Some(data) => {
                assert(data.qty == @balances.get((*data.token_id).into()), 'Bad FTS');
            },
            Option::None => { break; }
        };
    };
}