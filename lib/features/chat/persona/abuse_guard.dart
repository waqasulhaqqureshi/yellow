import 'dart:math';

import 'chat_persona.dart';

/// Knows the swear words (Roman Urdu / Hindi + English + common shorthand)
/// so the bots can 1) star them out and 2) scold the sender instead of
/// ignoring or escalating. Detection only — the bots never *use* these words.
class AbuseGuard {
  AbuseGuard._();

  /// Ordered longest-first so multi-word forms match before their parts.
  static const List<String> _lexicon = [
    // --- Roman Urdu / Hindi ---
    'bhen ke lode',
    'behn ke lode',
    'behn k lode',
    'behn k lorra',
    'bhen k lorra',
    'bhen ke lora',
    'madar chod',
    'madarchod',
    'maadarchood',
    'behanchod',
    'bhenchod',
    'bhen chod',
    'bhosdike',
    'bhosdi ke',
    'bhosdi',
    'chutiya',
    'chutiye',
    'chutiyo',
    'haramzada',
    'harami',
    'kamini',
    'kamina',
    'kuttiya',
    'kutte',
    'kutta',
    'randi',
    'chinaal',
    'chinal',
    'laude',
    'loda',
    'lund',
    'gaand mara',
    'gand mara',
    'gaand',
    'saale',
    'sale kutte',
    'tu mar ja',
    'mar ja sale',
    // --- shorthand / masked ---
    'b*hnchod',
    'bkl',
    'mkl',
    // --- English ---
    'motherfucker',
    'mother fucker',
    'fucking',
    'fucker',
    'fuck',
    'bitch',
    'bastard',
    'asshole',
    'dickhead',
    'dick head',
    'shit',
    'stfu',
  ];

  static final List<RegExp> _patterns = _lexicon
      .map((w) => RegExp(
            r'(?<![a-z])' + RegExp.escape(w) + r'(?![a-z])',
            caseSensitive: false,
          ))
      .toList();

  static bool containsAbuse(String text) {
    final t = text.toLowerCase();
    for (final p in _patterns) {
      if (p.hasMatch(t)) return true;
    }
    return false;
  }

  /// Stars every abusive term it recognises ("behn k lorra" → "***********").
  static String censor(String text) {
    var out = text;
    for (final p in _patterns) {
      out = out.replaceAllMapped(p, (m) => '*' * m.group(0)!.length);
    }
    return out;
  }

  /// Persona-flavoured scolds — the bots KNOW these words, and this is what
  /// they say back instead of repeating them.
  static String reprimand(ChatStyle style, Random rng) {
    final pool = switch (style) {
      ChatStyle.formal => const [
          "Please keep the conversation respectful.",
          "I'd appreciate cleaner language.",
          "Let's keep it civil, please.",
          "That word is not welcome here.",
        ],
      ChatStyle.salty => const [
          "gali? pehle khelna seekh lo",
          "tameez bhi koi cheez hoti hai",
          "gussa thanda karo champion",
          "aisi baatein mat karo, game khelo",
          "stars lag gaye tumhari baat pe",
        ],
      ChatStyle.rash => const [
          "gali nahi. bas.",
          "language. abhi.",
          "chup kar aur khel",
          "respect se baat kar",
        ],
      _ => const [
          "bhai gali kyu de rhe ho? ap ko tameez nhi hai",
          "yaar tameez se baat karo",
          "gali nahi yaar, dosti se khelo",
          "hey, language please",
          "no abusing here yaar",
          "respect rakho bhai, phir baat karte hain",
          "gali se game nahi jeeti jati",
        ],
    };
    return pool[rng.nextInt(pool.length)];
  }
}

/// Cheap Roman Urdu / Hindi sniffing ("tum kya kar rhe ho", "kahan se ho
/// bhai") — counted keyword hits, no language packages needed.
class RomanUrdu {
  RomanUrdu._();

  static const Set<String> _markers = {
    'kya', 'ky', 'kar', 'kare', 'karo', 'karte', 'rhe', 'rha', 'rhi', 'raha',
    'rahi', 'ho', 'bhai', 'yaar', 'kahan', 'tum', 'tumhara', 'aap', 'apko',
    'theek', 'thik', 'hai', 'hain', 'nahi', 'nhi', 'mera', 'meri', 'chalo',
    'acha', 'accha', 'haan', 'han', 'chal', 'khel', 'khelo', 'khelte',
    'jeet', 'haar', 'gussa', 'tameez', 'gali', 'kyun', 'kyu', 'kb', 'kab',
    'kal', 'aaj', 'raat', 'subah', 'chai', 'khana', 'maza', 'mazaa', 'dil',
    'dimagh', 'shukar', 'alhamdulillah', 'insha', 'sunao', 'batayein',
    'rehte', 'kaun', 'kaisa', 'kaisi', 'karta', 'karti', 'batao',
  };

  /// Two or more marker words → treat the message as Roman Urdu.
  static bool detect(String text) {
    var hits = 0;
    for (final w in text.toLowerCase().split(RegExp(r'[^a-z]+'))) {
      if (w.length > 1 && _markers.contains(w)) hits++;
      if (hits >= 2) return true;
    }
    return false;
  }
}
