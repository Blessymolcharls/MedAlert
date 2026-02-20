import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/compartment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(CompartmentAdapter());

  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            storageService: storageService,
            bleService: BleService(),
            notificationService: notificationService,
          )..init(),
        ),
      ],
      child: const MedAlertApp(),
    ),
  );
}

class MedAlertApp extends StatelessWidget {
  const MedAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedAlert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4D45),
          primary: const Color(0xFF1F4D45),
          secondary: const Color(0xFFF5C842),
          surface: const Color(0xFFFAF7F2),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 4,
          shadowColor: Color(0x14000000), // Colors.black.withOpacity(0.08)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide.none,
          ),
          margin: EdgeInsets.all(8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F4D45),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1F4D45), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
