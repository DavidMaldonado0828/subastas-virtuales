import { Routes } from '@angular/router';

export const CATALOG_ROUTES: Routes = [
  { path: '', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Catálogo de subastas' } },
  { path: ':id', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Detalle de subasta' } },
];
