Ticket_Tier__c tier = [SELECT Id FROM Ticket_Tier__c LIMIT 1];
EevOrderRestResource.RestOrderRequest body = new EevOrderRestResource.RestOrderRequest();
body.tierId = (String)tier.Id;
body.quantity = 1;
body.buyerEmail = 'external.buyer@example.com';
body.buyerLastName = 'ExternalBuyer';
body.idempotencyKey = 'REST-IDEMP-TEST-' + Crypto.getRandomInteger();
body.unitPrice = 1500.00;

RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
req.requestURI = '/services/apexrest/epiceventz/v1/orders';
req.httpMethod = 'POST';
RestContext.request = req;
RestContext.response = res;

EevOrderRestResource.RestOrderResponse apiRes = EevOrderRestResource.createOrder(body);
System.debug('***DEBUG_RESULT*** success=' + apiRes.success + ', msg=' + apiRes.message);

