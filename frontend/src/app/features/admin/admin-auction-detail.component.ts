import { Component, inject, OnInit, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatTableModule } from '@angular/material/table';
import { finalize } from 'rxjs';
import { AdminAuctionBidItem, AdminAuctionDetail } from '../../core/models/admin.model';
import { AdminService } from '../../core/services/admin.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CopPipe } from '../../shared/pipes/cop.pipe';
import { CancelAuctionDialogComponent } from './cancel-auction-dialog.component';

@Component({
  selector: 'app-admin-auction-detail', standalone: true,
  imports: [RouterLink, MatButtonModule, MatDialogModule, MatTableModule, AuctionStatusBadgeComponent, CopPipe],
  template: `
    <main class="admin-page">
      <header class="heading"><div><h1>Detalle de subasta</h1><p>Información administrativa completa de la subasta.</p></div>
        <div class="heading-actions"><a mat-button class="table-action" routerLink="/admin/subastas">Volver a subastas</a>
          @if (detail(); as auction) { @if (canCancel(auction)) { <button mat-button class="table-action action-danger" type="button" [disabled]="busy()" (click)="cancel()">Cancelar</button> } }
        </div>
      </header>
      @if (loading()) { <p role="status">Cargando detalle…</p> }
      @else if (detail(); as auction) {
        <section class="card">
          <div class="section-heading"><h2>{{ auction.product.name }}</h2><app-auction-status-badge [status]="auction.status" /></div>
          <p><strong>Marca:</strong> {{ auction.product.brand || '—' }} · <strong>Categoría:</strong> {{ auction.product.category }}</p>
          <p><strong>Descripción:</strong> {{ auction.product.description }}</p>
          <h3>Vendedor</h3>
          <dl class="details"><div><dt>Alias</dt><dd>{{ auction.seller.alias }}</dd></div><div><dt>Nombre</dt><dd>{{ auction.seller.name }}</dd></div>
            <div><dt>Correo</dt><dd><a [href]="'mailto:' + auction.seller.email">{{ auction.seller.email }}</a></dd></div><div><dt>Teléfono</dt><dd>{{ auction.seller.phone_number }}</dd></div></dl>
        </section>
        <section class="card"><h2>Subasta</h2>
          <dl class="details"><div><dt>Precio base</dt><dd>{{ auction.base_price | cop }}</dd></div><div><dt>Incremento mínimo</dt><dd>{{ auction.minimum_increment | cop }}</dd></div>
            <div><dt>Inicio</dt><dd class="date-line">{{ formatDate(auction.start_date) }}</dd></div><div><dt>Cierre</dt><dd class="date-line">{{ formatDate(auction.end_date) }}</dd></div>
            <div><dt>Cantidad de pujas</dt><dd>{{ auction.bid_count }}</dd></div><div><dt>Líder</dt><dd>@if (auction.leader_bid; as leader) { {{ leader.bidder_alias }} · {{ leader.amount | cop }} } @else { Sin pujas }</dd></div>
            @if (auction.winner; as winner) { <div><dt>Ganador</dt><dd>{{ winner.alias }} · {{ winner.amount | cop }}</dd></div> }
          </dl>
        </section>
        @if (auction.cancellation; as cancellation) {
          <section class="card cancellation"><h2>Cancelación</h2><p><strong>Motivo:</strong> {{ cancellation.reason }}</p>
            <p><strong>Fecha:</strong> {{ formatDate(cancellation.cancelled_at) }}</p><p><strong>Administrador:</strong> {{ cancellation.admin_alias }}</p>
          </section>
        }
        <section class="card"><h2>Historial de estados</h2>
          @if (auction.status_history.length === 0) { <p>No hay cambios de estado registrados.</p> }
          @else { <div class="table-scroll"><table mat-table [dataSource]="auction.status_history">
            <ng-container matColumnDef="old"><th mat-header-cell *matHeaderCellDef>Anterior</th><td mat-cell *matCellDef="let event">{{ event.old_status_code || '—' }}</td></ng-container>
            <ng-container matColumnDef="new"><th mat-header-cell *matHeaderCellDef>Nuevo</th><td mat-cell *matCellDef="let event">{{ event.new_status_code }}</td></ng-container>
            <ng-container matColumnDef="source"><th mat-header-cell *matHeaderCellDef>Origen</th><td mat-cell *matCellDef="let event">{{ event.event_source }}</td></ng-container>
            <ng-container matColumnDef="who"><th mat-header-cell *matHeaderCellDef>Quién</th><td mat-cell *matCellDef="let event">{{ event.changed_by_alias || 'Sistema' }}</td></ng-container>
            <ng-container matColumnDef="date"><th mat-header-cell *matHeaderCellDef>Fecha</th><td mat-cell *matCellDef="let event">{{ formatDate(event.changed_at) }}</td></ng-container>
            <tr mat-header-row *matHeaderRowDef="historyColumns"></tr><tr mat-row *matRowDef="let row; columns: historyColumns"></tr>
          </table></div> }
        </section>
        <section class="card"><div class="section-heading"><h2>Pujas</h2><span>{{ bidTotal() }} en total</span></div>
          @if (bidsLoading()) { <p role="status">Cargando pujas…</p> }
          @else if (bids().length === 0) { <p>No hay pujas registradas.</p> }
          @else { <div class="table-scroll"><table mat-table [dataSource]="bids()">
            <ng-container matColumnDef="alias"><th mat-header-cell *matHeaderCellDef>Alias</th><td mat-cell *matCellDef="let bid">{{ bid.bidder_alias }}</td></ng-container>
            <ng-container matColumnDef="name"><th mat-header-cell *matHeaderCellDef>Nombre</th><td mat-cell *matCellDef="let bid">{{ bid.bidder_name }}</td></ng-container>
            <ng-container matColumnDef="email"><th mat-header-cell *matHeaderCellDef>Correo</th><td mat-cell *matCellDef="let bid">{{ bid.bidder_email }}</td></ng-container>
            <ng-container matColumnDef="phone"><th mat-header-cell *matHeaderCellDef>Teléfono</th><td mat-cell *matCellDef="let bid">{{ bid.bidder_phone_number }}</td></ng-container>
            <ng-container matColumnDef="amount"><th mat-header-cell *matHeaderCellDef>Monto</th><td mat-cell *matCellDef="let bid">{{ bid.amount | cop }}</td></ng-container>
            <ng-container matColumnDef="date"><th mat-header-cell *matHeaderCellDef>Fecha</th><td mat-cell *matCellDef="let bid">{{ formatDate(bid.bid_date) }}</td></ng-container>
            <tr mat-header-row *matHeaderRowDef="bidColumns"></tr><tr mat-row *matRowDef="let row; columns: bidColumns"></tr>
          </table></div>
          <nav class="pagination" aria-label="Paginación de pujas"><button mat-stroked-button [disabled]="bidOffset() === 0 || bidsLoading()" (click)="previousBids()">Anterior</button>
            <span>{{ bidOffset() + 1 }}–{{ bidOffset() + bids().length }} de {{ bidTotal() }}</span>
            <button mat-stroked-button [disabled]="bidOffset() + bids().length >= bidTotal() || bidsLoading()" (click)="nextBids()">Siguiente</button></nav> }
        </section>
      } @else { <p class="empty">No fue posible cargar la subasta.</p> }
    </main>
  `,
  styles: `
    .admin-page { width: min(100% - 32px, 1200px); margin: 30px auto; }.heading,.section-heading { display:flex; justify-content:space-between; align-items:center; gap:16px; }.heading { margin-bottom:22px; }.heading h1,.section-heading h2 { margin:0; }.heading p { color:#667085; }.heading-actions { display:flex; gap:10px; flex-wrap:wrap; }.card { margin:16px 0; padding:20px; border:1px solid var(--border); border-radius:10px; background:#fff; }.card h2 { margin-top:0; }.card h3 { margin-bottom:8px; }.details { display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:14px 20px; margin:14px 0 0; }.details dt { color:#667085; font-size:.9rem; }.details dd { margin:4px 0 0; overflow-wrap:anywhere; }.details dd.date-line { white-space:nowrap; }.cancellation { border-color:#f0b8a5; }.table-scroll { overflow-x:auto; border:1px solid var(--border); }table { width:100%; min-width:760px; }.pagination { display:flex; justify-content:center; align-items:center; gap:16px; margin:20px 0 0; }.empty { padding:24px; text-align:center; }
    @media(max-width:620px) { .heading { align-items:flex-start; flex-direction:column; }.card { padding:14px; } }
  `,
})
export class AdminAuctionDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly admin = inject(AdminService);
  private readonly dialog = inject(MatDialog);
  protected readonly id = Number(this.route.snapshot.paramMap.get('id'));
  protected readonly detail = signal<AdminAuctionDetail | null>(null);
  protected readonly bids = signal<AdminAuctionBidItem[]>([]);
  protected readonly bidTotal = signal(0);
  protected readonly bidOffset = signal(0);
  protected readonly loading = signal(false);
  protected readonly bidsLoading = signal(false);
  protected readonly busy = signal(false);
  protected readonly bidLimit = 10;
  protected readonly historyColumns = ['old', 'new', 'source', 'who', 'date'];
  protected readonly bidColumns = ['alias', 'name', 'email', 'phone', 'amount', 'date'];
  private readonly dateFormatter = new Intl.DateTimeFormat('es-CO', {
    day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit',
  });

  ngOnInit(): void { this.load(); this.loadBids(); }

  protected load(): void {
    this.loading.set(true);
    this.admin.auctionDetail(this.id).pipe(finalize(() => this.loading.set(false))).subscribe({ next: (value) => this.detail.set(value), error: () => this.detail.set(null) });
  }

  protected loadBids(): void {
    this.bidsLoading.set(true);
    this.admin.auctionBids(this.id, this.bidLimit, this.bidOffset()).pipe(finalize(() => this.bidsLoading.set(false))).subscribe({
      next: (page) => { this.bids.set(page.items); this.bidTotal.set(page.total); },
      error: () => { this.bids.set([]); this.bidTotal.set(0); },
    });
  }

  protected canCancel(auction: AdminAuctionDetail): boolean { return auction.status === 'PROGRAMADA' || auction.status === 'ACTIVA'; }
  protected formatDate(value: string): string { return this.dateFormatter.format(new Date(value)); }

  protected cancel(): void {
    const auction = this.detail();
    if (!auction || !this.canCancel(auction)) return;
    this.dialog.open(CancelAuctionDialogComponent).afterClosed().subscribe((reason: string | undefined) => {
      if (!reason) return;
      this.busy.set(true);
      this.admin.cancelAuction(this.id, { reason }).pipe(finalize(() => this.busy.set(false))).subscribe({ next: () => this.load() });
    });
  }

  protected previousBids(): void { this.bidOffset.update((value) => Math.max(0, value - this.bidLimit)); this.loadBids(); }
  protected nextBids(): void { this.bidOffset.update((value) => value + this.bidLimit); this.loadBids(); }
}
