import { Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthResponse, LoginRequest, RegisterRequest, UserResponse } from '../models/auth.model';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly tokenKey = 'subastas.accessToken';
  private readonly userKey = 'subastas.user';
  readonly user = signal<UserResponse | null>(this.readUser());

  constructor(private readonly http: HttpClient, private readonly router: Router) {}

  /** Envía las credenciales y conserva la sesión devuelta por la API. */
  login(payload: LoginRequest): Observable<AuthResponse> {
    return this.http.post<AuthResponse>(`${environment.apiUrl}/auth/login`, payload).pipe(
      tap((response) => {
        localStorage.setItem(this.tokenKey, response.access_token);
        localStorage.setItem(this.userKey, JSON.stringify(response.user));
        this.user.set(response.user);
      }),
    );
  }

  /** Crea la cuenta usando el contrato real de registro. */
  register(payload: RegisterRequest): Observable<UserResponse> {
    return this.http.post<UserResponse>(`${environment.apiUrl}/auth/register`, payload);
  }

  token(): string | null { return localStorage.getItem(this.tokenKey); }

  /** Elimina credenciales y perfil guardados; el interceptor evita redirección doble. */
  logout(redirect = true): void {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
    this.user.set(null);
    if (redirect) void this.router.navigate(['/login']);
  }

  private readUser(): UserResponse | null {
    try {
      const saved = localStorage.getItem(this.userKey);
      return saved ? JSON.parse(saved) as UserResponse : null;
    } catch {
      return null;
    }
  }
}
