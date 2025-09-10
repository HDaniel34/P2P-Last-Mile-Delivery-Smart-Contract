(define-fungible-token delivery-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-job-not-available (err u106))
(define-constant err-job-already-accepted (err u107))
(define-constant err-job-not-accepted (err u108))
(define-constant err-invalid-status (err u109))

(define-data-var job-id-nonce uint u0)
(define-data-var total-supply uint u0)

(define-map delivery-jobs
  { job-id: uint }
  {
    shop: principal,
    customer: principal,
    delivery-address: (string-utf8 200),
    reward-amount: uint,
    status: (string-ascii 20),
    deliverer: (optional principal),
    created-at: uint,
    deadline: uint
  }
)

(define-map user-ratings
  { user: principal }
  { total-score: uint, rating-count: uint }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-public (mint-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-mint? delivery-token amount recipient))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok amount)
  )
)

(define-public (transfer-tokens (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (try! (ft-transfer? delivery-token amount tx-sender recipient))
    (ok amount)
  )
)

(define-public (create-delivery-job (customer principal) (delivery-address (string-utf8 200)) (reward-amount uint) (deadline-blocks uint))
  (let (
    (job-id (+ (var-get job-id-nonce) u1))
    (current-block stacks-block-height)
  )
    (asserts! (> reward-amount u0) err-invalid-amount)
    (asserts! (> deadline-blocks u0) err-invalid-amount)
    (asserts! (>= (ft-get-balance delivery-token tx-sender) reward-amount) err-insufficient-funds)
    (try! (ft-transfer? delivery-token reward-amount tx-sender (as-contract tx-sender)))
    (map-set delivery-jobs
      { job-id: job-id }
      {
        shop: tx-sender,
        customer: customer,
        delivery-address: delivery-address,
        reward-amount: reward-amount,
        status: "open",
        deliverer: none,
        created-at: current-block,
        deadline: (+ current-block deadline-blocks)
      }
    )
    (var-set job-id-nonce job-id)
    (ok job-id)
  )
)

(define-public (accept-delivery-job (job-id uint))
  (let (
    (job (unwrap! (map-get? delivery-jobs { job-id: job-id }) err-not-found))
  )
    (asserts! (is-eq (get status job) "open") err-job-not-available)
    (asserts! (< stacks-block-height (get deadline job)) err-job-not-available)
    (map-set delivery-jobs
      { job-id: job-id }
      (merge job {
        status: "accepted",
        deliverer: (some tx-sender)
      })
    )
    (ok true)
  )
)

(define-public (complete-delivery (job-id uint))
  (let (
    (job (unwrap! (map-get? delivery-jobs { job-id: job-id }) err-not-found))
    (deliverer (unwrap! (get deliverer job) err-job-not-accepted))
  )
    (asserts! (is-eq tx-sender deliverer) err-unauthorized)
    (asserts! (is-eq (get status job) "accepted") err-invalid-status)
    (asserts! (< stacks-block-height (get deadline job)) err-job-not-available)
    (try! (as-contract (ft-transfer? delivery-token (get reward-amount job) tx-sender deliverer)))
    (map-set delivery-jobs
      { job-id: job-id }
      (merge job { status: "completed" })
    )
    (ok true)
  )
)

(define-public (cancel-job (job-id uint))
  (let (
    (job (unwrap! (map-get? delivery-jobs { job-id: job-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get shop job)) err-unauthorized)
    (asserts! (is-eq (get status job) "open") err-invalid-status)
    (try! (as-contract (ft-transfer? delivery-token (get reward-amount job) tx-sender (get shop job))))
    (map-set delivery-jobs
      { job-id: job-id }
      (merge job { status: "cancelled" })
    )
    (ok true)
  )
)

(define-public (rate-user (user principal) (score uint))
  (let (
    (current-rating (default-to { total-score: u0, rating-count: u0 } (map-get? user-ratings { user: user })))
  )
    (asserts! (and (>= score u1) (<= score u5)) err-invalid-amount)
    (map-set user-ratings
      { user: user }
      {
        total-score: (+ (get total-score current-rating) score),
        rating-count: (+ (get rating-count current-rating) u1)
      }
    )
    (ok true)
  )
)

(define-read-only (get-job-details (job-id uint))
  (map-get? delivery-jobs { job-id: job-id })
)

(define-read-only (get-user-rating (user principal))
  (let (
    (rating (default-to { total-score: u0, rating-count: u0 } (map-get? user-ratings { user: user })))
  )
    (if (> (get rating-count rating) u0)
      (some (/ (get total-score rating) (get rating-count rating)))
      none
    )
  )
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance delivery-token user)
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-current-job-id)
  (var-get job-id-nonce)
)
