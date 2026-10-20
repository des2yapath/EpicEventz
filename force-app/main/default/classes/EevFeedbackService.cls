/**
 * @description Hero Feature Service: AI Feedback Intelligence & Automated Recovery.
 * Automatically classifies sentiment & operational topic, and escalates negative feedback (<= 2 stars)
 * directly into high-priority Service Cases and immediate remediation Tasks.
 * @author EpicEventz Development Team
 */
public with sharing class EevFeedbackService {

    public class FeedbackSubmission {
        public Id eventProjectId;
        public Id reviewerContactId;
        public Integer rating;
        public String comments;
    }

    public class FeedbackResult {
        public Id feedbackId;
        public String sentiment;
        public String issueTag;
        public Boolean wasEscalated;
        public Id caseId;
        public Id taskId;
    }

    public static FeedbackResult processFeedback(FeedbackSubmission sub) {
        if (sub == null || sub.eventProjectId == null || sub.rating == null) {
            throw new IllegalArgumentException('Event Project and Rating are required.');
        }

        FeedbackResult res = new FeedbackResult();

        // 1. Heuristic AI Classification
        res.sentiment = classifySentiment(sub.rating, sub.comments);
        res.issueTag = classifyTopic(sub.comments);

        // 2. Persist Feedback Intelligence
        Feedback_Intelligence__c fb = new Feedback_Intelligence__c();
        fb.Event_Project__c = sub.eventProjectId;
        fb.Reviewer__c = sub.reviewerContactId;
        fb.Rating__c = sub.rating;
        fb.Comments__c = sub.comments;
        fb.AI_Sentiment__c = res.sentiment;
        fb.Actionable_Issue_Tag__c = res.issueTag;
        insert as user fb;
        res.feedbackId = fb.Id;

        // 3. Hero Escalation: 2 stars or negative sentiment becomes an automated Case and Task!
        if (sub.rating <= 2 || res.sentiment == 'Negative') {
            res.wasEscalated = true;

            // Auto-create Service Case
            Case c = new Case();
            c.Subject = 'Attendee Complaint: ' + res.issueTag + ' (Rating: ' + sub.rating + '/5)';
            c.Description = sub.comments;
            c.Priority = 'High';
            c.Status = 'New';
            c.Origin = 'Web';
            if (sub.reviewerContactId != null) {
                c.ContactId = sub.reviewerContactId;
            }
            insert as user c;
            res.caseId = c.Id;

            // Auto-create next-day recovery Task
            Task t = new Task();
            t.Subject = 'Immediate Outreach: Resolve attendee feedback on ' + res.issueTag;
            t.WhatId = c.Id;
            if (sub.reviewerContactId != null) {
                t.WhoId = sub.reviewerContactId;
            }
            t.ActivityDate = Date.today().addDays(1);
            t.Priority = 'High';
            t.Status = 'Not Started';
            t.Description = 'Review complaint and issue compensatory credit or resolution. Customer feedback: ' + sub.comments;
            insert as user t;
            res.taskId = t.Id;

            EevLogger.warn('EevFeedbackService', 'Escalated 2-star feedback to Case ' + c.Id + ' and Task ' + t.Id,
                           new List<Id>{ fb.Id, c.Id, t.Id }, 'Contact attendee within 24 hours to recover relationship.');
        } else {
            res.wasEscalated = false;
            EevLogger.info('EevFeedbackService', 'Recorded positive/neutral feedback ' + fb.Id, new List<Id>{ fb.Id });
        }

        return res;
    }

    public static String classifySentiment(Integer rating, String comments) {
        if (rating <= 2) return 'Negative';
        if (rating >= 4) return 'Positive';

        if (String.isNotBlank(comments)) {
            String lower = comments.toLowerCase();
            if (lower.contains('chaotic') || lower.contains('terrible') || lower.contains('awful') ||
                lower.contains('worst') || lower.contains('horrible') || lower.contains('disaster') ||
                lower.contains('waste') || lower.contains('never again')) {
                return 'Negative';
            }
            if (lower.contains('great') || lower.contains('amazing') || lower.contains('awesome') ||
                lower.contains('loved') || lower.contains('excellent') || lower.contains('fantastic')) {
                return 'Positive';
            }
        }
        return 'Neutral';
    }

    public static String classifyTopic(String comments) {
        if (String.isBlank(comments)) return 'General';
        String lower = comments.toLowerCase();

        if (lower.contains('queue') || lower.contains('line') || lower.contains('crowd') || lower.contains('wait')) {
            return 'Crowd & Queues';
        }
        if (lower.contains('sound') || lower.contains('mic') || lower.contains('audio') || lower.contains('screen') || lower.contains('speaker')) {
            return 'Audio & Visual';
        }
        if (lower.contains('food') || lower.contains('drink') || lower.contains('water') || lower.contains('catering')) {
            return 'Catering & Refreshments';
        }
        if (lower.contains('ticket') || lower.contains('price') || lower.contains('cost') || lower.contains('expensive') || lower.contains('refund')) {
            return 'Ticketing & Pricing';
        }
        if (lower.contains('parking') || lower.contains('seat') || lower.contains('bathroom') || lower.contains('venue')) {
            return 'Venue & Facilities';
        }
        return 'General Operations';
    }
}

