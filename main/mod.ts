// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0

import * as DiemHelpers from "./helpers.ts";
import {
  assert,
} from "https://deno.land/std@0.85.0/testing/asserts.ts";
import {
  defaultUserContext,
  UserContext,
} from "./context.ts";
import * as devapi from "./devapi.ts";
import * as mv from "./move.ts";

export class BoardId {
  constructor(readonly hostAddress: string, readonly index: number) {}
}

export interface Move {
  player: string,
  x: number,
  y: number,
}

export interface BoardData {
  x: string;
  o: OptionAddress;
  moves: Move[]
}

export interface BoardsResource {
  data: Boards
}

export interface Boards {
  boards: BoardData[]
}

export class Board {
  constructor(readonly hostAddress: string, readonly index: number) {}

  id(): BoardId {
    return new BoardId(this.hostAddress, this.index);
  }

  async view(): Promise<string> {
    const boards: BoardsResource[] = await devapi.resourcesWithName("TicTacToe::Boards", this.hostAddress);
    const b: BoardData = boards[0].data.boards[this.index];
    const board = [
      ['-', '-', '-'],
      ['-', '-', '-'],
      ['-', '-', '-'],
    ];
    let winner = "";
    for (let i=0; i<b.moves.length; i++) {
      const m = b.moves[i];
      board[m.x][m.y] = m.player == b.x ? "x" : "o";
      if (check(board, m.x, m.y)) {
        winner = m.player;
        break;
      }
    }

    return `
${board[0][0]} ${board[0][1]} ${board[0][2]}
${board[1][0]} ${board[1][1]} ${board[1][2]}
${board[2][0]} ${board[2][1]} ${board[2][2]}

player x: ${b.x}${gameResult(b.x, winner)}
player o: ${address(b.o)}${gameResult(address(b.o), winner)}
`
  }
}

interface OptionAddress {
  vec: string[]
}

function address(opt: OptionAddress): string {
  return opt.vec.length == 1 ? opt.vec[0] : "-";
}

function gameResult(player: string, winner: string): string {
  if (winner == "") {
    return "";
  }
  return player == winner ? " -- winner" : " -- loser";
}

function check(board: string[][], x: number, y: number): boolean {
  if (board[x][0] != "-" && board[x][0] == board[x][1] && board[x][0] == board[x][2]) {
    return true;
  }
  if (board[0][y] != "-" && board[0][y] == board[1][y] && board[0][y] == board[2][y]) {
    return true;
  }
  if (board[0][0] != "-" && board[0][0] == board[1][1] && board[0][0] == board[2][2]) {
    return true;
  }
  if (board[0][2] != "-" && board[0][2] == board[1][1] && board[0][2] == board[2][0]) {
    return true;
  }
  return false;
}

export async function init(host: UserContext) {
  await call(
    host,
    "init",
    [],
  );

  const boards = await devapi.resourcesWithName("TicTacToe::Boards", host.address);
  return new Board(host.address, boards.length - 1);
}

export async function join(id: BoardId, player: UserContext) {
  await call(
    player,
    "join",
    [mv.Address(id.hostAddress), mv.U64(id.index.toString())],
  );
  return await showBoard(id)
}

export async function move(id: BoardId, player: UserContext, x: number, y: number) {
  await call(
    player,
    "make_move",
    [mv.Address(id.hostAddress), mv.U64(id.index.toString()), mv.U8(x), mv.U8(y)],
  );
  return await showBoard(id);
}

export async function showBoard(id: BoardId) {
  const b = new Board(id.hostAddress, id.index);
  return await b.view();
}

async function call(
  sender: UserContext,
  funcName: string,
  args: mv.MoveType[],
) {
  const moduleAddress = defaultUserContext.address;

  let txn = await DiemHelpers.invokeScriptFunctionForContext(
    sender,
    `${moduleAddress}::TicTacToe::${funcName}`,
    [],
    args,
  );
  txn = await devapi.waitForTransaction(txn.hash);
  assert(txn.success);
}
