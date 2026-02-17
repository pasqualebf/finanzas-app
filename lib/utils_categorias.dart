import 'package:flutter/material.dart';

// --- LISTA MAESTRA (Incluye 'Pago Tarjeta') ---
final List<String> categoriasGlobales = [
  'Otros',
  'Restaurant',
  'Supermercado',
  'Gasolina',
  'Servicios',
  'Subscripcion',
  'Entretenimiento',
  'Compras',
  'Salud',
  'Transporte',
  'Hogar',
  'Sueldo',
  'Transferencia',
  'Mortgage',
  'Car Insurance',
  'Travel',
  'Pago Tarjeta' // <--- NUEVA CATEGORÍA OFICIAL
];

// --- MAPA DE ÍCONOS ---
IconData getIconoCategoria(String categoria) {
  switch (categoria) {
    case 'Restaurant': return Icons.restaurant;
    case 'Supermercado': return Icons.shopping_cart;
    case 'Gasolina': return Icons.local_gas_station;
    case 'Servicios': return Icons.lightbulb;
    case 'Subscripcion': return Icons.subscriptions;
    case 'Entretenimiento': return Icons.movie;
    case 'Compras': return Icons.shopping_bag;
    case 'Salud': return Icons.local_hospital;
    case 'Transporte': return Icons.directions_car;
    case 'Hogar': return Icons.home;
    case 'Sueldo': return Icons.attach_money;
    case 'Transferencia': return Icons.compare_arrows;
    case 'Mortgage': return Icons.house;
    case 'Car Insurance': return Icons.car_crash;
    case 'Travel': return Icons.flight;
    case 'Pago Tarjeta': return Icons.credit_card_off; // Ícono para pago de deuda
    case 'Otros': return Icons.category;
    default: return Icons.help_outline;
  }
}

Color getColorCategoria(String categoria) {
  // Opcional: Colores para gráficas si los usas
  return Colors.grey; 
}