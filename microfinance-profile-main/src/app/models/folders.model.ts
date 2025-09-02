export interface Folder {
  name: string;
  status: 'approved' | 'pending' | 'review';
  statusText: string;
}