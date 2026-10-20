// 1. First scan
EevTicketService.CheckinResult res1 = EevCheckinController.processCheckin('PASS-TOKEN-DEMO-VIP-001');
System.debug('SCAN 1 isSuccess=' + res1.isSuccess + ', message=' + res1.message + ', attendee=' + res1.attendeeName);

// 2. Second scan (immediate double entry refusal)
EevTicketService.CheckinResult res2 = EevCheckinController.processCheckin('PASS-TOKEN-DEMO-VIP-001');
System.debug('SCAN 2 isSuccess=' + res2.isSuccess + ', message=' + res2.message);

