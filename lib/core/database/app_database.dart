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
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Habilitar claves foraneas en SQLite
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db
          .execute('ALTER TABLE compra_items ADD COLUMN producto_id INTEGER');
      await db.execute('''
        UPDATE compra_items
        SET producto_id = (
          SELECT id FROM productos
          WHERE LOWER(productos.nombre) = LOWER(compra_items.nombre_producto)
          LIMIT 1
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE unidades_medida (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE,
          abreviatura TEXT NOT NULL,
          categoria TEXT NOT NULL,
          factor_base REAL NOT NULL DEFAULT 1,
          fecha_creacion TEXT NOT NULL,
          fecha_actualizacion TEXT NOT NULL
        )
      ''');

      final now = DateTime.now().toIso8601String();
      await db.execute('''
        INSERT INTO unidades_medida (nombre, abreviatura, categoria, factor_base, fecha_creacion, fecha_actualizacion)
        VALUES
          ('Unidad', 'ud', 'Cantidad', 1, '$now', '$now'),
          ('Kilogramo', 'Kg', 'Masa', 1, '$now', '$now'),
          ('Gramo', 'g', 'Masa', 0.001, '$now', '$now'),
          ('Litro', 'L', 'Volumen', 1, '$now', '$now'),
          ('Mililitro', 'mL', 'Volumen', 0.001, '$now', '$now'),
          ('Metro', 'm', 'Longitud', 1, '$now', '$now'),
          ('Centímetro', 'cm', 'Longitud', 0.01, '$now', '$now'),
          ('Paquete', 'pkg', 'Cantidad', 1, '$now', '$now')
      ''');

      await db
          .execute('ALTER TABLE productos ADD COLUMN unidad_medida_id INTEGER');
      await db.execute(
          'ALTER TABLE compra_items ADD COLUMN unidad_medida_id INTEGER');
      await db
          .execute('ALTER TABLE compra_items ADD COLUMN unidad_medida TEXT');

      await db.execute('''
        UPDATE productos
        SET unidad_medida_id = (
          SELECT id FROM unidades_medida
          WHERE LOWER(unidades_medida.nombre) = LOWER(productos.unidad_medida)
             OR LOWER(unidades_medida.abreviatura) = LOWER(productos.unidad_medida)
          LIMIT 1
        )
      ''');

      await db.execute('''
        UPDATE compra_items
        SET unidad_medida = (
          SELECT unidad_medida FROM productos
          WHERE productos.id = compra_items.producto_id
          LIMIT 1
        )
        WHERE unidad_medida IS NULL
      ''');

      await db.execute('''
        UPDATE compra_items
        SET unidad_medida_id = (
          SELECT id FROM unidades_medida
          WHERE LOWER(unidades_medida.nombre) = LOWER(compra_items.unidad_medida)
             OR LOWER(unidades_medida.abreviatura) = LOWER(compra_items.unidad_medida)
          LIMIT 1
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de sesion del usuario autenticado
    await db.execute('''
      CREATE TABLE sesion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        correo TEXT NOT NULL,
        fecha_autenticacion TEXT NOT NULL,
        fecha_expiracion TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de unidades de medida normalizadas
    await db.execute('''
      CREATE TABLE unidades_medida (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        abreviatura TEXT NOT NULL,
        categoria TEXT NOT NULL,
        factor_base REAL NOT NULL DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');

    final now = DateTime.now().toIso8601String();
    await db.execute('''
      INSERT INTO unidades_medida (nombre, abreviatura, categoria, factor_base, fecha_creacion, fecha_actualizacion)
      VALUES
        ('Unidad', 'ud', 'Cantidad', 1, '$now', '$now'),
        ('Kilogramo', 'Kg', 'Masa', 1, '$now', '$now'),
        ('Gramo', 'g', 'Masa', 0.001, '$now', '$now'),
        ('Litro', 'L', 'Volumen', 1, '$now', '$now'),
        ('Mililitro', 'mL', 'Volumen', 0.001, '$now', '$now'),
        ('Metro', 'm', 'Longitud', 1, '$now', '$now'),
        ('Centímetro', 'cm', 'Longitud', 0.01, '$now', '$now'),
        ('Paquete', 'pkg', 'Cantidad', 1, '$now', '$now')
    ''');

    // Tabla de productos del inventario
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        categoria TEXT NOT NULL,
        unidad_medida TEXT NOT NULL,
        unidad_medida_id INTEGER,
        stock_actual REAL NOT NULL DEFAULT 0,
        stock_minimo REAL NOT NULL DEFAULT 0,
        precio_venta REAL,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL,
        FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id) ON DELETE SET NULL
      )
    ''');

    // Tabla de insumos por producto (receta de produccion)
    await db.execute('''
      CREATE TABLE insumos_producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        nombre_insumo TEXT NOT NULL,
        cantidad_por_unidad REAL NOT NULL,
        unidad_medida TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de compras
    await db.execute('''
      CREATE TABLE compras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_proveedor TEXT NOT NULL,
        telefono_proveedor TEXT,
        fecha_compra TEXT NOT NULL,
        metodo_pago TEXT NOT NULL,
        total REAL NOT NULL,
        imagen_path TEXT,
        fecha_registro TEXT NOT NULL
      )
    ''');

    // Tabla de items de cada compra
    await db.execute('''
      CREATE TABLE compra_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        compra_id INTEGER NOT NULL,
        nombre_producto TEXT NOT NULL,
        producto_id INTEGER,
        unidad_medida_id INTEGER,
        unidad_medida TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (compra_id) REFERENCES compras(id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE SET NULL,
        FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id) ON DELETE SET NULL
      )
    ''');

    // Tabla de ventas
    await db.execute('''
      CREATE TABLE ventas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre_comprador TEXT,
        fecha_venta TEXT NOT NULL,
        metodo_pago TEXT NOT NULL,
        total REAL NOT NULL,
        imagen_comprobante_path TEXT,
        fecha_registro TEXT NOT NULL
      )
    ''');

    // Tabla de items de cada venta
    await db.execute('''
      CREATE TABLE venta_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER NOT NULL,
        nombre_producto TEXT NOT NULL,
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE
      )
    ''');

    // Tabla de ajustes manuales de inventario
    await db.execute('''
      CREATE TABLE ajustes_inventario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        cantidad REAL NOT NULL,
        motivo TEXT NOT NULL,
        stock_anterior REAL NOT NULL,
        stock_nuevo REAL NOT NULL,
        fecha_ajuste TEXT NOT NULL,
        FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE
      )
    ''');

    // Indices para mejorar velocidad de busquedas frecuentes
    await db.execute('CREATE INDEX idx_compras_fecha ON compras(fecha_compra)');
    await db.execute(
        'CREATE INDEX idx_compras_proveedor ON compras(nombre_proveedor)');
    await db.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha_venta)');
    await db.execute(
        'CREATE INDEX idx_ventas_comprador ON ventas(nombre_comprador)');
    await db.execute('CREATE INDEX idx_productos_nombre ON productos(nombre)');
  }

  // Cierra la conexion a la base de datos
  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }

  // Elimina y recrea toda la base de datos (usado en restauracion de backup)
  Future<void> deleteAndRecreate() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mi_negocio.db');
    await close();
    await deleteDatabase(path);
    _database = await _initDatabase();
  }
}
