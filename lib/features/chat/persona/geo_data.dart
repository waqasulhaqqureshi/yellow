import 'dart:math';

/// Per-country cities + demonyms so a bot can answer "where are you from?"
/// and "which city?" in a believable, consistent way. Covers every ISO the
/// bot generator can produce ([BotNamePool.weightedIsos]); unknown ISOs fall
/// back to a generic answer rather than crashing.
class GeoData {
  GeoData._();

  static const Map<String, List<String>> cities = {
    'PK': ['Lahore', 'Karachi', 'Islamabad', 'Faisalabad', 'Multan', 'Peshawar'],
    'IN': ['Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad', 'Chennai', 'Kolkata'],
    'US': ['New York', 'Austin', 'Chicago', 'Seattle', 'Denver', 'Miami'],
    'GB': ['London', 'Manchester', 'Leeds', 'Glasgow', 'Bristol', 'Liverpool'],
    'DE': ['Berlin', 'Munich', 'Hamburg', 'Cologne', 'Frankfurt', 'Leipzig'],
    'FR': ['Paris', 'Lyon', 'Marseille', 'Toulouse', 'Nice', 'Bordeaux'],
    'BR': ['São Paulo', 'Rio de Janeiro', 'Salvador', 'Brasília', 'Curitiba'],
    'TR': ['Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Antalya'],
    'ES': ['Madrid', 'Barcelona', 'Valencia', 'Seville', 'Bilbao'],
    'IT': ['Rome', 'Milan', 'Naples', 'Turin', 'Florence', 'Bologna'],
    'RU': ['Moscow', 'Saint Petersburg', 'Kazan', 'Novosibirsk', 'Sochi'],
    'UA': ['Kyiv', 'Lviv', 'Odesa', 'Kharkiv', 'Dnipro'],
    'PL': ['Warsaw', 'Kraków', 'Gdańsk', 'Wrocław', 'Poznań'],
    'NL': ['Amsterdam', 'Rotterdam', 'Utrecht', 'Eindhoven', 'The Hague'],
    'SE': ['Stockholm', 'Gothenburg', 'Malmö', 'Uppsala'],
    'EG': ['Cairo', 'Alexandria', 'Giza', 'Luxor', 'Aswan'],
    'NG': ['Lagos', 'Abuja', 'Kano', 'Ibadan', 'Port Harcourt'],
    'ZA': ['Johannesburg', 'Cape Town', 'Durban', 'Pretoria'],
    'AU': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
    'CA': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa'],
    'MX': ['Mexico City', 'Guadalajara', 'Monterrey', 'Puebla', 'Cancún'],
    'AR': ['Buenos Aires', 'Córdoba', 'Rosario', 'Mendoza'],
    'JP': ['Tokyo', 'Osaka', 'Kyoto', 'Nagoya', 'Sapporo', 'Fukuoka'],
    'KR': ['Seoul', 'Busan', 'Incheon', 'Daegu', 'Daejeon'],
    'CN': ['Beijing', 'Shanghai', 'Shenzhen', 'Guangzhou', 'Chengdu'],
    'IR': ['Tehran', 'Isfahan', 'Shiraz', 'Mashhad', 'Tabriz'],
    'SA': ['Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam'],
    'AE': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Al Ain'],
    'ID': ['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Bali'],
    'MY': ['Kuala Lumpur', 'Penang', 'Johor Bahru', 'Ipoh'],
    'PH': ['Manila', 'Quezon City', 'Davao', 'Cebu', 'Makati'],
    'BD': ['Dhaka', 'Chittagong', 'Sylhet', 'Khulna'],
    'LK': ['Colombo', 'Kandy', 'Galle', 'Jaffna'],
    'NP': ['Kathmandu', 'Pokhara', 'Lalitpur', 'Biratnagar'],
    'GR': ['Athens', 'Thessaloniki', 'Patras', 'Heraklion'],
    'PT': ['Lisbon', 'Porto', 'Braga', 'Coimbra'],
  };

  /// How a bot refers to its own country ("from Pakistan", "here in Brazil").
  static const Map<String, String> countryName = {
    'PK': 'Pakistan',
    'IN': 'India',
    'US': 'the USA',
    'GB': 'the UK',
    'DE': 'Germany',
    'FR': 'France',
    'BR': 'Brazil',
    'TR': 'Turkey',
    'ES': 'Spain',
    'IT': 'Italy',
    'RU': 'Russia',
    'UA': 'Ukraine',
    'PL': 'Poland',
    'NL': 'the Netherlands',
    'SE': 'Sweden',
    'EG': 'Egypt',
    'NG': 'Nigeria',
    'ZA': 'South Africa',
    'AU': 'Australia',
    'CA': 'Canada',
    'MX': 'Mexico',
    'AR': 'Argentina',
    'JP': 'Japan',
    'KR': 'South Korea',
    'CN': 'China',
    'IR': 'Iran',
    'SA': 'Saudi Arabia',
    'AE': 'the UAE',
    'ID': 'Indonesia',
    'MY': 'Malaysia',
    'PH': 'the Philippines',
    'BD': 'Bangladesh',
    'LK': 'Sri Lanka',
    'NP': 'Nepal',
    'GR': 'Greece',
    'PT': 'Portugal',
  };

  static String cityFor(String iso, Random random) {
    final list = cities[iso];
    if (list == null || list.isEmpty) return 'my city';
    return list[random.nextInt(list.length)];
  }

  static String countryFor(String iso) => countryName[iso] ?? 'my country';

  static bool has(String iso) => cities.containsKey(iso);
}
