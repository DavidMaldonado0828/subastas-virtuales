import { Component, Input } from '@angular/core';
import { TitleCasePipe } from '@angular/common';
import { MatTableModule } from '@angular/material/table';

@Component({
  selector: 'app-data-table', standalone: true, imports: [MatTableModule, TitleCasePipe],
  template: `
    <table mat-table [dataSource]="rows" class="data-table">
      @for (column of columns; track column) {
        <ng-container [matColumnDef]="column">
          <th mat-header-cell *matHeaderCellDef>{{ column | titlecase }}</th>
          <td mat-cell *matCellDef="let row">{{ row[column] }}</td>
        </ng-container>
      }
      <tr mat-header-row *matHeaderRowDef="columns"></tr>
      <tr mat-row *matRowDef="let row; columns: columns"></tr>
    </table>
  `,
})
export class DataTableComponent {
  @Input() columns: string[] = [];
  @Input() rows: Record<string, unknown>[] = [];
}
