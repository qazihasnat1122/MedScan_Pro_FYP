import os

def create_files(base_path, file_map):
    for filepath, content in file_map.items():
        full_path = os.path.join(base_path, filepath)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content.strip() + '\n')

def append_to_file(filepath, content):
    with open(filepath, 'a', encoding='utf-8') as f:
        f.write('\n' + content.strip() + '\n')

def replace_in_file(filepath, search, replace):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content.replace(search, replace))

web_base = r"d:\medscan\MedScanPro\medscan_web\lib"

files = {
    # MODELS
    "models/product_model.dart": """
class ProductModel {
  final String id;
  final String manufacturerId;
  final String name;
  final String description;
  final String sku;
  final String status;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.manufacturerId,
    required this.name,
    required this.description,
    required this.sku,
    required this.status,
    required this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> data, String id) {
    return ProductModel(
      id: id,
      manufacturerId: data['manufacturerId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      sku: data['sku'] ?? '',
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturerId': manufacturerId,
      'name': name,
      'description': description,
      'sku': sku,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
""",
    "models/batch_model.dart": """
class BatchModel {
  final String id;
  final String manufacturerId;
  final String productId;
  final String batchNumber;
  final DateTime manufactureDate;
  final DateTime expiryDate;
  final int quantity;
  final String status;

  BatchModel({
    required this.id,
    required this.manufacturerId,
    required this.productId,
    required this.batchNumber,
    required this.manufactureDate,
    required this.expiryDate,
    required this.quantity,
    required this.status,
  });

  factory BatchModel.fromMap(Map<String, dynamic> data, String id) {
    return BatchModel(
      id: id,
      manufacturerId: data['manufacturerId'] ?? '',
      productId: data['productId'] ?? '',
      batchNumber: data['batchNumber'] ?? '',
      manufactureDate: data['manufactureDate'] != null ? DateTime.parse(data['manufactureDate'].toString()) : DateTime.now(),
      expiryDate: data['expiryDate'] != null ? DateTime.parse(data['expiryDate'].toString()) : DateTime.now(),
      quantity: data['quantity'] ?? 0,
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturerId': manufacturerId,
      'productId': productId,
      'batchNumber': batchNumber,
      'manufactureDate': manufactureDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'quantity': quantity,
      'status': status,
    };
  }
}
""",
    "models/packaging_reference.dart": """
class PackagingReference {
  final String id;
  final String manufacturerId;
  final String productId;
  final String imageUrl;
  final String publicId;
  final String description;
  final DateTime createdAt;

  PackagingReference({
    required this.id,
    required this.manufacturerId,
    required this.productId,
    required this.imageUrl,
    required this.publicId,
    required this.description,
    required this.createdAt,
  });

  factory PackagingReference.fromMap(Map<String, dynamic> data, String id) {
    return PackagingReference(
      id: id,
      manufacturerId: data['manufacturerId'] ?? '',
      productId: data['productId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      publicId: data['publicId'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'manufacturerId': manufacturerId,
      'productId': productId,
      'imageUrl': imageUrl,
      'publicId': publicId,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
""",
    # SERVICES
    "services/cloudinary_service.dart": """
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class CloudinaryService {
  // Hardcoded for direct upload to Cloudinary.
  // The cloudName and uploadPreset should ideally come from environment variables.
  // We use placeholder values here to indicate configuration is needed.
  final String cloudName = 'REPLACE_WITH_CLOUD_NAME';
  final String uploadPreset = 'REPLACE_WITH_UPLOAD_PRESET';

  Future<Map<String, dynamic>> uploadImage(PlatformFile file) async {
    if (cloudName == 'REPLACE_WITH_CLOUD_NAME' || uploadPreset == 'REPLACE_WITH_UPLOAD_PRESET') {
      throw Exception('Cloudinary is not configured. Please update CloudinaryService.');
    }
    
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);
    
    request.fields['upload_preset'] = uploadPreset;
    
    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
    } else {
      throw Exception('File bytes are null');
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to upload image: $responseBody');
    }
  }
}
""",
    # REPOSITORIES
    "repositories/manufacturer_repository.dart": """
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_reference.dart';

class ManufacturerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addProduct(ProductModel product) async {
    await _firestore.collection('products').add(product.toMap());
  }

  Stream<List<ProductModel>> getProducts(String manufacturerId) {
    return _firestore
        .collection('products')
        .where('manufacturerId', isEqualTo: manufacturerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ProductModel.fromMap(doc.data(), doc.id)).toList());
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

  Future<void> addPackagingReference(PackagingReference ref) async {
    await _firestore.collection('packagingReferences').add(ref.toMap());
  }

  Stream<List<PackagingReference>> getPackagingReferences(String manufacturerId) {
    return _firestore
        .collection('packagingReferences')
        .where('manufacturerId', isEqualTo: manufacturerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PackagingReference.fromMap(doc.data(), doc.id)).toList());
  }
}
""",
    # PROVIDERS
    "providers/manufacturer_providers.dart": """
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/manufacturer_repository.dart';
import '../services/cloudinary_service.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/packaging_reference.dart';
import 'auth_providers.dart';

final manufacturerRepositoryProvider = Provider<ManufacturerRepository>((ref) => ManufacturerRepository());
final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());

final productsProvider = StreamProvider<List<ProductModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getProducts(user.uid);
});

final batchesProvider = StreamProvider<List<BatchModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getBatches(user.uid);
});

final packagingReferencesProvider = StreamProvider<List<PackagingReference>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(manufacturerRepositoryProvider).getPackagingReferences(user.uid);
});
""",
    # SCREENS
    "features/manufacturer/dashboard_screen.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/dashboard_card.dart';

class ManufacturerDashboard extends ConsumerWidget {
  const ManufacturerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
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
                title: 'Total Products', 
                value: products.when(data: (d) => d.length.toString(), loading: () => '...', error: (_,__) => '0'), 
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
""",
    "features/manufacturer/products_screen.dart": """
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
    final productsAsync = ref.watch(productsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Products', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              PrimaryButton(text: 'Add Product', onPressed: () => context.go('/manufacturer/add_product')),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingState(),
              error: (e, st) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(productsProvider)),
              data: (products) {
                if (products.isEmpty) {
                  return const EmptyState(message: 'No products found. Add your first product.', icon: Icons.inventory_2_outlined);
                }
                return DataTableWrapper(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Created At')),
                  ],
                  rows: products.map((p) => DataRow(cells: [
                    DataCell(Text(p.name)),
                    DataCell(Text(p.sku)),
                    DataCell(Text(p.status)),
                    DataCell(Text(DateFormat.yMMMd().format(p.createdAt))),
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
""",
    "features/manufacturer/add_product_screen.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/product_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  void _save() async {
    if (_nameCtrl.text.isEmpty || _skuCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final repo = ref.read(manufacturerRepositoryProvider);
      final product = ProductModel(
        id: '',
        manufacturerId: user.uid,
        name: _nameCtrl.text.trim(),
        sku: _skuCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        status: 'active',
        createdAt: DateTime.now(),
      );
      await repo.addProduct(product);
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
        title: const Text('Add Product'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/manufacturer/products')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
                const SizedBox(height: 16),
                TextField(controller: _skuCtrl, decoration: const InputDecoration(labelText: 'SKU')),
                const SizedBox(height: 16),
                TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                const SizedBox(height: 32),
                _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Save Product', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
""",
    "features/manufacturer/batches_screen.dart": """
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
                    DataColumn(label: Text('Product ID')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Expiry')),
                  ],
                  rows: batches.map((b) => DataRow(cells: [
                    DataCell(Text(b.batchNumber)),
                    DataCell(Text(b.productId)),
                    DataCell(Text(b.quantity.toString())),
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
""",
    "features/manufacturer/add_batch_screen.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/batch_model.dart';
import '../../shared/widgets/primary_button.dart';

class AddBatchScreen extends ConsumerStatefulWidget {
  const AddBatchScreen({super.key});

  @override
  ConsumerState<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends ConsumerState<AddBatchScreen> {
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String? _selectedProductId;
  bool _isLoading = false;

  void _save() async {
    if (_batchCtrl.text.isEmpty || _selectedProductId == null || _qtyCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final repo = ref.read(manufacturerRepositoryProvider);
      final batch = BatchModel(
        id: '',
        manufacturerId: user.uid,
        productId: _selectedProductId!,
        batchNumber: _batchCtrl.text.trim(),
        manufactureDate: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 365)),
        quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        status: 'active',
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
    final productsAsync = ref.watch(productsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Batch'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/manufacturer/batches')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                productsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_,__) => const Text('Error loading products'),
                  data: (products) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Product'),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: _batchCtrl, decoration: const InputDecoration(labelText: 'Batch Number')),
                const SizedBox(height: 16),
                TextField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                const SizedBox(height: 32),
                _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Save Batch', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
""",
    "features/manufacturer/packaging_screen.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/manufacturer_providers.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/loading_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:intl/intl.dart';

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
                          Expanded(child: Image.network(r.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
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
""",
    "features/manufacturer/add_packaging_screen.dart": """
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/manufacturer_providers.dart';
import '../../providers/auth_providers.dart';
import '../../models/packaging_reference.dart';
import '../../shared/widgets/primary_button.dart';

class AddPackagingScreen extends ConsumerStatefulWidget {
  const AddPackagingScreen({super.key});

  @override
  ConsumerState<AddPackagingScreen> createState() => _AddPackagingScreenState();
}

class _AddPackagingScreenState extends ConsumerState<AddPackagingScreen> {
  final _descCtrl = TextEditingController();
  String? _selectedProductId;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  void _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  void _uploadAndSave() async {
    if (_selectedFile == null || _selectedProductId == null) return;
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final cloudinary = ref.read(cloudinaryServiceProvider);
      final repo = ref.read(manufacturerRepositoryProvider);
      
      final uploadResult = await cloudinary.uploadImage(_selectedFile!);
      
      final packRef = PackagingReference(
        id: '',
        manufacturerId: user.uid,
        productId: _selectedProductId!,
        imageUrl: uploadResult['secure_url'],
        publicId: uploadResult['public_id'],
        description: _descCtrl.text.trim(),
        createdAt: DateTime.now(),
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
    final productsAsync = ref.watch(productsProvider);
    
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                productsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_,__) => const Text('Error loading products'),
                  data: (products) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Product'),
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                    onChanged: (v) => setState(() => _selectedProductId = v),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.image),
                  label: Text(_selectedFile != null ? _selectedFile!.name : 'Select Image File'),
                ),
                const SizedBox(height: 32),
                _isLoading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(text: 'Upload and Save', onPressed: _uploadAndSave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
""",
    # SIMPLE PLACEHOLDERS
    "features/manufacturer/simple_screens.dart": """
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(title, style: const TextStyle(fontSize: 24)));
  }
}
"""
}

create_files(web_base, files)
print("Files generated for Module 3")
