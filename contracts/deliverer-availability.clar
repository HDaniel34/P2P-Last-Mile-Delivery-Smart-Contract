(define-constant err-already-available (err u500))
(define-constant err-not-available (err u501))
(define-constant err-invalid-zone (err u502))
(define-constant err-invalid-capacity (err u503))

(define-constant max-idle-blocks u72)
(define-constant min-capacity u1)
(define-constant max-capacity u10)

(define-map deliverer-availability
  { deliverer: principal }
  {
    available: bool,
    current-zone: (string-ascii 20),
    max-jobs: uint,
    active-jobs: uint,
    last-heartbeat: uint,
    total-hours-online: uint
  }
)

(define-map zone-workforce
  { zone-id: (string-ascii 20) }
  { active-count: uint, total-capacity: uint }
)

(define-map availability-history
  { deliverer: principal, session-id: uint }
  { zone: (string-ascii 20), start-block: uint, end-block: uint }
)

(define-data-var session-nonce uint u0)

(define-public (clock-in (zone-id (string-ascii 20)) (capacity uint))
  (let (
    (existing (map-get? deliverer-availability { deliverer: tx-sender }))
    (session-id (+ (var-get session-nonce) u1))
  )
    (asserts! (and (>= capacity min-capacity) (<= capacity max-capacity)) err-invalid-capacity)
    (asserts! (or (is-none existing) (not (get available (unwrap-panic existing)))) err-already-available)
    (map-set deliverer-availability
      { deliverer: tx-sender }
      {
        available: true,
        current-zone: zone-id,
        max-jobs: capacity,
        active-jobs: u0,
        last-heartbeat: stacks-block-height,
        total-hours-online: u0
      }
    )
    (update-zone-count zone-id capacity true)
    (var-set session-nonce session-id)
    (ok session-id)
  )
)

(define-public (clock-out)
  (let (
    (status (unwrap! (map-get? deliverer-availability { deliverer: tx-sender }) err-not-available))
    (session-id (var-get session-nonce))
  )
    (asserts! (get available status) err-not-available)
    (let (
      (hours-worked (- stacks-block-height (get last-heartbeat status)))
    )
      (map-set deliverer-availability
        { deliverer: tx-sender }
        (merge status { 
          available: false,
          total-hours-online: (+ (get total-hours-online status) hours-worked)
        })
      )
      (update-zone-count (get current-zone status) (get max-jobs status) false)
      (map-set availability-history
        { deliverer: tx-sender, session-id: session-id }
        { zone: (get current-zone status), start-block: (get last-heartbeat status), end-block: stacks-block-height }
      )
      (ok true)
    )
  )
)

(define-public (update-heartbeat)
  (let (
    (status (unwrap! (map-get? deliverer-availability { deliverer: tx-sender }) err-not-available))
  )
    (asserts! (get available status) err-not-available)
    (map-set deliverer-availability
      { deliverer: tx-sender }
      (merge status { last-heartbeat: stacks-block-height })
    )
    (ok true)
  )
)

(define-private (update-zone-count (zone-id (string-ascii 20)) (capacity uint) (adding bool))
  (let (
    (zone (default-to { active-count: u0, total-capacity: u0 } (map-get? zone-workforce { zone-id: zone-id })))
  )
    (map-set zone-workforce
      { zone-id: zone-id }
      {
        active-count: (if adding (+ (get active-count zone) u1) (- (get active-count zone) u1)),
        total-capacity: (if adding (+ (get total-capacity zone) capacity) (- (get total-capacity zone) capacity))
      }
    )
  )
)

(define-read-only (get-deliverer-status (deliverer principal))
  (map-get? deliverer-availability { deliverer: deliverer })
)

(define-read-only (get-zone-availability (zone-id (string-ascii 20)))
  (map-get? zone-workforce { zone-id: zone-id })
)

(define-read-only (is-deliverer-idle (deliverer principal))
  (match (map-get? deliverer-availability { deliverer: deliverer })
    status (and 
             (get available status)
             (> (- stacks-block-height (get last-heartbeat status)) max-idle-blocks))
    false
  )
)

(define-read-only (can-accept-job (deliverer principal))
  (match (map-get? deliverer-availability { deliverer: deliverer })
    status (and 
             (get available status)
             (< (get active-jobs status) (get max-jobs status)))
    false
  )
)
