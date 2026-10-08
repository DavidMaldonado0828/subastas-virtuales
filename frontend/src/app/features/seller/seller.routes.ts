import { Routes } from '@angular/router';
import { sellerGuard } from '../../core/guards/role.guard';

export const SELLER_ROUTES: Routes = [
  { path: 'productos/nuevo', canActivate: [sellerGuard], loadComponent: () => import('./seller-product-form.component').then((m) => m.SellerProductFormComponent) },
  { path: 'productos/:id/editar', canActivate: [sellerGuard], loadComponent: () => import('./seller-product-form.component').then((m) => m.SellerProductFormComponent) },
  { path: 'productos', canActivate: [sellerGuard], loadComponent: () => import('./seller-products.component').then((m) => m.SellerProductsComponent) },
  { path: 'subastas/nueva', canActivate: [sellerGuard], loadComponent: () => import('./seller-auction-form.component').then((m) => m.SellerAuctionFormComponent) },
  { path: 'subastas/:id/editar', canActivate: [sellerGuard], loadComponent: () => import('./seller-auction-form.component').then((m) => m.SellerAuctionFormComponent) },
  { path: 'subastas/:id/pujas', canActivate: [sellerGuard], loadComponent: () => import('./seller-bid-history.component').then((m) => m.SellerBidHistoryComponent) },
  { path: 'subastas', canActivate: [sellerGuard], loadComponent: () => import('./seller-auctions.component').then((m) => m.SellerAuctionsComponent) },
];
