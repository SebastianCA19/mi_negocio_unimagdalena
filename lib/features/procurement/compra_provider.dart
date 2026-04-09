import 'package:flutter/foundation.dart';
import 'models/compra_model.dart';
import 'compra_repository.dart';

class CompraProvider extends ChangeNotifier {
  final CompraRepository _repo = CompraRepository();

  List<Compra> _compras = [];
  List<Proveedor> _proveedores = [];
  bool _isLoading = false;
  String? _error;

  String _busqueda = '';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  List<Compra> get compras => _compras;
  List<Proveedor> get proveedores => _proveedores;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get busqueda => _busqueda;
  DateTime? get fechaDesde => _fechaDesde;
  DateTime? get fechaHasta => _fechaHasta;
  bool get hayFiltrosActivos =>
      _busqueda.isNotEmpty || _fechaDesde != null || _fechaHasta != null;

  // ─── Carga ───────────────────────────────────

  Future<void> cargarCompras() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _compras = await _repo.getCompras(
        busqueda: _busqueda.isNotEmpty ? _busqueda : null,
        fechaDesde: _fechaDesde != null ? _formatFecha(_fechaDesde!) : null,
        fechaHasta: _fechaHasta != null ? _formatFecha(_fechaHasta!) : null,
      );
      _proveedores = await _repo.getProveedores();
    } catch (e) {
      _error = 'Error al cargar compras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Compra?> getCompraDetalle(int id) => _repo.getCompraById(id);

  // ─── Filtros ─────────────────────────────────

  void setBusqueda(String texto) {
    _busqueda = texto;
    notifyListeners();
  }

  void setFechas(DateTime? desde, DateTime? hasta) {
    _fechaDesde = desde;
    _fechaHasta = hasta;
    notifyListeners();
  }

  void limpiarFiltros() {
    _busqueda = '';
    _fechaDesde = null;
    _fechaHasta = null;
    notifyListeners();
  }

  // ─── Proveedores ─────────────────────────────

  Future<List<Proveedor>> buscarProveedores(String query) =>
      _repo.buscarProveedores(query);

  Future<Proveedor> crearProveedor({
    required String nombre,
    String? telefono,
  }) async {
    final nuevo = await _repo.insertProveedor(
      Proveedor(nombre: nombre, telefono: telefono),
    );
    _proveedores = await _repo.getProveedores();
    notifyListeners();
    return nuevo;
  }

  Future<void> editarProveedor(Proveedor proveedor) async {
    await _repo.updateProveedor(proveedor);
    _proveedores = await _repo.getProveedores();
    notifyListeners();
  }

  // ─── CRUD Compras ─────────────────────────────

  Future<String?> guardarCompra(Compra compra, List<CompraItem> items) async {
    try {
      await _repo.insertCompra(compra, items);
      await cargarCompras();
      return null;
    } catch (e) {
      return 'Error al guardar compra: $e';
    }
  }

  Future<String?> eliminarCompra(int id) async {
    try {
      await _repo.deleteCompra(id);
      await cargarCompras();
      return null;
    } catch (e) {
      return 'Error al eliminar compra: $e';
    }
  }

  // ─── Utilidades ──────────────────────────────

  String _formatFecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
