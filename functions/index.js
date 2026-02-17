const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

setGlobalOptions({ 
  maxInstances: 10, timeoutSeconds: 300, memory: "256MiB", region: "us-central1" 
});

// 1. CONECTAR
exports.conectarSimpleFin = onCall(async (request) => {
  const data = request.data;
  const uid = (request.auth && request.auth.uid) || data.uid;
  const setupToken = data.setupToken;
  
  if (!uid) throw new HttpsError('invalid-argument', 'Faltan datos.');
  
  try {
    const claimUrl = Buffer.from(setupToken, 'base64').toString('utf-8');
    const response = await axios.post(claimUrl);
    
    await admin.firestore().collection('artifacts').doc('finanzas_app').collection('users').doc(uid).set({
      simpleFinUrl: response.data, 
      simpleFinConnected: true, 
      lastUpdate: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    await sincronizarDatos(uid, response.data);
    return { success: true };
  } catch (error) { throw new HttpsError('unknown', error.message); }
});

// 2. SINCRONIZAR
exports.sincronizarAhora = onCall(async (request) => {
  const uid = (request.auth && request.auth.uid) || request.data.uid;
  if (!uid) throw new HttpsError('invalid-argument', 'Falta UID.');
  
  try {
    const doc = await admin.firestore().collection('artifacts').doc('finanzas_app').collection('users').doc(uid).get();
    if (!doc.exists || !doc.data().simpleFinUrl) throw new HttpsError('failed-precondition', 'No banco.');
    
    await sincronizarDatos(uid, doc.data().simpleFinUrl);
    return { success: true };
  } catch (error) { throw new HttpsError('internal', error.message); }
});

// 3. IMPORTAR MOVIMIENTOS DESDE TEXTO (BILT WORKAROUND)
exports.importarMovimientosTexto = onCall(async (request) => {
  const uid = (request.auth && request.auth.uid) || request.data.uid;
  const texto = request.data.texto;
  const accountId = request.data.accountId;

  if (!uid || !texto || !accountId) throw new HttpsError('invalid-argument', 'Faltan datos.');

  try {
    const userRef = admin.firestore().collection('artifacts').doc('finanzas_app').collection('users').doc(uid);
    const batch = admin.firestore().batch();
    
    // Cargar reglas de usuario
    const rulesSnap = await userRef.collection('category_rules').get();
    const userRules = {};
    rulesSnap.forEach(doc => { userRules[doc.id] = doc.data().category; });

    // --- PARSEO INTELIGENTE DE TEXTO ---
    const lineas = texto.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    let fechaActual = new Date(); // Fallback
    
    // Regex para detectar fechas (ej: February 14, 2026, Yesterday, Today)
    const regexFecha = /^(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},\s+\d{4}$/i;
    
    let buffer = []; // Para acumular líneas entre fechas
    let totalImportado = 0; // Para actualizar balance

    for (let i = 0; i < lineas.length; i++) {
        const linea = lineas[i];

        // 1. Detectar Fecha
        if (linea.toUpperCase() === 'TODAY') {
            fechaActual = new Date();
            continue;
        }
        if (linea.toUpperCase() === 'YESTERDAY') {
            fechaActual = new Date();
            fechaActual.setDate(fechaActual.getDate() - 1);
            continue;
        }
        if (regexFecha.test(linea)) {
            fechaActual = new Date(linea);
            continue;
        }

        // 2. Detectar Bloque de Transacción
        // Estructura típica: [Nombre] -> [Monto] -> [Pending/Status - opcional]
        // Si la línea actual NO es fecha, y la SIGUIENTE empieza con $, es un par Nombre-Monto
        
        if (i + 1 < lineas.length) {
            const siguienteLinea = lineas[i+1];
            if (siguienteLinea.startsWith('$') || siguienteLinea.startsWith('-$')) {
                // ¡Encontrado!
                const nombreRaw = linea;
                const montoRaw = siguienteLinea.replace('$', '').replace(',', '');
                const monto = parseFloat(montoRaw);
                
                totalImportado += monto; // Sumar al total (positivo = gasto, negativo = pago)

                // Saltamos la línea de monto para el próximo ciclo
                i++; 
                
                // Si la siguiente línea es "Pending", la saltamos también
                if (i + 1 < lineas.length && lineas[i+1].toUpperCase() === 'PENDING') {
                    i++;
                }

                // --- PROCESAR TRANSACCIÓN (Reutilizando lógica) ---
                const rawText = nombreRaw.toUpperCase();
                let nombreFinal = nombreRaw;
                let categoriaFinal = "Otros";
                let tipoMovimiento = (monto < 0) ? 'expense' : 'income'; // En Bilt, gastos son positivos en la UI, pagos negativos?
                // AJUSTE BILT: En el texto pegado:
                // McDonald's $6.80 -> Gasto
                // Payment -$126.84 -> Pago a la tarjeta (Ingreso para la cuenta de crédito)
                
                // Normalizar signo: En tarjetas, gasto aumenta deuda (positivo visualmente en algunas apps, negativo en otras).
                // Asumiremos: Si viene positivo en texto ($6.80) es Gasto. Si viene negativo (-$126.84) es Pago.
                
                if (monto < 0) {
                     tipoMovimiento = 'income'; // Pago a la tarjeta
                     nombreFinal = "Pago Tarjeta";
                     categoriaFinal = "Pago Tarjeta";
                } else {
                     tipoMovimiento = 'expense'; // Gasto
                     
                     // Lógica de Categorización
                     if (userRules[nombreRaw.toUpperCase()]) {
                        categoriaFinal = userRules[nombreRaw.toUpperCase()];
                     } else {
                        const semantica = identificarSemantica(rawText);
                        if (semantica) {
                            nombreFinal = semantica.nombre;
                            categoriaFinal = semantica.categoria;
                        } else {
                            nombreFinal = limpiezaInteligenteGenerica(nombreRaw);
                            if (nombreFinal.toUpperCase().includes("RESTAURANT")) categoriaFinal = "Restaurant";
                            if (nombreFinal.toUpperCase().includes("MARKET")) categoriaFinal = "Supermercado";
                        }
                     }
                }

                // Generar ID único basado en fecha, monto y nombre para evitar duplicados al importar varias veces
                const idUnico = `MANUAL-${fechaActual.getTime()}-${monto}-${nombreRaw.replace(/\s/g, '').slice(0, 10)}`;
                const txnRef = userRef.collection('Movimientos').doc(idUnico);

                batch.set(txnRef, {
                  accountId: accountId,
                  amount: Math.abs(monto),
                  name: nombreFinal,
                  description: nombreRaw,
                  date: admin.firestore.Timestamp.fromDate(fechaActual),
                  category: categoriaFinal,
                  type: tipoMovimiento,
                  isManualImport: true
                }, { merge: true });
            }
        }
    }
    
    // Actualizar Balance de la Cuenta
    // Si la app usa Balance Negativo para Deuda:
    // Gasto (Positivo) -> Restar (Más negativo). 
    // Pago (Negativo) -> Restar (Menos negativo / Más positivo).
    if (totalImportado !== 0) {
        const accountRef = userRef.collection('Cuentas').doc(accountId);
        batch.update(accountRef, { 
            balance: admin.firestore.FieldValue.increment(-totalImportado) 
        });
    }

    await batch.commit();
    return { success: true, count: lineas.length };

  } catch (error) { throw new HttpsError('unknown', error.message); }
});

// 4. LÓGICA MAESTRA (V26 - FIX DOBLE BILT POR DOMINIO)
async function sincronizarDatos(userId, accessUrl) {
  const hoy = new Date();
  const hace60dias = new Date(); hace60dias.setDate(hoy.getDate() - 60);
  const start = Math.floor(hace60dias.getTime() / 1000);
  const end = Math.floor(hoy.getTime() / 1000);

  console.log(`Iniciando sincronización para ${userId}...`);

  const response = await axios.get(`${accessUrl}/accounts?start-date=${start}&end-date=${end}`);
  const data = response.data;
  
  const batch = admin.firestore().batch();
  const userRef = admin.firestore().collection('artifacts').doc('finanzas_app').collection('users').doc(userId);
  
  // OBTENER CUENTAS EXISTENTES (Para saber si es nueva o no)
  const existingAccountsSnap = await userRef.collection('Cuentas').select('accountId').get();
  const existingAccountIds = new Set();
  existingAccountsSnap.forEach(doc => existingAccountIds.add(doc.id));

  // Cargar reglas de usuario
  const rulesSnap = await userRef.collection('category_rules').get();
  const userRules = {};
  rulesSnap.forEach(doc => { userRules[doc.id] = doc.data().category; });

  // --- PROCESAR CUENTAS ---
  data.accounts.forEach((account) => {
    let infoCuenta = (account.name + " " + account.org.name).toUpperCase();
    // Protección contra undefined en account.org.domain
    let dominio = (account.org && account.org.domain) ? account.org.domain.toUpperCase() : "";

    // --- 1. DETECCIÓN DE CRÉDITO ---
    let esCredito = infoCuenta.includes("CREDIT") || 
                    infoCuenta.includes("VISA") || 
                    infoCuenta.includes("MASTERCARD") || 
                    infoCuenta.includes("AMEX") || 
                    infoCuenta.includes("DISCOVER") ||
                    infoCuenta.includes("BILT") ||
                    infoCuenta.includes("REWARDS"); 

    // --- 2. RENOMBRADO INTELIGENTE (LA SOLUCIÓN) ---
    // Si el dominio es Wells Fargo, pero se llama Bilt/Account -> Es la Autograph
    if (dominio.includes("WELLSFARGO") && (infoCuenta.includes("BILT") || account.name.includes("6708"))) {
        account.name = "Wells Fargo Autograph (Ex-Bilt)";
        esCredito = true;
    }
    // Si el dominio es BiltRewards -> Es la Nueva Bilt
    else if (dominio.includes("BILTREWARDS") || dominio.includes("CARDLESS") || dominio.includes("COLUMN")) {
        account.name = "Bilt Mastercard (Nueva)";
        esCredito = true;
    }
    // Caso genérico para limpiar nombres feos
    else if ((infoCuenta.includes("BILT") || infoCuenta.includes("CARDLESS")) && account.name.length < 8) {
        account.name = "Bilt Mastercard";
        esCredito = true;
    }

    // Guardar Cuenta
    const cuentaData = {
      accountId: account.id, 
      name: account.name, 
      institutionName: account.org.name, 
      currency: account.currency, 
      type: esCredito ? 'credit' : 'checking',
      lastSync: admin.firestore.FieldValue.serverTimestamp(),
    };

    // FIX BALANCE BILT: Si es la cuenta Bilt bugueada y el API manda 0, NO sobrescribir el balance manual.
    // Si el balance del API es distinto de 0, asumimos que se arregló o es correcto.
    const esBiltBugueada = account.name === "Bilt Mastercard (Nueva)";
    const exists = existingAccountIds.has(account.id);

    if (!esBiltBugueada || parseFloat(account.balance) !== 0) {
        cuentaData.balance = parseFloat(account.balance);
    } else {
        // Es Bilt, balance es 0. 
        // Si la cuenta NO existe, debemos inicializar el balance a 0 para que no explote el Frontend.
        if (!exists) {
            cuentaData.balance = 0;
        }
        // Si YA existe, asumimos que tiene un saldo manual y NO lo tocamos.
    }

    batch.set(userRef.collection('Cuentas').doc(account.id), cuentaData, { merge: true });

    // --- PROCESAR TRANSACCIONES ---
    if (account.transactions) {
      account.transactions.forEach((txn) => {
        const txnRef = userRef.collection('Movimientos').doc(txn.id);
        const monto = parseFloat(txn.amount);
        
        let payee = (txn.payee || "").trim();
        let desc = (txn.description || "").trim();
        const descripcionOriginal = (desc.length > payee.length) ? desc : payee;
        const rawText = (desc + " " + payee).toUpperCase(); 

        let nombreFinal = descripcionOriginal;
        let categoriaFinal = "Otros";
        let esReglaManualForzada = false;

        // --- FIX MANUAL SUPREMO ---
        if (
             (rawText.includes("BILT") && (rawText.includes("TRANSFER") || rawText.includes("PAYMENT") || rawText.includes("ACH"))) ||
             (rawText.includes("ONLINE PAYMENT") && (rawText.includes("THANK YOU"))) || 
             (rawText.includes("ONLINE TRANSFER") && (rawText.includes("CREDIT CARD")))
        ) {
            esReglaManualForzada = true;
            categoriaFinal = "Pago Tarjeta";
            if (rawText.includes("BILT")) nombreFinal = "Pago Bilt Mastercard";
            else nombreFinal = "Pago de Tarjeta de Crédito";
        }

        if (!esReglaManualForzada) {
            if (rawText.includes("ZELLE") || rawText.includes("VENMO")) {
                const matchTo = desc.match(/(?:Zelle payment to|Zelle to|Venmo payment to)\s+([A-Z\s]+?)(?:\s+Conf|#|\s+on|$)/i);
                const matchFrom = desc.match(/(?:Zelle from|Zelle payment from|Venmo from)\s+([A-Z\s]+?)(?:\s+on|#|$)/i);
                let persona = "";
                if (matchTo && matchTo[1]) persona = matchTo[1].trim();
                else if (matchFrom && matchFrom[1]) persona = matchFrom[1].trim();
                nombreFinal = persona ? `Zelle - ${capitalizar(persona)}` : (rawText.includes("VENMO") ? "Venmo" : "Zelle");
                categoriaFinal = "Transferencia";
            }
            else {
                const semantica = identificarSemantica(rawText);
                if (semantica) {
                    nombreFinal = semantica.nombre;
                    categoriaFinal = semantica.categoria;
                } else {
                    nombreFinal = limpiezaInteligenteGenerica(descripcionOriginal);
                    if (nombreFinal.toUpperCase().includes("RESTAURANT")) categoriaFinal = "Restaurant";
                    if (nombreFinal.toUpperCase().includes("MARKET")) categoriaFinal = "Supermercado";
                }
            }
        }

        let tipoMovimiento = (monto < 0) ? 'expense' : 'income';

        if (monto < 0) {
            tipoMovimiento = 'expense';
            if (!esReglaManualForzada && userRules[nombreFinal.toUpperCase()]) {
               categoriaFinal = userRules[nombreFinal.toUpperCase()];
            }
        } 
        else {
            if (!esReglaManualForzada) {
                if (esCredito) {
                    categoriaFinal = "Pago Tarjeta";
                    tipoMovimiento = 'income'; 
                    if (rawText.includes("PAYMENT") || rawText.includes("THANK")) nombreFinal = "Pago Tarjeta (Auto)";
                }
                else if (rawText.includes("COCA") || rawText.includes("PAYROLL") || rawText.includes("NOMINA")) {
                    categoriaFinal = "Sueldo";
                    nombreFinal = "Nómina Coca-Cola";
                    tipoMovimiento = 'income';
                }
                else if (rawText.includes("INTEREST")) {
                    categoriaFinal = "Otros"; 
                    nombreFinal = "Intereses Generados";
                    tipoMovimiento = 'income';
                }
                else if (rawText.includes("ZELLE") || rawText.includes("VENMO")) {
                    categoriaFinal = "Transferencia"; 
                    tipoMovimiento = 'income';
                }
                else {
                    if (rawText.includes("PAYMENT") || rawText.includes("THANK YOU")) categoriaFinal = "Pago Tarjeta";
                    else categoriaFinal = "Transferencia";
                    tipoMovimiento = 'income';
                }
            }
        }

        batch.set(txnRef, {
          accountId: account.id, 
          amount: Math.abs(monto), 
          name: nombreFinal, 
          description: descripcionOriginal, 
          date: new Date(txn.posted * 1000), 
          category: categoriaFinal, 
          type: tipoMovimiento,
        });
      });
    }
  });
  await batch.commit();
}

// --- LIMPIADOR Y CAPITALIZADOR ---
function limpiezaInteligenteGenerica(textoOriginal) {
    let t = textoOriginal.toUpperCase();
    t = t.replace(/CHECKCARD/g, "").replace(/DEBIT CARD/g, "").replace(/POS DEBIT/g, "").replace(/PURCHASE/g, "");
    t = t.replace(/PAYPAL \*/g, "PAYPAL ").replace(/SQ \*/g, "").replace(/TST \*/g, ""); 
    t = t.replace(/\d{4,}/g, "").replace(/\d{2}\/\d{2}/g, "");
    t = t.replace(/[*#\-_]/g, " "); 
    t = t.trim().replace(/\s+/g, " ");
    return capitalizar(t);
}

function capitalizar(texto) {
    if (!texto) return "Desconocido";
    return texto.toLowerCase().split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ');
}

// --- DICCIONARIO SEMÁNTICO ---
function identificarSemantica(raw) {
    const diccionario = [
        { regex: /AMAZON|AMZN|AWS/, name: "Compra Amazon", cat: "Compras" },
        { regex: /WALMART|WAL-MART|WM SUPERCENTER/, name: "Supermercado Walmart", cat: "Supermercado" },
        { regex: /HEB|H-E-B/, name: "Supermercado H-E-B", cat: "Supermercado" },
        { regex: /TARGET/, name: "Supermercado Target", cat: "Supermercado" },
        { regex: /COSTCO/, name: "Supermercado Costco", cat: "Supermercado" },
        { regex: /SAM'S|SAMS CLUB/, name: "Sam's Club", cat: "Supermercado" },
        { regex: /KROGER/, name: "Supermercado Kroger", cat: "Supermercado" },
        { regex: /WHOLE FOODS/, name: "Whole Foods", cat: "Supermercado" },
        { regex: /TRADER JOE/, name: "Trader Joe's", cat: "Supermercado" },
        { regex: /PUBLIX/, name: "Supermercado Publix", cat: "Supermercado" },
        { regex: /ALDI/, name: "Aldi", cat: "Supermercado" },
        
        { regex: /SHELL/, name: "Gasolina Shell", cat: "Gasolina" },
        { regex: /EXXON/, name: "Gasolina Exxon", cat: "Gasolina" },
        { regex: /CHEVRON/, name: "Gasolina Chevron", cat: "Gasolina" },
        { regex: /\bBP\b|BP GAS/, name: "Gasolina BP", cat: "Gasolina" }, 
        { regex: /\bQT\b|QUIKTRIP/, name: "Gasolina QuikTrip", cat: "Gasolina" }, 
        { regex: /VALERO/, name: "Gasolina Valero", cat: "Gasolina" },
        { regex: /7-ELEVEN|7 ELEVEN/, name: "Gasolina 7-Eleven", cat: "Gasolina" },
        { regex: /MURPHY/, name: "Gasolina Murphy", cat: "Gasolina" },

        { regex: /ENTERGY/, name: "Pago de Electricidad", cat: "Servicios" },
        { regex: /\bATT\b|AT&T/, name: "Pago AT&T", cat: "Servicios" }, 
        { regex: /VERIZON/, name: "Pago Verizon", cat: "Servicios" },
        { regex: /TMOBILE|T-MOBILE/, name: "Pago T-Mobile", cat: "Servicios" },
        { regex: /XFINITY|COMCAST/, name: "Internet Xfinity", cat: "Servicios" },
        { regex: /WATER/, name: "Pago de Agua", cat: "Servicios" },

        { regex: /NETFLIX/, name: "Suscripción Netflix", cat: "Subscripcion" },
        { regex: /SPOTIFY/, name: "Suscripción Spotify", cat: "Subscripcion" },
        { regex: /HULU/, name: "Suscripción Hulu", cat: "Subscripcion" },
        { regex: /DISNEY\+/, name: "Suscripción Disney+", cat: "Subscripcion" },
        { regex: /HBO/, name: "Suscripción HBO", cat: "Subscripcion" },
        { regex: /PLANET FITNESS/, name: "Gimnasio Planet Fitness", cat: "Subscripcion" },
        { regex: /COMPASSION/, name: "Donación Compassion", cat: "Subscripcion" },
        { regex: /FINANCIAL/, name: "Financial Service", cat: "Subscripcion" },

        { regex: /COOPER|MORTGAGE/, name: "Pago de Hipoteca", cat: "Mortgage" },
        { regex: /GEICO/, name: "Seguro Geico", cat: "Car Insurance" },
        { regex: /PROGRESSIVE/, name: "Seguro Progressive", cat: "Car Insurance" },
        { regex: /STATE FARM/, name: "Seguro State Farm", cat: "Car Insurance" },
        { regex: /NATIONWIDE/, name: "Seguro Nationwide", cat: "Salud" },

        { regex: /MCDONALD/, name: "McDonald's", cat: "Restaurant" },
        { regex: /STARBUCKS/, name: "Starbucks", cat: "Restaurant" },
        { regex: /BURGER KING/, name: "Burger King", cat: "Restaurant" },
        { regex: /UBER EATS/, name: "Uber Eats", cat: "Restaurant" },
        { regex: /CHICK-FIL-A/, name: "Chick-fil-A", cat: "Restaurant" },
        { regex: /DUNKIN/, name: "Dunkin'", cat: "Restaurant" },
        { regex: /SUBWAY/, name: "Subway", cat: "Restaurant" },
        { regex: /DOMINO/, name: "Domino's", cat: "Restaurant" },
        
        { regex: /EBAY/, name: "eBay", cat: "Compras" },
        { regex: /TEMU/, name: "Temu", cat: "Compras" },
        { regex: /SHOPIFY/, name: "Shopify", cat: "Compras" },
        { regex: /UDEMY/, name: "Curso Udemy", cat: "Compras" },
        { regex: /HOME DEPOT/, name: "Home Depot", cat: "Hogar" },
        { regex: /LOWES/, name: "Lowe's", cat: "Hogar" },
        { regex: /IKEA/, name: "IKEA", cat: "Hogar" },
        { regex: /UBER|LYFT/, name: "Transporte App", cat: "Transporte" },
    ];

    for (const item of diccionario) {
        if (item.regex.test(raw)) {
            return { nombre: item.name, categoria: item.cat };
        }
    }
    return null;
}