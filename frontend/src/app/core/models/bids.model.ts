import { AuctionStatus, MoneyValue } from './auctions.model';

export interface BidCreate { amount: number; }
export interface BidResponse { bid_id: number; auction_id: number; amount: MoneyValue; bid_date: string; is_leader: boolean; }
export interface BidHistoryItem { bidder_alias: string; amount: MoneyValue; bid_date: string; }
export interface BidHistoryPage { items: BidHistoryItem[]; limit: number; offset: number; }
export interface MyAuctionItem {
  auction_id: number; product_name: string; status: AuctionStatus; my_highest_bid: MoneyValue;
  leader_amount: MoneyValue; is_leader: boolean; cancelled_by_admin: boolean;
}
export interface MyAuctionPage { items: MyAuctionItem[]; limit: number; offset: number; }
