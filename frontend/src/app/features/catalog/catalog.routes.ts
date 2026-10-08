import { Routes } from '@angular/router';

export const CATALOG_ROUTES: Routes = [
  { path: '', loadComponent: () => import('./catalog.component').then((m) => m.CatalogComponent) },
  { path: ':id', loadComponent: () => import('./auction-detail.component').then((m) => m.AuctionDetailComponent) },
];
