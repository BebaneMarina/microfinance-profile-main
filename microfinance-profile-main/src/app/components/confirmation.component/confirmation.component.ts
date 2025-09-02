// confirmation.component.ts
import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

@Component({
  selector: 'app-confirmation',
  templateUrl: './confirmation.component.html',
  styleUrls: ['./confirmation.component.scss']
})
export class ConfirmationComponent implements OnInit {
  applicationId!: string; 

  constructor(private route: ActivatedRoute, private router: Router) { }

  ngOnInit(): void {
    const navigation = this.router.getCurrentNavigation();
    this.applicationId = navigation?.extras?.state?.['applicationId'];
    
    if (!this.applicationId) {
      // Rediriger si pas d'ID
      this.router.navigate(['/']);
    }
  }
}