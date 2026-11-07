import os

base_path = r'd:\medscan\MedScanPro\medscan_web\lib'

files = {
    'models/medicine_model.dart': '''
class MedicineModel {
  final String medicineId;
  final String manufacturerId;
  final String medicineName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String registrationInfo;
  final double referencePrice;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicineModel({
    required this.medicineId,
    required this.manufacturerId,
    required this.medicineName,
    required this.genericName,
    required this.strength,
    required this.dosageForm,
    required this.registrationInfo,
    required this.referencePrice,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicineModel.fromMap(Map<String, dynamic> data, String id) {
    return MedicineModel(
      medicineId: id,
      manufacturerId: data['manufacturerId'] ?? '',
      medicineName: data['medicineName'] ?? '',
      genericName: data['genericName'] ?? '',
      strength: data['strength'] ?? '',
      dosageForm: data['dosageForm'] ?? '',
      registrationInfo: data['registrationInfo'] ?? '',
      referencePrice: (data['referencePrice'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturerId': manufacturerId,
      'medicineName': medicineName,
      'genericName': genericName,
      'strength': strength,
      'dosageForm': dosageForm,
      'registrationInfo': registrationInfo,
      'referencePrice': referencePrice,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
''',
    'models/batch_model.dart': '''
class BatchModel {
  final String batchId;
  final String medicineId;
  final String manufacturerId;
  final String batchNumber;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final String status;
  final List<String> identifiers;
  final DateTime createdAt;
  final DateTime updatedAt;

  BatchModel({
    required this.batchId,
    required this.medicineId,
    required this.manufacturerId,
    required this.batchNumber,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.status,
    required this.identifiers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BatchModel.fromMap(Map<String, dynamic> data, String id) {
    return BatchModel(
      batchId: id,
      medicineId: data['medicineId'] ?? '',
      manufacturerId: data['manufacturerId'] ?? '',
      batchNumber: data['batchNumber'] ?? '',
      manufacturingDate: data['manufacturingDate'] != null ? DateTime.parse(data['manufacturingDate'].toString()) : DateTime.now(),
      expiryDate: data['expiryDate'] != null ? DateTime.parse(data['expiryDate'].toString()) : DateTime.now(),
      status: data['status'] ?? 'active',
      identifiers: List<String>.from(data['identifiers'] ?? []),
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'batchNumber': batchNumber,
      'manufacturingDate': manufacturingDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'status': status,
      'identifiers': identifiers,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
''',
    'models/packaging_model.dart': '''
class PackagingModel {
  final String referenceId;
  final String medicineId;
  final String manufacturerId;
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? sideImageUrl;
  final List<String> otherImageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;

  PackagingModel({
    required this.referenceId,
    required this.medicineId,
    required this.manufacturerId,
    this.frontImageUrl,
    this.backImageUrl,
    this.sideImageUrl,
    required this.otherImageUrls,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PackagingModel.fromMap(Map<String, dynamic> data, String id) {
    return PackagingModel(
      referenceId: id,
      medicineId: data['medicineId'] ?? '',
      manufacturerId: data['manufacturerId'] ?? '',
      frontImageUrl: data['frontImageUrl'],
      backImageUrl: data['backImageUrl'],
      sideImageUrl: data['sideImageUrl'],
      otherImageUrls: List<String>.from(data['otherImageUrls'] ?? []),
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'manufacturerId': manufacturerId,
      'frontImageUrl': frontImageUrl,
      'backImageUrl': backImageUrl,
      'sideImageUrl': sideImageUrl,
      'otherImageUrls': otherImageUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
''',
    'repositories/manufacturer_repository.dart': '''
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_model.dart';

class ManufacturerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addMedicine(MedicineModel medicine) async {
    await _firestore.collection('medicines').add(medicine.toMap());
  }

  Stream<List<MedicineModel>> getMedicines(String manufacturerId) {
    return _firestore
        .collection('medicines')
        .where('manufacturerId', isEqualTo: manufacturerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => MedicineModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addBatch(BatchModel batch) async {
    await _firestore.collection('batches').add(batch.toMap());
  }

  Stream<List<BatchModel>> getBatches(String manufacturerId) {
    return _firestore
        .collection('batches')
        .where('manufacturerId', isEqualTo: manufacturerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BatchModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> addPackagingReference(PackagingModel ref) async {
    await _firestore.collection('packagingReferences').add(ref.toMap());
  }

  Stream<List<PackagingModel>> getPackagingReferences(String manufacturerId) {
    return _firestore
        .collection('packagingReferences')
        .where('manufacturerId', isEqualTo: manufacturerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PackagingModel.fromMap(doc.data(), doc.id)).toList());
  }
}
''',
    'providers/manufacturer_providers.dart': '''
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/manufacturer_repository.dart';
import '../services/cloudinary_service.dart';
import '../models/medicine_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_model.dart';
import 'auth_providers.dart';

final manufacturerRepositoryProvider = Provider<ManufacturerRepository>((ref) => ManufacturerRepository());
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());

final medicinesProvider = StreamProvider<List<MedicineModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getMedicines(user.uid);
});

final batchesProvider = StreamProvider<List<BatchModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getBatches(user.uid);
});

final packagingReferencesProvider = StreamProvider<List<PackagingModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getPackagingReferences(user.uid);
});
''',
    'features/manufacturer/dashboard_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/dashboard_card.dart';

class ManufacturerDashboard extends ConsumerWidget {
  const ManufacturerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider);
    final batches = ref.watch(batchesProvider);
    final packaging = ref.watch(packagingReferencesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: DashboardCard(
                title: 'Total Medicines', 
                value: medicines.when(data: (d) => d.length.toString(), loading: () => '...', error: (_,__) => '0'), 
                icon: Icons.inventory)
              ),
              const SizedBox(width: 24),
              Expanded(child: DashboardCard(
                title: 'Active Batches', 
                value: batches.when(data: (d) => d.length.toString(), loading: () => '...', error: (_,__) => '0'), 
                icon: Icons.layers)
              ),
              const SizedBox(width: 24),
              Expanded(child: DashboardCard(
                title: 'Packaging Refs', 
                value: packaging.when(data: (d) => d.length.toString(), loading: () => '...', error: (_,__) => '0'), 
                icon: Icons.qr_code)
              ),
            ],
          ),
        ],
      ),
    );
  }
}
''',
    'features/manufacturer/products_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/data_table_wrapper.dart';
import 'package:intl/intl.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicinesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Medicines', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              PrimaryButton(text: 'Add Medicine', onPressed: () => context.go('/manufacturer/add_product')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: medicinesAsync.when(
              loading: () => const LoadingState(),
              error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(medicinesProvider)),
              data: (medicines) {
                if (medicines.isEmpty) {
                  return const EmptyState(message: 'No medicines found. Add your first medicine.', icon: Icons.inventory_2_outlined);
                }
                return DataTableWrapper(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Generic')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created At')),
                  ],
                  rows: medicines.map((m) => DataRow(cells: [
                    DataCell(Text(m.medicineName)),
                    DataCell(Text(m.genericName)),
                    DataCell(Text(m.status)),
                    DataCell(Text(DateFormat.yMMMd().format(m.createdAt))),
                  ])).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
''',
    'features/manufacturer/add_product_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/medicine_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _strengthCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final repo = ref.read(manufacturerRepositoryProvider);
      final medicine = MedicineModel(
        medicineId: '',
        manufacturerId: user.uid,
        medicineName: _nameCtrl.text.trim(),
        genericName: _genericCtrl.text.trim(),
        strength: _strengthCtrl.text.trim(),
        dosageForm: _dosageCtrl.text.trim(),
        registrationInfo: _regCtrl.text.trim(),
        referencePrice: double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
        description: _descCtrl.text.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.addMedicine(medicine);
      if (mounted) context.go('/manufacturer/products');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Medicine'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/manufacturer/products')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameCtrl, 
                    decoration: const InputDecoration(labelText: 'Medicine Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _genericCtrl, 
                    decoration: const InputDecoration(labelText: 'Generic Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(
                        controller: _strengthCtrl, 
                        decoration: const InputDecoration(labelText: 'Strength (e.g., 500mg)'),
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(
                        controller: _dosageCtrl, 
                        decoration: const InputDecoration(labelText: 'Dosage Form (e.g., Tablet)'),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _regCtrl, 
                    decoration: const InputDecoration(labelText: 'Registration Info'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceCtrl, 
                    decoration: const InputDecoration(labelText: 'Reference Price'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descCtrl, 
                    decoration: const InputDecoration(labelText: 'Description'), 
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Save Medicine', onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''',
    'features/manufacturer/batches_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/data_table_wrapper.dart';
import 'package:intl/intl.dart';

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(batchesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Batches', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              PrimaryButton(text: 'Add Batch', onPressed: () => context.go('/manufacturer/add_batch')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: batchesAsync.when(
              loading: () => const LoadingState(),
              error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(batchesProvider)),
              data: (batches) {
                if (batches.isEmpty) {
                  return const EmptyState(message: 'No batches found. Add your first batch.', icon: Icons.layers_outlined);
                }
                return DataTableWrapper(
                  columns: const [
                    DataColumn(label: Text('Batch Number')),
                    DataColumn(label: Text('Medicine ID')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Expiry')),
                  ],
                  rows: batches.map((b) => DataRow(cells: [
                    DataCell(Text(b.batchNumber)),
                    DataCell(Text(b.medicineId)),
                    DataCell(Text(b.status)),
                    DataCell(Text(DateFormat.yMMMd().format(b.expiryDate))),
                  ])).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
''',
    'features/manufacturer/add_batch_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/batch_model.dart';
import '../../shared/widgets/primary_button.dart';
import 'package:intl/intl.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({super.key});

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _batchCtrl = TextEditingController();
  final _identifiersCtrl = TextEditingController();
  String? _selectedMedicineId;
  DateTime _mfgDate = DateTime.now();
  DateTime _expDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;

  void _save() async {
    if (!_formKey.currentState!.validate() || _selectedMedicineId == null) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final repo = ref.read(manufacturerRepositoryProvider);
      final identifiers = _identifiersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      
      final batch = BatchModel(
        batchId: '',
        medicineId: _selectedMedicineId!,
        manufacturerId: user.uid,
        batchNumber: _batchCtrl.text.trim(),
        manufacturingDate: _mfgDate,
        expiryDate: _expDate,
        status: 'active',
        identifiers: identifiers,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.addBatch(batch);
      if (mounted) context.go('/manufacturer/batches');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Batch'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/manufacturer/batches')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  medicinesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_,__) => const Text('Error loading medicines'),
                    data: (medicines) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Medicine'),
                      items: medicines.map((m) => DropdownMenuItem(value: m.medicineId, child: Text(m.medicineName))).toList(),
                      onChanged: (v) => setState(() => _selectedMedicineId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _batchCtrl, 
                    decoration: const InputDecoration(labelText: 'Batch Number'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _mfgDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (d != null) setState(() => _mfgDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Mfg Date'),
                            child: Text(DateFormat.yMMMd().format(_mfgDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: _expDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                            if (d != null) setState(() => _expDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Expiry Date'),
                            child: Text(DateFormat.yMMMd().format(_expDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _identifiersCtrl, 
                    decoration: const InputDecoration(labelText: 'Identifiers (comma separated)'),
                  ),
                  const SizedBox(height: 32),
                  _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Save Batch', onPressed: _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''',
    'features/manufacturer/packaging_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';

class PackagingScreen extends ConsumerWidget {
  const PackagingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagingAsync = ref.watch(packagingReferencesProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Packaging References', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              PrimaryButton(text: 'Upload Reference', onPressed: () => context.go('/manufacturer/add_packaging')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: packagingAsync.when(
              loading: () => const LoadingState(),
              error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(packagingReferencesProvider)),
              data: (refs) {
                if (refs.isEmpty) {
                  return const EmptyState(message: 'No packaging references found.', icon: Icons.qr_code_outlined);
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemCount: refs.length,
                  itemBuilder: (context, i) {
                    final r = refs[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: (r.frontImageUrl != null && r.frontImageUrl!.isNotEmpty)
                                ? Image.network(r.frontImageUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                                : const Icon(Icons.image, size: 64, color: Colors.grey),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Med ID: ${r.medicineId}', maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
''',
    'features/manufacturer/add_packaging_screen.dart': '''
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/packaging_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddPackagingScreen extends ConsumerStatefulWidget {
  const AddPackagingScreen({super.key});

  @override
  ConsumerState<AddPackagingScreen> createState() => _AddPackagingScreenState();
}

class _AddPackagingScreenState extends ConsumerState<AddPackagingScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMedicineId;
  List<int>? _selectedFileBytes;
  String? _selectedFileName;
  bool _isLoading = false;

  void _pickFile() async {
    setState(() {
      _selectedFileBytes = [1, 2, 3];
      _selectedFileName = 'test_front_image.jpg';
    });
  }

  void _uploadAndSave() async {
    if (!_formKey.currentState!.validate() || _selectedFileName == null || _selectedMedicineId == null) return;
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final cloudinary = ref.read(cloudinaryServiceProvider);
      final repo = ref.read(manufacturerRepositoryProvider);
      
      final uploadResult = await cloudinary.uploadImage(_selectedFileBytes!, _selectedFileName!);
      
      final packRef = PackagingModel(
        referenceId: '',
        medicineId: _selectedMedicineId!,
        manufacturerId: user.uid,
        frontImageUrl: uploadResult['secure_url'],
        otherImageUrls: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await repo.addPackagingReference(packRef);
      if (mounted) context.go('/manufacturer/packaging_references');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicinesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Packaging Reference'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/manufacturer/packaging_references')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  medicinesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_,__) => const Text('Error loading medicines'),
                    data: (medicines) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Medicine'),
                      items: medicines.map((m) => DropdownMenuItem(value: m.medicineId, child: Text(m.medicineName))).toList(),
                      onChanged: (v) => setState(() => _selectedMedicineId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.image),
                    label: Text(_selectedFileName != null ? _selectedFileName! : 'Select Front Image'),
                  ),
                  const SizedBox(height: 32),
                  _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Upload and Save', onPressed: _uploadAndSave),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''
}

for filepath, content in files.items():
    full_path = os.path.join(base_path, filepath)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + '\\n')

print("Files generated for Module 4")
