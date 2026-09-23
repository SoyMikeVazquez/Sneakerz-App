import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:sneakerz_app/features/cart/providers/cart_provider.dart';
import 'package:sneakerz_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:sneakerz_app/features/cart/services/delivery_service.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _couponController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isApplyingCoupon = false;

  // Mapbox & Envíos
  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  bool _isSearchingAddress = false;
  bool _isCalculatingDelivery = false;

  @override
  void dispose() {
    _couponController.dispose();
    _addressController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    return double.tryParse(str);
  }

  void _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isApplyingCoupon = true);
    final error = await ref.read(cartProvider.notifier).applyCoupon(code);
    setState(() => _isApplyingCoupon = false);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      _couponController.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cupón aplicado con éxito'), backgroundColor: Colors.green),
      );
    }
  }

  void _onAddressChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearchingAddress = true);
      final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
      final results = await DeliveryService.searchAddress(query: query, token: token);

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearchingAddress = false;
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion, Map<String, dynamic>? selectedBranch) async {
    _addressController.text = suggestion.placeName;
    setState(() {
      _suggestions = [];
      _isSearchingAddress = false;
    });
    FocusScope.of(context).unfocus();

    if (selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una sucursal de origen primero')),
      );
      return;
    }

    final branchLat = _parseDouble(selectedBranch['lat'] ?? selectedBranch['latitud'] ?? selectedBranch['latitude']);
    final branchLng = _parseDouble(selectedBranch['long'] ?? selectedBranch['lng'] ?? selectedBranch['longitud'] ?? selectedBranch['longitude']);

    if (branchLat == null || branchLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La sucursal seleccionada no tiene coordenadas válidas')),
      );
      return;
    }

    setState(() => _isCalculatingDelivery = true);

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final calc = await DeliveryService.calculateDelivery(
      branchLat: branchLat,
      branchLng: branchLng,
      destLat: suggestion.lat,
      destLng: suggestion.lng,
      token: token,
    );

    if (mounted) {
      ref.read(cartProvider.notifier).setDeliveryInfo(
        address: suggestion.placeName,
        lat: suggestion.lat,
        lng: suggestion.lng,
        distanceKm: calc.distanceKm,
        cost: calc.shippingCost,
        isOutOfCoverage: calc.isOutOfCoverage,
      );
      setState(() => _isCalculatingDelivery = false);
    }
  }

  Future<void> _recalculateForBranch(Map<String, dynamic> branch) async {
    final cartState = ref.read(cartProvider);
    if (cartState.deliveryLat == null || cartState.deliveryLng == null) return;

    final branchLat = _parseDouble(branch['lat'] ?? branch['latitud'] ?? branch['latitude']);
    final branchLng = _parseDouble(branch['long'] ?? branch['lng'] ?? branch['longitud'] ?? branch['longitude']);
    if (branchLat == null || branchLng == null) return;

    setState(() => _isCalculatingDelivery = true);

    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final calc = await DeliveryService.calculateDelivery(
      branchLat: branchLat,
      branchLng: branchLng,
      destLat: cartState.deliveryLat!,
      destLng: cartState.deliveryLng!,
      token: token,
    );

    if (mounted) {
      ref.read(cartProvider.notifier).setDeliveryInfo(
        address: cartState.deliveryAddress ?? '',
        lat: cartState.deliveryLat!,
        lng: cartState.deliveryLng!,
        distanceKm: calc.distanceKm,
        cost: calc.shippingCost,
        isOutOfCoverage: calc.isOutOfCoverage,
      );
      setState(() => _isCalculatingDelivery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final cartItems = cartState.items;
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);
    final branchesAsync = ref.watch(adminBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu Carrito', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Vaciar carrito'),
                    content: const Text('¿Estás seguro de que quieres eliminar todos los items del carrito?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          Navigator.pop(context);
                        },
                        child: const Text('Vaciar', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'Tu carrito está vacío',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => context.pop(),
                    child: const Text('Explorar Productos'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.imageUrl.isNotEmpty
                                  ? Image.network(
                                      item.imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: AppColors.border.withValues(alpha: 0.2),
                                      child: const Icon(Icons.image_not_supported),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${item.price.toStringAsFixed(2)} MXN',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _buildQuantityButton(
                                  icon: Icons.remove,
                                  onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                _buildQuantityButton(
                                  icon: Icons.add,
                                  onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // PANEL INFERIOR CON COTIZACIÓN MAPBOX Y PAGO
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. CÓDIGO DE DESCUENTO
                          if (cartState.appliedCoupon == null)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'Código de descuento',
                                      hintStyle: const TextStyle(fontSize: 13),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.background,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  ),
                                  onPressed: _isApplyingCoupon ? null : _applyCoupon,
                                  child: _isApplyingCoupon
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Cupón ${cartState.appliedCoupon!.code} aplicado',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => ref.read(cartProvider.notifier).removeCoupon(),
                                    child: const Icon(Icons.close, color: Colors.green, size: 18),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 14),

                          // 2. SECCIÓN ENVÍO A DOMICILIO (MAPBOX)
                          _buildDeliverySection(context, cartState, branchesAsync),

                          const SizedBox(height: 16),

                          // 3. DESGLOSE DE TOTALES
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              Text('\$${subtotal.toStringAsFixed(2)} MXN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),

                          if (discount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Descuento', style: TextStyle(color: Colors.green, fontSize: 14)),
                                Text('-\$${discount.toStringAsFixed(2)} MXN', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ],

                          if (cartState.isDelivery) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.local_shipping_outlined, size: 15, color: AppColors.textSecondary),
                                    SizedBox(width: 4),
                                    Text('Costo de Envío', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                  ],
                                ),
                                if (cartState.isOutOfCoverage)
                                  const Text('Fuera de cobertura', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13))
                                else if (cartState.deliveryAddress == null || cartState.deliveryAddress!.isEmpty)
                                  const Text('Por cotizar', style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 13))
                                else
                                  Text(
                                    '+\$${cartState.shippingCost.toStringAsFixed(2)} MXN',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                                  ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 10),
                          const Divider(),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                              ),
                              Text(
                                '\$${total.toStringAsFixed(2)} MXN',
                                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.primary),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // BOTÓN REALIZAR ORDEN
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (cartState.isDelivery && cartState.isOutOfCoverage)
                                    ? Colors.grey[400]
                                    : AppColors.primary,
                                foregroundColor: AppColors.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                if (cartState.items.isEmpty) return;

                                if (cartState.isDelivery) {
                                  if (cartState.selectedBranch == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Por favor selecciona una sucursal')),
                                    );
                                    return;
                                  }
                                  if (cartState.deliveryAddress == null || cartState.deliveryAddress!.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Por favor busca y selecciona tu dirección de entrega en Mapbox')),
                                    );
                                    return;
                                  }
                                  if (cartState.isOutOfCoverage) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Dirección fuera de cobertura (máximo 12 km). Elige otra dirección o retira el envío.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // Abre pantalla de checkout para teléfono, nombre, correo y tarjeta simulada
                                context.push('/checkout');
                              },
                              child: Text(
                                (cartState.isDelivery && cartState.isOutOfCoverage)
                                    ? 'Fuera de Cobertura (Máx. 12 km)'
                                    : 'Realizar Orden',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDeliverySection(
    BuildContext context,
    CartState cartState,
    AsyncValue<List<Map<String, dynamic>>> branchesAsync,
  ) {
    final branches = branchesAsync.value ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cartState.isDelivery ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Switch Activar Envío
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.motorcycle, size: 20, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Añadir costo de envío',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: cartState.isDelivery,
                  activeThumbColor: AppColors.primary,
                  onChanged: (enabled) {
                    ref.read(cartProvider.notifier).toggleDelivery(enabled);
                    if (enabled && cartState.selectedBranch == null && branches.isNotEmpty) {
                      ref.read(cartProvider.notifier).setSelectedBranch(branches.first);
                    }
                  },
                ),
              ),
            ],
          ),

          // CONTENIDO EXPANDIBLE SI EL SWITCH ESTÁ ACTIVO
          if (cartState.isDelivery) ...[
            const Divider(height: 18),
            // SELECTOR DE SUCURSAL
            const Text(
              'Sucursal de despacho:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            branchesAsync.when(
              data: (branchList) {
                if (branchList.isEmpty) {
                  return const Text('No hay sucursales configuradas', style: TextStyle(fontSize: 12, color: Colors.grey));
                }

                final currentSelected = cartState.selectedBranch ?? branchList.first;
                if (cartState.selectedBranch == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(cartProvider.notifier).setSelectedBranch(currentSelected);
                  });
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: branchList.firstWhere(
                        (b) => (b['id'] ?? b['nombre']) == (currentSelected['id'] ?? currentSelected['nombre']),
                        orElse: () => branchList.first,
                      ),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      items: branchList.map((branch) {
                        final name = branch['nombre_sucursal'] ?? branch['nombre'] ?? branch['name'] ?? 'Sucursal';
                        final address = branch['direccion'] ?? branch['address'] ?? '';
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: branch,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (address.isNotEmpty)
                                Text(
                                  address,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newBranch) {
                        if (newBranch != null) {
                          ref.read(cartProvider.notifier).setSelectedBranch(newBranch);
                          _recalculateForBranch(newBranch);
                        }
                      },
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Error al cargar sucursales', style: TextStyle(fontSize: 12, color: Colors.red)),
            ),

            const SizedBox(height: 12),

            // TEXTFIELD DIRECCIÓN (MAPBOX)
            const Text(
              'Dirección de entrega (Mapbox):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _addressController,
              onChanged: _onAddressChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ingresa tu calle, número y colonia...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                suffixIcon: _isSearchingAddress
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : (_addressController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _addressController.clear();
                              setState(() => _suggestions = []);
                              ref.read(cartProvider.notifier).clearDelivery();
                              ref.read(cartProvider.notifier).toggleDelivery(true);
                            },
                          )
                        : null),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),

            // SUGERENCIAS DE AUTOCOMPLETADO
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final suggestion = _suggestions[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 16, color: AppColors.primary),
                      title: Text(suggestion.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        suggestion.placeName,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectSuggestion(suggestion, cartState.selectedBranch),
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            // BADGE DE DISTANCIA Y COTIZACIÓN
            if (_isCalculatingDelivery)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 10),
                    Text('Calculando ruta y distancia con Mapbox...', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else if (cartState.deliveryAddress != null && cartState.deliveryAddress!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cartState.isOutOfCoverage
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cartState.isOutOfCoverage ? Colors.red : Colors.green,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              cartState.isOutOfCoverage ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              color: cartState.isOutOfCoverage ? Colors.red : Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Distancia: ${cartState.deliveryDistanceKm?.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: cartState.isOutOfCoverage ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (!cartState.isOutOfCoverage)
                          Text(
                            '\$${cartState.shippingCost.toStringAsFixed(2)} MXN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cartState.isOutOfCoverage
                          ? '⚠️ Fuera de cobertura (el radio máximo de entrega es de 12.0 km).'
                          : 'Tarifa aplicada según distancia de entrega.',
                      style: TextStyle(
                        fontSize: 11,
                        color: cartState.isOutOfCoverage ? Colors.red[800] : Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
