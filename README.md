# SynStock - Synthetic Stock Exposure Protocol

A decentralized smart contract protocol built on the Stacks blockchain that provides synthetic exposure to individual stocks (AAPL, TSLA, MSFT, etc.) through fungible tokens backed by STX collateral.

## 🌟 Features

- **Synthetic Stock Tokens**: Mint fungible tokens representing exposure to individual stocks
- **Price Oracle Integration**: Authorized oracles provide real-time stock price feeds
- **Collateralized System**: All synthetic tokens are backed by STX deposits
- **Fee Management**: Configurable protocol fees (default 0.25%)
- **Multi-Stock Support**: Support for multiple stock symbols (AAPL, TSLA, MSFT, GOOGL, AMZN)
- **Position Tracking**: Track user positions and average purchase prices
- **Admin Controls**: Secure admin functions for oracle management and fee updates

## 🔧 Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity v2
- **Epoch**: 2.5
- **Token Standard**: Fungible Token (SIP-010)
- **Testing Framework**: Vitest with Clarinet SDK

## 📁 Project Structure

```
SynStock_contract/
├── contracts/
│   └── SynStock.clar          # Main smart contract
├── tests/
│   └── SynStock.test.ts       # Unit tests
├── settings/
│   ├── Devnet.toml           # Development network config
│   ├── Testnet.toml          # Testnet configuration
│   └── Mainnet.toml          # Mainnet configuration
├── Clarinet.toml             # Project configuration
├── package.json              # Node.js dependencies
├── tsconfig.json             # TypeScript configuration
└── vitest.config.js          # Test configuration
```

## 🚀 Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development toolkit
- [Node.js](https://nodejs.org/) (v16 or later)
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd SynStock
```

2. Install dependencies:
```bash
cd SynStock_contract
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## 📋 Usage Examples

### Minting Synthetic Stock Tokens

```clarity
;; Mint 100 AAPL synthetic tokens
(contract-call? .SynStock mint-syn-stock "AAPL" u100)
```

### Redeeming Synthetic Stock Tokens

```clarity
;; Redeem 50 AAPL synthetic tokens for STX
(contract-call? .SynStock redeem-syn-stock "AAPL" u50)
```

### Checking Stock Prices

```clarity
;; Get current AAPL price information
(contract-call? .SynStock get-stock-price "AAPL")
```

### Calculating Costs

```clarity
;; Calculate cost to mint 100 TSLA tokens
(contract-call? .SynStock calculate-mint-cost "TSLA" u100)
```

## 📖 Contract Functions Documentation

### Public Functions

#### `add-stock-symbol`
**Admin Only** - Initialize a new stock symbol with starting price.
- **Parameters**: `symbol` (string-ascii 10), `initial-price` (uint)
- **Returns**: `(response bool uint)`

#### `update-price`
**Oracle Only** - Update stock price for a given symbol.
- **Parameters**: `symbol` (string-ascii 10), `new-price` (uint)
- **Returns**: `(response bool uint)`

#### `mint-syn-stock`
Mint synthetic stock tokens by depositing STX collateral.
- **Parameters**: `symbol` (string-ascii 10), `amount` (uint)
- **Returns**: `(response {amount: uint, price: uint, total-cost: uint} uint)`

#### `redeem-syn-stock`
Burn synthetic stock tokens and receive STX payout.
- **Parameters**: `symbol` (string-ascii 10), `amount` (uint)
- **Returns**: `(response {amount: uint, price: uint, payout: uint} uint)`

#### `authorize-oracle`
**Admin Only** - Authorize a principal as a price oracle.
- **Parameters**: `oracle` (principal)
- **Returns**: `(response bool uint)`

#### `deauthorize-oracle`
**Admin Only** - Remove oracle authorization from a principal.
- **Parameters**: `oracle` (principal)
- **Returns**: `(response bool uint)`

#### `set-protocol-fee-rate`
**Admin Only** - Update the protocol fee rate (max 10%).
- **Parameters**: `new-rate` (uint)
- **Returns**: `(response bool uint)`

#### `transfer-admin`
**Admin Only** - Transfer admin privileges to another principal.
- **Parameters**: `new-admin` (principal)
- **Returns**: `(response bool uint)`

### Read-Only Functions

#### `get-stock-price`
Get current price and last updated block for a stock symbol.
- **Parameters**: `symbol` (string-ascii 10)
- **Returns**: `(optional {price: uint, last-updated: uint})`

#### `get-user-position`
Get user's position for a specific stock symbol.
- **Parameters**: `user` (principal), `symbol` (string-ascii 10)
- **Returns**: `(optional {balance: uint, avg-price: uint})`

#### `get-total-position`
Get total positions across all users for a stock symbol.
- **Parameters**: `symbol` (string-ascii 10)
- **Returns**: `(optional {total-balance: uint})`

#### `is-oracle-authorized`
Check if a principal is an authorized oracle.
- **Parameters**: `oracle` (principal)
- **Returns**: `bool`

#### `get-protocol-fee-rate`
Get current protocol fee rate in basis points.
- **Returns**: `uint`

#### `calculate-mint-cost`
Calculate STX cost to mint synthetic tokens.
- **Parameters**: `symbol` (string-ascii 10), `amount` (uint)
- **Returns**: `(response {stx-cost: uint, fee: uint, total-cost: uint} uint)`

#### `calculate-redeem-payout`
Calculate STX payout for redeeming synthetic tokens.
- **Parameters**: `symbol` (string-ascii 10), `amount` (uint)
- **Returns**: `(response {stx-value: uint, fee: uint, payout: uint} uint)`

## 🚀 Deployment Guide

### Local Development (Devnet)

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy contract:
```clarity
::deploy_contract contracts/SynStock.clar
```

### Testnet Deployment

1. Configure your testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --testnet
```

### Mainnet Deployment

1. Configure your mainnet settings in `settings/Mainnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deploy --mainnet
```

## 🛡️ Security Notes

### Key Security Features

- **Access Control**: Admin-only functions protected by sender verification
- **Oracle Authorization**: Only authorized oracles can update prices
- **Balance Validation**: Comprehensive balance checks before operations
- **Fee Limits**: Protocol fee capped at 10% maximum
- **Integer Overflow Protection**: Safe arithmetic operations throughout

### Security Considerations

1. **Oracle Risk**: Price feeds depend on authorized oracles; ensure oracle reliability
2. **Admin Keys**: Secure storage of admin private keys is critical
3. **Smart Contract Risk**: Audit contract code before mainnet deployment
4. **Liquidity Risk**: Large redemptions may impact STX reserves
5. **Price Volatility**: Synthetic tokens reflect real stock price movements

### Recommended Practices

- Use multi-signature wallets for admin functions
- Implement time delays for critical parameter changes
- Regular security audits and code reviews
- Monitor oracle price feed accuracy
- Maintain adequate STX reserves for redemptions

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Run tests with coverage:
```bash
npm run test:report
```

Watch mode for development:
```bash
npm run test:watch
```

## 📊 Default Stock Symbols

The contract initializes with the following stock symbols:

| Symbol | Initial Price (μSTX) | USD Equivalent |
|--------|---------------------|----------------|
| AAPL   | 15,000,000         | $150.00        |
| TSLA   | 20,000,000         | $200.00        |
| MSFT   | 30,000,000         | $300.00        |
| GOOGL  | 25,000,000         | $250.00        |
| AMZN   | 12,000,000         | $120.00        |

*Note: These are placeholder prices for development. In production, prices should be updated by authorized oracles.*

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the ISC License.

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. The protocol is not audited and should not be used with significant funds without proper due diligence. Synthetic tokens do not represent actual stock ownership and are purely for price exposure purposes.