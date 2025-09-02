// src/shared/dto/base.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class BaseDto {
  @ApiProperty({
    description: 'Date de création',
    type: Date,
    required: false,
  })
  createdAt?: Date;

  @ApiProperty({
    description: 'Date de mise à jour',
    type: Date,
    required: false,
  })
  updatedAt?: Date;
}