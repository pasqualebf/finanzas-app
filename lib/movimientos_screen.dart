import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'utils_categorias.dart'; 
import 'transaction_modal.dart'; 

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  // --- ESTADO DE LOS FILTROS ---
  String _busquedaTexto = "";
  
  // Filtros Avanzados
  DateTimeRange? _rangoFechas; // Si es null, muestra todo (o límite 100)
  List<String> _categoriasSeleccionadas = []; // Vacío = Todas
  List<String> _cuentasSeleccionadas = []; // Vacío = Todas

  // --- UI: MOSTRAR FILTROS AVANZADOS ---
  void _mostrarFiltrosAvanzados() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            
            return DraggableScrollableSheet(
              initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Text("Filtros Avanzados", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 25),

                    // 1. FECHAS
                    Text("Rango de Fechas", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _rangoFechas,
                          builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.black)), child: child!),
                        );
                        if (picked != null) {
                          setModalState(() => _rangoFechas = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_rangoFechas == null 
                                ? "Cualquier fecha (Últimos 100)" 
                                : "${DateFormat('dd/MM/yy').format(_rangoFechas!.start)} - ${DateFormat('dd/MM/yy').format(_rangoFechas!.end)}",
                                style: TextStyle(color: _rangoFechas == null ? Colors.grey : Colors.black)
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    if (_rangoFechas != null)
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setModalState(() => _rangoFechas = null), child: const Text("Borrar fecha", style: TextStyle(color: Colors.red)))),

                    const Divider(height: 30),

                    // 2. CUENTAS (Multi-selección)
                    Text("Cuentas", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                          .collection('users').doc(uid).collection('Cuentas').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        final docs = snapshot.data!.docs;
                        
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['alias'] ?? data['name'];
                            final isSelected = _cuentasSeleccionadas.contains(doc.id);
                            
                            return FilterChip(
                              label: Text(name),
                              selected: isSelected,
                              selectedColor: Colors.black,
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) _cuentasSeleccionadas.add(doc.id);
                                  else _cuentasSeleccionadas.remove(doc.id);
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const Divider(height: 30),

                    // 3. CATEGORÍAS (Multi-selección)
                    Text("Categorías", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: categoriasGlobales.map((cat) {
                        final isSelected = _categoriasSeleccionadas.contains(cat);
                        return FilterChip(
                          label: Text(cat),
                          avatar: isSelected ? null : Icon(getIconoCategoria(cat), size: 16),
                          selected: isSelected,
                          selectedColor: Colors.black,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) _categoriasSeleccionadas.add(cat);
                              else _categoriasSeleccionadas.remove(cat);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                    
                    // BOTONES DE ACCIÓN
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Limpiar todo
                              setState(() {
                                _rangoFechas = null;
                                _cuentasSeleccionadas.clear();
                                _categoriasSeleccionadas.clear();
                              });
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                            child: const Text("Limpiar filtros", style: TextStyle(color: Colors.black)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {}); // Actualiza la pantalla principal
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 15)),
                            child: const Text("Aplicar", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    )
                  ],
                );
              }
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final dateFormat = DateFormat('dd MMM');

    // 1. CONSTRUCCIÓN DE LA QUERY BASE (Solo Fecha)
    Query query = FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
        .collection('users').doc(uid).collection('Movimientos');

    // Aplicar filtro de fecha en la Query (Es lo más eficiente)
    if (_rangoFechas != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_rangoFechas!.start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_rangoFechas!.end.add(const Duration(days: 1))))
          .orderBy('date', descending: true);
    } else {
      // Si no hay fecha, traemos los últimos 100 para no saturar
      query = query.orderBy('date', descending: true).limit(100);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text("Movimientos", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          // Icono cambia si hay filtros activos
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list_alt, color: Colors.black), 
                onPressed: _mostrarFiltrosAvanzados
              ),
              if (_rangoFechas != null || _cuentasSeleccionadas.isNotEmpty || _categoriasSeleccionadas.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(10),
                  width: 10, height: 10,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                )
            ],
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(padding: const EdgeInsets.all(10), child: TextField(
            decoration: InputDecoration(
              hintText: "Buscar por nombre...", 
              prefixIcon: const Icon(Icons.search), 
              filled: true, fillColor: Colors.grey[100], 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
            ),
            onChanged: (val) => setState(() => _busquedaTexto = val),
          )),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;

          // 2. FILTRADO EN MEMORIA (Cliente)
          // Aquí aplicamos Cuenta, Categoría y Texto
          final movimientosFiltrados = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Filtro Texto
            final nombre = (data['name'] ?? '').toString().toLowerCase();
            if (_busquedaTexto.isNotEmpty && !nombre.contains(_busquedaTexto.toLowerCase())) return false;

            // Filtro Categoría
            final cat = (data['category'] ?? 'Otros').toString();
            if (_categoriasSeleccionadas.isNotEmpty && !_categoriasSeleccionadas.contains(cat)) return false;

            // Filtro Cuenta
            final accId = (data['accountId'] ?? '').toString();
            if (_cuentasSeleccionadas.isNotEmpty && !_cuentasSeleccionadas.contains(accId)) return false;

            return true;
          }).toList();

          if (movimientosFiltrados.isEmpty) return const Center(child: Text("No se encontraron movimientos"));

          return ListView.builder(
            padding: const EdgeInsets.all(15), 
            itemCount: movimientosFiltrados.length,
            itemBuilder: (context, index) {
              final data = movimientosFiltrados[index].data() as Map<String, dynamic>;
              final amount = (data['amount'] ?? 0).toDouble();
              final isIncome = data['type'] == 'income';
              final catName = (data['category'] as String?) ?? 'Otros';
              
              return Card(
                elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  // Editor Universal
                  onTap: () => mostrarEditorUniversal(context, movimientosFiltrados[index].id, data),
                  leading: CircleAvatar(backgroundColor: Colors.grey[100], child: Icon(getIconoCategoria(catName), color: Colors.black, size: 20)),
                  title: Text(data['name'] ?? 'Sin nombre', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(dateFormat.format((data['date'] as Timestamp).toDate()), style: GoogleFonts.poppins(fontSize: 12)),
                  trailing: Text("${isIncome ? '+' : ''}${currencyFormat.format(amount)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.black87)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}