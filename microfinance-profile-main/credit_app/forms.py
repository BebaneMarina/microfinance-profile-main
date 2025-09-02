from flask_wtf import FlaskForm
from wtforms import (
    StringField, IntegerField, SelectField, TextAreaField, 
    BooleanField, SubmitField
)
from wtforms.validators import DataRequired, NumberRange, Length, Optional

class CreditForm(FlaskForm):
    # Étape 1: Informations du crédit
    credit_type = SelectField('Type de crédit', validators=[DataRequired()])
    amount = IntegerField('Montant demandé (FCFA)', validators=[
        DataRequired(),
        NumberRange(min=50000, max=10000000)
    ])
    duration = SelectField('Durée', validators=[DataRequired()])
    purpose = TextAreaField('Objet du crédit', validators=[
        DataRequired(),
        Length(min=10, max=500)
    ])
    
    # Étape 2: Informations financières
    monthly_income = IntegerField('Revenus mensuels (FCFA)', validators=[
        DataRequired(),
        NumberRange(min=100000)
    ])
    income_type = SelectField('Type de revenus', validators=[DataRequired()])
    other_income = IntegerField('Autres revenus (FCFA)', validators=[Optional()])
    monthly_expenses = IntegerField('Charges mensuelles (FCFA)', validators=[
        DataRequired(),
        NumberRange(min=0)
    ])
    existing_debts = IntegerField('Dettes existantes (FCFA)', validators=[Optional()])
    
    # Étape 3: Garanties
    guarantor_name = StringField('Nom complet du garant', validators=[
        DataRequired(),
        Length(max=100)
    ])
    guarantor_phone = StringField('Téléphone du garant', validators=[
        DataRequired(),
        Length(min=8, max=20)
    ])
    guarantor_address = TextAreaField('Adresse du garant', validators=[
        DataRequired(),
        Length(max=200)
    ])
    collateral = StringField('Description de la garantie', validators=[
        Optional(),
        Length(max=100)
    ])
    collateral_value = IntegerField('Valeur estimée (FCFA)', validators=[Optional()])
    
    # Étape 4: Documents
    id_document = BooleanField('Pièce d\'identité valide')
    proof_income = BooleanField('Justificatif de revenus')
    proof_residence = BooleanField('Justificatif de domicile')
    guarantor_id = BooleanField('Pièce d\'identité du garant')
    additional_notes = TextAreaField('Notes additionnelles', validators=[Optional()])
    
    # Boutons de navigation
    previous_step = SubmitField('Précédent')
    next_step = SubmitField('Suivant')
    submit = SubmitField('Soumettre la demande')