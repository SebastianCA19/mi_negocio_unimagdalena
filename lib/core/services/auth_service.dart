import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthCheckResult {
  correoInvalido,
  sinConexion,
  errorServidor,
  correoNoEncontrado,
  dispositivoSinVincular,
  dispositivoVinculado,
  dispositivoDiferente,
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

  /// Verifica el correo y el UUID del dispositivo contra Supabase.
  ///
  /// Flujo:
  /// 1. Buscar el correo en la BD.
  ///    - No encontrado → [correoNoEncontrado]
  /// 2. Si device_uuid en BD es null → [dispositivoSinVincular]
  /// 3. Si device_uuid en BD == deviceUuid → [dispositivoVinculado]
  /// 4. Si device_uuid en BD != deviceUuid:
  ///    - Buscar si ese deviceUuid está vinculado a OTRO correo:
  ///      · Sí → [emailNoCorresponde]  (este dispositivo pertenece a otro)
  ///      · No → [dispositivoDiferente] (el correo pertenece a otro dispositivo)
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
          .timeout(_timeout);

      // ── 2. Correo no existe en la BD ─────────────────────────────────────
      if (rowsEmail.isEmpty) {
        return AuthCheckResponse(result: AuthCheckResult.correoNoEncontrado);
      }

      final estudiante =
          EstudianteInfo.fromJson(rowsEmail.first as Map<String, dynamic>);

      // ── 3. Sin UUID vinculado → verificar PRIMERO si el dispositivo
      //       ya está registrado bajo otro correo antes de ofrecer vincular ──
      if (estudiante.deviceUuid == null || estudiante.deviceUuid!.isEmpty) {
        final List<dynamic> rowsUuid = await Supabase.instance.client
            .from(_tableName)
            .select()
            .eq('device_uuid', deviceUuid)
            .limit(1)
            .timeout(_timeout);

        if (rowsUuid.isNotEmpty) {
          // Este dispositivo ya pertenece a otro correo
          return AuthCheckResponse(
            result: AuthCheckResult.emailNoCorresponde,
            estudiante: estudiante,
          );
        }

        // Dispositivo libre → ofrecer vinculación
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

      // ── 5. UUID no coincide: verificar si este dispositivo ya está
      //       registrado bajo OTRO correo ───────────────────────────────────
      final List<dynamic> rowsUuid = await Supabase.instance.client
          .from(_tableName)
          .select()
          .eq('device_uuid', deviceUuid)
          .limit(1)
          .timeout(_timeout);

      if (rowsUuid.isNotEmpty) {
        return AuthCheckResponse(
          result: AuthCheckResult.emailNoCorresponde,
          estudiante: estudiante,
        );
      }

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

  /// Guarda el [deviceUuid] en la fila del [email] en Supabase.
  /// En supabase_flutter v2, .update() sin .select() retorna void.
  /// Usamos .select() para confirmar que la fila fue efectivamente modificada.
  static Future<bool> vincularDispositivo({
    required String email,
    required String deviceUuid,
  }) async {
    try {
      final List<dynamic> updated = await Supabase.instance.client
          .from(_tableName)
          .update({'device_uuid': deviceUuid})
          .eq('email', email.trim().toLowerCase())
          .select()
          .timeout(_timeout);

      // Si retorna al menos una fila, el update fue exitoso
      return updated.isNotEmpty;
    } on Exception {
      return false;
    }
  }
}
