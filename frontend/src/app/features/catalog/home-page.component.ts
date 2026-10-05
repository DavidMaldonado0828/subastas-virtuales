import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'app-home-page',
  standalone: true,
  imports: [RouterLink, MatButtonModule],
  template: `
    <main class="home">
      <h1>Subastas virtuales</h1>
      <p>Explora subastas y encuentra productos de interés.</p>
      <a mat-flat-button routerLink="/catalogo">Ver catálogo</a>
    </main>
  `,
  styles: `
    .home { max-width: 60rem; margin: 10vh auto; padding: 2rem; }
    h1 { font-size: clamp(2rem, 6vw, 3.5rem); }
  `,
})
export class HomePageComponent {}
