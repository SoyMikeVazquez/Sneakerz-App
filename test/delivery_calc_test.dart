import 'package:flutter_test/flutter_test.dart';
import 'package:sneakerz_app/features/cart/services/delivery_service.dart';

void main() {
  test('Validar tabla oficial de costos de envío según distancia', () {
    final testCases = <double, double?>{
      0.5: 40.0,
      1.2: 40.0,
      3.0: 40.0,
      3.1: 50.0,
      3.9: 50.0,
      4.0: 50.0,
      4.2: 60.0,
      5.0: 60.0,
      5.5: 70.0,
      6.0: 70.0,
      6.8: 80.0,
      7.0: 80.0,
      7.4: 90.0,
      8.0: 90.0,
      8.3: 100.0,
      9.0: 100.0,
      9.9: 110.0,
      10.0: 110.0,
      10.5: 120.0,
      11.0: 120.0,
      11.2: 130.0,
      12.0: 130.0,
      12.01: null, // Fuera de cobertura (>12 km)
      15.0: null,  // Fuera de cobertura
    };

    testCases.forEach((distance, expectedCost) {
      final actual = DeliveryService.calculateShippingCost(distance);
      expect(actual, expectedCost, reason: 'Falló para distancia $distance km');
    });
  });
}
