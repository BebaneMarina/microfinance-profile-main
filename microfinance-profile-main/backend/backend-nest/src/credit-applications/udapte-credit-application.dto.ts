import { PartialType } from '@nestjs/mapped-types';
import { CreateCreditApplicationDto } from './create-credit-application.dto';
import { IsOptional, IsString } from 'class-validator';

export class UpdateCreditApplicationDto extends PartialType(CreateCreditApplicationDto) {
  @IsOptional()
  @IsString()
  status?: string;
}