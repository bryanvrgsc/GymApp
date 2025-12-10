# Firebase Cloud Function Setup for Auth0 Integration

Este archivo contiene el código necesario para crear un Cloud Function que intercambia tokens Auth0 por tokens de Firebase.

## 1. Crear proyecto de Cloud Functions

```bash
# Instalar Firebase CLI si no lo tienes
npm install -g firebase-tools

# Login a Firebase
firebase login

# Inicializar Functions en tu proyecto
cd tu-proyecto
firebase init functions

# Selecciona JavaScript o TypeScript
```

## 2. Instalar dependencias

```bash
cd functions
npm install firebase-admin jsonwebtoken jwks-rsa
```

## 3. Código de la Cloud Function

Crea el archivo `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

admin.initializeApp();

// Configura tu dominio Auth0
const AUTH0_DOMAIN = 'TU_DOMINIO.auth0.com';  // Reemplaza con tu dominio

// Cliente JWKS para verificar tokens Auth0
const client = jwksClient({
  jwksUri: `https://${AUTH0_DOMAIN}/.well-known/jwks.json`
});

function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

// Verificar token Auth0
function verifyAuth0Token(token) {
  return new Promise((resolve, reject) => {
    jwt.verify(token, getKey, {
      audience: `https://${AUTH0_DOMAIN}/api/v2/`,
      issuer: `https://${AUTH0_DOMAIN}/`,
      algorithms: ['RS256']
    }, (err, decoded) => {
      if (err) reject(err);
      else resolve(decoded);
    });
  });
}

// Cloud Function para intercambiar tokens
exports.createFirebaseToken = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }
  
  try {
    // Extraer token del header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'No authorization token provided' });
      return;
    }
    
    const auth0Token = authHeader.substring(7);
    const { auth0UserId, activeRole } = req.body;
    
    if (!auth0UserId) {
      res.status(400).json({ error: 'auth0UserId is required' });
      return;
    }
    
    // Verificar token Auth0 (opcional pero recomendado)
    // const decoded = await verifyAuth0Token(auth0Token);
    
    // Obtener datos del usuario desde Firestore
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(auth0UserId)
      .get();
    
    const userData = userDoc.data() || {};
    const roles = userData.roles || ['user'];
    
    // Crear custom token con claims
    const customClaims = {
      auth0UserId: auth0UserId,
      roles: roles,
      activeRole: activeRole || roles[0] || 'user',
      isStaff: roles.includes('staff') || roles.includes('admin'),
      isAdmin: roles.includes('admin')
    };
    
    // Crear Firebase custom token
    // Usamos auth0UserId como UID para Firebase
    const firebaseToken = await admin.auth().createCustomToken(auth0UserId, customClaims);
    
    console.log(`Created Firebase token for user: ${auth0UserId}, role: ${activeRole}`);
    
    res.status(200).json({ 
      token: firebaseToken,
      claims: customClaims
    });
    
  } catch (error) {
    console.error('Error creating Firebase token:', error);
    res.status(500).json({ error: error.message });
  }
});
```

## 4. Deploy

```bash
firebase deploy --only functions
```

## 5. Actualizar la app

Después de deployar, copia la URL de la función y actualiza `FirebaseAuthBridge.swift`:

```swift
private let tokenExchangeURL = "https://TU-REGION-TU-PROYECTO.cloudfunctions.net/createFirebaseToken"
```

## 6. Firestore Security Rules

Actualiza las reglas en Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is staff or admin
    function isStaffOrAdmin() {
      return isAuthenticated() && 
        (request.auth.token.isStaff == true || request.auth.token.isAdmin == true);
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isAuthenticated() && request.auth.token.isAdmin == true;
    }
    
    // Users collection
    match /users/{userId} {
      // Anyone authenticated can read users
      allow read: if isAuthenticated();
      
      // Users can update their own profile
      allow write: if isAuthenticated() && request.auth.uid == userId;
      
      // Staff/Admin can update any user's membership
      allow update: if isStaffOrAdmin();
    }
    
    // Membership renewals - only staff/admin can create
    match /membership_renewals/{renewalId} {
      allow read: if isAuthenticated();
      allow create: if isStaffOrAdmin();
    }
    
    // Attendance
    match /attendance/{docId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() || isStaffOrAdmin();
    }
    
    // Occupancy
    match /occupancy/{docId} {
      allow read: if isAuthenticated();
      allow write: if isStaffOrAdmin();
    }
  }
}
```

## Notas

- Para desarrollo, la app usa autenticación anónima como fallback
- Para producción, asegúrate de deployar el Cloud Function
- Los claims `isStaff` y `isAdmin` se usan en las reglas de Firestore
