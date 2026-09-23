import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sneakerz_app/features/home/screens/main_screen.dart';
import 'package:sneakerz_app/features/booking/screens/booking_screen.dart';
import 'package:sneakerz_app/features/booking/screens/confirmation_screen.dart';
import 'package:sneakerz_app/features/auth/screens/login_screen.dart';
import 'package:sneakerz_app/features/auth/screens/register_screen.dart';
import 'package:sneakerz_app/features/admin/screens/admin_dashboard_screen.dart';
import 'package:sneakerz_app/features/cart/screens/cart_screen.dart';
import 'package:sneakerz_app/features/cart/screens/checkout_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Acceso público por defecto.
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const MainScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/confirmation',
        builder: (context, state) => const ConfirmationScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
    ],
  );
});
