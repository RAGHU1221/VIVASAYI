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
    'அரியலூர்': [11.1401, 79.0782],
    'செங்கல்பட்டு': [12.6819, 79.9888],
    'சென்னை': [13.0827, 80.2707],
    'கோயம்புத்தூர்': [11.0168, 76.9558],
    'கடலூர்': [11.7480, 79.7714],
    'தர்மபுரி': [12.1211, 78.1582],
    'திண்டுக்கல்': [10.3624, 77.9695],
    'ஈரோடு': [11.3410, 77.7172],
    'கள்ளக்குறிச்சி': [11.7383, 78.9571],
    'காஞ்சிபுரம்': [12.8342, 79.7036],
    'கன்னியாகுமரி': [8.0883, 77.5385],
    'கரூர்': [10.9601, 78.0766],
    'கிருஷ்ணகிரி': [12.5266, 78.2141],
    'மதுரை': [9.9252, 78.1198],
    'மயிலாடுதுறை': [11.1014, 79.6583],
    'நாகப்பட்டினம்': [10.7672, 79.8449],
    'நாமக்கல்': [11.2189, 78.1674],
    'நீலகிரி': [11.4064, 76.6932],
    'பெரம்பலூர்': [11.2342, 78.8807],
    'புதுக்கோட்டை': [10.3833, 78.8001],
    'ராமநாதபுரம்': [9.3639, 78.8395],
    'ராணிப்பேட்டை': [12.9316, 79.3333],
    'சேலம்': [11.6643, 78.1460],
    'சிவகங்கை': [9.8433, 78.4809],
    'தென்காசி': [8.9594, 77.3151],
    'தஞ்சாவூர்': [10.7870, 79.1378],
    'தேனி': [10.0104, 77.4768],
    'தூத்துக்குடி': [8.7642, 78.1348],
    'திருச்சி': [10.7905, 78.7047],
    'திருநெல்வேலி': [8.7139, 77.7567],
    'திருப்பத்தூர்': [12.4963, 78.5730],
    'திருப்பூர்': [11.1085, 77.3411],
    'திருவள்ளூர்': [13.1439, 79.9086],
    'திருவண்ணாமலை': [12.2253, 79.0747],
    'திருவாரூர்': [10.7726, 79.6368],
    'வேலூர்': [12.9165, 79.1325],
    'விழுப்புரம்': [11.9401, 79.4861],
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

  /// GPS coordinates la irundhu weather — location name ku
  /// nearest district kandupidikkum.
  Future<Map<String, dynamic>> fetchWeatherByCoords(double lat, double lon) async {
    return _fetch(lat, lon, _nearestDistrict(lat, lon), gps: true);
  }

  /// GPS coords ku nearest TN district (simple squared-distance)
  static String _nearestDistrict(double lat, double lon) {
    String best = defaultDistrict;
    double bestDist = double.infinity;
    districts.forEach((name, c) {
      final d = (c[0] - lat) * (c[0] - lat) + (c[1] - lon) * (c[1] - lon);
      if (d < bestDist) {
        bestDist = d;
        best = name;
      }
    });
    return best;
  }

  /// Returns:
  /// {
  ///   'district': String, 'gps': bool,
  ///   'temp': double, 'humidity': int, 'wind': double, 'code': int,
  ///   'daily': [ {'date': DateTime, 'min': double, 'max': double,
  ///               'code': int, 'rain_chance': int}, ... 7 days ]
  /// }
  Future<Map<String, dynamic>> fetchWeather({String? district}) async {
    final d = district ?? await getSavedDistrict();
    final coords = districts[d] ?? districts[defaultDistrict]!;
    return _fetch(coords[0], coords[1], d);
  }

  Future<Map<String, dynamic>> _fetch(double lat, double lon, String label,
      {bool gps = false}) async {

    final res = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
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
      'district': label,
      'gps': gps,
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
