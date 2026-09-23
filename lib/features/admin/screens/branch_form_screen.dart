import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' as img_picker;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sneakerz_app/core/constants/colors.dart';
import 'package:sneakerz_app/features/auth/providers/auth_provider.dart';
import 'package:sneakerz_app/features/admin/providers/admin_dashboard_provider.dart';
import 'package:sneakerz_app/core/widgets/streetwear_background.dart';

class DayScheduleItem {
  final String key;
  final String label;
  bool isActive;
  TimeOfDay openTime;
  TimeOfDay closeTime;

  DayScheduleItem({
    required this.key,
    required this.label,
    this.isActive = true,
    this.openTime = const TimeOfDay(hour: 10, minute: 0),
    this.closeTime = const TimeOfDay(hour: 18, minute: 0),
  });

  Map<String, dynamic> toJson() => {
        'activo': isActive,
        'apertura': '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}',
        'cierre': '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}',
      };
}

class BranchFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? branch;

  const BranchFormScreen({super.key, this.branch});

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;

  double _lat = 25.686614; // Default: Monterrey / MX
  double _lng = -100.316113;
  double _zoom = 15.0;
  bool _isOpen = true;
  String? _uploadedImageUrl;

  bool get _isDesktopOrWeb =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  // Mapbox
  MapboxMap? _mapboxMap;
  String? _mapboxToken;
  bool _isMapReady = false;

  // Autocompletado de Mapbox
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  Timer? _debounceTimer;

  // Horario por Día
  late List<DayScheduleItem> _scheduleDays;

  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;

    _nameCtrl = TextEditingController(text: b?['nombre_sucursal'] ?? b?['nombre'] ?? b?['name'] ?? '');
    _addressCtrl = TextEditingController(text: b?['direccion'] ?? b?['address'] ?? b?['ubicacion'] ?? '');
    _phoneCtrl = TextEditingController(text: b?['telefono'] ?? b?['phone'] ?? '');

    _isOpen = b?['is_open'] ?? b?['is_active'] ?? b?['activo'] ?? true;
    _uploadedImageUrl = b?['imagen_sucursal'] ?? b?['imagen'] ?? b?['image'] ?? b?['foto'];

    final parsedLat = _parseDouble(b?['lat'] ?? b?['latitud'] ?? b?['latitude']);
    final parsedLng = _parseDouble(b?['long'] ?? b?['lng'] ?? b?['longitud'] ?? b?['longitude']);
    if (parsedLat != null && parsedLng != null && parsedLat != 0 && parsedLng != 0) {
      _lat = parsedLat;
      _lng = parsedLng;
    }

    _initSchedule(b);
    _initMapbox();
  }

  void _initSchedule(Map<String, dynamic>? branch) {
    final days = [
      {'key': 'lunes', 'label': 'Lunes'},
      {'key': 'martes', 'label': 'Martes'},
      {'key': 'miercoles', 'label': 'Miércoles'},
      {'key': 'jueves', 'label': 'Jueves'},
      {'key': 'viernes', 'label': 'Viernes'},
      {'key': 'sabado', 'label': 'Sábado'},
      {'key': 'domingo', 'label': 'Domingo'},
    ];

    dynamic existingJson = branch?['horario_json'] ??
        branch?['horarios_json'] ??
        branch?['horario_semanal'] ??
        branch?['horarios'] ??
        branch?['schedule_json'] ??
        branch?['detalle_horario'];

    Map<String, dynamic> jsonMap = {};
    if (existingJson is Map) {
      jsonMap = Map<String, dynamic>.from(existingJson);
    } else if (existingJson is String) {
      try {
        jsonMap = Map<String, dynamic>.from(jsonDecode(existingJson));
      } catch (_) {}
    }

    _scheduleDays = days.map((d) {
      final key = d['key']!;
      final label = d['label']!;
      final dayData = jsonMap[key];

      if (dayData is Map) {
        final active = dayData['activo'] ?? dayData['active'] ?? true;
        final ap = (dayData['apertura'] ?? '10:00').toString();
        final ci = (dayData['cierre'] ?? '18:00').toString();

        return DayScheduleItem(
          key: key,
          label: label,
          isActive: active == true,
          openTime: _parseTime(ap, const TimeOfDay(hour: 10, minute: 0)),
          closeTime: _parseTime(ci, const TimeOfDay(hour: 18, minute: 0)),
        );
      }

      return DayScheduleItem(
        key: key,
        label: label,
        isActive: key != 'domingo', // Default: Domingo cerrado
        openTime: const TimeOfDay(hour: 10, minute: 0),
        closeTime: const TimeOfDay(hour: 18, minute: 0),
      );
    }).toList();
  }

  TimeOfDay _parseTime(String str, TimeOfDay fallback) {
    final parts = str.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? fallback.hour;
      final m = int.tryParse(parts[1]) ?? fallback.minute;
      return TimeOfDay(hour: h, minute: m);
    }
    return fallback;
  }

  void _initMapbox() {
    final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    if (token.isNotEmpty) {
      MapboxOptions.setAccessToken(token);
      _mapboxToken = token;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  void _onPanMap(DragUpdateDetails details) {
    final factor = 360.0 / (256.0 * (1 << _zoom.toInt().clamp(1, 20)));
    setState(() {
      _lng -= details.delta.dx * factor * 0.45;
      _lat += details.delta.dy * factor * 0.45;
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    setState(() {
      _isMapReady = true;
    });

    _flyToCoordinates(_lat, _lng, zoom: 15.0);
  }

  void _flyToCoordinates(double lat, double lng, {double zoom = 15.5}) {
    if (_mapboxMap == null) return;
    _mapboxMap?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(lng, lat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _updateCoordsFromCenter() async {
    if (_mapboxMap == null) return;
    final state = await _mapboxMap?.getCameraState();
    final center = state?.center;
    if (center != null) {
      setState(() {
        _lat = center.coordinates.lat.toDouble();
        _lng = center.coordinates.lng.toDouble();
      });
    }
  }

  // Búsqueda de Geocoding Mapbox
  void _onAddressChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _addressSuggestions = [];
        _isSearchingAddress = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearchingAddress = true);
      try {
        final token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?access_token=$token&autocomplete=true&language=es&limit=5',
        );

        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final features = (data['features'] as List<dynamic>?) ?? [];
          setState(() {
            _addressSuggestions = features.map((f) => f as Map<String, dynamic>).toList();
            _isSearchingAddress = false;
          });
        } else {
          setState(() => _isSearchingAddress = false);
        }
      } catch (_) {
        setState(() => _isSearchingAddress = false);
      }
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final placeName = suggestion['place_name']?.toString() ?? '';
    final center = suggestion['center'] as List<dynamic>? ?? [];

    if (center.length >= 2) {
      final lng = (center[0] as num).toDouble();
      final lat = (center[1] as num).toDouble();

      setState(() {
        _lng = lng;
        _lat = lat;
        _addressCtrl.text = placeName;
        _addressSuggestions = [];
      });

      _flyToCoordinates(lat, lng, zoom: 16.0);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = img_picker.ImagePicker();
      final picked = await picker.pickImage(source: img_picker.ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final fileName = 'branch_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final supabase = ref.read(supabaseClientProvider);
      await supabase.storage.from('general').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      final publicUrl = supabase.storage.from('general').getPublicUrl(fileName);

      setState(() {
        _uploadedImageUrl = publicUrl;
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _generateScheduleSummary() {
    final activeDays = _scheduleDays.where((d) => d.isActive).toList();
    if (activeDays.isEmpty) return 'Cerrado temporalmente';

    // Formatear resumen
    final openStr = activeDays.first.openTime.format(context);
    final closeStr = activeDays.first.closeTime.format(context);
    return 'Lun - Sáb: $openStr - $closeStr';
  }

  Map<String, dynamic> _generateScheduleJson() {
    final map = <String, dynamic>{};
    for (final day in _scheduleDays) {
      map[day.key] = day.toJson();
    }
    return map;
  }

  Future<void> _saveBranch() async {
    final nombre = _nameCtrl.text.trim();
    final direccion = _addressCtrl.text.trim();

    if (nombre.isEmpty || direccion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa el nombre y la dirección de la sucursal')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final scheduleJson = _generateScheduleJson();
    final scheduleText = _generateScheduleSummary();

    String? errorMsg;
    if (widget.branch == null) {
      errorMsg = await ref.read(adminBranchesNotifierProvider.notifier).createBranch(
            nombre: nombre,
            direccion: direccion,
            telefono: _phoneCtrl.text.trim(),
            horario: scheduleText,
            horarioJson: scheduleJson,
            latitud: _lat,
            longitud: _lng,
            imagen: _uploadedImageUrl,
            isOpen: _isOpen,
          );
    } else {
      errorMsg = await ref.read(adminBranchesNotifierProvider.notifier).updateBranch(
            id: widget.branch!['id'],
            nombre: nombre,
            direccion: direccion,
            telefono: _phoneCtrl.text.trim(),
            horario: scheduleText,
            horarioJson: scheduleJson,
            latitud: _lat,
            longitud: _lng,
            imagen: _uploadedImageUrl,
            isOpen: _isOpen,
          );
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (errorMsg == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.branch == null ? '¡Sucursal creada exitosamente!' : '¡Sucursal actualizada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMsg'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.branch != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Sucursal' : 'Nueva Sucursal',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _saveBranch,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.check_circle_outline, color: AppColors.primary),
              label: Text(
                isEditing ? 'Guardar' : 'Crear',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      body: StreetwearBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. INFORMACIÓN GENERAL
                _buildSectionCard(
                  title: '🏢 Información General',
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Sucursal (ej. Sucursal Sendero)',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de Contacto',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('¿Sucursal Abierta / Operativa?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Visible en la app para agendar citas y ubicar en el mapa', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        value: _isOpen,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isOpen = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. UBICACIÓN & MAPA INTERACTIVO
                _buildSectionCard(
                  title: '📍 Ubicación & Mapa Interactivo',
                  children: [
                    const Text(
                      'Busca la dirección o desplaza el mapa para colocar el pin en la posición exacta.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    // Input de Dirección con Autocompletado
                    TextField(
                      controller: _addressCtrl,
                      onChanged: _onAddressChanged,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Buscar Dirección Física (Sugerencias Mapbox)',
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.accent),
                        suffixIcon: _isSearchingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : (_addressCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _addressCtrl.clear();
                                      setState(() => _addressSuggestions = []);
                                    },
                                  )
                                : null),
                      ),
                    ),

                    // Lista de sugerencias
                    if (_addressSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _addressSuggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final sug = _addressSuggestions[i];
                            final placeName = sug['place_name']?.toString() ?? '';
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.navigation_outlined, size: 16, color: AppColors.accent),
                                title: Text(sug['text']?.toString() ?? placeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(placeName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () => _selectSuggestion(sug),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 14),

                    // MAPA INTERACTIVO DE MAPBOX
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 280,
                        width: double.infinity,
                        child: _isDesktopOrWeb
                            ? GestureDetector(
                                onPanUpdate: _onPanMap,
                                child: Stack(
                                  children: [
                                    if (_mapboxToken != null && _mapboxToken!.isNotEmpty)
                                      Image.network(
                                        'https://api.mapbox.com/styles/v1/mapbox/light-v11/static/${_lng.toStringAsFixed(6)},${_lat.toStringAsFixed(6)},${_zoom.toInt()},0/800x400?access_token=$_mapboxToken',
                                        width: double.infinity,
                                        height: 280,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (ctx, child, progress) {
                                          if (progress == null) return child;
                                          return Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(color: AppColors.primary),
                                            ),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          child: const Center(child: Text('Error al cargar mapa')),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Text('Mapbox token no configurado', style: TextStyle(color: Colors.red)),
                                        ),
                                      ),

                                    // PIN FIJO AL CENTRO DEL MAPA
                                    Positioned.fill(
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 36.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                                                  ],
                                                ),
                                                child: const Text(
                                                  'Arrastra para mover',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Icon(Icons.location_pin, size: 44, color: AppColors.accent),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Controles de Zoom (+ / -)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Column(
                                        children: [
                                          Material(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 3,
                                            child: IconButton(
                                              icon: const Icon(Icons.add, size: 18),
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (_zoom < 19) setState(() => _zoom += 1);
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Material(
                                            color: Colors.white.withValues(alpha: 0.92),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 3,
                                            child: IconButton(
                                              icon: const Icon(Icons.remove, size: 18),
                                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                if (_zoom > 3) setState(() => _zoom -= 1);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Badge de coordenadas flotante
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.94),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.my_location, size: 16, color: AppColors.accent),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Lat: ${_lat.toStringAsFixed(5)}, Lng: ${_lng.toStringAsFixed(5)}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  if (_mapboxToken != null && _mapboxToken!.isNotEmpty)
                                    MapWidget(
                                      key: const ValueKey("branch_form_map"),
                                      onMapCreated: _onMapCreated,
                                      styleUri: MapboxStyles.LIGHT,
                                      onCameraChangeListener: (_) => _updateCoordsFromCenter(),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Text('Mapbox token no configurado', style: TextStyle(color: Colors.red)),
                                      ),
                                    ),

                                  // PIN FIJO AL CENTRO DEL MAPA
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 36.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6),
                                                ],
                                              ),
                                              child: const Text(
                                                'Mueve el mapa',
                                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Icon(Icons.location_pin, size: 44, color: AppColors.accent),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Badge de coordenadas flotante
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.94),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.my_location, size: 16, color: AppColors.accent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Lat: ${_lat.toStringAsFixed(5)}, Lng: ${_lng.toStringAsFixed(5)}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. HORARIOS POR DÍA
                _buildSectionCard(
                  title: '🕒 Horario Semanal por Día',
                  children: [
                    const Text(
                      'Configura la disponibilidad y horas de apertura/cierre para cada día de la semana.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_scheduleDays.length, (index) {
                      final day = _scheduleDays[index];
                      return _buildDayScheduleTile(day);
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. FOTOGRAFÍA DE FACHADA
                _buildSectionCard(
                  title: '📸 Fotografía de Fachada / Sucursal',
                  children: [
                    const Text(
                      'Sube una imagen representativa para que los clientes reconozcan la sucursal.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _isUploadingImage ? null : _pickAndUploadImage,
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _uploadedImageUrl != null ? AppColors.primary : Colors.black26),
                        ),
                        child: _isUploadingImage
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(19),
                                        child: Image.network(
                                          _uploadedImageUrl!,
                                          width: double.infinity,
                                          height: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: _pickAndUploadImage,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                                    SizedBox(width: 4),
                                                    Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () => setState(() => _uploadedImageUrl = null),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                                        child: const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text('Toca para subir foto de la sucursal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      const Text('Se guardará en el bucket general', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // BOTÓN GUARDAR
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                      elevation: 4,
                    ),
                    onPressed: _isSaving ? null : _saveBranch,
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                        : Text(
                            isEditing ? 'Guardar Cambios' : 'Crear Sucursal',
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDayScheduleTile(DayScheduleItem day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: day.isActive ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: day.isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.black12),
      ),
      child: Row(
        children: [
          // Switch Activo compacto
          Transform.scale(
            scale: 0.75,
            child: Switch.adaptive(
              value: day.isActive,
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) => setState(() => day.isActive = val),
            ),
          ),
          const SizedBox(width: 4),
          // Nombre del Día flexible
          Expanded(
            child: Text(
              day.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: day.isActive ? AppColors.textPrimary : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Horarios Apertura / Cierre
          if (day.isActive) ...[
            _buildTimePickerButton(
              time: day.openTime,
              onSelected: (newTime) => setState(() => day.openTime = newTime),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
            ),
            _buildTimePickerButton(
              time: day.closeTime,
              onSelected: (newTime) => setState(() => day.closeTime = newTime),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
              child: const Text('Cerrado', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerButton({required TimeOfDay time, required ValueChanged<TimeOfDay> onSelected}) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 12, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
