import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-page-placeholder',
  standalone: true,
  template: `<main><h1>{{ title }}</h1><p>Sección preparada para su implementación.</p></main>`,
  styles: `main { max-width: 60rem; margin: 3rem auto; padding: 1rem; }`,
})
export class PagePlaceholderComponent {
  private readonly route = inject(ActivatedRoute);
  protected readonly title = this.route.snapshot.data['title'] as string;
}
