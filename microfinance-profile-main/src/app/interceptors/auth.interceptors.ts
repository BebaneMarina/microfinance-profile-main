import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  
  // Récupérer le token depuis le localStorage
  const token = localStorage.getItem('access_token');
  
  // Cloner la requête et ajouter le token si disponible
  let authReq = req;
  if (token) {
    authReq = req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    });
  }
  
  // Passer la requête et gérer les erreurs
  return next(authReq).pipe(
    catchError((error) => {
      // Si erreur 401 (non autorisé), rediriger vers login
      if (error.status === 401) {
        localStorage.removeItem('access_token');
        localStorage.removeItem('currentUser');
        router.navigate(['/login']);
      }
      
      return throwError(() => error);
    })
  );
};