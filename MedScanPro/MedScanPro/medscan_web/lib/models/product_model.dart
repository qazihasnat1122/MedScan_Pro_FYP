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
