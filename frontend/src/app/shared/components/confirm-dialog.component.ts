import { Component, inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';

export interface ConfirmDialogData { title: string; message: string; confirmText?: string; destructive?: boolean; }

@Component({
  selector: 'app-confirm-dialog', standalone: true, imports: [MatDialogModule, MatButtonModule],
  template: `
    <h2 mat-dialog-title>{{ data.title }}</h2>
    <mat-dialog-content>{{ data.message }}</mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button type="button" (click)="dialog.close(false)">Cancelar</button>
      @if (data.destructive) { <button mat-button class="table-action action-danger" type="button" (click)="dialog.close(true)">{{ data.confirmText ?? 'Confirmar' }}</button> }
      @else { <button mat-flat-button class="primary-action" type="button" (click)="dialog.close(true)">{{ data.confirmText ?? 'Confirmar' }}</button> }
    </mat-dialog-actions>
  `,
})
export class ConfirmDialogComponent {
  protected readonly data = inject<ConfirmDialogData>(MAT_DIALOG_DATA);
  protected readonly dialog = inject(MatDialogRef<ConfirmDialogComponent, boolean>);
}
