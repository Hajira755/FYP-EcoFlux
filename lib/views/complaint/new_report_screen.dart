import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../viewmodels/complaint_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

// ─────────────────────────────────────────────
//  Color / Style Constants
// ─────────────────────────────────────────────
const _kGreen        = Color(0xFF2E7D32);
const _kGreenLight   = Color(0xFF66BB6A);
const _kGreenSurface = Color(0xFFE8F5E9);
const _kCardRadius   = 16.0;

// Gradient used in AppBar
const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF43A047), Color(0xFF81C784)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// Approximate bounding box covering all of Pakistan — used to reject any
// picked location (search / current location / map tap) that falls outside
// the country.
const double _kPakLatMin = 23.5;
const double _kPakLatMax = 37.5;
const double _kPakLngMin = 60.5;
const double _kPakLngMax = 77.5;

bool _isInPakistan(double lat, double lng) =>
    lat >= _kPakLatMin &&
        lat <= _kPakLatMax &&
        lng >= _kPakLngMin &&
        lng <= _kPakLngMax;

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen>
    with SingleTickerProviderStateMixin {
  final _formKey               = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedCategory;
  String  _selectedPriority = 'Medium';

  LatLng? _selectedLocation;
  String  _locationAddress = '';

  bool _isLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  final List<String> _categories = [
    'Overflowing Bin',
    'Illegal Dumping',
    'Uncollected Waste',
    'Other',
  ];

  // ── CHANGE 1: Category → Priority auto-mapping
  static const Map<String, String> _categoryPriority = {
    'Illegal Dumping':   'High',
    'Overflowing Bin':   'Medium',
    'Uncollected Waste': 'Low',
    'Other':             'Medium',
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //  Image picker
  // ──────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 60, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      // XFile.readAsBytes() works identically on Android, iOS, and Web —
      // unlike dart:io File, which throws on Web.
      final bytes = await picked.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 60, maxWidth: 1024, maxHeight: 1024);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _selectedImageBytes = bytes);
    }
  }

  // ──────────────────────────────────────────
  //  Location picker dialog
  // ──────────────────────────────────────────
  Future<void> _showLocationPicker() async {
    final locationNotifier = ValueNotifier<LatLng>(
      _selectedLocation ?? const LatLng(33.6844, 73.0479),
    );
    final addressNotifier  = ValueNotifier<String>(_locationAddress);
    final searchController = TextEditingController();
    final mapController    = MapController();
    bool isSearching       = false;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header with gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: _kHeaderGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Pick Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ── Search bar
                      StatefulBuilder(
                        builder: (_, setSearchState) => TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search address or area…',
                            prefixIcon:
                            const Icon(Icons.search, color: _kGreen),
                            suffixIcon: isSearching
                                ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kGreen),
                              ),
                            )
                                : null,
                            filled: true,
                            fillColor: _kGreenSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                          ),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) async {
                            if (value.trim().isEmpty) return;
                            setSearchState(() => isSearching = true);
                            try {
                              final url = Uri.parse(
                                  'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(value)}&format=json&limit=1&countrycodes=pk');
                              final response = await http.get(url,
                                  headers: {'User-Agent': 'EcoFlux-App/1.0'});
                              if (response.statusCode == 200) {
                                final data = jsonDecode(response.body);
                                if (data.isNotEmpty) {
                                  final lat = double.parse(data[0]['lat']);
                                  final lon = double.parse(data[0]['lon']);
                                  if (!_isInPakistan(lat, lon)) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Only locations within Pakistan are allowed')),
                                      );
                                    }
                                  } else {
                                    final newLoc = LatLng(lat, lon);
                                    locationNotifier.value = newLoc;
                                    addressNotifier.value =
                                    data[0]['display_name'];
                                    mapController.move(newLoc, 15);
                                  }
                                } else if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'No location found in Pakistan for this search')),
                                  );
                                }
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content:
                                      Text('Search failed. Try again.')),
                                );
                              }
                            } finally {
                              setSearchState(() => isSearching = false);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Current location button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              LocationPermission permission =
                              await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied) {
                                permission =
                                await Geolocator.requestPermission();
                              }
                              if (permission ==
                                  LocationPermission.deniedForever ||
                                  permission == LocationPermission.denied) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content:
                                        Text('Location permission denied')),
                                  );
                                }
                                return;
                              }
                              final position =
                              await Geolocator.getCurrentPosition(
                                desiredAccuracy: LocationAccuracy.high,
                              );
                              if (!_isInPakistan(
                                  position.latitude, position.longitude)) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Your current location is outside Pakistan. Please pick a location manually.')),
                                  );
                                }
                                return;
                              }
                              final newLoc = LatLng(
                                  position.latitude, position.longitude);
                              locationNotifier.value = newLoc;
                              mapController.move(newLoc, 16);
                              try {
                                final placemarks =
                                await placemarkFromCoordinates(
                                  position.latitude,
                                  position.longitude,
                                );
                                if (placemarks.isNotEmpty) {
                                  final p = placemarks.first;
                                  addressNotifier.value =
                                      '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}'
                                          .replaceAll(
                                          RegExp(r'^,\s*|,\s*$'), '')
                                          .trim();
                                }
                              } catch (_) {
                                addressNotifier.value =
                                '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                      content:
                                      Text('Could not get location: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Use My Current Location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kGreen,
                            side: const BorderSide(color: _kGreen),
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Map
                      ValueListenableBuilder<LatLng>(
                        valueListenable: locationNotifier,
                        builder: (_, loc, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 280,
                            child: FlutterMap(
                              mapController: mapController,
                              options: MapOptions(
                                initialCenter: loc,
                                initialZoom: 15,
                                onTap: (_, point) async {
                                  if (!_isInPakistan(
                                      point.latitude, point.longitude)) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Only locations within Pakistan are allowed')),
                                      );
                                    }
                                    return;
                                  }
                                  locationNotifier.value = point;
                                  try {
                                    final placemarks =
                                    await placemarkFromCoordinates(
                                      point.latitude,
                                      point.longitude,
                                    );
                                    if (placemarks.isNotEmpty) {
                                      final p = placemarks.first;
                                      addressNotifier.value =
                                          '${p.street ?? ''}, ${p.subLocality ?? ''}, ${p.locality ?? ''}'
                                              .replaceAll(
                                              RegExp(r'^,\s*|,\s*$'), '')
                                              .trim();
                                    }
                                  } catch (_) {
                                    addressNotifier.value =
                                    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                  'com.example.ecoflux',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: loc,
                                      width: 44,
                                      height: 44,
                                      child: const Icon(Icons.location_pin,
                                          color: Colors.red, size: 44),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── Selected address preview
                      ValueListenableBuilder<String>(
                        valueListenable: addressNotifier,
                        builder: (_, addr, __) => addr.isEmpty
                            ? const SizedBox()
                            : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kGreenSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                _kGreenLight.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: _kGreen, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  addr,
                                  style: const TextStyle(
                                      fontSize: 13, color: _kGreen),
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

              // ── Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = locationNotifier.value;
                            _locationAddress =
                            addressNotifier.value.isNotEmpty
                                ? addressNotifier.value
                                : '${locationNotifier.value.latitude.toStringAsFixed(5)}, ${locationNotifier.value.longitude.toStringAsFixed(5)}';
                          });
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Location',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Submit
  // ──────────────────────────────────────────
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showSnack('Please select a category');
      return;
    }
    if (_selectedLocation == null) {
      _showSnack('Please pick a location');
      return;
    }
    if (!_isInPakistan(
        _selectedLocation!.latitude, _selectedLocation!.longitude)) {
      _showSnack('Only locations within Pakistan are allowed');
      return;
    }

    final complaintVM =
    Provider.of<ComplaintViewModel>(context, listen: false);
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final userId = authVM.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

    await complaintVM.submitNewComplaint(
      description: _descriptionController.text.trim(),
      category:    _selectedCategory!,
      priority:    _selectedPriority,
      location:
      GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
      address:   _locationAddress,
      imageBytes: _selectedImageBytes,
      userId:    userId,
    );

    setState(() => _isLoading = false);

    if (mounted && complaintVM.errorMessage == null) {
      _showSnack('Report submitted successfully! ✅', color: _kGreen);
      Navigator.pop(context);
    } else if (mounted && complaintVM.errorMessage != null) {
      _showSnack(complaintVM.errorMessage!, color: Colors.red[700]!);
      complaintVM.clearError();
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Priority button color logic
  // ──────────────────────────────────────────
  Color _priorityFill(String label) {
    if (_selectedPriority != label) return Colors.white;
    if (label == 'High') return const Color(0xFFD32F2F);
    return _kGreen;
  }

  Color _priorityBorder(String label) {
    if (_selectedPriority != label) return const Color(0xFFBDBDBD);
    if (label == 'High') return const Color(0xFFD32F2F);
    return _kGreen;
  }

  Color _priorityTextColor(String label) {
    if (_selectedPriority != label) return const Color(0xFF757575);
    return Colors.white;
  }

  // ──────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final complaintVM = Provider.of<ComplaintViewModel>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: const BoxDecoration(gradient: _kHeaderGradient),
          child: AppBar(
            title: const Text(
              'New Report',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Photo card
              _SectionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Photo Evidence',
                subtitle: 'Optional — helps faster resolution',
                child: Column(
                  children: [
                    if (_selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedImageBytes!,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromGallery,
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 16),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGreen,
                                side: const BorderSide(color: _kGreen),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickFromCamera,
                              icon: const Icon(Icons.camera_alt_outlined,
                                  size: 16),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kGreen,
                                side: const BorderSide(color: _kGreen),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () =>
                                setState(() => _selectedImageBytes = null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                            ),
                            child:
                            const Icon(Icons.delete_outline, size: 18),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _PhotoSourceButton(
                              icon: Icons.photo_library_outlined,
                              label: 'Gallery',
                              onTap: _pickFromGallery,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _PhotoSourceButton(
                              icon: Icons.camera_alt_outlined,
                              label: 'Camera',
                              onTap: _pickFromCamera,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Description card
              _SectionCard(
                icon: Icons.description_outlined,
                title: 'Description',
                subtitle: 'Optional — max 50 words',
                child: TextFormField(
                  controller: _descriptionController,
                  minLines: 5,
                  maxLines: 8,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    hintText: 'Describe the waste issue in detail… (optional)',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: _kGreenSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGreen),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    // Description is optional now — empty is valid.
                    if (text.isEmpty) return null;

                    final wordCount = text
                        .split(RegExp(r'\s+'))
                        .where((w) => w.isNotEmpty)
                        .length;
                    if (wordCount > 50) {
                      return 'Description must not exceed 50 words (currently $wordCount)';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 14),

              // ── Category + Priority card
              _SectionCard(
                icon: Icons.category_outlined,
                title: 'Classification',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      hint: const Text('Select issue category'),
                      items: _categories
                          .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      //  auto-set priority when category changes
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v;
                          if (v != null) {
                            _selectedPriority =
                                _categoryPriority[v] ?? 'Medium';
                          }
                        });
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _kGreenSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kGreen),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                      validator: (v) =>
                      v == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Priority buttons
                    const Text('Priority',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Low', 'Medium', 'High'].map((p) {
                        return Expanded(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedPriority = p),
                              child: AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 11),
                                decoration: BoxDecoration(
                                  color: _priorityFill(p),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _priorityBorder(p),
                                    width: 1.5,
                                  ),
                                  boxShadow: _selectedPriority == p
                                      ? [
                                    BoxShadow(
                                      color: _priorityBorder(p)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: _priorityTextColor(p),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Location card
              _SectionCard(
                icon: Icons.location_on_outlined,
                title: 'Location',
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selectedLocation != null
                          ? _kGreenSurface
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedLocation != null
                            ? _kGreenLight
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _selectedLocation != null
                              ? _kGreen
                              : Colors.grey[300],
                          child: Icon(
                            _selectedLocation != null
                                ? Icons.check
                                : Icons.add_location_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedLocation != null
                                    ? 'Location Selected'
                                    : 'Tap to select location',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: _selectedLocation != null
                                      ? _kGreen
                                      : Colors.grey[600],
                                ),
                              ),
                              if (_locationAddress.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _locationAddress,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Submit button with gradient
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: (_isLoading || complaintVM.isLoading)
                      ? null
                      : _kHeaderGradient,
                  color: (_isLoading || complaintVM.isLoading)
                      ? Colors.grey[300]
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_isLoading || complaintVM.isLoading)
                      ? []
                      : [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading || complaintVM.isLoading)
                      ? null
                      : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: (_isLoading || complaintVM.isLoading)
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Submit Report',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Photo source button widget
// ─────────────────────────────────────────────
class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: _kGreenSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _kGreenLight.withValues(alpha: 0.5),
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _kGreen, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable section card widget
// ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String   title;
  final String?  subtitle;
  final Widget   child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _kGreenSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _kGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}