(define-constant err-zone-not-found (err u400))
(define-constant err-invalid-multiplier (err u401))
(define-constant err-invalid-zone (err u402))

(define-constant base-multiplier u100)
(define-constant min-multiplier u50)
(define-constant max-multiplier u300)
(define-constant surge-block-window u72)

(define-map delivery-zones
  { zone-id: (string-ascii 20) }
  {
    active-jobs: uint,
    active-deliverers: uint,
    completed-in-window: uint,
    current-multiplier: uint,
    last-updated: uint
  }
)

(define-map zone-history
  { zone-id: (string-ascii 20), timestamp: uint }
  { multiplier: uint, job-count: uint }
)

(define-public (register-zone (zone-id (string-ascii 20)))
  (begin
    (asserts! (is-none (map-get? delivery-zones { zone-id: zone-id })) err-invalid-zone)
    (map-set delivery-zones
      { zone-id: zone-id }
      {
        active-jobs: u0,
        active-deliverers: u0,
        completed-in-window: u0,
        current-multiplier: base-multiplier,
        last-updated: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (update-zone-activity (zone-id (string-ascii 20)) (job-created bool) (deliverer-active bool))
  (let (
    (zone (unwrap! (map-get? delivery-zones { zone-id: zone-id }) err-zone-not-found))
    (new-jobs (if job-created (+ (get active-jobs zone) u1) (get active-jobs zone)))
    (new-deliverers (if deliverer-active (+ (get active-deliverers zone) u1) (get active-deliverers zone)))
    (new-multiplier (calculate-surge-multiplier new-jobs new-deliverers))
  )
    (map-set delivery-zones
      { zone-id: zone-id }
      (merge zone {
        active-jobs: new-jobs,
        active-deliverers: new-deliverers,
        current-multiplier: new-multiplier,
        last-updated: stacks-block-height
      })
    )
    (ok new-multiplier)
  )
)

(define-public (complete-zone-delivery (zone-id (string-ascii 20)))
  (let (
    (zone (unwrap! (map-get? delivery-zones { zone-id: zone-id }) err-zone-not-found))
    (new-jobs (if (> (get active-jobs zone) u0) (- (get active-jobs zone) u1) u0))
    (new-completed (+ (get completed-in-window zone) u1))
  )
    (map-set delivery-zones
      { zone-id: zone-id }
      (merge zone {
        active-jobs: new-jobs,
        completed-in-window: new-completed
      })
    )
    (ok true)
  )
)

(define-private (calculate-surge-multiplier (active-jobs uint) (active-deliverers uint))
  (let (
    (demand-ratio (if (> active-deliverers u0) (/ (* active-jobs u100) active-deliverers) u200))
    (surge-multiplier (if (> demand-ratio u150) (+ base-multiplier u50)
                        (if (> demand-ratio u100) (+ base-multiplier u25)
                          (if (< demand-ratio u50) (- base-multiplier u25)
                            base-multiplier))))
  )
    (if (> surge-multiplier max-multiplier) max-multiplier
      (if (< surge-multiplier min-multiplier) min-multiplier surge-multiplier))
  )
)

(define-read-only (get-zone-surge (zone-id (string-ascii 20)))
  (map-get? delivery-zones { zone-id: zone-id })
)

(define-read-only (calculate-adjusted-reward (base-reward uint) (zone-id (string-ascii 20)))
  (match (map-get? delivery-zones { zone-id: zone-id })
    zone (ok (/ (* base-reward (get current-multiplier zone)) base-multiplier))
    err-zone-not-found
  )
)

(define-read-only (is-surge-active (zone-id (string-ascii 20)))
  (match (map-get? delivery-zones { zone-id: zone-id })
    zone (> (get current-multiplier zone) base-multiplier)
    false
  )
)
