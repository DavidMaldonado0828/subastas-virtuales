import 'package:equatable/equatable.dart';

class BidHistoryItem extends Equatable {
  const BidHistoryItem({
    required this.bidderAlias,
    required this.amount,
    required this.bidDate,
  });

  final String bidderAlias;
  final num amount;
  final DateTime bidDate;

  factory BidHistoryItem.fromJson(Map<String, dynamic> json) => BidHistoryItem(
    bidderAlias: json['bidder_alias'] as String,
    amount: _parseBidAmount(json['amount']),
    bidDate: DateTime.parse(json['bid_date'] as String),
  );

  @override
  List<Object?> get props => [bidderAlias, amount, bidDate];
}

num _parseBidAmount(dynamic value) =>
    value is num ? value : num.parse(value as String);
