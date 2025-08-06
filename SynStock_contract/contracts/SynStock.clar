
;; title: SynStock - Synthetic Stock Exposure Protocol
;; version: 1.0.0
;; summary: A smart contract providing synthetic exposure to individual stocks
;; description: This contract allows users to mint and redeem synthetic tokens representing exposure to individual stocks like AAPL, TSLA, etc.

;; traits
;;

;; token definitions
;; Define fungible token for synthetic stock tokens
(define-fungible-token syn-stock)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-symbol (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-symbol-not-found (err u105))
(define-constant err-symbol-already-exists (err u106))
(define-constant err-invalid-price (err u107))

;; data vars
(define-data-var contract-admin principal contract-owner)
(define-data-var protocol-fee-rate uint u25) ;; 0.25% = 25 basis points
(define-data-var total-supply uint u0)

;; data maps
;; Map to store stock symbols and their current prices (in micro-STX)
(define-map stock-prices 
    { symbol: (string-ascii 10) } 
    { price: uint, last-updated: uint })

;; Map to store user balances for each stock symbol
(define-map user-positions 
    { user: principal, symbol: (string-ascii 10) } 
    { balance: uint, avg-price: uint })

;; Map to store authorized price oracles
(define-map authorized-oracles 
    { oracle: principal } 
    { authorized: bool })

;; Map to track total positions per stock symbol
(define-map total-positions 
    { symbol: (string-ascii 10) } 
    { total-balance: uint })

;; public functions

;; Initialize a new stock symbol with starting price
(define-public (add-stock-symbol (symbol (string-ascii 10)) (initial-price uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
        (asserts! (> initial-price u0) err-invalid-price)
        (asserts! (is-none (map-get? stock-prices { symbol: symbol })) err-symbol-already-exists)
        
        (map-set stock-prices 
            { symbol: symbol } 
            { price: initial-price, last-updated: block-height })
        (map-set total-positions 
            { symbol: symbol } 
            { total-balance: u0 })
        (ok true)))

;; Update stock price (only authorized oracles)
(define-public (update-price (symbol (string-ascii 10)) (new-price uint))
    (begin
        (asserts! (default-to false (get authorized (map-get? authorized-oracles { oracle: tx-sender }))) err-not-authorized)
        (asserts! (> new-price u0) err-invalid-price)
        (asserts! (is-some (map-get? stock-prices { symbol: symbol })) err-symbol-not-found)
        
        (map-set stock-prices 
            { symbol: symbol } 
            { price: new-price, last-updated: block-height })
        (ok true)))

;; Mint synthetic stock tokens
(define-public (mint-syn-stock (symbol (string-ascii 10)) (amount uint))
    (let 
        (
            (price-data (unwrap! (map-get? stock-prices { symbol: symbol }) err-symbol-not-found))
            (current-price (get price price-data))
            (stx-cost (* amount current-price))
            (fee (/ (* stx-cost (var-get protocol-fee-rate)) u10000))
            (total-cost (+ stx-cost fee))
            (current-position (default-to { balance: u0, avg-price: u0 } 
                              (map-get? user-positions { user: tx-sender, symbol: symbol })))
            (current-balance (get balance current-position))
            (current-avg-price (get avg-price current-position))
            (new-balance (+ current-balance amount))
            (new-avg-price (if (is-eq current-balance u0)
                              current-price
                              (/ (+ (* current-balance current-avg-price) (* amount current-price)) new-balance)))
            (total-pos (default-to { total-balance: u0 } (map-get? total-positions { symbol: symbol })))
        )
        
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= (stx-get-balance tx-sender) total-cost) err-insufficient-balance)
        
        ;; Transfer STX from user
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        
        ;; Mint fungible tokens
        (try! (ft-mint? syn-stock amount tx-sender))
        
        ;; Update user position
        (map-set user-positions 
            { user: tx-sender, symbol: symbol } 
            { balance: new-balance, avg-price: new-avg-price })
        
        ;; Update total positions
        (map-set total-positions 
            { symbol: symbol } 
            { total-balance: (+ (get total-balance total-pos) amount) })
        
        ;; Update total supply
        (var-set total-supply (+ (var-get total-supply) amount))
        
        (ok { amount: amount, price: current-price, total-cost: total-cost })))

;; Burn synthetic stock tokens and redeem STX
(define-public (redeem-syn-stock (symbol (string-ascii 10)) (amount uint))
    (let 
        (
            (price-data (unwrap! (map-get? stock-prices { symbol: symbol }) err-symbol-not-found))
            (current-price (get price price-data))
            (stx-value (* amount current-price))
            (fee (/ (* stx-value (var-get protocol-fee-rate)) u10000))
            (payout (- stx-value fee))
            (current-position (unwrap! (map-get? user-positions { user: tx-sender, symbol: symbol }) err-insufficient-balance))
            (current-balance (get balance current-position))
            (new-balance (- current-balance amount))
            (total-pos (unwrap! (map-get? total-positions { symbol: symbol }) err-symbol-not-found))
        )
        
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (asserts! (>= (ft-get-balance syn-stock tx-sender) amount) err-insufficient-balance)
        
        ;; Burn fungible tokens
        (try! (ft-burn? syn-stock amount tx-sender))
        
        ;; Transfer STX to user
        (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
        
        ;; Update user position
        (if (is-eq new-balance u0)
            (map-delete user-positions { user: tx-sender, symbol: symbol })
            (map-set user-positions 
                { user: tx-sender, symbol: symbol } 
                { balance: new-balance, avg-price: (get avg-price current-position) }))
        
        ;; Update total positions
        (map-set total-positions 
            { symbol: symbol } 
            { total-balance: (- (get total-balance total-pos) amount) })
        
        ;; Update total supply
        (var-set total-supply (- (var-get total-supply) amount))
        
        (ok { amount: amount, price: current-price, payout: payout })))

;; Authorize a price oracle
(define-public (authorize-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
        (map-set authorized-oracles 
            { oracle: oracle } 
            { authorized: true })
        (ok true)))

;; Deauthorize a price oracle
(define-public (deauthorize-oracle (oracle principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
        (map-set authorized-oracles 
            { oracle: oracle } 
            { authorized: false })
        (ok true)))

;; Update protocol fee rate (only admin)
(define-public (set-protocol-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
        (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
        (var-set protocol-fee-rate new-rate)
        (ok true)))

;; Transfer admin privileges
(define-public (transfer-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-admin)) err-owner-only)
        (var-set contract-admin new-admin)
        (ok true)))

;; read only functions

;; Get stock price information
(define-read-only (get-stock-price (symbol (string-ascii 10)))
    (map-get? stock-prices { symbol: symbol }))

;; Get user position for a specific stock
(define-read-only (get-user-position (user principal) (symbol (string-ascii 10)))
    (map-get? user-positions { user: user, symbol: symbol }))

;; Get total positions for a stock symbol
(define-read-only (get-total-position (symbol (string-ascii 10)))
    (map-get? total-positions { symbol: symbol }))

;; Check if oracle is authorized
(define-read-only (is-oracle-authorized (oracle principal))
    (default-to false (get authorized (map-get? authorized-oracles { oracle: oracle }))))

;; Get protocol fee rate
(define-read-only (get-protocol-fee-rate)
    (var-get protocol-fee-rate))

;; Get contract admin
(define-read-only (get-contract-admin)
    (var-get contract-admin))

;; Get total supply of all synthetic stock tokens
(define-read-only (get-total-supply)
    (var-get total-supply))

;; Calculate mint cost for given amount and symbol
(define-read-only (calculate-mint-cost (symbol (string-ascii 10)) (amount uint))
    (match (map-get? stock-prices { symbol: symbol })
        price-data 
        (let 
            (
                (current-price (get price price-data))
                (stx-cost (* amount current-price))
                (fee (/ (* stx-cost (var-get protocol-fee-rate)) u10000))
            )
            (ok { stx-cost: stx-cost, fee: fee, total-cost: (+ stx-cost fee) }))
        err-symbol-not-found))

;; Calculate redeem payout for given amount and symbol
(define-read-only (calculate-redeem-payout (symbol (string-ascii 10)) (amount uint))
    (match (map-get? stock-prices { symbol: symbol })
        price-data 
        (let 
            (
                (current-price (get price price-data))
                (stx-value (* amount current-price))
                (fee (/ (* stx-value (var-get protocol-fee-rate)) u10000))
            )
            (ok { stx-value: stx-value, fee: fee, payout: (- stx-value fee) }))
        err-symbol-not-found))

;; private functions

;; Initialize contract with common stock symbols (called once during deployment)
(define-private (initialize-default-stocks)
    (begin
        ;; This would typically be called during contract deployment
        ;; Adding some popular stock symbols with placeholder prices
        ;; In production, these would be set by oracles with real prices
        (unwrap! (add-stock-symbol "AAPL" u15000000) (err u999)) ;; $150.00 in micro-STX
        (unwrap! (add-stock-symbol "TSLA" u20000000) (err u999)) ;; $200.00 in micro-STX  
        (unwrap! (add-stock-symbol "MSFT" u30000000) (err u999)) ;; $300.00 in micro-STX
        (unwrap! (add-stock-symbol "GOOGL" u25000000) (err u999)) ;; $250.00 in micro-STX
        (unwrap! (add-stock-symbol "AMZN" u12000000) (err u999)) ;; $120.00 in micro-STX
        (ok true)))

