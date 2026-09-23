import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> updateOrderStatus(String orderId, String newStatus, WidgetRef ref) async {
    state = const AsyncLoading();
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      
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
