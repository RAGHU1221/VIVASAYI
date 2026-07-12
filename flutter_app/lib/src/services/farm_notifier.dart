import 'package:flutter/foundation.dart';

class FarmNotifier extends ChangeNotifier {
  FarmNotifier._();

  static final FarmNotifier instance = FarmNotifier._();

  final List<Map<String, dynamic>> _farms = [];

  List<Map<String, dynamic>> get farms => List.unmodifiable(_farms);

  void addOrUpdate(Map<String, dynamic> farm) {
    final idx = _farms.indexWhere((f) => f['id'] == farm['id']);
    if (idx >= 0) {
      _farms[idx] = farm;
    } else {
      _farms.insert(0, farm);
    }
    notifyListeners();
  }

  void replaceAll(List<Map<String, dynamic>> farms) {
    _farms
      ..clear()
      ..addAll(farms);
    notifyListeners();
  }

  void removeById(int id) {
    _farms.removeWhere((f) => f['id'] == id);
    notifyListeners();
  }
}
