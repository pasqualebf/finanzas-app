import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'utils_categorias.dart'; 
import 'movimientos_filtrados_screen.dart';

class AnaliticaScreen extends StatefulWidget {
  const AnaliticaScreen({super.key});

  @override
  State<AnaliticaScreen> createState() => _AnaliticaScreenState();
}

class _AnaliticaScreenState extends State<AnaliticaScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
  
  DateTime _fechaInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fechaFin = DateTime.now();
  String? _cuentaFiltroId; 
  String _cuentaFiltroNombre = "Todas las cuentas";
  
  Map<String, double> _gastosPorCategoria = {};
  double _totalGastos = 0.0;
  double _totalIngresos = 0.0;
  double _totalAhorro = 0.0;
  bool _cargando = true;

  final List<Color> _coloresGrafica = [
    Color(0xFF4C4CFF), Color(0xFFFF4C4C), Color(0xFFFFB74D), 
    Color(0xFF4CAF50), Color(0xFF9C27B0), Color(0xFF00BCD4), 
    Color(0xFFFFEB3B), Color(0xFF795548), Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    Query query = FirebaseFirestore.instance
        .collection('artifacts').doc('finanzas_app')
        .collection('users').doc(uid)
        .collection('Movimientos')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_fechaInicio))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_fechaFin.add(const Duration(days: 1))));

    // --- AGREGA ESTA LÍNEA AQUÍ ABAJO 👇 ---
    // Esto fuerza a la consulta a usar tu índice existente (Descendente)
    query = query.orderBy('date', descending: true);

    if (_cuentaFiltroId != null) {
      query = query.where('accountId', isEqualTo: _cuentaFiltroId);
    }

    final snapshot = await query.get();

    double ingresos = 0;
    double gastos = 0;
    Map<String, double> categorias = {};

for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final double monto = (data['amount'] ?? 0).toDouble();
      final String tipo = data['type'] ?? 'expense';
      final String cat = data['category'] ?? 'Otros';

      // --- FILTRO MEJORADO ---
      // Si el tipo es 'transfer' O la categoría es explícitamente de traslado -> IGNORAR
      if (tipo == 'transfer' || cat == 'Transferencia' || cat == 'Pago Tarjeta' || cat == 'Credit Card Payment') {
        continue; 
      }

      if (tipo == 'income') {
        ingresos += monto;
      } else {
        // Asumimos que si no es income y no es transfer, es expense
        gastos += monto;
        categorias[cat] = (categorias[cat] ?? 0) + monto;
      }
    }

    if (mounted) {
      setState(() {
        _totalIngresos = ingresos;
        _totalGastos = gastos;
        _totalAhorro = ingresos - gastos;
        _gastosPorCategoria = Map.fromEntries(
            categorias.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
        );
        _cargando = false;
      });
    }
  }

  // --- CORRECCIÓN AQUÍ: Pasar el tipo 'expense' ---
void _verDetalle({String? categoria, String? tipo, required String titulo}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MovimientosFiltradosScreen(
      fechaInicio: _fechaInicio,
      fechaFin: _fechaFin,
      accountId: _cuentaFiltroId,
      categoria: categoria,
      tipo: tipo, 
      titulo: titulo,
    ))).then((_) {
       // ✨ MAGIA AQUÍ: 
       // El código dentro de .then() se ejecuta automáticamente cuando 
       // presionas "Atrás" y regresas a esta pantalla.
       _cargarDatos();
    });
  }

  // ... (El resto de funciones auxiliares como _mostrarFiltroCuentas y _seleccionarRangoFecha siguen igual) ...
  void _mostrarFiltroCuentas() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400,
          child: Column(
            children: [
              Text("Filtrar por cuenta", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                      .collection('users').doc(uid).collection('Cuentas').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var cuentas = snapshot.data!.docs;
                    return ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.account_balance_wallet),
                          title: const Text("Todas las cuentas"),
                          onTap: () {
                            setState(() { _cuentaFiltroId = null; _cuentaFiltroNombre = "Todas las cuentas"; });
                            _cargarDatos();
                            Navigator.pop(ctx);
                          },
                        ),
                        const Divider(),
                        ...cuentas.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.credit_card),
                            title: Text(data['alias'] ?? data['name']),
                            onTap: () {
                              setState(() { _cuentaFiltroId = doc.id; _cuentaFiltroNombre = data['alias'] ?? data['name']; });
                              _cargarDatos();
                              Navigator.pop(ctx);
                            },
                          );
                        }).toList()
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _seleccionarRangoFecha() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), 
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      builder: (context, child) => Theme(data: ThemeData.light().copyWith(primaryColor: Colors.black, colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Colors.white)), child: child!),
    );

    if (picked != null) {
      setState(() { _fechaInicio = picked.start; _fechaFin = picked.end; });
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          children: [
            Text("Analítica", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_cuentaFiltroNombre, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today, color: Colors.black), onPressed: _seleccionarRangoFecha),
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.black), onPressed: _mostrarFiltroCuentas),
        ],
      ),
      body: _cargando 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildResumenCards(),
                  const SizedBox(height: 30),
                  
                  if (_totalGastos > 0) ...[
                     Text("Distribución de Gastos", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 20),
                     SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2, centerSpaceRadius: 40, sections: _buildPieChartSections(),
                        ),
                      ),
                    ),
                  ] else 
                     Center(child: Text("Sin gastos registrados", style: GoogleFonts.poppins(color: Colors.grey))),

                  const SizedBox(height: 30),

                  Text("Detalle por Categoría", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._gastosPorCategoria.entries.map((entry) {
                    final porcentaje = (entry.value / _totalGastos) * 100;
                    final index = _gastosPorCategoria.keys.toList().indexOf(entry.key);
                    final color = _coloresGrafica[index % _coloresGrafica.length];
                    
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        // --- CORRECCIÓN CRÍTICA AQUÍ ---
                        // Cuando tocas una categoría de la lista de gastos, pasamos tipo: 'expense'
                        // Esto oculta los ingresos (Payment incorrectos) de esa vista detallada.
                        onTap: () => _verDetalle(categoria: entry.key, tipo: 'expense', titulo: entry.key),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Icon(getIconoCategoria(entry.key), color: color, size: 18),
                          ),
                          title: Text(entry.key, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          subtitle:  LinearProgressIndicator(
                            value: porcentaje / 100, backgroundColor: Colors.grey[200], color: color, minHeight: 6, borderRadius: BorderRadius.circular(3),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currencyFormat.format(entry.value), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              Text("${porcentaje.toStringAsFixed(1)}%", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList()
                ],
              ),
            ),
    );
  }

  Widget _buildResumenCards() {
    return Column(
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0,5))]),
          child: Column(
            children: [
              Text("Balance del Periodo", style: GoogleFonts.poppins(color: Colors.white70)),
              Text(currencyFormat.format(_totalAhorro), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _verDetalle(tipo: 'income', titulo: 'Ingresos del Periodo'),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.arrow_downward, color: Colors.green, size: 16), const SizedBox(width: 5), Text("Ingresos", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12))]),
                      const SizedBox(height: 5),
                      Text(currencyFormat.format(_totalIngresos), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () => _verDetalle(tipo: 'expense', titulo: 'Gastos del Periodo'),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Icon(Icons.arrow_upward, color: Colors.red, size: 16), const SizedBox(width: 5), Text("Gastos", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12))]),
                      const SizedBox(height: 5),
                      Text(currencyFormat.format(_totalGastos), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    int index = 0;
    return _gastosPorCategoria.entries.map((entry) {
      final isLarge = entry.value / _totalGastos > 0.15;
      final color = _coloresGrafica[index % _coloresGrafica.length];
      index++;
      return PieChartSectionData(
        color: color, value: entry.value, title: isLarge ? "${(entry.value / _totalGastos * 100).toStringAsFixed(0)}%" : "", radius: isLarge ? 60 : 50, titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }
}