import '../../core/database/app_database.dart';
import '../../core/util/app_formatters.dart';
import './models/producto_model.dart';

class InventoryRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ──────────────────────────────────────────────
  //  PRODUCTOS
  // ──────────────────────────────────────────────

  /// Retorna todos los productos, opcionalmente filtrados por categoría o búsqueda.
  Future<List<Producto>> getProductos({
    String? categoria,
    String? busqueda,
    bool soloStockBajo = false,
  }) async {
    final db = await _db.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (categoria != null && categoria.isNotEmpty) {
      conditions.add('categoria = ?');
      args.add(categoria);
    }
    if (busqueda != null && busqueda.isNotEmpty) {
      conditions.add('nombre LIKE ?');
      args.add('%$busqueda%');
    }
    if (soloStockBajo) {
      conditions.add('stock_actual <= stock_minimo');
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final maps = await db.query(
      'productos',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'nombre ASC',
    );

    return maps.map(Producto.fromMap).toList();
  }

  /// Retorna un producto por ID con sus insumos cargados.
  Future<Producto?> getProductoById(int id) async {
    final db = await _db.database;
    final maps = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;

    final producto = Producto.fromMap(maps.first);
    final insumos = await getInsumos(id);
    return producto.copyWith(insumos: insumos);
  }

  /// Cantidad de productos con stock bajo.
  Future<int> contarStockBajo() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM productos WHERE stock_actual <= stock_minimo',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Inserta un producto. Lanza excepción si el nombre ya existe.
  Future<int> insertProducto(Producto producto) async {
    final db = await _db.database;
    final now = AppFormatters.dateTimeToDb(DateTime.now());
    final map = producto.toMap()
      ..['fecha_creacion'] = now
      ..['fecha_actualizacion'] = now;
    map.remove('id');
    return await db.insert('productos', map);
  }

  /// Actualiza los datos de un producto.
  Future<void> updateProducto(Producto producto) async {
    final db = await _db.database;
    final map = producto.toMap()
      ..['fecha_actualizacion'] = AppFormatters.dateTimeToDb(DateTime.now());
    await db
        .update('productos', map, where: 'id = ?', whereArgs: [producto.id]);
  }

  /// Actualiza solo el stock_actual de un producto (usado por compras/ventas).
  Future<void> updateStock(int productoId, double nuevoStock) async {
    final db = await _db.database;
    await db.update(
      'productos',
      {
        'stock_actual': nuevoStock,
        'fecha_actualizacion': AppFormatters.dateTimeToDb(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  /// Elimina un producto (CASCADE borra sus insumos y ajustes).
  Future<void> deleteProducto(int id) async {
    final db = await _db.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  /// Verifica si ya existe un producto con ese nombre (ignorando ID propio).
  Future<bool> existeNombre(String nombre, {int? excluirId}) async {
    final db = await _db.database;
    final maps = await db.query(
      'productos',
      where: excluirId != null ? 'nombre = ? AND id != ?' : 'nombre = ?',
      whereArgs: excluirId != null ? [nombre, excluirId] : [nombre],
    );
    return maps.isNotEmpty;
  }

  // ──────────────────────────────────────────────
  //  INSUMOS
  // ──────────────────────────────────────────────

  Future<List<InsumoProducto>> getInsumos(int productoId) async {
    final db = await _db.database;
    final maps = await db.query(
      'insumos_producto',
      where: 'producto_id = ?',
      whereArgs: [productoId],
    );
    return maps.map(InsumoProducto.fromMap).toList();
  }

  /// Reemplaza todos los insumos de un producto (borrar + insertar).
  Future<void> saveInsumos(int productoId, List<InsumoProducto> insumos) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'insumos_producto',
        where: 'producto_id = ?',
        whereArgs: [productoId],
      );
      for (final insumo in insumos) {
        final map = insumo.toMap()..['producto_id'] = productoId;
        map.remove('id');
        await txn.insert('insumos_producto', map);
      }
    });
  }

  Future<void> deleteInsumo(int id) async {
    final db = await _db.database;
    await db.delete('insumos_producto', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────
  //  AJUSTES MANUALES
  // ──────────────────────────────────────────────

  Future<List<AjusteInventario>> getAjustes(int productoId) async {
    final db = await _db.database;
    final maps = await db.query(
      'ajustes_inventario',
      where: 'producto_id = ?',
      whereArgs: [productoId],
      orderBy: 'fecha_ajuste DESC',
    );
    return maps.map(AjusteInventario.fromMap).toList();
  }

  /// Registra un ajuste manual y actualiza el stock del producto.
  Future<void> registrarAjuste(AjusteInventario ajuste) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('ajustes_inventario', ajuste.toMap()..remove('id'));
      await txn.update(
        'productos',
        {
          'stock_actual': ajuste.stockNuevo,
          'fecha_actualizacion': AppFormatters.dateTimeToDb(DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [ajuste.productoId],
      );
    });
  }
}
