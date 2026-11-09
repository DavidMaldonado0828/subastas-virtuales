import 'package:equatable/equatable.dart';

import '../home/auction.dart';
import 'bid_minimum.dart';

class AuctionDetail extends Equatable {
  const AuctionDetail({
    required this.auction,
    required this.remainingSeconds,
    this.minimumBid,
    this.leaderBid,
    this.winner,
  });

  final Auction auction;
  final int remainingSeconds;
  final int? minimumBid;
  final LeaderBid? leaderBid;
  final AuctionWinner? winner;

  factory AuctionDetail.fromJson(Map<String, dynamic> json) {
    final minimumBid = calculateBidMinimum(
      basePrice: json['base_price'],
      currentLeaderAmount: json['current_leader_amount'],
      minimumIncrement: json['minimum_increment'],
    );
    final auctionJson = Map<String, dynamic>.from(json);
    for (final key in ['base_price', 'minimum_increment']) {
      auctionJson[key] = _safeNumber(json[key]) ?? 0;
    }
    auctionJson['current_leader_amount'] = json['current_leader_amount'] == null
        ? null
        : _safeNumber(json['current_leader_amount']);
    return AuctionDetail(
      auction: Auction.fromJson(auctionJson),
      remainingSeconds: json['remaining_seconds'] as int,
      minimumBid: minimumBid,
      leaderBid: json['leader_bid'] == null
          ? null
          : LeaderBid.fromJson(json['leader_bid'] as Map<String, dynamic>),
      winner: json['winner'] == null
          ? null
          : AuctionWinner.fromJson(json['winner'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [
    auction,
    remainingSeconds,
    minimumBid,
    leaderBid,
    winner,
  ];
}

class LeaderBid extends Equatable {
  const LeaderBid({required this.amount, required this.bidderAlias});

  final num amount;
  final String bidderAlias;

  factory LeaderBid.fromJson(Map<String, dynamic> json) => LeaderBid(
    amount: _number(json['amount']),
    bidderAlias: json['bidder_alias'] as String,
  );

  @override
  List<Object?> get props => [amount, bidderAlias];
}

class AuctionWinner extends Equatable {
  const AuctionWinner({required this.alias, required this.amount});

  final String alias;
  final num amount;

  factory AuctionWinner.fromJson(Map<String, dynamic> json) => AuctionWinner(
    alias: json['alias'] as String,
    amount: _number(json['amount']),
  );

  @override
  List<Object?> get props => [alias, amount];
}

num _number(dynamic value) => value is num ? value : num.parse(value as String);

num? _safeNumber(Object? value) {
  if (value is num) return value.isFinite ? value : null;
  if (value is String) {
    final parsed = num.tryParse(value);
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}
