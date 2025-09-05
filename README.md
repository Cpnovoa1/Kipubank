# 🏦 KipuBank

KipuBank es un contrato inteligente escrito en Solidity que simula un banco simple en la blockchain.  
Permite a los usuarios **depositar y retirar ETH** bajo ciertas reglas de seguridad y límites, siguiendo buenas prácticas de desarrollo Web3.

Este proyecto fue desarrollado como parte de un examen práctico para aplicar conocimientos de Solidity, seguridad en contratos y despliegue en testnets.  

---

## ✨ Características principales

- ✅ Depósitos en ETH con un **límite global** (`bankCap`) definido al desplegar.  
- ✅ Retiros limitados por transacción (`maxWithdrawPerTx`).  
- ✅ Registro individual de saldos por usuario mediante `mapping`.  
- ✅ Emisión de eventos en cada depósito y retiro.  
- ✅ Control de seguridad con errores personalizados y modificadores.  
- ✅ Funciones organizadas: externas, privadas y de vista.  

---

## 📂 Estructura del repositorio

kipu-bank/
│
├── contracts/
│ └── KipuBank.sol # Contrato inteligente principal
│
├── README.md # Documentación del proyecto
└── ...

yaml
Copiar código

---

## 🚀 Despliegue en Remix

1. Ingresa a [Remix](https://remix.ethereum.org).  
2. Crea un archivo en `contracts/KipuBank.sol` y pega el código.  
3. Compila con la versión **0.8.24**.  
4. En **Deploy & Run Transactions**:  
   - Selecciona **Injected Provider - MetaMask** (ej. testnet Sepolia).  
   - Ingresa los parámetros del constructor:  
     - `bankCap` → capacidad total en wei.  
     - `maxWithdrawPerTx` → retiro máximo por transacción en wei.  
   - Haz clic en **Deploy** y confirma en MetaMask.  

---

---------------------------------------------------------
🛠️ Cómo interactuar con el contrato
---------------------------------------------------------

1. Depositar ETH
   - En Remix, ingresa un valor en el campo "Value" (ejemplo: 1 ether).
   - Ejecuta la función:
     deposit()

2. Retirar ETH
   - Ejecuta la función con el monto a retirar (en wei), siempre menor o igual al límite por transacción:
     withdraw(500000000000000000)  // Retira 0.5 ETH

3. Consultar saldo
   - Para ver el saldo de una cuenta:
     balanceOf(0xTuDireccion)

4. Ver eventos
   - Cada depósito y retiro exitoso emite un evento (Deposited, Withdrawn), que se puede consultar en Remix o en Etherscan si se despliega en testnet.