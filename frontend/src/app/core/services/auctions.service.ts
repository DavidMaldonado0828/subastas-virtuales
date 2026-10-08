import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { EMPTY, expand, Observable, reduce } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuctionCatalogPage, AuctionCreate, AuctionPatch, AuctionPublicDetail, AuctionResponse, SellerAuctionPage } from '../models/auctions.model';
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

  /** Lista las subastas del vendedor con paginación. */
  sellerAuctions(limit: number, offset: number): Observable<SellerAuctionPage> {
    const params = new HttpParams().set('limit', limit).set('offset', offset);
    return this.http.get<SellerAuctionPage>(`${environment.apiUrl}/me/seller/auctions`, { params });
  }

  /** Recupera todas las páginas para que la vista del vendedor ordene globalmente por estado. */
  sellerAuctionsAll(limit = 100): Observable<SellerAuctionPage['items']> {
    return this.sellerAuctions(limit, 0).pipe(
      expand((page) => page.items.length > 0 && page.offset + page.items.length < page.total
        ? this.sellerAuctions(limit, page.offset + page.items.length)
        : EMPTY),
      reduce((items, page) => items.concat(page.items), [] as SellerAuctionPage['items']),
    );
  }

  createAuction(payload: AuctionCreate): Observable<AuctionResponse> {
    return this.http.post<AuctionResponse>(`${environment.apiUrl}/auctions`, payload);
  }

  updateAuction(id: number, payload: AuctionPatch): Observable<AuctionResponse> {
    return this.http.patch<AuctionResponse>(`${environment.apiUrl}/auctions/${id}`, payload);
  }
}
