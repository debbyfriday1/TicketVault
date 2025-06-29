;; TicketVault - Event ticket management and trading platform

(define-non-fungible-token event-ticket uint)

;; Storage
(define-map ticket-registry uint {organizer: principal, event-name: (string-utf8 64), venue-details: (string-utf8 256), ticket-info: (string-utf8 256), resale-price: uint})
(define-data-var ticket-id-counter uint u0)

;; Error codes
(define-constant err-organizer-only (err u500))
(define-constant err-ticket-not-found (err u501))
(define-constant err-purchase-failed (err u502))
(define-constant err-invalid-event-name (err u503))
(define-constant err-invalid-venue (err u504))
(define-constant err-invalid-info (err u505))
(define-constant err-invalid-price (err u506))
(define-constant err-invalid-ticket-id (err u507))

;; Create event ticket
(define-public (create-ticket (event-name (string-utf8 64)) (venue-details (string-utf8 256)) (ticket-info (string-utf8 256)) (resale-price uint))
  (begin
    ;; Validate ticket parameters
    (asserts! (> (len event-name) u0) err-invalid-event-name)
    (asserts! (> (len venue-details) u0) err-invalid-venue)
    (asserts! (> (len ticket-info) u0) err-invalid-info)
    (asserts! (> resale-price u0) err-invalid-price)
    
    (let
      ((ticket-id (var-get ticket-id-counter))
       (organizer tx-sender))
      
      ;; Mint ticket NFT
      (try! (nft-mint? event-ticket ticket-id organizer))
      
      ;; Register ticket details
      (map-set ticket-registry ticket-id {organizer: organizer, event-name: event-name, venue-details: venue-details, ticket-info: ticket-info, resale-price: resale-price})
      
      ;; Increment ticket counter
      (var-set ticket-id-counter (+ ticket-id u1))
      
      (ok ticket-id))))

;; Purchase ticket
(define-public (purchase-ticket (ticket-id uint))
  (begin
    ;; Validate ticket ID
    (asserts! (< ticket-id (var-get ticket-id-counter)) err-invalid-ticket-id)
    
    (let
      ((ticket-data (unwrap! (map-get? ticket-registry ticket-id) err-ticket-not-found))
       (price (get resale-price ticket-data))
       (organizer (get organizer ticket-data))
       (current-owner (unwrap! (nft-get-owner? event-ticket ticket-id) err-ticket-not-found)))
      
      ;; Check buyer has sufficient funds
      (asserts! (>= (stx-get-balance tx-sender) price) err-purchase-failed)
      
      ;; Transfer payment to organizer
      (try! (stx-transfer? price tx-sender organizer))
      
      ;; Transfer ticket to buyer
      (try! (nft-transfer? event-ticket ticket-id current-owner tx-sender))
      
      (ok true))))

;; Get ticket details
(define-read-only (get-ticket-details (ticket-id uint))
  (map-get? ticket-registry ticket-id))

;; Check ticket ownership
(define-read-only (owns-ticket (ticket-id uint) (attendee principal))
  (is-eq (some attendee) (nft-get-owner? event-ticket ticket-id)))

;; Get ticket owner
(define-read-only (get-ticket-owner (ticket-id uint))
  (nft-get-owner? event-ticket ticket-id))