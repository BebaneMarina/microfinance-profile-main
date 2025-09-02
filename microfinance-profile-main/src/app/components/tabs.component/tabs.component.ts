import { Component, EventEmitter, Input, Output } from '@angular/core';

@Component({
  selector: 'app-tabs',
  standalone: true,
  templateUrl: './tabs.component.html',
  styleUrls: ['./tabs.component.scss']
})
export class TabsComponent {
  @Input() activeTab = 'profile';
  @Output() tabChange = new EventEmitter<string>();

  setTab(tab: string): void {
    this.activeTab = tab;
    this.tabChange.emit(tab);
  }
}