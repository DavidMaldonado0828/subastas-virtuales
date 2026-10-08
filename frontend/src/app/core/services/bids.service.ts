import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { BidCreate, BidHistoryPage, BidResponse } from '../models/bids.model';

@Injectable({ providedIn: 'root' })
export class BidsService {
  constructor(private readonly http: HttpClient) {}

  /** Recupera las cinco pujas públicas más altas de la subasta. */
  history(auctionId: number, limit = 5, offset = 0): Observable<BidHistoryPage> {
    const params = new HttpParams().set('limit', limit).set('offset', offset);
    return this.http.get<BidHistoryPage>(`${environment.apiUrl}/auctions/${auctionId}/bids`, { params });
  }

  /** Envía la puja; la API valida el monto y la concurrencia. */
  place(auctionId: number, payload: BidCreate): Observable<BidResponse> {
    return this.http.post<BidResponse>(`${environment.apiUrl}/auctions/${auctionId}/bids`, payload);
  }
}
