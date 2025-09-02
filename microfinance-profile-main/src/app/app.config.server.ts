import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideServerRendering } from '@angular/ssr';
import { routes } from './app.routes.server';  // Import de la constante routes

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideServerRendering()
  ]
};
