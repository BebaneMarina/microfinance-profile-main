import { inject } from '@angular/core';
import { Router, ActivatedRouteSnapshot, RouterStateSnapshot, CanActivateFn } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { StorageService } from '../services/storage.service';

export const roleGuard: CanActivateFn = (route: ActivatedRouteSnapshot, state: RouterStateSnapshot) => {
  const router = inject(Router);
  const authService = inject(AuthService);
  const storageService = inject(StorageService);
  
  // Vérifier si l'utilisateur est authentifié
  if (!authService.isAuthenticated()) {
    router.navigate(['/login']);
    return false;
  }
  
  // Récupérer le rôle requis depuis la route
  const requiredRole = route.data['role'] as string;
  
  // Si aucun rôle n'est requis, autoriser l'accès
  if (!requiredRole) {
    return true;
  }
  
  // Récupérer l'utilisateur actuel depuis le storage (pas un Observable)
  const currentUser = storageService.getCurrentUser();
  
  // Si pas d'utilisateur, rediriger vers login
  if (!currentUser) {
    router.navigate(['/login']);
    return false;
  }
  
  // Récupérer le rôle de l'utilisateur
  const userRole = currentUser.role || 'client';
  
  // Vérifier si le rôle correspond
  if (userRole === requiredRole) {
    return true;
  }
  
  // Rediriger selon le rôle de l'utilisateur
  switch (userRole) {
    case 'admin':
      router.navigate(['/admin/dashboard']);
      break;
    case 'agent':
      router.navigate(['/agent/dashboard']);
      break;
    case 'client':
      router.navigate(['/client/profile']);
      break;
    default:
      router.navigate(['/login']);
  }
  
  return false;
};

// Version alternative avec authGuard combiné
export const authGuard: CanActivateFn = (route: ActivatedRouteSnapshot, state: RouterStateSnapshot) => {
  const router = inject(Router);
  const authService = inject(AuthService);
  
  if (authService.isAuthenticated()) {
    return true;
  }
  
  // Sauvegarder l'URL demandée pour redirection après login
  router.navigate(['/login'], { queryParams: { returnUrl: state.url } });
  return false;
};

// Guard pour vérifier plusieurs rôles
export const multiRoleGuard: CanActivateFn = (route: ActivatedRouteSnapshot, state: RouterStateSnapshot) => {
  const router = inject(Router);
  const authService = inject(AuthService);
  const storageService = inject(StorageService);
  
  // Vérifier si l'utilisateur est authentifié
  if (!authService.isAuthenticated()) {
    router.navigate(['/login']);
    return false;
  }
  
  // Récupérer les rôles autorisés depuis la route
  const allowedRoles = route.data['roles'] as string[];
  
  // Si aucun rôle n'est spécifié, autoriser l'accès
  if (!allowedRoles || allowedRoles.length === 0) {
    return true;
  }
  
  // Récupérer l'utilisateur actuel
  const currentUser = storageService.getCurrentUser();
  
  if (!currentUser) {
    router.navigate(['/login']);
    return false;
  }
  
  const userRole = currentUser.role || 'client';
  
  // Vérifier si le rôle de l'utilisateur est dans la liste des rôles autorisés
  if (allowedRoles.includes(userRole)) {
    return true;
  }
  
  // Rediriger vers la page appropriée
  router.navigate(['/unauthorized']);
  return false;
};