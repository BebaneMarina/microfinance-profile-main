import { IsNotEmpty, IsNumber } from 'class-validator';

export class CreateScoringDto {
  @IsNotEmpty()
  @IsNumber()
  creditRequestId: number;
}