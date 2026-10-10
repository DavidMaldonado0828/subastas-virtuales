import { Component, inject } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { AuthService } from '../../core/auth/auth.service';
import { UserRole } from '../../core/models/auth.model';
import { ConfirmDialogComponent } from '../components/confirm-dialog.component';

@Component({
  selector: 'app-navbar', standalone: true,
  imports: [RouterLink, RouterLinkActive, MatButtonModule, MatDialogModule],
  template: `
    <header class="navbar">
      <a class="brand" routerLink="/" routerLinkActive="nav-active" ariaCurrentWhenActive="page" aria-label="SubastaX, inicio">
        <img src="/logo-subastax.png" alt="SubastaX">
      </a>
      <nav aria-label="Navegación principal">
        <a mat-button routerLink="/subastas" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Subastas</a>
        @if (auth.user(); as user) {
          @if (user.role === 'POSTOR') { <a mat-button routerLink="/postor/mis-subastas" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Mis subastas</a> }
          @if (user.role === 'VENDEDOR') {
            <a mat-button routerLink="/vendedor/productos" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Mis productos</a>
            <a mat-button routerLink="/vendedor/subastas" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Mis subastas</a>
          }
          @if (user.role === 'ADMIN') {
            <a mat-button routerLink="/admin/subastas" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Gestión de subastas</a>
            <a mat-button routerLink="/admin/usuarios" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Usuarios</a>
            <a mat-button routerLink="/admin/categorias" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Categorías</a>
          }
          <span class="user-alias">{{ user.alias }}</span>
          <span class="role-badge">{{ roleNames[user.role] }}</span>
          <button mat-button type="button" (click)="confirmLogout()">Cerrar sesión</button>
        } @else {
          <a mat-button routerLink="/login" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Iniciar sesión</a>
          <a mat-flat-button class="primary-action nav-action" routerLink="/registro" routerLinkActive="nav-active" ariaCurrentWhenActive="page">Registrarse</a>
        }
      </nav>
    </header>
  `,
})
export class NavbarComponent {
  protected readonly auth = inject(AuthService);
  private readonly dialog = inject(MatDialog);
  protected readonly roleNames: Record<UserRole, string> = {
    VENDEDOR: 'Vendedor', POSTOR: 'Participante', ADMIN: 'Administrador',
  };

  protected confirmLogout(): void {
    this.dialog.open(ConfirmDialogComponent, {
      data: { title: 'Cerrar sesión', message: '¿Quieres salir de tu cuenta?', confirmText: 'Cerrar sesión' },
    }).afterClosed().subscribe((confirmed: boolean) => {
      if (confirmed) this.auth.logout();
    });
  }
}
