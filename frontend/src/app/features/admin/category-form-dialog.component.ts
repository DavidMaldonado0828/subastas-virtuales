import { Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { AdminCategory, AdminCategoryCreate } from '../../core/models/admin.model';

@Component({
  selector: 'app-category-form-dialog', standalone: true,
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
  template: `
    <h2 mat-dialog-title>{{ data ? 'Editar categoría' : 'Nueva categoría' }}</h2>
    <form [formGroup]="form" (ngSubmit)="submit()">
      <mat-dialog-content>
        <mat-form-field appearance="outline" class="field"><mat-label>Nombre</mat-label>
          <input matInput formControlName="name" maxlength="60">
          @if (form.controls.name.touched && form.controls.name.hasError('minlength')) { <mat-error>Usa al menos 2 caracteres.</mat-error> }
          @if (form.controls.name.touched && form.controls.name.hasError('required')) { <mat-error>El nombre es obligatorio.</mat-error> }
        </mat-form-field>
        <mat-form-field appearance="outline" class="field"><mat-label>Descripción</mat-label>
          <textarea matInput formControlName="description" rows="3" maxlength="400"></textarea>
          @if (form.controls.description.touched && form.controls.description.hasError('required')) { <mat-error>La descripción es obligatoria.</mat-error> }
        </mat-form-field>
      </mat-dialog-content>
      <mat-dialog-actions align="end">
        <button mat-button type="button" (click)="dialog.close()">Cancelar</button>
        <button mat-flat-button class="primary-action" type="submit" [disabled]="form.invalid">Guardar</button>
      </mat-dialog-actions>
    </form>
  `,
  styles: `.field { display: block; width: min(100%, 480px); min-width: min(380px, 75vw); }`,
})
export class CategoryFormDialogComponent {
  protected readonly data = inject<AdminCategory | null>(MAT_DIALOG_DATA);
  protected readonly dialog = inject(MatDialogRef<CategoryFormDialogComponent, AdminCategoryCreate>);
  protected readonly form = new FormGroup({
    name: new FormControl(this.data?.name ?? '', { nonNullable: true, validators: [Validators.required, Validators.minLength(2), Validators.maxLength(60)] }),
    description: new FormControl(this.data?.description ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(400)] }),
  });

  protected submit(): void {
    this.form.markAllAsTouched();
    if (this.form.invalid) return;
    const value = this.form.getRawValue();
    if (value.name.trim().length < 2) return;
    this.dialog.close({ name: value.name.trim(), description: value.description });
  }
}
