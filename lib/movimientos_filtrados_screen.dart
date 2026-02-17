import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'utils_categorias.dart'; 
import 'transaction_modal.dart'; // IMPORTANTE: Conectamos el Editor Universal

class MovimientosFiltradosScreen extends StatefulWidget {
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? categoria;
  final String? tipo; 
  final String? accountId;
  final String titulo;

  const MovimientosFiltradosScreen({
    super.key,
    required this.fechaInicio,
    required this.fechaFin,
    required this.titulo,
    this.categoria,
    this.tipo,
    this.accountId,
  });

  @override
  State<MovimientosFiltradosScreen> createState() => _MovimientosFiltradosScreenState();
}

class _MovimientosFiltradosScreenState extends State<MovimientosFiltradosScreen> {
  
  // Hemos eliminado _mostrarDetalleCompleto y _guardarCambios
  // porque ahora usamos la lógica centralizada en transaction_modal.dart

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final dateFormat = DateFormat('dd MMM');

    Query query = FirebaseFirestore.instance
        .collection('artifacts').doc('finanzas_app')
        .collection('users').doc(uid)
        .collection('Movimientos')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(widget.fechaInicio))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(widget.fechaFin.add(const Duration(days: 1))))
        .orderBy('date', descending: true);

    if (widget.accountId != null) {
      query = query.where('accountId', isEqualTo: widget.accountId);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(widget.titulo, style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          
          final movimientosFiltrados = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['category'] as String?) ?? 'Otros';
            final type = (data['type'] as String?) ?? 'expense';

            if (widget.categoria != null && cat != widget.categoria) return false;
            if (widget.tipo != null && type != widget.tipo) return false;
            
            // Lógica para excluir movimientos neutros si no estamos filtrando por categoría específica
            bool esNeutro = (cat == 'Transferencia' || cat == 'Credit Card Payment' || cat == 'Pago Tarjeta');
            if (widget.categoria != null) return true; 
            if (esNeutro) return false; 
            return true;
          }).toList();

          if (movimientosFiltrados.isEmpty) {
            return Center(child: Text("No se encontraron movimientos", style: GoogleFonts.poppins(color: Colors.grey)));
          }

          double totalLista = 0;
          for (var doc in movimientosFiltrados) {
             final d = doc.data() as Map<String, dynamic>;
             double amt = (d['amount'] ?? 0).toDouble();
             if (widget.tipo == 'expense') totalLista += amt;
             else if (widget.tipo == 'income') totalLista += amt;
             else {
                if (d['type'] == 'income') totalLista += amt;
                else totalLista -= amt;
             }
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total verificado:", style: GoogleFonts.poppins(color: Colors.grey)),
                    Text(currencyFormat.format(totalLista), style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: movimientosFiltrados.length,
                  itemBuilder: (context, index) {
                    final data = movimientosFiltrados[index].data() as Map<String, dynamic>;
                    final amount = (data['amount'] ?? 0).toDouble();
                    final isIncome = data['type'] == 'income';
                    final catName = (data['category'] as String?) ?? 'Otros';
                    final nota = data['note'] as String?; 

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        // AQUÍ CONECTAMOS EL EDITOR UNIVERSAL
                        onTap: () => mostrarEditorUniversal(context, movimientosFiltrados[index].id, data), 
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          child: Icon(getIconoCategoria(catName), color: Colors.black, size: 20),
                        ),
                        title: Text(data['name'] ?? 'Sin nombre', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateFormat.format((data['date'] as Timestamp).toDate()), style: GoogleFonts.poppins(fontSize: 12)),
                            if (nota != null && nota.isNotEmpty) 
                               Text("📝 $nota", style: GoogleFonts.poppins(fontSize: 11, color: Colors.amber[800], fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Text(
                          "${isIncome ? '+' : ''}${currencyFormat.format(amount)}",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}