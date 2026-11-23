import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:rutina_fit/models/rest_time.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para persistencia de tiempos de descanso personalizados.
class RestTimeService {
  static const _storageKey = 'custom_rest_times';
  static late SharedPreferences _prefs;
  static List<RestTime> _customTimes = [];

  /// Inicializa el servicio y carga los tiempos guardados.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadCustomTimes();
    } catch (e) {
      debugPrint('Error inicializando RestTimeService: $e');
    }
  }

  /// Carga los tiempos personalizados desde storage.
  static Future<void> _loadCustomTimes() async {
    try {
      final json = _prefs.getString(_storageKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _customTimes = list.map((m) => RestTime.fromMap(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error cargando tiempos personalizados: $e');
    }
  }

  /// Guarda los tiempos personalizados en storage.
  static Future<void> _saveToStorage() async {
    try {
      final json = jsonEncode(_customTimes.map((t) => t.toMap()).toList());
      await _prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Error guardando tiempos personalizados: $e');
    }
  }

  /// Obtiene todos los tiempos personalizados.
  static List<RestTime> getCustomTimes() => List.unmodifiable(_customTimes);

  /// Crea y guarda un nuevo tiempo personalizado.
  static Future<RestTime> addCustomTime(int seconds) async {
    final time = RestTime.create(seconds: seconds, isCustom: true);
    _customTimes.add(time);
    await _saveToStorage();
    return time;
  }

  /// Actualiza un tiempo personalizado existente.
  static Future<bool> updateCustomTime(String id, int seconds) async {
    final index = _customTimes.indexWhere((t) => t.id == id);
    if (index == -1) return false;
    _customTimes[index] = _customTimes[index].copyWith(seconds: seconds);
    await _saveToStorage();
    return true;
  }

  /// Elimina un tiempo personalizado.
  static Future<bool> deleteCustomTime(String id) async {
    final initialLength = _customTimes.length;
    _customTimes.removeWhere((t) => t.id == id);
    if (_customTimes.length != initialLength) {
      await _saveToStorage();
      return true;
    }
    return false;
  }

  /// Obtiene un tiempo por ID.
  static RestTime? getCustomTimeById(String id) =>
      _customTimes.cast<RestTime?>().firstWhere((t) => t?.id == id, orElse: () => null);
}
