import '../../core/database/app_database.dart';
import './models/producto_model.dart';

class InventoryRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ──────────────────────────────────────────────
  //  UNIDADES DE MEDIDA
  // ──────────────────────────────────────────────

  Future<List<UnidadMedida>> getUnidadesMedida() async {
    final db = await _db.database;
    final maps = await db.query('unidades_medida', orderBy: 'nombre ASC');
    return maps.map(UnidadMedida.fromMap).toList();
  }

  Future<UnidadMedida?> getUnidadMedidaById(int id) async {
    final db = await _db.database;
    final maps =
        await db.query('unidades_medida', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return UnidadMedida.fromMap(maps.first);
  }

  /// Busca unidades cuyo nombre o abreviatura contengan [query].
  Future<List<UnidadMedida>> buscarUnidades(String query) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT * FROM unidades_medida
      WHERE LOWER(nombre)      LIKE LOWER(?)
         OR LOWER(abreviatura) LIKE LOWER(?)
      ORDER BY nombre ASC
      ''',
      ['%$query%', '%$query%'],
    );
    return maps.map(UnidadMedida.fromMap).toList();
  }

  /// Inserta una nueva unidad de medida y retorna su id.
  Future<int> insertUnidadMedida(UnidadMedida unidad) async {
    final db = await _db.database;
    return db.insert('unidades_medida', unidad.toMap());
  }

  // ──────────────────────────────────────────────
  //  PRODUCTOS
  // ──────────────────────────────────────────────

  /// Retorna todos los productos con su unidad de medida (JOIN).
  Future<List<Producto>> getProductos({
    bool? soloMateriaPrima,
    String? busqueda,
    bool soloStockBajo = false,
  }) async {
    final db = await _db.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (soloMateriaPrima != null) {
      conditions.add('p.es_materia_prima = ?');
      args.add(soloMateriaPrima ? 1 : 0);
    }
    if (busqueda != null && busqueda.isNotEmpty) {
      conditions.add('p.nombre LIKE ?');
      args.add('%$busqueda%');
    }
    if (soloStockBajo) {
      conditions.add('p.stock_actual <= p.stock_minimo');
    }

    final where =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final maps = await db.rawQuery(
      '''
      SELECT
        p.*,
        um.nombre      AS um_nombre,
        um.abreviatura AS um_abreviatura,
        um.factor_base AS um_factor_base
      FROM productos p
      JOIN unidades_medida um ON um.id = p.unidad_medida_id
      $where
      ORDER BY p.nombre ASC
      ''',
      args.isNotEmpty ? args : null,
    );

    return maps.map(Producto.fromMap).toList();
  }

  /// Retorna un producto con su unidad y sus insumos.
  Future<Producto?> getProductoById(int id) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        p.*,
        um.nombre      AS um_nombre,
        um.abreviatura AS um_abreviatura,
        um.factor_base AS um_factor_base
      FROM productos p
      JOIN unidades_medida um ON um.id = p.unidad_medida_id
      WHERE p.id = ?
      ''',
      [id],
    );
    if (maps.isEmpty) return null;

    final producto = Producto.fromMap(maps.first);
    final insumos = await getInsumos(id);
    return producto.copyWith(insumos: insumos);
  }

  Future<int> contarStockBajo() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM productos WHERE stock_actual <= stock_minimo',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> insertProducto(Producto producto) async {
    final db = await _db.database;
    final map = producto.toMap()..remove('id');
    return db.insert('productos', map);
  }

  Future<void> updateProducto(Producto producto) async {
    final db = await _db.database;
    await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  Future<void> updateStock(int productoId, double nuevoStock) async {
    final db = await _db.database;
    await db.update(
      'productos',
      {'stock_actual': nuevoStock},
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  Future<void> deleteProducto(int id) async {
    final db = await _db.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

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

  /// Retorna los insumos de un producto con datos del insumo y su unidad.
  Future<List<InsumoProducto>> getInsumos(int productoId) async {
    final db = await _db.database;
    final maps = await db.rawQuery(
      '''
      SELECT
        ip.*,
        p.nombre           AS insumo_nombre,
        p.unidad_medida_id AS insumo_unidad_medida_id,
        um.nombre          AS insumo_um_nombre,
        um.abreviatura     AS insumo_um_abreviatura,
        um.factor_base     AS insumo_um_factor_base
      FROM insumos_producto ip
      JOIN productos       p  ON p.id  = ip.insumo_id
      JOIN unidades_medida um ON um.id = p.unidad_medida_id
      WHERE ip.producto_id = ?
      ''',
      [productoId],
    );
    return maps.map(InsumoProducto.fromMap).toList();
  }

  /// Reemplaza todos los insumos de un producto.
  Future<void> saveInsumos(int productoId, List<InsumoProducto> insumos) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'insumos_producto',
        where: 'producto_id = ?',
        whereArgs: [productoId],
      );
      for (final insumo in insumos) {
        final map = insumo.toMap()
          ..remove('id')
          ..['producto_id'] = productoId;
        await txn.insert('insumos_producto', map);
      }
    });
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

  /// Registra un ajuste y actualiza el stock del producto en una transaccion.
  Future<void> registrarAjuste(
      AjusteInventario ajuste, double nuevoStock) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('ajustes_inventario', ajuste.toMap()..remove('id'));
      await txn.update(
        'productos',
        {'stock_actual': nuevoStock},
        where: 'id = ?',
        whereArgs: [ajuste.productoId],
      );
    });
  }
}
