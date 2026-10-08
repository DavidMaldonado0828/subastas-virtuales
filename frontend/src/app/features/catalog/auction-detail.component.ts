import { DatePipe } from '@angular/common';
import { Component, DestroyRef, OnInit, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatTableModule } from '@angular/material/table';
import { HttpErrorResponse } from '@angular/common/http';
import { finalize, forkJoin, interval } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { AuctionPublicDetail } from '../../core/models/auctions.model';
import { BidHistoryItem } from '../../core/models/bids.model';
import { ApiErrorService } from '../../core/services/api-error.service';
import { AuctionsService } from '../../core/services/auctions.service';
import { BidsService } from '../../core/services/bids.service';
import { AuctionStatusBadgeComponent } from '../../shared/components/auction-status-badge.component';
import { CopPipe } from '../../shared/pipes/cop.pipe';

@Component({
  selector: 'app-auction-detail', standalone: true,
  imports: [DatePipe, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatTableModule, AuctionStatusBadgeComponent, CopPipe],
  template: `
    <main class="detail-page">
      <button mat-button class="back-link" type="button" (click)="goBack()">← Volver</button>
      <div class="page-heading">
        <h1>Detalle de subasta</h1>
        @if (auction()?.status === 'PROGRAMADA' || auction()?.status === 'ACTIVA') {
          <button mat-stroked-button type="button" [disabled]="loading()" (click)="load()">Actualizar</button>
        }
      </div>

      @if (loading() && !auction()) {
        <p role="status">Cargando detalle…</p>
      } @else if (error()) {
        <p class="error-message" role="alert">{{ error() }}</p>
      } @else if (auction(); as item) {
        <section class="auction-summary">
          @if (item.product.image_url) {
            <img class="product-image" [src]="item.product.image_url" [alt]="item.product.name" />
          }
          <div class="summary-content">
            <p class="category">{{ item.product.category }}</p>
            <h2>{{ item.product.name }}</h2>
            <p>{{ item.product.brand || 'Sin marca' }} · Vendedor: {{ item.seller_alias }}</p>
            <div class="status-row"><app-auction-status-badge [status]="item.status" />
              @if (remainingSeconds() > 0) {
                <span class="timer">{{ item.status === 'PROGRAMADA' ? 'Inicia en' : 'Tiempo restante' }}: {{ countdown() }}</span>
              }
            </div>
            <dl class="price-grid">
              <div><dt>Precio base</dt><dd>{{ item.base_price | cop }}</dd></div>
              <div><dt>Incremento mínimo</dt><dd>{{ item.minimum_increment | cop }}</dd></div>
              <div><dt>Puja líder actual</dt><dd class="leader-price">{{ item.leader_bid?.amount | cop }}</dd></div>
              @if (item.leader_bid) { <div><dt>Alias líder</dt><dd>{{ item.leader_bid.bidder_alias }}</dd></div> }
            </dl>

            @if (item.status === 'CERRADA' && item.winner) {
              <p class="result-message">Ganador: <strong>{{ item.winner.alias }}</strong> con {{ item.winner.amount | cop }}</p>
            } @else if (item.status === 'FINALIZADA_SIN_GANADOR') {
              <p class="result-message">La subasta finalizó sin ganador porque no recibió pujas.</p>
            }

            @if (auth.user()?.role === 'POSTOR' && item.status === 'ACTIVA') {
              @if (isCurrentLeader(item)) {
                <p class="result-message">Vas ganando con {{ item.current_leader_amount | cop }}.</p>
              } @else if (minimumSuggested === null) {
                <p class="error-message" role="alert">No se pudo calcular el mínimo de puja con los datos recibidos.</p>
              } @else {
                <form class="bid-form" [formGroup]="bidForm" (ngSubmit)="placeBid()">
                  <mat-form-field appearance="outline">
                    <mat-label>Ingresa tu puja</mat-label>
                    <input matInput type="number" [min]="minimumSuggested" step="10000" inputmode="numeric" formControlName="amount" />
                    <mat-hint>Mínimo sugerido: {{ minimumSuggested | cop }}</mat-hint>
                    @if (bidForm.controls.amount.touched && bidForm.controls.amount.hasError('pattern')) {
                      <mat-error>Ingresa el monto en pesos enteros, sin centavos.</mat-error>
                    } @else if (bidForm.controls.amount.touched && bidForm.controls.amount.hasError('min')) {
                      <mat-error>La puja debe ser igual o superior al mínimo sugerido.</mat-error>
                    }
                  </mat-form-field>
                  <p class="binding-note">Las pujas son vinculantes y no se pueden retirar.</p>
                  <button mat-flat-button class="primary-action" type="submit" [disabled]="bidForm.invalid || posting()">
                    {{ posting() ? 'Enviando…' : 'Pujar' }}
                  </button>
                </form>
              }
            }
          </div>
        </section>

        <section class="bids-section">
          <h2>Top 5 de pujas</h2>
          @if (bids().length === 0) {
            <p>Aún no hay pujas.</p>
          } @else {
            <div class="table-scroll">
              <table mat-table [dataSource]="bids()" class="bids-table">
                <ng-container matColumnDef="bidder_alias">
                  <th mat-header-cell *matHeaderCellDef>Participante</th>
                  <td mat-cell *matCellDef="let bid">{{ bid.bidder_alias }}</td>
                </ng-container>
                <ng-container matColumnDef="amount">
                  <th mat-header-cell *matHeaderCellDef>Monto</th>
                  <td mat-cell *matCellDef="let bid">{{ bid.amount | cop }}</td>
                </ng-container>
                <ng-container matColumnDef="bid_date">
                  <th mat-header-cell *matHeaderCellDef>Fecha local</th>
                  <td mat-cell *matCellDef="let bid">{{ bid.bid_date | date:'short' }}</td>
                </ng-container>
                <tr mat-header-row *matHeaderRowDef="bidColumns"></tr>
                <tr mat-row *matRowDef="let row; columns: bidColumns"></tr>
              </table>
            </div>
          }
        </section>
      }
    </main>
  `,
  styles: `
      .detail-page { width: min(100% - 32px, 900px); margin: 28px auto 56px; }
    .error-message { color: #b42318; }
    .back-link { color: var(--primary); }
    .page-heading, .status-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; }
    .page-heading { margin: 14px 0 24px; }
    .page-heading h1 { margin: 0; font-size: 2rem; }
    .auction-summary { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.2fr); overflow: hidden; border: 1px solid var(--border); border-radius: 6px; }
    .product-image { width: 100%; height: 100%; min-height: 320px; object-fit: cover; background: #e5e7eb; }
    .summary-content { padding: 24px; }
    .summary-content h2 { margin: 8px 0; font-size: 1.7rem; }
    .category, dt { color: #667085; }
    .status-row { justify-content: flex-start; margin: 20px 0; }
    .timer { padding: 6px 12px; border-radius: 20px; background: #1f2937; color: white; }
    .price-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    dt { font-size: .87rem; } dd { margin: 5px 0 0; font-weight: 600; }
    .leader-price { color: var(--accent); font-size: 1.3rem; }
    .result-message { padding: 12px; border-radius: 4px; background: #f3f4f6; }
    .bid-form { display: grid; gap: 8px; margin-top: 24px; }
    .bid-form mat-form-field { width: 100%; }
    .binding-note { margin: 0 0 8px; color: #667085; font-size: .9rem; }
    .bids-section { margin-top: 32px; }
    .bids-section h2 { font-size: 1.25rem; }
    .table-scroll { overflow-x: auto; }
    .bids-table { width: 100%; border: 1px solid var(--border); }
    @media (max-width: 680px) {
      .auction-summary { grid-template-columns: 1fr; }
      .product-image { min-height: 220px; max-height: 280px; }
      .summary-content { padding: 18px; }
      .page-heading h1 { font-size: 1.6rem; }
    }
  `,
})
export class AuctionDetailComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);
  private readonly auctions = inject(AuctionsService);
  private readonly bidsService = inject(BidsService);
  private readonly fb = inject(FormBuilder);
  private readonly messages = inject(ApiErrorService);
  protected readonly auth = inject(AuthService);
  protected readonly auction = signal<AuctionPublicDetail | null>(null);
  protected readonly bids = signal<BidHistoryItem[]>([]);
  protected readonly bidColumns = ['bidder_alias', 'amount', 'bid_date'];
  protected readonly remainingSeconds = signal(0);
  protected readonly loading = signal(false);
  protected readonly posting = signal(false);
  protected readonly error = signal('');
  protected auctionId = 0;
  protected readonly bidForm = this.fb.nonNullable.group({
    amount: [0, [Validators.required, Validators.min(0.01), Validators.pattern(/^\d+$/)]],
  });

  ngOnInit(): void {
    this.route.paramMap.pipe(takeUntilDestroyed(this.destroyRef)).subscribe((params) => {
      this.auctionId = Number(params.get('id'));
      this.load();
    });
    interval(1000).pipe(takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      this.remainingSeconds.update((seconds) => Math.max(0, seconds - 1));
    });
  }

  protected goBack(): void {
    const returnUrl: unknown = history.state?.returnUrl;
    if (typeof returnUrl === 'string' && returnUrl.startsWith('/') && !returnUrl.startsWith('//')) {
      void this.router.navigateByUrl(returnUrl);
      return;
    }
    void this.router.navigate(['/subastas']);
  }

  protected get minimumSuggested(): number | null {
    const auction = this.auction();
    if (!auction) return null;
    const basePrice = Number(auction.base_price);
    if (auction.current_leader_amount !== null) {
      const leaderAmount = Number(auction.current_leader_amount);
      const increment = Number(auction.minimum_increment);
      if (!Number.isFinite(leaderAmount) || !Number.isFinite(increment)) return null;
      const minimum = leaderAmount + increment;
      return Number.isFinite(minimum) ? Math.ceil(minimum) : null;
    }
    return Number.isFinite(basePrice) ? Math.ceil(basePrice) : null;
  }

  protected isCurrentLeader(auction: AuctionPublicDetail): boolean {
    return auction.leader_bid !== null && this.auth.user()?.alias === auction.leader_bid.bidder_alias;
  }

  protected countdown(): string {
    const seconds = this.remainingSeconds();
    const hours = Math.floor(seconds / 3600).toString().padStart(2, '0');
    const minutes = Math.floor((seconds % 3600) / 60).toString().padStart(2, '0');
    const remainder = (seconds % 60).toString().padStart(2, '0');
    return `${hours}:${minutes}:${remainder}`;
  }

  /** Refresca el detalle y el historial público de cinco pujas. */
  protected load(): void {
    if (!Number.isInteger(this.auctionId) || this.auctionId < 1) return;
    this.loading.set(true);
    this.error.set('');
    forkJoin({
      auction: this.auctions.detail(this.auctionId),
      bids: this.bidsService.history(this.auctionId),
    }).pipe(finalize(() => this.loading.set(false))).subscribe({
      next: ({ auction, bids }) => {
        this.auction.set(auction);
        this.bids.set(bids.items);
        this.remainingSeconds.set(Math.max(0, auction.remaining_seconds));
        const minimum = this.minimumSuggested;
        const currentAmount = Number(this.bidForm.controls.amount.value);
        if (minimum !== null && (!Number.isFinite(currentAmount) || currentAmount < minimum)) {
          this.bidForm.controls.amount.setValue(minimum);
        }
        this.bidForm.controls.amount.setValidators([
          Validators.required,
          Validators.min(minimum ?? 0),
          Validators.pattern(/^\d+$/),
        ]);
        this.bidForm.controls.amount.updateValueAndValidity();
      },
      error: (error: unknown) => {
        const detail = error instanceof HttpErrorResponse ? error.error?.detail : null;
        this.error.set(typeof detail === 'string' ? detail : 'No se pudo cargar el detalle de la subasta.');
      },
    });
  }

  /** Envía la puja y vuelve a consultar el detalle cuando la API la acepta. */
  protected placeBid(): void {
    const amount = Number(this.bidForm.controls.amount.value);
    const minimum = this.minimumSuggested;
    if (this.bidForm.invalid || this.posting() || minimum === null || !Number.isInteger(amount) || amount < minimum) {
      this.bidForm.markAllAsTouched();
      return;
    }
    this.posting.set(true);
    this.bidsService.place(this.auctionId, { amount }).subscribe({
      next: () => {
        this.posting.set(false);
        this.messages.show('Puja registrada correctamente.');
        this.load();
      },
      error: () => { this.posting.set(false); },
    });
  }
}
