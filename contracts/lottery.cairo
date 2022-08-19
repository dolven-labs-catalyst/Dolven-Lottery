%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)

from starkware.cairo.common.math import (
    unsigned_div_rem,
    assert_not_zero,
    assert_not_equal,
    assert_nn,
    assert_le,
    assert_lt,
    assert_nn_le,
    assert_in_range,
)

from openzeppelin.token.erc20.interfaces.IERC20 import IERC20

@storage_var
func manager() -> (user : felt):
end

@storage_var
func winner() -> (winner : felt):
end

@storage_var
func players(id : felt) -> (user : felt):
end

@storage_var
func player_count() -> (count : felt):
end

@storage_var
func token() -> (address : felt):
end

# type: Uint256
@storage_var
func ticketPrice() -> (amount : Uint256):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    manager_address : felt, token_address : felt, ticket_price : Uint256
):
    manager.write(value=manager_address)
    token.write(value=token_address)
    ticketPrice.write(value=ticket_price)
    return ()
end

@view
func get_manager{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let (user) = manager.read()
    return (user)
end

@view
func get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    plyrs_len : felt, plyrs : felt*
):
    alloc_locals
    let (plyrs_len, plyrs) = _get_players(0)
    return (plyrs_len, plyrs - plyrs_len)
end

func _get_players{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    plyr_index : felt
) -> (plyrs_len : felt, plyrs : felt*):
    alloc_locals
    let (player) = players.read(id=plyr_index)
    if player == 0:
        let (found_players : felt*) = alloc()
        return (0, found_players)
    end

    let (plyrs_len, plyrs) = _get_players(plyr_index + 1)
    assert [plyrs] = player
    return (plyrs_len + 1, plyrs + 1)
end

@external
func enter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ticketCount : Uint256
):
    let (oldCount) = player_count.read()
    let (caller) = get_caller_address()
    with_attr error_message("Caller address must different 0. Got: {caller}."):
        assert_not_zero(caller)
    end
    let (price) = ticketPrice.read()
    let (token_address) = token.read()
    let (current_contract_address) = get_contract_address()
    let (total_cost : Uint256, _) = uint256_mul(price, ticketCount)
    IERC20.transferFrom(
        contract_address=token_address,
        sender=caller,
        recipient=current_contract_address,
        amount=total_cost,
    )
    writePlayer(ticketCount=ticketCount, caller=caller, count=ticketCount)
    return ()
end

func writePlayer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ticketCount : Uint256, caller : felt, count : Uint256
):
    let (isEq) = uint256_eq(count, Uint256(0, 0))
    if isEq == 1:
        return ()
    end
    let (oldCount) = player_count.read()
    players.write(id=oldCount, value=caller)
    player_count.write(value=oldCount + 1)
    let (sub) = uint256_sub(count, Uint256(1, 0))
    writePlayer(ticketCount=ticketCount, caller=caller, count=sub)
    return ()
end

@external
func pick_winner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (_winner) = get_winner()
    let (caller) = get_caller_address()
    let (manager) = get_manager()
    with_attr error_message("Caller address must be manager. Got: {caller}."):
        assert_not_equal(manager, caller)
    end
    let (token_address) = token.read()
    let (current_contract_address) = get_contract_address()
    let (amount) = IERC20.balanceOf(
        contract_address=token_address, account=current_contract_address
    )
    winner.write(value=_winner)
    IERC20.transfer(contract_address=token_address, recipient=_winner, amount=amount)
    return ()
end

@view
func get_winner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    winner : felt
):
    let (block_timestamp) = get_block_timestamp()
    let (length) = player_count.read()
    let (_, winnerId) = unsigned_div_rem(block_timestamp, length)
    let (winner) = players.read(id=winnerId)
    return (winner)
end
