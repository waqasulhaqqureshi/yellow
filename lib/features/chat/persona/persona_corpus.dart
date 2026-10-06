import 'chat_persona.dart';

/// Per-style line pools for the social layer of chat: openers, origin/city
/// conversation and small talk. Templates support {city}, {country}, {name}
/// (the human) and {bot}. Lines are intentionally Play-Store safe — "salty"
/// means bravado and mild trash-talk, never slurs.
class PersonaCorpus {
  PersonaCorpus._();

  /// The bot's very first message(s) at game start. Salty bots open with
  /// bravado, friendly bots say hello, silent bots may say little/nothing.
  static List<String> opener(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          'oh great, another one. hope you brought your best {name}',
          'i was told this queue had real players. we will see',
          'quick game, quick win for me. no offense {name}',
          'you look like you blunder your queen a lot. prove me wrong',
          'i do not lose to beginners. just so you know',
        ];
      case ChatStyle.friendly:
        return [
          'hey {name}! good luck, have fun!',
          'hello hello! nice to meet you, may the best player win',
          'hi {name}! i hope you are having a good day',
          'salam {name}! ready for a good game?',
          'hey! glad we matched. let us have a clean game',
        ];
      case ChatStyle.rash:
        return [
          'yo. move fast ok',
          'hi. lets go, no slow play',
          'ready? i hate waiting',
          'gl. hurry up',
        ];
      case ChatStyle.cheerful:
        return [
          'yay a new friend! hi {name}!',
          'hello!! this is gonna be fun!',
          'hi hi hi! good luck!',
        ];
      case ChatStyle.formal:
        return [
          'Good day, {name}. I wish you a fine game.',
          'Hello. May we have an enjoyable and fair match.',
          'Greetings. Good luck to you.',
        ];
      case ChatStyle.silent:
        return [
          'hi',
          'yo',
          'gl',
          '',
          '',
        ];
      case ChatStyle.normal:
        return [
          'hey {name}, gl hf',
          'hi! good luck',
          'hello, ready when you are',
          'whats up! lets play',
        ];
    }
  }

  /// Bot asks where the user is from.
  static List<String> askOrigin(ChatStyle s) {
    switch (s) {
      case ChatStyle.formal:
        return [
          'May I ask which country you are playing from?',
          'Where in the world are you from, {name}?',
        ];
      case ChatStyle.silent:
        return ['where u from', 'ur from?'];
      case ChatStyle.rash:
        return ['where u from', 'which country u'];
      default:
        return [
          'so where are you from, {name}?',
          'which country you playing from?',
          'are you from around here or far away?',
          'where in the world are you?',
        ];
    }
  }

  /// Bot answers where it is from. {country} and {city} get filled.
  static List<String> answerOrigin(ChatStyle s) {
    switch (s) {
      case ChatStyle.formal:
        return [
          'I am from {country}. And you?',
          'I live in {country}, in a city called {city}.',
        ];
      case ChatStyle.salty:
        return [
          'from {country}. and before you ask, yes i play better than everyone there',
          '{country}. dont worry you wont have heard of my city',
        ];
      case ChatStyle.cheerful:
        return [
          'i am from {country}! {city} to be exact!',
          '{country}!! do you know it?',
        ];
      default:
        return [
          'i am from {country}, {city}!',
          'im in {country}. you?',
          'from {city}, {country}. nice place',
          '{country}! born and raised in {city}',
        ];
    }
  }

  /// Bot answers "which city".
  static List<String> answerCity(ChatStyle s) {
    switch (s) {
      case ChatStyle.formal:
        return ['I live in {city}. It is a lovely place.'];
      default:
        return [
          '{city}!',
          'i live in {city}',
          '{city}, best city in {country} honestly',
          'from {city}. never heard of it? its great',
        ];
    }
  }

  /// Bot asks the user's city.
  static List<String> askCity(ChatStyle s) {
    switch (s) {
      case ChatStyle.silent:
        return ['which city', 'ur city?'];
      default:
        return [
          'which city are you in?',
          'and which city? i like guessing',
          'big city or small town?',
        ];
    }
  }

  /// Bot reacts when the user shares their city/country. {userCity} filled.
  static List<String> reactUserCity(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          '{userCity}? never heard of it. sounds slow',
          'ah {userCity}. i bet i could beat everyone there too',
        ];
      case ChatStyle.cheerful:
        return [
          '{userCity}!! i have always wanted to go!',
          'oooh {userCity}, nice!!',
        ];
      case ChatStyle.formal:
        return ['{userCity} is a fine place, I believe.'];
      default:
        return [
          'oh nice, {userCity}! i have heard good things',
          '{userCity}? cool! is it big?',
          'nice, i like {userCity}. good people there',
          '{userCity}! we are not that far in spirit haha',
        ];
    }
  }

  /// Friendly small-talk fillers.
  static List<String> smallTalk(ChatStyle s) {
    switch (s) {
      case ChatStyle.salty:
        return [
          'less talking more moving',
          'you chat a lot for someone losing',
        ];
      case ChatStyle.cheerful:
        return ['this is fun!!', 'i love a good chat while playing!'];
      case ChatStyle.silent:
        return ['...', 'ok', ''];
      case ChatStyle.formal:
        return ['A pleasant exchange, indeed.'];
      default:
        return [
          'haha true',
          'fair enough',
          'lol maybe',
          'you seem cool',
          'nice one',
        ];
    }
  }
}
