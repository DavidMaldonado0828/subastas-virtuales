export type UserRole = 'VENDEDOR' | 'POSTOR' | 'ADMIN';
export type RegisterableRole = 'VENDEDOR' | 'POSTOR';
export type AccountStatus = 'ACTIVO' | 'BLOQUEADO' | 'DESACTIVADO';

export interface RegisterRequest {
  role: RegisterableRole;
  name: string;
  alias: string;
  email: string;
  password: string;
  phone_number: string;
  address?: string | null;
  accept_bid_policy?: boolean;
}

export interface LoginRequest { email: string; password: string; }
export interface UserResponse { user_id: number; role: UserRole; name: string; alias: string; email: string; }
export interface AuthResponse { access_token: string; token_type: string; expires_at: string; user: UserResponse; }
