import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from '../auth/auth.service';
import { ApiErrorService } from '../services/api-error.service';

// Cierra sesiones inválidas y presenta los mensajes de error de la API.
export const errorInterceptor: HttpInterceptorFn = (request, next) => {
  const auth = inject(AuthService);
  const messages = inject(ApiErrorService);
  const router = inject(Router);

  return next(request).pipe(catchError((error: HttpErrorResponse) => {
    if (error.status === 401) {
      auth.logout(false);
      void router.navigate(['/login']);
      messages.show(apiDetail(error) ?? 'La sesión no es válida. Inicia sesión de nuevo.');
    } else if (error.status === 422) {
      messages.show(validationMessage(error));
    } else {
      messages.show(apiDetail(error) ?? 'No fue posible completar la solicitud.');
    }
    return throwError(() => error);
  }));
};

function apiDetail(error: HttpErrorResponse): string | null {
  const detail = error.error?.detail;
  return typeof detail === 'string' ? detail : null;
}

function validationMessage(error: HttpErrorResponse): string {
  const detail = error.error?.detail;
  if (typeof detail === 'string') return detail;
  if (!Array.isArray(detail)) return 'Revisa los datos ingresados.';

  return detail.map((item: { loc?: unknown[]; msg?: string }) => {
    const field = item.loc?.at(-1);
    const fieldName = typeof field === 'string' ? (fieldNames[field] ?? field) : 'Campo';
    return `${fieldName}: ${translateValidation(item.msg ?? '')}`;
  }).join(' ');
}

const fieldNames: Record<string, string> = {
  name: 'Nombre', alias: 'Nombre de usuario', email: 'Correo', password: 'Contraseña',
  phone_number: 'Teléfono', address: 'Dirección', role: 'Tipo de cuenta',
  accept_bid_policy: 'Política de pujas',
};

function translateValidation(message: string): string {
  const text = message.toLowerCase();
  if (text.includes('field required')) return 'este campo es obligatorio.';
  if (text.includes('valid email')) return 'ingresa un correo válido.';
  if (text.includes('at least') && text.includes('characters')) return 'el texto es demasiado corto.';
  if (text.includes('at most') && text.includes('characters')) return 'el texto es demasiado largo.';
  if (text.includes('input should be')) return 'el valor no es válido.';
  return message || 'revisa este campo.';
}
