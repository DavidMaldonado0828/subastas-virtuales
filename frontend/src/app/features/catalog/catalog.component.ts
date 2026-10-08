import { Component, inject, OnInit, signal } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatTabsModule } from '@angular/material/tabs';
import { finalize } from 'rxjs';
import { AuctionCatalogItem } from '../../core/models/auctions.model';
import { AuctionsService } from '../../core/services/auctions.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CopPipe } from '../../shared/pipes/cop.pipe';
import { AuthService } from '../../core/auth/auth.service';
import { MyAuctionItem } from '../../core/models/bids.model';
import { AuctionStatus } from '../../core/models/auctions.model';

@Component({
  selector: 'app-catalog', standalone: true,
  imports: [RouterLink, MatButtonModule, MatCardModule, MatTabsModule, AuctionStatusBadgeComponent, CopPipe],
  template: `
    <main class="catalog-page">
      <h1>Subastas</h1>
      <mat-tab-group [selectedIndex]="tabIndex()" (selectedTabChange)="selectTab($event.index)">
        <mat-tab label="Disponibles"></mat-tab>
        <mat-tab label="Cerradas"></mat-tab>
      </mat-tab-group>
      @if (loading()) {
        <p role="status">Cargando subastas…</p>
      } @else if (error()) {
        <p class="error-message" role="alert">{{ error() }}</p>
        <button mat-stroked-button type="button" (click)="load()">Reintentar</button>
      } @else if (items().length === 0) {
        <p>{{ status() === 'CERRADAS' ? 'No hay subastas cerradas.' : 'No hay subastas activas ni próximas disponibles.' }}</p>
      } @else {
        <section class="auction-grid" aria-label="Catálogo de subastas">
          @for (auction of items(); track auction.id) {
            <mat-card class="auction-card">
              @if (auction.product.image_url) {
                <img mat-card-image [src]="auction.product.image_url" [alt]="auction.product.name" />
              } @else {
                <div class="image-placeholder" aria-hidden="true">Sin imagen</div>
              }
              <mat-card-content>
                <div class="card-topline">
                  <span class="category">{{ auction.product.category }}</span>
                  <app-auction-status-badge [status]="auction.status" />
                </div>
                <h2>{{ auction.product.name }}</h2>
                <p class="brand">{{ auction.product.brand || 'Sin marca' }}</p>
                <p><span class="label">Precio base</span><strong class="price">{{ auction.base_price | cop }}</strong></p>
                <p><span class="label">Líder actual</span><strong>{{ auction.current_leader_amount | cop }}</strong></p>
                @if (auction.status === 'CANCELADA' || ((auction.status === 'ACTIVA' || auction.status === 'CERRADA') && participation()[auction.id] !== undefined)) {
                  <span class="result-badge"
                    [class.success-badge]="auction.status === 'ACTIVA' ? participation()[auction.id] : auction.status === 'CERRADA' && participation()[auction.id]"
                    [class.loss-badge]="auction.status === 'ACTIVA' ? !participation()[auction.id] : auction.status === 'CERRADA' && !participation()[auction.id]"
                    [class.cancelled-badge]="auction.status === 'CANCELADA'">
                    {{ participationLabel(auction.status, participation()[auction.id]) }}
                  </span>
                }
                @if (auction.status !== 'CANCELADA') {
                  <a mat-flat-button class="primary-action view-action" [routerLink]="['/subastas', auction.id]" [state]="{ returnUrl: '/subastas' }">Ver</a>
                }
              </mat-card-content>
            </mat-card>
          }
        </section>
      }

      <nav class="pagination" aria-label="Paginación del catálogo">
        <button mat-stroked-button type="button" [disabled]="offset() === 0 || loading()" (click)="previous()">Anterior</button>
        @if (items().length > 0) { <span>Resultados {{ offset() + 1 }}–{{ offset() + items().length }}</span> }
        <button mat-stroked-button type="button" [disabled]="items().length < pageSize || loading()" (click)="next()">Siguiente</button>
      </nav>
    </main>
  `,
  styles: `
    .catalog-page { width: min(100% - 32px, 1100px); margin: 32px auto; }
    h1 { margin-bottom: 24px; font-size: 2rem; }
    .auction-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 20px; }
    .auction-card { overflow: hidden; }
    .auction-card img, .image-placeholder { height: 190px; object-fit: cover; background: #e5e7eb; }
    .image-placeholder { display: grid; place-items: center; color: #667085; }
    .card-topline { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin: 12px 0; }
    .category, .brand, .label { color: #667085; font-size: .9rem; }
    h2 { margin: 8px 0; font-size: 1.15rem; }
    p { display: flex; justify-content: space-between; gap: 8px; }
    .price { color: var(--accent); }
    .result-badge { display: inline-flex; width: fit-content; margin: 4px 0 8px; padding: 5px 10px; border-radius: 999px; font-size: .85rem; font-weight: 600; }
    .success-badge { color: #12643a; background: #dcfce7; }
    .loss-badge { color: #9a3412; background: #ffedd5; }
    .cancelled-badge { color: #475467; background: #eaecf0; }
    .view-action { width: 100%; margin-top: 8px; }
    .error-message { color: #b42318; }
    .pagination { display: flex; align-items: center; justify-content: center; gap: 18px; margin: 28px 0; }
    @media (max-width: 800px) { .auction-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
    @media (max-width: 560px) { .auction-grid { grid-template-columns: 1fr; } .pagination { gap: 10px; flex-wrap: wrap; } }
  `,
})
export class CatalogComponent implements OnInit {
  private readonly auctions = inject(AuctionsService);
  private readonly auth = inject(AuthService);
  protected readonly pageSize = 12;
  protected readonly items = signal<AuctionCatalogItem[]>([]);
  protected readonly offset = signal(0);
  protected readonly loading = signal(false);
  protected readonly error = signal('');
  protected readonly status = signal<'DISPONIBLES' | 'CERRADAS'>('DISPONIBLES');
  protected readonly tabIndex = signal(0);
  protected readonly participation = signal<Record<number, boolean>>({});

  ngOnInit(): void {
    this.load();
    if (this.auth.user()?.role === 'POSTOR') {
      this.auctions.myAuctions(100, 0).subscribe({
        next: (page) => this.participation.set(Object.fromEntries(page.items.map((item: MyAuctionItem) =>
          [item.auction_id, item.is_leader]))),
      });
    }
  }

  protected selectTab(index: number): void {
    this.tabIndex.set(index);
    this.status.set(index === 1 ? 'CERRADAS' : 'DISPONIBLES');
    this.offset.set(0);
    this.load();
  }

  protected previous(): void {
    this.offset.update((offset) => Math.max(0, offset - this.pageSize));
    this.load();
  }

  protected next(): void {
    this.offset.update((offset) => offset + this.pageSize);
    this.load();
  }

  protected load(): void {
    this.loading.set(true);
    this.error.set('');
    this.auctions.catalog(this.pageSize, this.offset(), this.status() === 'CERRADAS' ? 'CERRADA' : undefined).pipe(
      finalize(() => this.loading.set(false)),
    ).subscribe({
      next: (page) => this.items.set(page.items),
      error: (error: unknown) => {
        this.items.set([]);
        const detail = error instanceof HttpErrorResponse ? error.error?.detail : null;
        this.error.set(typeof detail === 'string' ? detail : 'No se pudieron cargar las subastas. Intenta de nuevo.');
      },
    });
  }

  protected participationLabel(status: AuctionStatus, isLeader: boolean | undefined): string {
    if (status === 'CANCELADA') return 'Cancelada';
    if (status === 'ACTIVA') return isLeader ? 'Vas ganando' : 'Te superaron';
    if (status === 'CERRADA') return isLeader ? 'Ganaste' : 'Perdiste';
    return '';
  }
}
