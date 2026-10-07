import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { environment } from '../../../environments/environment';

// Adjunta el JWT cuando hay una sesión guardada.
export const authInterceptor: HttpInterceptorFn = (request, next) => {
  const token = inject(AuthService).token();
  const isApiRequest = request.url.startsWith(environment.apiUrl);
  return next(token && isApiRequest
    ? request.clone({ setHeaders: { Authorization: `Bearer ${token}` } })
    : request);
};
