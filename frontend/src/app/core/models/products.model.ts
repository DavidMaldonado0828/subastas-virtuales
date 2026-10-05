export interface ProductCreate {
  name: string;
  description: string;
  category_id: number;
  brand?: string | null;
  image_url?: string | null;
}
export type ProductPatch = Partial<ProductCreate>;
export interface ProductResponse {
  product_id: number; seller_id: number; category_id: number; status_id: number; status: string;
  name: string; brand: string | null; description: string; image_url: string | null;
  created_at: string; updated_at: string | null;
}
export interface CategoryResponse { category_id: number; name: string; description: string; }
export interface ProductDeleteResponse { product_id: number; result: string; status: string | null; }
