import matplotlib.pyplot as plt

# Exemple : accuracy des données test et validation
labels = ['Test', 'Validation']
values = [1.0000, 0.9990]

plt.figure(figsize=(6, 4))
bars = plt.bar(labels, values, color=['green', 'blue'])

# Affichage des valeurs sur les barres
for bar in bars:
    yval = bar.get_height()
    plt.text(bar.get_x() + bar.get_width()/2.0, yval + 0.001, f"{yval:.4f}", ha='center', va='bottom')

plt.ylim(0.95, 1.01)
plt.title('Accuracy du modèle')
plt.ylabel('Accuracy')
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.tight_layout()
plt.show()
