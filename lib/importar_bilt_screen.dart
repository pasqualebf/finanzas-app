import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

class ImportarBiltModal extends StatefulWidget {
  final String accountId;
  final String accountName;

  const ImportarBiltModal({super.key, required this.accountId, required this.accountName});

  @override
  State<ImportarBiltModal> createState() => _ImportarBiltModalState();
}

class _ImportarBiltModalState extends State<ImportarBiltModal> {
  final _textoController = TextEditingController();
  bool _cargando = false;
  String? _resultado;

  Future<void> _procesarTexto() async {
    if (_textoController.text.trim().isEmpty) return;

    setState(() {
      _cargando = true;
      _resultado = null;
    });

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('importarMovimientosTexto').call({
        "accountId": widget.accountId,
        "texto": _textoController.text,
      });

      final count = result.data['count'] ?? 0;
      
      if (mounted) {
        setState(() {
          _cargando = false;
          _resultado = "✅ Se importaron $count movimientos correctamente.";
          _textoController.clear();
        });
        
        // Cerrar modal tras éxito después de un breve delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true); 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _resultado = "❌ Error: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        top: 20, left: 20, right: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Importar a ${widget.accountName}", 
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Copia los movimientos de la web de Bilt (Ctrl+C) y pégalos aquí:",
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 15),
          
          TextField(
            controller: _textoController,
            maxLines: 8,
            style: GoogleFonts.robotoMono(fontSize: 12),
            decoration: InputDecoration(
              hintText: "Ejemplo:\nFebruary 14, 2026\nMcDonald's\n\$6.80\n...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          
          if (_resultado != null) ...[
            const SizedBox(height: 15),
            Text(_resultado!, style: GoogleFonts.poppins(
              color: _resultado!.startsWith("✅") ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600
            )),
          ],

          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: _cargando ? null : _procesarTexto,
              child: _cargando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Procesar Movimientos", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}