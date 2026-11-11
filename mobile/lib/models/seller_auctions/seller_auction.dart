import 'package:equatable/equatable.dart';

class SellerAuction extends Equatable {
  const SellerAuction({
    required this.id,
    required this.productId,
    required this.productName,
    required this.category,
    required this.basePrice,
    required this.minimumIncrement,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.bidCount,
    this.cancellationReason,
    this.cancelledAt,
  });
  final int id, productId, bidCount;
  final String productName, category, status;
  final num basePrice, minimumIncrement;
  final DateTime startDate, endDate;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  factory SellerAuction.fromJson(Map<String, dynamic> json) {
    final product = Map<String, dynamic>.from(json['product'] as Map);
    final cancellation = json['cancellation'] == null
        ? null
        : Map<String, dynamic>.from(json['cancellation'] as Map);
    return SellerAuction(
      id: json['auction_id'] as int,
      productId: product['product_id'] as int,
      productName: product['name'] as String,
      category: product['category'] as String,
      basePrice: _number(json['base_price']),
      minimumIncrement: _number(json['minimum_increment']),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      bidCount: json['bid_count'] as int,
      cancellationReason: cancellation?['reason'] as String?,
      cancelledAt: cancellation?['cancelled_at'] == null
          ? null
          : DateTime.parse(cancellation!['cancelled_at'] as String),
    );
  }
  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    category,
    basePrice,
    minimumIncrement,
    startDate,
    endDate,
    status,
    bidCount,
    cancellationReason,
    cancelledAt,
  ];
}

class SellerAuctionPage {
  const SellerAuctionPage({
    required this.items,
    required this.limit,
    required this.offset,
    required this.total,
  });
  final List<SellerAuction> items;
  final int limit, offset, total;
  factory SellerAuctionPage.fromJson(Map<String, dynamic> json) =>
      SellerAuctionPage(
        items: (json['items'] as List<dynamic>)
            .map(
              (raw) =>
                  SellerAuction.fromJson(Map<String, dynamic>.from(raw as Map)),
            )
            .toList(growable: false),
        limit: json['limit'] as int,
        offset: json['offset'] as int,
        total: json['total'] as int,
      );
}

class SellerBid extends Equatable {
  const SellerBid({
    required this.alias,
    required this.amount,
    required this.date,
  });
  final String alias;
  final num amount;
  final DateTime date;
  factory SellerBid.fromJson(Map<String, dynamic> json) => SellerBid(
    alias: json['bidder_alias'] as String,
    amount: _number(json['amount']),
    date: DateTime.parse(json['bid_date'] as String),
  );
  @override
  List<Object?> get props => [alias, amount, date];
}

class SellerBidPage {
  const SellerBidPage({
    required this.items,
    required this.limit,
    required this.offset,
  });
  final List<SellerBid> items;
  final int limit, offset;
  factory SellerBidPage.fromJson(Map<String, dynamic> json) => SellerBidPage(
    items: (json['items'] as List<dynamic>)
        .map((raw) => SellerBid.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(growable: false),
    limit: json['limit'] as int,
    offset: json['offset'] as int,
  );
}

num _number(dynamic value) =>
    value is num ? value : num.parse(value.toString());
