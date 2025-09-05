// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title KipuVault — bóvedas personales de ETH con tope global y límite por retiro
/// @author ---
contract KipuVault {
    // Errores

    /// @notice No se permite monto en cero.
    error ZeroAmount();

    /// @notice Se superó el tope global de la bóveda.
    /// @param cap Máximo total permitido (wei).
    /// @param requested Depósito solicitado (wei).
    /// @param currentTotal Total actual depositado (wei).
    error BankCapExceeded(uint256 cap, uint256 requested, uint256 currentTotal);

    /// @notice Balance insuficiente para el retiro.
    /// @param requested Monto solicitado (wei).
    /// @param available Balance disponible del usuario (wei).
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice El monto del retiro excede el límite por transacción.
    /// @param requested Monto solicitado (wei).
    /// @param maxAllowed Máximo permitido (wei).
    error WithdrawTooLarge(uint256 requested, uint256 maxAllowed);

    /// @notice Falló la transferencia nativa de ETH.
    error TransferFailed();

    /// @notice Se detectó reentrancia.
    error Reentrancy();

    /// @notice Parámetros inválidos en el constructor.
    error InvalidParams();

    // Eventos

    /// @notice Emitido en un depósito exitoso.
    /// @param account Dirección del depositante.
    /// @param amount Monto depositado (wei).
    /// @param newBalance Balance actualizado del usuario (wei).
    event Deposited(address indexed account, uint256 amount, uint256 newBalance);

    /// @notice Emitido en un retiro exitoso.
    /// @param account Dirección del retirante.
    /// @param amount Monto retirado (wei).
    /// @param newBalance Balance actualizado del usuario (wei).
    event Withdrawn(address indexed account, uint256 amount, uint256 newBalance);

    //   Constantes e Inmutables

    /// @notice Versión semántica del contrato.
    string public constant VERSION = "1.0.0";

    /// @notice Máxima cantidad de ETH que la bóveda puede contener globalmente (wei). Definido al desplegar.
    uint256 public immutable maxVaultCapacity;

    /// @notice Monto máximo de retiro por transacción (wei). Definido al desplegar.
    uint256 public immutable maxWithdrawAmount;

    //    Variables de Estado

    /// @notice Total actual de ETH almacenado en la bóveda (wei).
    uint256 public totalLiquidity;

    /// @notice Balances de usuarios.
    mapping(address => uint256) private balances;

    /// @notice Número de depósitos por usuario.
    mapping(address => uint256) public userDeposits;

    /// @notice Número de retiros por usuario.
    mapping(address => uint256) public userWithdrawals;

    /// @notice Contadores globales de operaciones.
    uint256 public totalDepositOps;
    uint256 public totalWithdrawOps;

    /// @dev Bandera simple de protección contra reentrancia.
    bool private locked;

    // Modificadores

    /// @notice Previene operaciones con valor cero.
    /// @param amount Monto a validar (wei).
    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Protege funciones contra reentrancia usando un candado.
    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    // Constructor

    /// @param _vaultCap Capacidad máxima global (wei).
    /// @param _withdrawLimit Límite de retiro por transacción (wei).
    constructor(uint256 _vaultCap, uint256 _withdrawLimit) {
        if (_vaultCap == 0 || _withdrawLimit == 0 || _withdrawLimit > _vaultCap) {
            revert InvalidParams();
        }
        maxVaultCapacity = _vaultCap;
        maxWithdrawAmount = _withdrawLimit;
    }

    // Funciones Principales

    /// @notice Deposita ETH en tu bóveda personal.
    /// @dev Sigue el patrón CEI (Checks-Effects-Interactions). Emite {Deposited}.
    function deposit() external payable nonZero(msg.value) {
        // Validaciones
        uint256 updatedTotal = totalLiquidity + msg.value;
        if (updatedTotal > maxVaultCapacity) {
            revert BankCapExceeded(maxVaultCapacity, msg.value, totalLiquidity);
        }

        // Efectos
        balances[msg.sender] += msg.value;
        totalLiquidity = updatedTotal;
        unchecked {
            userDeposits[msg.sender] += 1;
            totalDepositOps += 1;
        }

        // Interacciones (ninguna externa aquí)
        emit Deposited(msg.sender, msg.value, balances[msg.sender]);
    }

    /// @notice Retira ETH de tu bóveda personal.
    /// @param amount Monto a retirar (wei).
    /// @dev Sigue CEI + nonReentrant + transferencia segura. Emite {Withdrawn}.
    function withdraw(uint256 amount)
        external
        nonZero(amount)
        nonReentrant
    {
        // Validaciones
        if (amount > maxWithdrawAmount) {
            revert WithdrawTooLarge(amount, maxWithdrawAmount);
        }
        uint256 balance = balances[msg.sender];
        if (amount > balance) {
            revert InsufficientBalance(amount, balance);
        }

        // Efectos
        balances[msg.sender] = balance - amount;
        totalLiquidity -= amount;
        unchecked {
            userWithdrawals[msg.sender] += 1;
            totalWithdrawOps += 1;
        }

        // Interacciones
        _safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, balances[msg.sender]);
    }

    // Vistas

    /// @notice Retorna el balance del usuario.
    /// @param account Dirección a consultar.
    /// @return Balance en wei.
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /// @notice Retorna la configuración inmutable de la bóveda.
    /// @return cap Capacidad global de la bóveda (wei).
    /// @return withdrawLimit Límite de retiro por transacción (wei).
    function getConfig() external view returns (uint256 cap, uint256 withdrawLimit) {
        return (maxVaultCapacity, maxWithdrawAmount);
    }

    /// @notice Retorna la capacidad restante (maxVaultCapacity - totalLiquidity).
    function availableCapacity() external view returns (uint256) {
        return maxVaultCapacity - totalLiquidity;
    }

    // Utilidades internas

    /// @dev Transferencia segura de ETH nativo usando llamada de bajo nivel.
    function _safeTransfer(address to, uint256 amount) private {
        (bool sent, ) = to.call{value: amount}("");
        if (!sent) revert TransferFailed();
    }

    // Manejo de ETH

    /// @notice Fallback para transferencias directas de ETH. Se contabiliza como depósito.
    receive() external payable {
        if (msg.value == 0) revert ZeroAmount();
        uint256 updatedTotal = totalLiquidity + msg.value;
        if (updatedTotal > maxVaultCapacity) {
            revert BankCapExceeded(maxVaultCapacity, msg.value, totalLiquidity);
        }

        balances[msg.sender] += msg.value;
        totalLiquidity = updatedTotal;
        unchecked {
            userDeposits[msg.sender] += 1;
            totalDepositOps += 1;
        }

        emit Deposited(msg.sender, msg.value, balances[msg.sender]);
    }

    /// @notice Maneja llamadas con datos no reconocidos. Acepta ETH y lo contabiliza como depósito.
    fallback() external payable {
        if (msg.value > 0) {
            uint256 updatedTotal = totalLiquidity + msg.value;
            if (updatedTotal > maxVaultCapacity) {
                revert BankCapExceeded(maxVaultCapacity, msg.value, totalLiquidity);
            }

            balances[msg.sender] += msg.value;
            totalLiquidity = updatedTotal;
            unchecked {
                userDeposits[msg.sender] += 1;
                totalDepositOps += 1;
            }

            emit Deposited(msg.sender, msg.value, balances[msg.sender]);
        }
    }
}
