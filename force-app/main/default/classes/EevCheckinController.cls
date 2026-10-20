/**
 * @description Lightning Web Component controller for the checkinConsole door scanning interface.
 * @author EpicEventz Development Team
 */
public with sharing class EevCheckinController {

    @AuraEnabled
    public static EevTicketService.CheckinResult processCheckin(String token) {
        try {
            return EevTicketService.checkin(token);
        } catch (Exception ex) {
            EevTicketService.CheckinResult errRes = new EevTicketService.CheckinResult();
            errRes.isSuccess = false;
            errRes.message = 'System Error during check-in: ' + ex.getMessage();
            return errRes;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PassSummary> getRecentPasses() {
        List<Ticket_Pass__c> passes = [
            SELECT Id, Name, Status__c, Check_In_Timestamp__c, Table_Seat_Assignment__c,
                   Attendee_Contact__r.Name, Ticket_Tier__r.Name, Secure_QR_Token__c
            FROM Ticket_Pass__c
            WITH USER_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];

        List<PassSummary> summaries = new List<PassSummary>();
        for (Ticket_Pass__c p : passes) {
            PassSummary s = new PassSummary();
            s.id = p.Id;
            s.passNumber = p.Name;
            s.attendeeName = p.Attendee_Contact__r != null ? p.Attendee_Contact__r.Name : 'Guest';
            s.tierName = p.Ticket_Tier__r != null ? p.Ticket_Tier__r.Name : 'General';
            s.seatAssignment = p.Table_Seat_Assignment__c;
            s.status = p.Status__c;
            s.token = p.Secure_QR_Token__c;
            s.checkInTime = p.Check_In_Timestamp__c;
            summaries.add(s);
        }
        return summaries;
    }

    public class PassSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String passNumber;
        @AuraEnabled public String attendeeName;
        @AuraEnabled public String tierName;
        @AuraEnabled public String seatAssignment;
        @AuraEnabled public String status;
        @AuraEnabled public String token;
        @AuraEnabled public Datetime checkInTime;
    }
}

