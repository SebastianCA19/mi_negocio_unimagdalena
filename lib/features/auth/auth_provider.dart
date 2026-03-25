import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/util/app_constants.dart';

enum AuthStatus { desconocido, autenticado, noAutenticado, expirado }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.desconocido;
  String? _correo;

  AuthStatus get status => _status;
  String? get correo => _correo;
  bool get isAutenticado => _status == AuthStatus.autenticado;

  // Claves en SharedPreferences
  static const String _keyCorreo = 'auth_correo';
  static const String _keyFechaExpiracion = 'auth_fecha_expiracion';
  static const String _keyActiva = 'auth_activa';

  // Verifica si hay una sesion local valida al iniciar la app
  Future<void> verificarSesionLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final activa = prefs.getBool(_keyActiva) ?? false;
    final correoGuardado = prefs.getString(_keyCorreo);
    final expiracionStr = prefs.getString(_keyFechaExpiracion);

    if (!activa || correoGuardado == null || expiracionStr == null) {
      _status = AuthStatus.noAutenticado;
      notifyListeners();
      return;
    }

    final expiracion = DateTime.tryParse(expiracionStr);
    if (expiracion == null || DateTime.now().isAfter(expiracion)) {
      // Sesion expirada
      await _limpiarSesion(prefs);
      _status = AuthStatus.expirado;
      notifyListeners();
      return;
    }

    // Sesion valida
    _correo = correoGuardado;
    _status = AuthStatus.autenticado;
    notifyListeners();
  }

  // Guarda la sesion luego de verificar con el servidor institucional
  Future<void> guardarSesion(String correo) async {
    final prefs = await SharedPreferences.getInstance();
    final expiracion = DateTime.now().add(
      const Duration(days: AppConstants.vigenciaSesionDias),
    );

    await prefs.setString(_keyCorreo, correo);
    await prefs.setString(_keyFechaExpiracion, expiracion.toIso8601String());
    await prefs.setBool(_keyActiva, true);

    _correo = correo;
    _status = AuthStatus.autenticado;
    notifyListeners();
  }

  // Cierra sesion manualmente (los datos NO se borran)
  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await _limpiarSesion(prefs);
    _status = AuthStatus.noAutenticado;
    _correo = null;
    notifyListeners();
  }

  Future<void> _limpiarSesion(SharedPreferences prefs) async {
    await prefs.remove(_keyCorreo);
    await prefs.remove(_keyFechaExpiracion);
    await prefs.setBool(_keyActiva, false);
  }

  // Valida formato del correo institucional
  static bool esCorreoValido(String correo) {
    return correo.trim().endsWith(AppConstants.dominioInstitucional) &&
        correo.trim().length > AppConstants.dominioInstitucional.length;
  }
}