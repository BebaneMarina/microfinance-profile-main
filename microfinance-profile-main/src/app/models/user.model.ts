// src/app/models/user.model.ts
export interface User {
  profileImage?: string;
  name?: string;
  role?: string;
  // autres propriétés utilisateur si nécessaire
}

// Pour les éléments de navigation
export interface NavItem {
  label: string;
  route: string;
  icon?: string;
}