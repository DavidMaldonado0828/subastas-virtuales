import 'package:equatable/equatable.dart';

import '../home/auction.dart';

class AuctionDetail extends Equatable {
  const AuctionDetail({
    required this.auction,
    required this.remainingSeconds,
    this.leaderBid,
    this.winner,
  });

  final Auction auction;
  final int remainingSeconds;
  final LeaderBid? leaderBid;
  final AuctionWinner? winner;

  factory AuctionDetail.fromJson(Map<String, dynamic> json) => AuctionDetail(
    auction: Auction.fromJson(json),
    remainingSeconds: json['remaining_seconds'] as int,
    leaderBid: json['leader_bid'] == null
        ? null
        : LeaderBid.fromJson(json['leader_bid'] as Map<String, dynamic>),
    winner: json['winner'] == null
        ? null
        : AuctionWinner.fromJson(json['winner'] as Map<String, dynamic>),
  );

  @override
  List<Object?> get props => [auction, remainingSeconds, leaderBid, winner];
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
