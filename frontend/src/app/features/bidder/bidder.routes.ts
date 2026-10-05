import { Routes } from '@angular/router';

export const BIDDER_ROUTES: Routes = [
  { path: 'mis-subastas', loadComponent: () => import('../../shared/components/page-placeholder.component').then(m => m.PagePlaceholderComponent), data: { title: 'Mis subastas' } },
];
