import { ComponentFixture, TestBed } from '@angular/core/testing';

import { MultiBankComparatorComponent } from './multi-bank-comparator.component';

describe('MultiBankComparatorComponent', () => {
  let component: MultiBankComparatorComponent;
  let fixture: ComponentFixture<MultiBankComparatorComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [MultiBankComparatorComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(MultiBankComparatorComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
