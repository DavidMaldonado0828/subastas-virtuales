import { HttpRequest } from '@angular/common/http';
import { environment } from '../../../environments/environment';

/** Identifica lecturas que la API ofrece sin autenticación. */
export function isPublicAuctionRead(request: HttpRequest<unknown>): boolean {
  if (request.method !== 'GET' || !request.url.startsWith(environment.apiUrl)) return false;
  const path = request.url.slice(environment.apiUrl.length).split('?')[0];
  return /^\/auctions(?:\/\d+(?:\/bids)?)?$/.test(path);
}
