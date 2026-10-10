import { Component, inject, OnInit, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { MatTableModule } from '@angular/material/table';
import { finalize } from 'rxjs';
import { AdminAuctionItem } from '../../core/models/admin.model';
import { AuctionStatus } from '../../core/models/auctions.model';
import { AdminService } from '../../core/services/admin.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CancelAuctionDialogComponent } from './cancel-auction-dialog.component';

@Component({
  selector: 'app-admin-auctions', standalone: true,
  imports: [RouterLink, MatButtonModule, MatDialogModule, MatFormFieldModule, MatSelectModule, MatTableModule, AuctionStatusBadgeComponent],
  template: `
    <main class="admin-page">
      <header class="heading"><div><h1>Subastas</h1><p>Consulta y administra las subastas del sistema.</p></div>
        <button mat-stroked-button type="button" [disabled]="loading()" (click)="load()">Actualizar</button>
      </header>
      <mat-form-field appearance="outline" class="status-filter"><mat-label>Estado</mat-label>
        <mat-select [value]="status() ?? 'TODOS'" (selectionChange)="changeStatus($event.value)">
          <mat-option value="TODOS">Todos</mat-option>
          <mat-option value="PROGRAMADA">Programadas</mat-option><mat-option value="ACTIVA">Activas</mat-option>
          <mat-option value="CERRADA">Cerradas</mat-option><mat-option value="FINALIZADA_SIN_GANADOR">FINALIZADA_SIN_GANADOR</mat-option>
          <mat-option value="CANCELADA">Canceladas</mat-option>
        </mat-select>
      </mat-form-field>
      @if (loading()) { <p role="status">Cargando subastas…</p> }
      @else if (items().length === 0) { <p class="empty">No hay subastas para este filtro.</p> }
      @else {
        <div class="table-scroll"><table mat-table [dataSource]="items()">
          <ng-container matColumnDef="product"><th mat-header-cell *matHeaderCellDef>Producto</th><td mat-cell *matCellDef="let auction">{{ auction.product.name }} <small>{{ auction.product.category }}</small></td></ng-container>
          <ng-container matColumnDef="seller"><th mat-header-cell *matHeaderCellDef>Vendedor</th><td mat-cell *matCellDef="let auction">{{ auction.seller_alias }}</td></ng-container>
          <ng-container matColumnDef="status"><th mat-header-cell *matHeaderCellDef>Estado</th><td mat-cell *matCellDef="let auction"><app-auction-status-badge [status]="auction.status" /></td></ng-container>
          <ng-container matColumnDef="bid_count"><th mat-header-cell *matHeaderCellDef>Pujas</th><td mat-cell *matCellDef="let auction">{{ auction.bid_count }}</td></ng-container>
          <ng-container matColumnDef="start"><th mat-header-cell *matHeaderCellDef>Inicio</th><td mat-cell *matCellDef="let auction"><span class="date-line" [class.emphasis]="auction.status === 'PROGRAMADA'">{{ formatDate(auction.start_date) }}</span></td></ng-container>
          <ng-container matColumnDef="end"><th mat-header-cell *matHeaderCellDef>Cierre</th><td mat-cell *matCellDef="let auction"><span class="date-line" [class.emphasis]="auction.status === 'ACTIVA'">{{ formatDate(auction.end_date) }}</span></td></ng-container>
          <ng-container matColumnDef="actions"><th mat-header-cell *matHeaderCellDef>Acciones</th><td mat-cell *matCellDef="let auction">
            <a mat-button class="table-action" [routerLink]="['/admin/subastas', auction.auction_id]">Ver detalle</a>
            @if (canCancel(auction)) { <button mat-button class="table-action action-danger" type="button" [disabled]="busyId() === auction.auction_id" (click)="openCancel(auction)">Cancelar</button> }
          </td></ng-container>
          <tr mat-header-row *matHeaderRowDef="columns"></tr><tr mat-row *matRowDef="let row; columns: columns"></tr>
        </table></div>
        <nav class="pagination" aria-label="Paginación de subastas"><button mat-stroked-button [disabled]="offset() === 0 || loading()" (click)="previous()">Anterior</button><span>{{ offset() + 1 }}–{{ offset() + items().length }} de {{ total() }}</span><button mat-stroked-button [disabled]="offset() + items().length >= total() || loading()" (click)="next()">Siguiente</button></nav>
      }
    </main>
  `,
  styles: `
    .admin-page { width: min(100% - 32px, 1200px); margin: 30px auto; }.heading { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }.heading h1 { margin: 0; }.heading p, small { color: #667085; }.status-filter { width: min(100%, 340px); }.table-scroll { overflow-x: auto; border: 1px solid var(--border); }table { width: 100%; min-width: 1180px; }td small { display: block; }.mat-column-product { min-width:260px; }.date-line { white-space:nowrap; }.date-line.emphasis { font-weight:700; }.mat-column-actions { width:240px; min-width:240px; }.mat-column-actions th,.mat-column-actions td { white-space:nowrap; }.pagination { display: flex; justify-content: center; align-items: center; gap: 16px; margin: 24px; }.empty { padding: 24px; text-align: center; color: #667085; }
    @media (max-width: 620px) { .heading { align-items: flex-start; flex-direction: column; gap: 12px; } }
  `,
})
export class AdminAuctionsComponent implements OnInit {
  private readonly admin = inject(AdminService);
  private readonly dialog = inject(MatDialog);
  protected readonly pageSize = 20;
  protected readonly columns = ['product', 'seller', 'status', 'bid_count', 'start', 'end', 'actions'];
  private readonly dateFormatter = new Intl.DateTimeFormat('es-CO', {
    day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
  protected readonly items = signal<AdminAuctionItem[]>([]);
  protected readonly status = signal<AuctionStatus | null>(null);
  protected readonly offset = signal(0);
  protected readonly total = signal(0);
  protected readonly loading = signal(false);
  protected readonly busyId = signal<number | null>(null);
  private reloadRequested = false;

  ngOnInit(): void { this.load(); }

  protected load(): void {
    if (this.loading()) { this.reloadRequested = true; return; }
    this.loading.set(true);
    this.admin.auctions(this.pageSize, this.offset(), this.status() ?? undefined).pipe(finalize(() => {
      this.loading.set(false);
      if (this.reloadRequested) { this.reloadRequested = false; this.load(); }
    })).subscribe({
      next: (page) => { this.items.set(page.items); this.total.set(page.total); },
      error: () => { this.items.set([]); this.total.set(0); },
    });
  }

  protected changeStatus(value: string): void {
    this.status.set(value === 'TODOS' ? null : value as AuctionStatus);
    this.offset.set(0);
    this.load();
  }

  protected canCancel(auction: AdminAuctionItem): boolean { return auction.status === 'PROGRAMADA' || auction.status === 'ACTIVA'; }
  protected formatDate(value: string): string { return this.dateFormatter.format(new Date(value)); }
  protected previous(): void { this.offset.update((value) => Math.max(0, value - this.pageSize)); this.load(); }
  protected next(): void { this.offset.update((value) => value + this.pageSize); this.load(); }

  protected openCancel(auction: AdminAuctionItem): void {
    this.dialog.open(CancelAuctionDialogComponent).afterClosed().subscribe((reason: string | undefined) => {
      if (!reason) return;
      this.busyId.set(auction.auction_id);
      this.admin.cancelAuction(auction.auction_id, { reason }).pipe(finalize(() => this.busyId.set(null))).subscribe({ next: () => this.load() });
    });
  }
}
