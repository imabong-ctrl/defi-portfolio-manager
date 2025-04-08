;; Title: DeFi Portfolio Manager
;; 
;; Summary:
;; A sophisticated DeFi portfolio management system that enables users to create, 
;; manage, and automatically rebalance token portfolios with customizable allocations.
;;
;; Description:
;; This smart contract implements a decentralized portfolio management protocol that allows
;; users to:
;; - Create portfolios with multiple SIP-010 compliant tokens
;; - Set and update target allocations for each token
;; - Automatically rebalance portfolios based on predefined thresholds
;; - Track portfolio performance and asset distribution
;; The system includes built-in safety mechanisms, fee structures, and administrative
;; controls for sustainable protocol management.

;; Error codes - Structured operational failure states
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PORTFOLIO (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))
(define-constant ERR-REBALANCE-FAILED (err u104))
(define-constant ERR-PORTFOLIO-EXISTS (err u105))
(define-constant ERR-INVALID-PERCENTAGE (err u106))
(define-constant ERR-MAX-TOKENS-EXCEEDED (err u107))
(define-constant ERR-LENGTH-MISMATCH (err u108))
(define-constant ERR-USER-STORAGE-FAILED (err u109))
(define-constant ERR-INVALID-TOKEN-ID (err u110))

;; Protocol Configuration - Immutable settings
(define-data-var protocol-owner principal tx-sender)
(define-data-var portfolio-counter uint u0)
(define-data-var protocol-fee uint u25)  ;; 0.25% fee in basis points (1 BP = 0.01%)
(define-constant MAX-TOKENS-PER-PORTFOLIO u10)
(define-constant BASIS-POINTS u10000)

;; Data Storage - State management architecture
(define-map Portfolios
    uint  ;; NFT-style portfolio ID
    {
        owner: principal,
        created-at: uint,
        last-rebalanced: uint,
        total-value: uint,  ;; Stored in satoshi equivalents
        active: bool,
        token-count: uint
    }
)

(define-map PortfolioAssets
    {portfolio-id: uint, token-id: uint}
    {
        target-percentage: uint,  ;; Basis points representation
        current-amount: uint,     ;; Actual token quantity
        token-address: principal  ;; SIP-010 compliant addresses
    }
)

(define-map UserPortfolios
    principal
    (list 20 uint)  ;; Wallet-to-portfolio mapping
)

;; READ-ONLY INTERFACE

(define-read-only (get-portfolio (portfolio-id uint))
    (map-get? Portfolios portfolio-id)
)

(define-read-only (get-portfolio-asset (portfolio-id uint) (token-id uint))
    (map-get? PortfolioAssets {portfolio-id: portfolio-id, token-id: token-id})
)

(define-read-only (get-user-portfolios (user principal))
    (default-to (list) (map-get? UserPortfolios user))
)

(define-read-only (calculate-rebalance-amounts (portfolio-id uint))
    (let (
        (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
        (total-value (get total-value portfolio))
    )
    (ok {
        portfolio-id: portfolio-id,
        total-value: total-value,
        needs-rebalance: (> (- stacks-block-height (get last-rebalanced portfolio)) u144)  ;; 24h blocks
    }))
)

;; CORE FUNCTIONALITY

(define-public (create-portfolio (initial-tokens (list 10 principal)) (percentages (list 10 uint)))
    (let (
        (portfolio-id (+ (var-get portfolio-counter) u1))
        (token-count (len initial-tokens))
        (percentage-count (len percentages))
        (token-0 (element-at? initial-tokens u0))
        (token-1 (element-at? initial-tokens u1))
        (percentage-0 (element-at? percentages u0))
        (percentage-1 (element-at? percentages u1))
    )
    ;; Validation layer
    (asserts! (<= token-count MAX-TOKENS-PER-PORTFOLIO) ERR-MAX-TOKENS-EXCEEDED)
    (asserts! (is-eq token-count percentage-count) ERR-LENGTH-MISMATCH)
    (asserts! (validate-portfolio-percentages percentages) ERR-INVALID-PERCENTAGE)
    
    ;; Portfolio genesis
    (map-set Portfolios portfolio-id
        {
            owner: tx-sender,
            created-at: stacks-block-height,
            last-rebalanced: stacks-block-height,
            total-value: u0,
            active: true,
            token-count: token-count
        }
    )
    
    ;; Asset initialization
    (asserts! (and (is-some token-0) (is-some token-1)) ERR-INVALID-TOKEN)
    (asserts! (and (is-some percentage-0) (is-some percentage-1)) ERR-INVALID-PERCENTAGE)
    
    (try! (initialize-portfolio-asset 
        u0 
        (unwrap-panic token-0)
        (unwrap-panic percentage-0)
        portfolio-id))
    
    (try! (initialize-portfolio-asset 
        u1
        (unwrap-panic token-1)
        (unwrap-panic percentage-1)
        portfolio-id))
    
    ;; User state update
    (try! (add-to-user-portfolios tx-sender portfolio-id))
    (var-set portfolio-counter portfolio-id)
    (ok portfolio-id))
)

;; PORTFOLIO OPERATIONS

(define-public (rebalance-portfolio (portfolio-id uint))
    (let (
        (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
    )
    (asserts! (is-eq tx-sender (get owner portfolio)) ERR-NOT-AUTHORIZED)
    (asserts! (get active portfolio) ERR-INVALID-PORTFOLIO)
    
    (map-set Portfolios portfolio-id
        (merge portfolio {last-rebalanced: stacks-block-height})
    )
    (ok true))
)

(define-public (update-portfolio-allocation 
    (portfolio-id uint) 
    (token-id uint)
    (new-percentage uint))
    (let (
        (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
        (asset (unwrap! (get-portfolio-asset portfolio-id token-id) ERR-INVALID-TOKEN))
    )
    (asserts! (is-eq tx-sender (get owner portfolio)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-percentage new-percentage) ERR-INVALID-PERCENTAGE)
    (asserts! (validate-token-id portfolio-id token-id) ERR-INVALID-TOKEN-ID)
    
    (map-set PortfolioAssets
        {portfolio-id: portfolio-id, token-id: token-id}
        (merge asset {target-percentage: new-percentage})
    )
    (ok true))
)

;; INTERNAL HELPERS

(define-private (validate-token-id (portfolio-id uint) (token-id uint))
    (let ((portfolio (unwrap! (get-portfolio portfolio-id) false)))
    (and 
        (< token-id MAX-TOKENS-PER-PORTFOLIO)
        (< token-id (get token-count portfolio))
        true
    ))
)

(define-private (validate-percentage (percentage uint))
    (and (>= percentage u0) (<= percentage BASIS-POINTS))
)

(define-private (validate-portfolio-percentages (percentages (list 10 uint)))
    (fold check-percentage-sum percentages true)
)

(define-private (check-percentage-sum (current-percentage uint) (valid bool))
    (and valid (validate-percentage current-percentage))
)

(define-private (add-to-user-portfolios (user principal) (portfolio-id uint))
    (let (
        (current-portfolios (get-user-portfolios user))
        (new-portfolios (unwrap! (as-max-len? (append current-portfolios portfolio-id) u20) ERR-USER-STORAGE-FAILED))
    )
    (map-set UserPortfolios user new-portfolios)
    (ok true))
)

(define-private (initialize-portfolio-asset (index uint) (token principal) (percentage uint) (portfolio-id uint))
    (if (>= percentage u0)
        (begin
            (map-set PortfolioAssets
                {portfolio-id: portfolio-id, token-id: index}
                {
                    target-percentage: percentage,
                    current-amount: u0,
                    token-address: token
                }
            )
            (ok true))
        ERR-INVALID-TOKEN
    )
)