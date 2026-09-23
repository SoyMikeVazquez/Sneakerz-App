import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:sneakerz_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:sneakerz_app/features/auth/providers/auth_provider.dart';
import 'package:sneakerz_app/features/booking/providers/services_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroBottomSheet extends ConsumerStatefulWidget {
  const RegistroBottomSheet({super.key});

  @override
  ConsumerState<RegistroBottomSheet> createState() => _RegistroBottomSheetState();
}

class _RegistroBottomSheetState extends ConsumerState<RegistroBottomSheet> {
  int _currentStep = 0; // 0: Search, 1: Register Client, 2: Job Details
  bool _isLoading = false;

  // Step 0: Search
  final _searchCtrl = TextEditingController();
  bool _searchByPhone = false;
  bool _hasSearched = false;
  String _lastQuery = '';
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _defaultClients = [];
  bool _isLoadingDefaultClients = false;
  Map<String, dynamic>? _selectedClient;

  // Step 1: Register Client
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientEmailCtrl = TextEditingController();

  // Step 2: Job Details
  final _modelCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _anticipoCtrl = TextEditingController();
  String? _selectedService;
  String? _selectedBranchName;
  String? _selectedBranchId;
  List<String> _uploadedImageUrls = [];
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultClients();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDefaultBranch();
    });
  }

  Future<void> _loadDefaultClients() async {
    setState(() => _isLoadingDefaultClients = true);
    final supabase = ref.read(supabaseClientProvider);
    try {
      List<dynamic> response;
      try {
        response = await supabase
            .from('clientes')
            .select('*')
            .order('nombre', ascending: true)
            .limit(100);
      } catch (_) {
        response = await supabase
            .from('clientes')
            .select('*')
            .limit(100);
      }

      if (mounted) {
        setState(() {
          _defaultClients = response.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoadingDefaultClients = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando clientes predeterminados: $e');
      if (mounted) {
        setState(() => _isLoadingDefaultClients = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _searchResults.clear();
      });
      return;
    }

    List<Map<String, dynamic>> filtered = [];
    if (_searchByPhone) {
      final cleanDigits = query.replaceAll(RegExp(r'\D'), '');
      filtered = _defaultClients.where((c) {
        final t = (c['telefono'] ?? c['phone'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
        return t.contains(cleanDigits);
      }).toList();
    } else {
      final lower = query.toLowerCase();
      filtered = _defaultClients.where((c) {
        final n = (c['nombre'] ?? c['name'] ?? '').toString().toLowerCase();
        final email = (c['correo'] ?? c['email'] ?? '').toString().toLowerCase();
        return n.contains(lower) || email.contains(lower);
      }).toList();
    }

    setState(() {
      _hasSearched = true;
      _lastQuery = query;
      _searchResults = filtered;
    });
  }

  void _initDefaultBranch() {
    final branchesAsync = ref.read(adminBranchesProvider);
    final currentSelectedBranch = ref.read(selectedBranchIdProvider);
    final branchesList = branchesAsync.value ?? [];
    if (branchesList.isNotEmpty) {
      final match = branchesList.firstWhere(
        (b) => b['id']?.toString() == currentSelectedBranch?.toString(),
        orElse: () => branchesList.first,
      );
      setState(() {
        _selectedBranchName = match['nombre'] ?? match['name'] ?? 'Matriz';
        _selectedBranchId = match['id']?.toString();
      });
    } else {
      setState(() {
        _selectedBranchName = 'Matriz';
      });
    }
  }

  Future<void> _searchClient() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _lastQuery = query;
    });

    final supabase = ref.read(supabaseClientProvider);
    try {
      List<Map<String, dynamic>> results = [];

      if (_searchByPhone) {
        final cleanDigits = query.replaceAll(RegExp(r'\D'), '');

        if (cleanDigits.isNotEmpty) {
          try {
            final numVal = int.tryParse(cleanDigits);
            if (numVal != null) {
              final directRes = await supabase
                  .from('clientes')
                  .select('*')
                  .or('telefono.eq.$cleanDigits,telefono.eq.$numVal')
                  .limit(10);
              if (directRes is List) {
                results.addAll(directRes.map((e) => Map<String, dynamic>.from(e)));
              }
            }
          } catch (_) {}
        }

        // Fallback en memoria si no se encontraron resultados directos
        if (results.isEmpty && cleanDigits.isNotEmpty) {
          final all = await supabase.from('clientes').select('*').limit(100);
          final digitsLast10 = cleanDigits.length >= 10
              ? cleanDigits.substring(cleanDigits.length - 10)
              : cleanDigits;
          results = all.where((c) {
            final t = (c['telefono'] ?? c['phone'] ?? '')
                .toString()
                .replaceAll(RegExp(r'\D'), '');
            return t.contains(cleanDigits) ||
                t.contains(digitsLast10) ||
                (cleanDigits.length >= 7 && t.endsWith(cleanDigits));
          }).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      } else {
        // Búsqueda por nombre con similitud (ilike)
        try {
          final response = await supabase
              .from('clientes')
              .select('*')
              .ilike('nombre', '%$query%')
              .limit(15);
          if (response is List) {
            results.addAll(response.map((e) => Map<String, dynamic>.from(e)));
          }
        } catch (_) {}

        // Fallback en memoria para máxima compatibilidad
        if (results.isEmpty) {
          final all = await supabase.from('clientes').select('*').limit(100);
          results = all.where((c) {
            final n = (c['nombre'] ?? c['name'] ?? '').toString().toLowerCase();
            return n.contains(query.toLowerCase());
          }).map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching client: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerClient() async {
    final name = _clientNameCtrl.text.trim();
    final phone = _clientPhoneCtrl.text.trim();
    final email = _clientEmailCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y teléfono son obligatorios'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);
    try {
      final numericPhone = int.tryParse(phone.replaceAll(RegExp(r'\D'), '')) ?? phone;
      final response = await supabase
          .from('clientes')
          .insert({
            'nombre': name,
            'telefono': numericPhone,
            if (email.isNotEmpty) 'correo': email,
          })
          .select()
          .single();
      
      setState(() {
        _defaultClients.insert(0, Map<String, dynamic>.from(response));
        _selectedClient = response;
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error registering client: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar cliente: $e'), backgroundColor: AppColors.error),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_uploadedImageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 5 fotos permitidas'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      
      setState(() => _isUploadingImage = true);
      
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final fileName = 'registro_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final supabase = ref.read(supabaseClientProvider);
      
      await supabase.storage.from('general').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
          
      final publicUrl = supabase.storage.from('general').getPublicUrl(fileName);
      
      setState(() {
        _uploadedImageUrls.add(publicUrl);
        _isUploadingImage = false;
      });
    } catch (e) {
      debugPrint('Error uploading image: $e');
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveRegistro() async {
    if (_selectedClient == null) return;
    if (_selectedService == null || _modelCtrl.text.isEmpty || _montoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio, modelo y monto son obligatorios'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    final errorMsg = await ref.read(adminRegistrosNotifierProvider.notifier).createRegistro(
      clienteNombre: _selectedClient!['nombre'] ?? 'Cliente',
      telefono: _selectedClient!['telefono'] ?? '',
      correo: _selectedClient!['correo'],
      modelo: _modelCtrl.text.trim(),
      servicio: _selectedService!,
      sucursal: _selectedBranchName ?? 'Matriz',
      sucursalId: _selectedBranchId,
      notas: _notesCtrl.text.trim(),
      total: double.tryParse(_montoCtrl.text.trim()) ?? 0.0,
      anticipo: double.tryParse(_anticipoCtrl.text.trim()) ?? 0.0,
      imageUrls: _uploadedImageUrls,
    );

    setState(() => _isLoading = false);

    if (errorMsg == null) {
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMsg'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
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
              const Text(
                '👟 Nuevo Registro',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildCurrentStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildSearchStep();
      case 1:
        return _buildRegisterClientStep();
      case 2:
        return _buildJobDetailsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildSearchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buscar Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),

        // Switch / Selector de Tipo de Búsqueda
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_searchByPhone) {
                      setState(() {
                        _searchByPhone = false;
                        _searchCtrl.clear();
                        _searchResults.clear();
                        _hasSearched = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_searchByPhone ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 18,
                          color: !_searchByPhone ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Por Nombre',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !_searchByPhone ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_searchByPhone) {
                      setState(() {
                        _searchByPhone = true;
                        _searchCtrl.clear();
                        _searchResults.clear();
                        _hasSearched = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _searchByPhone ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.phone,
                          size: 18,
                          color: _searchByPhone ? Colors.white : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Por Teléfono',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _searchByPhone ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Campo de Búsqueda
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                keyboardType: _searchByPhone ? TextInputType.phone : TextInputType.text,
                decoration: InputDecoration(
                  hintText: _searchByPhone ? '10 dígitos (ej. 5512345678)' : 'Nombre del cliente (ej. Mike)',
                  prefixIcon: _searchByPhone
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: const Text(
                            '+52',
                            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14),
                          ),
                        )
                      : const Icon(Icons.search, color: AppColors.primary),
                  prefixIconConstraints: _searchByPhone ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _hasSearched = false;
                              _searchResults.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _searchClient(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _searchClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Lista de clientes (predeterminada o resultados de búsqueda)
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _hasSearched
                  ? (_searchResults.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resultados encontrados (${_searchResults.length}):',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => _buildClientCard(_searchResults[index]),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 54, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontró ningún cliente con "$_lastQuery"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Puedes buscar manualmente arriba o registrarlo con el botón de abajo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ))
                  : (_isLoadingDefaultClients
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 12),
                              Text(
                                'Cargando clientes...',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : _defaultClients.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Clientes Registrados (${_defaultClients.length}):',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      _searchByPhone ? 'Filtro por teléfono' : 'Filtro por nombre',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _defaultClients.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) => _buildClientCard(_defaultClients[index]),
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 54,
                                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No hay clientes registrados aún',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            )),
        ),

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Pre-llenar con lo que buscó si aplica
              if (!_searchByPhone && _searchCtrl.text.trim().isNotEmpty) {
                _clientNameCtrl.text = _searchCtrl.text.trim();
              } else if (_searchByPhone && _searchCtrl.text.trim().isNotEmpty) {
                _clientPhoneCtrl.text = _searchCtrl.text.trim();
              }
              setState(() => _currentStep = 1);
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Registrar Nuevo Cliente'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final nombre = client['nombre'] ?? client['name'] ?? 'Sin nombre';
    final tel = client['telefono'] ?? client['phone'] ?? 'Sin teléfono';
    final correo = client['correo'] ?? client['email'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(
          nombre.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '📞 $tel${correo.isNotEmpty ? ' • $correo' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
        onTap: () {
          setState(() {
            _selectedClient = client;
            _currentStep = 2; // Go to Job Details
          });
        },
      ),
    );
  }

  Widget _buildRegisterClientStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 0),
              ),
              const Text('Registrar Nuevo Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clientNameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo (Opcional)', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _registerClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar y Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsStep() {
    final servicesAsync = ref.watch(servicesProvider);
    
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() {
                _selectedClient = null;
                _currentStep = 0;
              }),
            ),
            Expanded(
              child: Text(
                'Cliente: ${_selectedClient?['nombre'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                servicesAsync.when(
                  data: (services) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Servicio',
                      prefixIcon: Icon(Icons.cleaning_services_outlined),
                    ),
                    value: _selectedService,
                    items: services.map((s) => DropdownMenuItem(
                      value: s.name,
                      child: Text(s.name),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedService = val),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error cargando servicios'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(labelText: 'Marca / Modelo del Par', prefixIcon: Icon(Icons.ice_skating)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monto Total (\$)', prefixIcon: Icon(Icons.attach_money)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _anticipoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Anticipo (\$)', prefixIcon: Icon(Icons.money)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notas / Detalles', prefixIcon: Icon(Icons.notes)),
                ),
                const SizedBox(height: 16),
                
                // Photos section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Fotos del Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${_uploadedImageUrls.length}/5', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._uploadedImageUrls.map((url) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: -10,
                              right: -10,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _uploadedImageUrls.remove(url);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      
                      if (_uploadedImageUrls.length < 5)
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black26),
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.add_a_photo, color: AppColors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveRegistro,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Crear Registro', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
