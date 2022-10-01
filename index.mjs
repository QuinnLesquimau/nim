import {loadStdlib, ask } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';
const stdlib = loadStdlib(process.env);
stdlib.setProviderByName("TestNet");


// const startingBalance = stdlib.parseCurrency(100);
// const acc = await stdlib.newTestAccount(startingBalance);
const mnemonic = await ask.ask(
  `What is your account mnemonic?`,
  (x => x)
);
const acc = await stdlib.newAccountFromMnemonic(mnemonic);
const who = await ask.ask(
  "Are you Alice?",
  ask.yesno,
) ? "Alice" : "Bob";

let ctc = null;
if (who == "Alice"){
  ctc = acc.contract(backend);
  ctc.getInfo().then((info) => {
    console.log(`The info of the contract: ${JSON.stringify(info)}`);
  })
} else {
  const info = await ask.ask(
    "Give the info of the contract:",
    JSON.parse,
  )
  ctc = acc.contract(backend, info);
}

const player = {
  seeState: (matches, alicePlays) => {
    console.log(`There are ${matches} matches, ${alicePlays ? "Alice" : "Bob"} has to play.`);
  },
  seePlay: (matches, alicePlays) => {
    console.log(`${alicePlays ? "Alice" : "Bob"} takes ${matches} matches.`);
  },
  informTimeout: () => {
    console.log("There is a timeout.");
    process.exit(1);
  },
  play: async (totalMatches) => {
    const matches = await ask.ask(
      "How many matches do you want to take (1, 2, 3)?",
      Number
    );
    if (matches < 1 || matches > 3 || matches > totalMatches) {
      throw Error("error: not an acceptable number of matches.");
    }
    return matches;
  },
};

const fmt = (x) => stdlib.formatCurrency(x, 4);
const getBalance = async () => fmt(await stdlib.balanceOf(acc));

const before = await getBalance();
console.log(`Your balance is ${before}`);

if (who == "Alice"){
  player.wager = await ask.ask(
    "How much do you want to wager?",
    stdlib.parseCurrency
  );
  player.deadline = { ETH: 10, ALGO: 20, CFX: 10 }[stdlib.connector];
  player.alicePlaysFirst = await ask.ask(
    "Do you want to play first?",
    ask.yesno
  );
  player.initialNumberMatches = await ask.ask(
    "How many matches are there at the beginning?",
    Number
  );

} else {
  player.acceptGame = async (
                              wager,
                              matches,
                              alicePlaysFirst
  ) => {
    const accepted = await ask.ask(
      `Do you accept the wager of ${fmt(wager)} for a game with ${matches} matches, where ${alicePlaysFirst ? "Alice plays" : "you play"} first?`,
      ask.yesno
    );
    if (!accepted) {
      process.exit(0);
    }
  };
}

const part = who == "Alice" ? ctc.p.Alice : ctc.p.Bob;
await part(player);

const after = await getBalance();
console.log(`Your balance is now ${after}`);

ask.done();