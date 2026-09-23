import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sneakerz_app/core/services/email_service.dart';

final adminOrdersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  
  // We want to fetch all orders along with their items and optionally the user email.
  // Since we might not have a direct join to auth.users that returns email (due to security),
  // we'll fetch the orders and items first.
  
  final response = await supabase
      .from('orders')
      .select('*, order_items(*)')
      .order('created_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});

// A provider for mutating orders (e.g. changing status)
class AdminOrdersNotifier extends StateNotifier<AsyncValue<void>> {
  AdminOrdersNotifier() : super(const AsyncData(null));

  Future<void> updateOrderStatus(
    String orderId,
    String newStatus,
    WidgetRef ref, {
    Map<String, dynamic>? orderData,
  }) async {
    state = const AsyncLoading();
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);

      // Si la orden se marca como completada, notificamos por correo al cliente
      if (newStatus == 'completado') {
        Map<String, dynamic>? data = orderData;
        if (data == null) {
          try {
            final res = await supabase
                .from('orders')
                .select('*, order_items(*)')
                .eq('id', orderId)
                .maybeSingle();
            if (res != null) data = res;
          } catch (_) {}
        }

        if (data != null) {
          final email = data['customer_email']?.toString() ?? '';
          if (email.isNotEmpty) {
            EmailService.sendOrderApprovedNotification(
              orderId: orderId,
              userEmail: email,
              customerName: data['customer_name']?.toString(),
              customerPhone: data['customer_phone']?.toString(),
              total: (data['total'] as num?)?.toDouble() ?? 0.0,
              isDelivery: data['is_delivery'] == true,
              deliveryAddress: data['delivery_address']?.toString(),
              branchName: data['branch_name']?.toString(),
              items: data['order_items'] as List<dynamic>?,
            ).ignore();
          }
        }
      }
      
      // Invalidate to refresh the list
      ref.invalidate(adminOrdersProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final adminOrdersNotifierProvider = StateNotifierProvider<AdminOrdersNotifier, AsyncValue<void>>((ref) {
  return AdminOrdersNotifier();
});
