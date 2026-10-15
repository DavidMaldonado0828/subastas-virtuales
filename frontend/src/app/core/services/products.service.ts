import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import { CategoryResponse, ProductCreate, ProductDeleteResponse, ProductPatch, ProductResponse } from '../models/products.model';

@Injectable({ providedIn: 'root' })
export class ProductsService {
  constructor(private readonly http: HttpClient) {}

  /** Consulta la lista propia; la pantalla aplica sus filtros en cliente. */
  list(): Observable<ProductResponse[]> {
    return this.http.get<ProductResponse[]>(`${environment.apiUrl}/products`);
  }

  categories(): Observable<CategoryResponse[]> {
    return this.http.get<CategoryResponse[]>(`${environment.apiUrl}/categories`);
  }

  get(id: number): Observable<ProductResponse> {
    return this.http.get<ProductResponse>(`${environment.apiUrl}/products/${id}`);
  }

  create(payload: ProductCreate): Observable<ProductResponse> {
    return this.http.post<ProductResponse>(`${environment.apiUrl}/products`, payload);
  }

  update(id: number, payload: ProductPatch): Observable<ProductResponse> {
    return this.http.patch<ProductResponse>(`${environment.apiUrl}/products/${id}`, payload);
  }

  /** Envía el archivo al almacenamiento del backend sin fijar el content-type. */
  uploadImage(id: number, file: File): Observable<ProductResponse> {
    const data = new FormData();
    data.append('file', file);
    return this.http.post<ProductResponse>(`${environment.apiUrl}/products/${id}/image`, data);
  }

  /** Quita la imagen actual del producto. */
  deleteImage(id: number): Observable<ProductResponse> {
    return this.http.delete<ProductResponse>(`${environment.apiUrl}/products/${id}/image`);
  }

  remove(id: number): Observable<ProductDeleteResponse> {
    return this.http.delete<ProductDeleteResponse>(`${environment.apiUrl}/products/${id}`);
  }

  reactivate(id: number): Observable<ProductResponse> {
    return this.http.post<ProductResponse>(`${environment.apiUrl}/products/${id}/reactivate`, {});
  }
}
