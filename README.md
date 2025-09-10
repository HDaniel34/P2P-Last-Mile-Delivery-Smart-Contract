# 🚚 P2P Last-Mile Delivery Smart Contract

A decentralized last-mile delivery platform powered by token incentives and gig-based delivery workers on the Stacks blockchain.

## 🌟 Features

- 🏪 **Shop Job Creation**: Stores can post delivery jobs with token rewards
- 🚴 **Gig-Based Delivery**: Anyone can accept and complete delivery jobs
- 💰 **Token Incentives**: Native delivery tokens for payments and rewards
- ⭐ **Rating System**: Community-driven user ratings for trust
- 🔒 **Escrow Protection**: Automatic fund holding until delivery completion
- ⏰ **Deadline Management**: Time-based job expiration

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd P2P-Last-Mile-Delivery-Smart-Contract
clarinet check
```

## 📋 Usage Instructions

### 🏪 For Shop Owners

#### 1. Mint Delivery Tokens (Contract Owner Only)
```clarity
(contract-call? .P2P-Last-Mile-Delivery mint-tokens 'SP1... u1000)
```

#### 2. Create a Delivery Job
```clarity
(contract-call? .P2P-Last-Mile-Delivery create-delivery-job 
  'SP2CUSTOMER...
  u"123 Main St, City"
  u100
  u144)  ;; 24 hours in blocks
```

#### 3. Cancel Job (if needed)
```clarity
(contract-call? .P2P-Last-Mile-Delivery cancel-job u1)
```

### 🚴 For Delivery Workers

#### 1. Accept a Delivery Job
```clarity
(contract-call? .P2P-Last-Mile-Delivery accept-delivery-job u1)
```

#### 2. Complete the Delivery
```clarity
(contract-call? .P2P-Last-Mile-Delivery complete-delivery u1)
```

#### 3. Rate Other Users
```clarity
(contract-call? .P2P-Last-Mile-Delivery rate-user 'SP1SHOP... u5)
```

### 🔍 Query Functions

#### Check Job Details
```clarity
(contract-call? .P2P-Last-Mile-Delivery get-job-details u1)
```

#### View User Rating
```clarity
(contract-call? .P2P-Last-Mile-Delivery get-user-rating 'SP1...)
```

#### Check Token Balance
```clarity
(contract-call? .P2P-Last-Mile-Delivery get-token-balance 'SP1...)
```

## 🎯 Core Functions

| Function | Description | Access |
|----------|-------------|---------|
| `mint-tokens` | Create new delivery tokens | Owner only |
| `create-delivery-job` | Post a new delivery job | Shop owners |
| `accept-delivery-job` | Accept an available job | Delivery workers |
| `complete-delivery` | Mark delivery as completed | Assigned deliverer |
| `cancel-job` | Cancel an open job | Job creator |
| `rate-user` | Rate other platform users | Anyone |
| `transfer-tokens` | Send tokens to another user | Token holders |

## 📊 Job Status Flow

```
open → accepted → completed
  ↓
cancelled
```

## 🏗️ Contract Architecture

- **Fungible Token**: Native delivery-token for payments
- **Job Management**: Complete lifecycle from creation to completion  
- **Escrow System**: Automatic fund holding and release
- **Rating System**: Community trust through peer ratings
- **Access Control**: Role-based function restrictions

## 🧪 Testing

```bash
clarinet test
```

## 🔧 Development

### Contract Deployment
```bash
clarinet integrate
```

### Local Testing
```bash
clarinet console
```

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only function |
| u101 | Job not found |
| u102 | Unauthorized access |
| u103 | Resource already exists |
| u104 | Invalid amount |
| u105 | Insufficient funds |
| u106 | Job not available |
| u107 | Job already accepted |
| u108 | Job not accepted |
| u109 | Invalid status |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

MIT License - see LICENSE file for details

---

Built with ❤️ on Stacks blockchain
