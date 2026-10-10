import { DatePipe } from '@angular/common';
import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatTableModule } from '@angular/material/table';
import { forkJoin, finalize } from 'rxjs';
import { SellerAuctionItem } from '../../core/models/auctions.model';
import { BidHistoryItem } from '../../core/models/bids.model';
import { AuctionsService } from '../../core/services/auctions.service';
import { BidsService } from '../../core/services/bids.service';
import { CopPipe } from '../../shared/pipes/cop.pipe';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';

@Component({
  selector: 'app-seller-bid-history', standalone: true,
  imports: [DatePipe, RouterLink, MatButtonModule, MatTableModule, CopPipe, AuctionStatusBadgeComponent],
  template: `
    <main class="history-page">
      <a mat-button routerLink="/vendedor/subastas">← Volver a mis subastas</a>
      <h1>Historial de pujas</h1>
      @if (auction(); as current) {
        <section class="summary" aria-label="Resumen de la subasta">
          <div class="summary-title"><div><h2>{{ current.product.name }}</h2><p>{{ current.product.category }}</p></div><app-auction-status-badge [status]="current.status" /></div>
          <div class="summary-grid">
            <p><span>Precio base</span><strong>{{ current.base_price | cop }}</strong></p>
            <p><span>Incremento mínimo</span><strong>{{ current.minimum_increment | cop }}</strong></p>
            <p><span>Total de pujas</span><strong>{{ current.bid_count }}</strong></p>
            <p><span>Puja más alta</span><strong>{{ highestBid() ? (highestBid()!.amount | cop) : 'Sin pujas' }}</strong></p>
          </div>
          @if (current.status === 'CERRADA') { <p class="result">{{ highestBid() ? 'Ganador: ' + highestBid()!.bidder_alias : 'Subasta cerrada sin pujas.' }} @if (highestBid()) { · {{ highestBid()!.amount | cop }} }</p> }
          @if (current.status === 'FINALIZADA_SIN_GANADOR') { <p class="result">Finalizada sin ganador: no hubo pujas.</p> }
          @if (current.status === 'CANCELADA') {
            @if (current.cancellation; as cancellation) {
              <div class="result cancellation"><p><strong>Motivo de cancelación:</strong> {{ cancellation.reason }}</p>
                <p><strong>Fecha:</strong> {{ cancellation.cancelled_at | date:'medium' }}</p></div>
            } @else { <p class="result">Subasta cancelada. No hay un motivo registrado.</p> }
          }
        </section>
      }
      @if (loading()) { <p role="status">Cargando historial…</p> }
      @else if (items().length === 0) { <p>Esta subasta aún no tiene pujas.</p> }
      @else {
        <div class="table-scroll"><table mat-table [dataSource]="items()">
          <ng-container matColumnDef="number"><th mat-header-cell *matHeaderCellDef>N.º / posición</th><td mat-cell *matCellDef="let bid; let i = index">{{ offset() + i + 1 }}</td></ng-container>
          <ng-container matColumnDef="bidder_alias"><th mat-header-cell *matHeaderCellDef>Participante</th><td mat-cell *matCellDef="let bid">{{ bid.bidder_alias }}</td></ng-container>
          <ng-container matColumnDef="amount"><th mat-header-cell *matHeaderCellDef>Monto</th><td mat-cell *matCellDef="let bid">{{ bid.amount | cop }}</td></ng-container>
          <ng-container matColumnDef="bid_date"><th mat-header-cell *matHeaderCellDef>Fecha local</th><td mat-cell *matCellDef="let bid">{{ bid.bid_date | date:'short' }}</td></ng-container>
          <ng-container matColumnDef="leader"><th mat-header-cell *matHeaderCellDef>Liderazgo</th><td mat-cell *matCellDef="let bid; let i = index">@if (offset() === 0 && i === 0) { <strong class="leader">Líder actual</strong> } @else { — }</td></ng-container>
          <tr mat-header-row *matHeaderRowDef="columns"></tr><tr mat-row *matRowDef="let row; columns: columns"></tr>
        </table></div>
        <nav class="pagination" aria-label="Paginación del historial">
          <button mat-stroked-button type="button" [disabled]="offset() === 0 || loading()" (click)="previous()">Anterior</button>
          <span>{{ offset() + 1 }}–{{ offset() + items().length }}</span>
          <button mat-stroked-button type="button" [disabled]="items().length < pageSize || loading()" (click)="next()">Siguiente</button>
        </nav>
      }
    </main>
  `,
  styles: `
    .history-page { width: min(100% - 32px, 900px); margin: 30px auto; } h1 { margin: 20px 0; }
    .summary { border: 1px solid var(--border); border-radius: 12px; padding: 18px; margin: 18px 0 26px; }.summary-title { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }.summary h2 { margin: 0; }.summary-title p { margin: 5px 0; color: #667085; }
    .summary-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }.summary-grid p { display: flex; flex-direction: column; gap: 5px; }.summary-grid span { color: #667085; font-size: .88rem; }.result { background: #f8fafc; padding: 10px 12px; border-radius: 8px; }.cancellation p { margin:5px 0; }.leader { color: #1a73e8; }
    table { width: 100%; }.table-scroll { overflow-x: auto; border: 1px solid var(--border); }
    .pagination { display: flex; justify-content: center; align-items: center; gap: 16px; margin: 24px; }
    @media (max-width: 640px) { .summary-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  `,
})
export class SellerBidHistoryComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly auctions = inject(AuctionsService);
  private readonly bids = inject(BidsService);
  protected readonly pageSize = 100;
  protected readonly columns = ['number', 'bidder_alias', 'amount', 'bid_date', 'leader'];
  protected readonly auctionId = signal(0);
  protected readonly items = signal<BidHistoryItem[]>([]);
  protected readonly auction = signal<SellerAuctionItem | null>(null);
  protected readonly highestBid = signal<BidHistoryItem | null>(null);
  protected readonly offset = signal(0);
  protected readonly loading = signal(true);

  ngOnInit(): void {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    if (!Number.isInteger(id) || id < 1) return;
    this.auctionId.set(id);
    this.load();
  }

  protected load(): void {
    this.loading.set(true);
    forkJoin({ auctions: this.auctions.sellerAuctionsAll(), bids: this.bids.history(this.auctionId(), this.pageSize, this.offset()) })
      .pipe(finalize(() => this.loading.set(false))).subscribe({
      next: ({ auctions, bids }) => {
        this.auction.set(auctions.find((item) => item.auction_id === this.auctionId()) ?? null);
        this.items.set(bids.items);
        if (this.offset() === 0) this.highestBid.set(bids.items[0] ?? null);
      },
      error: () => { this.items.set([]); this.auction.set(null); this.highestBid.set(null); },
    });
  }

  protected previous(): void { this.offset.update((value) => Math.max(0, value - this.pageSize)); this.load(); }
  protected next(): void { this.offset.update((value) => value + this.pageSize); this.load(); }
}
