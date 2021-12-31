%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_lt, uint256_eq
)

from contracts.token.ERC721_base import (
    ERC721_name_,
    ERC721_symbol_,
    ERC721_balanceOf,
    ERC721_ownerOf,
    ERC721_getApproved,
    ERC721_isApprovedForAll,

    ERC721_initializer,
    ERC721_approve, 
    ERC721_setApprovalForAll, 
    ERC721_transferFrom,
    ERC721_safeTransferFrom,
    ERC721_mint,
    ERC721_burn
)

from contracts.ERC165 import ERC165_register_interface

#
# Storage
#

@storage_var
func all_tokens_len() -> (res: Uint256):
end

@storage_var
func all_tokens_list(index_low: felt, index_high: felt) -> (token_id: Uint256):
end

@storage_var
func all_tokens_index(token_id_low: felt, token_id_high: felt) -> (index: Uint256):
end

@storage_var
func owned_tokens(owner: felt, index_low: felt, index_high: felt) -> (token_id: Uint256):
end

@storage_var
func owned_tokens_index(token_id_low: felt, token_id_high: felt) -> (index: Uint256):
end

#
# Constructor
#

func ERC721_Enumerable_initializer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # register IERC721_Enumerable
    ERC165_register_interface('0x780e9d63')
    return ()
end

#
# Getters
#

func ERC721_Enumerable_totalSupply{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }() -> (totalSupply: Uint256):
    let (totalSupply) = all_tokens_len.read()
    return (totalSupply)
end


func ERC721_Enumerable_tokenByIndex{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(index: Uint256) -> (token_id: Uint256):
    alloc_locals
    # Ensures index argument is less than total_supply 
    let (len: Uint256) = ERC721_Enumerable_totalSupply()
    let (is_lt) = uint256_lt(index, len)
    assert is_lt = 1

    let (token_id: Uint256) = all_tokens_list.read(index.low, index.high)
    return (token_id)
end

func ERC721_Enumerable_tokenOfOwnerByIndex{
        syscall_ptr: felt*, 
        pedersen_ptr: HashBuiltin*, 
        range_check_ptr
    }(owner: felt, index: Uint256) -> (token_id: Uint256):
    alloc_locals
    # Ensures index argument is less than owner's balance 
    let (len: Uint256) = ERC721_balanceOf(owner)
    let (is_lt) = uint256_lt(index, len)
    assert_not_zero(is_lt)

    let (token_id: Uint256) = owned_tokens.read(owner, index.low, index.high)
    return (token_id)
end

#
# Externals
#

func ERC721_Enumerable_mint{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    _add_token_to_all_tokens_enumeration(token_id)
    _add_token_to_owner_enumeration(to, token_id)
    ERC721_mint(to, token_id)
    return ()
end

func ERC721_Enumerable_burn{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    let (_from) = ERC721_ownerOf(token_id)
    _remove_token_from_owner_enumeration(_from, token_id)
    _remove_token_from_all_tokens_enumeration(token_id)
    ERC721_burn(token_id)
    return ()
end

func ERC721_Enumerable_transferFrom{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(_from: felt, to: felt, token_id: Uint256):
    _remove_token_from_owner_enumeration(_from, token_id)
    _add_token_to_owner_enumeration(to, token_id)
    ERC721_transferFrom(_from, to, token_id)
    return ()
end

func ERC721_Enumerable_safeTransferFrom{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(
        _from: felt, 
        to: felt, 
        token_id: Uint256, 
        data_len: felt,
        data: felt*
    ):
    _remove_token_from_owner_enumeration(_from, token_id)
    _add_token_to_owner_enumeration(to, token_id)
    ERC721_safeTransferFrom(_from, to, token_id, data_len, data)
    return ()
end

#
# Internals
#

func _add_token_to_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (supply: Uint256) = all_tokens_len.read()
    # Update all_tokens_list
    all_tokens_list.write(supply.low, supply.high, token_id)

    # Update all_tokens_index
    all_tokens_index.write(token_id.low, token_id.high, supply)

    # Update all_tokens_len
    let (local new_supply: Uint256, _) = uint256_add(supply, Uint256(1, 0))
    all_tokens_len.write(new_supply)
    return ()
end

func _remove_token_from_all_tokens_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(token_id: Uint256):
    alloc_locals
    let (supply: Uint256) = all_tokens_len.read()
    let (local index_from_id: Uint256) = all_tokens_index.read(token_id.low, token_id.high)
    let (local last_token_id: Uint256) = all_tokens_list.read(supply.low, supply.high)

    # Update all_tokens_list i.e. index n => token_id
    all_tokens_list.write(index_from_id.low, index_from_id.high, last_token_id)

    # Update all_tokens_index i.e. token_id => index n
    all_tokens_index.write(last_token_id.low, last_token_id.high, index_from_id)

    # Update totalSupply
    let (local new_supply: Uint256) = uint256_sub(supply, Uint256(1, 0))
    all_tokens_len.write(new_supply)
    return ()
end

func _add_token_to_owner_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(to: felt, token_id: Uint256):
    alloc_locals
    let (local length: Uint256) = ERC721_balanceOf(to) 
    owned_tokens.write(to, length.low, length.high, token_id)
    owned_tokens_index.write(token_id.low, token_id.high, length)
    return ()
end

func _remove_token_from_owner_enumeration{
        pedersen_ptr: HashBuiltin*, 
        syscall_ptr: felt*, 
        range_check_ptr
    }(_from: felt, token_id: Uint256):
    alloc_locals
    let (local last_token_index: Uint256) = ERC721_balanceOf(_from)
    # the index starts at zero therefore the user's last token index is their balance minus one
    let (last_token_index) = uint256_sub(last_token_index, Uint256(1, 0))
    let (local token_index: Uint256) = owned_tokens_index.read(token_id.low, token_id.high)

    # If index is last, we can just set the return values to zero
    let (is_equal) = uint256_eq(token_index, last_token_index)
    if is_equal == 1:
        owned_tokens_index.write(token_id.low, token_id.high, Uint256(0, 0))
        owned_tokens.write(_from, last_token_index.low, last_token_index.high, Uint256(0, 0))
        return ()
    end

    # If index is not last, reposition owner's last token to the removed token's index
    let (last_token_id: Uint256) = owned_tokens.read(_from, last_token_index.low, last_token_index.high)
    owned_tokens.write(_from, token_index.low, token_index.high, last_token_id)
    owned_tokens_index.write(last_token_id.low, last_token_id.high, token_index)
    return ()
end
