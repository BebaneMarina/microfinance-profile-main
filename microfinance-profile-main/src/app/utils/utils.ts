// utils/utils.ts
export function isUserInRole(role: string): boolean {
  const rolesString = sessionStorage.getItem('roles');
  if (!rolesString) return false;

  // Si format string simple séparé par des virgules
  const roles = rolesString.split(',');
  return roles.includes(role);
}
