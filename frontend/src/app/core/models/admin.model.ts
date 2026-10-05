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
