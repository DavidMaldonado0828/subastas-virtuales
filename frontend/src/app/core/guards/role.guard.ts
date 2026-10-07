import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { UserRole } from '../models/auth.model';

// Protege rutas futuras y dirige al login si falta sesión o no coincide el rol.
export function roleGuard(requiredRole: UserRole): CanActivateFn {
  return () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    if (auth.token() && auth.user()?.role === requiredRole) return true;
    return router.createUrlTree(['/login']);
  };
}

export const sellerGuard = roleGuard('VENDEDOR');
export const bidderGuard = roleGuard('POSTOR');
export const adminGuard = roleGuard('ADMIN');
