import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import ConfusionMatrixDisplay

# Exemple : matrice 3 classes (copie celle reçue dans test_retrain)
matrice = [
    [559, 0, 0],
    [0, 728, 0],
    [0, 0, 713]
]

# Classe optionnelle (noms)
classes = ['Classe 0', 'Classe 1', 'Classe 2']

# Convertir en array numpy
cm = np.array(matrice)

# Afficher le graphique
disp = ConfusionMatrixDisplay(confusion_matrix=cm, display_labels=classes)
disp.plot(cmap=plt.cm.Blues, values_format='.0f')
plt.title("Matrice de confusion - Données test")
plt.grid(False)
plt.tight_layout()
plt.show()
