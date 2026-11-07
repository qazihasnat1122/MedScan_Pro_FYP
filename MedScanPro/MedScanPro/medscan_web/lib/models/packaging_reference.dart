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
