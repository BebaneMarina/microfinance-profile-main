// src/app/app.routes.base.ts
import type { Route } from '@angular/router';

export const baseRoutes: Route[] = [
  {
    path: '',
    loadComponent: () => import('./home/home').then(m => m.HomeComponent),
  },
  {
    path: '**',
    redirectTo: '',
  }
];
