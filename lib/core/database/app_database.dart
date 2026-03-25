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
        // Habilitar claves foraneas en SQLite
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
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

    // Tabla de productos del inventario
    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        categoria TEXT NOT NULL,
        unidad_medida TEXT NOT NULL,
        stock_actual REAL NOT NULL DEFAULT 0,
        stock_minimo REAL NOT NULL DEFAULT 0,
        precio_venta REAL,
        fecha_creacion TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
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
        cantidad REAL NOT NULL,
        precio_unitario REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (compra_id) REFERENCES compras(id) ON DELETE CASCADE
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
    await db.execute('CREATE INDEX idx_compras_proveedor ON compras(nombre_proveedor)');
    await db.execute('CREATE INDEX idx_ventas_fecha ON ventas(fecha_venta)');
    await db.execute('CREATE INDEX idx_ventas_comprador ON ventas(nombre_comprador)');
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