module Sender::TicTacToe {
    use Std::Errors;
    use Std::Signer;
    use Std::Vector;

    struct Board has store, copy, drop {
        // Players of the game, host is [0], joined player is [1].
        // Only 2 players allowed.
        // Host player can take first move before another player join.
        // Joined player can make move immediately when joining regardless
        // host player moved before the player joined.
        players: vector<address>,
        // cells of the game board, length == 9
        cells: vector<u8>,
        // last move's token:
        //   0: no one moved
        //   1: TOKEN_X
        //   2: TOKEN_O
        last_move_token: u8,
    }

    struct Boards has key, copy {
        boards: vector<Board>,
    }

    const TOKEN_X: u8 = 1;
    const TOKEN_O: u8 = 2;

    // errors
    const EPLAYER_ALREADY_JOINED: u64 = 0;
    const EGAME_STARTED: u64 = 1;
    const EGAME_BOARD_NOT_FOUND: u64 = 2;
    const ENOT_GAME_PLAYER: u64 = 3;
    const ENOT_PLAYER_TURN: u64 = 4;
    const ECELL_IS_TAKEN: u64 = 5;
    const ECOMPLETED_GAME: u64 = 6;

    public(script) fun init(host: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        if (!exists<Boards>(host_addr)) {
            move_to(&host, Boards {
                boards: Vector::empty<Board>(),
            });
        };
        let boards = borrow_global_mut<Boards>(host_addr);
        Vector::push_back<Board>(&mut boards.boards, Board{
            players: vector[host_addr],
            cells: vector[0, 0, 0, 0, 0, 0, 0, 0, 0],
            last_move_token: 0,
        });
    }

    public(script) fun join(player: signer, host_addr: address, index: u64) acquires Boards {
        assert!(exists<Boards>(host_addr), Errors::invalid_argument(EGAME_BOARD_NOT_FOUND));

        let boards = borrow_global_mut<Boards>(host_addr);

        assert!(Vector::length(&boards.boards) > index, Errors::invalid_argument(EGAME_BOARD_NOT_FOUND));
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);

        assert!(Vector::length(&board.players) < 2, Errors::invalid_argument(EGAME_STARTED));

        let player_addr = Signer::address_of(&player);
        assert!(host_player_addr(board) != &player_addr, Errors::invalid_argument(EPLAYER_ALREADY_JOINED));

        Vector::push_back<address>(&mut board.players, player_addr);
    }

    public(script) fun make_move(player: signer, host_addr: address, index: u64, x: u8, y: u8) acquires Boards {
        assert!(exists<Boards>(host_addr), Errors::invalid_argument(EGAME_BOARD_NOT_FOUND));
        let boards = borrow_global_mut<Boards>(host_addr);

        assert!(Vector::length(&boards.boards) > index, Errors::invalid_argument(EGAME_BOARD_NOT_FOUND));
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);

        assert!(!is_end(board), Errors::invalid_argument(ECOMPLETED_GAME));

        let player_addr = Signer::address_of(&player);
        assert!(is_player(board, &player_addr), Errors::invalid_argument(ENOT_GAME_PLAYER));

        let token = token(board, &player_addr);
        assert!(token != board.last_move_token, Errors::invalid_argument(ENOT_PLAYER_TURN));

        let cell_index = make_cell_index(x, y);
        let cell = Vector::borrow_mut<u8>(&mut board.cells, cell_index);
        assert!(*cell == 0, Errors::invalid_argument(ECELL_IS_TAKEN));
        *cell = token;
        board.last_move_token = token;
    }

    public fun is_end(board: &Board): bool {
        board.last_move_token > 0 &&
          (is_all_same_tokens_in_row(board, 0) ||
          is_all_same_tokens_in_row(board, 1) ||
          is_all_same_tokens_in_row(board, 2) ||
          is_all_same_tokens_in_column(board, 0) ||
          is_all_same_tokens_in_column(board, 1) ||
          is_all_same_tokens_in_column(board, 2) ||
          is_all_same_tokens_in_x1(board) ||
          is_all_same_tokens_in_x2(board))
    }

    fun is_all_same_tokens_in_row(board: &Board, row: u64): bool {
        Vector::borrow<u8>(&board.cells, row*3) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, row*3+1) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, row*3+2) == &board.last_move_token
    }

    fun is_all_same_tokens_in_column(board: &Board, col: u64): bool {
        Vector::borrow<u8>(&board.cells, col) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 3 + col) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 6 + col) == &board.last_move_token
    }

    fun is_all_same_tokens_in_x1(board: &Board): bool {
        Vector::borrow<u8>(&board.cells, 0) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 4) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 8) == &board.last_move_token
    }

    fun is_all_same_tokens_in_x2(board: &Board): bool {
        Vector::borrow<u8>(&board.cells, 2) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 4) == &board.last_move_token &&
        Vector::borrow<u8>(&board.cells, 6) == &board.last_move_token
    }

    public fun is_player(board: &Board, addr: &address): bool {
       host_player_addr(board) == addr || is_joined_player_addr(board, addr)
    }

    public fun is_joined_player_addr(board: &Board, addr: &address): bool {
        if (Vector::length(&board.players) < 2) {
           false
        } else {
            joined_player_addr(board) == addr
        }
    }

    public fun host_player_addr(board: &Board): &address {
        Vector::borrow<address>(&board.players, 0)
    }

    public fun make_cell_index(x: u8, y: u8): u64 {
        ((x * 3 + y) as u64)
    }

    public fun token(board: &Board, player: &address): u8 {
        if (player == host_player_addr(board)) {
            TOKEN_X
        } else {
            TOKEN_O
        }
    }

    fun joined_player_addr(board: &Board): &address {
        Vector::borrow<address>(&board.players, 1)
    }

    #[test(host = @0x1, player = @0x2)]
    public(script) fun join_player(host: signer, player: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player, host_addr, 0);
    }

    #[test(host = @0x1, player = @0x1)]
    #[expected_failure(abort_code = 7)]
    public(script) fun host_player_cannot_join(host: signer, player: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player, host_addr, 0);
    }

    #[test(host = @0x1, player1 = @0x2, player2 = @0x3)]
    #[expected_failure(abort_code = 263)]
    public(script) fun join_one_player(host: signer, player1: signer, player2: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player1, host_addr, 0);
        join(player2, host_addr, 0);
    }

    #[test(player = @0x2, invalid_host = @0x3)]
    #[expected_failure(abort_code = 519)]
    public(script) fun join_with_invalid_host_address(player: signer, invalid_host: signer) acquires Boards {
        let host_addr = Signer::address_of(&invalid_host);
        join(player, host_addr, 0);
    }

    #[test(host = @0x1, player = @0x2)]
    #[expected_failure(abort_code = 519)]
    public(script) fun join_with_invalid_index(host: signer, player: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player, host_addr, 1);
    }

    #[test(host = @0x1, player = @0x2, move_player = @0x2)]
    public(script) fun make_move_by_player(host: signer, player: signer, move_player: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player, host_addr, 0);
        make_move(move_player, host_addr, 0, 0, 0);
    }

    #[test(host = @0x1, player1 = @0x2, player2 = @0x3)]
    #[expected_failure(abort_code = 775)]
    public(script) fun move_by_invalid_player(host: signer, player1: signer, player2: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(player1, host_addr, 0);
        make_move(player2, host_addr, 0, 0, 0);
    }

    #[test(host = @0x1, host_move = @0x1, player = @0x2)]
    public(script) fun host_player_can_take_first_move_before_player_join(
        host: signer, host_move: signer, player: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        make_move(host_move, host_addr, 0, 0, 0);
        join(player, host_addr, 0);
    }

    #[test(host = @0x1, host_move1 = @0x1, host_move2 = @0x1)]
    #[expected_failure(abort_code = 1031)]
    public(script) fun cannot_move_twice_by_host_player(
        host: signer, host_move1: signer, host_move2: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        make_move(host_move1, host_addr, 0, 0, 0);
        make_move(host_move2, host_addr, 0, 0, 1);
    }

    #[test(host = @0x1, joined_player = @0x2, joined_move1 = @0x2, joined_move2 = @0x2)]
    #[expected_failure(abort_code = 1031)]
    public(script) fun cannot_move_twice_by_joined_player(
        host: signer, joined_player: signer, joined_move1: signer, joined_move2: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);
        make_move(joined_move1, host_addr, 0, 0, 0);
        make_move(joined_move2, host_addr, 0, 0, 1);
    }

    #[test(host = @0x1, host_move = @0x1, joined_player = @0x2, joined_move = @0x2)]
    #[expected_failure(abort_code = 1287)]
    public(script) fun cannot_make_same_cell_move(
        host: signer, host_move: signer, joined_player: signer, joined_move: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);
        make_move(host_move, host_addr, 0, 1, 1);
        make_move(joined_move, host_addr, 0, 1, 1);
    }

    #[test(host = @0x1, host_move = @0x1, joined_player = @0x2, invalid_host = @0x2)]
    #[expected_failure(abort_code = 519)]
    public(script) fun make_move_with_invalid_board_host_address(
        host: signer, host_move: signer, joined_player: signer, invalid_host: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);

        let invalid_host_addr = Signer::address_of(&invalid_host);
        make_move(host_move, invalid_host_addr, 0, 1, 1);
    }

    #[test(host = @0x1, host_move = @0x1, joined_player = @0x2)]
    #[expected_failure(abort_code = 519)]
    public(script) fun make_move_with_invalid_board_index(
        host: signer, host_move: signer, joined_player: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);
        make_move(host_move, host_addr, 9, 1, 1);
    }

    #[test(
        host = @0x1, joined_player = @0x2,
        host_move1 = @0x1, host_move2 = @0x1, host_move3 = @0x1,
        joined_move1 = @0x2, joined_move2 = @0x2
    )]
    public(script) fun a_complete_game(
        host: signer, host_move1: signer, host_move2: signer, host_move3: signer,
        joined_player: signer, joined_move1: signer, joined_move2: signer,
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);
        // - - -
        // - x -
        // - - -
        make_move(host_move1, host_addr, 0, 1, 1);
        // o - -
        // - x -
        // - - -
        make_move(joined_move1, host_addr, 0, 0, 0);
        // o - -
        // - x -
        // x - -
        make_move(host_move2, host_addr, 0, 2, 0);
        // o o -
        // - x -
        // x - -
        make_move(joined_move2, host_addr, 0, 0, 1);
        // o o x
        // - x -
        // x - -
        make_move(host_move3, host_addr, 0, 0, 2);
    }

    #[test(
        host = @0x1, joined_player = @0x2,
        host_move1 = @0x1, host_move2 = @0x1, host_move3 = @0x1,
        joined_move1 = @0x2, joined_move2 = @0x2, joined_move3 = @0x2
    )]
    #[expected_failure(abort_code = 1543)]
    public(script) fun cannot_make_move_for_a_completed_game(
        host: signer, host_move1: signer, host_move2: signer, host_move3: signer,
        joined_player: signer, joined_move1: signer, joined_move2: signer, joined_move3: signer
    ) acquires Boards {
        let host_addr = Signer::address_of(&host);
        init(host);
        join(joined_player, host_addr, 0);
        // - - -
        // - x -
        // - - -
        make_move(host_move1, host_addr, 0, 1, 1);
        // o - -
        // - x -
        // - - -
        make_move(joined_move1, host_addr, 0, 0, 0);
        // o - -
        // - x -
        // x - -
        make_move(host_move2, host_addr, 0, 2, 0);
        // o o -
        // - x -
        // x - -
        make_move(joined_move2, host_addr, 0, 0, 1);
        // o o x
        // - x -
        // x - -
        make_move(host_move3, host_addr, 0, 0, 2);

        // should fail
        make_move(joined_move3, host_addr, 0, 1, 0);
    }

    #[test(host = @0x1)]
    public fun test_is_game_end(host: address) {
        assert!(!is_end(&Board {
            players: vector[host],
            cells: vector[0, 0, 0, 0, 0, 0, 0, 0, 0],
            last_move_token: 0,
        }), 0);

        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                1, 1, 1,
                0, 0, 0,
                0, 0, 0
            ],
            last_move_token: 1,
        }), 0);
        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                0, 0, 0,
                1, 1, 1,
                0, 0, 0
            ],
            last_move_token: 1,
        }), 0);
        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                0, 0, 0,
                0, 0, 0,
                1, 1, 1,
            ],
            last_move_token: 1,
        }), 0);

        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                1, 0, 0,
                1, 0, 0,
                1, 0, 0,
            ],
            last_move_token: 1,
        }), 0);
        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                0, 1, 0,
                0, 1, 0,
                0, 1, 0,
            ],
            last_move_token: 1,
        }), 0);
        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                0, 0, 1,
                0, 0, 1,
                0, 0, 1,
            ],
            last_move_token: 1,
        }), 0);

        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            ],
            last_move_token: 1,
        }), 0);
        assert!(is_end(&Board {
            players: vector[host],
            cells: vector[
                0, 0, 1,
                0, 1, 0,
                1, 0, 0,
            ],
            last_move_token: 1,
        }), 0);

        assert!(!is_end(&Board {
            players: vector[host],
            cells: vector[
                1, 0, 1,
                0, 1, 1,
                0, 1, 0,
            ],
            last_move_token: 1,
        }), 0);
        assert!(!is_end(&Board {
            players: vector[host],
            cells: vector[
                1, 0, 1,
                1, 0, 1,
                0, 1, 0,
            ],
            last_move_token: 1,
        }), 0);
    }
}
