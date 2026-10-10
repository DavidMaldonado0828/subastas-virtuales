import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AdminAuctionBidPage, AdminAuctionDetail, AdminAuctionPage, AdminCategory, AdminCategoryCreate, AdminCategoryPatch, AdminCategoryStatusUpdate, AdminUserPage, AuctionCancellationResponse, AuctionCancelRequest, UserStatusUpdate, AdminUserStatusResponse } from '../models/admin.model';
import { AuctionStatus } from '../models/auctions.model';

@Injectable({ providedIn: 'root' })
export class AdminService {
  constructor(private readonly http: HttpClient) {}

  /** Consulta subastas administrativas con paginación y estado opcional. */
  auctions(limit: number, offset: number, status?: AuctionStatus): Observable<AdminAuctionPage> {
    let params = new HttpParams().set('limit', limit).set('offset', offset);
    if (status) params = params.set('status', status);
    return this.http.get<AdminAuctionPage>(`${environment.apiUrl}/admin/auctions`, { params });
  }

  /** Busca usuarios por alias o email; el servidor conserva privacidad de sus datos. */
  users(limit: number, offset: number, search?: string): Observable<AdminUserPage> {
    let params = new HttpParams().set('limit', limit).set('offset', offset);
    if (search) params = params.set('search', search);
    return this.http.get<AdminUserPage>(`${environment.apiUrl}/admin/users`, { params });
  }

  updateUserStatus(id: number, payload: UserStatusUpdate): Observable<AdminUserStatusResponse> {
    return this.http.patch<AdminUserStatusResponse>(`${environment.apiUrl}/admin/users/${id}/status`, payload);
  }

  cancelAuction(id: number, payload: AuctionCancelRequest): Observable<AuctionCancellationResponse> {
    return this.http.post<AuctionCancellationResponse>(`${environment.apiUrl}/admin/auctions/${id}/cancel`, payload);
  }

  /** Consulta los datos completos de una subasta para administración. */
  auctionDetail(id: number): Observable<AdminAuctionDetail> {
    return this.http.get<AdminAuctionDetail>(`${environment.apiUrl}/admin/auctions/${id}`);
  }

  /** Consulta las pujas administrativas en páginas. */
  auctionBids(id: number, limit: number, offset: number): Observable<AdminAuctionBidPage> {
    const params = new HttpParams().set('limit', limit).set('offset', offset);
    return this.http.get<AdminAuctionBidPage>(`${environment.apiUrl}/admin/auctions/${id}/bids`, { params });
  }

  /** Lista todas las categorías, incluidas las desactivadas. */
  categories(): Observable<AdminCategory[]> {
    return this.http.get<AdminCategory[]>(`${environment.apiUrl}/admin/categories`);
  }

  createCategory(payload: AdminCategoryCreate): Observable<AdminCategory> {
    return this.http.post<AdminCategory>(`${environment.apiUrl}/admin/categories`, payload);
  }

  updateCategory(id: number, payload: AdminCategoryPatch): Observable<AdminCategory> {
    return this.http.patch<AdminCategory>(`${environment.apiUrl}/admin/categories/${id}`, payload);
  }

  updateCategoryStatus(id: number, payload: AdminCategoryStatusUpdate): Observable<{ id: number; status: string }> {
    return this.http.patch<{ id: number; status: string }>(`${environment.apiUrl}/admin/categories/${id}/status`, payload);
  }
}
