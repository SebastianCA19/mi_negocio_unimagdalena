import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Obtiene un identificador único y estable para el dispositivo.
///
/// Estrategia:
/// - Android  → usa [androidId] (persiste entre reinstalaciones en la misma ROM).
/// - iOS      → usa [identifierForVendor] (cambia si el usuario borra la app,
///              por lo que se persiste en SharedPreferences como fallback).
/// - Otros    → genera un UUID v4 y lo persiste en SharedPreferences.
class DeviceUuidService {
  static const _prefKey = 'device_uuid_persisted';

  static Future<String> getDeviceUuid() async {
    if (Platform.isAndroid) {
      return _getAndroidUuid();
    } else if (Platform.isIOS) {
      return _getIosUuid();
    } else {
      return _getOrCreatePersistedUuid();
    }
  }

  // ── Android ───────────────────────────────────────────────────────────────

  static Future<String> _getAndroidUuid() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final id = info.id; // Build.ID — estable en la misma ROM
      if (id.isNotEmpty) return id;
    } catch (_) {}
    // Fallback: UUID persistido
    return _getOrCreatePersistedUuid();
  }

  // ── iOS ───────────────────────────────────────────────────────────────────

  static Future<String> _getIosUuid() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      final id = info.identifierForVendor ?? '';
      if (id.isNotEmpty) {
        // Persistir para sobrevivir a reinstalaciones
        final prefs = await SharedPreferences.getInstance();
        if (!prefs.containsKey(_prefKey)) {
          await prefs.setString(_prefKey, id);
        }
        return prefs.getString(_prefKey) ?? id;
      }
    } catch (_) {}
    return _getOrCreatePersistedUuid();
  }

  // ── Fallback: UUID generado y persistido ──────────────────────────────────

  static Future<String> _getOrCreatePersistedUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = Uuid().v4();
    await prefs.setString(_prefKey, generated);
    return generated;
  }
}