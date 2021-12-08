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

export interface BoardData {
  players: string[];
  cells: string;
}

export interface Resource {
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
    const boards: Resource[] = await devapi.resourcesWithName("TicTacToe::Boards", this.hostAddress);
    const b: BoardData = boards[0].data.boards[this.index];
    return `
${token(b, 0)} ${token(b, 1)} ${token(b, 2)}
${token(b, 3)} ${token(b, 4)} ${token(b, 5)}
${token(b, 6)} ${token(b, 7)} ${token(b, 8)}

player x: ${playerInfo(b, b.players[0])}
player o: ${playerInfo(b, b.players[1])}
`
  }
}

function token(board: BoardData, index: number): string {
  const t = DiemHelpers.hexToBytes(board.cells)[index];
  return t == 0 ? "-" : (t == 1 ? "x" : "o")
}

function playerInfo(board: BoardData, player: string): string {
  const winner = isWinner(board, player) ? " -- winner" : "";
  return player ? `${player}${winner}` : "-"
}

function isWinner(board: BoardData, player: string): boolean {
  const cells = DiemHelpers.hexToBytes(board.cells);
  function cell(x: number, y: number): number {
    return cells[x*3+y]
  }
  const tokenId = playerTokenId(board, player);
  for (let i=0; i<3; i++) {
    if (cell(0, i) == tokenId && cell(1, i) == tokenId && cell(2, i) == tokenId) {
      return true;
    }
    if (cell(i, 0) == tokenId && cell(i, 1) == tokenId && cell(i, 2) == tokenId) {
      return true;
    }
  }
  if (cell(0, 0) == tokenId && cell(1, 1) == tokenId && cell(2, 2) == tokenId) {
    return true;
  }
  if (cell(2, 0) == tokenId && cell(1, 1) == tokenId && cell(0, 2) == tokenId) {
    return true;
  }
  return false;
}

function playerTokenId(board: BoardData, player: string): number {
  try {
    return board.players.indexOf(player) + 1;
  } catch {
    throw `unknown player: ${player}`
  }
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
