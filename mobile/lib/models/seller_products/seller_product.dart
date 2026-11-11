import 'package:equatable/equatable.dart';

class SellerProduct extends Equatable {
  const SellerProduct({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.status,
    required this.name,
    required this.description,
    this.brand,
    this.imageUrl,
  });
  final int id, categoryId;
  final String categoryName, status, name, description;
  final String? brand, imageUrl;
  factory SellerProduct.fromJson(Map<String, dynamic> json) => SellerProduct(
    id: json['product_id'] as int,
    categoryId: json['category_id'] as int,
    categoryName: json['category_name'] as String? ?? '',
    status: json['status'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    brand: json['brand'] as String?,
    imageUrl: json['image_url'] as String?,
  );
  @override
  List<Object?> get props => [
    id,
    categoryId,
    categoryName,
    status,
    name,
    description,
    brand,
    imageUrl,
  ];
}

class SellerCategory extends Equatable {
  const SellerCategory({required this.id, required this.name});
  final int id;
  final String name;
  factory SellerCategory.fromJson(Map<String, dynamic> json) => SellerCategory(
    id: json['category_id'] as int,
    name: json['name'] as String,
  );
  @override
  List<Object?> get props => [id, name];
}
