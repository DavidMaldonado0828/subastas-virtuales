import { Routes } from '@angular/router';

export const ADMIN_ROUTES: Routes = [
  { path: 'subastas', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Administrar subastas' } },
  { path: 'usuarios', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Administrar usuarios' } },
];
