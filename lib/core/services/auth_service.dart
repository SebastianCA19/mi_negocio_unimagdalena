import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
  // Las credenciales se leen del archivo .env en la raíz del proyecto.
  //
  // Variables requeridas:
  //   API_ACCESS_URL  → URL base del proyecto Supabase
  //                     Ejemplo: https://xyzabc.supabase.co
  //
  //   API_ANON_KEY    → Clave pública anon/public de Supabase
  //                     (Settings → API → Project API keys → anon public)
  //                     Empieza con "eyJ..."
  //
  // DATABASE_PASSWORD y DATABASE_NAME son la contraseña y nombre de la base
  // de datos PostgreSQL directa; NO se usan aquí porque la REST API de
  // Supabase se autentica con el anon key, no con la contraseña de postgres.

  static String get _supabaseUrl =>
      dotenv.env['API_ACCESS_URL'] ??
      (throw Exception('Falta API_ACCESS_URL en el archivo .env'));

  static String get _supabaseAnonKey =>
      dotenv.env['API_ANON_KEY'] ??
      (throw Exception('Falta API_ANON_KEY en el archivo .env'));

  static const String _tableName = 'estudiantes';
  static const Duration _timeout = Duration(seconds: 10);

  /// Endpoint REST de Supabase para la tabla de estudiantes
  static Uri _buildUri({Map<String, String>? queryParams}) {
    final uri = Uri.parse('${_supabaseUrl.trimRight()}/rest/v1/$_tableName');
    if (queryParams != null) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  static Map<String, String> get _headers => {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
      };

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
      final responseEmail = await http
          .get(
            _buildUri(queryParams: {
              'email': 'eq.${email.trim().toLowerCase()}',
              'select':
                  'email,first_name,middle_name,first_surname,second_surname,device_uuid',
              'limit': '1',
            }),
            headers: _headers,
          )
          .timeout(_timeout);

      if (responseEmail.statusCode != 200) {
        return AuthCheckResponse(
          result: AuthCheckResult.errorServidor,
          mensajeError:
              'Error del servidor (${responseEmail.statusCode}). Inténtalo más tarde.',
        );
      }

      final List<dynamic> rowsEmail = jsonDecode(responseEmail.body) as List;

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
      final responseUuid = await http
          .get(
            _buildUri(queryParams: {
              'device_uuid': 'eq.$deviceUuid',
              'select': 'email',
              'limit': '1',
            }),
            headers: _headers,
          )
          .timeout(_timeout);

      if (responseUuid.statusCode == 200) {
        final List<dynamic> rowsUuid = jsonDecode(responseUuid.body) as List;

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
      final response = await http
          .patch(
            _buildUri(queryParams: {
              'email': 'eq.${email.trim().toLowerCase()}',
            }),
            headers: _headers,
            body: jsonEncode({'device_uuid': deviceUuid}),
          )
          .timeout(_timeout);

      // Supabase devuelve 204 No Content en PATCH exitoso
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
