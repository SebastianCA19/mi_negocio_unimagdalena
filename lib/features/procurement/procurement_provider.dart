import 'package:flutter/foundation.dart';
import 'models/pro_model.dart';
import 'procurement_repository.dart';

class ProcurementProvider extends ChangeNotifier {
  final ProcurementRepository _repo = ProcurementRepository();

  List<Procurement> _procurements = [];
  bool _isLoading = false;
  String? _error;

  // Active filters
  String _search = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Getters
  List<Procurement> get procurements => _procurements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  bool get hasActiveFilters =>
      _search.isNotEmpty || _dateFrom != null || _dateTo != null;

  // Load procurements
  Future<void> loadProcurements() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _procurements = await _repo.getProcurements(
        search: _search.isNotEmpty ? _search : null,
        dateFrom: _dateFrom != null
            ? '${_dateFrom!.year.toString().padLeft(4, '0')}-'
                '${_dateFrom!.month.toString().padLeft(2, '0')}-'
                '${_dateFrom!.day.toString().padLeft(2, '0')}'
            : null,
        dateTo: _dateTo != null
            ? '${_dateTo!.year.toString().padLeft(4, '0')}-'
                '${_dateTo!.month.toString().padLeft(2, '0')}-'
                '${_dateTo!.day.toString().padLeft(2, '0')}'
            : null,
      );
    } catch (e) {
      _error = 'Error al cargar compras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Procurement?> getProcurementDetail(int id) =>
      _repo.getProcurementById(id);

  // Set filters
  void setSearch(String text) {
    _search = text;
    notifyListeners();
  }

  void setDate(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _dateFrom = null;
    _dateTo = null;
    notifyListeners();
  }

  // Save procurement (Null if creating new, error message if failed)
  Future<String?> saveProcurement(
      Procurement procurement, List<ProcurementItem> items) async {
    try {
      await _repo.insertProcurement(procurement, items);
      await loadProcurements();
      return null;
    } catch (e) {
      return 'Error al guardar compra: $e';
    }
  }

  // Delete procurement (returns error message if failed, null if successful)
  Future<String?> deleteProcurement(int id) async {
    try {
      await _repo.deleteProcurement(id);
      await loadProcurements();
      return null;
    } catch (e) {
      return 'Error al eliminar compra: $e';
    }
  }
}
