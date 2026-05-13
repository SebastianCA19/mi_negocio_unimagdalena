import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Resultado de la verificación institucional ────────────────────────────────

enum AuthCheckResult {
  /// Correo no tiene el dominio institucional
  correoInvalido,

  /// Sin conexión a internet
  sinConexion,

  /// Error inesperado del servidor
  errorServidor,

  /// El correo no existe en la base de datos institucional
  correoNoEncontrado,

  /// UUID en BD es null → primer dispositivo, hay que vincularlo
  dispositivoSinVincular,

  /// El UUID del dispositivo coincide con el de la BD → OK
  dispositivoVinculado,

  /// El UUID NO coincide → dispositivo diferente al registrado
  dispositivoDiferente,

  /// El email no coincide con el UUID registrado para este dispositivo
  emailNoCorresponde,
}

class EstudianteInfo {
  final String email;
  final String firstName;
  final String? middleName;
  final String firstSurname;
  final String? secondSurname;
  final String? deviceUuid;

  EstudianteInfo({
    required this.email,
    required this.firstName,
    this.middleName,
    required this.firstSurname,
    this.secondSurname,
    this.deviceUuid,
  });

  String get nombreCompleto {
    final partes = [
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName,
      firstSurname,
      if (secondSurname != null && secondSurname!.isNotEmpty) secondSurname,
    ];
    return partes.join(' ');
  }

  String get primerNombre => firstName;
  String get primerApellido => firstSurname;

  factory EstudianteInfo.fromJson(Map<String, dynamic> json) {
    return EstudianteInfo(
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      middleName: json['middle_name'] as String?,
      firstSurname: json['first_surname'] as String,
      secondSurname: json['second_surname'] as String?,
      deviceUuid: json['device_uuid'] as String?,
    );
  }
}

class AuthCheckResponse {
  final AuthCheckResult result;
  final EstudianteInfo? estudiante;
  final String? mensajeError;

  AuthCheckResponse({
    required this.result,
    this.estudiante,
    this.mensajeError,
  });
}

// ── Servicio principal ────────────────────────────────────────────────────────

class AuthService {
  static String get _supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      (throw Exception('Falta SUPABASE_URL en el archivo .env'));

  static String get _supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      (throw Exception('Falta SUPABASE_PUBLISHABLE_KEY en el archivo .env'));

  static String get _tableName =>
      dotenv.env['TABLE_NAME'] ??
      (throw Exception('Falta TABLE_NAME en el archivo .env'));

  static const Duration _timeout = Duration(seconds: 10);

  static Future<void> initializeSupabase() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabasePublishableKey,
    );
  }

  // ── Verificación principal ─────────────────────────────────────────────────

  /// Verifica el correo y el UUID del dispositivo contra Supabase.
  ///
  /// Flujo:
  /// 1. Validación de formato de correo (offline)
  /// 2. Búsqueda del correo en la BD institucional
  ///    a. No encontrado → [AuthCheckResult.correoNoEncontrado]
  /// 3. Si device_uuid en BD es null → [AuthCheckResult.dispositivoSinVincular]
  /// 4. Si device_uuid en BD == [deviceUuid] del dispositivo
  ///    → [AuthCheckResult.dispositivoVinculado]
  /// 5. Si device_uuid en BD != [deviceUuid]
  ///    → buscar si el deviceUuid pertenece a otro registro
  ///      - Sí: [AuthCheckResult.emailNoCorresponde]
  ///      - No: [AuthCheckResult.dispositivoDiferente]
  static Future<AuthCheckResponse> verificarAcceso({
    required String email,
    required String deviceUuid,
  }) async {
    try {
      // ── 1. Buscar el registro por email ──────────────────────────────────
      final List<dynamic> rowsEmail = await Supabase.instance.client
          .from(_tableName)
          .select()
          .eq('email', email.trim().toLowerCase())
          .limit(1)
          .timeout(_timeout) as List<dynamic>;

      // ── 2. Correo no existe en la BD ─────────────────────────────────────
      if (rowsEmail.isEmpty) {
        return AuthCheckResponse(result: AuthCheckResult.correoNoEncontrado);
      }

      final estudiante =
          EstudianteInfo.fromJson(rowsEmail.first as Map<String, dynamic>);

      // ── 3. Sin UUID vinculado → primer dispositivo ───────────────────────
      if (estudiante.deviceUuid == null || estudiante.deviceUuid!.isEmpty) {
        return AuthCheckResponse(
          result: AuthCheckResult.dispositivoSinVincular,
          estudiante: estudiante,
        );
      }

      // ── 4. UUID coincide → acceso permitido ──────────────────────────────
      if (estudiante.deviceUuid == deviceUuid) {
        return AuthCheckResponse(
          result: AuthCheckResult.dispositivoVinculado,
          estudiante: estudiante,
        );
      }

      // ── 5. UUID no coincide → verificar si el UUID ya está registrado
      //       bajo otro email (para dar mejor mensaje de error)

      final List<dynamic> responseUuid = await Supabase.instance.client
          .from(_tableName)
          .select()
          .eq('device_uuid', deviceUuid)
          .limit(1)
          .timeout(_timeout) as List<dynamic>;

      if (responseUuid.isNotEmpty) {
        final List<dynamic> rowsUuid = jsonDecode(responseUuid.first) as List;

        if (rowsUuid.isNotEmpty) {
          // Este dispositivo ya está vinculado a otro correo
          return AuthCheckResponse(
            result: AuthCheckResult.emailNoCorresponde,
            estudiante: estudiante,
          );
        }
      }

      // El UUID de este dispositivo no está en ningún registro,
      // pero el email sí está vinculado a otro dispositivo
      return AuthCheckResponse(
        result: AuthCheckResult.dispositivoDiferente,
        estudiante: estudiante,
      );
    } on SocketException {
      return AuthCheckResponse(result: AuthCheckResult.sinConexion);
    } on HttpException {
      return AuthCheckResponse(result: AuthCheckResult.sinConexion);
    } on Exception catch (e) {
      return AuthCheckResponse(
        result: AuthCheckResult.errorServidor,
        mensajeError: e.toString(),
      );
    }
  }

  // ── Vincular dispositivo ───────────────────────────────────────────────────

  /// Guarda el [deviceUuid] en la fila del [email] en Supabase.
  /// Debe llamarse solo cuando el usuario aprueba la vinculación
  /// ([AuthCheckResult.dispositivoSinVincular]).
  static Future<bool> vincularDispositivo({
    required String email,
    required String deviceUuid,
  }) async {
    try {
      final List<dynamic> response = await Supabase.instance.client
          .from(_tableName)
          .update({'device_uuid': deviceUuid})
          .eq('email', email.trim().toLowerCase())
          .timeout(_timeout) as List<dynamic>;

      // Supabase devuelve 204 No Content en PATCH exitoso
      return response.isEmpty;
    } catch (_) {
      return false;
    }
  }
}
