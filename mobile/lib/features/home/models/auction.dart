import 'package:equatable/equatable.dart';

class Auction extends Equatable {
  const Auction({
    required this.id,
    required this.productName,
    required this.category,
    required this.basePrice,
    required this.minimumIncrement,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.sellerAlias,
    this.brand,
    this.imageUrl,
    this.currentLeaderAmount,
  });

  final int id;
  final String productName;
  final String category;
  final String? brand;
  final String? imageUrl;
  final num basePrice;
  final num minimumIncrement;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final num? currentLeaderAmount;
  final String sellerAlias;

  factory Auction.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    return Auction(
      id: json['id'] as int,
      productName: product['name'] as String,
      category: product['category'] as String,
      brand: product['brand'] as String?,
      imageUrl: product['image_url'] as String?,
      basePrice: _parseNumber(json['base_price']),
      minimumIncrement: _parseNumber(json['minimum_increment']),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      currentLeaderAmount: json['current_leader_amount'] == null
          ? null
          : _parseNumber(json['current_leader_amount']),
      sellerAlias: json['seller_alias'] as String,
    );
  }

  @override
  List<Object?> get props => [
    id, productName, category, brand, imageUrl, basePrice,
    minimumIncrement, startDate, endDate, status, currentLeaderAmount,
    sellerAlias,
  ];
}

num _parseNumber(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.parse(value);
  throw FormatException('Monto de subasta inválido: $value');
}

class AuctionPage {
  const AuctionPage({required this.items, required this.limit, required this.offset});
  final List<Auction> items;
  final int limit;
  final int offset;

  factory AuctionPage.fromJson(Map<String, dynamic> json) => AuctionPage(
    items: (json['items'] as List<dynamic>)
        .map((item) => Auction.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    limit: json['limit'] as int,
    offset: json['offset'] as int,
  );
}
