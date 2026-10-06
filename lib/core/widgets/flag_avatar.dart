import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:random_avatar/random_avatar.dart';

/// Multicultural generated avatar. NOTE: the file import is all-lowercase
/// (`random_avatar.dart`) — the capital-R variant only resolves on
/// case-insensitive filesystems (Windows) and breaks portable builds.
class BotAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const BotAvatar({super.key, required this.seed, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: RandomAvatar(seed, height: size, width: size),
      ),
    );
  }
}

/// Country flag from country_pickers with an emoji fallback.
class CountryFlag extends StatelessWidget {
  final String isoCode;
  final double width;
  final double height;

  const CountryFlag({
    super.key,
    required this.isoCode,
    this.width = 30,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    Country? country;
    try {
      country = CountryPickerUtils.getCountryByIsoCode(isoCode);
    } catch (_) {
      country = null;
    }
    if (country == null) {
      return Text(_emoji(isoCode), style: const TextStyle(fontSize: 20));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.asset(
        CountryPickerUtils.getFlagImageAssetPath(country.isoCode),
        package: 'country_pickers',
        width: width,
        height: height,
        fit: BoxFit.fill,
        errorBuilder: (context, error, stackTrace) =>
            Text(_emoji(isoCode), style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  static String _emoji(String iso) {
    if (iso.length != 2) return '🏳️';
    final upper = iso.toUpperCase();
    final c0 = upper.codeUnitAt(0);
    final c1 = upper.codeUnitAt(1);
    if (c0 < 65 || c0 > 90 || c1 < 65 || c1 > 90) return '🏳️';
    return String.fromCharCode(0x1F1E6 + c0 - 65) +
        String.fromCharCode(0x1F1E6 + c1 - 65);
  }
}
