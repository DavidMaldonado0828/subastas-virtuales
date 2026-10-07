import { Component, inject } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatRadioModule } from '@angular/material/radio';
import { AuthService } from '../../core/auth/auth.service';
import { RegisterableRole } from '../../core/models/auth.model';
import { ApiErrorService } from '../../core/services/api-error.service';

@Component({
  selector: 'app-register', standalone: true,
  imports: [ReactiveFormsModule, RouterLink, MatButtonModule, MatCheckboxModule, MatFormFieldModule, MatInputModule, MatRadioModule],
  template: `
    <main class="auth-page register-page"><section class="auth-card">
      <h1>Registrarse</h1>
      <form [formGroup]="form" (ngSubmit)="submit()" novalidate>
        <div class="form-grid">
          <mat-form-field appearance="outline">
            <mat-label>Nombre completo</mat-label><input matInput formControlName="name" autocomplete="name" />
            @if (form.controls.name.touched && form.controls.name.invalid) { <mat-error>Ingresa tu nombre.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Nombre de usuario</mat-label><input matInput formControlName="alias" autocomplete="username" />
            @if (form.controls.alias.touched && form.controls.alias.invalid) { <mat-error>Ingresa tu alias.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Correo</mat-label><input matInput type="email" formControlName="email" autocomplete="email" />
            @if (form.controls.email.touched && form.controls.email.invalid) { <mat-error>Ingresa un correo válido.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Teléfono</mat-label><input matInput type="tel" formControlName="phone_number" autocomplete="tel" />
            @if (form.controls.phone_number.touched && form.controls.phone_number.invalid) { <mat-error>Ingresa tu teléfono.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Contraseña</mat-label><input matInput type="password" formControlName="password" autocomplete="new-password" />
            <mat-hint>Mínimo 8 caracteres</mat-hint>
            @if (form.controls.password.touched && form.controls.password.invalid) { <mat-error>Usa al menos 8 caracteres.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline">
            <mat-label>Confirmar contraseña</mat-label><input matInput type="password" formControlName="confirmPassword" autocomplete="new-password" />
            @if (form.controls.confirmPassword.touched && form.controls.confirmPassword.value !== form.controls.password.value) { <mat-error>Las contraseñas deben coincidir.</mat-error> }
          </mat-form-field>
          <mat-form-field appearance="outline" class="full-width">
            <mat-label>Dirección (opcional)</mat-label><input matInput formControlName="address" autocomplete="street-address" />
          </mat-form-field>
        </div>
        <fieldset class="role-picker">
          <legend>Quiero registrarme como:</legend>
          <mat-radio-group formControlName="role" aria-label="Tipo de cuenta">
            <mat-radio-button value="VENDEDOR">Vendedor</mat-radio-button>
            <mat-radio-button value="POSTOR">Participante</mat-radio-button>
          </mat-radio-group>
        </fieldset>
        @if (form.controls.role.value === 'POSTOR') {
          <mat-checkbox formControlName="accept_bid_policy" class="policy">
            Acepto la política de pujas (las pujas son vinculantes y no pueden retirarse).
          </mat-checkbox>
          @if (form.controls.accept_bid_policy.touched && !form.controls.accept_bid_policy.value) {
            <div class="field-error">Debes aceptar la política para registrarte como participante.</div>
          }
        }
        <button mat-flat-button class="primary-action" type="submit" [disabled]="!canSubmit || busy">
          {{ busy ? 'Creando cuenta…' : 'Registrarme' }}
        </button>
      </form>
      <div class="auth-footer"><span>¿Ya tienes cuenta?</span> <a routerLink="/login">Inicia sesión</a></div>
    </section></main>
  `,
})
export class RegisterComponent {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly messages = inject(ApiErrorService);
  protected readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.maxLength(100)]],
    alias: ['', [Validators.required, Validators.maxLength(50)]],
    email: ['', [Validators.required, Validators.email]],
    phone_number: ['', [Validators.required, Validators.maxLength(20)]],
    password: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(128)]],
    confirmPassword: ['', Validators.required],
    address: [''],
    role: ['POSTOR' as RegisterableRole, Validators.required],
    accept_bid_policy: [false],
  });
  protected busy = false;

  protected get canSubmit(): boolean {
    const values = this.form.getRawValue();
    return this.form.valid && values.password === values.confirmPassword &&
      (values.role !== 'POSTOR' || values.accept_bid_policy);
  }

  /** Envía solo los campos definidos por el contrato de registro. */
  protected submit(): void {
    this.form.markAllAsTouched();
    if (!this.canSubmit || this.busy) return;
    this.busy = true;
    const { confirmPassword: _confirmPassword, ...payload } = this.form.getRawValue();
    this.auth.register(payload).subscribe({
      next: () => {
        this.messages.show('Cuenta creada. Ya puedes iniciar sesión.');
        void this.router.navigate(['/login']);
      },
      error: () => { this.busy = false; },
    });
  }
}
