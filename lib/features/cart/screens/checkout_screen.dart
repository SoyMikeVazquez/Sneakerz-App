import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:sneakerz_app/features/cart/providers/cart_provider.dart';
import 'package:sneakerz_app/features/auth/providers/auth_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos de contacto
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Datos de tarjeta (simulada)
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Prellenar si hay sesión de usuario o cliente
    final customerPhone = ref.read(customerSessionProvider);
    if (customerPhone != null && customerPhone.isNotEmpty) {
      _phoneController.text = customerPhone;
    }
    final user = ref.read(currentUserProvider);
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final orderId = await ref.read(cartProvider.notifier).checkout(
            customerName: _nameController.text.trim(),
            customerPhone: _phoneController.text.trim(),
            customerEmail: _emailController.text.trim(),
            paymentMethod: 'Tarjeta (Simulación Demo)',
          );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (orderId != null) {
        _showSuccessDialog(orderId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El carrito está vacío'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el pedido: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time_filled, color: Colors.orange, size: 48),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'ESTADO: PEDIDO PENDIENTE',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¡Pedido Recibido!',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Orden #${orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Tu pedido ha quedado en estado pendiente y será preparado a la brevedad por el equipo de Sneakerz.\n\nEnviamos el pedido pendiente a revisar a:\n${_emailController.text.trim()}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Cierra dialog
                  context.go('/'); // Vuelve a inicio
                },
                child: const Text('Entendido / Volver a la Tienda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Datos de Pago y Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TARJETA VISUAL DE CRÉDITO / DÉBITO
                _buildVisualCard(),

                const SizedBox(height: 24),

                // 2. DATOS DE CONTACTO
                _buildSectionHeader(
                  icon: Icons.person_outline,
                  title: '1. Datos de Contacto',
                  subtitle: 'Para identificarte y notificarte el estado de tu pedido',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (10 dígitos) *',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        hintText: '8112345678',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'El teléfono es obligatorio';
                        if (val.trim().length < 10) return 'Ingresa un teléfono válido de 10 dígitos';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo *',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20),
                        hintText: 'Ej. Juan Pérez',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'El nombre es obligatorio';
                        if (val.trim().length < 3) return 'Ingresa tu nombre completo';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico *',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                        hintText: 'ejemplo@correo.com',
                        helperText: 'Aquí te llegará la confirmación con Resend',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'El correo es obligatorio';
                        if (!val.contains('@') || !val.contains('.')) return 'Ingresa un correo electrónico válido';
                        return null;
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. DATOS DE TARJETA (SIMULACIÓN)
                _buildSectionHeader(
                  icon: Icons.credit_card_outlined,
                  title: '2. Datos de Pago (Simulación)',
                  subtitle: 'Modo de prueba seguro, no se realizará ningún cargo real',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                        _CardNumberFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Número de Tarjeta (Demo)',
                        prefixIcon: Icon(Icons.credit_card, size: 20),
                        hintText: '4000 1234 5678 9010',
                      ),
                      validator: (val) => null, // Demo: no bloquea el pedido
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cardExpiryController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                              _CardExpiryFormatter(),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Expiración',
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                              hintText: 'MM/AA',
                            ),
                            validator: (val) => null, // Demo
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _cardCvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              prefixIcon: Icon(Icons.lock_outline, size: 18),
                              hintText: '123',
                            ),
                            validator: (val) => null, // Demo
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cardHolderController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Nombre en la Tarjeta',
                        prefixIcon: Icon(Icons.account_box_outlined, size: 20),
                        hintText: 'COMO APARECE EN LA TARJETA',
                      ),
                      validator: (val) => null, // Demo
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '🔒 Simulación activa: Los datos de tarjeta son solo una prueba y no se almacenan.',
                              style: TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 4. RESUMEN DEL PEDIDO
                _buildSectionHeader(
                  icon: Icons.receipt_long_outlined,
                  title: '3. Resumen de la Orden',
                  subtitle: '${cartState.items.length} productos/servicios seleccionados',
                ),
                const SizedBox(height: 12),
                _buildCardContainer(
                  children: [
                    // Detalles de entrega si aplica
                    if (cartState.isDelivery) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.motorcycle, size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Envío a Domicilio (${cartState.deliveryDistanceKm?.toStringAsFixed(1)} km)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    cartState.deliveryAddress ?? '',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+\$${cartState.shippingCost.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

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
                          const Text('Costo de Envío', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          Text('+\$${cartState.shippingCost.toStringAsFixed(2)} MXN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total a Pagar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '\$${total.toStringAsFixed(2)} MXN',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // BOTÓN DE PAGO
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                      elevation: 0,
                    ),
                    onPressed: _isProcessing ? null : _processPayment,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            'Pagar y Confirmar Pedido (\$${total.toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisualCard() {
    final rawNumber = _cardNumberController.text.trim();
    final cardNumber = rawNumber.isNotEmpty ? rawNumber : '•••• •••• •••• ••••';
    final expiry = _cardExpiryController.text.isNotEmpty ? _cardExpiryController.text : 'MM/AA';
    final holder = _cardHolderController.text.isNotEmpty
        ? _cardHolderController.text.toUpperCase()
        : (_nameController.text.isNotEmpty ? _nameController.text.toUpperCase() : 'NOMBRE DEL TITULAR');

    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E24), Color(0xFF2B2D42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chip Dorado
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5C07B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const Text(
                'SNEAKERZ PAY',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13),
              ),
            ],
          ),
          Text(
            cardNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
              fontFamily: 'monospace',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TITULAR', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      holder,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('VENCE', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(expiry, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// Formateadores de texto para la tarjeta
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) text = text.substring(0, 16);

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }

    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
