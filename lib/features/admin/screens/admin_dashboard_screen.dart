import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sneakerz_app/core/widgets/streetwear_background.dart';
import 'package:sneakerz_app/features/auth/providers/auth_provider.dart';
import 'package:sneakerz_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:sneakerz_app/models/product_model.dart';
import 'package:sneakerz_app/models/service_model.dart';
import 'package:sneakerz_app/features/booking/providers/services_provider.dart';
import 'package:sneakerz_app/features/admin/screens/branch_form_screen.dart';
import 'package:sneakerz_app/features/admin/widgets/registro_bottom_sheet.dart';
import 'package:sneakerz_app/features/admin/widgets/finanzas_bottom_sheet.dart';
import 'package:sneakerz_app/features/admin/providers/admin_orders_provider.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool? _lastIsSuperAdmin;

  int _catalogSubIndex = 0; // 0: Productos, 1: Servicios

  void _initTabController(bool isSuperAdmin) {
    if (_tabController != null && _lastIsSuperAdmin == isSuperAdmin) return;
    _tabController?.dispose();
    _lastIsSuperAdmin = isSuperAdmin;
    _tabController = TabController(length: isSuperAdmin ? 6 : 5, vsync: this);
    _tabController!.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final branchesAsync = ref.watch(adminBranchesProvider);
    final selectedBranch = ref.watch(selectedBranchIdProvider);

    return userProfileAsync.when(
      data: (profile) {
        final isSuperAdmin = profile?.superAdmin ?? false;
        _initTabController(isSuperAdmin);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.surface.withOpacity(0.9),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
              onPressed: () => context.go('/'),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSuperAdmin ? Colors.amber.shade700 : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                onPressed: () {
                  ref.invalidate(adminFinanceProvider);
                  ref.invalidate(adminRegistrosProvider);
                  ref.invalidate(adminProductsNotifierProvider);
                  ref.invalidate(adminServicesNotifierProvider);
                  ref.invalidate(adminUsersNotifierProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.error),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
            bottom: _tabController == null
                ? null
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: isSuperAdmin ? Colors.amber : AppColors.primary,
                    labelColor: isSuperAdmin ? Colors.amber : AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      const Tab(icon: Icon(Icons.analytics_outlined), text: 'Finanzas'),
                      const Tab(icon: Icon(Icons.inventory_outlined), text: 'Registros'),
                      const Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Pedidos'),
                      const Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Catálogo'),
                      const Tab(icon: Icon(Icons.storefront_outlined), text: 'Sucursales'),
                      if (isSuperAdmin)
                        const Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Usuarios'),
                    ],
                  ),
          ),
          body: StreetwearBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // Scope Header
                  _buildScopeHeader(context, isSuperAdmin, branchesAsync, selectedBranch),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFinancesTab(context),
                        _buildRegistrosTab(context),
                        _buildPedidosTab(context),
                        _buildCatalogTab(context),
                        _buildBranchesTab(context, isSuperAdmin),
                        if (isSuperAdmin) _buildUsersTab(context, branchesAsync),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _tabController?.index == 0
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FinanzasBottomSheet(),
                  ),
                  icon: const Icon(Icons.attach_money),
                  label: const Text('Nuevo Movimiento', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : _tabController?.index == 1
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const RegistroBottomSheet(),
                  ),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Nuevo Registro', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : _tabController?.index == 2
              ? null
              : _tabController?.index == 3
              ? FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  onPressed: () {
                    if (_catalogSubIndex == 0) {
                      _showProductBottomSheet(context);
                    } else {
                      _showServiceBottomSheet(context);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: Text(
                    _catalogSubIndex == 0 ? 'Nuevo Producto' : 'Nuevo Servicio',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : (_tabController?.index == 4
                  ? FloatingActionButton.extended(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      onPressed: () => _showBranchBottomSheet(context),
                      icon: const Icon(Icons.add_business),
                      label: const Text('Nueva Sucursal', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : (_tabController?.index == 5 && isSuperAdmin
                      ? FloatingActionButton.extended(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
                          onPressed: () => _showCreateUserBottomSheet(context, branchesAsync),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Crear Usuario', style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      : null)),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildScopeHeader(
    BuildContext context,
    bool isSuperAdmin,
    AsyncValue<List<Map<String, dynamic>>> branchesAsync,
    String? selectedBranch,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isSuperAdmin ? Icons.domain : Icons.store,
                size: 20,
                color: isSuperAdmin ? Colors.amber : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isSuperAdmin ? 'Vista General (Franquicia)' : 'Vista de Sucursal',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          if (isSuperAdmin)
            branchesAsync.when(
              data: (branches) {
                return DropdownButton<String?>(
                  value: selectedBranch,
                  hint: const Text('Todas las Sucursales', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list, size: 18, color: AppColors.primary),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('🌐 Todas las Sucursales', style: TextStyle(fontSize: 12)),
                    ),
                    ...branches.map(
                      (b) => DropdownMenuItem<String?>(
                        value: b['id']?.toString(),
                        child: Text('📍 ${b['nombre'] ?? 'Sucursal'}', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    ref.read(selectedBranchIdProvider.notifier).state = val;
                  },
                );
              },
              loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox(),
            ),
        ],
      ),
    );
  }

  // TAB 1: FINANZAS
  Widget _buildFinancesTab(BuildContext context) {
    final financeAsync = ref.watch(adminFinanceProvider);

    return financeAsync.when(
      data: (finance) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Resumen Financiero',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDateRangePicker(context),
                ],
              ),
              const SizedBox(height: 16),

              // Tarjeta de Balance General (Dark Theme)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E1E), Color(0xFF000000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
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
                        const Text(
                          'Balance Neto',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: finance.balance >= 0 ? Colors.green.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            finance.balance >= 0 ? '+ Positivo' : '- En Alerta',
                            style: TextStyle(
                              color: finance.balance >= 0 ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '\$${finance.balance.toStringAsFixed(2)} MXN',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinanceMetricItem(
                            label: 'Ingresos Totales',
                            value: '\$${finance.totalIngresos.toStringAsFixed(2)}',
                            color: Colors.white,
                            icon: Icons.arrow_downward,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white),
                        Expanded(
                          child: _buildFinanceMetricItem(
                            label: 'Gastos Operativos',
                            value: '\$${finance.totalGastos.toStringAsFixed(2)}',
                            color: Colors.redAccent,
                            icon: Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),

              // Métricas de Rendimiento
              Text(
                'Métricas Operativas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Servicios Completados',
                      value: '${finance.serviciosCompletados}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Servicios en Proceso',
                      value: '${finance.serviciosPendientes}',
                      icon: Icons.timelapse,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Ticket Promedio',
                      value: '\$${finance.ticketPromedio.toStringAsFixed(2)}',
                      icon: Icons.receipt_long,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Transacciones',
                      value: '${finance.transacciones.length}',
                      icon: Icons.swap_horiz,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Últimos Movimientos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (finance.transacciones.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No hay movimientos registrados.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                ...finance.transacciones.take(20).map((t) {
                  final isGasto = t['isGasto'] == true || t['isgasto'] == true || t['tipo_ingreso']?.toString().toLowerCase() == 'gasto' || t['tipo']?.toString().toLowerCase() == 'gasto';
                  final montoVal = t['monto_cobrar'] ?? t['monto'] ?? t['total'] ?? t['precio'] ?? 0;
                  final monto = montoVal is num ? montoVal.toDouble() : double.tryParse(montoVal.toString()) ?? 0.0;
                  final titulo = t['nombre_registro'] ?? t['concepto'] ?? t['title'] ?? 'Movimiento';
                  final desc = t['descripcion'] ?? t['contacto'] ?? t['tipo_ingreso'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isGasto ? AppColors.error.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isGasto ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isGasto ? AppColors.error : Colors.green,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titulo,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isGasto ? '-' : '+'}\$${monto.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isGasto ? AppColors.error : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error al cargar finanzas: $e')),
    );
  }

  Widget _buildDateRangePicker(BuildContext context) {
    final dateRange = ref.watch(financeDateRangeProvider);
    final isToday = dateRange != null &&
        dateRange.start.day == DateTime.now().day &&
        dateRange.start.month == DateTime.now().month &&
        dateRange.start.year == DateTime.now().year &&
        dateRange.end.day == DateTime.now().day;

    String dateText = 'Hoy';
    if (!isToday && dateRange != null) {
      dateText = '${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year} - ${dateRange.end.day}/${dateRange.end.month}/${dateRange.end.year}';
    }

    return GestureDetector(
      onTap: () async {
        final newRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          initialDateRange: dateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.background,
                  onSurface: AppColors.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (newRange != null) {
          // Adjust end date to 23:59:59
          final end = DateTime(newRange.end.year, newRange.end.month, newRange.end.day, 23, 59, 59);
          ref.read(financeDateRangeProvider.notifier).state = DateTimeRange(start: newRange.start, end: end);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              dateText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isDarkTheme = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDarkTheme ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  // TAB 2: CITAS Y REGISTROS
  Widget _buildRegistrosTab(BuildContext context) {
    final registrosAsync = ref.watch(adminRegistrosProvider);

    return registrosAsync.when(
      data: (allRegistros) {
        final displayedList = allRegistros.where((item) => item['cita'] != true).toList();

        return Column(
          children: [


            // Lista
            Expanded(
              child: displayedList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_outlined,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay trabajos activos en taller.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: displayedList.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == displayedList.length) {
                          return const SizedBox(height: 100);
                        }

                        final item = displayedList[index];
                        final status = item['status']?.toString() ?? 'Dado de alta';
                        final id = item['id'];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1,
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
                                      Text(
                                        item['id']?.toString() ?? 'Folio',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '📍 ${item['sucursal'] ?? 'Sucursal Centro'}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item['modelo'] ?? item['marca_modelo'] ?? 'Sneakers',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Servicio: ${item['servicio'] ?? 'Limpieza General'}',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cliente: ${item['cliente_nombre'] ?? item['nombre_dueño'] ?? 'Cliente'} • Tel: ${item['telefono'] ?? item['telefono_dueño'] ?? 'N/A'}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              if (item['notas'] != null && item['notas'].toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.border.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Nota: ${item['notas']}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              // Acciones
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total: \$${(item['total'] ?? item['pagado_total'] ?? 0).toString()}',
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                  ),

                                    if (status == 'recibido' || status == 'servicio_iniciado')
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: const BorderSide(color: Colors.orange),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () => ref.read(adminRegistrosNotifierProvider.notifier).updateStatus(id, 'servicio_realizandose'),
                                        icon: const Icon(Icons.water_drop_outlined, size: 16),
                                        label: const Text('Iniciar Lavado', style: TextStyle(fontSize: 12)),
                                      )
                                    else if (status == 'en_lavado' || status == 'servicio_realizandose')
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.purple,
                                          side: const BorderSide(color: Colors.purple),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () => ref.read(adminRegistrosNotifierProvider.notifier).updateStatus(id, 'servicio_listo_para_entregar'),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: const Text('Marcar Listo', style: TextStyle(fontSize: 12)),
                                      )
                                    else if (status == 'listo_para_entrega' || status == 'listo' || status == 'servicio_listo_para_entregar')
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        onPressed: () => ref.read(adminRegistrosNotifierProvider.notifier).updateStatus(id, 'entregado'),
                                        icon: const Icon(Icons.done_all, size: 16),
                                        label: const Text('Entregar Par', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 1) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {

      case 'recibido':
      case 'servicio_iniciado':
        bg = Colors.blue.withOpacity(0.15);
        fg = Colors.blue;
        label = 'Iniciado';
        break;
      case 'en_lavado':
      case 'servicio_realizandose':
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange;
        label = 'Realizándose';
        break;
      case 'listo_para_entrega':
      case 'listo':
      case 'servicio_listo_para_entregar':
        bg = Colors.purple.withOpacity(0.15);
        fg = Colors.purple;
        label = 'Listo';
        break;
      case 'entregado':
        bg = Colors.green.withOpacity(0.15);
        fg = Colors.green;
        label = 'Entregado';
        break;
      default:
        bg = AppColors.border.withOpacity(0.2);
        fg = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  // TAB 3: CATÁLOGO (PRODUCTOS Y SERVICIOS)
  Widget _buildCatalogTab(BuildContext context) {
    return Column(
      children: [
        // Sub-filtro Productos / Servicios
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    label: '👟 Productos',
                    isSelected: _catalogSubIndex == 0,
                    color: AppColors.primary,
                    onTap: () => setState(() => _catalogSubIndex = 0),
                  ),
                ),
                Expanded(
                  child: _buildFilterChip(
                    label: '🧼 Servicios',
                    isSelected: _catalogSubIndex == 1,
                    color: AppColors.primary,
                    onTap: () => setState(() => _catalogSubIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista
        Expanded(
          child: _catalogSubIndex == 0 ? _buildProductsList(context) : _buildServicesList(context),
        ),
      ],
    );
  }

  Widget _buildProductsList(BuildContext context) {
    final productsState = ref.watch(adminProductsNotifierProvider);

    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 54, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No hay productos en inventario.'),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showProductBottomSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Primer Producto'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: products.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == products.length) {
              return const SizedBox(height: 100);
            }

            final product = products[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: AppColors.border.withOpacity(0.2),
                              child: const Icon(Icons.image, color: AppColors.textSecondary),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.border.withOpacity(0.2),
                            child: const Icon(Icons.inventory_2, color: AppColors.textSecondary),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${product.price.toStringAsFixed(2)} • ${product.category ?? 'General'}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                    onPressed: () => _showProductBottomSheet(context, product: product),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: '¿Eliminar producto?',
                        message: '¿Estás seguro de eliminar "${product.name}"?',
                      );

                      if (confirm == true) {
                        await ref.read(adminProductsNotifierProvider.notifier).deleteProduct(product.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildServicesList(BuildContext context) {
    final servicesState = ref.watch(adminServicesNotifierProvider);

    return servicesState.when(
      data: (services) {
        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cleaning_services_outlined, size: 54, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No hay servicios registrados.'),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showServiceBottomSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear Primer Servicio'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: services.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == services.length) {
              return const SizedBox(height: 100);
            }

            final service = services[index];

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: service.imageUrl != null && service.imageUrl!.isNotEmpty
                        ? Image.network(
                            service.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: AppColors.border.withOpacity(0.2),
                              child: const Icon(Icons.cleaning_services, color: AppColors.textSecondary),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: AppColors.border.withOpacity(0.2),
                            child: const Icon(Icons.cleaning_services, color: AppColors.textSecondary),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.price > 0 ? '\$${service.price.toStringAsFixed(2)}' : 'Servicio Especial',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                    onPressed: () => _showServiceBottomSheet(context, service: service),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: '¿Eliminar servicio?',
                        message: '¿Estás seguro de eliminar "${service.name}"?',
                      );

                      if (confirm == true) {
                        await ref.read(adminServicesNotifierProvider.notifier).deleteService(service.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // TAB 4: SUCURSALES
  Widget _buildBranchesTab(BuildContext context, bool isSuperAdmin) {
    final branchesAsync = ref.watch(adminBranchesProvider);

    return branchesAsync.when(
      data: (branches) {
        if (branches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_outlined, size: 54, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text('No hay sucursales registradas en Supabase.'),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showBranchBottomSheet(context),
                  icon: const Icon(Icons.add_business),
                  label: const Text('Crear Primer Sucursal'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: branches.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == branches.length) {
              return const SizedBox(height: 100);
            }

            final branch = branches[index];
            final id = branch['id'];
            final nombre = branch['nombre_sucursal'] ?? branch['nombre'] ?? branch['name'] ?? 'Sucursal';
            final direccion = branch['direccion'] ?? branch['address'] ?? branch['ubicacion'] ?? 'Ubicación no especificada';
            final telefono = branch['telefono'] ?? branch['phone'];
            final horario = branch['horario'] ?? branch['schedule'];
            final imagen = branch['imagen_sucursal'] ?? branch['imagen'] ?? branch['image'] ?? branch['foto'];
            final isOpen = branch['is_open'] == true || branch['is_active'] == true || branch['activo'] == true;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imagen != null && imagen.toString().isNotEmpty
                        ? Image.network(
                            imagen.toString(),
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 54,
                              height: 54,
                              color: AppColors.primary.withValues(alpha: 0.12),
                              child: const Icon(Icons.storefront, color: AppColors.primary, size: 24),
                            ),
                          )
                        : Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.storefront, color: AppColors.primary, size: 24),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nombre,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOpen ? 'Abierta' : 'Cerrada',
                                style: TextStyle(
                                  color: isOpen ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          direccion,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        if (telefono != null && telefono.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '📞 $telefono',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                        if (horario != null && horario.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '🕒 $horario',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                    onPressed: () => _showBranchBottomSheet(context, branch: branch),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: '¿Eliminar sucursal?',
                        message: '¿Estás seguro de eliminar "$nombre"?',
                      );

                      if (confirm == true && id != null) {
                        await ref.read(adminBranchesNotifierProvider.notifier).deleteBranch(id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // TAB 5: USUARIOS (SUPERADMIN)
  Widget _buildUsersTab(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> branchesAsync,
  ) {
    final usersState = ref.watch(adminUsersNotifierProvider);

    return usersState.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('No hay usuarios registrados en la tabla users.'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateUserBottomSheet(context, branchesAsync),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Registrar Primer Usuario'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == users.length) {
              return const SizedBox(height: 100);
            }

            final user = users[index];
            final nombre = user['nombre']?.toString() ?? 'Usuario';
            final correo = user['correo']?.toString() ?? 'Sin correo';
            final telefono = user['telefono']?.toString() ?? 'N/A';
            final sucursal = user['sucursal']?.toString() ?? 'Sin asignar';
            final isAdmin = user['is_admin'] == true;
            final isSuperAdmin = user['superAdmin'] == true;
            final id = user['id'];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSuperAdmin
                      ? Colors.amber.withOpacity(0.5)
                      : (isAdmin ? AppColors.primary.withOpacity(0.5) : AppColors.border),
                  width: (isSuperAdmin || isAdmin) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isSuperAdmin
                        ? Colors.amber.withOpacity(0.2)
                        : (isAdmin ? AppColors.primary.withOpacity(0.2) : AppColors.border.withOpacity(0.3)),
                    child: Icon(
                      isSuperAdmin ? Icons.shield : (isAdmin ? Icons.admin_panel_settings : Icons.person),
                      color: isSuperAdmin ? Colors.amber : (isAdmin ? AppColors.primary : AppColors.textSecondary),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                nombre,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildRoleBadge(isAdmin: isAdmin, isSuperAdmin: isSuperAdmin),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$correo • 📞 $telefono',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📍 $sucursal',
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: () async {
                      final confirm = await _showConfirmDialog(
                        context,
                        title: '¿Eliminar usuario?',
                        message: '¿Estás seguro de eliminar a $nombre?',
                      );

                      if (confirm == true) {
                        await ref.read(adminUsersNotifierProvider.notifier).deleteUser(id, correo: correo);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error al cargar usuarios: $e')),
    );
  }

  Widget _buildRoleBadge({required bool isAdmin, required bool isSuperAdmin}) {
    if (isSuperAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: const Text('SuperAdmin', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
      );
    }
    if (isAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: const Text('Admin', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppColors.border.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
      child: const Text('Staff', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  // DIALOGO DE CONFIRMACIÓN
  Future<bool?> _showConfirmDialog(BuildContext context, {required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // BOTTOM SHEET: CREAR / EDITAR PRODUCTO (ANCHO COMPLETO Y RESPONSIVO)
  void _showProductBottomSheet(BuildContext context, {ProductItem? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final priceCtrl = TextEditingController(text: product?.price != null && product!.price > 0 ? product.price.toString() : '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    String? uploadedImageUrl = product?.imageUrl;
    final catCtrl = TextEditingController(text: product?.category ?? 'Cuidado Rápido');
    bool isSaving = false;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndUploadImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (picked == null) return;
              setModalState(() => isUploadingImage = true);
              final bytes = await picked.readAsBytes();
              final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
              final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.$ext';
              final supabase = ref.read(supabaseClientProvider);
              await supabase.storage.from('general').uploadBinary(
                    fileName,
                    bytes,
                    fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
                  );
              final publicUrl = supabase.storage.from('general').getPublicUrl(fileName);
              setModalState(() {
                uploadedImageUrl = publicUrl;
                isUploadingImage = false;
              });
            } catch (e) {
              print('Error uploading image: $e');
              setModalState(() => isUploadingImage = false);
            }
          }

          return Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product == null ? '📦 Nuevo Producto' : '✏️ Editar Producto',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Producto',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Precio (\$ MXN)',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: catCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Image container
                  const Text('Imagen del Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isUploadingImage ? null : pickAndUploadImage,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: uploadedImageUrl != null ? AppColors.primary : Colors.black26),
                      ),
                      child: isUploadingImage
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        uploadedImageUrl!,
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey)),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () => setModalState(() => uploadedImageUrl = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppColors.primary),
                                    SizedBox(height: 6),
                                    Text('Toca para subir foto del producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Descripción detallada',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: isSaving || isUploadingImage
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                              if (name.isEmpty || price <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor completa el nombre y un precio válido')),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              String? errorMsg;
                              if (product == null) {
                                errorMsg = await ref.read(adminProductsNotifierProvider.notifier).createProduct(
                                      name: name,
                                      price: price,
                                      description: descCtrl.text.trim(),
                                      imageUrl: uploadedImageUrl ?? '',
                                      category: catCtrl.text.trim(),
                                    );
                              } else {
                                errorMsg = await ref.read(adminProductsNotifierProvider.notifier).updateProduct(
                                      id: product.id,
                                      name: name,
                                      price: price,
                                      description: descCtrl.text.trim(),
                                      imageUrl: uploadedImageUrl ?? '',
                                      category: catCtrl.text.trim(),
                                    );
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg == null ? '¡Producto guardado exitosamente!' : 'Error: $errorMsg'),
                                    backgroundColor: errorMsg == null ? Colors.green : AppColors.error,
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                          : Text(
                              product == null ? 'Crear Producto' : 'Guardar Cambios',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // BOTTOM SHEET: CREAR / EDITAR SERVICIO
  void _showServiceBottomSheet(BuildContext context, {ServiceItem? service}) {
    final nameCtrl = TextEditingController(text: service?.name ?? '');
    final priceCtrl = TextEditingController(text: service?.price != null && service!.price > 0 ? service.price.toString() : '');
    final descCtrl = TextEditingController(text: service?.description ?? '');
    String? uploadedImageUrl = service?.imageUrl;
    final typeCtrl = TextEditingController(text: service?.type ?? 'General');
    bool isSaving = false;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickAndUploadImage() async {
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (picked == null) return;
              setModalState(() => isUploadingImage = true);
              final bytes = await picked.readAsBytes();
              final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
              final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}.$ext';
              final supabase = ref.read(supabaseClientProvider);
              await supabase.storage.from('general').uploadBinary(
                    fileName,
                    bytes,
                    fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
                  );
              final publicUrl = supabase.storage.from('general').getPublicUrl(fileName);
              setModalState(() {
                uploadedImageUrl = publicUrl;
                isUploadingImage = false;
              });
            } catch (e) {
              setModalState(() => isUploadingImage = false);
            }
          }

          return Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        service == null ? '🧼 Nuevo Servicio' : '✏️ Editar Servicio',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Servicio',
                      prefixIcon: Icon(Icons.cleaning_services_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Precio (\$ MXN)',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: typeCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Tipo / Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Image container
                  const Text('Imagen del Servicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isUploadingImage ? null : pickAndUploadImage,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: uploadedImageUrl != null ? AppColors.primary : Colors.black26),
                      ),
                      child: isUploadingImage
                          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                          : (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        uploadedImageUrl!,
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey)),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () => setModalState(() => uploadedImageUrl = null),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppColors.primary),
                                    SizedBox(height: 6),
                                    Text('Toca para subir foto del servicio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                )),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Descripción del Servicio',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: isSaving || isUploadingImage
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor ingresa el nombre del servicio')),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              String? errorMsg;
                              if (service == null) {
                                errorMsg = await ref.read(adminServicesNotifierProvider.notifier).createService(
                                      name: name,
                                      price: price,
                                      description: descCtrl.text.trim(),
                                      imageUrl: uploadedImageUrl ?? '',
                                      type: typeCtrl.text.trim(),
                                    );
                              } else {
                                errorMsg = await ref.read(adminServicesNotifierProvider.notifier).updateService(
                                      id: service.id,
                                      name: name,
                                      price: price,
                                      description: descCtrl.text.trim(),
                                      imageUrl: uploadedImageUrl ?? '',
                                      type: typeCtrl.text.trim(),
                                    );
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg == null ? '¡Servicio guardado exitosamente!' : 'Error: $errorMsg'),
                                    backgroundColor: errorMsg == null ? Colors.green : AppColors.error,
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                          : Text(
                              service == null ? 'Crear Servicio' : 'Guardar Cambios',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // BOTTOM SHEET: CREAR USUARIO (EXCLUSIVO SUPERADMIN)
  void _showCreateUserBottomSheet(
    BuildContext context,
    AsyncValue<List<Map<String, dynamic>>> branchesAsync,
  ) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String selectedBranch = 'Sucursal Centro';
    bool isAdmin = false;
    bool isSuperAdmin = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.person_add, color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text('Registrar Usuario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Contraseña de Acceso', prefixIcon: Icon(Icons.lock_outline)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
                  ),
                  const SizedBox(height: 16),

                  // Selector de Sucursal
                  branchesAsync.when(
                    data: (branches) {
                      final branchList = branches.map((b) => b['nombre']?.toString() ?? 'Sucursal').toList();
                      if (branchList.isEmpty) branchList.add('Sucursal Centro');
                      if (!branchList.contains(selectedBranch)) selectedBranch = branchList.first;

                      return DropdownButtonFormField<String>(
                        value: selectedBranch,
                        decoration: const InputDecoration(labelText: 'Sucursal Asignada', prefixIcon: Icon(Icons.storefront_outlined)),
                        items: branchList.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedBranch = val);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(color: AppColors.primary),
                    error: (_, __) => TextField(
                      decoration: const InputDecoration(labelText: 'Sucursal'),
                      onChanged: (val) => selectedBranch = val,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text('¿Es Administrador de Sucursal?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Permite ver finanzas y citas de su sucursal', style: TextStyle(fontSize: 11)),
                      value: isAdmin,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => isAdmin = val),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      title: const Text('¿Es SuperAdmin (Franquicia)?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber)),
                      subtitle: const Text('Acceso total a todas las sucursales y creador de usuarios', style: TextStyle(fontSize: 11)),
                      value: isSuperAdmin,
                      activeColor: Colors.amber,
                      onChanged: (val) => setModalState(() {
                        isSuperAdmin = val;
                        if (val) isAdmin = true;
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final nombre = nameCtrl.text.trim();
                              final correo = emailCtrl.text.trim();
                              final password = passCtrl.text.trim();
                              final telefono = phoneCtrl.text.trim();

                              if (nombre.isEmpty || correo.isEmpty || password.isEmpty || telefono.isEmpty || selectedBranch.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor completa todos los campos')),
                                );
                                return;
                              }

                              setModalState(() => isSaving = true);

                              final errorMsg = await ref.read(adminUsersNotifierProvider.notifier).createUser(
                                    nombre: nombre,
                                    correo: correo,
                                    password: password,
                                    telefono: telefono,
                                    sucursal: selectedBranch,
                                    isAdmin: isAdmin,
                                    isSuperAdmin: isSuperAdmin,
                                  );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg == null ? '¡Usuario creado exitosamente!' : 'Error: $errorMsg'),
                                    backgroundColor: errorMsg == null ? Colors.green : AppColors.error,
                                  ),
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Registrar Usuario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // NAVEGAR A PANTALLA COMPLETA: CREAR / EDITAR SUCURSAL
  void _showBranchBottomSheet(BuildContext context, {Map<String, dynamic>? branch}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(branch: branch),
      ),
    );
  }

  // TAB 3: PEDIDOS
  Widget _buildPedidosTab(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text('No hay pedidos registrados', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final pendingOrders = orders.where((o) => o['status'] == 'pending' || o['status'] == 'procesando').toList();
        final completedOrders = orders.where((o) => o['status'] == 'completado' || o['status'] == 'entregado' || o['status'] == 'cancelado').toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            if (pendingOrders.isNotEmpty) ...[
              const Text('Pendientes de Procesar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...pendingOrders.map((order) => _buildOrderCard(order)),
              const SizedBox(height: 24),
            ],
            if (completedOrders.isNotEmpty) ...[
              const Text('Historial de Pedidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...completedOrders.map((order) => _buildOrderCard(order)),
            ],
            const SizedBox(height: 100),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Error al cargar pedidos: $e')),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final total = (order['total'] ?? 0).toString();
    final date = order['created_at'] != null 
        ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(order['created_at']).toLocal())
        : '';
    final orderItems = (order['order_items'] as List?) ?? [];
    
    Color statusColor = Colors.orange;
    String statusText = 'Pendiente';
    if (status == 'completado' || status == 'entregado') {
      statusColor = Colors.green;
      statusText = 'Completado';
    } else if (status == 'cancelado') {
      statusColor = AppColors.error;
      statusText = 'Cancelado';
    }

    final customerName = order['customer_name']?.toString() ?? '';
    final customerPhone = order['customer_phone']?.toString() ?? '';
    final customerEmail = order['customer_email']?.toString() ?? '';
    final isDelivery = order['is_delivery'] == true;
    final deliveryAddress = order['delivery_address']?.toString() ?? '';
    final branchName = order['branch_name']?.toString() ?? '';
    final shippingCost = (order['shipping_cost'] ?? 0).toString();
    final distanceKm = order['delivery_distance_km'] != null ? '${order['delivery_distance_km']} km' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Orden #${order['id'].toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Fecha: $date', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          
          // DATOS DEL CLIENTE
          if (customerName.isNotEmpty || customerPhone.isNotEmpty || customerEmail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  if (customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(customerPhone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                  if (customerEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            customerEmail,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // DATOS DE ENVÍO A DOMICILIO SI APLICA
          if (isDelivery) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.motorcycle, size: 15, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Envío a Domicilio ${distanceKm != null ? '($distanceKm)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                      ),
                      const Spacer(),
                      Text('+\$$shippingCost', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                    ],
                  ),
                  if (deliveryAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Destino: $deliveryAddress',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (branchName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sucursal despacho: $branchName',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 6),

          // LISTA DE ITEMS
          ...orderItems.map((item) {
            final isProduct = item['item_type'] == 'product';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(isProduct ? Icons.inventory_2_outlined : Icons.cleaning_services_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${item['quantity']}x ID:${item['item_id'].toString().substring(0, item['item_id'].toString().length > 6 ? 6 : item['item_id'].toString().length)}', style: const TextStyle(fontSize: 12)),
                  ),
                  Text('\$${item['price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: \$$total MXN', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              if (status == 'pending' || status == 'procesando')
                Row(
                  children: [
                    if (status == 'pending') ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () {
                          ref.read(adminOrdersNotifierProvider.notifier).updateOrderStatus(order['id'], 'procesando', ref);
                        },
                        child: const Text('Procesar', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: () {
                        ref.read(adminOrdersNotifierProvider.notifier).updateOrderStatus(order['id'], 'completado', ref);
                      },
                      child: const Text('Completar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
