import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme_provider.dart';
import 'presentation/pages/auth/splash_page.dart';
import 'presentation/providers/cashier_notification_provider.dart';
import 'presentation/providers/customer_cart_provider.dart';
import 'presentation/providers/customer_notification_provider.dart';
import 'routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => CustomerCartProvider()..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => CashierNotificationProvider()),
        ChangeNotifierProvider(create: (_) => CustomerNotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Kanzza Frozen Food',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const SplashPage(),
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
