// interfaces/scoring-engine.interface.ts
import { CreditScoringRequestDto } from '../dto/credit-scoring-request.dto';
import { CreditScoringResponseDto } from '../dto/credit-scoring-response.dto';
import { ScoringHistoryDto } from '../dto/scoring-history.dto';

export interface ScoringEngineInterface {
  evaluateCredit(creditData: CreditScoringRequestDto): Promise<CreditScoringResponseDto>;
  getScoringHistory(clientId: string, limit: number): Promise<ScoringHistoryDto[]>;
  getScoringStatistics(): Promise<any>;
  retrainModel(): Promise<any>;
}