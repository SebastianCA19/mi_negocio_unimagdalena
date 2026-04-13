import 'package:flutter/foundation.dart';
import 'models/venta_model.dart';
import 'venta_repository.dart';

class VentaProvider extends ChangeNotifier {
  final VentaRepository _repo = VentaRepository();

  List<Venta> _ventas = [];
  bool _isLoading = false;
  String? _error;

  String _busqueda = '';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  List<Venta> get ventas => _ventas;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get busqueda => _busqueda;
  DateTime? get fechaDesde => _fechaDesde;
  DateTime? get fechaHasta => _fechaHasta;
  bool get hayFiltrosActivos =>
      _busqueda.isNotEmpty || _fechaDesde != null || _fechaHasta != null;

  // ─── Carga ───────────────────────────────────

  Future<void> cargarVentas() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ventas = await _repo.getVentas(
        busqueda: _busqueda.isNotEmpty ? _busqueda : null,
        fechaDesde: _fechaDesde != null ? _formatFecha(_fechaDesde!) : null,
        fechaHasta: _fechaHasta != null ? _formatFecha(_fechaHasta!) : null,
      );
    } catch (e) {
      _error = 'Error al cargar ventas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Venta?> getVentaDetalle(int id) => _repo.getVentaById(id);

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

  // ─── CRUD Ventas ─────────────────────────────

  /// Guarda la venta. Retorna null si fue exitoso, o un mensaje de error.
  /// Si hay alertas de stock insuficiente las retorna en [alertasStock].
  Future<({String? error, Map<String, double> alertasStock})> guardarVenta(
    Venta venta,
    List<VentaItem> items,
  ) async {
    try {
      final result = await _repo.insertVenta(venta, items);
      await cargarVentas();
      return (error: null, alertasStock: result.alertasStock);
    } catch (e) {
      return (error: 'Error al guardar venta: $e', alertasStock: <String, double>{});
    }
  }

  /// Elimina la venta. Si [restituirStock] es true, devuelve el stock.
  Future<String?> eliminarVenta(int id, {bool restituirStock = false}) async {
    try {
      await _repo.deleteVenta(id, restituirStock: restituirStock);
      await cargarVentas();
      return null;
    } catch (e) {
      return 'Error al eliminar venta: $e';
    }
  }

  // ─── Utilidades ──────────────────────────────

  String _formatFecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}