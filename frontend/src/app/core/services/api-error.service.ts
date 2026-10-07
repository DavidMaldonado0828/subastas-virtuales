import { Injectable, signal } from '@angular/core';
import { MatSnackBar } from '@angular/material/snack-bar';

@Injectable({ providedIn: 'root' })
export class ApiErrorService {
  readonly message = signal('');
  constructor(private readonly snackbar: MatSnackBar) {}

  /** Muestra errores y confirmaciones breves en el snackbar de Material. */
  show(message: string): void {
    this.message.set(message);
    this.snackbar.open(message, 'Cerrar', { duration: 5000, horizontalPosition: 'end', verticalPosition: 'top' });
  }

  clear(): void { this.message.set(''); }
}
