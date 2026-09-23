import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sneakerz_app/models/cart_item_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sneakerz_app/features/auth/providers/auth_provider.dart';
import 'package:sneakerz_app/core/services/email_service.dart';

class Coupon {
  final String id;
  final String code;
  final String type; // 'percentage' or 'fixed'
  final double value;

  Coupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'],
      code: json['code'],
      type: json['discount_type'],
      value: (json['discount_value'] as num).toDouble(),
    );
  }
}

class CartState {
  final List<CartItem> items;
  final Coupon? appliedCoupon;

  // Entrega a domicilio
  final bool isDelivery;
  final Map<String, dynamic>? selectedBranch;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? deliveryDistanceKm;
  final double shippingCost;
  final bool isOutOfCoverage;
  final bool isCalculatingDelivery;

  CartState({
    this.items = const [],
    this.appliedCoupon,
    this.isDelivery = false,
    this.selectedBranch,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryDistanceKm,
    this.shippingCost = 0.0,
    this.isOutOfCoverage = false,
    this.isCalculatingDelivery = false,
  });

  CartState copyWith({
    List<CartItem>? items,
    Coupon? appliedCoupon,
    bool clearCoupon = false,
    bool? isDelivery,
    Map<String, dynamic>? selectedBranch,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
    double? deliveryDistanceKm,
    double? shippingCost,
    bool? isOutOfCoverage,
    bool? isCalculatingDelivery,
    bool clearDeliveryData = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      isDelivery: isDelivery ?? this.isDelivery,
      selectedBranch: clearDeliveryData ? null : (selectedBranch ?? this.selectedBranch),
      deliveryAddress: clearDeliveryData ? null : (deliveryAddress ?? this.deliveryAddress),
      deliveryLat: clearDeliveryData ? null : (deliveryLat ?? this.deliveryLat),
      deliveryLng: clearDeliveryData ? null : (deliveryLng ?? this.deliveryLng),
      deliveryDistanceKm: clearDeliveryData ? null : (deliveryDistanceKm ?? this.deliveryDistanceKm),
      shippingCost: clearDeliveryData ? 0.0 : (shippingCost ?? this.shippingCost),
      isOutOfCoverage: clearDeliveryData ? false : (isOutOfCoverage ?? this.isOutOfCoverage),
      isCalculatingDelivery: clearDeliveryData ? false : (isCalculatingDelivery ?? this.isCalculatingDelivery),
    );
  }

  double get subtotal {
    return items.fold(0, (previousValue, element) => previousValue + (element.price * element.quantity));
  }

  double get discount {
    if (appliedCoupon == null) return 0;
    if (appliedCoupon!.type == 'percentage') {
      return subtotal * (appliedCoupon!.value / 100);
    } else {
      return appliedCoupon!.value > subtotal ? subtotal : appliedCoupon!.value;
    }
  }

  double get total {
    final base = (subtotal - discount).clamp(0.0, double.infinity);
    return isDelivery ? base + shippingCost : base;
  }

  int get itemCount {
    return items.fold(0, (previousValue, element) => previousValue + element.quantity);
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final Ref ref;
  CartNotifier(this.ref) : super(CartState());

  void addItem(CartItem item) {
    final index = state.items.indexWhere((element) => element.id == item.id);
    if (index >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(quantity: newItems[index].quantity + item.quantity);
      state = state.copyWith(items: newItems);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void removeItem(String id) {
    state = state.copyWith(items: state.items.where((item) => item.id != id).toList());
  }

  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeItem(id);
      return;
    }
    
    final index = state.items.indexWhere((element) => element.id == id);
    if (index >= 0) {
      final newItems = List<CartItem>.from(state.items);
      newItems[index] = newItems[index].copyWith(quantity: quantity);
      state = state.copyWith(items: newItems);
    }
  }

  void clearCart() {
    state = CartState();
  }

  // --- MÉTODOS DE ENVÍO Y MAPBOX ---

  void toggleDelivery(bool enabled) {
    state = state.copyWith(
      isDelivery: enabled,
      shippingCost: enabled ? state.shippingCost : 0.0,
    );
  }

  void setSelectedBranch(Map<String, dynamic>? branch) {
    state = state.copyWith(selectedBranch: branch);
  }

  void setCalculatingDelivery(bool isCalculating) {
    state = state.copyWith(isCalculatingDelivery: isCalculating);
  }

  void setDeliveryInfo({
    required String address,
    required double lat,
    required double lng,
    required double? distanceKm,
    required double? cost,
    required bool isOutOfCoverage,
  }) {
    state = state.copyWith(
      deliveryAddress: address,
      deliveryLat: lat,
      deliveryLng: lng,
      deliveryDistanceKm: distanceKm,
      shippingCost: cost ?? 0.0,
      isOutOfCoverage: isOutOfCoverage,
      isCalculatingDelivery: false,
    );
  }

  void clearDelivery() {
    state = state.copyWith(
      isDelivery: false,
      clearDeliveryData: true,
    );
  }

  // --- CUPONES ---

  Future<String?> applyCoupon(String code) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('coupons')
          .select()
          .eq('code', code)
          .eq('active', true)
          .maybeSingle();

      if (response == null) {
        return 'Cupón inválido o expirado';
      }

      // Check valid_until and usage_limit
      if (response['valid_until'] != null) {
        final validUntil = DateTime.parse(response['valid_until']);
        if (DateTime.now().isAfter(validUntil)) {
          return 'Este cupón ha expirado';
        }
      }

      if (response['usage_limit'] != null && response['used_count'] >= response['usage_limit']) {
        return 'El cupón ha alcanzado su límite de uso';
      }

      final coupon = Coupon.fromJson(response);
      state = state.copyWith(appliedCoupon: coupon);
      return null; // Success
    } catch (e) {
      return 'Error al validar cupón: $e';
    }
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  // --- CHECKOUT ---

  Future<String?> checkout({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    String paymentMethod = 'Tarjeta (Simulación)',
  }) async {
    if (state.items.isEmpty) return null;

    try {
      final supabase = Supabase.instance.client;
      final user = ref.read(currentUserProvider);
      
      // Guardar snapshot de datos para notificaciones antes de limpiar el carrito
      final itemsSnapshot = List<CartItem>.from(state.items);
      final subtotalSnapshot = state.subtotal;
      final discountSnapshot = state.discount;
      final totalSnapshot = state.total;
      final isDeliverySnapshot = state.isDelivery;
      final addressSnapshot = state.deliveryAddress;
      final branchNameSnapshot = state.selectedBranch?['nombre_sucursal'] ?? state.selectedBranch?['nombre'];
      final shippingCostSnapshot = state.shippingCost;

      Map<String, dynamic>? orderResponse;

      // 1. Armar datos de la orden
      final orderData = <String, dynamic>{
        'total': state.total,
        'status': 'pending',
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_email': customerEmail,
        'payment_method': paymentMethod,
      };

      if (user != null) {
        orderData['user_id'] = user.id;
      }

      if (state.isDelivery) {
        orderData['is_delivery'] = true;
        orderData['branch_name'] = branchNameSnapshot ?? '';
        orderData['delivery_address'] = addressSnapshot ?? '';
        orderData['delivery_lat'] = state.deliveryLat;
        orderData['delivery_lng'] = state.deliveryLng;
        orderData['delivery_distance_km'] = state.deliveryDistanceKm;
        orderData['shipping_cost'] = state.shippingCost;
      }

      try {
        orderResponse = await supabase.from('orders').insert(orderData).select().single();
      } catch (colErr) {
        debugPrint('[Checkout] Error con campos extendidos, intentando fallback básico: $colErr');
        // Fallback seguro si faltan columnas nuevas en la base de datos
        final fallbackData = <String, dynamic>{
          'total': state.total,
          'status': 'pending',
        };
        if (user != null) {
          fallbackData['user_id'] = user.id;
        }
        orderResponse = await supabase.from('orders').insert(fallbackData).select().single();
      }
      
      final orderId = orderResponse['id']?.toString() ?? '';

      // 2. Crear los items de la orden
      final orderItemsData = itemsSnapshot.map((item) => {
        'order_id': orderId,
        'item_id': item.id,
        'item_type': item.type,
        'quantity': item.quantity,
        'price': item.price,
      }).toList();

      await supabase.from('order_items').insert(orderItemsData);

      // 3. Registrar uso del cupón si aplica
      if (state.appliedCoupon != null) {
        try {
          await supabase.rpc('increment_coupon_usage', params: {'coupon_id': state.appliedCoupon!.id});
        } catch (_) {}
      }

      // 4. Registrar o vincular cliente en tabla clientes
      if (customerPhone.isNotEmpty) {
        try {
          await supabase.from('clientes').upsert({
            'telefono': int.tryParse(customerPhone) ?? customerPhone,
            'nombre': customerName,
            if (customerEmail.isNotEmpty) 'correo': customerEmail,
          }, onConflict: 'telefono');
        } catch (_) {}
      }

      // 5. Enviar notificación por correo con Resend al correo proporcionado
      final recipientEmail = customerEmail.isNotEmpty ? customerEmail : (user?.email ?? '');
      if (recipientEmail.isNotEmpty) {
        EmailService.sendOrderNotification(
          orderId: orderId,
          userEmail: recipientEmail,
          items: itemsSnapshot,
          subtotal: subtotalSnapshot,
          discount: discountSnapshot,
          total: totalSnapshot,
          isDelivery: isDeliverySnapshot,
          deliveryAddress: addressSnapshot,
          branchName: branchNameSnapshot,
          shippingCost: shippingCostSnapshot,
        ).ignore();
      }

      // 6. Limpiar carrito
      clearCart();
      return orderId;
    } catch (e) {
      debugPrint('Error en checkout: $e');
      rethrow;
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});

final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});

final cartDiscountProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).discount;
});

final cartShippingCostProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).shippingCost;
});

final cartIsDeliveryProvider = Provider<bool>((ref) {
  return ref.watch(cartProvider).isDelivery;
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).total;
});

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});
