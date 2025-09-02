import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

export type UserDocument = User & Document;

@Schema({ collection: 'utilisateur' })
export class User {
  @Prop({ required: true })
  idutilisateur: number;

  @Prop({ 
    required: true,
    maxlength: 100
  })
  nomutilisateur: string;

  @Prop({ 
    required: true,
    maxlength: 100,
    unique: true
  })
  email: string;

  @Prop({ 
    required: true,
    maxlength: 255,
    select: false
  })
  motdepasse: string;

  @Prop({ 
    required: true,
    maxlength: 50
  })
  role: string;

  @Prop({ 
    default: Date.now
  })
  datecreation: Date;

  @Prop({ 
    default: true
  })
  estactif: boolean;
}

export const UserSchema = SchemaFactory.createForClass(User);

// Index pour l'email unique
UserSchema.index({ email: 1 }, { unique: true });