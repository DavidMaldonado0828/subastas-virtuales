export interface BidCreate { amount: number; }
export interface BidResponse { bid_id: number; auction_id: number; amount: number; bid_date: string; is_leader: boolean; }
export interface BidHistoryItem { bidder_alias: string; amount: number; bid_date: string; }
export interface BidHistoryPage { items: BidHistoryItem[]; limit: number; offset: number; }
export interface MyAuctionItem {
  auction_id: number; product_name: string; status: string; my_highest_bid: number;
  leader_amount: number; is_leader: boolean;
}
export interface MyAuctionPage { items: MyAuctionItem[]; limit: number; offset: number; }
