import 'package:flutter/material.dart';

// --- CATÁLOGO DE COLORES ---
final List<Color> paletaColores = [
  Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
  Colors.teal, Colors.pink, Colors.indigo, Colors.brown, Colors.cyan,
  Colors.deepOrange, Colors.lime, Colors.amber, Colors.lightBlue, Colors.blueGrey,
  Colors.black,
];

// Helpers
int colorToInt(Color color) => color.value;
Color intToColor(int? value) => value == null ? Colors.blue : Color(value);

// --- CATÁLOGO MAESTRO DE ICONOS ---
// Clave: Nombre exacto de la categoría -> Valor: Icono
final Map<String, IconData> mapaIconos = {
  // --- Categorías del Sistema (Las que ya tenías) ---
  'Restaurant': Icons.restaurant,
  'Supermercado': Icons.shopping_cart,
  'Gasolina': Icons.local_gas_station,
  'Servicios': Icons.lightbulb,
  'Subscripcion': Icons.subscriptions, // Ojo con la 'b'
  'Entretenimiento': Icons.movie,
  'Compras': Icons.shopping_bag,
  'Salud': Icons.health_and_safety,
  'Transporte': Icons.directions_car,
  'Hogar': Icons.home,
  'Sueldo': Icons.attach_money,
  'Transferencia': Icons.swap_horiz,
  'Mortgage': Icons.real_estate_agent, // O casa
  'Car Insurance': Icons.car_crash,
  'Travel': Icons.flight,
  'Pago Tarjeta': Icons.credit_card_off,
  'Otros': Icons.category,

  // --- Opciones genéricas para nuevas categorías ---
  'gym': Icons.fitness_center,
  'ropa': Icons.checkroom,
  'cafe': Icons.local_cafe,
  'bar': Icons.local_bar,
  'banco': Icons.account_balance,
  'mascota': Icons.pets,
  'bebe': Icons.child_friendly,
  'educacion': Icons.school,
  'regalo': Icons.card_giftcard,
  'reparacion': Icons.build,
  'trabajo': Icons.work,
  'freelance': Icons.laptop_mac,
  'juegos': Icons.sports_esports,
  'musica': Icons.music_note,
  'telefono': Icons.phone_iphone,
  'internet': Icons.wifi,
  'agua': Icons.water_drop,
};

// Helper Inteligente: Busca en el mapa nuevo, si no, usa un default
IconData getIconoFromName(String? name) {
  if (name == null) return Icons.category;
  
  // 1. Busqueda exacta (Ej: "Restaurant")
  if (mapaIconos.containsKey(name)) {
    return mapaIconos[name]!;
  }
  
  // 2. Busqueda insensible a mayúsculas (Ej: "restaurant")
  // Esto ayuda a conectar lo viejo con lo nuevo
  try {
    final key = mapaIconos.keys.firstWhere((k) => k.toLowerCase() == name.toLowerCase());
    return mapaIconos[key]!;
  } catch (e) {
    return Icons.category; // Si falla todo, devuelve icono genérico
  }
}