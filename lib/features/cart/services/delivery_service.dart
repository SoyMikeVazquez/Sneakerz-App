import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String id;
  final String placeName;
  final String text;
  final double lat;
  final double lng;

  PlaceSuggestion({
    required this.id,
    required this.placeName,
    required this.text,
    required this.lat,
    required this.lng,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final center = (json['center'] as List<dynamic>?) ?? [0.0, 0.0];
    final lng = center.isNotEmpty ? (center[0] as num).toDouble() : 0.0;
    final lat = center.length > 1 ? (center[1] as num).toDouble() : 0.0;

    return PlaceSuggestion(
      id: json['id']?.toString() ?? '',
      placeName: json['place_name']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      lat: lat,
      lng: lng,
    );
  }
}

class DeliveryCalculation {
  final double distanceKm;
  final double? shippingCost;
  final bool isOutOfCoverage;

  DeliveryCalculation({
    required this.distanceKm,
    required this.shippingCost,
    required this.isOutOfCoverage,
  });
}

class DeliveryService {
  /// Calcula el costo de envío basado en la tabla oficial:
  /// 0 a 3 km: $40 MXN (Tarifa base)
  /// 3 a 4 km: $50 MXN
  /// 4 a 5 km: $60 MXN
  /// 5 a 6 km: $70 MXN
  /// 6 a 7 km: $80 MXN
  /// 7 a 8 km: $90 MXN
  /// 8 a 9 km: $100 MXN
  /// 9 a 10 km: $110 MXN
  /// 10 a 11 km: $120 MXN
  /// 11 a 12 km: $130 MXN
  /// > 12 km: Fuera de cobertura (null)
  static double? calculateShippingCost(double distanceKm) {
    if (distanceKm < 0) return null;
    if (distanceKm > 12.0) return null; // Fuera de cobertura

    if (distanceKm <= 3.0) {
      return 40.0; // Tarifa base
    }

    // Cada km extra después de 3 km añade $10 MXN
    final extraKm = distanceKm.ceil() - 3;
    return 40.0 + (extraKm * 10.0);
  }

  /// Búsqueda de lugares / autocompletado en Mapbox
  static Future<List<PlaceSuggestion>> searchAddress({
    required String query,
    required String token,
  }) async {
    if (query.trim().length < 3 || token.isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$token&autocomplete=true&language=es&limit=5',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = (data['features'] as List<dynamic>?) ?? [];
        return features
            .map((f) => PlaceSuggestion.fromJson(f as Map<String, dynamic>))
            .where((p) => p.lat != 0.0 && p.lng != 0.0)
            .toList();
      }
    } catch (e) {
      debugPrint('Error en autocompletado de Mapbox: $e');
    }
    return [];
  }

  /// Calcula la distancia real de ruta en automóvil utilizando Mapbox Directions API.
  /// En caso de fallo de conexión, calcula la distancia mediante la fórmula de Haversine con factor de corrección.
  static Future<double> getDrivingDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String token,
  }) async {
    if (token.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?access_token=$token&overview=simplified',
        );

        final response = await http.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final distanceMeters = (routes[0]['distance'] as num).toDouble();
            return distanceMeters / 1000.0;
          }
        }
      } catch (e) {
        debugPrint('Error en Mapbox Directions API, usando fallback Haversine: $e');
      }
    }

    // Respaldo Haversine x 1.25 (factor de ruta aproximado)
    final straightLine = calculateHaversineDistanceKm(startLat, startLng, endLat, endLng);
    return straightLine * 1.25;
  }

  /// Distancia en línea recta (Haversine)
  static double calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * (math.pi / 180.0)) *
            math.cos(lat2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Procesa la cotización completa entre sucursal y destino
  static Future<DeliveryCalculation> calculateDelivery({
    required double branchLat,
    required double branchLng,
    required double destLat,
    required double destLng,
    required String token,
  }) async {
    final distanceKm = await getDrivingDistanceKm(
      startLat: branchLat,
      startLng: branchLng,
      endLat: destLat,
      endLng: destLng,
      token: token,
    );

    final cost = calculateShippingCost(distanceKm);
    return DeliveryCalculation(
      distanceKm: distanceKm,
      shippingCost: cost,
      isOutOfCoverage: cost == null,
    );
  }
}
