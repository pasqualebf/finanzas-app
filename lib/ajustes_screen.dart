import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// Importamos pantallas y servicios
import 'categorias_screen.dart'; 
import 'main.dart'; 
import 'backup_service.dart'; // <--- IMPORTANTE: Importamos el servicio nuevo

class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final BackupService _backupService = BackupService(); // Instancia del servicio

  // Colores disponibles
  final List<Color> temas = [
    const Color(0xFF0A2463), // Azul Navy
    const Color(0xFF2E7D32), // Verde Bosque
    const Color(0xFF4527A0), // Morado
    const Color(0xFFC62828), // Rojo
    const Color(0xFF212121), // Negro
  ];

  Future<void> _cambiarColor(int colorValue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
      .collection('users').doc(uid).set({
        'themeColor': colorValue
      }, SetOptions(merge: true));
    if (mounted) setState(() {});
  }

  // --- ZONA DE PELIGRO: RESETEAR APP ---
  Future<void> _resetearApp() async {
    bool confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Reiniciar App de Fábrica?"),
        content: const Text(
          "Esto borrará tu sesión actual y desconectará tus bancos.\n\n"
          "La app quedará limpia para que otra persona use.\n\n"
          "¿Estás seguro?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sí, Borrar Todo", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    ) ?? false;

    if (!confirmar) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.delete(); 
      await FirebaseAuth.instance.signInAnonymously();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const FinanceApp()), 
          (Route<dynamic> route) => false
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al resetear: $e")));
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
       if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const FinanceApp()), 
          (Route<dynamic> route) => false
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajustes"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SECCIÓN 1: APARIENCIA
          Text("Apariencia", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text("Color del Tema", style: GoogleFonts.poppins(color: Colors.grey[600])),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: temas.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _cambiarColor(temas[index].value),
                  child: Container(
                    width: 50, height: 50,
                    margin: const EdgeInsets.only(right: 15),
                    decoration: BoxDecoration(
                      color: temas[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                      ]
                    ),
                  ),
                );
              },
            ),
          ),
          
          const Divider(height: 40),

          // SECCIÓN 2: GESTIÓN DE DATOS
          Text("Gestión", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                child: const Icon(Icons.category, color: Colors.blue),
              ),
              title: Text("Categorías de Gastos", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: const Text("Crea, edita o elimina tus categorías"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriasScreen()));
              },
            ),
          ),

          const SizedBox(height: 30),

          // --- SECCIÓN 3: ZONA DE SEGURIDAD (RESPALDO) ---
          Text("Zona de Seguridad", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.indigo),
                  title: const Text("Crear Respaldo Local"),
                  subtitle: const Text("Guarda todos tus datos en un archivo"),
                  onTap: () => _backupService.exportarDatos(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_page_rounded, color: Colors.teal),
                  title: const Text("Restaurar desde Archivo"),
                  subtitle: const Text("Recupera datos de un respaldo anterior"),
                  onTap: () async {
                    bool? confirm = await showDialog(
                      context: context, 
                      builder: (ctx) => AlertDialog(
                        title: const Text("¿Restaurar datos?"),
                        content: const Text("Esto fusionará los datos del archivo con los actuales. No te preocupes, NO se duplicarán movimientos que ya existan."),
                        actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                           ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Restaurar")),
                        ],
                      )
                    );

                    if (confirm == true && mounted) {
                      _backupService.importarDatos(context);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // SECCIÓN 4: ZONA DE PELIGRO
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.red[100]!)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 10),
                    Text("Zona de Peligro", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Usa esto si vas a entregar la app a otra persona. Se borrarán tus datos de este dispositivo.",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[800])
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _resetearApp,
                    child: const Text("Restablecer App (Modo Fábrica)"),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}