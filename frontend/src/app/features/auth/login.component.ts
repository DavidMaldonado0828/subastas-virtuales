import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { AuthService } from '../../core/auth/auth.service';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-login', standalone: true,
  imports: [ReactiveFormsModule, RouterLink, MatButtonModule, MatFormFieldModule, MatInputModule,MatIconModule],
  template: `
    <main class="auth-page"><section class="auth-card">
      <h1>Iniciar Sesión</h1>
      <form [formGroup]="form" (ngSubmit)="submit()" novalidate>
        <mat-form-field appearance="outline">
          <mat-label>Correo</mat-label>
          <input matInput type="email" autocomplete="email" formControlName="email" placeholder="nombre@correo.com" />
          @if (form.controls.email.touched && form.controls.email.invalid) { <mat-error>Ingresa un correo válido.</mat-error> }
        </mat-form-field>
        <mat-form-field appearance="outline">
          <mat-label>Contraseña</mat-label>
          <input matInput [type]="showPassword ? 'text' : 'password'" autocomplete="current-password" formControlName="password" />
          <button mat-icon-button matSuffix type="button" (click)="showPassword = !showPassword" [attr.aria-label]="'Ocultar contraseña'" [attr.aria-pressed]="showPassword">
            <mat-icon>{{ showPassword ? 'visibility_off' : 'visibility' }}</mat-icon>
          </button>
          @if (form.controls.password.touched && form.controls.password.invalid) { <mat-error>Ingresa tu contraseña.</mat-error> }
        </mat-form-field>
        <button mat-flat-button class="primary-action" type="submit" [disabled]="form.invalid || busy">
          {{ busy ? 'Ingresando…' : 'Ingresar' }}
        </button>
      </form>
      <div class="auth-footer"><span>¿No tienes cuenta?</span> <a routerLink="/registro">Regístrate</a></div>
    </section></main>
  `,
})
export class LoginComponent {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  protected readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', Validators.required],
  });
  protected busy = false;
  protected showPassword = false;

  protected submit(): void {
    if (this.form.invalid || this.busy) { 
      this.form.markAllAsTouched(); return; 
    }
    this.busy = true;
    this.auth.login(this.form.getRawValue()).subscribe({
      next: () => void this.router.navigateByUrl('/'),
      error: () => { this.busy = false; this.form.controls.password.reset();},
    });

  }
}
