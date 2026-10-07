import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', loadComponent: () => import('./features/auth/auth-home.component').then((m) => m.AuthHomeComponent) },
  { path: 'login', loadComponent: () => import('./features/auth/login.component').then((m) => m.LoginComponent) },
  { path: 'registro', loadComponent: () => import('./features/auth/register.component').then((m) => m.RegisterComponent) },
  { path: '**', redirectTo: '' },
];
