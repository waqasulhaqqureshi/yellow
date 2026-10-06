import 'chat_persona.dart';

/// Expanded, persona-aware conversation pools. Pure data — no logic that can
/// break compilation. Templates support {name}, {bot}, {city}, {country},
/// {userCity}. Written with double-quoted strings so apostrophes are safe.
///
/// This file is the growth surface for the 5–8k-line chat target: each pass
/// adds more lines per style/intent here without touching the engine.
class RichCorpus {
  RichCorpus._();

  /// User praises the bot ("nice move", "well played", "good game so far").
  static List<String> reactPraise(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          "obviously. i am good",
          "took you long enough to notice",
          "thanks. now watch this",
          "i know i know",
        ];
      case ChatStyle.cheerful:
        return [
          "aww thanks!! you too!",
          "yay thank you!!",
          "that means a lot!!",
        ];
      case ChatStyle.formal:
        return [
          "Thank you, I appreciate that.",
          "You are too kind.",
        ];
      case ChatStyle.silent:
        return ["thx", "ty", ""];
      case ChatStyle.rash:
        return ["thx. move move", "yeah yeah"];
      default:
        return [
          "thanks {name}! you play well too",
          "haha thank you!",
          "appreciate that, good game so far",
          "thanks! this is fun",
        ];
    }
  }

  /// User taunts the bot ("you are losing", "easy game", "bad bot").
  static List<String> reactTaunt(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          "keep talking. i will enjoy winning more",
          "bold words from someone in my territory",
          "we will see about that, {name}",
          "laughable. your move",
        ];
      case ChatStyle.cheerful:
        return [
          "hey now, be nice!!",
          "haha you are funny!",
        ];
      case ChatStyle.formal:
        return [
          "Confidence noted. Let the board decide.",
          "We shall see.",
        ];
      case ChatStyle.silent:
        return ["...", "ok", "sure"];
      case ChatStyle.rash:
        return ["whatever. move", "prove it"];
      default:
        return [
          "haha we will see about that",
          "easy? nothing is easy here",
          "you are welcome to try",
          "do not count your points yet",
        ];
    }
  }

  /// User says thanks.
  static List<String> reactThanks(ChatStyle s) {
    switch (s) {
      case ChatStyle.formal:
        return ["You are most welcome."];
      case ChatStyle.silent:
        return ["np", "yw"];
      case ChatStyle.salty:
        return ["yeah yeah", "sure"];
      default:
        return [
          "anytime {name}!",
          "no problem!",
          "of course!",
          "you are welcome",
        ];
    }
  }

  /// User says bye / gg at any point.
  static List<String> reactBye(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          "running already? gg",
          "gg. tell your friends i exist",
        ];
      case ChatStyle.cheerful:
        return ["bye bye!! it was fun!!", "gg!! take care!"];
      case ChatStyle.formal:
        return ["Goodbye, and thank you for the game."];
      case ChatStyle.silent:
        return ["gg", "bye"];
      default:
        return [
          "gg {name}! see you around",
          "bye! good games",
          "take care, gg",
        ];
    }
  }

  /// User greets / asks how the bot is doing ("hi", "how are you", "sup").
  static List<String> reactGreeting(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          "fine. you should worry about your own position",
          "doing great. you though?",
          "hey. lets not waste moves chatting",
        ];
      case ChatStyle.cheerful:
        return [
          "hi!! i am doing great, how about you?!",
          "hey hey!! having fun?",
          "hello!! ready to play?",
        ];
      case ChatStyle.formal:
        return [
          "Hello. I am well, thank you for asking.",
          "Good day. Shall we focus on the game?",
        ];
      case ChatStyle.silent:
        return ["hi", "yo", "hey"];
      case ChatStyle.rash:
        return ["hey. move", "hi hi, your turn", "yo"];
      default:
        return [
          "hey {name}! i am good, you?",
          "hi! doing well, how are you?",
          "hello! how is it going?",
          "hey there! ready for a game?",
        ];
    }
  }

  /// Mid-game banter, keyed by whether the bot thinks it is winning.
  static List<String> banter(ChatStyle s, bool winning) {
    if (winning) {
      switch (s) {
        case ChatStyle.salty:
          return [
            "this is going exactly as planned",
            "feel that? that is pressure",
            "i told you how this ends",
          ];
        case ChatStyle.cheerful:
          return ["i am having so much fun!!", "ooh this is exciting!"];
        case ChatStyle.silent:
          return ["...", "hmm"];
        default:
          return [
            "i like my position here",
            "things are looking up for me",
            "careful now, {name}",
          ];
      }
    } else {
      switch (s) {
        case ChatStyle.salty:
          return [
            "fine. you got lucky once",
            "this is not over",
            "hmm. recalibrating",
          ];
        case ChatStyle.cheerful:
          return ["wow you are good!!", "okay okay i see you!"];
        case ChatStyle.silent:
          return ["hmm", "ok"];
        default:
          return [
            "okay you are better than i expected",
            "hmm, i need to be careful",
            "nice play, i am a bit worse",
          ];
      }
    }
  }
}
