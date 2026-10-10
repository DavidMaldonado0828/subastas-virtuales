import { Component, DestroyRef, inject, OnInit, signal } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { FormControl, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatTableModule } from '@angular/material/table';
import { debounceTime, distinctUntilChanged, finalize } from 'rxjs';
import { AdminUserListItem } from '../../core/models/admin.model';
import { AdminService } from '../../core/services/admin.service';

@Component({
  selector: 'app-admin-users', standalone: true,
  imports: [ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatTableModule],
  template: `
    <main class="admin-page">
      <header class="heading"><div><h1>Usuarios</h1><p>Busca por alias o correo y administra el acceso.</p></div>
        <button mat-stroked-button type="button" [disabled]="loading()" (click)="load()">Actualizar</button>
      </header>
      <mat-form-field appearance="outline" class="search-field"><mat-label>Alias o correo</mat-label>
        <input matInput [formControl]="search" placeholder="Buscar usuario">
        @if (search.value) { <button mat-button matSuffix type="button" (click)="search.setValue('')">Limpiar</button> }
      </mat-form-field>
      @if (loading()) { <p role="status">Cargando usuarios…</p> }
      @else if (items().length === 0) { <p class="empty">No se encontraron usuarios.</p> }
      @else {
        <div class="table-scroll"><table mat-table [dataSource]="items()">
          <ng-container matColumnDef="alias"><th mat-header-cell *matHeaderCellDef>Alias</th><td mat-cell *matCellDef="let user">{{ user.alias }}</td></ng-container>
          <ng-container matColumnDef="role"><th mat-header-cell *matHeaderCellDef>Rol</th><td mat-cell *matCellDef="let user">{{ roleLabel(user.role) }}</td></ng-container>
          <ng-container matColumnDef="status"><th mat-header-cell *matHeaderCellDef>Estado</th><td mat-cell *matCellDef="let user"><span class="status" [class.blocked]="user.status === 'BLOQUEADO'">{{ user.status }}</span></td></ng-container>
          <ng-container matColumnDef="actions"><th mat-header-cell *matHeaderCellDef>Acciones</th><td mat-cell *matCellDef="let user">
            @if (user.role !== 'ADMIN' && user.status === 'ACTIVO') { <button mat-button class="table-action action-danger" type="button" [disabled]="busyId() === user.id" (click)="updateStatus(user, 'BLOQUEADO')">Bloquear</button> }
            @else if (user.role !== 'ADMIN' && user.status === 'BLOQUEADO') { <button mat-button class="table-action" type="button" [disabled]="busyId() === user.id" (click)="updateStatus(user, 'ACTIVO')">Reactivar</button> }
            @else { — }
          </td></ng-container>
          <tr mat-header-row *matHeaderRowDef="columns"></tr><tr mat-row *matRowDef="let row; columns: columns"></tr>
        </table></div>
        <nav class="pagination" aria-label="Paginación de usuarios"><button mat-stroked-button [disabled]="offset() === 0 || loading()" (click)="previous()">Anterior</button><span>{{ offset() + 1 }}–{{ offset() + items().length }} de {{ total() }}</span><button mat-stroked-button [disabled]="offset() + items().length >= total() || loading()" (click)="next()">Siguiente</button></nav>
      }
    </main>
  `,
  styles: `
    .admin-page { width: min(100% - 32px, 1000px); margin: 30px auto; }.heading { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }.heading h1 { margin: 0; }.heading p { color: #667085; }.search-field { width: min(100%, 440px); }.table-scroll { overflow-x: auto; border: 1px solid var(--border); }table { width: 100%; min-width: 600px; }.status { display: inline-block; padding: 4px 9px; border-radius: 999px; background: #e7f5ec; color: #176b38; font-size: .85rem; }.status.blocked { background: #fff0ec; color: #b54708; }.pagination { display: flex; justify-content: center; align-items: center; gap: 16px; margin: 24px; }.empty { padding: 24px; text-align: center; color: #667085; }
    @media (max-width: 620px) { .heading { align-items: flex-start; flex-direction: column; gap: 12px; } }
  `,
})
export class AdminUsersComponent implements OnInit {
  private readonly admin = inject(AdminService);
  private readonly destroyRef = inject(DestroyRef);
  protected readonly pageSize = 20;
  protected readonly columns = ['alias', 'role', 'status', 'actions'];
  protected readonly items = signal<AdminUserListItem[]>([]);
  protected readonly offset = signal(0);
  protected readonly total = signal(0);
  protected readonly loading = signal(false);
  protected readonly busyId = signal<number | null>(null);
  protected readonly search = new FormControl('', { nonNullable: true });
  private reloadRequested = false;

  ngOnInit(): void {
    this.search.valueChanges.pipe(debounceTime(300), distinctUntilChanged(), takeUntilDestroyed(this.destroyRef)).subscribe(() => {
      this.offset.set(0);
      this.load();
    });
    this.load();
  }

  protected load(): void {
    if (this.loading()) { this.reloadRequested = true; return; }
    this.loading.set(true);
    this.admin.users(this.pageSize, this.offset(), this.search.value.trim() || undefined).pipe(finalize(() => {
      this.loading.set(false);
      if (this.reloadRequested) { this.reloadRequested = false; this.load(); }
    })).subscribe({
      next: (page) => { this.items.set(page.items); this.total.set(page.total); },
      error: () => { this.items.set([]); this.total.set(0); },
    });
  }

  protected roleLabel(role: AdminUserListItem['role']): string {
    return role === 'POSTOR' ? 'Postor' : role === 'VENDEDOR' ? 'Vendedor' : 'Administrador';
  }

  protected updateStatus(user: AdminUserListItem, status: 'BLOQUEADO' | 'ACTIVO'): void {
    this.busyId.set(user.id);
    this.admin.updateUserStatus(user.id, { status }).pipe(finalize(() => this.busyId.set(null))).subscribe({ next: () => this.load() });
  }

  protected previous(): void { this.offset.update((value) => Math.max(0, value - this.pageSize)); this.load(); }
  protected next(): void { this.offset.update((value) => value + this.pageSize); this.load(); }
}
