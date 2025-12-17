import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clave.dart';

class ClavesCacheService {
  static const String _cacheKeyPrefix = 'claves_cache_';
  static const String _cacheTimestampPrefix = 'claves_timestamp_';
  static const Duration _cacheExpiration = Duration(hours: 24);

  Future<void> cacheClaves(String medioId, List<Clave> claves) async {
    final prefs = await SharedPreferences.getInstance();

    final clavesJson = claves.map((c) => {
      'id': c.id,
      'codigo': c.codigo,
      'descripcion': c.descripcion,
      'tipo': c.tipo,
      'medioId': c.medioId,
      'color': c.color,
      'icono': c.icono,
      'orden': c.orden,
      'isActive': c.isActive,
    }).toList();

    await prefs.setString('$_cacheKeyPrefix$medioId', jsonEncode(clavesJson));
    await prefs.setInt(
      '$_cacheTimestampPrefix$medioId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<Clave>?> getCachedClaves(String medioId) async {
    final prefs = await SharedPreferences.getInstance();

    final cachedData = prefs.getString('$_cacheKeyPrefix$medioId');
    final timestamp = prefs.getInt('$_cacheTimestampPrefix$medioId');

    if (cachedData == null || timestamp == null) {
      return null;
    }

    // Check if cache is expired
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _cacheExpiration) {
      return null;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.map((json) => Clave.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasCachedClaves(String medioId) async {
    final claves = await getCachedClaves(medioId);
    return claves != null && claves.isNotEmpty;
  }

  Future<void> clearCache(String medioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$medioId');
    await prefs.remove('$_cacheTimestampPrefix$medioId');
  }

  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_cacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
