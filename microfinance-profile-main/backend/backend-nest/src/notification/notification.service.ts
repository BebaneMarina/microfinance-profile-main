import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from '../entities/notification.entity';

@Injectable()
export class NotificationsService {
  [x: string]: any;
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private notificationRepository: Repository<Notification>,
  ) {}

  // ... autres méthodes ...

  async markAsRead(id: number): Promise<Notification> {
    await this.notificationRepository.update(id, {
      isRead: true,
      readAt: new Date(),
    });

    const notification = await this.notificationRepository.findOne({ where: { id } });
    
    if (!notification) {
      throw new NotFoundException(`Notification #${id} not found`);
    }

    return notification;
  }
}