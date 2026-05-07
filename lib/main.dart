import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/inventory/inventory_provider.dart';
import 'features/procurement/compra_provider.dart';
import 'features/sales/venta_provider.dart';
import 'features/accounting/finanzas_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fija el color de la barra de estado para que coincida con el splash
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryColor,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await initializeDateFormatting('es_CO', null);

  // ── Verificar sesión ANTES de construir el árbol de widgets ──────────────
  // Esto elimina la pantalla blanca: cuando runApp se ejecuta, ya sabemos
  // si el usuario está autenticado o no.
  final authProvider = AuthProvider();
  await authProvider.verificarSesionLocal();

  runApp(
    MultiProvider(
      providers: [
        // Inyectamos la instancia ya inicializada, no una nueva
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => CompraProvider()),
        ChangeNotifierProvider(create: (_) => VentaProvider()),
        ChangeNotifierProvider(create: (_) => FinanzasProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    // El router ya no necesita llamar verificarSesionLocal()
    // porque se hizo en main() antes del runApp
    _router = AppRouter.createRouter(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MiNegocio UniMagdalena',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}