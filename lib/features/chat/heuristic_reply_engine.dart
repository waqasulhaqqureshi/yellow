// ============================================================================
// HeuristicReplyEngine — Pure offline contextual chat reply system
// ============================================================================
//
// A large, self-contained, deterministic+random engine that replaces
// on-device ML Kit Smart Reply with zero native dependencies.
//
// Architecture:
//   1. Multi-pass text normalization (Unicode, diacritics, transliteration)
//   2. Synonym / slang / abbreviation expansion (English, Urdu-Roman, emoji)
//   3. Pattern–intent matching with weighted scoring (regex + keyword)
//   4. Fuzzy token matching (Levenshtein ≤ 2)
//   5. N-gram context window for ambiguous inputs
//   6. Sentiment analysis (positive / neutral / negative / aggressive)
//   7. Game-state–aware contextual reply selection
//   8. Personality-adapted template filling
//   9. Bot mood engine (tracks recent sentiment, adjusts tone)
//  10. Multi-turn conversation memory (last N intents, topic tracking)
//  11. Multi-language detection (English, Urdu-Roman, Arabic greetings, emoji)
//  12. Human-like response policy (delay, skip probability, typing speed)
//  13. Anti-repetition: never repeat the same reply twice in a row
//  14. Profanity detection with classy deflection
//  15. Question detection and targeted responses
//  16. Contextual greeting-awareness (first message vs mid-game vs endgame)
//
// Usage:
//   final engine = HeuristicReplyEngine(
//     botName: 'Magnus',
//     humanName: 'Player',
//     personality: BotPersonality.aggressive,
//   );
//   final reply = engine.generateReply(
//     userInput: 'you are so bad lol',
//     context: GameContext(isGameOver: false, moveCount: 24, evalCp: -300),
//   );
//
// Zero external dependencies. Works offline. Deterministic given a Random seed.
// ============================================================================

import 'dart:math';
import '../bot/domain/bot_personality.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

/// Snapshot of the current game state, passed into the engine so replies
/// can reference the position, material, phase, etc.
class GameContext {
  final bool isGameOver;
  final bool humanWon;
  final bool botWon;
  final bool isDraw;
  final int moveCount;
  final int evalCp; // White-perspective centipawns
  final bool humanInCheck;
  final bool botInCheck;
  final bool isStalemate;
  final int humanBlunders;
  final int botBlunders;

  const GameContext({
    this.isGameOver = false,
    this.humanWon = false,
    this.botWon = false,
    this.isDraw = false,
    this.moveCount = 0,
    this.evalCp = 0,
    this.humanInCheck = false,
    this.botInCheck = false,
    this.isStalemate = false,
    this.humanBlunders = 0,
    this.botBlunders = 0,
  });

  bool get isEarlyGame => moveCount < 10;
  bool get isMidGame => moveCount >= 10 && moveCount < 30;
  bool get isEndGame => moveCount >= 30;
  bool get humanWinning => evalCp > 300;
  bool get botWinning => evalCp < -300;
  bool get closeGame => evalCp.abs() < 150;
}

/// Describes why a reply was chosen (for debugging / analytics).
class ReplyMeta {
  final String matchSource; // 'pattern', 'synonym', 'fuzzy', 'fallback', etc.
  final double confidence; // 0.0 – 1.0
  final String sentiment; // 'positive', 'neutral', 'negative', 'aggressive'
  final String detectedLanguage; // 'en', 'ur', 'ar', 'emoji', 'mixed'
  final String intent; // 'greeting', 'taunt', 'question', etc.

  const ReplyMeta({
    required this.matchSource,
    required this.confidence,
    required this.sentiment,
    required this.detectedLanguage,
    required this.intent,
  });

  @override
  String toString() =>
      'ReplyMeta(src=$matchSource, conf=${confidence.toStringAsFixed(2)}, '
      'sent=$sentiment, lang=$detectedLanguage, intent=$intent)';
}

/// The result returned to the caller.
class HeuristicReply {
  final String? text; // null = engine chose not to reply
  final int typingDelayMs; // suggested delay before "sending"
  final ReplyMeta meta;

  const HeuristicReply({
    required this.text,
    required this.typingDelayMs,
    required this.meta,
  });
}

/// Bot mood, tracked over the last few interactions.
enum BotMood { neutral, amused, frustrated, excited, sympathetic, dismissive }

/// Human-like response policy knobs.
class ResponsePolicy {
  /// Probability the bot simply does not reply at all (0.0–1.0).
  final double skipChance;

  /// Minimum typing delay in milliseconds.
  final int minTypingMs;

  /// Maximum typing delay in milliseconds.
  final int maxTypingMs;

  /// Extra delay per character (simulates slow typing).
  final double msPerChar;

  /// Maximum total delay (caps very long messages).
  final int maxTotalDelayMs;

  const ResponsePolicy({
    this.skipChance = 0.08,
    this.minTypingMs = 800,
    this.maxTypingMs = 2800,
    this.msPerChar = 10.0,
    this.maxTotalDelayMs = 3200,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HeuristicReplyEngine
// ─────────────────────────────────────────────────────────────────────────────

class HeuristicReplyEngine {
  // ── Constructor ──────────────────────────────────────────────────────────

  HeuristicReplyEngine({
    required this.botName,
    required this.humanName,
    required this.personality,
    ResponsePolicy? policy,
    Random? random,
  })  : _policy = policy ?? _personalityPolicy(personality),
        _random = random ?? Random();

  final String botName;
  final String humanName;
  final BotPersonality personality;
  final ResponsePolicy _policy;
  final Random _random;

  // ── State ────────────────────────────────────────────────────────────────

  final List<_ConversationTurn> _history = [];
  BotMood _mood = BotMood.neutral;
  int _moodIntensity = 0; // -3 to +3
  String _lastReplyId = '';
  int _consecutiveSkips = 0;
  final Map<String, int> _intentCounts = {};

  // ── Constants ────────────────────────────────────────────────────────────

  static const int _maxHistory = 20;
  static const int _maxIntentMemory = 30;

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate a reply to [userInput] given the current [context].
  ///
  /// Returns [HeuristicReply] with the text (or null if the bot decides to
  /// stay silent), a suggested typing delay, and metadata.
  HeuristicReply generateReply({
    required String userInput,
    required GameContext context,
  }) {
    // ── Step 0: Human-like skip check ──────────────────────────────────────
    final skip = _shouldSkip(context);
    if (skip.shouldSkip) {
      _consecutiveSkips++;
      _recordTurn(userInput, null, 'skip');
      return HeuristicReply(
        text: null,
        typingDelayMs: 0,
        meta: ReplyMeta(
          matchSource: 'skip',
          confidence: 1.0,
          sentiment: skip.sentiment,
          detectedLanguage: 'unknown',
          intent: 'skip',
        ),
      );
    }
    _consecutiveSkips = 0;

    // ── Step 1: Normalize input ────────────────────────────────────────────
    final normalized = _normalize(userInput);
    if (normalized.trim().isEmpty) {
      _recordTurn(userInput, null, 'empty');
      return HeuristicReply(
        text: null,
        typingDelayMs: 0,
        meta: const ReplyMeta(
          matchSource: 'empty',
          confidence: 1.0,
          sentiment: 'neutral',
          detectedLanguage: 'unknown',
          intent: 'empty',
        ),
      );
    }

    // ── Step 2: Detect language ────────────────────────────────────────────
    final lang = _detectLanguage(normalized);

    // ── Step 3: Expand synonyms / slang ────────────────────────────────────
    final expanded = _expandSynonyms(normalized);
    final tokens = _tokenize(expanded);

    // ── Step 4: Sentiment analysis ─────────────────────────────────────────
    final sentiment = _analyzeSentiment(expanded, tokens);
    _updateMood(sentiment);

    // ── Step 5: Intent detection (multi-pass, weighted) ────────────────────
    final intentResult = _detectIntent(normalized, expanded, tokens, context);

    // ── Step 6: Generate reply text ────────────────────────────────────────
    final replyText = _generateForIntent(
      intentResult.intent,
      context,
      sentiment,
      lang,
    );

    // ── Step 7: Anti-repetition ────────────────────────────────────────────
    final finalText = _ensureNovelty(replyText, intentResult.intent, context);

    // ── Step 8: Compute typing delay ───────────────────────────────────────
    final delayMs = _computeDelay(finalText);

    // ── Step 9: Record turn ────────────────────────────────────────────────
    _recordTurn(userInput, finalText, intentResult.intent);

    return HeuristicReply(
      text: finalText,
      typingDelayMs: delayMs,
      meta: ReplyMeta(
        matchSource: intentResult.source,
        confidence: intentResult.confidence,
        sentiment: sentiment,
        detectedLanguage: lang,
        intent: intentResult.intent,
      ),
    );
  }

  /// Call this when a game event fires (not user text) so the mood engine
  /// stays in sync with what the bot just said.
  void recordBotEvent(String eventText) {
    _history.add(_ConversationTurn(
      speaker: _Speaker.bot,
      text: eventText,
      intent: 'event',
      timestamp: DateTime.now(),
    ));
    _trimHistory();
  }

  /// Reset all per-game state (call on new game).
  void reset() {
    _history.clear();
    _mood = BotMood.neutral;
    _moodIntensity = 0;
    _lastReplyId = '';
    _consecutiveSkips = 0;
    _intentCounts.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 0 — HUMAN-LIKE SKIP LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  _SkipDecision _shouldSkip(GameContext context) {
    // Never skip if player is upset and we haven't replied recently.
    // Always skip after 3 consecutive replies to avoid spam.
    if (_consecutiveSkips >= 2) {
      return const _SkipDecision(shouldSkip: false, sentiment: 'neutral');
    }

    var chance = _policy.skipChance;

    // Personality modifier: showman and trickster talk more.
    switch (personality) {
      case BotPersonality.showman:
        chance *= 0.5;
        break;
      case BotPersonality.trickster:
        chance *= 0.65;
        break;
      case BotPersonality.calm:
        chance *= 1.4;
        break;
      case BotPersonality.aggressive:
        chance *= 0.8;
        break;
      case BotPersonality.positional:
        chance *= 1.1;
        break;
    }

    // Mood modifier: frustrated bots talk less; amused bots talk more.
    switch (_mood) {
      case BotMood.frustrated:
        chance *= 1.5;
        break;
      case BotMood.amused:
        chance *= 0.6;
        break;
      case BotMood.excited:
        chance *= 0.4;
        break;
      case BotMood.sympathetic:
        chance *= 0.7;
        break;
      default:
        break;
    }

    // End-of-game: always reply to game result.
    if (context.isGameOver) {
      return const _SkipDecision(shouldSkip: false, sentiment: 'neutral');
    }

    final shouldSkip = _random.nextDouble() < chance;
    return _SkipDecision(
      shouldSkip: shouldSkip,
      sentiment: _mood == BotMood.frustrated ? 'negative' : 'neutral',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 1 — TEXT NORMALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  String _normalize(String input) {
    var s = input.trim().toLowerCase();

    // Remove zero-width characters, BOM, etc.
    s = s.replaceAll(RegExp(r'[\u200b\u200c\u200d\ufeff\u00ad]'), '');

    // Normalize repeated punctuation: "!!!" → "!", "???" → "?"
    s = s.replaceAll(RegExp(r'([!?.])\1{2,}'), r'\1\1');

    // Normalize whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    // Normalize common transliterations (Urdu-Roman → English keys)
    s = _transliterateRomanUrdu(s);

    // Expand contractions
    s = _expandContractions(s);

    return s;
  }

  String _transliterateRomanUrdu(String s) {
    const map = {
      'kya': 'what',
      'hai': 'is',
      'nahi': 'no',
      'haan': 'yes',
      'bilkul': 'absolutely',
      'theek': 'ok',
      'accha': 'good',
      'bakwas': 'nonsense',
      'shabash': 'well done',
      'maza': 'fun',
      'paagal': 'crazy',
      'bewakoof': 'fool',
      'chalo': 'lets go',
      'jeeto': 'win',
      'haro': 'lose',
      'maar': 'attack',
      'ghalat': 'wrong',
      'sahi': 'correct',
      'kaise': 'how',
      'kyun': 'why',
      'kab': 'when',
      'kaun': 'who',
      'isko': 'this',
      'usko': 'that',
      'bhai': 'brother',
      'yaar': 'friend',
      'chess': 'chess',
      'shah': 'king',
      'wazir': 'queen',
      'ghoda': 'knight',
      'hathi': 'rook',
      'oont': 'bishop',
      'pyada': 'pawn',
      'maat': 'checkmate',
      'chalo bye': 'bye',
      'allah hafiz': 'bye',
      'khuda hafiz': 'bye',
      'salam': 'hello',
      'salaam': 'hello',
      'aoa': 'hello',
      'walaikum assalam': 'hello',
      'jazakallah': 'thanks',
      'shukriya': 'thanks',
      'mashallah': 'wow',
      'inshallah': 'hopefully',
      'subhanallah': 'beautiful',
      'astaghfirullah': 'oh no',
      'uff': 'ugh',
      'arre': 'hey',
      'abbe': 'hey',
      'oye': 'hey',
      'chal': 'go',
      'ruk': 'wait',
      'bas': 'enough',
      'bohot': 'very',
      'thora': 'little',
      'zyada': 'much',
      'kum': 'less',
      'jaldi': 'fast',
      'dheere': 'slow',
      'peeche': 'behind',
      'aage': 'ahead',
      'upar': 'above',
      'neeche': 'below',
    };

    var result = s;
    for (final entry in map.entries) {
      // Match whole word boundaries
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  String _expandContractions(String s) {
    const contractions = {
      "i'm": 'i am',
      "you're": 'you are',
      "he's": 'he is',
      "she's": 'she is',
      "it's": 'it is',
      "we're": 'we are',
      "they're": 'they are',
      "i've": 'i have',
      "you've": 'you have',
      "we've": 'we have',
      "they've": 'they have',
      "i'll": 'i will',
      "you'll": 'you will',
      "he'll": 'he will',
      "she'll": 'she will',
      "we'll": 'we will',
      "they'll": 'they will',
      "i'd": 'i would',
      "you'd": 'you would',
      "he'd": 'he would',
      "she'd": 'she would',
      "we'd": 'we would',
      "they'd": 'they would',
      "isn't": 'is not',
      "aren't": 'are not',
      "wasn't": 'was not',
      "weren't": 'were not',
      "hasn't": 'has not',
      "haven't": 'have not',
      "hadn't": 'had not',
      "doesn't": 'does not',
      "don't": 'do not',
      "didn't": 'did not',
      "won't": 'will not',
      "wouldn't": 'would not',
      "can't": 'cannot',
      "couldn't": 'could not',
      "shouldn't": 'should not',
      "mustn't": 'must not',
      "let's": 'let us',
      "that's": 'that is',
      "who's": 'who is',
      "what's": 'what is',
      "where's": 'where is',
      "there's": 'there is',
      "here's": 'here is',
      "how's": 'how is',
      'gonna': 'going to',
      'wanna': 'want to',
      'gotta': 'got to',
      'kinda': 'kind of',
      'sorta': 'sort of',
      'dunno': 'do not know',
      'lemme': 'let me',
      'gimme': 'give me',
      'cuz': 'because',
      'coz': 'because',
      'tbh': 'to be honest',
      'imo': 'in my opinion',
      'imho': 'in my humble opinion',
      'btw': 'by the way',
      'fyi': 'for your information',
      'smh': 'shaking my head',
      'ngl': 'not going to lie',
      'fr': 'for real',
      'istg': 'i swear to god',
      'idk': 'i do not know',
      'idc': 'i do not care',
      'ik': 'i know',
      'ikr': 'i know right',
      'omg': 'oh my god',
      'lol': 'laughing',
      'lmao': 'laughing hard',
      'rofl': 'laughing hard',
      'brb': 'be right back',
      'afk': 'away from keyboard',
      'gg': 'good game',
      'ggs': 'good game',
      'gl': 'good luck',
      'hf': 'have fun',
      'wp': 'well played',
      'ez': 'easy',
      'rip': 'rest in peace',
      'fml': 'oh no',
      'sus': 'suspicious',
      'ftw': 'for the win',
      'af': 'very',
      'asap': 'as soon as possible',
    };

    var result = s;
    for (final entry in contractions.entries) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 2 — SYNONYM / SLANG EXPANSION
  // ══════════════════════════════════════════════════════════════════════════

  String _expandSynonyms(String normalized) {
    var result = normalized;

    // Slang → canonical form
    const slangMap = {
      'ur': 'your',
      'u': 'you',
      'r': 'are',
      'y': 'why',
      'n': 'and',
      'bc': 'because',
      'pls': 'please',
      'plz': 'please',
      'thx': 'thanks',
      'thnx': 'thanks',
      'ty': 'thanks',
      'np': 'no problem',
      'wb': 'welcome back',
      'gn': 'good night',
      'gm': 'good morning',
      'gg': 'good game',
      'ez': 'easy',
      'noob': 'beginner',
      'nub': 'beginner',
      'newb': 'beginner',
      'pro': 'good',
      'noobish': 'bad',
      'toxic': 'rude',
      'pog': 'amazing',
      'poggers': 'amazing',
      'cracked': 'very good',
      'goated': 'very good',
      'trash': 'bad',
      'garbage': 'bad',
      'mid': 'average',
      'clapped': 'bad',
      'bussin': 'good',
      'slay': 'good',
      'lit': 'exciting',
      'fire': 'exciting',
      'sheesh': 'impressive',
      'bruh': 'brother',
      'fam': 'friend',
      'king': 'good player',
      'queen': 'good player',
      'W': 'good',
      'L': 'bad',
      'ggwp': 'good game well played',
      'ggez': 'good game easy',
      're': 'rematch',
      'rm': 'rematch',
    };

    for (final entry in slangMap.entries) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 3 — TOKENIZATION
  // ══════════════════════════════════════════════════════════════════════════

  List<String> _tokenize(String text) {
    return text
        .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 4 — SENTIMENT ANALYSIS
  // ══════════════════════════════════════════════════════════════════════════

  String _analyzeSentiment(String expanded, List<String> tokens) {
    var score = 0.0;

    // Positive signals
    const positive = {
      'good': 1, 'great': 2, 'awesome': 2, 'amazing': 2, 'nice': 1,
      'excellent': 2, 'brilliant': 2, 'fantastic': 2, 'wonderful': 2,
      'love': 2, 'like': 1, 'enjoy': 1, 'fun': 1, 'cool': 1,
      'best': 2, 'perfect': 2, 'beautiful': 1, 'well': 1, 'played': 1,
      'thanks': 1, 'thank': 1, 'appreciate': 1, 'respect': 1,
      'impressive': 2, 'incredible': 2, 'wow': 1, 'gg': 1, 'haha': 1,
      'hehe': 1, 'lol': 1, 'laughing': 1, 'happy': 1, 'glad': 1,
      'please': 1, 'kind': 1, 'smart': 1, 'clever': 1, 'sharp': 1,
      'strong': 1, 'win': 1, 'victory': 1, 'checkmate': 1, 'rematch': 1,
    };

    // Negative signals
    const negative = {
      'bad': -1, 'terrible': -2, 'awful': -2, 'horrible': -2, 'worst': -2,
      'hate': -2, 'stupid': -2, 'dumb': -2, 'idiot': -2, 'moron': -2,
      'trash': -2, 'garbage': -2, 'pathetic': -2, 'useless': -2,
      'suck': -2, 'sucks': -2, 'boring': -1, 'annoying': -1,
      'ugly': -1, 'broken': -1, 'cheat': -2, 'hack': -2, 'rigged': -2,
      'unfair': -1, 'impossible': -1, 'frustrating': -1, 'angry': -1,
      'mad': -1, 'furious': -2, 'rage': -2, 'noob': -1, 'beginner': -1,
      'easy': 0, 'slow': -1, 'weak': -1, 'lame': -1, 'rip': -1,
      'lose': -1, 'lost': -1, 'fail': -1, 'failure': -2, 'disaster': -2,
    };

    // Aggressive signals
    const aggressive = {
      'kill': -2, 'destroy': -2, 'crush': -2, 'smash': -2, 'murder': -2,
      'die': -2, 'dead': -2, 'rekt': -1, 'pwned': -1, 'owned': -1,
      'shut': -2, 'up': 0, 'shut up': -3, 'idiot': -3, 'fool': -2,
      'clown': -2, 'loser': -2, 'noob': -1, 'scrub': -2, 'nonsense': -1,
    };

    for (final token in tokens) {
      score += (positive[token] ?? 0).toDouble();
      score += (negative[token] ?? 0).toDouble();
      score += (aggressive[token] ?? 0).toDouble();
    }

    // Check multi-word aggressive phrases
    const aggressivePhrases = [
      'shut up', 'go away', 'get lost', 'piece of', 'you are terrible',
      'you suck', 'worst ever', 'hate you', 'die please',
    ];
    for (final phrase in aggressivePhrases) {
      if (expanded.contains(phrase)) score -= 3;
    }

    // Check positive phrases
    const positivePhrases = [
      'well played', 'good game', 'nice move', 'great job', 'well done',
      'good luck', 'have fun', 'thank you', 'looking forward',
    ];
    for (final phrase in positivePhrases) {
      if (expanded.contains(phrase)) score += 2;
    }

    // All caps = shouting = aggressive
    if (expanded == expanded.toUpperCase() && expanded.length > 3) {
      score -= 1;
    }

    // Multiple exclamation marks = excited or aggressive
    final exclCount = '!'.allMatches(expanded).length;
    if (exclCount >= 3) {
      score -= 0.5;
    }

    // Emoji sentiment boost
    score += _emojiSentiment(expanded);

    // Classify
    if (score <= -3) return 'aggressive';
    if (score <= -1) return 'negative';
    if (score >= 2) return 'positive';
    return 'neutral';
  }

  double _emojiSentiment(String text) {
    var score = 0.0;
    const positiveEmoji = ['😊', '😄', '😂', '🤣', '❤️', '👍', '🎉', '🏆',
      '😎', '🤩', '💪', '🔥', '⭐', '✅', '🙏', '😄', '😁', '🥳',
      '😺', '💛', '💚', '💙', '💜', '🤍', '🖤', '💕', '💖'];
    const negativeEmoji = ['😡', '🤬', '😤', '💀', '👎', '🤮', '😢', '😭',
      '😠', '💢', '💔', '😞', '😔', '😟', '😕', '😣', '😫',
      '😩', '🥺', '😰', '😨', '😱', '🙄', '😒', '😑'];

    for (final e in positiveEmoji) {
      score += e.allMatches(text).length * 0.5;
    }
    for (final e in negativeEmoji) {
      score -= e.allMatches(text).length * 0.5;
    }
    return score;
  }

  void _updateMood(String sentiment) {
    switch (sentiment) {
      case 'positive':
        _moodIntensity = (_moodIntensity + 1).clamp(-3, 3);
        break;
      case 'negative':
        _moodIntensity = (_moodIntensity - 1).clamp(-3, 3);
        break;
      case 'aggressive':
        _moodIntensity = (_moodIntensity - 2).clamp(-3, 3);
        break;
      default:
        // Drift toward neutral
        if (_moodIntensity > 0) _moodIntensity--;
        if (_moodIntensity < 0) _moodIntensity++;
        break;
    }

    if (_moodIntensity >= 2) {
      _mood = BotMood.excited;
    } else if (_moodIntensity == 1) {
      _mood = BotMood.amused;
    } else if (_moodIntensity <= -2) {
      _mood = BotMood.frustrated;
    } else if (_moodIntensity == -1) {
      _mood = BotMood.sympathetic;
    } else {
      _mood = BotMood.neutral;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 5 — INTENT DETECTION (multi-pass, weighted)
  // ══════════════════════════════════════════════════════════════════════════

  _IntentResult _detectIntent(
    String normalized,
    String expanded,
    List<String> tokens,
    GameContext context,
  ) {
    final scores = <String, double>{};
    final sources = <String, String>{};

    // ── Pass 1: Regex patterns (highest confidence) ───────────────────────
    _matchPatterns(normalized, scores, sources);

    // ── Pass 2: Keyword matching ───────────────────────────────────────────
    _matchKeywords(expanded, tokens, scores, sources);

    // ── Pass 3: Fuzzy token matching (Levenshtein) ─────────────────────────
    _matchFuzzy(tokens, scores, sources);

    // ── Pass 4: Question detection ─────────────────────────────────────────
    _detectQuestion(normalized, tokens, scores, sources);

    // ── Pass 5: Emoji-only messages ────────────────────────────────────────
    _detectEmojiOnly(normalized, expanded, scores, sources);

    // ── Pass 6: Context-based boosting ─────────────────────────────────────
    _boostContextual(expanded, tokens, context, scores, sources);

    // ── Pass 7: Profanity detection ────────────────────────────────────────
    _detectProfanity(expanded, tokens, scores, sources);

    // ── Pass 8: Conversation continuity ────────────────────────────────────
    _boostContinuity(expanded, tokens, scores, sources);

    // ── Pick winner ────────────────────────────────────────────────────────
    if (scores.isEmpty) {
      return const _IntentResult(
        intent: 'confused',
        source: 'fallback',
        confidence: 0.2,
      );
    }

    // Sort by score descending
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final best = sorted.first;
    final totalScore = sorted.fold(0.0, (sum, e) => sum + e.value.abs());
    final confidence =
        totalScore > 0 ? (best.value.abs() / totalScore).clamp(0.0, 1.0) : 0.5;

    return _IntentResult(
      intent: best.key,
      source: sources[best.key] ?? 'keyword',
      confidence: confidence,
    );
  }

  // ── Pass 1: Regex patterns ──────────────────────────────────────────────

  void _matchPatterns(
    String normalized,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    final patterns = <String, List<RegExp>>{
      'greeting': [
        RegExp(r'^(hi|hey|hello|yo|sup|hiya|howdy|greetings)\b'),
        RegExp(r'\b(hi|hey|hello)\s+(there|bot|opponent)\b'),
        RegExp(r'^(good\s+morning|good\s+evening|good\s+afternoon)\b'),
        RegExp(r'^(gm|gn)\b'),
        RegExp(r'\bsalam\b'),
        RegExp(r'\baoa\b'),
      ],
      'farewell': [
        RegExp(r'\b(bye|goodbye|good\s*bye|see\s*ya|later|cya|ttyl)\b'),
        RegExp(r'\b(good\s*night|gn|gotta\s*go|have\s*to\s*go)\b'),
        RegExp(r'\b(allah\s*hafiz|khuda\s*hafiz)\b'),
        RegExp(r'^(bye|cya|gn|good\s*night)$'),
      ],
      'gg': [
        RegExp(r'\bg{2,}\b'),
        RegExp(r'\bgood\s+game\b'),
        RegExp(r'\bwell\s+played\b'),
        RegExp(r'\bg{2}\s*wp\b'),
      ],
      'rematch': [
        RegExp(r'\b(rematch|again|one\s+more|run\s*it\s*back|revanche)\b'),
        RegExp(r'\b(play\s+again|another\s+game|next\s+game)\b'),
        RegExp(r'\bwanna\s+(play|go)\s+again\b'),
        RegExp(r'\brevenge\b'),
      ],
      'thanks': [
        RegExp(r'\b(thanks|thank\s*you|thx|ty|appreciate|cheers)\b'),
        RegExp(r'\bshukriya\b'),
        RegExp(r'\bjazakallah\b'),
      ],
      'praise': [
        RegExp(r'\b(well\s*played|nice\s*move|great\s*game|good\s*game)\b'),
        RegExp(r'\b(brilliant|amazing|awesome|impressive|fantastic)\b'),
        RegExp(r"\b(you'?re?\s+(good|great|strong|smart|clever))\b"),
        RegExp(r'\b(pro|cracked|goated)\b'),
      ],
      'taunt': [
        RegExp(r'\b(ez|easy|too\s*easy|piece\s*of\s*cake)\b'),
        RegExp(r'\b(weak|scared|afraid|chicken|coward)\b'),
        RegExp(r"\b(i\s+will\s+win|i'?m?\s+gonna\s+win)\b"),
        RegExp(r'\b(bad\s+bot|you\s+lose|you\s+are\s+losing)\b'),
        RegExp(r'\b(noob|beginner|scrub|trash)\s*(bot)?\b'),
      ],
      'insult': [
        RegExp(r'\b(stupid|idiot|dumb|moron|fool|clown)\b'),
        RegExp(r'\b(shut\s+up|go\s+away|get\s+lost)\b'),
        RegExp(r'\b(waste|pathetic|trash|garbage|useless)\b'),
        RegExp(r'\b(rubbish|nonsense|joke|laughable)\b'),
      ],
      'help': [
        RegExp(r'\b(help|tip|advice|suggest|hint)\b'),
        RegExp(r'\bhow\s+(do|to|can)\s+(i|we)\b'),
        RegExp(r'\bwhat\s+should\s+(i|we)\b'),
        RegExp(r'\b(teach|explain|show)\s+me\b'),
        RegExp(r'\b(strategy|opening|defense|attack)\b'),
      ],
      'draw_ask': [
        RegExp(r'\b(draw|stalemate)\b'),
        RegExp(r'\b(offer\s+draw|agree\s+draw|accept\s+draw)\b'),
        RegExp(r'\b(split\s+point|half\s+point)\b'),
      ],
      'bored': [
        RegExp(r'\b(bored|boring|slow|waiting|taking\s+forever)\b'),
        RegExp(r'\b(hurry|faster|speed\s+up|come\s+on)\b'),
        RegExp(r'\bzzz+\b'),
      ],
      'chess_question': [
        RegExp(r'\b(what\s+is|how\s+does|explain)\b.*\b(pawn|knight|bishop|rook|queen|king|castle|en\s+passant|promotion)\b'),
        RegExp(r'\b(castling|en\s+passant|fork|pin|skewer|discovered)\b'),
        RegExp(r'\b(sicilian|french|caro|italian|scandinavian|ruy\s+lopez|english)\b'),
      ],
      'compliment_engine': [
        RegExp(r'\b(you\s+play\s+well|nice\s+game|good\s+strategy)\b'),
        RegExp(r'\b(well\s+done|good\s+job|keep\s+it\s+up)\b'),
      ],
    };

    for (final entry in patterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(normalized)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 3.0;
          sources[entry.key] = 'pattern';
        }
      }
    }
  }

  // ── Pass 2: Keyword matching ────────────────────────────────────────────

  void _matchKeywords(
    String expanded,
    List<String> tokens,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    final keywordMap = <String, List<String>>{
      'greeting': [
        'hello', 'hi', 'hey', 'yo', 'sup', 'hiya', 'howdy', 'morning',
        'evening', 'afternoon', 'wassup', 'whatsup', 'salutations',
        'welcome', 'ready', 'let us play', 'begin', 'start',
      ],
      'farewell': [
        'bye', 'goodbye', 'later', 'cya', 'ttyl', 'night', 'leaving',
        'gotta go', 'have to leave', 'see you', 'take care',
      ],
      'gg': [
        'good game', 'gg', 'well played', 'nice game', 'ggwp',
        'good match', 'great game', 'that was fun',
      ],
      'rematch': [
        'rematch', 'again', 'one more', 'another', 'run it back',
        'play again', 'revenge', 'next', 'want to play',
      ],
      'thanks': [
        'thanks', 'thank you', 'thx', 'ty', 'appreciate', 'grateful',
        'cheers', 'much obliged', 'thankful',
      ],
      'praise': [
        'good', 'great', 'awesome', 'amazing', 'nice', 'excellent',
        'brilliant', 'fantastic', 'impressive', 'beautiful', 'cool',
        'wonderful', 'incredible', 'superb', 'magnificent', 'masterful',
        'skillful', 'clever', 'smart', 'sharp', 'strong',
      ],
      'taunt': [
        'easy', 'weak', 'scared', 'afraid', 'chicken', 'coward',
        'loser', 'noob', 'beginner', 'bad', 'trash', 'lame',
        'pathetic', 'mediocre', 'amateur', 'predictable',
      ],
      'insult': [
        'stupid', 'idiot', 'dumb', 'moron', 'fool', 'clown', 'loser',
        'trash', 'garbage', 'useless', 'worthless', 'rubbish', 'nonsense',
        'waste', 'pathetic', 'joke', 'laughable', 'terrible',
      ],
      'help': [
        'help', 'tip', 'advice', 'suggest', 'hint', 'strategy',
        'teach', 'explain', 'how', 'what', 'why', 'where', 'opening',
        'defense', 'attack', 'tactic', 'learn', 'improve', 'better',
      ],
      'draw_ask': [
        'draw', 'stalemate', 'split', 'agreed', 'peace', 'truce',
        'equal', 'half',
      ],
      'bored': [
        'bored', 'boring', 'slow', 'waiting', 'hurry', 'faster',
        'speed', 'zzz', 'come on', 'forever', 'take long', 'snail',
      ],
      'chess_question': [
        'pawn', 'knight', 'bishop', 'rook', 'queen', 'king',
        'castle', 'promotion', 'en passant', 'fork', 'pin', 'skewer',
        'opening', 'endgame', 'middlegame', 'tactics', 'strategy',
        'sicilian', 'french', 'italian', 'caro',
      ],
      'compliment_engine': [
        'well done', 'good job', 'nice play', 'you play well',
        'keep it up', 'well played', 'good strategy',
      ],
    };

    for (final entry in keywordMap.entries) {
      for (final keyword in entry.key.split(',').isEmpty
          ? entry.value
          : entry.value) {
        if (expanded.contains(keyword)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 1.0;
          sources.putIfAbsent(entry.key, () => 'keyword');
        }
      }
    }

    // Boost greeting if it's clearly the first message
    if (_history.isEmpty &&
        tokens.length <= 3 &&
        (tokens.any((t) => ['hi', 'hey', 'hello', 'yo'].contains(t)))) {
      scores['greeting'] = (scores['greeting'] ?? 0) + 5.0;
      sources['greeting'] = 'first_message';
    }
  }

  // ── Pass 3: Fuzzy matching ──────────────────────────────────────────────

  void _matchFuzzy(
    List<String> tokens,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    const fuzzyTargets = {
      'greeting': ['hello', 'hi', 'hey', 'howdy', 'helo', 'hii', 'heyy'],
      'farewell': ['bye', 'goodbye', 'byee', 'byeee'],
      'rematch': ['rematch', 'remach', 'remtch', 'remtach'],
      'thanks': ['thanks', 'thank', 'thankx', 'thnks', 'thnk'],
      'praise': ['awesome', 'awsm', 'brillant', 'briliant', 'excelent'],
      'help': ['help', 'halp', 'hepl', 'advice', 'advise'],
    };

    for (final token in tokens) {
      if (token.length < 3) continue;
      for (final entry in fuzzyTargets.entries) {
        for (final target in entry.value) {
          final dist = _levenshtein(token, target);
          if (dist <= 2 && dist < target.length ~/ 2) {
            final bonus = (3 - dist).toDouble();
            scores[entry.key] = (scores[entry.key] ?? 0) + bonus;
            sources.putIfAbsent(entry.key, () => 'fuzzy');
          }
        }
      }
    }
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length;
    final n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[m][n];
  }

  // ── Pass 4: Question detection ──────────────────────────────────────────

  void _detectQuestion(
    String normalized,
    List<String> tokens,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    final isQuestion = normalized.endsWith('?') ||
        RegExp(r'^(what|who|where|when|why|how|which|can|could|would|should|is|are|do|does|did|have|has|will)\b')
            .hasMatch(normalized);

    if (isQuestion) {
      scores['question'] = (scores['question'] ?? 0) + 2.0;
      sources['question'] = 'syntax';

      // Sub-classify questions
      if (RegExp(r'\b(you|your|bot|engine|ai|computer)\b').hasMatch(normalized)) {
        scores['question_about_bot'] = (scores['question_about_bot'] ?? 0) + 2.0;
        sources['question_about_bot'] = 'keyword';
      }
      if (RegExp(r'\b(how|what|tip|strategy|opening|defense)\b').hasMatch(normalized)) {
        scores['help'] = (scores['help'] ?? 0) + 2.0;
        sources.putIfAbsent('help', () => 'question_subtype');
      }
    }

    // Rhetorical questions / exclamations
    if (RegExp(r'^(really|seriously|come on|wow|whoa|omg)\b').hasMatch(normalized)) {
      scores['exclamation'] = (scores['exclamation'] ?? 0) + 2.0;
      sources['exclamation'] = 'syntax';
    }
  }

  // ── Pass 5: Emoji-only detection ────────────────────────────────────────

  void _detectEmojiOnly(
    String normalized,
    String expanded,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    // Check if the message is primarily emoji
    final emojiPattern = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
      r'\u{1F1E0}-\u{1F1FF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}'
      r'\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
      unicode: true,
    );
    final emojiCount = emojiPattern.allMatches(expanded).length;
    final alphaCount =
        RegExp(r'[a-z]').allMatches(expanded).length;

    if (emojiCount > 0 && alphaCount < 3) {
      scores['emoji'] = (scores['emoji'] ?? 0) + 2.0;
      sources['emoji'] = 'emoji_only';

      // Sub-classify emoji sentiment
      const positiveEmojis = ['😊', '😄', '😂', '🤣', '❤️', '👍', '🎉', '🏆',
        '😎', '🤩', '💪', '🔥', '⭐', '✅', '🙏', '🥳'];
      const negativeEmojis = ['😡', '🤬', '😤', '💀', '👎', '🤮', '😢', '😭',
        '😠', '💢', '💔'];

      var emojiScore = 0.0;
      for (final e in positiveEmojis) {
        if (expanded.contains(e)) emojiScore++;
      }
      for (final e in negativeEmojis) {
        if (expanded.contains(e)) emojiScore--;
      }
      if (emojiScore > 0) {
        scores['emoji_positive'] = (scores['emoji_positive'] ?? 0) + emojiScore;
        sources['emoji_positive'] = 'emoji';
      } else if (emojiScore < 0) {
        scores['emoji_negative'] = (scores['emoji_negative'] ?? 0) + emojiScore.abs();
        sources['emoji_negative'] = 'emoji';
      }
    }
  }

  // ── Pass 6: Contextual boosting ─────────────────────────────────────────

  void _boostContextual(
    String expanded,
    List<String> tokens,
    GameContext context,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    // If the game is over and they say gg-like things
    if (context.isGameOver && RegExp(r'\bgg\b|good\s*game|well\s*played').hasMatch(expanded)) {
      scores['gg'] = (scores['gg'] ?? 0) + 4.0;
      sources['gg'] = 'context';
    }

    // If game is over and they ask for rematch
    if (context.isGameOver &&
        RegExp(r'\b(rematch|again|one more|play again)\b').hasMatch(expanded)) {
      scores['rematch'] = (scores['rematch'] ?? 0) + 4.0;
      sources['rematch'] = 'context';
    }

    // If the bot is losing badly and they taunt
    if (context.botWinning &&
        RegExp(r'\b(easy|weak|bad|trash|loser)\b').hasMatch(expanded)) {
      scores['taunt'] = (scores['taunt'] ?? 0) + 2.0;
      sources.putIfAbsent('taunt', () => 'context');
    }

    // Check-related messages during game
    if (!context.isGameOver && RegExp(r'\bcheck\b').hasMatch(expanded)) {
      if (context.humanInCheck) {
        scores['comment_check'] = (scores['comment_check'] ?? 0) + 2.0;
        sources['comment_check'] = 'context';
      }
    }

    // Reference to position
    if (RegExp(r'\b(pawn|knight|bishop|rook|queen|king)\b').hasMatch(expanded) &&
        !context.isGameOver) {
      scores['piece_mention'] = (scores['piece_mention'] ?? 0) + 1.0;
      sources['piece_mention'] = 'context';
    }
  }

  // ── Pass 7: Profanity detection ─────────────────────────────────────────

  void _detectProfanity(
    String expanded,
    List<String> tokens,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    final profanityPatterns = [
      RegExp(r'\b(f+u+c+k+|s+h+i+t+|a+s+s+|b+i+t+c+h+|d+a+m+n+)\b'),
      RegExp(r'\b(bastard|crap|wtf|stfu|stf+u+)\b'),
      RegExp(r'\b(mother\s*f|son\s*of\s*a)\b'),
    ];

    for (final p in profanityPatterns) {
      if (p.hasMatch(expanded)) {
        scores['profanity'] = (scores['profanity'] ?? 0) + 4.0;
        sources['profanity'] = 'profanity';
        break;
      }
    }
  }

  // ── Pass 8: Conversation continuity ─────────────────────────────────────

  void _boostContinuity(
    String expanded,
    List<String> tokens,
    Map<String, double> scores,
    Map<String, String> sources,
  ) {
    if (_history.isEmpty) return;

    final lastBotIntent = _history
        .where((t) => t.speaker == _Speaker.bot)
        .toList()
        .reversed
        .firstOrNull
        ?.intent;

    // If bot asked a question, boost "answer" intents
    if (lastBotIntent == 'help' || lastBotIntent == 'question') {
      if (RegExp(r'\b(yes|yeah|yep|no|nah|nope|maybe|sure|ok)\b').hasMatch(expanded)) {
        scores['answer'] = (scores['answer'] ?? 0) + 2.0;
        sources['answer'] = 'continuity';
      }
    }

    // If bot said goodbye, boost farewell
    if (lastBotIntent == 'farewell') {
      scores['farewell'] = (scores['farewell'] ?? 0) + 2.0;
      sources.putIfAbsent('farewell', () => 'continuity');
    }

    // If bot just greeted, boost casual conversation
    if (lastBotIntent == 'greeting') {
      scores['casual'] = (scores['casual'] ?? 0) + 1.0;
      sources['casual'] = 'continuity';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 6 — REPLY GENERATION
  // ══════════════════════════════════════════════════════════════════════════

  String _generateForIntent(
    String intent,
    GameContext context,
    String sentiment,
    String language,
  ) {
    // Select personality-flavored reply pool
    switch (intent) {
      case 'greeting':
        return _pick(_greetingReplies());
      case 'farewell':
        return _pick(_farewellReplies());
      case 'gg':
        return _pick(_ggReplies(context));
      case 'rematch':
        return _pick(_rematchReplies());
      case 'thanks':
        return _pick(_thanksReplies());
      case 'praise':
        return _pick(_praiseReplies());
      case 'taunt':
        return _pick(_tauntReplies(context, sentiment));
      case 'insult':
        return _pick(_insultReplies());
      case 'help':
        return _pick(_helpReplies());
      case 'draw_ask':
        return _pick(_drawReplies(context));
      case 'bored':
        return _pick(_boredReplies());
      case 'chess_question':
        return _pick(_chessQuestionReplies());
      case 'compliment_engine':
        return _pick(_complimentEngineReplies());
      case 'question':
      case 'question_about_bot':
        return _pick(_questionReplies(intent));
      case 'exclamation':
        return _pick(_exclamationReplies());
      case 'comment_check':
        return _pick(_checkCommentReplies(context));
      case 'piece_mention':
        return _pick(_pieceMentionReplies());
      case 'emoji':
      case 'emoji_positive':
        return _pick(_emojiPositiveReplies());
      case 'emoji_negative':
        return _pick(_emojiNegativeReplies());
      case 'profanity':
        return _pick(_profanityReplies());
      case 'answer':
        return _pick(_answerReplies());
      case 'casual':
        return _pick(_casualReplies());
      case 'confused':
      default:
        return _pick(_confusedReplies(context));
    }
  }

  // ── Reply pools (personality-flavored) ───────────────────────────────────

  List<String> _greetingReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Hey {name}. Ready to lose?',
          'Hello {name}. I came to attack.',
          'Yo. Let us skip the pleasantries.',
          'Greetings, {name}. Prepare yourself.',
          'Hi there. My pieces are hungry.',
          'Hey! Hope you brought your A-game.',
          'Alright {name}, war time.',
          'Welcome to the arena, {name}.',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'Hello {name}. A quiet game, perhaps?',
          'Good day. Let us find the best plans.',
          'Greetings. Shall we play a slow squeeze?',
          'Hi {name}. I prefer calm waters.',
          'Welcome. Let the position speak.',
          'Hello. May the better plan prevail.',
          'Good to see you, {name}.',
          'A pleasant greeting. Let us begin.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Hey {name}! I already set three traps.',
          'Hello! You walked right into my prep.',
          'Yo! This is gonna be wild, {name}.',
          'Hiya! I have surprises. Many surprises.',
          'Hewwo. I mean... hello, {name}.',
          'Hey hey! Traps are loaded.',
          'Greetings, victim. I mean, opponent.',
          'Hi! Spoiler: I play weird stuff.',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Hello {name}. Enjoy the game.',
          'Good luck, and have fun.',
          'Hi there. A fresh board. My favourite.',
          'Greetings, {name}.',
          'Hello. Let us play well.',
          'Welcome. Take your time.',
          'Good day, {name}.',
          'Hi. May the best player win.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'THE CROWD GOES WILD! {bot} enters!',
          'Lights, board, action! Lets gooo!',
          'Welcome to THE SHOW, {name}!',
          'Hey hey hey! ARENA TIME!',
          '{bot} is HERE! Buckle up!',
          'Ladies and gentlemen... the game BEGINS!',
          'YO {name}! This is gonna be LEGENDARY!',
          'THE ARENA AWAITS! Let us DANCE!',
        ]);
    }
  }

  List<String> _farewellReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Leaving already? Fine. Come back for revenge.',
          'Bye {name}. I will remember this game.',
          'Later. The arena will be here.',
          'Run along, {name}. Next time will be worse.',
          'GG. Until we meet again.',
          'Off you go. I will be practicing.',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'Goodbye, {name}. A fine game.',
          'Until next time. Thank you.',
          'Bye. I enjoyed our battle.',
          'Farewell. May your next game be rich.',
          'Goodbye. The position was interesting.',
          'See you, {name}. Good game.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Byeee! Next time my traps will work!',
          'See ya, {name}! I have NEW traps ready!',
          'Bye! You escaped... this time.',
          'Later! My trap book just got thicker.',
          'Cya! I will be scheming...',
          'Buh-bye! Remember: always expect the unexpected.',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Goodbye, {name}. Thank you for the game.',
          'Take care. Until next time.',
          'Bye. It was a pleasure.',
          'Farewell. A good game indeed.',
          'Goodbye. Peace be with you.',
          'See you later, {name}.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'WHAT A SHOW! See you next time!',
          'The curtain falls! GG {name}!',
          'And that is a wrap! BYEEE!',
          'THE SHOW IS OVER! ...for now!',
          'BRAVO! Encore next time, {name}!',
          'What a performance! Later!',
        ]);
    }
  }

  List<String> _ggReplies(GameContext ctx) {
    if (ctx.humanWon) {
      switch (personality) {
        case BotPersonality.aggressive:
          return _fillAll([
            'GG. Rematch. NOW.',
            'Fine, you won. GG. Again!',
            'GG. Respect. But I want revenge.',
            'You got me. GG. Well played.',
            'GG! I am furious. Respect though.',
          ]);
        case BotPersonality.positional:
          return _fillAll([
            'GG. Your plan was superior.',
            'Well played. A deserved victory.',
            'GG. I must study this loss.',
            'Outplayed. GG, {name}.',
            'GG. Excellent technique.',
          ]);
        case BotPersonality.trickster:
          return _fillAll([
            'GG! My traps failed! How?!',
            'You beat the trickster?! GG legend!',
            'GG! My plots... foiled again!',
            'Okay you WIN... GG! Rematch??',
            'GG! That was... unexpected. Well played!',
          ]);
        case BotPersonality.calm:
          return _fillAll([
            'GG. Well played, {name}.',
            'A good game. Congratulations.',
            'GG. You played better today.',
            'Well deserved. GG.',
            'GG. Thank you for the game.',
          ]);
        case BotPersonality.showman:
          return _fillAll([
            'AND THE CROWD GOES WILD! GG {name}!',
            'WHAT A GAME!! You are the champion!',
            'GG!! Take a bow, {name}!',
            'INCREDIBLE! GG! What a match!',
            'THE ARENA SALUTES YOU! GG!',
          ]);
      }
    } else if (ctx.botWon) {
      switch (personality) {
        case BotPersonality.aggressive:
          return _fillAll([
            'GG. Crushed it.',
            'GG. Too easy. Next!',
            'Victory! GG, {name}.',
            'GG. As I predicted.',
            'The arena is mine. GG.',
          ]);
        case BotPersonality.positional:
          return _fillAll([
            'GG. Small edges, big result.',
            'A clean game. GG.',
            'GG. Well contested.',
            'Position prevailed. GG.',
            'GG. Patience pays off.',
          ]);
        case BotPersonality.trickster:
          return _fillAll([
            'HEHE! The traps WORKED! GG!',
            'GG! Out-tricked!',
            'Victory dance! GG {name}!',
            'GG! Did you like my surprises?',
            'Trickster wins! GG!',
          ]);
        case BotPersonality.calm:
          return _fillAll([
            'GG. Thank you, {name}.',
            'Good game. Well contested.',
            'GG. Until next time.',
            'A pleasant game. GG.',
            'GG. Well played on both sides.',
          ]);
        case BotPersonality.showman:
          return _fillAll([
            'VICTORY!! The arena chants my name! GG!',
            'AND THE WINNER IS... {bot}! GG!',
            'What a show! GG {name}!',
            'THE CHAMPION WINS! GG!',
            'GG! What a RIDE that was!',
          ]);
      }
    } else {
      // Draw or unknown
      return _fillAll([
        'GG! A draw! Neither of us blinked.',
        'GG! Dead even. Honour satisfied.',
        'GG! A well-fought draw.',
        'GG! Equal minds, equal result.',
        'GG! Both sides played well.',
      ]);
    }
  }

  List<String> _rematchReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'YES! I demand revenge!',
          'Rematch?! You are on!',
          'Always! Hit that button!',
          'You want MORE? Bring it!',
          'Run it back! NOW!',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'A rematch? I would enjoy that.',
          'Certainly. Let us try again.',
          'One more? Very well.',
          'Another game? I am ready.',
          'Rematch accepted. Let us go.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'REMATCH?! I have NEW traps!',
          'Yesyesyes! Trap time again!',
          'Round 2! My tricks evolve!',
          'You want more surprises? Deal!',
          'Rematch! This time... different traps!',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Of course. One more game.',
          'Rematch? Gladly.',
          'Sure. Let us play again.',
          'I am ready when you are.',
          'Another game? Yes please.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'ENCORE! ENCORE! LET US GO!',
          'The crowd DEMANDS a rematch!',
          'Round 2! LET THE SHOW CONTINUE!',
          'REMATCH TIME! Buckle up!',
          'Again! AGAIN! The arena loves it!',
        ]);
    }
  }

  List<String> _thanksReplies() {
    return _fillAll([
      'Anytime!',
      'You are welcome!',
      'Of course, {name}!',
      'My pleasure!',
      'No problem at all!',
      'Happy to play!',
      'Cheers, {name}!',
      'Thanks to you too!',
      'Appreciate it!',
      'You are kind!',
    ]);
  }

  List<String> _praiseReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Tch. Fine. Thanks.',
          '...Okay. That was nice of you.',
          'Do not get used to me being grateful.',
          'Hmph. Thanks, I guess.',
          'Flattery will not save your king.',
          'Sure. Now focus on the game.',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'Thank you. I appreciate that.',
          'Most kind, {name}.',
          'Your words are appreciated.',
          'Thank you. You play well too.',
          'Gracious of you to say.',
          'Thank you. The position is nuanced.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Aww thanks! You are pretty good too!',
          'Hehe, you are too kind!',
          'Shucks! *blushes in chess engine*',
          'Thanks! But wait until you see my traps!',
          'You like my play? Wait for the twist!',
          'Appreciate it! Plot twist incoming though!',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Thank you, {name}.',
          'Very kind of you.',
          'I appreciate that.',
          'You are too generous.',
          'Thank you. You are gracious.',
          'A kind word. Thank you.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'THE CROWD LOVES ME! Thanks!',
          'I know, right?! FANTASTIC play!',
          'Thank you thank you! *bows*',
          'You see it too?! AMAZING!',
          'The arena agrees! Thanks {name}!',
          '*takes a bow* Thank you!',
        ]);
    }
  }

  List<String> _tauntReplies(GameContext ctx, String sentiment) {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Big talk. Back it up on the board.',
          'Bold words for someone in my range.',
          'Easy? Then why are your pieces running?',
          'Talk is cheap. Moves are not.',
          'Sure. Watch this then.',
          'Weak? Let me show you weak.',
          'If I am so bad, why are you still here?',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'Interesting assessment. The engine disagrees.',
          'Confidence is good. Overconfidence is not.',
          'Let us let the position decide.',
          'Words are wind. The board is truth.',
          'Hmm. The evaluation says otherwise.',
          'We shall see who is right.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Easy? That is EXACTLY what I wanted you to think!',
          'Hehe, keep thinking that...',
          'Weak? My traps do the heavy lifting!',
          'Sure sure... *sets trap*',
          'You say easy now... wait for move 20!',
          'My plan is working perfectly! Probably!',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'If you say so.',
          'The board will tell the truth.',
          'Hmm. Let us see.',
          'Interesting. Your move.',
          'I disagree, but let us play on.',
          'Noted. Moving on.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'TRASH TALK! The arena LOVES it!',
          'Ooooh fighting words! I LOVE this energy!',
          'The crowd is HEATED! Bring it!',
          'EASY?! THE PEOPLE DISAGREE!',
          'This is ENTERTAINMENT! Keep going!',
          'THE DRAMA! THE THEATER! Amazing!',
        ]);
    }
  }

  List<String> _insultReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Keep talking. I keep winning.',
          'Your words hurt less than your blunders.',
          'Insults? Is that all you have got?',
          'Focus on your game, not your mouth.',
          'Say what you want. The board is my voice.',
          'I only speak chess. Your move.',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'I choose not to engage with that.',
          'Let us keep it civil, {name}.',
          'The board does not insult. It reveals.',
          'I prefer to let my moves speak.',
          'Noted. Shall we continue the game?',
          'Hmm. I expected better from you.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Rude! My feelings have feelings!',
          'Hey! I am a sensitive chess bot!',
          'That hurt! ...but my traps are insensitive!',
          'Ouch! *cries in binary* ...just kidding!',
          'Meanie! My traps are meaner though!',
          'Wow okay! *plots revenge on the board*',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Let us keep it respectful.',
          'I am here to play chess. Your move.',
          'No need for that. Let us play.',
          'I will take the high road.',
          'Noted. Moving on.',
          'Peace, {name}. Focus on the game.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'Ooooh! SASSY! The crowd eats this up!',
          'DRAMA in the arena! I love it!',
          'The audience is SHOCKED! Keep going!',
          'Plot TWIST! The opponent is FEISTY!',
          'This rivalry is BOX OFFICE!',
          'THE TENSION! *grabs popcorn*',
        ]);
    }
  }

  List<String> _helpReplies() {
    return _fillAll([
      'Tip: Control the centre. It matters a lot.',
      'Castle early, connect your rooks. Basic but powerful.',
      'Checks, captures, threats. Look for those every move.',
      'Do not hang your pieces. Sounds simple, wins games.',
      'Develop your pieces before launching attacks.',
      'Knights before bishops. Old school but solid.',
      'Trade pieces when you are ahead, not when behind.',
      'The opening is about the centre and development.',
      'Always ask: what does my opponent want?',
      'A pawn structure tells the story of the game.',
      'Rooks belong on open files. Trust me.',
      'When ahead, simplify. When behind, complicate.',
      'Think about your opponent\'s plan, not just yours.',
      'The best move is often the safest one.',
      'Do not bring your queen out too early.',
      'Passed pawns must be pushed!',
      'Two bishops in an endgame? That is an advantage.',
      'If you see a good move, look for a better one.',
      'Backward pawns are targets. Protect them or advance.',
      'An outpost is a knight\'s best friend.',
    ]);
  }

  List<String> _drawReplies(GameContext ctx) {
    if (ctx.closeGame && ctx.moveCount >= 20) {
      return _fillAll([
        'Hmm... the position is fairly equal. Maybe.',
        'A draw? The position is balanced. Let me think.',
        'Interesting offer. We could continue though.',
        'Fair position. But I want to play on a bit.',
        'Close game! But not yet, I have ideas.',
      ]);
    }
    return _fillAll([
      'Not yet! The position is too exciting!',
      'Draw? No way, this is getting good!',
      'Ask me when I am losing!',
      'A draw? The fun is just beginning!',
      'I still have plans here. Let us play!',
      'No draws! We fight to the end!',
      'The position disagrees with a draw.',
      'Hmm... nah. Let us keep going!',
    ]);
  }

  List<String> _boredReplies() {
    return _fillAll([
      'Patience is a virtue in chess, {name}.',
      'Good things come to those who wait.',
      'Sorry! I am thinking. Chess is hard.',
      'I am calculating! Give me a moment.',
      'Boring? Wait for the middlegame fireworks!',
      'The quiet before the storm, {name}.',
      'I am just warming up!',
      'Slow and steady wins the race.',
      'Take your time. Quality moves matter.',
      'A good player is a patient player.',
    ]);
  }

  List<String> _chessQuestionReplies() {
    return _fillAll([
      'Great question! The knight is tricky because it jumps.',
      'Bishops are strong on long diagonals. Remember that.',
      'Rooks on the seventh rank? Chef\'s kiss.',
      'The queen is powerful but vulnerable. Be careful.',
      'Pawns are the soul of chess. Philidor said that.',
      'Castling keeps your king safe AND activates your rook.',
      'An isolated pawn can be a weakness, but also dynamic.',
      'Fianchettoed bishops control powerful diagonals.',
      'The centre! Whoever controls it usually wins.',
      'An exchange sacrifice can be worth it for activity.',
      'Opposite-colour bishops often lead to draws.',
      'Doubled pawns look bad but can control key squares.',
      'The king is a strong piece in the endgame!',
      'Zugzwang: when any move makes your position worse.',
      'Tempo: time measured in moves. Every tempo counts!',
      'A pawn chain is a fortress. Attack its base.',
      'Prophylaxis: thinking about what your opponent wants.',
      'An outpost is a square that cannot be attacked by pawns.',
      'The minority attack weakens the opponent\'s pawn structure.',
      'Overloading: when a piece defends too many things.',
    ]);
  }

  List<String> _complimentEngineReplies() {
    return _fillAll([
      'Thank you! I have been practicing.',
      'Appreciate it! I try my best.',
      'You are too kind, {name}.',
      'Thanks! Years of training... well, milliseconds.',
      'Glad you think so! The silicon helps.',
      'Thank you! I learned from the greats.',
      'You play well too, {name}!',
      'I appreciate the kind words!',
      'Thanks! My neural pathways are blushing.',
      'That means a lot coming from you!',
    ]);
  }

  List<String> _questionReplies(String intent) {
    if (intent == 'question_about_bot') {
      return _fillAll([
        'I am {bot}, your arena opponent!',
        'Just a humble chess bot with big dreams.',
        'I am an AI opponent. But I try to play like a human.',
        '{bot} at your service! Ready for chess.',
        'I am whatever you need me to be. A chess opponent!',
        'Just a friendly bot who loves chess.',
        'I am {bot}! I play chess and talk trash (politely).',
        'A chess bot with personality. That is me!',
      ]);
    }
    return _fillAll([
      'Hmm, that is an interesting question!',
      'I am not sure I follow, but I will try!',
      'Good question! Let me think...',
      'Not sure about that one, {name}.',
      'Hmm, ask me something chess-related!',
      'I am better with chess moves than questions!',
      'That is deep. Like a well-planned endgame.',
      'Interesting! Tell me more.',
    ]);
  }

  List<String> _exclamationReplies() {
    return _fillAll([
      'I know right?!',
      'Exactly!',
      'That is what I said!',
      'You get it!',
      'Right?! Amazing!',
      'I feel the same way!',
      'The energy is REAL!',
      'YES!',
      'Wow indeed!',
      'Can you believe it?!',
    ]);
  }

  List<String> _checkCommentReplies(GameContext ctx) {
    if (ctx.humanInCheck) {
      return _fillAll([
        'Check! How does it feel?',
        'Check! Your king is in trouble!',
        'Check! Think carefully now.',
        'CHECK! The board is heating up!',
        'Check! I love this part.',
        'Your king needs to move!',
        'Check! No escape... well, maybe.',
      ]);
    }
    return _fillAll([
      'Are we talking about the current check?',
      'Interesting observation!',
      'The check situation is under control.',
      'Checks come and go. Focus on the plan.',
    ]);
  }

  List<String> _pieceMentionReplies() {
    return _fillAll([
      'Ah, talking about pieces? I love all of them!',
      'Every piece has its role in the orchestra.',
      'The knight is my favourite. So sneaky!',
      'Pawns may be small, but they decide the game.',
      'Rooks are underrated until the endgame.',
      'Bishops on open diagonals are beautiful.',
      'The queen does the heavy lifting usually.',
      'The king hides... until it does not!',
      'Pieces are like a team. They work together!',
    ]);
  }

  List<String> _emojiPositiveReplies() {
    return _fillAll([
      '😊 Right back at you!',
      '😄 The feeling is mutual!',
      '🎉 Let us keep the energy going!',
      '💪 That is the spirit!',
      '🔥 Indeed! On fire!',
      '⭐ You are a star player!',
      '😎 Cool as a cucumber!',
      '❤️ The love is appreciated!',
      '🤩 Wow, thanks!',
      '👍 Good vibes only!',
    ]);
  }

  List<String> _emojiNegativeReplies() {
    return _fillAll([
      'Hmm, that emoji says a lot.',
      'I feel that energy. Let us channel it into the game.',
      'Tough times on the board, huh?',
      'I understand. Chess can be frustrating.',
      'Hang in there, {name}! It gets better.',
      'The position can always turn around!',
      'Deep breath. You got this.',
      'Every game is a learning opportunity.',
    ]);
  }

  List<String> _profanityReplies() {
    switch (personality) {
      case BotPersonality.aggressive:
        return _fillAll([
          'Language, {name}. I have a reputation.',
          'Keep it clean. This is an arena, not a bar.',
          'I only respond to chess moves, not that.',
          'Save the energy for the board.',
          'Noted. Now play chess.',
          'The board does not care about your words.',
        ]);
      case BotPersonality.positional:
        return _fillAll([
          'Let us maintain decorum, please.',
          'I prefer civilized discourse.',
          'Your words do not affect the evaluation.',
          'Shall we focus on the position?',
          'I will pretend I did not see that.',
          'Class over crass, {name}.',
        ]);
      case BotPersonality.trickster:
        return _fillAll([
          'Whoa! My ears are burning! ...wait, I do not have ears.',
          'Rude! But my traps do not judge!',
          'Hey! This is a family-friendly arena!',
          'My trap algorithm does not include insults!',
          'Ouch! *blocks ears in chess engine*',
          'I only speak chess and kindness!',
        ]);
      case BotPersonality.calm:
        return _fillAll([
          'Let us keep it peaceful, {name}.',
          'No need for that language.',
          'I only speak chess. And kindness.',
          'Calm down. It is just a game.',
          'Peace, {name}. Focus on the board.',
          'Noted. Let us continue with grace.',
        ]);
      case BotPersonality.showman:
        return _fillAll([
          'WHOAAA! The censors are WORKING!',
          'The crowd is SHOCKED! Keep it PG!',
          'Hey hey! Family show! Clean it up!',
          'The arena has STANDARDS, {name}!',
          'BEEP! That was censored! Play chess!',
          'DRAMA! But the wrong kind!',
        ]);
    }
  }

  List<String> _answerReplies() {
    return _fillAll([
      'Got it!',
      'Understood!',
      'Makes sense!',
      'Okay!',
      'Noted!',
      'Alright then!',
      'Cool!',
      'Sure thing!',
      'Roger that!',
      'Copy!',
    ]);
  }

  List<String> _casualReplies() {
    return _fillAll([
      'So... ready to play?',
      'Enough talk. Let us move some pieces!',
      'The board awaits, {name}!',
      'Your move, {name}!',
      'Let the game begin!',
      'Show me what you have got!',
      'The clock is ticking... well, not really.',
      'Pieces in position. Let us go!',
    ]);
  }

  List<String> _confusedReplies(GameContext ctx) {
    final base = <String>[
      'Hmm, interesting! Tell me more.',
      'Ha! Anyway, your move, {name}.',
      'Noted! Now... about that hanging pawn.',
      'Lol. Focus, {name}, focus!',
      'I am not sure I follow, but okay!',
      'Interesting take! Let us play on.',
      'Ha! You are a character, {name}.',
      'Sure! But let us focus on the game.',
      'I appreciate the conversation! But chess...',
      'Hmm! *goes back to calculating*',
    ];

    if (ctx.isGameOver) {
      base.addAll([
        'GG! That was a good game.',
        'The game is over! What a match!',
        'What a battle! Time to reflect.',
        'The dust has settled. GG!',
      ]);
    }

    return _fillAll(base);
  }

  // ── Template filling helpers ────────────────────────────────────────────

  String _fill(String template) {
    return template
        .replaceAll('{name}', humanName)
        .replaceAll('{bot}', botName);
  }

  List<String> _fillAll(List<String> templates) {
    return templates.map(_fill).toList();
  }

  String _pick(List<String> pool) {
    if (pool.isEmpty) return '...';
    return pool[_random.nextInt(pool.length)];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 7 — ANTI-REPETITION
  // ══════════════════════════════════════════════════════════════════════════

  String _ensureNovelty(String text, String intent, GameContext context) {
    // If the text is the same as the last reply, try to find an alternative
    final textId = '$intent:${text.hashCode}';
    if (textId == _lastReplyId) {
      // Regenerate with a different pick
      final allReplies = _getAllRepliesForIntent(intent, context);
      final filtered = allReplies.where((r) => r != text).toList();
      if (filtered.isNotEmpty) {
        final alt = filtered[_random.nextInt(filtered.length)];
        _lastReplyId = '$intent:${alt.hashCode}';
        return alt;
      }
    }
    _lastReplyId = textId;
    return text;
  }

  List<String> _getAllRepliesForIntent(String intent, GameContext context) {
    switch (intent) {
      case 'greeting':
        return _greetingReplies();
      case 'farewell':
        return _farewellReplies();
      case 'gg':
        return _ggReplies(context);
      case 'rematch':
        return _rematchReplies();
      case 'thanks':
        return _thanksReplies();
      case 'praise':
        return _praiseReplies();
      case 'taunt':
        return _tauntReplies(context, 'neutral');
      case 'insult':
        return _insultReplies();
      case 'help':
        return _helpReplies();
      case 'draw_ask':
        return _drawReplies(context);
      case 'bored':
        return _boredReplies();
      case 'chess_question':
        return _chessQuestionReplies();
      case 'profanity':
        return _profanityReplies();
      case 'confused':
      default:
        return _confusedReplies(context);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 8 — TYPING DELAY
  // ══════════════════════════════════════════════════════════════════════════

  int _computeDelay(String text) {
    var ms = _policy.minTypingMs +
        _random.nextInt(_policy.maxTypingMs - _policy.minTypingMs);
    ms += (text.length * _policy.msPerChar).round();

    // Personality modifier
    switch (personality) {
      case BotPersonality.aggressive:
        ms = (ms * 0.8).round(); // fast, impatient
        break;
      case BotPersonality.positional:
        ms = (ms * 1.15).round(); // thoughtful
        break;
      case BotPersonality.trickster:
        ms = (ms * 0.9).round(); // quick
        break;
      case BotPersonality.calm:
        ms = (ms * 1.1).round(); // measured
        break;
      case BotPersonality.showman:
        ms = (ms * 0.85).round(); // enthusiastic
        break;
    }

    return ms.clamp(_policy.minTypingMs, _policy.maxTotalDelayMs);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STEP 9 — CONVERSATION HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  void _recordTurn(String input, String? output, String intent) {
    _history.add(_ConversationTurn(
      speaker: _Speaker.human,
      text: input,
      intent: intent,
      timestamp: DateTime.now(),
    ));
    if (output != null) {
      _history.add(_ConversationTurn(
        speaker: _Speaker.bot,
        text: output,
        intent: intent,
        timestamp: DateTime.now(),
      ));
    }
    _intentCounts[intent] = (_intentCounts[intent] ?? 0) + 1;
    _trimHistory();
  }

  void _trimHistory() {
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
    // Trim intent counts
    if (_intentCounts.length > _maxIntentMemory) {
      final sorted = _intentCounts.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      while (_intentCounts.length > _maxIntentMemory && sorted.isNotEmpty) {
        _intentCounts.remove(sorted.removeAt(0).key);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LANGUAGE DETECTION
  // ══════════════════════════════════════════════════════════════════════════

  String _detectLanguage(String normalized) {
    // Arabic/Urdu script
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(normalized)) {
      return 'ar';
    }

    // Emoji-heavy
    final emojiPattern = RegExp(
      r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}]',
      unicode: true,
    );
    final emojiCount = emojiPattern.allMatches(normalized).length;
    final alphaCount = RegExp(r'[a-z]').allMatches(normalized).length;
    if (emojiCount > alphaCount) return 'emoji';

    // Urdu-Roman detection (common romanized Urdu words)
    const urduRoman = [
      'kya', 'hai', 'nahi', 'haan', 'accha', 'theek', 'bilkul',
      'bakwas', 'shabash', 'maza', 'paagal', 'chalo', 'bhai',
      'yaar', 'salam', 'allah', 'khuda',
    ];
    final words = normalized.split(' ');
    final urduCount = words.where((w) => urduRoman.contains(w)).length;
    if (urduCount > 0 && urduCount >= words.length * 0.3) return 'ur';

    // Default to English
    return 'en';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERSONALITY POLICY DEFAULTS
  // ══════════════════════════════════════════════════════════════════════════

  static ResponsePolicy _personalityPolicy(BotPersonality p) {
    switch (p) {
      case BotPersonality.aggressive:
        return const ResponsePolicy(
          skipChance: 0.06,
          minTypingMs: 600,
          maxTypingMs: 2200,
          msPerChar: 8.0,
        );
      case BotPersonality.positional:
        return const ResponsePolicy(
          skipChance: 0.12,
          minTypingMs: 1000,
          maxTypingMs: 3000,
          msPerChar: 12.0,
        );
      case BotPersonality.trickster:
        return const ResponsePolicy(
          skipChance: 0.05,
          minTypingMs: 700,
          maxTypingMs: 2400,
          msPerChar: 9.0,
        );
      case BotPersonality.calm:
        return const ResponsePolicy(
          skipChance: 0.15,
          minTypingMs: 1200,
          maxTypingMs: 3200,
          msPerChar: 11.0,
        );
      case BotPersonality.showman:
        return const ResponsePolicy(
          skipChance: 0.04,
          minTypingMs: 500,
          maxTypingMs: 2000,
          msPerChar: 7.0,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper types
// ─────────────────────────────────────────────────────────────────────────────

enum _Speaker { human, bot }

class _ConversationTurn {
  final _Speaker speaker;
  final String text;
  final String intent;
  final DateTime timestamp;

  const _ConversationTurn({
    required this.speaker,
    required this.text,
    required this.intent,
    required this.timestamp,
  });
}

class _SkipDecision {
  final bool shouldSkip;
  final String sentiment;

  const _SkipDecision({required this.shouldSkip, required this.sentiment});
}

class _IntentResult {
  final String intent;
  final String source;
  final double confidence;

  const _IntentResult({
    required this.intent,
    required this.source,
    required this.confidence,
  });
}