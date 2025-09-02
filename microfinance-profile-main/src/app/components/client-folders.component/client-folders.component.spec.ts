import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ClientFoldersComponent } from './client-folders.component';

describe('ClientFoldersComponent', () => {
  let component: ClientFoldersComponent;
  let fixture: ComponentFixture<ClientFoldersComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ClientFoldersComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ClientFoldersComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
