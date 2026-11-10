import 'package:equatable/equatable.dart';

class MyAuction extends Equatable {
  const MyAuction({
    required this.auctionId,
    required this.productName,
    required this.status,
    required this.myHighestBid,
    required this.leaderAmount,
    required this.isLeader,
    required this.cancelledByAdmin,
  });
  final int auctionId;
  final String productName;
  final String status;
  final num myHighestBid;
  final num? leaderAmount;
  final bool isLeader;
  final bool cancelledByAdmin;

  factory MyAuction.fromJson(Map<String, dynamic> json) => MyAuction(
    auctionId: json['auction_id'] as int,
    productName: json['product_name'] as String,
    status: json['status'] as String,
    myHighestBid: _number(json['my_highest_bid']),
    leaderAmount: json['leader_amount'] == null
        ? null
        : _number(json['leader_amount']),
    isLeader: json['is_leader'] as bool,
    cancelledByAdmin: json['cancelled_by_admin'] as bool? ?? false,
  );
  @override
  List<Object?> get props => [
    auctionId,
    productName,
    status,
    myHighestBid,
    leaderAmount,
    isLeader,
    cancelledByAdmin,
  ];
}

num _number(dynamic value) =>
    value is num ? value : num.parse(value.toString());

class MyAuctionsPage {
  const MyAuctionsPage({
    required this.items,
    required this.limit,
    required this.offset,
  });
  final List<MyAuction> items;
  final int limit;
  final int offset;
  factory MyAuctionsPage.fromJson(Map<String, dynamic> json) => MyAuctionsPage(
    items: (json['items'] as List<dynamic>)
        .map(
          (item) => MyAuction.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    limit: json['limit'] as int,
    offset: json['offset'] as int,
  );
}
