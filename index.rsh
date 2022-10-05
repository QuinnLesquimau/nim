'reach 0.1';

const numberHeaps = 3; // Need to be the same as in the frontend

const Player = {
  seeState: Fun([Array(UInt, numberHeaps), Bool], Null),
  seePlay: Fun([UInt, UInt, Bool], Null),
  informTimeout: Fun([], Null),
  play: Fun([Array(UInt, numberHeaps)], Tuple(UInt, UInt)),
};

export const main = Reach.App(() => {
  const A = Participant('Alice', {
    ...Player,
    wager: UInt,
    alicePlaysFirst: Bool,
    initialNumberMatches: Array(UInt, numberHeaps),
    deadline: UInt,
  });

  const B = Participant('Bob', {
    ...Player,
    acceptGame: Fun([UInt, Array(UInt, numberHeaps), Bool], Null),
  });

  const informTimeout = () => {
    each([A, B], () => {
      interact.informTimeout();
    });
  };

  init();

  A.only(() => {
    const wager = declassify(interact.wager);
    const deadline = declassify(interact.deadline);
    const alicePlaysFirst = 
      declassify(interact.alicePlaysFirst);
    const initialNumberMatches = 
      declassify(interact.initialNumberMatches);
  })
  A.publish(
    wager,
    deadline,
    alicePlaysFirst,
    initialNumberMatches
  ).pay(wager);
  commit();

  B.only(() => {
    interact.acceptGame(wager, initialNumberMatches, alicePlaysFirst);
  });
  B.pay(wager)
    .timeout(relativeTime(deadline), () => 
      closeTo(A));

  var [ matches, whoPlays ] = // whoPlays is true if A has to play
     [ initialNumberMatches, alicePlaysFirst ];
  invariant( balance() == 2 * wager && matches.all(x => x >= 0));
  while ( matches.any(x => x > 0) ) {
    const isAcceptable = (matchesRemoved, index) => (matchesRemoved <= 3
                                  && index < numberHeaps
                                  && matchesRemoved <= matches[index]
                                  && matchesRemoved >= 1);
    const doPlay = (matchesRemoved, index) => ([ matches.set(index, matches[index] - matchesRemoved), !whoPlays ]);
    each([A, B], () => {
      interact.seeState(matches, whoPlays);
    });

    if (whoPlays){
      commit();

      A.only(() => {
        const [matchesRemoved, index] = declassify(interact.play(matches));
        assume(isAcceptable(matchesRemoved, index));
      });
      A.publish(matchesRemoved, index)
        .timeout(relativeTime(deadline), () => closeTo(B, informTimeout));
      require(isAcceptable(matchesRemoved, index), "Not acceptable play from Alice.");

      each([A, B], () => {
        interact.seePlay(matchesRemoved, index, whoPlays);
      });
      [ matches, whoPlays ] = doPlay(matchesRemoved, index);
      continue;
    }
  
    else{
      commit();

      B.only(() => {
        const [matchesRemoved, index] = declassify(interact.play(matches));
        assume(isAcceptable(matchesRemoved, index));
      });
      B.publish(matchesRemoved, index)
        .timeout(relativeTime(deadline), () => closeTo(A, informTimeout));
      require(isAcceptable(matchesRemoved, index), "Not acceptable play from Bob.");

      each([A, B], () => {
        interact.seePlay(matchesRemoved, index, whoPlays);
      });
      [ matches, whoPlays ] = doPlay(matchesRemoved, index);
      continue;
    }
  }
  assert(matches.all(x => x == 0));
  const A_wins = !whoPlays;
  transfer(2 * wager).to(A_wins ? A : B);
  commit();

  exit();
});