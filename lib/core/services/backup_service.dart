import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../util/app_constants.dart';
import '../util/app_formatters.dart';

class BackupInfo {
  final File archivo;
  final DateTime fechaCreacion;
  final int tamanoBytes;

  BackupInfo({
    required this.archivo,
    required this.fechaCreacion,
    required this.tamanoBytes,
  });

  String get nombre => basename(archivo.path);

  String get tamanoDisplay {
    if (tamanoBytes < 1024) return '$tamanoBytes B';
    if (tamanoBytes < 1024 * 1024) {
      return '${(tamanoBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(tamanoBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupService {
  static const List<String> _tablas = AppConstants.tablas;

  // ── Último backup ─────────────────────────────────────────────────────────

  /// Retorna info del último backup si la ruta guardada aún existe en disco.
  Future<BackupInfo?> ultimoBackup(String? rutaGuardada) async {
    if (rutaGuardada == null || rutaGuardada.isEmpty) return null;
    final archivo = File(rutaGuardada);
    if (!await archivo.exists()) return null;
    return BackupInfo(
      archivo: archivo,
      fechaCreacion: await archivo.lastModified(),
      tamanoBytes: await archivo.length(),
    );
  }

  // ── Crear backup ──────────────────────────────────────────────────────────
  /// Retorna el [BackupInfo] del archivo creado, o **null** si el usuario
  /// canceló el selector de carpeta.
  Future<BackupInfo?> crearBackup({
    void Function(double progreso)? onProgreso,
  }) async {
    final directorio = await getApplicationDocumentsDirectory();
    final carpeta = directorio.path;

    final timestamp = AppFormatters.dateTimeToDb(DateTime.now())
        .replaceAll(':', '-')
        .replaceAll(' ', '_');
    final nombreArchivo =
        '${AppConstants.backupPrefix}_$timestamp${AppConstants.backupExtension}';
    final archivo = File(join(carpeta, nombreArchivo));

    final db = await AppDatabase.instance.database;
    final Map<String, List<Map<String, dynamic>>> datos = {};

    for (int i = 0; i < _tablas.length; i++) {
      final tabla = _tablas[i];
      try {
        datos[tabla] = await db.query(tabla);
      } catch (_) {
        datos[tabla] = [];
      }
      onProgreso?.call((i + 1) / _tablas.length * 0.9);
    }

    await archivo.writeAsString(jsonEncode(datos), encoding: utf8);
    onProgreso?.call(1.0);

    return BackupInfo(
      archivo: archivo,
      fechaCreacion: DateTime.now(),
      tamanoBytes: await archivo.length(),
    );
  }

  // ── Eliminar backup ───────────────────────────────────────────────────────
  Future<void> eliminarBackup(File archivo) async {
    if (await archivo.exists()) await archivo.delete();
  }

  // ── Restaurar backup ──────────────────────────────────────────────────────
  /// Restaura la base de datos desde un archivo .mnbak.
  /// Llama [onProgreso] con valores entre 0.0 y 1.0.
  Future<void> restaurarBackup(
    File archivo, {
    void Function(double progreso)? onProgreso,
  }) async {
    onProgreso?.call(0.0);

    final contenido = await archivo.readAsString(encoding: utf8);
    onProgreso?.call(0.1);

    final Map<String, dynamic> raw = jsonDecode(contenido);
    onProgreso?.call(0.2);

    await AppDatabase.instance.deleteAndRecreate();
    onProgreso?.call(0.35);

    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final tablas = raw.keys.toList();
      for (int i = 0; i < tablas.length; i++) {
        final tabla = tablas[i];
        final List<dynamic> filas = raw[tabla] as List<dynamic>? ?? [];
        for (final fila in filas) {
          try {
            await txn.insert(
              tabla,
              Map<String, dynamic>.from(fila as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (_) {
            // Ignorar filas que violen restricciones (datos corruptos)
          }
        }
        onProgreso?.call(0.35 + (i + 1) / tablas.length * 0.65);
      }
    });

    onProgreso?.call(1.0);
  }
}
