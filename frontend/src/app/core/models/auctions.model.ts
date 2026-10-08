export type AuctionStatus = 'PROGRAMADA' | 'ACTIVA' | 'CERRADA' | 'FINALIZADA_SIN_GANADOR' | 'CANCELADA';
export type MoneyValue = number | string;
export interface PublicProduct { product_id: number; name: string; brand: string | null; image_url: string | null; category: string; }
export interface LeaderBid { amount: MoneyValue; bidder_alias: string; }
export interface AuctionWinner { alias: string; amount: MoneyValue; }
export interface AuctionCatalogItem {
  id: number; product: PublicProduct; base_price: MoneyValue; minimum_increment: MoneyValue;
  start_date: string; end_date: string; status: AuctionStatus;
  current_leader_amount: MoneyValue | null; seller_alias: string;
}
export interface AuctionCatalogPage { items: AuctionCatalogItem[]; limit: number; offset: number; }
export interface AuctionPublicDetail extends AuctionCatalogItem {
  leader_bid: LeaderBid | null; winner: AuctionWinner | null; remaining_seconds: number;
}
export interface AuctionCreate { product_id: number; base_price: number; minimum_increment: number; start_date: string; end_date: string; }
export type AuctionPatch = Partial<Omit<AuctionCreate, 'product_id'>>;
export interface AuctionResponse {
  auction_id: number; product_id: number; status_id: number; base_price: number; minimum_increment: number;
  start_date: string; end_date: string; created_at: string; updated_at: string | null;
}
export interface SellerAuctionItem {
  auction_id: number; product: PublicProduct; base_price: number; minimum_increment: number;
  start_date: string; end_date: string; status: AuctionStatus; bid_count: number;
}
export interface SellerAuctionPage { items: SellerAuctionItem[]; limit: number; offset: number; total: number; }
