import { Component, inject } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

@Component({
  selector: 'app-cancel-auction-dialog', standalone: true,
  imports: [ReactiveFormsModule, MatButtonModule, MatDialogModule, MatFormFieldModule, MatInputModule],
  template: `
    <h2 mat-dialog-title>Cancelar subasta</h2>
    <mat-dialog-content>
      <p>La subasta dejará de estar disponible. Las pujas existentes se conservarán.</p>
      <mat-form-field appearance="outline" class="reason-field">
        <mat-label>Motivo de cancelación</mat-label>
        <textarea matInput [formControl]="reason" rows="4" maxlength="1000"></textarea>
        @if (reason.touched && !validReason()) { <mat-error>Escribe un motivo de al menos 10 caracteres, sin contar espacios al inicio o al final.</mat-error> }
      </mat-form-field>
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button type="button" (click)="dialog.close()">Volver</button>
      <button mat-flat-button class="primary-action" type="button" [disabled]="!validReason()" (click)="submit()">Cancelar subasta</button>
    </mat-dialog-actions>
  `,
  styles: `.reason-field { width: 100%; min-width: min(440px, 75vw); }`,
})
export class CancelAuctionDialogComponent {
  protected readonly dialog = inject(MatDialogRef<CancelAuctionDialogComponent, string>);
  protected readonly reason = new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.minLength(10)] });

  protected validReason(): boolean { return this.reason.value.trim().length >= 10; }
  protected submit(): void {
    const value = this.reason.value.trim();
    if (value.length >= 10) this.dialog.close(value);
    else this.reason.markAsTouched();
  }
}
