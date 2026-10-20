/**
 * @description Apex REST resource exposing idempotent ticket booking API for external integrations and Postman.
 * Endpoint: POST /services/apexrest/epiceventz/v1/orders
 * @author EpicEventz Development Team
 */
@RestResource(urlMapping='/epiceventz/v1/orders/*')
global with sharing class EevOrderRestResource {

    global class RestOrderRequest {
        public String tierId;
        public Integer quantity;
        public String buyerEmail;
        public String buyerLastName;
        public String idempotencyKey;
        public Decimal unitPrice;
    }

    global class RestOrderResponse {
        public Boolean success;
        public String message;
        public String bookingOrderId;
        public String paymentId;
        public List<String> passIds;
        public Boolean isReplay;
    }

    @HttpPost
    global static RestOrderResponse createOrder(RestOrderRequest request) {
        RestOrderResponse resp = new RestOrderResponse();
        resp.passIds = new List<String>();

        if (request == null || String.isBlank(request.tierId) || request.quantity == null || request.quantity <= 0) {
            resp.success = false;
            resp.message = 'Validation error: tierId and positive quantity are required.';
            RestContext.response.statusCode = 400;
            return resp;
        }

        try {
            // Find or create buyer contact
            Contact buyer = null;
            if (String.isNotBlank(request.buyerEmail)) {
                List<Contact> contacts = [
                    SELECT Id FROM Contact 
                    WHERE Email = :request.buyerEmail.trim() 
                    WITH USER_MODE 
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    buyer = contacts[0];
                } else {
                    buyer = new Contact();
                    buyer.LastName = String.isNotBlank(request.buyerLastName) ? request.buyerLastName : 'Attendee';
                    buyer.Email = request.buyerEmail.trim();
                    insert as user buyer;
                }
            }

            Id tierId = Id.valueOf(request.tierId);
            Ticket_Tier__c tier = [
                SELECT Id, Event_Project__c, Price__c 
                FROM Ticket_Tier__c 
                WHERE Id = :tierId 
                WITH USER_MODE 
                LIMIT 1
            ];

            EevCheckoutService.CheckoutRequest chkReq = new EevCheckoutService.CheckoutRequest();
            chkReq.tierId = tierId;
            chkReq.eventProjectId = tier.Event_Project__c;
            chkReq.quantity = request.quantity;
            chkReq.buyerContactId = buyer != null ? buyer.Id : null;
            chkReq.unitPrice = request.unitPrice != null ? request.unitPrice : (tier.Price__c != null ? tier.Price__c : 100.00);
            chkReq.idempotencyKey = request.idempotencyKey;
            chkReq.paymentMethod = 'Card';

            EevCheckoutService.CheckoutResult chkRes = EevCheckoutService.processCheckout(chkReq);

            resp.success = chkRes.isSuccess;
            resp.message = chkRes.message;
            resp.bookingOrderId = (String)chkRes.bookingOrderId;
            resp.paymentId = (String)chkRes.paymentId;
            resp.isReplay = chkRes.isReplay;
            if (chkRes.passIds != null) {
                for (Id pid : chkRes.passIds) {
                    resp.passIds.add((String)pid);
                }
            }
            RestContext.response.statusCode = 200;

        } catch (Exception ex) {
            resp.success = false;
            resp.message = 'Booking failed: ' + ex.getMessage();
            RestContext.response.statusCode = 500;
            EevLogger.error('EevOrderRestResource', ex, null, 'Verify request body and tier configuration.');
        }

        return resp;
    }
}

