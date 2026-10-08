import { Routes } from '@angular/router';
import { adminGuard } from '../../core/guards/role.guard';

export const ADMIN_ROUTES: Routes = [
  { path: 'subastas', canActivate: [adminGuard], loadComponent: () => import('./admin-auctions.component').then((m) => m.AdminAuctionsComponent) },
  { path: 'usuarios', canActivate: [adminGuard], loadComponent: () => import('./admin-users.component').then((m) => m.AdminUsersComponent) },
];
