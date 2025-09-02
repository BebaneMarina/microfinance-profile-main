import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CreditSimulateurComponent } from './credit-simulation.component';

describe('CreditSimulationComponent', () => {
  let component: CreditSimulateurComponent;
  let fixture: ComponentFixture<CreditSimulateurComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CreditSimulateurComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(CreditSimulateurComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
