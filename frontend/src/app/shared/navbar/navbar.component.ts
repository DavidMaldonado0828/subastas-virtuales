import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { AuthService } from '../../core/auth/auth.service';
import { UserRole } from '../../core/models/auth.model';
import { ConfirmDialogComponent } from '../components/confirm-dialog.component';

@Component({
  selector: 'app-navbar', standalone: true,
  imports: [RouterLink, MatButtonModule, MatDialogModule],
  template: `
    <header class="navbar">
      <a class="brand" routerLink="/">Subastas</a>
      <nav aria-label="Navegación principal">
        <a mat-button routerLink="/subastas">Subastas</a>
        @if (auth.user(); as user) {
          @if (user.role === 'POSTOR') { <a mat-button routerLink="/postor/mis-subastas">Mis subastas</a> }
          <span class="user-alias">{{ user.alias }}</span>
          <span class="role-badge">{{ roleNames[user.role] }}</span>
          <button mat-button type="button" (click)="confirmLogout()">Cerrar sesión</button>
        } @else {
          <a mat-button routerLink="/login">Iniciar sesión</a>
          <a mat-flat-button class="primary-action nav-action" routerLink="/registro">Registrarse</a>
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
