import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ClientProfil } from '../../models/monprofil.model';

@Component({
  selector: 'monprofile',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './monprofil.component.html',
  styleUrls: ['./monprofil.component.scss']
})
export class MonprofilComponent implements OnInit {
  client: ClientProfil = {
    profileImage: '',
    name: 'marina brunelle',
    initiales: 'MK',
    accountNumber: '1234567890',
    fullName: 'marina brunelle',
    birthDate: '1985-05-15',
    birthPlace: 'Libreville',
    gender: 'feminin',
    maritalStatus: 'Marié',
    children: 2,
    phone1: '+241 77 12 34 56',
    phone2: '+241 66 78 90 12',
    email: 'marina@email.com',
    city: 'Libreville',
    district: 'Centre-ville',
    address: '123 Rue de la Paix',
    idExpiryDate: '2028-12-31',
    profession: 'Ingénieur',
    employer: 'Société ABC',
    monthlyIncome: 1500000,
    workExperience: 10,
    idType: 'CNI',
    idNumber: 'GA123456789',
    idIssueDate: '2023-01-15'
  };

  isEditing: boolean = false;
  showSuccessMessage: boolean = false;
  activeTab: string = 'personal';

  constructor(private router: Router) {}

  ngOnInit(): void {
    this.loadClientProfile();
  }

  loadClientProfile(): void {
    // Charger le profil depuis le service
  }

  toggleEdit(): void {
    this.isEditing = !this.isEditing;
  }

  saveProfile(): void {
    // Sauvegarder les modifications
    this.isEditing = false;
    this.showSuccessMessage = true;
    
    setTimeout(() => {
      this.showSuccessMessage = false;
    }, 3000);
  }

  cancelEdit(): void {
    this.isEditing = false;
    this.loadClientProfile(); // Recharger les données originales
  }

  changeProfileImage(): void {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = (e: any) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (event: any) => {
          this.client.profileImage = event.target.result;
        };
        reader.readAsDataURL(file);
      }
    };
    input.click();
  }
}