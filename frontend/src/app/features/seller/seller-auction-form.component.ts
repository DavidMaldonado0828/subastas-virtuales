import { Component, inject, OnInit, signal } from '@angular/core';
import { AbstractControl, FormBuilder, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MAT_DATE_LOCALE, MatNativeDateModule } from '@angular/material/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { finalize } from 'rxjs';
import { AuctionCreate, AuctionPatch, SellerAuctionItem } from '../../core/models/auctions.model';
import { ProductResponse } from '../../core/models/products.model';
import { AuctionsService } from '../../core/services/auctions.service';
import { ProductsService } from '../../core/services/products.service';
import { ApiErrorService } from '../../core/services/api-error.service';

function localDateTime(day: Date | null, time: string): Date | null {
  if (!day || !time) return null;
  const [hour, minute] = time.split(':').map(Number);
  if (!Number.isInteger(hour) || !Number.isInteger(minute)) return null;
  const value = new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, minute);
  return Number.isNaN(value.getTime()) ? null : value;
}

function dateRangeValidator(control: AbstractControl): ValidationErrors | null {
  const value = control.getRawValue() as { start_day?: Date | null; start_time?: string; end_day?: Date | null; end_time?: string };
  const start = localDateTime(value.start_day ?? null, value.start_time ?? '');
  const end = localDateTime(value.end_day ?? null, value.end_time ?? '');
  return start && end && end.getTime() <= start.getTime() ? { endBeforeStart: true } : null;
}

@Component({
  selector: 'app-seller-auction-form', standalone: true,
  providers: [{ provide: MAT_DATE_LOCALE, useValue: 'es-CO' }],
  imports: [ReactiveFormsModule, MatNativeDateModule, MatButtonModule, MatCardModule, MatDatepickerModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  template: `
    <main class="form-page">
      <button mat-button type="button" class="back-link" (click)="cancel()">← Volver a mis subastas</button>
      @if (loading()) { <p role="status">Cargando formulario…</p> }
      @else {
        <mat-card><mat-card-content>
          <h1>{{ auction() ? 'Editar subasta' : 'Nueva subasta' }}</h1>
          <form [formGroup]="form" (ngSubmit)="save()" class="auction-form">
            @if (!auction()) {
              <mat-form-field appearance="outline"><mat-label>Producto activo</mat-label>
                <mat-select formControlName="product_id">
                  @for (product of activeProducts(); track product.product_id) { <mat-option [value]="product.product_id">{{ product.name }}</mat-option> }
                </mat-select>
                @if (form.controls.product_id.touched && form.controls.product_id.invalid) { <mat-error>Selecciona un producto activo.</mat-error> }
              </mat-form-field>
            } @else { <p class="product-name">Producto: <strong>{{ auction()!.product.name }}</strong></p> }

            <mat-form-field appearance="outline"><mat-label>Precio base (COP)</mat-label>
              <input matInput type="number" min="50000" formControlName="base_price" />
              @if (form.controls.base_price.touched && form.controls.base_price.hasError('pattern')) { <mat-error>Ingresa un monto entero en pesos.</mat-error> }
              @else if (form.controls.base_price.touched && form.controls.base_price.hasError('min')) { <mat-error>El precio base mínimo es $50.000.</mat-error> }
              @else if (form.controls.base_price.touched && form.controls.base_price.hasError('required')) { <mat-error>El precio base es obligatorio.</mat-error> }
            </mat-form-field>
            <mat-form-field appearance="outline"><mat-label>Incremento mínimo (COP)</mat-label>
              <input matInput type="number" min="5000" formControlName="minimum_increment" />
              @if (form.controls.minimum_increment.touched && form.controls.minimum_increment.hasError('pattern')) { <mat-error>Ingresa un monto entero en pesos.</mat-error> }
              @else if (form.controls.minimum_increment.touched && form.controls.minimum_increment.hasError('min')) { <mat-error>El incremento mínimo permitido es $5.000.</mat-error> }
              @else if (form.controls.minimum_increment.touched && form.controls.minimum_increment.hasError('required')) { <mat-error>El incremento mínimo es obligatorio.</mat-error> }
            </mat-form-field>

            <div class="date-time-row">
              <mat-form-field appearance="outline"><mat-label>Fecha de inicio</mat-label>
                <input matInput [matDatepicker]="startPicker" formControlName="start_day" />
                <mat-datepicker-toggle matSuffix [for]="startPicker" />
                <mat-datepicker #startPicker />
                @if (form.controls.start_day.touched && form.controls.start_day.invalid) { <mat-error>Selecciona una fecha de inicio válida.</mat-error> }
              </mat-form-field>
              <mat-form-field appearance="outline"><mat-label>Hora de inicio</mat-label><input matInput type="time" formControlName="start_time" />
                @if (form.controls.start_time.touched && form.controls.start_time.invalid) { <mat-error>Selecciona una hora de inicio válida.</mat-error> }
              </mat-form-field>
            </div>
            <div class="date-time-row">
              <mat-form-field appearance="outline"><mat-label>Fecha de cierre</mat-label>
                <input matInput [matDatepicker]="endPicker" formControlName="end_day" />
                <mat-datepicker-toggle matSuffix [for]="endPicker" />
                <mat-datepicker #endPicker />
                @if (form.controls.end_day.touched && form.controls.end_day.invalid) { <mat-error>Selecciona una fecha de cierre válida.</mat-error> }
              </mat-form-field>
              <mat-form-field appearance="outline"><mat-label>Hora de cierre</mat-label><input matInput type="time" formControlName="end_time" />
                @if (form.controls.end_time.touched && form.controls.end_time.invalid) { <mat-error>Selecciona una hora de cierre válida.</mat-error> }
              </mat-form-field>
            </div>
            @if (form.hasError('endBeforeStart') && (form.controls.end_day.touched || form.controls.end_time.touched)) {
              <p class="date-error" role="alert">La fecha y hora de cierre deben ser posteriores al inicio.</p>
            }
            <div class="actions"><button mat-flat-button class="primary-action" type="submit" [disabled]="saving() || form.invalid">{{ saving() ? 'Guardando…' : 'Guardar' }}</button>
              <button mat-button type="button" (click)="cancel()">Cancelar</button></div>
          </form>
        </mat-card-content></mat-card>
      }
    </main>
  `,
  styles: `
    .form-page { width: min(100% - 32px, 820px); margin: 28px auto 50px; }.back-link { margin: 0 0 16px -10px; color: var(--primary); }
    h1 { margin: 6px 0 24px; font-size: 1.8rem; }.auction-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px 16px; }
    .product-name, .date-time-row, .actions { grid-column: span 2; }.date-time-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .date-time-row mat-form-field { width: 100%; }.actions { display: flex; gap: 12px; margin-top: 6px; }.date-error { color: #b42318; grid-column: span 2; margin: 0; }
    @media (max-width: 640px) { .auction-form { grid-template-columns: 1fr; }.product-name, .date-time-row, .actions, .date-error { grid-column: auto; }.date-time-row { grid-template-columns: 1fr; gap: 0; } }
  `,
})
export class SellerAuctionFormComponent implements OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly auctions = inject(AuctionsService);
  private readonly products = inject(ProductsService);
  private readonly messages = inject(ApiErrorService);
  private readonly fb = inject(FormBuilder);
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly activeProducts = signal<ProductResponse[]>([]);
  protected readonly auction = signal<SellerAuctionItem | null>(null);
  protected readonly form = this.fb.group({
    product_id: [0, [Validators.required, Validators.min(1)]],
    base_price: [0, [Validators.required, Validators.min(50000), Validators.pattern(/^\d+$/)]],
    minimum_increment: [0, [Validators.required, Validators.min(5000), Validators.pattern(/^\d+$/)]],
    start_day: this.fb.control<Date | null>(null, Validators.required),
    start_time: ['', [Validators.required, Validators.pattern(/^([01]\d|2[0-3]):[0-5]\d$/)]],
    end_day: this.fb.control<Date | null>(null, Validators.required),
    end_time: ['', [Validators.required, Validators.pattern(/^([01]\d|2[0-3]):[0-5]\d$/)]],
  }, { validators: dateRangeValidator });
  private baseline: { basePrice: number; increment: number; startDay: number; startTime: string; endDay: number; endTime: string } | null = null;

  ngOnInit(): void {
    const idValue = this.route.snapshot.paramMap.get('id');
    if (!idValue) {
      this.products.list().pipe(finalize(() => this.loading.set(false))).subscribe({
        next: (rows) => this.activeProducts.set(rows.filter((row) => row.status === 'ACTIVO')),
        error: () => this.activeProducts.set([]),
      });
      return;
    }
    const id = Number(idValue);
    if (!Number.isInteger(id) || id < 1) { this.cancel(); return; }
    this.auctions.sellerAuctionsAll().pipe(finalize(() => this.loading.set(false))).subscribe({
      next: (rows) => {
        const item = rows.find((row) => row.auction_id === id);
        if (!item || item.bid_count !== 0 || !['ACTIVA', 'PROGRAMADA'].includes(item.status)) {
          this.messages.show('Esta subasta no se puede editar.'); this.cancel(); return;
        }
        this.auction.set(item);
        const start = new Date(item.start_date);
        const end = new Date(item.end_date);
        const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
        const endDay = new Date(end.getFullYear(), end.getMonth(), end.getDate());
        const startTime = this.timeText(start);
        const endTime = this.timeText(end);
        this.baseline = { basePrice: Number(item.base_price), increment: Number(item.minimum_increment),
          startDay: startDay.getTime(), startTime, endDay: endDay.getTime(), endTime };
        this.form.reset({ product_id: item.product.product_id, base_price: Number(item.base_price),
          minimum_increment: Number(item.minimum_increment), start_day: startDay, start_time: startTime,
          end_day: endDay, end_time: endTime });
      },
      error: () => this.cancel(),
    });
  }

  protected save(): void {
    if (this.form.invalid || this.saving()) { this.form.markAllAsTouched(); return; }
    const raw = this.form.getRawValue();
    const start = localDateTime(raw.start_day, raw.start_time ?? '');
    const end = localDateTime(raw.end_day, raw.end_time ?? '');
    const basePrice = Number(raw.base_price);
    const increment = Number(raw.minimum_increment);
    if (!start || !end || !Number.isInteger(basePrice) || !Number.isInteger(increment)) {
      this.messages.show('Revisa los montos, fechas y horas ingresados.'); return;
    }
    this.saving.set(true);
    const item = this.auction();
    if (!item) {
      const payload: AuctionCreate = { product_id: Number(raw.product_id), base_price: basePrice,
        minimum_increment: increment, start_date: start.toISOString(), end_date: end.toISOString() };
      this.auctions.createAuction(payload).pipe(finalize(() => this.saving.set(false))).subscribe({
        next: () => { this.messages.show('Subasta creada.'); this.cancel(); }, error: () => undefined,
      });
      return;
    }
    const before = this.baseline;
    const patch: AuctionPatch = {};
    if (before && basePrice !== before.basePrice) patch.base_price = basePrice;
    if (before && increment !== before.increment) patch.minimum_increment = increment;
    if (before && (raw.start_day?.getTime() !== before.startDay || raw.start_time !== before.startTime)) patch.start_date = start.toISOString();
    if (before && (raw.end_day?.getTime() !== before.endDay || raw.end_time !== before.endTime)) patch.end_date = end.toISOString();
    if (!Object.keys(patch).length) { this.saving.set(false); this.messages.show('No hay cambios para guardar.'); return; }
    this.auctions.updateAuction(item.auction_id, patch).pipe(finalize(() => this.saving.set(false))).subscribe({
      next: () => { this.messages.show('Subasta actualizada.'); this.cancel(); }, error: () => undefined,
    });
  }

  protected cancel(): void { void this.router.navigate(['/vendedor/subastas']); }

  private timeText(value: Date): string {
    return `${value.getHours().toString().padStart(2, '0')}:${value.getMinutes().toString().padStart(2, '0')}`;
  }
}
