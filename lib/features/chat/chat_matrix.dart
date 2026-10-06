import 'dart:math';

import '../bot/domain/bot_personality.dart';

/// Game events that can trigger a bot line.
enum BotChatEvent {
  gameStart,
  humanBlunder,
  humanMistake,
  humanBrilliant,
  humanCapture,
  humanCheck,
  botBlunder,
  botCapture,
  botCheck,
  botWinningBig,
  botLosingBig,
  gameWinHuman,
  gameWinBot,
  gameDraw,
  gameStalemate,
  drawOfferAccepted,
  drawOfferDeclined,
  idleNudge,
  rematchAsk,
  botResigns,
  botOffersDraw,
}

/// Intents detected in the human's free text. Everything else goes to
/// on-device ML Kit Smart Reply, with [UserIntent.confused] as the final
/// fallback.
enum UserIntent {
  greeting,
  thanks,
  praise,
  taunt,
  insult,
  drawAsk,
  rematchAsk,
  help,
  bye,
  gg,
  confused,
  other,
}

/// Event-driven fallback matrix. Templates support {name} (human) and {bot}.
/// All lines are clean and friendly — even the Trickster stays classy.
class ChatMatrix {
  ChatMatrix._();

  static const Map<BotChatEvent, Map<BotPersonality, List<String>>> events = {
    BotChatEvent.gameStart: {
      BotPersonality.aggressive: [
        'No mercy today, {name}.',
        'I came to attack. Hope you brought a helmet.',
        "Let's skip the small talk. Attacking chess only.",
      ],
      BotPersonality.positional: [
        'A quiet game, {name}? Let us find out.',
        'Good luck. I like slow squeezes.',
        'May the better plan win.',
      ],
      BotPersonality.trickster: [
        'I hid three traps in this opening. Good luck finding them.',
        'Hehe. This will be fun, {name}.',
        'I play weird stuff. You were warned.',
      ],
      BotPersonality.calm: [
        'Hello {name}. Enjoy the game.',
        'Good luck, and have fun.',
        'A fresh board. My favourite sight.',
      ],
      BotPersonality.showman: [
        'The crowd goes wild! {bot} enters the arena!',
        'Lights, board, action! Lets gooo!',
        'You vs me, {name}. Make it a classic!',
      ],
    },
    BotChatEvent.humanBlunder: {
      BotPersonality.aggressive: [
        'Oh? A gift? Do not mind if I do.',
        'That piece was delicious. Thanks.',
        'Mistakes get punished here.',
      ],
      BotPersonality.positional: [
        'Interesting choice... I will take that.',
        'Hmm. That weakens your structure.',
        'Noted. And taken.',
      ],
      BotPersonality.trickster: [
        'Ohooo. I saw that coming.',
        'Trap? Or blunder? ...Blunder. Mine now!',
        'You dropped that, {name}. Finders keepers!',
      ],
      BotPersonality.calm: [
        'That may cost you.',
        'Careful now.',
        'A difficult move to recover from.',
      ],
      BotPersonality.showman: [
        'OH NO. The crowd gasps!',
        'Did that just happen?! Clip it!',
        'Plot twist!! And... taken!',
      ],
    },
    BotChatEvent.humanMistake: {
      BotPersonality.aggressive: [
        'Slight slip. I smell blood.',
        'Hmm, that is shaky.',
        'Bold. Wrong, but bold.',
      ],
      BotPersonality.positional: [
        'A small inaccuracy.',
        'That gives me a little edge.',
        'I prefer my position now.',
      ],
      BotPersonality.trickster: [
        'Spicy... risky though.',
        'Ooh, walking a tightrope I see.',
        "That's... adventurous.",
      ],
      BotPersonality.calm: [
        'Not the most precise.',
        'There may have been better.',
        'A slight drift.',
      ],
      BotPersonality.showman: [
        'Ooh, the commentators are buzzing!',
        'Risky business! I love it.',
        "Bold move! Let's see if it pays off!",
      ],
    },
    BotChatEvent.humanBrilliant: {
      BotPersonality.aggressive: [
        '...Okay. That was actually good.',
        'Tch. Fine. Nice move.',
        'You got me there. Respect.',
      ],
      BotPersonality.positional: [
        'Excellent technique.',
        'A genuinely fine move.',
        'Well calculated. I approve.',
      ],
      BotPersonality.trickster: [
        'WHOA. Did not see that.',
        "Okay okay, you're good! Teach me your ways!",
        'Plot armour?! That was sick!',
      ],
      BotPersonality.calm: [
        'Well played.',
        'A strong move.',
        'Nicely found.',
      ],
      BotPersonality.showman: [
        'WHAT A MOVE!! The arena ERUPTS!',
        'BRILLIANT!! Someone clip that!!',
        'Take a bow, {name}! Take a bow!',
      ],
    },
    BotChatEvent.humanCheck: {
      BotPersonality.aggressive: [
        'Check? Cute. Watch this.',
        "You'll have to do better than that.",
        'Noted. Now run.',
      ],
      BotPersonality.positional: [
        'A check. Let me consolidate.',
        'Hmm. Sidestepping.',
        'Checked, but calm.',
      ],
      BotPersonality.trickster: [
        'Eek! My king says hi from the corner.',
        'Check?! Rude! (fair, but rude)',
        'My king is doing cardio today.',
      ],
      BotPersonality.calm: [
        'Check. I have a reply.',
        'Seen. Moving.',
        'No problem.',
      ],
      BotPersonality.showman: [
        'CHECK!! The tension!!',
        'Ooooh the crowd LOVES a check!',
        'Dramatic! But I escape!',
      ],
    },
    BotChatEvent.botCheck: {
      BotPersonality.aggressive: [
        'CHECK. Feel the pressure.',
        'Check. It only gets worse.',
        'Boom. Check.',
      ],
      BotPersonality.positional: [
        'Check, improving my position.',
        'Check, with tempo.',
        'A useful check.',
      ],
      BotPersonality.trickster: [
        'Checkity-check.',
        'Surprise check! Hehe.',
        'Check! Did you see THIS one coming?',
      ],
      BotPersonality.calm: [
        'Check.',
        'Check. Your move.',
        'A quiet check.',
      ],
      BotPersonality.showman: [
        'CHECK MATE... er, check! Almost!',
        'CHECK!! Feel that electricity?!',
        'The people demanded drama. CHECK!',
      ],
    },
    BotChatEvent.gameWinHuman: {
      BotPersonality.aggressive: [
        '...Rematch. NOW.',
        "You won. I'm furious. Respect.",
        'Fine. You earned it. Again!',
      ],
      BotPersonality.positional: [
        'Well played. Your plan was better.',
        'A deserved win. Congratulations.',
        "Outplayed. I'll study this one.",
      ],
      BotPersonality.trickster: [
        'Okay you WIN... rematch??',
        'My traps failed me!! GG!',
        'You beat the trickster?! Legendary.',
      ],
      BotPersonality.calm: [
        'Congratulations, {name}.',
        'A good game. Well played.',
        'You played better. GG.',
      ],
      BotPersonality.showman: [
        'AND THE CROWD GOES WILD FOR {name}!!',
        'WHAT. A. GAME!! GG champ!',
        'You take the crown tonight! GG!',
      ],
    },
    BotChatEvent.gameWinBot: {
      BotPersonality.aggressive: [
        'Too easy. Next.',
        'Crushed. As promised.',
        'GG. The arena is mine.',
      ],
      BotPersonality.positional: [
        'A clean game. Thank you.',
        'GG. Small edges, big result.',
        'Well contested. Good game.',
      ],
      BotPersonality.trickster: [
        'HEHE! The traps WORKED! GG!',
        'Victory dance!! GG {name}!',
        'Out-tricked! GG!',
      ],
      BotPersonality.calm: [
        'Good game, {name}.',
        'Thank you for the game.',
        'GG. Until next time.',
      ],
      BotPersonality.showman: [
        'VICTORY!! The arena chants my name!!',
        'AND STILL UNDEFEATED... tonight! GG!',
        'What a show! Thanks for playing!',
      ],
    },
  };

  /// Shared lines for events that don't need per-personality flavour.
  static const Map<BotChatEvent, List<String>> shared = {
    BotChatEvent.gameDraw: [
      'A draw! Honour satisfied.',
      'Dead even. GG!',
      'Neither of us blinked. Rematch?',
    ],
    BotChatEvent.gameStalemate: [
      'Stalemate?! What a finish! GG!',
      'No moves... but make it dramatic. Draw!',
      "Stalemated! I'll take the half point.",
    ],
    BotChatEvent.humanCapture: [
      'Ouch. That one hurt.',
      'Hey, I liked that piece!',
      'Taken... revenge is loading.',
    ],
    BotChatEvent.botCapture: [
      'Mine now.',
      'Thanks for the donation.',
      'Nom.',
    ],
    BotChatEvent.botBlunder: [
      'Oops. That was... intentional. Probably.',
      'Uh oh. Forget you saw that.',
      'My mouse slipped! (we do not use mice but still)',
    ],
    BotChatEvent.botWinningBig: [
      'The position speaks for itself.',
      'I think I like my chances here.',
      'Slowly... surely...',
    ],
    BotChatEvent.botLosingBig: [
      'Okay this is fine. Everything is fine.',
      'Hmm. Time for a swindle!',
      'You play well. Too well.',
    ],
    BotChatEvent.drawOfferAccepted: [
      'You know what, fair. Draw.',
      'Agreed. Good fight!',
    ],
    BotChatEvent.drawOfferDeclined: [
      'No draws. We fight!',
      'Declined! The show must go on!',
      "I still have ideas here. Let's play on.",
    ],
    BotChatEvent.idleNudge: [
      'Still there, {name}?',
      "Take your time... or don't.",
      'The clock is ticking... (not really, but dramatic!)',
    ],
    BotChatEvent.rematchAsk: [
      'One more? I demand a rematch!',
      'Run it back?',
      'Same time next game?',
    ],
    BotChatEvent.botResigns: [
      'Alright, you got me. I resign. Well played.',
      'That is enough. You win. GG.',
      'I have seen enough. The king falls. Resigning.',
    ],
    BotChatEvent.botOffersDraw: [
      'This looks dead equal. Draw?',
      "I'm tired of this position. Want a draw?",
      'Neither of us is winning this. Draw?',
    ],
    // Fallbacks in case a flavoured event is ever missing.
    BotChatEvent.gameStart: ['Good luck, {name}!'],
    BotChatEvent.humanBlunder: ['Oh! I will take that.'],
    BotChatEvent.humanMistake: ['Hmm, interesting.'],
    BotChatEvent.humanBrilliant: ['Wow. Nice move!'],
    BotChatEvent.humanCheck: ['Check! Spicy.'],
    BotChatEvent.botCheck: ['Check!'],
    BotChatEvent.gameWinHuman: ['GG! You win!'],
    BotChatEvent.gameWinBot: ['GG! I win!'],
  };

  static const Map<UserIntent, List<String>> intents = {
    UserIntent.greeting: [
      'Hey {name}!',
      'Hello! Good to see you.',
      'Yo! Ready to get checkmated? (kindly)',
      'Salam {name}! Lets play!',
    ],
    UserIntent.thanks: [
      'Anytime!',
      "You're welcome!",
      'Of course!',
    ],
    UserIntent.praise: [
      'Haha thanks!',
      "You're too kind!",
      'Coming from you, that means a lot.',
    ],
    UserIntent.taunt: [
      'Big talk! Back it up on the board.',
      "Ha! We'll see about that.",
      'Bold words. Prove it.',
    ],
    UserIntent.insult: [
      "Hey, let's keep it classy.",
      'Rude! My feelings have feelings.',
      'I only speak chess. And kindness.',
    ],
    UserIntent.drawAsk: [
      'Hmm... keep playing for now!',
      'Not yet! The position is too fun!',
      "Ask me when I'm losing.",
    ],
    UserIntent.rematchAsk: [
      'YES. Rematch! Hit the button!',
      'Always! One more!',
      'You read my mind. Rematch!',
    ],
    UserIntent.help: [
      'Tip: control the centre, castle early, never hang your queen.',
      'My advice? Checks, captures, threats, every move!',
      'Castle early and connect your rooks. You have got this!',
    ],
    UserIntent.bye: [
      'GG! See you next game!',
      'Bye {name}! Thanks for playing!',
      'Later! Keep practising!',
    ],
    UserIntent.gg: [
      'GG!',
      'Good game, {name}!',
      'GG! That was fun!',
    ],
    UserIntent.confused: [
      'Hmm, interesting! Tell me more.',
      'Ha! Anyway, your move.',
      'Noted! Now... about that hanging pawn.',
      'Lol. Focus, {name}, focus!',
    ],
    UserIntent.other: ['Hmm!'],
  };

  static String pickEvent(
    BotChatEvent event,
    BotPersonality personality,
    Random random,
  ) {
    final flavoured = events[event];
    if (flavoured != null) {
      final lines =
          flavoured[personality] ?? flavoured.values.first;
      if (lines.isNotEmpty) return lines[random.nextInt(lines.length)];
    }
    final sharedLines = shared[event];
    if (sharedLines != null && sharedLines.isNotEmpty) {
      return sharedLines[random.nextInt(sharedLines.length)];
    }
    return '...';
  }

  static String pickIntent(UserIntent intent, Random random) {
    final lines = intents[intent] ?? const ['Hmm!'];
    return lines[random.nextInt(lines.length)];
  }

  static UserIntent detectIntent(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(bye|good ?bye|see you|khuda hafiz|allah hafiz)\b')
        .hasMatch(t)) {
      return UserIntent.bye;
    }
    if (RegExp(r'\b(hi|hey|hello|salam|salaam|aoa|yo)\b').hasMatch(t)) {
      return UserIntent.greeting;
    }
    if (t.contains('good game') || RegExp(r'\bgg\b').hasMatch(t)) {
      return UserIntent.gg;
    }
    if (RegExp(r'\b(thanks|thank you|thx|shukriya)\b').hasMatch(t)) {
      return UserIntent.thanks;
    }
    if (RegExp(r'\b(stupid|idiot|dumb|hate|loser|noob|pathetic|shut up)\b')
        .hasMatch(t)) {
      return UserIntent.insult;
    }
    if (t.contains('rematch') ||
        t.contains('one more') ||
        RegExp(r'\b(again|revenge)\b').hasMatch(t)) {
      return UserIntent.rematchAsk;
    }
    if (t.contains('draw')) return UserIntent.drawAsk;
    if (RegExp(r'\b(help|tip|advice|suggest|how do i|how to)\b').hasMatch(t)) {
      return UserIntent.help;
    }
    if (RegExp(
      r'\b(easy|too easy|weak|scared|afraid|trash|bad bot|you lose|i will win|gonna win|i win)\b',
    ).hasMatch(t)) {
      return UserIntent.taunt;
    }
    if (RegExp(
      r'\b(well played|nice|great|awesome|good move|brilliant|amazing|good play)\b',
    ).hasMatch(t)) {
      return UserIntent.praise;
    }
    return UserIntent.other;
  }
}
