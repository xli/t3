module Sender::TicTacToe {
    use Std::Signer;
    use Std::Vector;
    use Std::Option;

    struct Move has store, copy {
        player: address,
        x: u8,
        y: u8,
    }

    struct Board has store, copy {
        x: address,
        o: Option::Option<address>,
        moves: vector<Move>,
    }

    struct Boards has key, copy {
        boards: vector<Board>,
    }

    public(script) fun init(host: signer) acquires Boards {
        let host_addr = Signer::address_of(&host);
        if (!exists<Boards>(host_addr)) {
            move_to(&host, Boards {
                boards: Vector::empty<Board>(),
            });
        };
        let boards = borrow_global_mut<Boards>(host_addr);
        Vector::push_back<Board>(&mut boards.boards, Board{
            x: host_addr,
            o: Option::none<address>(),
            moves: Vector::empty<Move>(),
        });
    }

    public(script) fun join(player: signer, host_addr: address, index: u64) acquires Boards {
        let boards = borrow_global_mut<Boards>(host_addr);
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);
        board.o = Option::some(Signer::address_of(&player));
    }

    public(script) fun make_move(player: signer, host_addr: address, index: u64, x: u8, y: u8) acquires Boards {
        let boards = borrow_global_mut<Boards>(host_addr);
        let board = Vector::borrow_mut<Board>(&mut boards.boards, index);
        Vector::push_back<Move>(&mut board.moves, Move{
            player: Signer::address_of(&player),
            x: x,
            y: y,
        });
    }
}