import { Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { AuthService } from '../../core/auth/auth.service';
import { UserRole } from '../../core/models/auth.model';

@Component({
  selector: 'app-auth-home', standalone: true, imports: [RouterLink, MatButtonModule],
  template: `
    <main class="home-page">
      @if (auth.user(); as user) {
        <h1>Bienvenido, {{ user.alias }}</h1>
        <p>Sesión iniciada como {{ roleNames[user.role] }}.</p>
      } @else {
        <h1>Subastas virtuales</h1>
        <p>Compra y vende productos en subastas.</p>
        <a mat-flat-button class="primary-action" routerLink="/login">Iniciar sesión</a>
      }
    </main>
  `,
})
export class AuthHomeComponent {
  protected readonly auth = inject(AuthService);
  protected readonly roleNames: Record<UserRole, string> = {
    VENDEDOR: 'Vendedor', POSTOR: 'Participante', ADMIN: 'Administrador',
  };
}
