import { Routes } from '@angular/router';
import { bidderGuard } from '../../core/guards/role.guard';

export const BIDDER_ROUTES: Routes = [
  { path: 'mis-subastas', canActivate: [bidderGuard], loadComponent: () => import('./my-auctions.component').then((m) => m.MyAuctionsComponent) },
];
