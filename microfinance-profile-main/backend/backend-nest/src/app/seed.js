"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g = Object.create((typeof Iterator === "function" ? Iterator : Object).prototype);
    return g.next = verb(0), g["throw"] = verb(1), g["return"] = verb(2), typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (g && (g = 0, op[0] && (_ = 0)), _) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.seedUsers = seedUsers;
exports.verifyData = verifyData;
var pg_1 = require("pg");
var bcrypt = require("bcrypt");
// Configuration de la base de données
var pool = new pg_1.Pool({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'credit_scoring',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'admin',
});
var userData = [
    // ADMINISTRATEURS
    {
        email: 'admin@entreprise.com',
        password: 'admin123',
        two_factor_enabled: true,
        role: 'admin',
        username: 'admin_principal',
        is_active: true,
        profile: {
            nom: 'Martin',
            prenom: 'Pierre',
            telephone: '+33123456789',
            departement: 'Direction'
        },
        last_login: '2024-06-19 14:30:00+00'
    },
    {
        email: 'superadmin@entreprise.com',
        password: 'superadmin456',
        two_factor_enabled: true,
        role: 'admin',
        username: 'super_admin',
        is_active: true,
        profile: {
            nom: 'Dubois',
            prenom: 'Marie',
            telephone: '+33987654321',
            departement: 'IT'
        },
        last_login: '2024-06-20 09:15:00+00'
    },
    // EMPLOYÉS
    {
        email: 'employe1@entreprise.com',
        password: 'employe123',
        two_factor_enabled: false,
        role: 'employee',
        username: 'jean_dupont',
        is_active: true,
        profile: {
            nom: 'Dupont',
            prenom: 'Jean',
            telephone: '+33456789123',
            departement: 'Ventes',
            poste: 'Commercial'
        },
        last_login: '2024-06-20 08:45:00+00'
    },
    {
        email: 'employe2@entreprise.com',
        password: 'employe456',
        two_factor_enabled: true,
        role: 'employee',
        username: 'sophie_martin',
        is_active: true,
        profile: {
            nom: 'Martin',
            prenom: 'Sophie',
            telephone: '+33789123456',
            departement: 'RH',
            poste: 'Responsable RH'
        },
        last_login: '2024-06-19 16:20:00+00'
    },
    {
        email: 'employe3@entreprise.com',
        password: 'employe789',
        two_factor_enabled: false,
        role: 'employee',
        username: 'lucas_bernard',
        is_active: true,
        profile: {
            nom: 'Bernard',
            prenom: 'Lucas',
            telephone: '+33321654987',
            departement: 'Technique',
            poste: 'Développeur'
        },
        last_login: '2024-06-20 07:30:00+00'
    },
    // CLIENTS
    {
        email: 'client1@email.com',
        password: 'client123',
        two_factor_enabled: false,
        role: 'client',
        username: 'client_alpha',
        is_active: true,
        profile: {
            nom: 'Moreau',
            prenom: 'Paul',
            telephone: '+33654987321',
            adresse: '15 rue de la Paix, Paris',
            type_client: 'Particulier'
        },
        last_login: '2024-06-18 11:00:00+00'
    },
    {
        email: 'client2@email.com',
        password: 'client456',
        two_factor_enabled: true,
        role: 'client',
        username: 'client_beta',
        is_active: true,
        profile: {
            nom: 'Leroy',
            prenom: 'Anne',
            telephone: '+33147258369',
            adresse: '22 avenue des Champs, Lyon',
            type_client: 'Particulier'
        },
        last_login: '2024-06-19 13:45:00+00'
    },
    {
        email: 'entreprise@client.com',
        password: 'client789',
        two_factor_enabled: false,
        role: 'client',
        username: 'client_entreprise',
        is_active: true,
        profile: {
            nom: 'TechCorp',
            siret: '12345678901234',
            telephone: '+33159753486',
            adresse: '100 rue de l Innovation, Toulouse',
            type_client: 'Entreprise',
            contact: 'Michel Roux'
        },
        last_login: '2024-06-17 15:30:00+00'
    },
    {
        email: 'nouveau.client@email.com',
        password: 'nouveauclient123',
        two_factor_enabled: false,
        role: 'client',
        username: 'nouveau_client',
        is_active: true,
        profile: {
            nom: 'Petit',
            prenom: 'Julie',
            telephone: '+33698765432',
            adresse: '8 place du Marché, Bordeaux',
            type_client: 'Particulier'
        }
    },
    {
        email: 'ancien.client@email.com',
        password: 'ancienclient123',
        two_factor_enabled: false,
        role: 'client',
        username: 'ancien_client',
        is_active: false,
        profile: {
            nom: 'Ancier',
            prenom: 'Robert',
            telephone: '+33612345678',
            adresse: '5 rue Ancienne, Marseille',
            type_client: 'Particulier',
            raison_desactivation: 'Compte ferme a la demande du client'
        },
        last_login: '2024-05-15 10:20:00+00'
    }
];
function hashPassword(password) {
    return __awaiter(this, void 0, void 0, function () {
        var saltRounds;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    saltRounds = 12;
                    return [4 /*yield*/, bcrypt.hash(password, saltRounds)];
                case 1: return [2 /*return*/, _a.sent()];
            }
        });
    });
}
function clearUsersTable() {
    return __awaiter(this, void 0, void 0, function () {
        var error_1;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, , 4]);
                    return [4 /*yield*/, pool.query('DELETE FROM public.users')];
                case 1:
                    _a.sent();
                    return [4 /*yield*/, pool.query('ALTER SEQUENCE users_user_id_seq RESTART WITH 1')];
                case 2:
                    _a.sent();
                    console.log('✅ Table users vidée et séquence remise à zéro');
                    return [3 /*break*/, 4];
                case 3:
                    error_1 = _a.sent();
                    console.error('❌ Erreur lors du vidage de la table:', error_1);
                    throw error_1;
                case 4: return [2 /*return*/];
            }
        });
    });
}
function insertUser(user) {
    return __awaiter(this, void 0, void 0, function () {
        var client, hashedPassword, query, values, result, error_2;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0: return [4 /*yield*/, pool.connect()];
                case 1:
                    client = _a.sent();
                    _a.label = 2;
                case 2:
                    _a.trys.push([2, 5, 6, 7]);
                    return [4 /*yield*/, hashPassword(user.password)];
                case 3:
                    hashedPassword = _a.sent();
                    query = "\n      INSERT INTO public.users (\n        email, \n        password_hash, \n        two_factor_enabled, \n        role, \n        username, \n        password, \n        is_active,\n        profile,\n        last_login\n      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)\n      RETURNING user_id, email, username, role\n    ";
                    values = [
                        user.email,
                        hashedPassword,
                        user.two_factor_enabled,
                        user.role,
                        user.username,
                        user.password, // Mot de passe en clair (à des fins de développement uniquement)
                        user.is_active,
                        JSON.stringify(user.profile),
                        user.last_login || null
                    ];
                    return [4 /*yield*/, client.query(query, values)];
                case 4:
                    result = _a.sent();
                    console.log("\u2705 Utilisateur cr\u00E9\u00E9: ".concat(result.rows[0].username, " (").concat(result.rows[0].role, ") - ID: ").concat(result.rows[0].user_id));
                    return [3 /*break*/, 7];
                case 5:
                    error_2 = _a.sent();
                    console.error("\u274C Erreur lors de l'insertion de ".concat(user.email, ":"), error_2);
                    throw error_2;
                case 6:
                    client.release();
                    return [7 /*endfinally*/];
                case 7: return [2 /*return*/];
            }
        });
    });
}
function seedUsers() {
    return __awaiter(this, void 0, void 0, function () {
        var _i, userData_1, user, summary, error_3;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    console.log('🌱 Démarrage du seeding de la table users...\n');
                    _a.label = 1;
                case 1:
                    _a.trys.push([1, 8, , 9]);
                    // Vider la table existante
                    return [4 /*yield*/, clearUsersTable()];
                case 2:
                    // Vider la table existante
                    _a.sent();
                    _i = 0, userData_1 = userData;
                    _a.label = 3;
                case 3:
                    if (!(_i < userData_1.length)) return [3 /*break*/, 6];
                    user = userData_1[_i];
                    return [4 /*yield*/, insertUser(user)];
                case 4:
                    _a.sent();
                    _a.label = 5;
                case 5:
                    _i++;
                    return [3 /*break*/, 3];
                case 6:
                    console.log("\n\u2705 Seeding termin\u00E9 avec succ\u00E8s! ".concat(userData.length, " utilisateurs ins\u00E9r\u00E9s."));
                    return [4 /*yield*/, pool.query("\n      SELECT \n        role,\n        COUNT(*) as count,\n        COUNT(CASE WHEN is_active = true THEN 1 END) as active_count\n      FROM public.users \n      GROUP BY role \n      ORDER BY role\n    ")];
                case 7:
                    summary = _a.sent();
                    console.log('\n📊 Résumé des utilisateurs créés:');
                    summary.rows.forEach(function (row) {
                        console.log("   ".concat(row.role, ": ").concat(row.count, " total (").concat(row.active_count, " actifs)"));
                    });
                    return [3 /*break*/, 9];
                case 8:
                    error_3 = _a.sent();
                    console.error('❌ Erreur lors du seeding:', error_3);
                    process.exit(1);
                    return [3 /*break*/, 9];
                case 9: return [2 /*return*/];
            }
        });
    });
}
function verifyData() {
    return __awaiter(this, void 0, void 0, function () {
        var result, error_4;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 2, , 3]);
                    return [4 /*yield*/, pool.query("\n      SELECT \n        user_id,\n        email,\n        username,\n        role,\n        is_active,\n        two_factor_enabled,\n        created_at,\n        last_login,\n        profile->>'nom' as nom,\n        profile->>'prenom' as prenom\n      FROM public.users\n      ORDER BY role, user_id\n    ")];
                case 1:
                    result = _a.sent();
                    console.log('\n🔍 Vérification des données insérées:');
                    result.rows.forEach(function (user) {
                        console.log("   ".concat(user.user_id, ": ").concat(user.username, " (").concat(user.email, ") - ").concat(user.role, " - ").concat(user.is_active ? 'Actif' : 'Inactif'));
                    });
                    return [3 /*break*/, 3];
                case 2:
                    error_4 = _a.sent();
                    console.error('❌ Erreur lors de la vérification:', error_4);
                    return [3 /*break*/, 3];
                case 3: return [2 /*return*/];
            }
        });
    });
}
function main() {
    return __awaiter(this, void 0, void 0, function () {
        var error_5;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    _a.trys.push([0, 3, 4, 6]);
                    return [4 /*yield*/, seedUsers()];
                case 1:
                    _a.sent();
                    return [4 /*yield*/, verifyData()];
                case 2:
                    _a.sent();
                    return [3 /*break*/, 6];
                case 3:
                    error_5 = _a.sent();
                    console.error('❌ Erreur fatale:', error_5);
                    process.exit(1);
                    return [3 /*break*/, 6];
                case 4: return [4 /*yield*/, pool.end()];
                case 5:
                    _a.sent();
                    console.log('\n🔚 Connexion à la base de données fermée.');
                    return [7 /*endfinally*/];
                case 6: return [2 /*return*/];
            }
        });
    });
}
// Exécuter le script
if (require.main === module) {
    main().catch(console.error);
}
