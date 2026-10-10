import { Component, computed, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { finalize, interval } from 'rxjs';
import { AuctionStatus, SellerAuctionItem } from '../../core/models/auctions.model';
import { AuctionsService } from '../../core/services/auctions.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CopPipe } from '../../shared/pipes/cop.pipe';

@Component({
  selector: 'app-seller-auctions', standalone: true,
  imports: [RouterLink, MatButtonModule, MatCardModule, MatFormFieldModule, MatSelectModule, AuctionStatusBadgeComponent, CopPipe],
  template: `
    <main class="seller-page">
      <div class="heading"><div><h1>Mis subastas</h1><p>Consulta y administra tus subastas.</p></div>
        <div class="heading-actions">
          <button mat-stroked-button type="button" [disabled]="loading() || refreshing()" (click)="load(true)">{{ refreshing() ? 'Actualizando…' : 'Actualizar' }}</button>
          <a mat-flat-button class="primary-action" routerLink="/vendedor/subastas/nueva">Nueva subasta</a>
        </div>
      </div>

      @if (loading()) { <p role="status">Cargando subastas…</p> }
      @else {
        <mat-form-field appearance="outline" class="status-filter"><mat-label>Estado</mat-label>
          <mat-select [value]="statusFilter()" (selectionChange)="statusFilter.set($event.value)">
            <mat-option value="TODAS">Todas</mat-option><mat-option value="EN_CURSO">Activas y programadas</mat-option>
            <mat-option value="CERRADAS">Cerradas / finalizadas</mat-option><mat-option value="CANCELADA">Canceladas</mat-option>
          </mat-select>
        </mat-form-field>
        @if (visibleItems().length === 0) { <p class="empty">{{ emptyMessage() }}</p> }
        @else {
              <div class="auction-list">
                @for (auction of visibleItems(); track auction.auction_id) {
                  <mat-card class="auction-row"><mat-card-content>
                    <div class="row-heading"><div><h3>{{ auction.product.name }}</h3><span class="category">{{ auction.product.category }}</span></div>
                      <app-auction-status-badge [status]="auction.status" />
                    </div>
                    @if (countdown(auction); as timer) { <p class="timer">{{ timer.label }} {{ timer.value }}</p> }
                    <div class="facts">
                      <p><span>Precio base</span><strong>{{ auction.base_price | cop }}</strong></p>
                      <p><span>Incremento mínimo</span><strong>{{ auction.minimum_increment | cop }}</strong></p>
                      <p><span>Inicio</span><strong class="date-line">{{ formatDate(auction.start_date) }}</strong></p>
                      <p><span>Cierre</span><strong class="date-line">{{ formatDate(auction.end_date) }}</strong></p>
                      <p><span>Pujas</span><strong>{{ auction.bid_count }}</strong></p>
                    </div>
                    <div class="row-actions">
                      <a mat-button class="table-action" [routerLink]="['/vendedor/subastas', auction.auction_id, 'pujas']">Historial de pujas</a>
                      @if (canEdit(auction)) { <a mat-button class="table-action" [routerLink]="['/vendedor/subastas', auction.auction_id, 'editar']">Editar</a> }
                    </div>
                  </mat-card-content></mat-card>
                }
              </div>
        }
      }
    </main>
  `,
  styles: `
    .seller-page { width: min(100% - 32px, 1000px); margin: 32px auto; }.heading { display: flex; justify-content: space-between; align-items: center; margin-bottom: 22px; }
    .heading-actions { display: flex; gap: 10px; align-items: center; } h1 { margin: 0; }.heading p, .category { color: #667085; }
    .status-filter { width: min(100%, 360px); margin: 4px 0 16px; }.auction-list { display: grid; gap: 14px; }.auction-row h3 { margin: 0 0 6px; font-size: 1.2rem; }
    .row-heading { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }.facts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 4px 20px; margin: 16px 0; }
    .facts p { display: flex; flex-direction: column; gap: 4px; margin: 5px 0; }.facts span { color: #667085; font-size: .88rem; }.date-line { white-space:nowrap; }.row-actions { display: flex; gap: 8px; flex-wrap: wrap; }.timer { margin: 14px 0 0; color: #1a73e8; font-weight: 600; }
    .empty { text-align: center; padding: 30px; color: #667085; }
    @media (max-width: 640px) { .heading { align-items: flex-start; gap: 12px; flex-direction: column; }.heading-actions { flex-wrap: wrap; }.facts { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  `,
})
export class SellerAuctionsComponent implements OnInit {
  private readonly auctions = inject(AuctionsService);
  private readonly destroyRef = inject(DestroyRef);
  protected readonly items = signal<SellerAuctionItem[]>([]);
  protected readonly loading = signal(false);
  protected readonly refreshing = signal(false);
  protected readonly statusFilter = signal<'TODAS' | 'EN_CURSO' | 'CERRADAS' | 'CANCELADA'>('TODAS');
  protected readonly clockNow = signal(Date.now());
  private readonly dateFormatter = new Intl.DateTimeFormat('es-CO', {
    day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
  protected readonly visibleItems = computed(() => this.items().filter((item) => {
    const filter = this.statusFilter();
    if (filter === 'EN_CURSO') return item.status === 'ACTIVA' || item.status === 'PROGRAMADA';
    if (filter === 'CERRADAS') return item.status === 'CERRADA' || item.status === 'FINALIZADA_SIN_GANADOR';
    if (filter === 'CANCELADA') return item.status === 'CANCELADA';
    return true;
  }));
  protected readonly emptyMessage = computed(() => ({
    TODAS: 'Aún no tienes subastas registradas.', EN_CURSO: 'No tienes subastas activas ni programadas.',
    CERRADAS: 'No tienes subastas cerradas o finalizadas.', CANCELADA: 'No tienes subastas canceladas.',
  })[this.statusFilter()]);

  ngOnInit(): void {
    this.load();
    interval(1000).pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => this.clockNow.set(Date.now()));
    interval(30000).pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      if (this.items().some((item) => item.status === 'ACTIVA' || item.status === 'PROGRAMADA')) this.load(true);
    });
  }

  protected load(background = false): void {
    if (this.loading() || this.refreshing()) return;
    background ? this.refreshing.set(true) : this.loading.set(true);
    this.auctions.sellerAuctionsAll().pipe(finalize(() => { this.loading.set(false); this.refreshing.set(false); })).subscribe({
      next: (items) => {
        const priority: Record<AuctionStatus, number> = { ACTIVA: 0, PROGRAMADA: 0, CERRADA: 1, FINALIZADA_SIN_GANADOR: 1, CANCELADA: 2 };
        this.items.set([...items].sort((left, right) => priority[left.status] - priority[right.status]
          || Date.parse(right.start_date) - Date.parse(left.start_date) || right.auction_id - left.auction_id));
      },
      error: () => { if (!background) this.items.set([]); },
    });
  }

  protected canEdit(auction: SellerAuctionItem): boolean {
    return auction.bid_count === 0 && (auction.status === 'PROGRAMADA' || auction.status === 'ACTIVA');
  }

  protected formatDate(value: string): string { return this.dateFormatter.format(new Date(value)); }

  protected countdown(auction: SellerAuctionItem): { label: string; value: string } | null {
    const target = auction.status === 'PROGRAMADA' ? Date.parse(auction.start_date)
      : auction.status === 'ACTIVA' ? Date.parse(auction.end_date) : NaN;
    if (!Number.isFinite(target)) return null;
    const seconds = Math.max(0, Math.floor((target - this.clockNow()) / 1000));
    const hours = Math.floor(seconds / 3600).toString().padStart(2, '0');
    const minutes = Math.floor((seconds % 3600) / 60).toString().padStart(2, '0');
    const remainder = (seconds % 60).toString().padStart(2, '0');
    return { label: auction.status === 'PROGRAMADA' ? 'Inicia en' : 'Cierra en', value: `${hours}:${minutes}:${remainder}` };
  }
}
