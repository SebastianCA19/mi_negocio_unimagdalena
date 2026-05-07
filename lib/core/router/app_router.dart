import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/procurement/compras_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/accounting/accounting_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../widgets/main_scaffold.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String home = '/';
  static const String compras = '/compras';
  static const String ventas = '/ventas';
  static const String inventario = '/inventario';
  static const String finanzas = '/finanzas';
  static const String configuracion = '/configuracion';

  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: authProvider,
      redirect: (context, state) {
        final status = authProvider.status;

        // Si el estado es desconocido, mostrar el splash screen
        if (status == AuthStatus.desconocido) {
          if (state.matchedLocation != splash) return splash;
          return null;
        }

        // Si ya sabemos el estado, salir del splash
        if (state.matchedLocation == splash) {
          if (status == AuthStatus.autenticado) return home;
          return auth;
        }

        final isAuthRoute = state.matchedLocation == auth;

        if (status != AuthStatus.autenticado && !isAuthRoute) return auth;
        if (status == AuthStatus.autenticado && isAuthRoute) return home;

        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: auth,
          builder: (context, state) => const AuthScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: home,
              builder: (context, state) => const ComprasScreen(),
            ),
            GoRoute(
              path: compras,
              builder: (context, state) => const ComprasScreen(),
            ),
            GoRoute(
              path: ventas,
              builder: (context, state) => const SalesScreen(),
            ),
            GoRoute(
              path: inventario,
              builder: (context, state) => const InventoryScreen(),
            ),
            GoRoute(
              path: finanzas,
              builder: (context, state) => const AccountingScreen(),
            ),
            GoRoute(
              path: configuracion,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Página no encontrada: ${state.error}'),
        ),
      ),
    );
  }
}