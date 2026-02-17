import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'utils_categorias.dart'; 
import 'transaction_modal.dart'; // IMPORTANTE: Conectamos el Editor Universal

class CuentaDetalleScreen extends StatefulWidget {
  final String accountId;
  final Map<String, dynamic> accountData;
  final Color bankColor;

  const CuentaDetalleScreen({
    super.key, 
    required this.accountId, 
    required this.accountData,
    required this.bankColor,
  });

  @override
  State<CuentaDetalleScreen> createState() => _CuentaDetalleScreenState();
}

class _CuentaDetalleScreenState extends State<CuentaDetalleScreen> {
  
  // --- 1. AGREGAR MOVIMIENTO (Se mantiene local porque es CREACIÓN, no edición) ---
  void _agregarMovimientoRapido() {
    final nombreCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String tipoMovimiento = 'expense';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget selector(String label, String val, Color col) {
              final selected = tipoMovimiento == val;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setModalState(() => tipoMovimiento = val),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? col.withOpacity(0.1) : Colors.transparent,
                      border: Border.all(color: selected ? col : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10)
                    ),
                    alignment: Alignment.center,
                    child: Text(label, style: TextStyle(color: selected ? col : Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Agregar a ${widget.accountData['alias'] ?? widget.accountData['name']}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(children: [
                    selector("Gasto", 'expense', Colors.red),
                    selector("Ingreso", 'income', Colors.green),
                  ]),
                  const SizedBox(height: 15),
                  TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Concepto", border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 10),
                  TextField(controller: montoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Monto", prefixText: "\$", border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: widget.bankColor),
                      onPressed: () {
                        if (nombreCtrl.text.isNotEmpty && montoCtrl.text.isNotEmpty) {
                          _guardarMovimiento(nombreCtrl.text, double.parse(montoCtrl.text), tipoMovimiento);
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text("Guardar", style: TextStyle(color: Colors.white)),
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

  Future<void> _guardarMovimiento(String nombre, double monto, String tipo) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userRef = FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app').collection('users').doc(uid);

    await userRef.collection('Movimientos').add({
      'name': nombre,
      'amount': monto,
      'category': 'Otros',
      'date': Timestamp.now(),
      'accountId': widget.accountId,
      'type': tipo,
      'isManual': true,
    });

    bool esManual = (widget.accountData['type'] == 'manual') || (widget.accountData['institutionName'] == 'Manual');
    
    if (esManual) {
      final cuentaRef = userRef.collection('Cuentas').doc(widget.accountId);
      FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(cuentaRef);
        double saldo = (snapshot.data()?['balance'] ?? 0.0).toDouble();
        if (tipo == 'income') saldo += monto;
        else saldo -= monto;
        transaction.update(cuentaRef, {'balance': saldo});
      });
    }
  }

  // --- MENÚ DE OPCIONES (Editar/Eliminar) ---
  void _confirmarAccion(String docId, Map<String, dynamic> movData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(movData['name'] ?? 'Movimiento', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Editar Movimiento"),
              onTap: () {
                 Navigator.pop(ctx);
                 // AQUÍ USAMOS EL MODULO UNIVERSAL
                 mostrarEditorUniversal(context, docId, movData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Eliminar Movimiento"),
              onTap: () {
                Navigator.pop(ctx);
                _borrarMovimientoSeguro(docId, movData);
              },
            ),
          ],
        ),
      )
    );
  }

  Future<void> _borrarMovimientoSeguro(String docId, Map<String, dynamic> movData) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userRef = FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app').collection('users').doc(uid);
    final movRef = userRef.collection('Movimientos').doc(docId);
    final cuentaRef = userRef.collection('Cuentas').doc(widget.accountId);

    bool esManual = (widget.accountData['type'] == 'manual') || (widget.accountData['institutionName'] == 'Manual');

    if (esManual) {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final cuentaSnap = await transaction.get(cuentaRef);
        if (!cuentaSnap.exists) return;
        double saldo = (cuentaSnap.data()?['balance'] ?? 0).toDouble();
        double monto = (movData['amount'] ?? 0).toDouble();
        String tipo = movData['type'] ?? 'expense';
        // Si borramos un gasto, el saldo sube. Si borramos ingreso, baja.
        if (tipo == 'income') saldo -= monto; else saldo += monto;
        transaction.update(cuentaRef, {'balance': saldo});
        transaction.delete(movRef);
      });
    } else {
      await movRef.delete();
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🗑️ Eliminado")));
  }

  Widget _buildErrorWidget(Object? error) {
    return const Center(child: Text("Error cargando datos."));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final dateFormat = DateFormat('dd MMM');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: widget.bankColor,
        title: Text(widget.accountData['alias'] ?? widget.accountData['name'], style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarMovimientoRapido,
        backgroundColor: widget.bankColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
           Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
            decoration: BoxDecoration(
              color: widget.bankColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: widget.bankColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.accountData['institutionName'] ?? 'Banco', style: GoogleFonts.poppins(color: Colors.white70)),
                const SizedBox(height: 5),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('artifacts').doc('finanzas_app')
                      .collection('users').doc(user!.uid).collection('Cuentas').doc(widget.accountId).snapshots(),
                  builder: (context, snapshot) {
                    double saldo = widget.accountData['balance'];
                    if (snapshot.hasData && snapshot.data!.exists) {
                        saldo = (snapshot.data!.get('balance') ?? 0).toDouble();
                    }
                    return Text(
                      currencyFormat.format(saldo),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    );
                  }
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('artifacts').doc('finanzas_app')
                  .collection('users').doc(user.uid)
                  .collection('Movimientos')
                  .where('accountId', isEqualTo: widget.accountId)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorWidget(snapshot.error);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("Sin movimientos"));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final amount = (data['amount'] ?? 0).toDouble();
                    final isIncome = data['type'] == 'income';
                    final category = data['category'] ?? 'Otros';
                    final bool isManual = data['isManual'] == true;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Container(
                        decoration: BoxDecoration(
                          border: isManual ? const Border(left: BorderSide(color: Colors.amber, width: 4)) : null,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          // AL TOCAR, SE ABRE EL MENÚ, Y SI ELIGES EDITAR, SE ABRE EL MODAL UNIVERSAL
                          onTap: () => _confirmarAccion(docs[index].id, data), 
                          leading: CircleAvatar(
                            backgroundColor: widget.bankColor.withOpacity(0.1),
                            child: Icon(getIconoCategoria(category), color: widget.bankColor, size: 20),
                          ),
                          title: Text(data['name'] ?? 'Movimiento', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateFormat.format((data['date'] as Timestamp).toDate())),
                              Text(category, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Text(
                            "${isIncome ? '+' : ''}${currencyFormat.format(amount)}",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.black87),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}