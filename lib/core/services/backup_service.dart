import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
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
  /// Orden topológico: cada tabla aparece DESPUÉS de todas las tablas
  /// a las que referencia con FK. Esto garantiza que al restaurar no
  /// se violen restricciones de integridad referencial.
  ///
  /// unidades_medida  → sin dependencias
  /// sesion           → sin dependencias
  /// proveedores      → sin dependencias
  /// productos        → depende de unidades_medida
  /// insumos_producto → depende de productos
  /// compras          → depende de proveedores
  /// compra_items     → depende de compras, productos, unidades_medida
  /// ventas           → sin dependencias externas
  /// venta_items      → depende de ventas, productos
  /// ajustes_inventario → depende de productos
  static const List<String> _tablasOrdenadas = [
    'unidades_medida',
    'sesion',
    'proveedores',
    'productos',
    'insumos_producto',
    'compras',
    'compra_items',
    'ventas',
    'venta_items',
    'ajustes_inventario',
  ];

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

  /// Abre un selector de carpeta nativo. Si el usuario confirma, exporta la
  /// base de datos a un archivo .mnbak en esa carpeta.
  ///
  /// Retorna el [BackupInfo] del archivo creado, o **null** si el usuario
  /// canceló el selector de carpeta.
  Future<BackupInfo?> crearBackup({
    void Function(double progreso)? onProgreso,
  }) async {
    // 1. El usuario elige la carpeta destino
    final carpeta = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Guardar copia de seguridad en…',
    );
    if (carpeta == null) return null;

    // 2. Construir nombre de archivo con timestamp
    final timestamp = AppFormatters.dateTimeToDb(DateTime.now())
        .replaceAll(':', '-')
        .replaceAll(' ', '_');
    final nombreArchivo =
        '${AppConstants.backupPrefix}_$timestamp${AppConstants.backupExtension}';
    final archivo = File(join(carpeta, nombreArchivo));

    // 3. Exportar cada tabla en orden topológico
    final db = await AppDatabase.instance.database;
    final Map<String, List<Map<String, dynamic>>> datos = {};

    for (int i = 0; i < _tablasOrdenadas.length; i++) {
      final tabla = _tablasOrdenadas[i];
      try {
        datos[tabla] = await db.query(tabla);
      } catch (_) {
        datos[tabla] = [];
      }
      onProgreso?.call((i + 1) / _tablasOrdenadas.length * 0.9);
    }

    // 4. Escribir JSON
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
  ///
  /// El proceso:
  /// 1. Deshabilita FK temporalmente para poder truncar y reinsertar.
  /// 2. Recrea el schema limpio con [deleteAndRecreate].
  /// 3. Inserta las tablas en orden topológico, ignorando las que no
  ///    existan en el JSON (backups de versiones anteriores).
  /// 4. Llama [onProgreso] con valores entre 0.0 y 1.0.
  Future<void> restaurarBackup(
    File archivo, {
    void Function(double progreso)? onProgreso,
  }) async {
    onProgreso?.call(0.0);

    // Leer y parsear el JSON
    final contenido = await archivo.readAsString(encoding: utf8);
    onProgreso?.call(0.1);

    final Map<String, dynamic> raw = jsonDecode(contenido);
    onProgreso?.call(0.2);

    // Recrear el schema vacío (DROP + CREATE)
    await AppDatabase.instance.deleteAndRecreate();
    onProgreso?.call(0.35);

    final db = await AppDatabase.instance.database;

    // Insertar en orden topológico para respetar las FK.
    // Si el JSON viene de una versión anterior y no tiene alguna tabla,
    // simplemente se omite.
    await db.transaction((txn) async {
      // Deshabilitar FK durante la carga masiva para mayor robustez;
      // se vuelve a habilitar al terminar la transacción.
      await txn.execute('PRAGMA foreign_keys = OFF');

      for (int i = 0; i < _tablasOrdenadas.length; i++) {
        final tabla = _tablasOrdenadas[i];

        // Omitir tablas que no vengan en el backup
        if (!raw.containsKey(tabla)) {
          onProgreso?.call(0.35 + (i + 1) / _tablasOrdenadas.length * 0.65);
          continue;
        }

        final List<dynamic> filas = raw[tabla] as List<dynamic>? ?? [];

        for (final fila in filas) {
          try {
            await txn.insert(
              tabla,
              Map<String, dynamic>.from(fila as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (_) {
            // Ignorar filas individuales corruptas y continuar
          }
        }

        onProgreso?.call(0.35 + (i + 1) / _tablasOrdenadas.length * 0.65);
      }

      await txn.execute('PRAGMA foreign_keys = ON');
    });

    onProgreso?.call(1.0);
  }
}
