// Copyright (c) The Diem Core Contributors
// SPDX-License-Identifier: Apache-2.0
//
// This file is generated on new project creation.

import {
  assertEquals,
} from "https://deno.land/std@0.85.0/testing/asserts.ts";
import * as main from "../main/mod.ts";
import * as context from "../main/context.ts";

Deno.test("Test Play Tic Tac Toe", async () => {
  const playerA = context.defaultUserContext;
  const playerB = context.UserContext.fromEnv("test");

  const board = await main.init(playerA);
  assertEquals(main.boardId(playerA, 0), board.id());

  assertEquals(await board.view(), `
- - -
- - -
- - -

player x: ${playerA.address}
player o: -
`);

  assertEquals(await main.join(board.id(), playerB), `
- - -
- - -
- - -

player x: ${playerA.address}
player o: ${playerB.address}
`);

  assertEquals(await main.move(board.id(), playerA, 0, 0), `
x - -
- - -
- - -

player x: ${playerA.address}
player o: ${playerB.address}
`);

  assertEquals(await main.move(board.id(), playerB, 1, 1), `
x - -
- o -
- - -

player x: ${playerA.address}
player o: ${playerB.address}
`);

  assertEquals(await main.move(board.id(), playerA, 1, 0), `
x - -
x o -
- - -

player x: ${playerA.address}
player o: ${playerB.address}
`);

  assertEquals(await main.move(board.id(), playerB, 2, 1), `
x - -
x o -
- o -

player x: ${playerA.address}
player o: ${playerB.address}
`);
  assertEquals(await main.move(board.id(), playerA, 2, 0), `
x - -
x o -
x o -

player x: ${playerA.address} -- winner
player o: ${playerB.address}
`);
});

Deno.test("Test init multiple games", async () => {
  const playerA = context.defaultUserContext;

  const board1 = await main.init(playerA);
  const nextBoardIndex = board1.id().index + 1;

  const board2 = await main.init(playerA);
  assertEquals(main.boardId(playerA, nextBoardIndex), board2.id());
});
