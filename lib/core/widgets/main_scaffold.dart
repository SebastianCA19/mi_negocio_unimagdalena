import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import 'app_loading_widgets.dart'; // <-- importa FadeIndexedStack

// Importa las screens directamente para poder mantenerlas vivas (IndexedStack)
import '../../features/procurement/compras_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/accounting/accounting_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Scaffold principal con:
/// - IndexedStack para mantener el estado de cada módulo en memoria
/// - FadeIndexedStack para hacer fade suave al cambiar de tab
/// - BottomNavigationBar estándar de la app
class MainScaffold extends StatefulWidget {
  /// [child] ya no se usa porque ahora gestionamos las screens
  /// directamente aquí con IndexedStack para preservar estado.
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  /// Las screens se crean una sola vez y se mantienen vivas.
  /// Esto elimina el re-render al cambiar de tab.
  static const List<Widget> _screens = [
    ComprasScreen(),
    SalesScreen(),
    InventoryScreen(),
    AccountingScreen(),
    SettingsScreen(),
  ];

  int _indexFromLocation(String location) {
    if (location.startsWith(AppRouter.ventas)) return 1;
    if (location.startsWith(AppRouter.inventario)) return 2;
    if (location.startsWith(AppRouter.finanzas)) return 3;
    if (location.startsWith(AppRouter.configuracion)) return 4;
    return 0;
  }

  void _onTap(int index) {
    if (_currentIndex == index) return; // evita rebuild innecesario
    setState(() => _currentIndex = index);

    // Sincronizar el router (para deep links y el botón atrás del SO)
    switch (index) {
      case 0:
        context.go(AppRouter.compras);
        break;
      case 1:
        context.go(AppRouter.ventas);
        break;
      case 2:
        context.go(AppRouter.inventario);
        break;
      case 3:
        context.go(AppRouter.finanzas);
        break;
      case 4:
        context.go(AppRouter.configuracion);
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sincronizar el index si la navegación vino de fuera (deep link / back)
    final location = GoRouterState.of(context).matchedLocation;
    final newIndex = _indexFromLocation(location);
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FadeIndexedStack hace fade al cambiar de tab;
      // IndexedStack internamente conserva el estado de cada screen.
      body: FadeIndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Compras',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Ventas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Finanzas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Config.',
          ),
        ],
      ),
    );
  }
}