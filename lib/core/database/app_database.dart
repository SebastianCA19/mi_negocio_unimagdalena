import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mi_negocio.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // ── Sesion del usuario autenticado ──────────────────────────────────────
    // correo: correo institucional verificado.
    // nombre / apellido: obtenidos del proveedor de identidad institucional
    // (o hardcodeados durante la simulacion de login).
    await db.execute('''
      CREATE TABLE sesion (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        correo            TEXT    NOT NULL UNIQUE,
        nombre            TEXT    NOT NULL DEFAULT '',
        apellido          TEXT    NOT NULL DEFAULT '',
        fecha_inicio      TEXT    NOT NULL,
        fecha_expiracion  TEXT    NOT NULL,
        activa            INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ── Unidades de medida ───────────────────────────────────────────────────
    // factor_base expresa cuantas unidades base equivale 1 de esta unidad.
    // Ejemplo: 1 kg = 1000 g → factor_base(kg) = 1000, factor_base(g) = 1.
    // Todas las unidades de la misma categoria deben usar la misma base.
    await db.execute('''
      CREATE TABLE unidades_medida (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre      TEXT    NOT NULL UNIQUE,
        abreviatura TEXT    NOT NULL,
        factor_base REAL    NOT NULL DEFAULT 1
      )
    ''');

    await _insertarUnidadesBase(db);

    // ── Proveedores ──────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE proveedores (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre   TEXT NOT NULL,
        telefono TEXT
      )
    ''');

    // ── Productos del inventario ─────────────────────────────────────────────
    // es_materia_prima = 1  → materia prima
    // es_materia_prima = 0  → producto terminado
    await db.execute('''
      CREATE TABLE productos (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre           TEXT    NOT NULL UNIQUE,
        es_materia_prima INTEGER NOT NULL DEFAULT 0,
        unidad_medida_id INTEGER NOT NULL,
        stock_actual     REAL    NOT NULL DEFAULT 0,
        stock_minimo     REAL    NOT NULL DEFAULT 0,
        precio_venta     REAL,
        FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id)
          ON DELETE RESTRICT
      )
    ''');

    // ── Insumos por producto (receta de produccion) ──────────────────────────
    // producto_id → producto terminado que se produce
    // insumo_id   → producto (materia prima) que se consume al producir
    // La cantidad se expresa en la unidad de medida propia del insumo.
    await db.execute('''
      CREATE TABLE insumos_producto (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id         INTEGER NOT NULL,
        insumo_id           INTEGER NOT NULL,
        cantidad_por_unidad REAL    NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE,
        FOREIGN KEY (insumo_id)   REFERENCES productos(id) ON DELETE CASCADE,
        UNIQUE (producto_id, insumo_id)
      )
    ''');

    // ── Compras ──────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE compras (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        proveedor_id   INTEGER NOT NULL,
        fecha_compra   TEXT    NOT NULL,
        metodo_pago    TEXT    NOT NULL,
        imagen_path    TEXT,
        fecha_registro TEXT    NOT NULL,
        FOREIGN KEY (proveedor_id) REFERENCES proveedores(id)
          ON DELETE RESTRICT
      )
    ''');

    // ── Items de cada compra ─────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE compra_items (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        compra_id        INTEGER NOT NULL,
        producto_id      INTEGER NOT NULL,
        unidad_medida_id INTEGER NOT NULL,
        cantidad         REAL    NOT NULL,
        precio_unitario  REAL    NOT NULL,
        FOREIGN KEY (compra_id)        REFERENCES compras(id)         ON DELETE CASCADE,
        FOREIGN KEY (producto_id)      REFERENCES productos(id)       ON DELETE RESTRICT,
        FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id) ON DELETE RESTRICT
      )
    ''');

    // ── Ventas ───────────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE ventas (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        notas_cliente  TEXT,
        fecha_venta    TEXT NOT NULL,
        metodo_pago    TEXT NOT NULL,
        imagen_path    TEXT,
        fecha_registro TEXT NOT NULL
      )
    ''');

    // ── Items de cada venta ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE venta_items (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id        INTEGER NOT NULL,
        producto_id     INTEGER NOT NULL,
        cantidad        REAL    NOT NULL,
        precio_unitario REAL    NOT NULL,
        FOREIGN KEY (venta_id)    REFERENCES ventas(id)    ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT
      )
    ''');

    // ── Ajustes manuales de inventario ───────────────────────────────────────
    // tipo: 'Aumento' | 'Disminucion'
    await db.execute('''
      CREATE TABLE ajustes_inventario (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id  INTEGER NOT NULL,
        tipo         TEXT    NOT NULL,
        cantidad     REAL    NOT NULL,
        motivo       TEXT    NOT NULL,
        fecha_ajuste TEXT    NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
      )
    ''');

    // ── Indices ──────────────────────────────────────────────────────────────
    await db.execute(
        'CREATE INDEX idx_compras_fecha         ON compras(fecha_compra)');
    await db.execute(
        'CREATE INDEX idx_compras_proveedor     ON compras(proveedor_id)');
    await db.execute(
        'CREATE INDEX idx_ventas_fecha          ON ventas(fecha_venta)');
    await db
        .execute('CREATE INDEX idx_productos_nombre      ON productos(nombre)');
    await db.execute(
        'CREATE INDEX idx_compra_items_compra   ON compra_items(compra_id)');
    await db.execute(
        'CREATE INDEX idx_compra_items_producto ON compra_items(producto_id)');
    await db.execute(
        'CREATE INDEX idx_venta_items_venta     ON venta_items(venta_id)');
    await db.execute(
        'CREATE INDEX idx_venta_items_producto  ON venta_items(producto_id)');
  }

  Future<void> _insertarUnidadesBase(DatabaseExecutor db) async {
    // Conversion: valor_en_base = cantidad * factor_base
    //
    // Masa     → gramo  (g)    como unidad base
    // Volumen  → mililitro (mL) como unidad base
    // Longitud → centimetro (cm) como unidad base
    // Cantidad → unidad (ud)   como unidad base
    const rows = [
      // Cantidad
      ('Unidad', 'ud', 1.0),
      ('Paquete', 'pkg', 1.0),
      // Masa (base: g)
      ('Gramo', 'g', 1.0),
      ('Kilogramo', 'kg', 1000.0),
      // Volumen (base: mL)
      ('Mililitro', 'mL', 1.0),
      ('Litro', 'L', 1000.0),
      // Longitud (base: cm)
      ('Centimetro', 'cm', 1.0),
      ('Metro', 'm', 100.0),
    ];

    const sql = '''
      INSERT INTO unidades_medida (nombre, abreviatura, factor_base)
      VALUES (?, ?, ?)
    ''';

    for (final (nombre, abrev, factor) in rows) {
      await db.execute(sql, [nombre, abrev, factor]);
    }
  }

  // ── Utilitarios ──────────────────────────────────────────────────────────────

  /// Cierra la conexion. Debe llamarse solo al cerrar la aplicacion.
  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }

  /// Elimina y recrea toda la base de datos (usado en restauracion de backup).
  Future<void> deleteAndRecreate() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mi_negocio.db');
    await close();
    await deleteDatabase(path);
    _database = await _initDatabase();
  }
}
