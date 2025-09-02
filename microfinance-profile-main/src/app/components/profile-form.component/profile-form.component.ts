import { Component, EventEmitter, Output } from '@angular/core';
import { ClientService } from '../../services/client.service';
import { ClientProfile } from '../../models/client.model';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-profile-form',
  standalone: true,
  imports: [FormsModule],
  templateUrl: './profile-form.component.html',
  styleUrls: ['./profile-form.component.scss']
})
export class ProfileFormComponent {
  profile: ClientProfile;
  originalProfile: ClientProfile;

  @Output() save = new EventEmitter<ClientProfile>();

  constructor(private clientService: ClientService) {
    this.profile = { ...this.clientService.getProfile() };
    this.originalProfile = { ...this.profile };
  }

  saveProfile(): void {
    if (!this.profile.fullName || !this.profile.phone1) {
      alert('Les champs nom et téléphone sont obligatoires');
      return;
    }

    this.clientService.updateProfile(this.profile);
    this.originalProfile = { ...this.profile };
    this.save.emit(this.profile);
    alert('Profil enregistré avec succès!');
  }

  resetForm(): void {
    if (confirm('Annuler toutes les modifications?')) {
      this.profile = { ...this.originalProfile };
    }
  }
}