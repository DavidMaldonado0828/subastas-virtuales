import { Component, inject, OnDestroy, OnInit, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { finalize, forkJoin, of, switchMap, tap } from 'rxjs';
import { CategoryResponse, ProductCreate, ProductPatch, ProductResponse } from '../../core/models/products.model';
import { ProductsService } from '../../core/services/products.service';
import { ApiErrorService } from '../../core/services/api-error.service';

@Component({
  selector: 'app-seller-product-form', standalone: true,
  imports: [ReactiveFormsModule, MatButtonModule, MatCardModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  template: `
    <main class="form-page">
      <button mat-button type="button" class="back-link" (click)="cancel()">← Volver a mis productos</button>
      @if (loading()) { <p role="status">Cargando formulario…</p> }
      @else {
        <mat-card><mat-card-content>
          <h1>{{ product() ? 'Editar producto' : 'Registrar producto' }}</h1>
          <form [formGroup]="form" (ngSubmit)="save()" class="product-form">
            <mat-form-field appearance="outline"><mat-label>Nombre</mat-label><input matInput formControlName="name" maxlength="100" />
              @if (form.controls.name.touched && form.controls.name.invalid) { <mat-error>Ingresa un nombre válido.</mat-error> }
            </mat-form-field>
            <mat-form-field appearance="outline"><mat-label>Descripción</mat-label><textarea matInput rows="4" formControlName="description" maxlength="400"></textarea>
              @if (form.controls.description.touched && form.controls.description.invalid) { <mat-error>Ingresa una descripción válida.</mat-error> }
            </mat-form-field>
            <mat-form-field appearance="outline"><mat-label>Categoría</mat-label>
              <mat-select formControlName="category_id">
                @for (category of categories(); track category.category_id) { <mat-option [value]="category.category_id">{{ category.name }}</mat-option> }
              </mat-select>
              @if (form.controls.category_id.touched && form.controls.category_id.invalid) { <mat-error>Selecciona una categoría activa.</mat-error> }
            </mat-form-field>
            <mat-form-field appearance="outline"><mat-label>Marca (opcional)</mat-label><input matInput formControlName="brand" /></mat-form-field>
            <section class="image-editor" aria-label="Imagen del producto">
              @if (imagePreview()) { <img [src]="imagePreview()!" alt="Vista previa de la imagen del producto" /> }
              @else { <div class="image-placeholder">Sin imagen</div> }
              <label class="file-label">Seleccionar imagen
                <input type="file" accept="image/jpeg,image/png,image/webp" (change)="selectImage($event)" />
              </label>
              @if (imagePreview()) { <button mat-button type="button" (click)="removeImage()">Quitar imagen</button> }
              <small>JPEG, PNG o WEBP. Máximo 2 MB.</small>
            </section>
            <div class="actions"><button mat-flat-button class="primary-action" type="submit" [disabled]="saving() || form.invalid">Guardar</button>
              <button mat-button type="button" (click)="cancel()">Cancelar</button></div>
          </form>
        </mat-card-content></mat-card>
      }
    </main>
  `,
  styles: `
    .form-page { width: min(100% - 32px, 760px); margin: 28px auto 50px; }
    .back-link { margin: 0 0 16px -10px; color: var(--primary); }
    h1 { margin: 6px 0 24px; font-size: 1.8rem; }
    .product-form { display: grid; gap: 10px; }
    .image-editor { display:grid; justify-items:start; gap:8px; margin:4px 0 12px; }
    .image-editor img, .image-placeholder { width:220px; height:150px; object-fit:cover; border-radius:6px; background:#e5e7eb; }
    .image-placeholder { display:grid; place-items:center; color:#667085; }
    .file-label { display:inline-flex; cursor:pointer; color:var(--primary); font-weight:600; }
    .file-label input { position:absolute; width:1px; height:1px; opacity:0; }
    .image-editor small { color:#667085; }
    .actions { display: flex; gap: 12px; margin-top: 6px; }
  `,
})
export class SellerProductFormComponent implements OnInit, OnDestroy {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly products = inject(ProductsService);
  private readonly messages = inject(ApiErrorService);
  private readonly fb = inject(FormBuilder);
  protected readonly loading = signal(true);
  protected readonly saving = signal(false);
  protected readonly categories = signal<CategoryResponse[]>([]);
  protected readonly product = signal<ProductResponse | null>(null);
  protected readonly imagePreview = signal<string | null>(null);
  private readonly selectedFile = signal<File | null>(null);
  private removeExistingImage = false;
  private objectUrl: string | null = null;
  protected readonly form = this.fb.nonNullable.group({
    name: ['', [Validators.required, Validators.maxLength(100)]],
    description: ['', [Validators.required, Validators.maxLength(400)]],
    category_id: [0, [Validators.required, Validators.min(1)]],
    brand: [''],
  });

  ngOnInit(): void {
    const idValue = this.route.snapshot.paramMap.get('id');
    if (!idValue) {
      this.products.categories().pipe(finalize(() => this.loading.set(false))).subscribe({
        next: (categories) => this.categories.set(categories), error: () => undefined,
      });
      return;
    }
    const id = Number(idValue);
    if (!Number.isInteger(id) || id < 1) { this.cancel(); return; }
    forkJoin({ categories: this.products.categories(), product: this.products.get(id) })
      .pipe(finalize(() => this.loading.set(false))).subscribe({
        next: ({ categories, product }) => {
          this.categories.set(categories);
          this.product.set(product);
          this.imagePreview.set(product.image_url);
          this.form.reset({ name: product.name, description: product.description, category_id: product.category_id,
            brand: product.brand ?? '' });
        },
        error: () => this.cancel(),
      });
  }

  protected save(): void {
    if (this.form.invalid || this.saving()) { this.form.markAllAsTouched(); return; }
    const raw = this.form.getRawValue();
    const id = this.product()?.product_id;
    this.saving.set(true);
    if (id === undefined) {
      const payload: ProductCreate = { ...raw, brand: raw.brand.trim() || null, image_url: null };
      this.products.create(payload).pipe(
        tap((created) => this.product.set(created)),
        switchMap((created) => this.selectedFile() ? this.products.uploadImage(created.product_id, this.selectedFile()!) : of(created)),
        finalize(() => this.saving.set(false)),
      ).subscribe({ next: () => { this.messages.show('Producto registrado.'); this.cancel(); }, error: () => undefined });
      return;
    }

    const existing = this.product()!;
    const patch: ProductPatch = {};
    if (raw.name !== existing.name) patch.name = raw.name;
    if (raw.description !== existing.description) patch.description = raw.description;
    if (raw.category_id !== existing.category_id) patch.category_id = raw.category_id;
    const brand = raw.brand.trim() || null;
    if (brand !== existing.brand) patch.brand = brand;
    if (!Object.keys(patch).length && !this.selectedFile() && !this.removeExistingImage) {
      this.saving.set(false);
      this.messages.show('No hay cambios para guardar.');
      return;
    }
    const productUpdate = Object.keys(patch).length ? this.products.update(id, patch) : of(existing);
    const selected = this.selectedFile();
    productUpdate.pipe(switchMap((saved) => selected
      ? this.products.uploadImage(id, selected)
      : this.removeExistingImage ? this.products.deleteImage(id) : of(saved)),
    finalize(() => this.saving.set(false))).subscribe({
      next: () => { this.messages.show('Producto actualizado.'); this.cancel(); }, error: () => undefined,
    });
  }

  protected selectImage(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    if (!file) return;
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl);
    this.objectUrl = URL.createObjectURL(file);
    this.selectedFile.set(file);
    this.removeExistingImage = false;
    this.imagePreview.set(this.objectUrl);
  }

  protected removeImage(): void {
    if (this.objectUrl) URL.revokeObjectURL(this.objectUrl);
    this.objectUrl = null;
    this.selectedFile.set(null);
    this.removeExistingImage = !!this.product()?.image_url;
    this.imagePreview.set(null);
  }

  ngOnDestroy(): void { if (this.objectUrl) URL.revokeObjectURL(this.objectUrl); }

  protected cancel(): void { void this.router.navigate(['/vendedor/productos']); }
}
