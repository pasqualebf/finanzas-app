import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

// --- IMPORTACIONES DE TUS PANTALLAS ---
import 'analitica_screen.dart'; // <--- ¡AQUÍ ESTÁ LA MAGIA!
import 'cuentas_screen.dart';
import 'movimientos_screen.dart';
import 'ajustes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null 
        ? FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
            .collection('users').doc(uid).snapshots()
        : null,
      builder: (context, snapshot) {
        int colorValue = 0xFF0A2463; 
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('themeColor')) {
            colorValue = data['themeColor'];
          }
        }

        final seedColor = Color(colorValue);

        return MaterialApp(
          title: 'Finance Cloud',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seedColor, primary: seedColor),
            scaffoldBackgroundColor: const Color(0xFFF4F6F8),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: seedColor,
                foregroundColor: Colors.white,
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: seedColor,
              foregroundColor: Colors.white,
            )
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  
  // --- LISTA DE PÁGINAS CONECTADA ---
  final List<Widget> _pages = [
    const AnaliticaScreen(), // <--- ¡AHORA SÍ CARGARÁ TU GRÁFICA!
    const CuentasScreen(),
    const MovimientosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finance Cloud"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen())),
          )
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Analítica'),
          NavigationDestination(icon: FaIcon(FontAwesomeIcons.wallet), label: 'Cuentas'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Movimientos'),
        ],
      ),
    );
  }
}