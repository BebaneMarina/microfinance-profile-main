// footer.component.ts
import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-footer',
  standalone: true,
  imports: [CommonModule],
  template: `
    <footer class="footer" [class.sidebar-collapsed]="sidebarCollapsed">
      <div class="footer-content">
        <!-- Left Section - Copyright -->
        <div class="footer-left">
          <p class="copyright">
            Copyright © 2024 
            <a href="#" class="company-link">Pecubox</a>. 
            <span class="footer-links">
              <a href="/privacy">Privacy Policy</a>
              <span class="divider">|</span>
              <a href="/terms">Terms of Use</a>
              <span class="divider">|</span>
              <a href="/contact">Contact</a>
            </span>
          </p>
        </div>

        <!-- Right Section - Additional Links -->
        <div class="footer-right">
          <div class="footer-actions">
            <a href="/help" class="footer-link">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <path d="M8 0C3.58172 0 0 3.58172 0 8C0 12.4183 3.58172 16 8 16C12.4183 16 16 12.4183 16 8C16 3.58172 12.4183 0 8 0ZM8 12C7.44772 12 7 11.5523 7 11C7 10.4477 7.44772 10 8 10C8.55228 10 9 10.4477 9 11C9 11.5523 8.55228 12 8 12ZM9 8.5C9 8.77614 8.77614 9 8.5 9H7.5C7.22386 9 7 8.77614 7 8.5V8C7 6.89543 7.89543 6 9 6C9.55228 6 10 5.55228 10 5C10 4.44772 9.55228 4 9 4C8.44772 4 8 4.44772 8 5H7C7 3.89543 7.89543 3 9 3C10.1046 3 11 3.89543 11 5C11 6.10457 10.1046 7 9 7V8.5Z" fill="currentColor"/>
              </svg>
              Help Center
            </a>
            
            <a href="/support" class="footer-link">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                <path d="M8 1C4.13401 1 1 4.13401 1 8C1 11.866 4.13401 15 8 15C11.866 15 15 11.866 15 8C15 4.13401 11.866 1 8 1ZM8 4C8.55228 4 9 4.44772 9 5C9 5.55228 8.55228 6 8 6C7.44772 6 7 5.55228 7 5C7 4.44772 7.44772 4 8 4ZM10 12H6V11H7V8H6V7H9V11H10V12Z" fill="currentColor"/>
              </svg>
              Support
            </a>

            <div class="version-info">
              <span class="version">v2.1.0</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile Footer -->
      <div class="mobile-footer">
        <div class="mobile-footer-content">
          <p class="mobile-copyright">© 2024 Pecubox</p>
          <div class="mobile-links">
            <a href="/help">Help</a>
            <a href="/support">Support</a>
            <a href="/privacy">Privacy</a>
          </div>
        </div>
      </div>
    </footer>
  `,
  styles: [`
    .footer {
      position: fixed;
      bottom: 0;
      left: 280px;
      right: 0;
      height: 60px;
      background: #ffffff;
      border-top: 1px solid #e5e7eb;
      z-index: 998;
      transition: left 0.3s ease;
    }

    .footer.sidebar-collapsed {
      left: 72px;
    }

    .footer-content {
      display: flex;
      align-items: center;
      justify-content: space-between;
      height: 100%;
      padding: 0 32px;
    }

    .footer-left {
      flex: 1;
    }

    .copyright {
      font-size: 13px;
      color: #6b7280;
      margin: 0;
      display: flex;
      align-items: center;
      gap: 8px;
      flex-wrap: wrap;
    }

    .company-link {
      color: #4f46e5;
      text-decoration: none;
      font-weight: 600;
      transition: color 0.2s ease;
    }

    .company-link:hover {
      color: #3730a3;
    }

    .footer-links {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .footer-links a {
      color: #6b7280;
      text-decoration: none;
      font-size: 13px;
      transition: color 0.2s ease;
    }

    .footer-links a:hover {
      color: #374151;
    }

    .divider {
      color: #d1d5db;
    }

    .footer-right {
      display: flex;
      align-items: center;
    }

    .footer-actions {
      display: flex;
      align-items: center;
      gap: 20px;
    }

    .footer-link {
      display: flex;
      align-items: center;
      gap: 6px;
      color: #6b7280;
      text-decoration: none;
      font-size: 13px;
      font-weight: 500;
      transition: all 0.2s ease;
      padding: 6px 12px;
      border-radius: 6px;
    }

    .footer-link:hover {
      color: #4f46e5;
      background-color: #f3f4f6;
    }

    .footer-link svg {
      width: 14px;
      height: 14px;
    }

    .version-info {
      display: flex;
      align-items: center;
      padding: 4px 8px;
      background-color: #f3f4f6;
      border-radius: 12px;
      border: 1px solid #e5e7eb;
    }

    .version {
      font-size: 11px;
      color: #6b7280;
      font-weight: 600;
      font-family: 'Courier New', monospace;
    }

    .mobile-footer {
      display: none;
      padding: 16px;
      background: #f9fafb;
      border-top: 1px solid #e5e7eb;
    }

    .mobile-footer-content {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
    }

    .mobile-copyright {
      font-size: 12px;
      color: #6b7280;
      margin: 0;
    }

    .mobile-links {
      display: flex;
      gap: 16px;
    }

    .mobile-links a {
      font-size: 12px;
      color: #6b7280;
      text-decoration: none;
      transition: color 0.2s ease;
    }

    .mobile-links a:hover {
      color: #4f46e5;
    }

    /* Tablet Styles */
    @media (max-width: 1024px) and (min-width: 769px) {
      .footer {
        left: 240px;
        padding: 0 24px;
      }

      .footer.sidebar-collapsed {
        left: 64px;
      }

      .footer-content {
        padding: 0 24px;
      }

      .footer-actions {
        gap: 16px;
      }

      .footer-links {
        display: none;
      }
    }

    /* Mobile Styles */
    @media (max-width: 768px) {
      .footer {
        left: 0;
        height: auto;
        position: relative;
      }

      .footer.sidebar-collapsed {
        left: 0;
      }

      .footer-content {
        display: none;
      }

      .mobile-footer {
        display: block;
      }
    }

    /* Small Mobile Styles */
    @media (max-width: 480px) {
      .mobile-links {
        gap: 12px;
      }

      .mobile-links a {
        font-size: 11px;
      }

      .mobile-copyright {
        font-size: 11px;
      }
    }

    /* Print Styles */
    @media print {
      .footer {
        display: none;
      }
    }
  `]
})
export class FooterComponent {
  @Input() sidebarCollapsed: boolean = false;
}