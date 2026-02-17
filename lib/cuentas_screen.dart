import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'cuenta_detalle_screen.dart';
import 'importar_bilt_screen.dart'; // IMPORTAR PANTALLA DE IMPORTACIÓN

class CuentasScreen extends StatefulWidget {
  const CuentasScreen({super.key});

  @override
  State<CuentasScreen> createState() => _CuentasScreenState();
}

class _CuentasScreenState extends State<CuentasScreen> {
  bool _cargando = false;
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

  // --- PALETA DE COLORES ---
  final List<Color> paletaColores = [
    const Color(0xFFCD1409), // Wells Fargo
    const Color(0xFFE31837), // Bank of America
    const Color(0xFF117ACA), // Chase
    const Color(0xFF003B70), // Citi
    const Color(0xFF004977), // Capital One
    const Color(0xFF000000), // Marcus / Black
    const Color(0xFFD4AF37), // Goldman / Gold
    const Color(0xFF006FCF), // Amex Blue
    const Color(0xFF4CA90C), // Regions / Cash
    const Color(0xFFFF6000), // Discover
    const Color(0xFF003087), // PayPal
    const Color(0xFF2E7D32), // Verde Genérico
    const Color(0xFF4527A0), // Morado
    const Color(0xFFAD1457), // Magenta
    const Color(0xFF37474F), // Gris
    const Color(0xFF00695C), // Teal
  ];

  Color _getAutoColor(String institutionName) {
    final name = institutionName.toLowerCase();
    if (name.contains('chase')) return const Color(0xFF117ACA);
    if (name.contains('wells')) return const Color(0xFFCD1409);
    if (name.contains('america')) return const Color(0xFFE31837);
    if (name.contains('citi')) return const Color(0xFF003B70);
    if (name.contains('amex')) return const Color(0xFF006FCF);
    if (name.contains('discover')) return const Color(0xFFFF6000);
    if (name.contains('paypal')) return const Color(0xFF003087);
    if (name.contains('manual') || name.contains('efectivo')) return const Color(0xFF2E7D32);
    return const Color(0xFF37474F);
  }

  // --- 1. CONEXIÓN SIMPLEFIN ---
  Future<void> _conectarSimpleFin(String token) async {
    setState(() => _cargando = true);
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFunctions.instance.httpsCallable('conectarSimpleFin').call({
        "setupToken": token,
        "uid": user?.uid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Bancos conectados"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- 2. CREAR CUENTA MANUAL ---
  Future<void> _crearCuentaManual(String nombre, double saldoInicial) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
          .collection('users').doc(user.uid).collection('Cuentas').add({
        'name': nombre,
        'balance': saldoInicial,
        'institutionName': 'Manual', // Esto ayuda a identificarla
        'type': 'manual',
        'customColor': 0xFF2E7D32, // Verde por defecto
        'lastSync': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Cuenta creada")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al crear cuenta")));
    }
  }

  // --- MENÚ DE SELECCIÓN DE TIPO DE CUENTA ---
  void _mostrarOpcionesAgregar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Agregar Cuenta", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.link, color: Colors.blue),
                ),
                title: Text("Vincular Banco Real", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: const Text("Usar SimpleFIN (Chase, BoA, etc)"),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoToken();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.green),
                ),
                title: Text("Cuenta Manual", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                subtitle: const Text("Efectivo, Préstamos, Otros"),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarFormularioManual();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  // --- FORMULARIO MANUAL ---
  void _mostrarFormularioManual() {
    final nombreCtrl = TextEditingController();
    final saldoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nueva Cuenta Manual", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: "Nombre (ej. Cartera)", border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: saldoCtrl,
              decoration: const InputDecoration(labelText: "Saldo Inicial", prefixText: "\$ ", border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  if (nombreCtrl.text.isNotEmpty && saldoCtrl.text.isNotEmpty) {
                    _crearCuentaManual(nombreCtrl.text, double.tryParse(saldoCtrl.text) ?? 0.0);
                  }
                },
                child: const Text("Crear Cuenta", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- DIÁLOGO DE TOKEN ---
  void _mostrarDialogoToken() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vincular Banco", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Pega tu token de SimpleFIN aquí:", style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "aHR0cHM6Ly..."),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(ctx);
                    _conectarSimpleFin(controller.text.trim());
                  }
                },
                child: const Text("Conectar", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- REORDENAR CUENTAS ---
  void _mostrarReordenarCuentas(List<QueryDocumentSnapshot> docs) {
    List<QueryDocumentSnapshot> items = List.from(docs);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text("Organizar Cuentas", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("Arrastra para cambiar el orden", style: GoogleFonts.poppins(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) {
                        setModalState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = items.removeAt(oldIndex);
                          items.insert(newIndex, item);
                        });
                      },
                      children: items.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final nombre = data['alias'] ?? data['name'] ?? 'Cuenta';
                        return ListTile(
                          key: ValueKey(doc.id),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.drag_handle, color: Colors.grey),
                          title: Text(nombre, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.menu),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      onPressed: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;
                        final batch = FirebaseFirestore.instance.batch();
                        for (int i = 0; i < items.length; i++) {
                          batch.update(items[i].reference, {'sortOrder': i});
                        }
                        await batch.commit();
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Guardar Orden", style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

// --- ELIMINAR CUENTA ---
  Future<void> _eliminarCuenta(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Preguntar confirmación para evitar accidentes
    bool? confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Eliminar cuenta?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          "Se borrará esta cuenta y su historial de la aplicación. Si es una cuenta bancaria, podría volver a aparecer en la próxima sincronización.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // 2. Borrar de Firebase
    try {
      // 2.1 Borrar movimientos asociados (Batch)
      final batch = FirebaseFirestore.instance.batch();
      
      final movimientosSnap = await FirebaseFirestore.instance
          .collection('artifacts').doc('finanzas_app')
          .collection('users').doc(user.uid)
          .collection('Movimientos')
          .where('accountId', isEqualTo: docId)
          .get();

      for (var doc in movimientosSnap.docs) {
        batch.delete(doc.reference);
      }

      // 2.2 Borrar la cuenta
      final cuentaRef = FirebaseFirestore.instance
          .collection('artifacts').doc('finanzas_app')
          .collection('users').doc(user.uid)
          .collection('Cuentas').doc(docId);
      
      batch.delete(cuentaRef);

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Cierra el modal de edición
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🗑️ Cuenta eliminada"), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al eliminar"), backgroundColor: Colors.red),
        );
      }
    }
  }

void _editarCuenta(String docId, Map<String, dynamic> currentData) {
    String nuevoAlias = currentData['alias'] ?? currentData['name'];
    int colorSeleccionado = currentData['customColor'] ?? _getAutoColor(currentData['institutionName'] ?? '').value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Personalizar Cuenta", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo de Texto
                  TextField(
                    decoration: const InputDecoration(labelText: "Nombre corto (Alias)", border: OutlineInputBorder()),
                    controller: TextEditingController(text: nuevoAlias),
                    onChanged: (val) => nuevoAlias = val,
                  ),
                  
                  const SizedBox(height: 20),
                  Text("Elige un color:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  
                  // Selector de Colores
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: paletaColores.map((color) {
                      final isSelected = color.value == colorSeleccionado;
                      return GestureDetector(
                        onTap: () => setModalState(() => colorSeleccionado = color.value),
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      onPressed: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          await FirebaseFirestore.instance
                              .collection('artifacts').doc('finanzas_app')
                              .collection('users').doc(uid)
                              .collection('Cuentas').doc(docId)
                              .update({
                            'alias': nuevoAlias,
                            'customColor': colorSeleccionado
                          });
                        }
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text("Guardar Cambios", style: TextStyle(color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- NUEVO BOTÓN DE ELIMINAR ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Eliminar esta cuenta"),
                      onPressed: () {
                        // Cerramos el modal actual primero si quieres, o llamamos directo.
                        // Como _eliminarCuenta muestra un diálogo encima, está bien llamarlo directo.
                        _eliminarCuenta(docId);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// --- PEGA ESTO EN LUGAR DE LA FUNCIÓN VIEJA ---
  Future<void> _refrescarDatos() async {
    setState(() => _cargando = true);
    final user = FirebaseAuth.instance.currentUser;
    
    // 1. Seguridad: Si no hay usuario logueado, cancelamos para evitar errores
    if (user == null) {
        if (mounted) setState(() => _cargando = false);
        return;
    }

    try {
      // 2. CORRECCIÓN CLAVE: Enviamos el 'uid' explícitamente entre llaves {}
      await FirebaseFunctions.instance.httpsCallable('sincronizarAhora').call({
        "uid": user.uid 
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🔄 Datos actualizados correctamente"), backgroundColor: Colors.green)
        );
      }
    } catch (e) { 
      debugPrint("Error Sync: $e"); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    } finally { 
      if (mounted) setState(() => _cargando = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFFF4F6F8),
            elevation: 0,
            expandedHeight: 80,
            floating: false, pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 10),
              title: Text("Mis Finanzas", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
            ),
            actions: [
              IconButton(
                // Este es el botón que llama a la función corregida
                icon: _cargando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync, color: Colors.black),
                onPressed: _cargando ? null : _refrescarDatos,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.black, size: 28),
                onPressed: _mostrarOpcionesAgregar,
              ),
              const SizedBox(width: 10),
            ],
          ),

          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                  .collection('users').doc(user.uid).collection('Cuentas').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: LinearProgressIndicator());
                
                var cuentas = snapshot.data!.docs;
                // Ordenar seguro
                cuentas.sort((a, b) {
                  int ordenA = (a.data() as Map)['sortOrder'] ?? 999;
                  int ordenB = (b.data() as Map)['sortOrder'] ?? 999;
                  return ordenA.compareTo(ordenB);
                });

                double patrimonioTotal = 0;
                for (var doc in cuentas) { 
                  final data = doc.data() as Map<String, dynamic>;
                  patrimonioTotal += (data['balance'] ?? 0.0); 
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Patrimonio Total", style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
                          IconButton(
                            icon: const Icon(Icons.sort, color: Colors.black),
                            tooltip: "Organizar cuentas",
                            onPressed: () => _mostrarReordenarCuentas(cuentas),
                          )
                        ],
                      ),
                      Text(currencyFormat.format(patrimonioTotal), 
                        style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
                      
                      const SizedBox(height: 25),

                      if (cuentas.isEmpty)
                        const Center(child: Text("Sin cuentas. Usa el + para empezar."))
                      else
                        ...cuentas.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final balance = (data['balance'] ?? 0.0).toDouble();
                          
                          Color cardColor = (data['customColor'] != null) 
                              ? Color(data['customColor']) 
                              : _getAutoColor(data['institutionName'] ?? '');
                          
                          final nombreMostrar = data['alias'] ?? data['name'];
                          
                          // DETECCIÓN DE BILT
                          final esBilt = (nombreMostrar.toString().toUpperCase().contains("BILT") || 
                                          (data['institutionName'] ?? "").toString().toUpperCase().contains("WELLS FARGO") || // Temporal por si acaso
                                          (data['institutionName'] ?? "").toString().toUpperCase().contains("BILT"));

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => CuentaDetalleScreen(accountId: doc.id, accountData: data, bankColor: cardColor)
                              ));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: cardColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                                        child: const FaIcon(FontAwesomeIcons.buildingColumns, color: Colors.white, size: 16),
                                      ),
                                      Row(
                                        children: [
                                          // --- BOTÓN IMPORTAR (SOLO BILT) ---
                                          if (esBilt) 
                                            GestureDetector(
                                              onTap: () {
                                                showModalBottomSheet(
                                                  context: context, 
                                                  isScrollControlled: true,
                                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                                  builder: (_) => ImportarBiltModal(accountId: doc.id, accountName: nombreMostrar)
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                margin: const EdgeInsets.only(right: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2), 
                                                  borderRadius: BorderRadius.circular(20)
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.content_paste, color: Colors.white, size: 14),
                                                    SizedBox(width: 5),
                                                    Text("Importar", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                                                  ],
                                                ),
                                              ),
                                            ),
                                          // ----------------------------------
                                          GestureDetector(
                                            onTap: () => _editarCuenta(doc.id, data),
                                            child: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Text(nombreMostrar, 
                                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
                                  
                                  if (data['institutionName'] != null)
                                    Text(data['institutionName'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                                  
                                  const SizedBox(height: 10),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 5),

                                  Text(currencyFormat.format(balance), 
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}