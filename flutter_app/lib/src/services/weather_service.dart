import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Open-Meteo weather service — free, no API key, client-direct
/// (Render backend touch pannadhu, cold start problem illa).
/// MUKKIYAM: fresh Dio use pannuvom — ApiClient oda Dio use panna
/// Bearer token open-meteo ku poidum.
class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static const _districtKey = 'weather_district';
  static const defaultDistrict = 'சென்னை';

  /// TN major districts — [latitude, longitude]
  static const Map<String, List<double>> districts = {
    'சென்னை': [13.0827, 80.2707],
    'கோயம்புத்தூர்': [11.0168, 76.9558],
    'மதுரை': [9.9252, 78.1198],
    'திருச்சி': [10.7905, 78.7047],
    'சேலம்': [11.6643, 78.1460],
    'திருநெல்வேலி': [8.7139, 77.7567],
    'ஈரோடு': [11.3410, 77.7172],
    'வேலூர்': [12.9165, 79.1325],
    'தஞ்சாவூர்': [10.7870, 79.1378],
    'திண்டுக்கல்': [10.3624, 77.9695],
    'கடலூர்': [11.7480, 79.7714],
    'விழுப்புரம்': [11.9401, 79.4861],
    'கன்னியாகுமரி': [8.0883, 77.5385],
    'நாமக்கல்': [11.2189, 78.1674],
    'கரூர்': [10.9601, 78.0766],
    'விருதுநகர்': [9.5680, 77.9624],
  };

  Future<String> getSavedDistrict() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_districtKey);
    return (saved != null && districts.containsKey(saved)) ? saved : defaultDistrict;
  }

  Future<void> saveDistrict(String district) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_districtKey, district);
  }

  /// Returns:
  /// {
  ///   'district': String,
  ///   'temp': double, 'humidity': int, 'wind': double, 'code': int,
  ///   'daily': [ {'date': DateTime, 'min': double, 'max': double,
  ///               'code': int, 'rain_chance': int}, ... 7 days ]
  /// }
  Future<Map<String, dynamic>> fetchWeather({String? district}) async {
    final d = district ?? await getSavedDistrict();
    final coords = districts[d] ?? districts[defaultDistrict]!;

    final res = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': coords[0],
        'longitude': coords[1],
        'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
        'daily': 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max',
        'timezone': 'Asia/Kolkata',
        'forecast_days': 7,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;

    final dates = List<String>.from(daily['time'] as List);
    final maxT = List<num>.from(daily['temperature_2m_max'] as List);
    final minT = List<num>.from(daily['temperature_2m_min'] as List);
    final codes = List<num>.from(daily['weather_code'] as List);
    final rain = List<num>.from(daily['precipitation_probability_max'] as List);

    return {
      'district': d,
      'temp': (current['temperature_2m'] as num).toDouble(),
      'humidity': (current['relative_humidity_2m'] as num).toInt(),
      'wind': (current['wind_speed_10m'] as num).toDouble(),
      'code': (current['weather_code'] as num).toInt(),
      'daily': List.generate(dates.length, (i) => {
        'date': DateTime.parse(dates[i]),
        'min': minT[i].toDouble(),
        'max': maxT[i].toDouble(),
        'code': codes[i].toInt(),
        'rain_chance': rain[i].toInt(),
      }),
    };
  }

  /// WMO weather code → Tamil description
  static String describe(int code) {
    if (code == 0) return 'தெளிவான வானம்';
    if (code <= 2) return 'ஓரளவு மேகம்';
    if (code == 3) return 'மேகமூட்டம்';
    if (code <= 48) return 'மூடுபனி';
    if (code <= 57) return 'தூறல்';
    if (code <= 67) return 'மழை';
    if (code <= 77) return 'பனி';
    if (code <= 82) return 'கன மழை';
    if (code <= 86) return 'பனிப்பொழிவு';
    return 'இடி மழை';
  }

  static String dayName(DateTime date) {
    const names = ['திங்கள்', 'செவ்வாய்', 'புதன்', 'வியாழன்', 'வெள்ளி', 'சனி', 'ஞாயிறு'];
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'இன்று';
    }
    return names[date.weekday - 1];
  }
}
