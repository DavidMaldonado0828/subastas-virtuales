import { Routes } from '@angular/router';

export const AUTH_ROUTES: Routes = [
  { path: 'login', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Iniciar sesión' } },
  { path: 'registro', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Crear cuenta' } },
];
