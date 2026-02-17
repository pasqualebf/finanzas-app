import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'utils_categorias.dart';      // Lista base
import 'utils_icons_colores.dart';   // Iconos nuevos y colores

void mostrarEditorUniversal(BuildContext context, String docId, Map<String, dynamic> data) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final nombreCtrl = TextEditingController(text: data['name']);
  final notaCtrl = TextEditingController(text: (data['note'] as String?) ?? '');
  final montoCtrl = TextEditingController(text: (data['amount'] ?? 0).toString());
  
  String descripcionOriginal = (data['description'] as String?) ?? (data['name'] as String?) ?? '';
  String categoriaActual = (data['category'] as String?) ?? 'Otros';
  String categoriaOriginal = categoriaActual;
  
  String tipoMovimiento = (data['type'] as String?) ?? 'expense';
  String accountId = (data['accountId'] as String?) ?? '';

  showModalBottomSheet(
    context: context, 
    isScrollControlled: true, 
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (_, scrollController) {
          
          // 1. PRIMERO OBTENEMOS LAS CATEGORÍAS PERSONALIZADAS DE FIREBASE
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                .collection('users').doc(uid).collection('user_categories').orderBy('name').snapshots(),
            builder: (context, snapshotCats) {
              
              // 2. CONSTRUIMOS LA LISTA COMBINADA
              List<String> listaTotal = List.from(categoriasGlobales); // Empezamos con las del sistema
              
              if (snapshotCats.hasData) {
                for (var doc in snapshotCats.data!.docs) {
                  String nombreCustom = doc['name'];
                  // Evitamos duplicados visuales
                  if (!listaTotal.contains(nombreCustom)) {
                    listaTotal.add(nombreCustom);
                  }
                }
              }
              
              // Ordenamos alfabéticamente
              listaTotal.sort();

              // Aseguramos que la categoría actual esté en la lista (por si fue borrada)
              if (!listaTotal.contains(categoriaActual)) {
                listaTotal.add(categoriaActual);
              }

              // 3. LUEGO OBTENEMOS LA INFO DEL BANCO (Como antes)
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                    .collection('users').doc(uid).collection('Cuentas').doc(accountId).get(),
                builder: (context, snapshotAccount) {
                  String bancoNombre = "Cargando...";
                  bool esManual = false;
                  if (snapshotAccount.hasData && snapshotAccount.data!.exists) {
                    final cData = snapshotAccount.data!.data() as Map<String, dynamic>;
                    bancoNombre = "${cData['institutionName']} • ${cData['alias'] ?? cData['name']}";
                    esManual = (cData['type'] == 'manual') || (cData['institutionName'] == 'Manual');
                  }

                  return StatefulBuilder(builder: (context, setModalState) {
                    
                    void guardarCambios({bool crearRegla = false}) async {
                      if (crearRegla) {
                          final nombreRegla = nombreCtrl.text.trim().toUpperCase();
                          await FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                            .collection('users').doc(uid).collection('category_rules').doc(nombreRegla).set({
                              'category': categoriaActual,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'source': 'app_learning'
                            });
                      }

                      await FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                        .collection('users').doc(uid).collection('Movimientos').doc(docId).update({
                          'name': nombreCtrl.text, 
                          'note': notaCtrl.text, 
                          'category': categoriaActual, 
                          'type': tipoMovimiento, 
                          'isManual': true
                        });

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(crearRegla ? "✅ Guardado y Aprendido" : "✅ Actualizado"))
                        );
                      }
                    }

                    return ListView(
                      controller: scrollController, padding: const EdgeInsets.all(25),
                      children: [
                        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 20),
                        Text("Detalle del Movimiento", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 15),
                        
                        Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [const Icon(Icons.account_balance, size: 20, color: Colors.grey), const SizedBox(width: 10), Expanded(child: Text(bancoNombre, style: GoogleFonts.poppins(color: Colors.grey[800], fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1))]),
                        ),
                        const SizedBox(height: 20),

                        if (descripcionOriginal.isNotEmpty && descripcionOriginal != nombreCtrl.text)
                          Container(
                            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(color: Colors.blueGrey[50], border: Border.all(color: Colors.blueGrey[100]!), borderRadius: BorderRadius.circular(10)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("DESCRIPCIÓN ORIGINAL:", style: GoogleFonts.poppins(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(descripcionOriginal, style: GoogleFonts.poppins(fontSize: 12, color: Colors.blueGrey[800])),
                            ]),
                          ),

                        TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre Visible", border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit))),
                        const SizedBox(height: 15),
                        TextField(controller: notaCtrl, decoration: const InputDecoration(labelText: "Nota Personal", border: OutlineInputBorder(), prefixIcon: Icon(Icons.note_alt, color: Colors.amber), filled: true, fillColor: Color(0xFFFFF8E1))),
                        const SizedBox(height: 15),
                        
                        // SELECTOR DE TIPO (3 OPCIONES)
                        Row(children: [
                          Expanded(child: ChoiceChip(
                            label: const Text("Gasto"), selected: tipoMovimiento == 'expense', selectedColor: Colors.red[100], 
                            onSelected: (val) => setModalState(() => tipoMovimiento = 'expense'), avatar: const Icon(Icons.arrow_upward, color: Colors.red, size: 18)
                          )),
                          const SizedBox(width: 5),
                          Expanded(child: ChoiceChip(
                            label: const Text("Ingreso"), selected: tipoMovimiento == 'income', selectedColor: Colors.green[100], 
                            onSelected: (val) => setModalState(() => tipoMovimiento = 'income'), avatar: const Icon(Icons.arrow_downward, color: Colors.green, size: 18)
                          )),
                          const SizedBox(width: 5),
                          Expanded(child: ChoiceChip(
                            label: const Text("Neutro"), selected: tipoMovimiento == 'transfer', selectedColor: Colors.blue[100], 
                            onSelected: (val) => setModalState(() => tipoMovimiento = 'transfer'), avatar: const Icon(Icons.swap_horiz, color: Colors.blue, size: 18)
                          )),
                        ]),
                        
                        if (tipoMovimiento == 'transfer')
                           Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text("ℹ️ No se sumará a gastos ni ingresos.", style: TextStyle(fontSize: 11, color: Colors.blue[800], fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                           ),

                        const SizedBox(height: 15),

                        // DROPDOWN CON LISTA COMPLETA
                        DropdownButtonFormField<String>(
                          value: listaTotal.contains(categoriaActual) ? categoriaActual : null, 
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: "Categoría", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                          items: listaTotal.map((cat) {
                            // Usamos el helper nuevo para buscar el icono correcto (sea sistema o custom)
                            final iconData = getIconoFromName(cat);
                            return DropdownMenuItem(
                              value: cat, 
                              child: Row(children: [
                                Icon(iconData, size: 18, color: Colors.grey), 
                                const SizedBox(width: 10), 
                                Expanded(child: Text(cat, overflow: TextOverflow.ellipsis))
                              ])
                            );
                          }).toList(),
                          onChanged: (val) { if (val != null) setModalState(() => categoriaActual = val); },
                        ),
                        const SizedBox(height: 15),

                        TextField(controller: montoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                          readOnly: !esManual, style: TextStyle(color: !esManual ? Colors.grey : Colors.black),
                          decoration: InputDecoration(labelText: "Monto", prefixText: "\$", border: OutlineInputBorder(), prefixIcon: const Icon(Icons.attach_money), suffixIcon: !esManual ? const Icon(Icons.lock, color: Colors.grey) : null),
                        ),
                        const SizedBox(height: 30),
                        
                        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            onPressed: () {
                              if (categoriaActual != categoriaOriginal) {
                                showDialog(
                                  context: context,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text("🤖 Aprendizaje Inteligente"),
                                    content: Text("He notado que cambiaste la categoría a '$categoriaActual'.\n\n¿Quieres que clasifique automáticamente todos los futuros movimientos de '${nombreCtrl.text}' como '$categoriaActual'?"),
                                    actions: [
                                      TextButton(onPressed: () { Navigator.pop(dialogCtx); guardarCambios(crearRegla: false); }, child: const Text("Solo esta vez", style: TextStyle(color: Colors.grey))),
                                      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black), onPressed: () { Navigator.pop(dialogCtx); guardarCambios(crearRegla: true); }, child: const Text("Sí, aprender siempre"))
                                    ],
                                  )
                                );
                              } else {
                                guardarCambios(crearRegla: false);
                              }
                            },
                            child: const Text("Guardar Cambios", style: TextStyle(color: Colors.white, fontSize: 16)),
                        )),
                        const SizedBox(height: 20),
                        Text("Fecha: ${DateFormat('dd MMM yyyy - HH:mm').format((data['date'] as Timestamp).toDate())}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ],
                    );
                  });
                }
              );
            }
          );
        }
      );
    }
  );
}