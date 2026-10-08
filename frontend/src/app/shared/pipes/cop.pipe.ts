import { Pipe, PipeTransform } from '@angular/core';

@Pipe({ name: 'cop', standalone: true })
export class CopPipe implements PipeTransform {
  private readonly formatter = new Intl.NumberFormat('es-CO', {
    style: 'currency', currency: 'COP', maximumFractionDigits: 0,
  });

  transform(value: number | string | null | undefined): string {
    if (value == null || value === '') return '—';
    const amount = Number(value);
    return Number.isFinite(amount) ? this.formatter.format(amount) : '—';
  }
}
