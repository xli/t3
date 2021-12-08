module Sender::TicTacToe {
    use Std::Signer;
    use Std::Vector;

    struct Board has store, copy {
        players: vector<address>,
        cells: vector<u8>,
    }

    struct Boards has key, copy {
        boards: vector<Board>,
    }

    const TOKEN_X: u8 = 1;
    const TOKEN_O: u8 = 2;

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
        });
    }

    public(script) fun join(player: signer, host_addr: address, index: u64) acquires Boards {
        let boards = borrow_global_mut<Boards>(host_addr);
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);
        Vector::push_back<address>(&mut board.players, Signer::address_of(&player));
    }

    public(script) fun make_move(player: signer, host_addr: address, index: u64, x: u8, y: u8) acquires Boards {
        let player_addr = Signer::address_of(&player);
        let boards = borrow_global_mut<Boards>(host_addr);
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);
        let token = token(board, &player_addr);
        let cell = Vector::borrow_mut<u8>(&mut board.cells, cell_index(x, y));
        *cell = token;
    }

    public fun cell_index(x: u8, y: u8): u64 {
        ((x * 3 + y) as u64)
    }

    public fun token(board: &Board, player: &address): u8 {
        let host = Vector::borrow<address>(&board.players, 0);
        if (player == host) {
            TOKEN_X
        } else {
            TOKEN_O
        }
    }
}