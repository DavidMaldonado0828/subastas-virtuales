import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuctionCatalogPage, AuctionPublicDetail } from '../models/auctions.model';
import { MyAuctionPage } from '../models/bids.model';

export type CatalogStatus = 'ACTIVA' | 'PROGRAMADA' | 'CERRADA';
export type MyAuctionStatus = 'ACTIVA' | 'CERRADA';

@Injectable({ providedIn: 'root' })
export class AuctionsService {
  constructor(private readonly http: HttpClient) {}

  /** Consulta una página del catálogo público. */
  catalog(limit: number, offset: number, status?: CatalogStatus): Observable<AuctionCatalogPage> {
    let params = new HttpParams().set('limit', limit).set('offset', offset);
    if (status) params = params.set('status', status);
    return this.http.get<AuctionCatalogPage>(`${environment.apiUrl}/auctions`, { params });
  }

  /** Obtiene el detalle público de una subasta. */
  detail(id: number): Observable<AuctionPublicDetail> {
    return this.http.get<AuctionPublicDetail>(`${environment.apiUrl}/auctions/${id}`);
  }

  /** Lista las subastas en las que el participante ha pujado. */
  myAuctions(limit: number, offset: number, status?: MyAuctionStatus): Observable<MyAuctionPage> {
    let params = new HttpParams().set('limit', limit).set('offset', offset);
    if (status) params = params.set('status', status);
    return this.http.get<MyAuctionPage>(`${environment.apiUrl}/me/auctions`, { params });
  }
}
