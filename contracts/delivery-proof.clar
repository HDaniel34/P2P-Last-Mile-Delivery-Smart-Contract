(define-constant err-proof-not-found (err u200))
(define-constant err-proof-already-exists (err u201))
(define-constant err-invalid-deliverer (err u202))
(define-constant err-dispute-window-closed (err u203))
(define-constant err-already-disputed (err u204))
(define-constant err-invalid-customer (err u205))

(define-constant dispute-window-blocks u144)

(define-map delivery-proofs
  { job-id: uint }
  {
    deliverer: principal,
    photo-hash: (buff 32),
    location-lat: uint,
    location-lng: uint,
    timestamp: uint,
    disputed: bool,
    verified: bool
  }
)

(define-map delivery-disputes
  { job-id: uint }
  {
    customer: principal,
    reason: (string-utf8 200),
    disputed-at: uint,
    resolved: bool
  }
)

(define-public (submit-delivery-proof 
    (job-id uint) 
    (photo-hash (buff 32)) 
    (location-lat uint) 
    (location-lng uint))
  (let (
    (existing-proof (map-get? delivery-proofs { job-id: job-id }))
  )
    (asserts! (is-none existing-proof) err-proof-already-exists)
    (map-set delivery-proofs
      { job-id: job-id }
      {
        deliverer: tx-sender,
        photo-hash: photo-hash,
        location-lat: location-lat,
        location-lng: location-lng,
        timestamp: stacks-block-height,
        disputed: false,
        verified: false
      }
    )
    (ok true)
  )
)

(define-public (verify-delivery (job-id uint))
  (let (
    (proof (unwrap! (map-get? delivery-proofs { job-id: job-id }) err-proof-not-found))
  )
    (map-set delivery-proofs
      { job-id: job-id }
      (merge proof { verified: true })
    )
    (ok true)
  )
)

(define-public (dispute-delivery (job-id uint) (reason (string-utf8 200)))
  (let (
    (proof (unwrap! (map-get? delivery-proofs { job-id: job-id }) err-proof-not-found))
    (current-block stacks-block-height)
    (dispute-deadline (+ (get timestamp proof) dispute-window-blocks))
  )
    (asserts! (< current-block dispute-deadline) err-dispute-window-closed)
    (asserts! (not (get disputed proof)) err-already-disputed)
    (map-set delivery-proofs
      { job-id: job-id }
      (merge proof { disputed: true })
    )
    (map-set delivery-disputes
      { job-id: job-id }
      {
        customer: tx-sender,
        reason: reason,
        disputed-at: current-block,
        resolved: false
      }
    )
    (ok true)
  )
)

(define-read-only (get-delivery-proof (job-id uint))
  (map-get? delivery-proofs { job-id: job-id })
)

(define-read-only (get-dispute-details (job-id uint))
  (map-get? delivery-disputes { job-id: job-id })
)

(define-read-only (is-proof-verified (job-id uint))
  (match (map-get? delivery-proofs { job-id: job-id })
    proof (get verified proof)
    false
  )
)

(define-read-only (can-dispute (job-id uint))
  (match (map-get? delivery-proofs { job-id: job-id })
    proof (and 
            (not (get disputed proof))
            (< stacks-block-height (+ (get timestamp proof) dispute-window-blocks)))
    false
  )
)