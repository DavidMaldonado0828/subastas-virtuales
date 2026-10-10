import { AuctionStatus, PublicProduct } from './auctions.model';
import { UserRole } from './auth.model';

export interface AdminAuctionItem {
  auction_id: number; product: Pick<PublicProduct, 'name' | 'brand' | 'category'>; seller_alias: string;
  base_price: number; minimum_increment: number; start_date: string; end_date: string;
  status: AuctionStatus; bid_count: number; leader_bid: { amount: number; bidder_alias: string } | null;
}
export interface AdminAuctionPage { items: AdminAuctionItem[]; limit: number; offset: number; total: number; }
export interface AdminUserListItem { id: number; alias: string; role: UserRole; status: string; }
export interface AdminUserPage { items: AdminUserListItem[]; limit: number; offset: number; total: number; }
export interface UserStatusUpdate { status: 'BLOQUEADO' | 'ACTIVO'; }
export interface AdminUserStatusResponse { user_id: number; status: string; }
export interface AuctionCancelRequest { reason: string; }
export interface AuctionCancellationResponse { auction_id: number; status: string; reason: string; cancelled_at: string; }

export interface AdminAuctionDetail {
  auction_id: number;
  product: { name: string; brand: string | null; category: string; description: string };
  seller: { alias: string; name: string; email: string; phone_number: string };
  base_price: number | string;
  minimum_increment: number | string;
  start_date: string;
  end_date: string;
  status: AuctionStatus;
  bid_count: number;
  leader_bid: { amount: number | string; bidder_alias: string } | null;
  winner: { alias: string; amount: number | string } | null;
  cancellation: { reason: string; cancelled_at: string; admin_alias: string } | null;
  status_history: Array<{
    old_status_code: string | null; new_status_code: string; event_source: string;
    changed_by_alias: string | null; changed_at: string;
  }>;
}
export interface AdminAuctionBidItem {
  bidder_alias: string; bidder_name: string; bidder_email: string; bidder_phone_number: string;
  amount: number | string; bid_date: string;
}
export interface AdminAuctionBidPage { items: AdminAuctionBidItem[]; limit: number; offset: number; total: number; }
export type AdminCategoryStatus = 'ACTIVA' | 'DESACTIVADA';
export interface AdminCategory { id: number; name: string; description: string; status: AdminCategoryStatus; product_count: number; }
export interface AdminCategoryCreate { name: string; description: string; }
export type AdminCategoryPatch = Partial<AdminCategoryCreate>;
export interface AdminCategoryStatusUpdate { status: AdminCategoryStatus; }
