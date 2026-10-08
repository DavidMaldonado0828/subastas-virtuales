import { Component, computed, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { debounceTime, finalize, Subject } from 'rxjs';
import { CategoryResponse, ProductResponse } from '../../core/models/products.model';
import { ProductsService } from '../../core/services/products.service';
import { ApiErrorService } from '../../core/services/api-error.service';
import { ConfirmDialogComponent } from '../../shared/components/confirm-dialog.component';

@Component({
  selector: 'app-seller-products', standalone: true,
  imports: [RouterLink, MatButtonModule, MatDialogModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  template: `
    <main class="seller-page">
      <div class="heading"><div><h1>Mis productos</h1><p>Administra los productos que publicas en subasta.</p></div>
        <a mat-flat-button class="primary-action" routerLink="/vendedor/productos/nuevo">Registrar producto</a>
      </div>

      <section class="filters" aria-label="Filtros de productos">
        <mat-form-field appearance="outline"><mat-label>Buscar por nombre</mat-label>
          <input matInput [value]="searchText()" (input)="queueNameFilter($any($event.target).value)" />
        </mat-form-field>
        <mat-form-field appearance="outline"><mat-label>Estado</mat-label>
          <mat-select [value]="statusFilter()" (selectionChange)="statusFilter.set($event.value)">
            <mat-option value="TODOS">Todos</mat-option><mat-option value="ACTIVO">Activo</mat-option><mat-option value="DESACTIVADO">Desactivado</mat-option>
          </mat-select>
        </mat-form-field>
        <button mat-stroked-button type="button" (click)="clearFilters()">Limpiar</button>
      </section>

      @if (loading()) { <p role="status">Cargando productos…</p> }
      @else if (visibleProducts().length === 0) { <p class="empty">No hay productos para mostrar con estos filtros.</p> }
      @else {
        <section class="table-wrap" aria-label="Lista de productos">
          <table class="products-table">
            <colgroup><col class="image-col" /><col class="product-col" /><col class="category-col" /><col class="status-col" /><col class="actions-col" /></colgroup>
            <thead><tr><th>Imagen</th><th>Producto</th><th>Categoría</th><th>Estado</th><th>Acciones</th></tr></thead>
            <tbody>
              @for (product of visibleProducts(); track product.product_id) {
                <tr>
                  <td>@if (product.image_url) { <img [src]="product.image_url" [alt]="product.name" /> } @else { <div class="image-placeholder">Sin imagen</div> }</td>
                  <td><strong>{{ product.name }}</strong><small>{{ product.brand || 'Sin marca' }}</small></td>
                  <td>{{ categoryName(product.category_id) }}</td>
                  <td><span class="status-badge" [class.active]="product.status === 'ACTIVO'" [class.inactive]="product.status === 'DESACTIVADO'">{{ product.status }}</span></td>
                  <td><div class="row-actions">
                    @if (product.status === 'DESACTIVADO') {
                      <button mat-flat-button color="primary" type="button" (click)="reactivate(product)">Reactivar</button>
                    } @else {
                      <a mat-button [routerLink]="['/vendedor/productos', product.product_id, 'editar']">Editar</a>
                      <button mat-button color="warn" type="button" (click)="confirmDelete(product)">Eliminar</button>
                    }
                  </div></td>
                </tr>
              }
            </tbody>
          </table>
        </section>
      }
    </main>
  `,
  styles: `
    .seller-page { width: min(100% - 32px, 1100px); margin: 32px auto; }
    .heading, .filters, .form-actions, .row-actions { display: flex; align-items: center; gap: 14px; }
    .heading { justify-content: space-between; margin-bottom: 22px; } h1 { margin: 0; } .heading p { color: #667085; }
    .filters { flex-wrap: wrap; margin: 20px 0; } .filters mat-form-field { min-width: 210px; }
    .table-wrap { overflow-x: auto; border: 1px solid var(--border); border-radius: 6px; }
    .products-table { width: 100%; min-width: 850px; table-layout: fixed; border-collapse: collapse; }
    .image-col { width: 10%; }.product-col { width: 30%; }.category-col { width: 20%; }.status-col { width: 15%; }.actions-col { width: 25%; }
    th, td { padding: 12px 16px; text-align: left; vertical-align: middle; }
    th { color: #667085; background: #f9fafb; font-size: .8rem; font-weight: 500; text-transform: uppercase; }
    tbody tr { border-top: 1px solid #eaecf0; }
    td img, .image-placeholder { width: 64px; height: 58px; object-fit: cover; border-radius: 4px; background: #e5e7eb; }
    .image-placeholder { display: grid; place-items: center; color: #667085; font-size: .7rem; }
    small { display: block; margin-top: 5px; color: #667085; }.status-badge { width: fit-content; padding: 5px 10px; border-radius: 999px; font-size: .82rem; }
    .active { color: #12643a; background: #dcfce7; }.inactive { color: #475467; background: #eaecf0; }
    .row-actions { display: flex; align-items: center; gap: 4px; white-space: nowrap; }.empty { padding: 28px; text-align: center; color: #667085; }
  `,
})
export class SellerProductsComponent implements OnInit {
  private readonly products = inject(ProductsService);
  private readonly dialog = inject(MatDialog);
  private readonly messages = inject(ApiErrorService);
  private readonly destroyRef = inject(DestroyRef);
  private readonly nameInput = new Subject<string>();
  protected readonly rows = signal<ProductResponse[]>([]);
  protected readonly categories = signal<CategoryResponse[]>([]);
  protected readonly loading = signal(true);
  protected readonly searchText = signal('');
  protected readonly nameFilter = signal('');
  protected readonly statusFilter = signal('TODOS');
  protected readonly visibleProducts = computed(() => {
    const name = this.normalize(this.nameFilter());
    const status = this.statusFilter();
    return this.rows().filter((item) => (status === 'TODOS' || item.status === status)
      && this.normalize(item.name).includes(name));
  });

  ngOnInit(): void {
    this.load();
    this.products.categories().subscribe({ next: (items) => this.categories.set(items), error: () => undefined });
    this.nameInput.pipe(debounceTime(300), takeUntilDestroyed(this.destroyRef)).subscribe((value) => this.nameFilter.set(value));
  }

  protected load(): void {
    this.loading.set(true);
    this.products.list().pipe(finalize(() => this.loading.set(false))).subscribe({
      next: (items) => this.rows.set(items),
      error: () => this.rows.set([]),
    });
  }

  protected queueNameFilter(value: string): void {
    this.searchText.set(value);
    this.nameInput.next(value);
  }

  protected clearFilters(): void {
    this.searchText.set('');
    this.nameFilter.set('');
    this.nameInput.next('');
    this.statusFilter.set('TODOS');
  }

  protected confirmDelete(product: ProductResponse): void {
    this.dialog.open(ConfirmDialogComponent, { data: { title: 'Eliminar producto', message: `“${product.name}”: si no tiene subastas, se eliminará. Si tiene una subasta ACTIVA, la operación será rechazada. Si tiene una PROGRAMADA, se cancelará y el producto se desactivará. Las subastas cerradas, finalizadas sin ganador o canceladas se conservarán sin cambios.`, confirmText: 'Continuar' } })
      .afterClosed().subscribe((confirmed: boolean) => {
        if (!confirmed) return;
        this.products.remove(product.product_id).subscribe({
          next: (result) => { this.messages.show(result.result === 'DELETED' ? 'Producto eliminado.' : 'Producto desactivado porque tiene historial'); this.load(); },
          error: () => undefined,
        });
      });
  }

  protected reactivate(product: ProductResponse): void {
    this.products.reactivate(product.product_id).subscribe({
      next: () => { this.messages.show('Producto reactivado.'); this.load(); },
      error: () => undefined,
    });
  }

  protected categoryName(id: number): string { return this.categories().find((item) => item.category_id === id)?.name ?? `Categoría ${id}`; }

  private normalize(value: string): string {
    return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase();
  }
}
