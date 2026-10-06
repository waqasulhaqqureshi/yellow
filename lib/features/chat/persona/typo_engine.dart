import 'dart:math';

import 'chat_persona.dart';

/// Turns a clean template line into something a human would actually type:
/// slang, dropped apostrophes, lowercase, the occasional fat-fingered word and
/// a trailing "lol"/emoji. All transformations are probabilistic and driven
/// by the bot's [ChatPersona], so a formal bot stays clean while a rash one
/// types like they're late for a bus.
class TypoEngine {
  TypoEngine._();

  static const Map<String, String> _slang = {
    'you': 'u',
    'your': 'ur',
    'are': 'r',
    'why': 'y',
    'okay': 'ok',
    'thanks': 'thx',
    'thank you': 'thx',
    'because': 'cuz',
    'going to': 'gonna',
    'want to': 'wanna',
    'got to': 'gotta',
    'kind of': 'kinda',
    'sort of': 'sorta',
    'do not': 'dont',
    'i am': 'im',
    'it is': 'its',
    'that is': 'thats',
    'what is': 'whats',
    'here is': 'heres',
    'there is': 'theres',
  };

  static const List<String> _fillers = ['lol', 'haha', 'xd', 'lmao', 'heh'];

  static const List<String> _emoji = ['😄', '', '😂', '', '', '😉', '😎', '♟️'];

  /// Humanizes [text] for [persona]. Deterministic given [random].
  static String humanize(
    String text,
    ChatPersona persona,
    Random random,
  ) {
    var out = text;

    // Slang / contractions (phrase-level first, then word-level).
    if (persona.slangRate > 0) {
      _slang.forEach((clean, slang) {
        if (random.nextDouble() < persona.slangRate) {
          final re = RegExp(RegExp.escape(clean), caseSensitive: false);
          out = out.replaceFirstMapped(re, (m) {
            final original = m.group(0)!;
            // Preserve leading capital if the original had one.
            if (original.isNotEmpty &&
                original[0] == original[0].toUpperCase()) {
              return slang[0].toUpperCase() + slang.substring(1);
            }
            return slang;
          });
        }
      });
    }

    // Dropped apostrophes.
    if (persona.slangRate > 0.1 && random.nextDouble() < persona.slangRate) {
      out = out.replaceAll("'", '');
    }

    // Fat-finger a single word.
    if (persona.typoRate > 0) {
      out = _typoOneWord(out, persona.typoRate, random);
    }

    // Lowercase-mostly typing.
    if (persona.style == ChatStyle.rash || persona.style == ChatStyle.salty) {
      if (random.nextDouble() < 0.6) out = _decapitalize(out);
    } else if (persona.typoRate > 0 && random.nextDouble() < 0.3) {
      out = _decapitalize(out);
    }

    // Trailing filler / emoji.
    if (persona.slangRate > 0.25 && random.nextDouble() < persona.slangRate * 0.5) {
      out = '$out ${_fillers[random.nextInt(_fillers.length)]}';
    }
    if (persona.emojiRate > 0 && random.nextDouble() < persona.emojiRate) {
      out = '$out ${_emoji[random.nextInt(_emoji.length)]}';
    }

    return out.trim();
  }

  static String _decapitalize(String s) {
    if (s.isEmpty) return s;
    // Keep the first letter capitalised only sometimes (names etc.).
    return s[0].toLowerCase() + s.substring(1);
  }

  static String _typoOneWord(String text, double rate, Random random) {
    final words = text.split(' ');
    final candidates = <int>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i].replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (w.length >= 5) candidates.add(i);
    }
    if (candidates.isEmpty) return text;
    if (random.nextDouble() > rate) return text;
    final idx = candidates[random.nextInt(candidates.length)];
    final word = words[idx];
    // Strip surrounding punctuation so we only mangle the letters.
    final firstChar = word[0];
    final lastChar = word[word.length - 1];
    final lead = RegExp(r'[^a-zA-Z]').hasMatch(firstChar) ? firstChar : '';
    final trail = RegExp(r'[^a-zA-Z]').hasMatch(lastChar) ? lastChar : '';
    final core = word.substring(lead.length, word.length - trail.length);
    if (core.length < 5) return text;
    final pos = 1 + random.nextInt(core.length - 2);
    final kind = random.nextInt(3);
    String mangled;
    if (kind == 0) {
      // Swap two adjacent letters.
      final chars = core.split('');
      final t = chars[pos];
      chars[pos] = chars[pos + 1];
      chars[pos + 1] = t;
      mangled = chars.join();
    } else if (kind == 1) {
      // Drop a letter.
      mangled = core.substring(0, pos) + core.substring(pos + 1);
    } else {
      // Double a letter.
      mangled = core.substring(0, pos) + core[pos] + core.substring(pos);
    }
    words[idx] = '$lead$mangled$trail';
    return words.join(' ');
  }
}
