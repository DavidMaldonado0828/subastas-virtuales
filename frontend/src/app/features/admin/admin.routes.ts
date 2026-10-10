import { Routes } from '@angular/router';
import { adminGuard } from '../../core/guards/role.guard';

export const ADMIN_ROUTES: Routes = [
  { path: 'subastas', canActivate: [adminGuard], loadComponent: () => import('./admin-auctions.component').then((m) => m.AdminAuctionsComponent) },
  { path: 'subastas/:id', canActivate: [adminGuard], loadComponent: () => import('./admin-auction-detail.component').then((m) => m.AdminAuctionDetailComponent) },
  { path: 'usuarios', canActivate: [adminGuard], loadComponent: () => import('./admin-users.component').then((m) => m.AdminUsersComponent) },
  { path: 'categorias', canActivate: [adminGuard], loadComponent: () => import('./admin-categories.component').then((m) => m.AdminCategoriesComponent) },
];
