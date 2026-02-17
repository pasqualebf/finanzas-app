import 'dart:convert';
import 'dart:io'; // Necesario para detectar Android y manejar archivos
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class BackupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. EXPORTAR MEJORADO ---
  Future<void> exportarDatos(BuildContext context) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⏳ Creando respaldo...")));

      // A. Recopilar Datos
      final cuentas = await _db.collection('artifacts').doc('finanzas_app').collection('users').doc(uid).collection('Cuentas').get();
      final movs = await _db.collection('artifacts').doc('finanzas_app').collection('users').doc(uid).collection('Movimientos').get();
      final reglas = await _db.collection('artifacts').doc('finanzas_app').collection('users').doc(uid).collection('category_rules').get();

      final data = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'cuentas': cuentas.docs.map((d) => _docToMap(d)).toList(),
        'movimientos': movs.docs.map((d) => _docToMap(d)).toList(),
        'reglas': reglas.docs.map((d) => _docToMap(d)).toList(),
      };

      final jsonString = jsonEncode(data);
      final fileName = 'respaldo_finanzas_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // B. INTENTO DE GUARDADO DIRECTO (Android)
      bool guardadoDirectoExitoso = false;
      String rutaFinal = "";

      if (Platform.isAndroid) {
        try {
          // Intentamos escribir directo en la carpeta pública de Descargas
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            rutaFinal = '${downloadDir.path}/$fileName';
            final file = File(rutaFinal);
            await file.writeAsString(jsonString);
            guardadoDirectoExitoso = true;
          }
        } catch (e) {
          // Si falla (por permisos), no hacemos nada y pasamos al Plan B (Compartir)
          print("No se pudo guardar directo: $e");
        }
      }

      // C. RESULTADO
      if (guardadoDirectoExitoso) {
        // ÉXITO: Avisamos dónde está
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars(); // Limpiar el "Cargando..."
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("✅ Respaldo Guardado"),
              content: Text("El archivo se guardó correctamente en tu carpeta de DESCARGAS:\n\n$fileName\n\nPuedes buscarlo con tu gestor de archivos."),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
                // Opción extra por si acaso quiere enviarlo
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Share.shareXFiles([XFile(rutaFinal)], text: 'Respaldo Finanzas');
                  }, 
                  child: const Text("Compartir también")
                )
              ],
            )
          );
        }
      } else {
        // PLAN B: Usar Share (como antes) pero guardando en temporal primero
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(jsonString);
        
        if (context.mounted) {
           ScaffoldMessenger.of(context).hideCurrentSnackBar();
           // Le decimos al usuario qué hacer
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text("⚠️ Selecciona 'Guardar en Archivos' o tu gestor de archivos"),
             duration: Duration(seconds: 4),
           ));
        }
        await Share.shareXFiles([XFile(filePath)], text: 'Respaldo de Mis Finanzas');
      }
      
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- 2. IMPORTAR (SIN CAMBIOS) ---
  Future<void> importarDatos(BuildContext context) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⏳ Restaurando...")));
        
        File file = File(result.files.single.path!);
        String content = await file.readAsString();
        Map<String, dynamic> data = jsonDecode(content);

        await _restaurarColeccion(uid, 'Cuentas', data['cuentas']);
        await _restaurarColeccion(uid, 'category_rules', data['reglas']);
        await _restaurarColeccion(uid, 'Movimientos', data['movimientos']);

        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Restaurado con éxito")));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- UTILS (SIN CAMBIOS) ---
  Map<String, dynamic> _docToMap(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['__docId__'] = doc.id;
    data.forEach((key, value) {
      if (value is Timestamp) data[key] = "TIMESTAMP::${value.toDate().toIso8601String()}";
    });
    return data;
  }

  Future<void> _restaurarColeccion(String uid, String colName, List<dynamic>? items) async {
    if (items == null) return;
    final ref = _db.collection('artifacts').doc('finanzas_app').collection('users').doc(uid).collection(colName);
    var batch = _db.batch();
    int count = 0;

    for (var item in items) {
      String id = item['__docId__'];
      Map<String, dynamic> d = Map.from(item);
      d.remove('__docId__');
      d.forEach((k, v) {
        if (v is String && v.startsWith("TIMESTAMP::")) d[k] = Timestamp.fromDate(DateTime.parse(v.replaceAll("TIMESTAMP::", "")));
      });

      batch.set(ref.doc(id), d, SetOptions(merge: true));
      count++;
      if (count >= 400) { await batch.commit(); batch = _db.batch(); count = 0; }
    }
    if (count > 0) await batch.commit();
  }
}