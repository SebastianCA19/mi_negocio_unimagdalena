import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/util/app_constants.dart';

enum AuthStatus { desconocido, autenticado, noAutenticado, expirado }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.desconocido;
  String? _correo;
  String? _nombre;
  String? _apellido;

  AuthStatus get status => _status;
  String? get correo => _correo;
  String? get nombre => _nombre;
  String? get apellido => _apellido;
  bool get isAutenticado => _status == AuthStatus.autenticado;

  /// Nombre completo. Si no hay nombre guardado, devuelve el correo.
  String get nombreCompleto {
    final n = _nombre?.trim() ?? '';
    final a = _apellido?.trim() ?? '';
    if (n.isEmpty && a.isEmpty) return _correo ?? '';
    return '$n $a'.trim();
  }

  /// Iniciales para el avatar (máximo 2 caracteres, mayúsculas).
  String get iniciales {
    final n = _nombre?.trim() ?? '';
    final a = _apellido?.trim() ?? '';
    if (n.isEmpty && a.isEmpty) {
      // Fallback: primera letra del correo
      return (_correo?.isNotEmpty == true) ? _correo![0].toUpperCase() : '?';
    }
    final primeraLetraNombre = n.isNotEmpty ? n[0].toUpperCase() : '';
    final primeraLetraApellido = a.isNotEmpty ? a[0].toUpperCase() : '';
    return '$primeraLetraNombre$primeraLetraApellido';
  }

  // Claves en SharedPreferences
  static const _keyCorreo = 'auth_correo';
  static const _keyNombre = 'auth_nombre';
  static const _keyApellido = 'auth_apellido';
  static const _keyFechaExpiracion = 'auth_fecha_expiracion';
  static const _keyActiva = 'auth_activa';

  /// Verifica si hay una sesion local valida al iniciar la app.
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
      await _limpiarSesion(prefs);
      _status = AuthStatus.expirado;
      notifyListeners();
      return;
    }

    _correo = correoGuardado;
    _nombre = prefs.getString(_keyNombre) ?? '';
    _apellido = prefs.getString(_keyApellido) ?? '';
    _status = AuthStatus.autenticado;
    notifyListeners();
  }

  /// Guarda la sesion luego de verificar con el servidor institucional.
  /// [nombre] y [apellido] deben obtenerse del proveedor de identidad.
  /// Mientras el login es simulado se pasan valores hardcodeados.
  Future<void> guardarSesion(
    String correo, {
    String nombre = '',
    String apellido = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiracion = DateTime.now().add(
      const Duration(days: AppConstants.vigenciaSesionDias),
    );

    await prefs.setString(_keyCorreo, correo);
    await prefs.setString(_keyNombre, nombre);
    await prefs.setString(_keyApellido, apellido);
    await prefs.setString(_keyFechaExpiracion, expiracion.toIso8601String());
    await prefs.setBool(_keyActiva, true);

    _correo = correo;
    _nombre = nombre;
    _apellido = apellido;
    _status = AuthStatus.autenticado;
    notifyListeners();
  }

  /// Cierra sesion manualmente (los datos de negocio NO se borran).
  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await _limpiarSesion(prefs);
    _status = AuthStatus.noAutenticado;
    _correo = null;
    _nombre = null;
    _apellido = null;
    notifyListeners();
  }

  Future<void> _limpiarSesion(SharedPreferences prefs) async {
    await prefs.remove(_keyCorreo);
    await prefs.remove(_keyNombre);
    await prefs.remove(_keyApellido);
    await prefs.remove(_keyFechaExpiracion);
    await prefs.setBool(_keyActiva, false);
  }

  /// Valida formato del correo institucional.
  static bool esCorreoValido(String correo) {
    return correo.trim().endsWith(AppConstants.dominioInstitucional) &&
        correo.trim().length > AppConstants.dominioInstitucional.length;
  }
}
