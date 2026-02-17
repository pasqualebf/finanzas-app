import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'utils_icons_colores.dart'; // Tu nuevo archivo de iconos
import 'utils_categorias.dart';    // Tu archivo viejo con la lista 'categoriasGlobales'

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- DIÁLOGO EDITOR ---
  void _mostrarEditorCategoria({String? docId, Map<String, dynamic>? dataExistente}) {
    final nombreCtrl = TextEditingController(text: dataExistente?['name'] ?? '');
    
    // Recuperamos icono y color. 
    // Si es nuevo, icono default. Si editamos, buscamos su icono.
    String nombreActual = dataExistente?['name'] ?? 'Otros';
    String selectedIconKey = dataExistente?['iconKey'] ?? nombreActual; 
    Color selectedColor = intToColor(dataExistente?['colorValue']); 
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder( 
          builder: (context, setDialogState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(25, 20, 25, 20 + MediaQuery.of(context).viewInsets.bottom),
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text(docId == null ? "Nueva Categoría" : "Editar Categoría", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 30),

                    // VISTA PREVIA
                    Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: selectedColor.withOpacity(0.2), shape: BoxShape.circle),
                        // Aquí usamos el helper inteligente para mostrar el icono correcto
                        child: Icon(getIconoFromName(selectedIconKey), color: selectedColor, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder(), prefixIcon: Icon(Icons.label)),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 30),

                    // COLOR
                    Text("Color de Etiqueta", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: paletaColores.length,
                        itemBuilder: (context, index) {
                          final color = paletaColores[index];
                          final isSelected = selectedColor.value == color.value;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColor = color),
                            child: Container(
                              width: 45, height: 45,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ICONO
                    Text("Icono", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6, crossAxisSpacing: 10, mainAxisSpacing: 10,
                      ),
                      itemCount: mapaIconos.length,
                      itemBuilder: (context, index) {
                        final key = mapaIconos.keys.elementAt(index);
                        final iconData = mapaIconos.values.elementAt(index);
                        
                        // Lógica visual: Si la key coincide O si el icono es el mismo
                        final isSelected = selectedIconKey == key;
                        
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIconKey = key),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? selectedColor.withOpacity(0.2) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: selectedColor, width: 2) : null
                            ),
                            child: Icon(iconData, color: isSelected ? selectedColor : Colors.grey[400], size: 24),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),

                    // BOTÓN GUARDAR
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                        onPressed: () async {
                          if (nombreCtrl.text.trim().isEmpty) return;
                          
                          final uid = _auth.currentUser?.uid;
                          if (uid == null) return;
                          
                          // Guardamos "iconKey" con el nombre de la key del mapa (Ej: 'Restaurant')
                          final dataToSave = {
                            'name': nombreCtrl.text.trim(),
                            'iconKey': selectedIconKey, 
                            'colorValue': colorToInt(selectedColor),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          if (docId == null) {
                            await _db.collection('artifacts').doc('finanzas_app')
                                .collection('users').doc(uid).collection('user_categories').add(dataToSave);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Categoría creada")));
                          } else {
                            await _db.collection('artifacts').doc('finanzas_app')
                                .collection('users').doc(uid).collection('user_categories').doc(docId).update(dataToSave);
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Categoría actualizada")));
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(docId == null ? "Crear Categoría" : "Guardar Cambios", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                );
              }
            );
          }
        );
      }
    );
  }

  void _confirmarBorrado(String docId, String nombre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: Text("Vas a eliminar la categoría personalizada '$nombre'."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = _auth.currentUser?.uid;
              if (uid != null) {
                await _db.collection('artifacts').doc('finanzas_app')
                  .collection('users').doc(uid).collection('user_categories').doc(docId).delete();
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🗑️ Eliminada")));
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Mis Categorías"),
        backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () => _mostrarEditorCategoria(), 
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('artifacts').doc('finanzas_app')
            .collection('users').doc(uid).collection('user_categories')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 1. OBTENER CATEGORÍAS PERSONALIZADAS (Firestore)
          final customDocs = snapshot.data!.docs;
          
          // 2. PREPARAR LISTA FINAL (Globales + Personalizadas)
          // Empezamos con las globales del sistema
          List<Map<String, dynamic>> listaFinal = categoriasGlobales.map((catName) {
            return {
              'id': 'SYSTEM_$catName', // ID falso para identificarla
              'name': catName,
              'isSystem': true,
              'iconKey': catName, // La clave del icono suele ser el mismo nombre
              'colorValue': null, // Color default
            };
          }).toList();

          // Agregamos las personalizadas, o reemplazamos si el nombre coincide (Override)
          for (var doc in customDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Sin nombre';
            
            // Verificamos si ya existe en la lista (para no duplicar visualmente)
            int index = listaFinal.indexWhere((element) => element['name'] == name);
            
            final mapData = {
              'id': doc.id,
              'name': name,
              'isSystem': false, // Es tuya, es editable
              'iconKey': data['iconKey'],
              'colorValue': data['colorValue'],
            };

            if (index != -1) {
              // Si ya existía como global, la "sobrescribimos" visualmente con tu personalización
              listaFinal[index] = mapData;
            } else {
              // Si es nueva, la agregamos
              listaFinal.add(mapData);
            }
          }

          // Ordenar alfabéticamente
          listaFinal.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: listaFinal.length,
            itemBuilder: (context, index) {
              final item = listaFinal[index];
              final bool isSystem = item['isSystem'] == true;
              final name = item['name'];
              
              // Buscamos el icono usando el Helper del mapa nuevo
              final iconData = getIconoFromName(item['iconKey'] ?? name);
              final colorData = intToColor(item['colorValue']);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colorData.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(iconData, color: colorData),
                  ),
                  title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                  trailing: isSystem 
                    ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20) // Candado para sistema
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey),
                            onPressed: () => _mostrarEditorCategoria(docId: item['id'], dataExistente: item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmarBorrado(item['id'], name),
                          ),
                        ],
                      ),
                  // Si es del sistema, al hacer tap podrías clonarla o editarla para volverla custom
                  onTap: isSystem ? () {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("'$name' es del sistema. Crea una nueva para personalizar.")));
                  } : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}