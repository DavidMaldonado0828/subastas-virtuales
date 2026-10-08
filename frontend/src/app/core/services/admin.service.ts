import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AdminAuctionPage, AdminUserPage, AuctionCancellationResponse, AuctionCancelRequest, UserStatusUpdate, AdminUserStatusResponse } from '../models/admin.model';
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
}
