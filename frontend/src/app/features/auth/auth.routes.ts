import { Routes } from '@angular/router';

export const AUTH_ROUTES: Routes = [
  { path: 'login', loadComponent: () => import('./login.component').then(m => m.LoginComponent) },
  { path: 'registro', loadComponent: () => import('./register.component').then(m => m.RegisterComponent) },
];
