import { Routes } from '@angular/router';

export const SELLER_ROUTES: Routes = [
  { path: 'productos', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Mis productos' } },
  { path: 'subastas', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Mis subastas' } },
];
