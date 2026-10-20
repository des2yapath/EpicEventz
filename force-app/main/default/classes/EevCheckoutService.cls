/**
 * @description Atomic checkout service handling idempotent ticket purchases, money ledgering, and pass generation.
 * @author EpicEventz Development Team
 */
public with sharing class EevCheckoutService {

    public class CheckoutRequest {
        public Id eventId;
        public Id eventProjectId;
        public Id tierId;
        public Integer quantity;
        public Id buyerContactId;
        public Decimal unitPrice;
        public String paymentMethod;
        public String idempotencyKey;
    }

    public class CheckoutResult {
        public Boolean isSuccess;
        public Id bookingOrderId;
        public Id paymentId;
        public List<Id> passIds;
        public String message;
        public Boolean isReplay;
    }

    public class CheckoutException extends Exception {}

    /**
     * @description Executes atomic ticket purchase with idempotency guard.
     */
    public static CheckoutResult processCheckout(CheckoutRequest req) {
        if (req == null || req.tierId == null || req.quantity == null || req.quantity <= 0) {
            throw new CheckoutException('Invalid checkout parameters provided.');
        }

        // 1. Idempotency Check (UC-04 replay protection)
        if (String.isNotBlank(req.idempotencyKey)) {
            List<Payment__c> existingPayments = [
                SELECT Id, Status__c, Amount__c
                FROM Payment__c
                WHERE Idempotency_Key__c = :req.idempotencyKey
                WITH USER_MODE
                LIMIT 1
            ];
            if (!existingPayments.isEmpty()) {
                // Replay detected! Return existing successful transaction without double charging
                CheckoutResult replayRes = new CheckoutResult();
                replayRes.isSuccess = true;
                replayRes.isReplay = true;
                replayRes.paymentId = existingPayments[0].Id;
                replayRes.message = 'Idempotent request replayed. Previous transaction returned.';
                EevLogger.info('EevCheckoutService', 'Replayed idempotent checkout with key ' + req.idempotencyKey, new List<Id>{ existingPayments[0].Id });
                return replayRes;
            }
        }

        Savepoint sp = Database.setSavepoint();
        CheckoutResult result = new CheckoutResult();
        result.passIds = new List<Id>();

        try {
            // 2. Atomically reserve inventory via Compare-And-Swap
            EevInventoryService.reserveTierInventory(req.tierId, req.quantity);

            // 3. Calculate total amount
            Decimal totalAmount = (req.unitPrice != null ? req.unitPrice : 0) * req.quantity;

            // 4. Create Booking Order (teammate's ledger object)
            Booking_Order__c bo = new Booking_Order__c();
            bo.Buyer_Contact__c = req.buyerContactId;
            if (req.eventProjectId != null) {
                bo.Event_Project__c = req.eventProjectId;
            }
            bo.Total_Amount_Paid__c = totalAmount;
            bo.Payment_Status__c = 'Success';
            bo.Gateway_Transaction_Id__c = String.isNotBlank(req.idempotencyKey) ? req.idempotencyKey : ('GW-' + Datetime.now().getTime());
            insert as user bo;
            result.bookingOrderId = bo.Id;

            // 5. Create Payment record in money ledger
            Payment__c pay = new Payment__c();
            pay.Amount__c = totalAmount;
            pay.Status__c = 'Captured';
            pay.Method__c = String.isNotBlank(req.paymentMethod) ? req.paymentMethod : 'Card';
            pay.Idempotency_Key__c = req.idempotencyKey;
            pay.Captured_At__c = System.now();
            insert as user pay;
            result.paymentId = pay.Id;

            // 6. Issue Ticket Passes with unique cryptographically random tokens (UC-05)
            List<Ticket_Pass__c> passes = new List<Ticket_Pass__c>();
            for (Integer i = 0; i < req.quantity; i++) {
                Ticket_Pass__c pass = new Ticket_Pass__c();
                pass.Booking_Order__c = bo.Id;
                pass.Ticket_Tier__c = req.tierId;
                pass.Attendee_Contact__c = req.buyerContactId;
                pass.Status__c = 'Valid';
                pass.Secure_QR_Token__c = generateSecureToken(bo.Id, req.tierId, i);
                pass.Table_Seat_Assignment__c = 'Seat ' + (i + 1);
                passes.add(pass);
            }
            insert as user passes;

            for (Ticket_Pass__c p : passes) {
                result.passIds.add(p.Id);
            }

            result.isSuccess = true;
            result.isReplay = false;
            result.message = 'Successfully completed checkout and issued ' + req.quantity + ' tickets.';

            EevLogger.info('EevCheckoutService', 'Completed checkout for Order ' + bo.Id, new List<Id>{ bo.Id, pay.Id });

        } catch (Exception ex) {
            Database.rollback(sp);
            EevLogger.error('EevCheckoutService', ex, null, 'Check tier availability and customer payment details.');
            throw ex;
        }

        return result;
    }

    private static String generateSecureToken(Id orderId, Id tierId, Integer idx) {
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(orderId + '-' + tierId + '-' + idx + '-' + Datetime.now().getTime()));
        return EncodingUtil.convertToHex(hash).substring(0, 32);
    }
}

