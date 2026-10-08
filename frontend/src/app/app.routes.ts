import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'subastas' },
  { path: 'login', loadComponent: () => import('./features/auth/login.component').then((m) => m.LoginComponent) },
  { path: 'registro', loadComponent: () => import('./features/auth/register.component').then((m) => m.RegisterComponent) },
  { path: 'subastas', loadChildren: () => import('./features/catalog/catalog.routes').then((m) => m.CATALOG_ROUTES) },
  { path: 'postor', loadChildren: () => import('./features/bidder/bidder.routes').then((m) => m.BIDDER_ROUTES) },
  { path: '**', redirectTo: '' },
];
