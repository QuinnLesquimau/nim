'reach 0.1';

const Player = {
  seeState: Fun([UInt, Bool], Null),
  seePlay: Fun([UInt, Bool], Null),
  informTimeout: Fun([], Null),
  play: Fun([UInt], UInt),
};

export const main = Reach.App(() => {
  const A = Participant('Alice', {
    ...Player,
    wager: UInt,
    alicePlaysFirst: Bool,
    initialNumberMatches: UInt,
    deadline: UInt,
  });

  const B = Participant('Bob', {
    ...Player,
    acceptGame: Fun([UInt, UInt, Bool], Null),
  });

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

  var v = 
    { matches: initialNumberMatches, whoPlays: alicePlaysFirst };
  invariant( balance() == 2 * wager && v.matches >= 0);
  while ( v.matches != 0 ) {
    commit();
    each([A, B], () => {
      interact.seeState(v.matches, v.whoPlays);
    })

    A.only(() => {
      const _playA = v.whoPlays ? 
        Array.max(array(UInt, [interact.play(v.matches), 1]))
          : 0;
      const playA = declassify(Array.min(array(UInt, [_playA, 3, v.matches])));
    });
    A.publish(playA)
      .timeout(relativeTime(deadline), () => closeTo(B));
    require(playA <= 3 && playA <= v.matches && boolXor(playA > 0, !v.whoPlays), "Not acceptable play from Alice.");
    commit();

    B.only(() => {
      const _playB = !v.whoPlays ? 
        Array.max(array(UInt, [interact.play(v.matches), 1]))
          : 0;
      const playB = declassify(Array.min(array(UInt, [_playB, 3, v.matches])));
    });
    B.publish(playB)
      .timeout(relativeTime(deadline), () => closeTo(A));
      require(playB <= 3 && playB <= v.matches && boolXor(playB > 0, v.whoPlays), "Not acceptable play from Bob.");
    
    assert(boolXor(playA == 0, playB == 0));
    assert(playA + playB <= v.matches);
    each([A, B], () => {
      interact.seePlay(playA + playB, v.whoPlays);
    });
    v = {matches: v.matches - playA - playB, whoPlays: !v.whoPlays};
    continue;
  }

  assert(v.matches == 0);
  const A_wins = !v.whoPlays;
  transfer(2 * wager).to(A_wins ? A : B);
  commit();

  exit();
});