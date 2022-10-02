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
  invariant( balance() == 2 * wager && matches >= 0);
  while ( matches != 0 ) {
    const isAcceptable = (play) => (play <= 3
                                  && play <= matches
                                  && play >= 1);
    const doPlay = (play) => ([ matches - play, !whoPlays ]);
    each([A, B], () => {
      interact.seeState(matches, whoPlays);
    });

    if (whoPlays){
      commit();

      A.only(() => {
        const play = whoPlays ? 
          declassify(interact.play(matches))
            : 0;
        assume(isAcceptable(play));
      });
      A.publish(play)
        .timeout(relativeTime(deadline), () => closeTo(B, informTimeout));
      require(isAcceptable(play), "Not acceptable play from Alice.");

      each([A, B], () => {
        interact.seePlay(play, whoPlays);
      });
      [ matches, whoPlays ] = doPlay(play);
      continue;
  }
  
    else{
      commit();

      B.only(() => {
        const play = !whoPlays ? 
          declassify(interact.play(matches))
            : 0;
        assume(isAcceptable(play));
      });
      B.publish(play)
        .timeout(relativeTime(deadline), () => closeTo(A, informTimeout));
      require(isAcceptable(play), "Not acceptable play from Bob.");
      
      each([A, B], () => {
        interact.seePlay(play, whoPlays);
      });
      [ matches, whoPlays ] = doPlay(play);
      continue;
    }
  }

  assert(matches == 0);
  const A_wins = !whoPlays;
  transfer(2 * wager).to(A_wins ? A : B);
  commit();

  exit();
});