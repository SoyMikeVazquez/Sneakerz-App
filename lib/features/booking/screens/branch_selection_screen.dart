import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sneakerz_app/core/widgets/streetwear_background.dart';
import 'package:sneakerz_app/features/booking/providers/services_provider.dart';
import 'package:sneakerz_app/features/booking/providers/products_provider.dart';
import 'package:sneakerz_app/features/booking/providers/promos_provider.dart';
import 'package:sneakerz_app/features/booking/widgets/ai_image_upload_section.dart';
import 'package:sneakerz_app/models/promo_model.dart';
import 'package:sneakerz_app/models/service_model.dart';
import 'package:sneakerz_app/models/product_model.dart';
import 'package:sneakerz_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:sneakerz_app/features/cart/providers/cart_provider.dart';
import 'package:sneakerz_app/models/cart_item_model.dart';

class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: StreetwearBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(promosProvider);
              ref.invalidate(servicesProvider);
              ref.invalidate(productsProvider);
            },
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(context, ref),
                    const SizedBox(height: 32),
                    
                    _buildSectionTitle(context, 'Promociones Especiales'),
                    const SizedBox(height: 16),
                    _buildPromosList(ref, context),
                    const SizedBox(height: 32),

                    _buildSectionTitle(context, 'Nuestros Servicios'),
                    const SizedBox(height: 16),
                    _buildServicesList(ref, context),
                  const SizedBox(height: 24),
                  
                  _buildOrderStatusButton(context),
                  const SizedBox(height: 24),

                  const AIImageUploadSection(),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, 'Productos'),
                  const SizedBox(height: 16),
                  _buildProductsList(ref, context),
                  const SizedBox(height: 32),

                  _buildSectionTitle(context, 'Selecciona una sucursal'),
                  const SizedBox(height: 8),
                  Text(
                    '¿Dónde quieres dejar tus sneakers hoy?',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildBranchesList(ref, context),
                  const SizedBox(height: 36),
                  _buildFranchiseSection(context),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final cartItemCount = ref.watch(cartItemCountProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido a',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            Image.asset(
              'assets/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) => Text(
                'SNEAKERZ.',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, size: 28),
              onPressed: () => context.push('/cart'),
              color: AppColors.primary,
            ),
            if (cartItemCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    cartItemCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }

  Widget _buildPromosList(WidgetRef ref, BuildContext context) {
    final promosAsync = ref.watch(promosProvider);

    return SizedBox(
      height: 160,
      child: promosAsync.when(
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: Text(
                'No hay promociones activas',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final promo = promos[index];
              return _buildPromoCard(
                imageUrl: promo.imageUrl,
                title: promo.title,
                onTap: () => _showPromoDetailBottomSheet(context, promo),
              ).animate().fade(duration: 600.ms, delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) => Container(
            width: 280,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'Error al cargar promociones',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCard({
    required String imageUrl,
    required String title,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(40),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    color: AppColors.textSecondary.withOpacity(0.2),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.image_not_supported, color: AppColors.border, size: 40),
                    ),
                  ),
                );
              },
            ),
            Container(
              color: Colors.black.withOpacity(0.4),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildServicesList(WidgetRef ref, BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    return SizedBox(
      height: 140,
      child: servicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: Text(
                'No hay servicios disponibles',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final service = services[index];
              return _buildSquareCard(
                imageUrl: service.imageUrl ?? '',
                title: service.name,
                price: service.price > 0 ? '\$${service.price.toStringAsFixed(0)}' : null,
                onTap: () => _showServiceDetailBottomSheet(context, ref, service),
              ).animate().fade(duration: 600.ms, delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) => Container(
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'Error al cargar servicios',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList(WidgetRef ref, BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return SizedBox(
      height: 140,
      child: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Text(
                'No hay productos disponibles',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildSquareCard(
                imageUrl: product.imageUrl ?? '',
                title: product.name,
                price: product.price > 0 ? '\$${product.price.toStringAsFixed(0)}' : null,
                onTap: () => _showProductDetailBottomSheet(context, ref, product),
              ).animate().fade(duration: 600.ms, delay: (index * 100).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) => Container(
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
        ),
        error: (error, _) => Center(
          child: Text(
            'Error al cargar productos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquareCard({
    required String imageUrl,
    required String title,
    String? price,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.all(24),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.contain,
                      color: AppColors.textSecondary.withOpacity(0.2),
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.image_not_supported, color: AppColors.border, size: 24),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.all(24),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  color: AppColors.textSecondary.withOpacity(0.2),
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.image_not_supported, color: AppColors.border, size: 24),
                  ),
                ),
              ),
            Container(
              color: Colors.black.withOpacity(0.35),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      price,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBranchesList(WidgetRef ref, BuildContext context) {
    final branchesAsync = ref.watch(adminBranchesProvider);

    return branchesAsync.when(
      data: (branches) {
        if (branches.isEmpty) {
          return Center(
            child: Text(
              'No hay sucursales disponibles',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: branches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final branch = branches[index];
            final nombre = branch['nombre_sucursal'] ?? branch['nombre'] ?? branch['name'] ?? 'Sucursal';
            final direccion = branch['direccion'] ?? branch['address'] ?? branch['ubicacion'] ?? 'Ubicación no especificada';
            final horario = branch['horario'] ?? branch['schedule'];
            final isOpen = branch['is_open'] == true || branch['is_active'] == true || branch['activo'] == true;

            return _buildBranchCard(
              context,
              name: nombre,
              address: direccion,
              distance: horario != null && horario.toString().isNotEmpty ? horario.toString() : 'Sucursal activa',
              isOpen: isOpen,
            ).animate().fade(duration: 600.ms, delay: (index * 100).ms).slideY(begin: 0.2, end: 0);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBranchCard(
    BuildContext context, {
    required String name,
    required String address,
    required String distance,
    required bool isOpen,
  }) {
    return GestureDetector(
      onTap: () => context.push('/booking'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30), // Pill shape for branch cards
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen ? AppColors.primary : AppColors.error,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isOpen ? AppColors.primary : AppColors.error,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOpen ? 'ABIERTO' : 'CERRADO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.navigation_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      distance,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatusButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        onPressed: () => context.push('/login'),
        child: const Text(
          'Consulta el servicio de tus productos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ).animate().fade(duration: 600.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }

  // MODAL BOTTOM SHEET: PROMOCIONES
  void _showPromoDetailBottomSheet(BuildContext context, PromoItem promo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (promo.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  promo.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.border.withOpacity(0.2),
                    child: const Icon(Icons.local_offer_outlined, size: 48, color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⚡ PROMOCIÓN EXCLUSIVA',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              promo.title.replaceAll('\n', ' '),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              promo.description != null && promo.description!.isNotEmpty
                  ? promo.description!
                  : 'Aprovecha este descuento especial por tiempo limitado en cualquiera de nuestras sucursales.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/booking');
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: const Text(
                  'Aprovechar Promoción (Agendar)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // MODAL BOTTOM SHEET: SERVICIOS
  void _showServiceDetailBottomSheet(BuildContext context, WidgetRef ref, ServiceItem service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (service.imageUrl != null && service.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  service.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.border.withOpacity(0.2),
                    child: const Icon(Icons.cleaning_services_outlined, size: 48, color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'SERVICIO SNEAKERZ',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                if (service.price > 0)
                  Text(
                    '\$${service.price.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              service.description != null && service.description!.isNotEmpty
                  ? service.description!
                  : 'Servicio premium de limpieza y restauración para devolver a tus sneakers su esplendor original.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () {
                  ref.read(cartProvider.notifier).addItem(
                    CartItem(
                      id: service.id,
                      name: service.name,
                      price: service.price,
                      quantity: 1,
                      imageUrl: service.imageUrl ?? '',
                      type: 'service',
                    )
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Servicio añadido al carrito')),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text(
                  'Añadir al carrito',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // MODAL BOTTOM SHEET: PRODUCTOS
  void _showProductDetailBottomSheet(BuildContext context, WidgetRef ref, ProductItem product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  product.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.border.withOpacity(0.2),
                    child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.category ?? 'CUIDADO SNEAKERZ',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                Text(
                  '\$${product.price.toStringAsFixed(2)} MXN',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              product.description != null && product.description!.isNotEmpty
                  ? product.description!
                  : 'Producto oficial de acompañamiento y protección especializado para el calzado.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () {
                  ref.read(cartProvider.notifier).addItem(
                    CartItem(
                      id: product.id,
                      name: product.name,
                      price: product.price,
                      quantity: 1,
                      imageUrl: product.imageUrl ?? '',
                      type: 'product',
                    )
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Producto añadido al carrito')),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text(
                  'Añadir al carrito',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFranchiseSection(BuildContext context) {
    const franchiseUrl = 'https://guiadefranquicias.com/franquicia/688847';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, size: 14, color: Colors.amber),
                    SizedBox(width: 5),
                    Text(
                      'FRANQUICIAS DISPONIBLES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: Colors.blueAccent),
                    SizedBox(width: 4),
                    Text(
                      'Oficial',
                      style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Quieres abrir tu propia sucursal Sneakerz? 🚀',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Súmate a la marca referente en cuidado, restauración y personalización de calzado urbano. Un modelo de negocio rentable, validado y con alta demanda en todo México.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFranchiseBadge('💼 Alta Rentabilidad'),
              _buildFranchiseBadge('👟 Mercado en Crecimiento'),
              _buildFranchiseBadge('🛠️ Capacitación Continua'),
              _buildFranchiseBadge('📍 Territorios Exclusivos'),
            ],
          ),
          const SizedBox(height: 22),
          // Botón principal al formulario oficial de Guía de Franquicias
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                final uri = Uri.parse(franchiseUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo abrir el enlace.')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18, color: Colors.black),
              label: const Text(
                'Llenar Formulario Oficial',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Botón secundario para ver más detalles en modal
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _showFranchiseInfoModal(context, franchiseUrl),
              icon: const Icon(Icons.info_outline, size: 17, color: Colors.white),
              label: const Text(
                'Conoce los Requisitos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'En convenio oficial con Guía de Franquicias México',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFranchiseBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showFranchiseInfoModal(BuildContext context, String franchiseUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 24, color: AppColors.primary),
                const SizedBox(width: 10),
                const Text(
                  'Franquicias Sneakerz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '¿Por qué invertir en una franquicia Sneakerz?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildModalBullet(
              '👟 Negocio Especializado',
              'El cuidado de calzado de colección y sneakers es una industria en pleno auge con clientes recurrentes y fieles.',
            ),
            _buildModalBullet(
              '📦 Modelo Llave en Mano',
              'Te entregamos el manual operativo, fórmulas profesionales, insumos y capacitación para ti y tu equipo.',
            ),
            _buildModalBullet(
              '📍 Territorios Exclusivos',
              'Protección geográfica de zona para asegurar el éxito y exclusividad de tu sucursal.',
            ),
            _buildModalBullet(
              '📝 Contacto Directo',
              'Envía tu información mediante el formulario oficial de Guía de Franquicias para recibir la ficha técnica y costos de inversión.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(franchiseUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  'Ir al Formulario Oficial de Franquicias',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalBullet(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

