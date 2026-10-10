import { Component, inject, OnInit, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { MatTableModule } from '@angular/material/table';
import { finalize } from 'rxjs';
import { AdminCategory } from '../../core/models/admin.model';
import { AdminService } from '../../core/services/admin.service';
import { ApiErrorService } from '../../core/services/api-error.service';
import { ConfirmDialogComponent } from '../../shared/components/confirm-dialog.component';
import { CategoryFormDialogComponent } from './category-form-dialog.component';

@Component({
  selector: 'app-admin-categories', standalone: true,
  imports: [MatButtonModule, MatDialogModule, MatTableModule],
  template: `
    <main class="admin-page">
      <header class="heading"><div><h1>Categorías</h1><p>Administra las categorías disponibles para productos.</p></div>
        <div class="actions"><button mat-stroked-button type="button" [disabled]="loading()" (click)="load()">Actualizar</button>
          <button mat-flat-button class="primary-action" type="button" (click)="openForm()">Nueva categoría</button></div>
      </header>
      @if (loading()) { <p role="status">Cargando categorías…</p> }
      @else if (categories().length === 0) { <p class="empty">Aún no hay categorías.</p> }
      @else { <div class="table-scroll"><table mat-table [dataSource]="categories()">
        <ng-container matColumnDef="name"><th mat-header-cell *matHeaderCellDef>Nombre</th><td mat-cell *matCellDef="let category">{{ category.name }}</td></ng-container>
        <ng-container matColumnDef="description"><th mat-header-cell *matHeaderCellDef>Descripción</th><td mat-cell *matCellDef="let category">{{ category.description }}</td></ng-container>
        <ng-container matColumnDef="status"><th mat-header-cell *matHeaderCellDef>Estado</th><td mat-cell *matCellDef="let category"><span class="category-badge" [class.inactive]="category.status === 'DESACTIVADA'">{{ category.status }}</span></td></ng-container>
        <ng-container matColumnDef="count"><th mat-header-cell *matHeaderCellDef>Productos</th><td mat-cell *matCellDef="let category">{{ category.product_count }}</td></ng-container>
        <ng-container matColumnDef="actions"><th mat-header-cell *matHeaderCellDef>Acciones</th><td mat-cell *matCellDef="let category">
          <div class="row-actions"><button mat-button class="table-action" type="button" [disabled]="busyId() === category.id" (click)="openForm(category)">Editar</button>
            <button mat-button class="table-action" [class.action-danger]="category.status === 'ACTIVA'" type="button" [disabled]="busyId() === category.id" (click)="toggleStatus(category)">{{ category.status === 'ACTIVA' ? 'Desactivar' : 'Reactivar' }}</button></div>
        </td></ng-container>
        <tr mat-header-row *matHeaderRowDef="columns"></tr><tr mat-row *matRowDef="let row; columns: columns"></tr>
      </table></div> }
    </main>
  `,
  styles: `
    .admin-page { width:min(100% - 32px,1100px); margin:30px auto; }.heading { display:flex; justify-content:space-between; align-items:center; gap:16px; margin-bottom:20px; }.heading h1 { margin:0; }.heading p { color:#667085; }.actions,.row-actions { display:flex; align-items:center; gap:8px; flex-wrap:wrap; }.table-scroll { overflow-x:auto; border:1px solid var(--border); }table { width:100%; min-width:760px; }.category-badge { display:inline-block; padding:4px 10px; border-radius:999px; background:#e7f5ec; color:#176b38; font-size:.85rem; }.category-badge.inactive { background:#f2f4f7; color:#475467; }.empty { padding:26px; text-align:center; color:#667085; }
    @media(max-width:620px) { .heading { align-items:flex-start; flex-direction:column; }.actions { width:100%; } }
  `,
})
export class AdminCategoriesComponent implements OnInit {
  private readonly admin = inject(AdminService);
  private readonly dialog = inject(MatDialog);
  private readonly messages = inject(ApiErrorService);
  protected readonly categories = signal<AdminCategory[]>([]);
  protected readonly loading = signal(false);
  protected readonly busyId = signal<number | null>(null);
  protected readonly columns = ['name', 'description', 'status', 'count', 'actions'];

  ngOnInit(): void { this.load(); }

  protected load(): void {
    this.loading.set(true);
    this.admin.categories().pipe(finalize(() => this.loading.set(false))).subscribe({
      next: (categories) => this.categories.set(categories),
      error: () => this.categories.set([]),
    });
  }

  protected openForm(category?: AdminCategory): void {
    this.dialog.open(CategoryFormDialogComponent, { data: category ?? null, width: 'min(540px, 94vw)' })
      .afterClosed().subscribe((value: { name: string; description: string } | undefined) => {
        if (!value) return;
        const request = category
          ? this.admin.updateCategory(category.id, {
            ...(value.name !== category.name ? { name: value.name } : {}),
            ...(value.description !== category.description ? { description: value.description } : {}),
          })
          : this.admin.createCategory(value);
        if (category && value.name === category.name && value.description === category.description) return;
        this.busyId.set(category?.id ?? -1);
        request.pipe(finalize(() => this.busyId.set(null))).subscribe({
          next: () => { this.messages.show(category ? 'Categoría actualizada.' : 'Categoría creada.'); this.load(); },
        });
      });
  }

  protected toggleStatus(category: AdminCategory): void {
    const status = category.status === 'ACTIVA' ? 'DESACTIVADA' : 'ACTIVA';
    const action = status === 'DESACTIVADA' ? 'desactivar' : 'reactivar';
    this.dialog.open(ConfirmDialogComponent, { data: {
      title: `${action[0].toUpperCase()}${action.slice(1)} categoría`,
      message: status === 'DESACTIVADA'
        ? 'No podrá asignarse a productos nuevos o editados. Los productos existentes conservarán la categoría.'
        : 'La categoría volverá a estar disponible para asignarla a productos.',
      confirmText: action[0].toUpperCase() + action.slice(1),
      destructive: status === 'DESACTIVADA',
    } }).afterClosed().subscribe((confirmed: boolean) => {
      if (!confirmed) return;
      this.busyId.set(category.id);
      this.admin.updateCategoryStatus(category.id, { status }).pipe(finalize(() => this.busyId.set(null))).subscribe({
        next: () => { this.messages.show(`Categoría ${status === 'ACTIVA' ? 'reactivada' : 'desactivada'}.`); this.load(); },
      });
    });
  }
}
