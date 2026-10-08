import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { MyAuctionItem } from '../../core/models/bids.model';
import { AuctionsService } from '../../core/services/auctions.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CopPipe } from '../../shared/pipes/cop.pipe';
import { finalize } from 'rxjs';
import { HttpErrorResponse } from '@angular/common/http';
import { MyAuctionStatus } from '../../core/services/auctions.service';

@Component({
  selector: 'app-my-auctions', standalone: true,
  imports: [RouterLink, MatButtonModule, MatCardModule, MatFormFieldModule, MatSelectModule, AuctionStatusBadgeComponent, CopPipe],
  template: `
    <main class="my-auctions-page">
      <h1>Mis subastas</h1>
      <mat-form-field appearance="outline">
        <mat-label>Estado</mat-label>
        <mat-select [value]="filter()" (selectionChange)="changeFilter($event.value)">
          <mat-option value="TODAS">Todas</mat-option>
          <mat-option value="ACTIVA">Activas</mat-option>
          <mat-option value="CERRADA">Cerradas</mat-option>
        </mat-select>
      </mat-form-field>
      @if (loading()) {
        <p role="status">Cargando tus subastas…</p>
      } @else if (error()) {
        <p class="error-message" role="alert">{{ error() }}</p>
      } @else if (items().length === 0) {
        <p>Aún no has participado en ninguna subasta.</p>
        <a mat-flat-button class="primary-action" routerLink="/subastas">Explorar subastas</a>
      } @else {
        <section class="my-auctions-grid">
          @for (auction of items(); track auction.auction_id) {
            <mat-card>
              <mat-card-content>
                <div class="card-heading">
                  <h2>{{ auction.product_name }}</h2>
                  <app-auction-status-badge [status]="auction.status" />
                </div>
                <p><span>Mi puja más alta</span><strong>{{ auction.my_highest_bid | cop }}</strong></p>
                <p><span>Líder actual</span><strong>{{ auction.leader_amount | cop }}</strong></p>
                @if (auction.status === 'ACTIVA' || auction.status === 'CERRADA' || auction.status === 'CANCELADA') {
                  <span class="result-badge"
                    [class.success-badge]="auction.status === 'ACTIVA' ? auction.is_leader : auction.status === 'CERRADA' && auction.is_leader"
                    [class.loss-badge]="auction.status === 'ACTIVA' ? !auction.is_leader : auction.status === 'CERRADA' && !auction.is_leader"
                    [class.cancelled-badge]="auction.status === 'CANCELADA'">
                    {{ participationLabel(auction.status, auction.is_leader) }}
                  </span>
                }
                @if (auction.status !== 'CANCELADA') {
                  <a mat-stroked-button [routerLink]="['/subastas', auction.auction_id]" [state]="{ returnUrl: '/postor/mis-subastas' }">Ver subasta</a>
                }
              </mat-card-content>
            </mat-card>
          }
        </section>
      }
    </main>
  `,
  styles: `
    .my-auctions-page { width: min(100% - 32px, 1000px); margin: 32px auto; }
    .error-message { color: #b42318; }
    h1 { margin-bottom: 24px; font-size: 2rem; }
    .my-auctions-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; }
    .card-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
    h2 { margin: 0 0 18px; font-size: 1.15rem; }
    p { display: flex; justify-content: space-between; gap: 12px; }
    .result-badge { display: inline-flex; width: fit-content; margin: 4px 0 12px; padding: 5px 10px; border-radius: 999px; font-size: .85rem; font-weight: 600; }
    .success-badge { color: #12643a; background: #dcfce7; }
    .loss-badge { color: #9a3412; background: #ffedd5; }
    .cancelled-badge { color: #475467; background: #eaecf0; }
    @media (max-width: 640px) { .my-auctions-grid { grid-template-columns: 1fr; } }
  `,
})
export class MyAuctionsComponent implements OnInit {
  private readonly auctions = inject(AuctionsService);
  protected readonly items = signal<MyAuctionItem[]>([]);
  protected readonly loading = signal(true);
  protected readonly error = signal('');
  protected readonly filter = signal<'TODAS' | MyAuctionStatus>('TODAS');

  ngOnInit(): void {
    this.load();
  }

  protected changeFilter(value: 'TODAS' | MyAuctionStatus): void {
    this.filter.set(value);
    this.load();
  }

  protected participationLabel(status: MyAuctionItem['status'], isLeader: boolean): string {
    if (status === 'CANCELADA') return 'Cancelada';
    if (status === 'ACTIVA') return isLeader ? 'Vas ganando' : 'Te superaron';
    if (status === 'CERRADA') return isLeader ? 'Ganaste' : 'Perdiste';
    return '';
  }

  private load(): void {
    this.loading.set(true);
    this.error.set('');
    const selected = this.filter();
    const status: MyAuctionStatus | undefined = selected === 'TODAS' ? undefined : selected;
    this.auctions.myAuctions(100, 0, status).pipe(finalize(() => this.loading.set(false))).subscribe({
      next: (page) => this.items.set(page.items),
      error: (error: unknown) => {
        this.items.set([]);
        const detail = error instanceof HttpErrorResponse ? error.error?.detail : null;
        this.error.set(typeof detail === 'string' ? detail : 'No se pudieron cargar tus subastas.');
      },
    });
  }
}
