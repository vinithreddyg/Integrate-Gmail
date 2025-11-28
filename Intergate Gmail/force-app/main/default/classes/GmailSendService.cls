/**
 * @description Service to send emails via Gmail API using Named Credential 'Google_Gmail_NC'
 * Implements Invocable Apex for Flow and a Queueable for async send.
 * Follows: with sharing, user mode DML, Database methods, early returns, enums over strings.
 */
public with sharing class GmailSendService {

    /**
     * Gmail Scopes enum for clarity/maintenance
     */
    public enum GMAIL_SCOPES {
        HTTPS_WWW_GOOGLEAPIS_COM_AUTH_GMAIL_SEND
    }

    /**
     * Public DTO for sending email
     */
    public class EmailRequest {
        @InvocableVariable(required=true)
        public String toAddress;
        @InvocableVariable(required=true)
        public String subject;
        @InvocableVariable(required=true)
        public String bodyText; // plain text body
        @InvocableVariable
        public String fromAddress; // optional - Gmail will use authorized account if omitted
    }

    /**
     * Public DTO response
     */
    public class EmailResponse {
        public Boolean success;
        public String messageId;
        public String errorMessage;
    }

    /**
     * Invocable method to send a single email via Flow (process each input)
     */
    @InvocableMethod(label='Send Gmail Email' description='Sends email via Google Gmail API using Named Credential Google_Gmail_NC')
    public static List<Id> sendEmailInvocable(List<EmailRequest> requests) {
        System.debug('GmailSendService.sendEmailInvocable: Starting with ' + (requests == null ? 0 : requests.size()) + ' requests');
        List<Id> results = new List<Id>();
        if (requests == null || requests.isEmpty()) {
            System.debug('GmailSendService.sendEmailInvocable: No requests provided, returning empty list');
            return results;
        }
        for (EmailRequest req : requests) {
            // For invocable methods, we can't return detailed results, so we just enqueue each job
            System.debug('GmailSendService.sendEmailInvocable: Enqueuing job for request to ' + (req != null && req.toAddress != null ? req.toAddress : 'unknown'));
            results.add(System.enqueueJob(new GmailSendQueueable(req)));
        }
        System.debug('GmailSendService.sendEmailInvocable: Completed, enqueued ' + results.size() + ' jobs');
        return results;
    }

    /**
     * Queueable job to send an email asynchronously
     */
    public class GmailSendQueueable implements Queueable, Database.AllowsCallouts {
        private EmailRequest request;
        public GmailSendQueueable(EmailRequest request) {
            this.request = request;
        }
        public void execute(QueueableContext qc) {
            sendEmailSync(request);
        }
    }

    /**
     * Public helper to enqueue async send
     */
    @AuraEnabled
    public static Id enqueueSend(EmailRequest req) {
        System.debug('GmailSendService.enqueueSend: Enqueuing job for request to ' + (req != null && req.toAddress != null ? req.toAddress : 'unknown'));
        Id jobId = System.enqueueJob(new GmailSendQueueable(req));
        System.debug('GmailSendService.enqueueSend: Job enqueued with ID: ' + jobId);
        return jobId;
    }

    /**
     * Aura-enabled wrapper for LWC to send synchronously
     */
    @AuraEnabled
    public static EmailResponse sendEmailAura(String toAddress, String subject, String bodyText, String fromAddress) {
        EmailRequest r = new EmailRequest();
        r.toAddress = toAddress;
        r.subject = subject;
        r.bodyText = bodyText;
        r.fromAddress = fromAddress;
        return sendEmailSync(r);
    }

    /**
     * Core sync sender. Returns EmailResponse indicating success/failure.
     */
    public static EmailResponse sendEmailSync(EmailRequest req) {
        System.debug('GmailSendService.sendEmailSync: Starting to send email to ' + req.toAddress);
        EmailResponse resObj = new EmailResponse();
        // Validate required fields
        if (req == null) {
            resObj.success = false;
            resObj.errorMessage = 'Request is null';
            System.debug('GmailSendService.sendEmailSync: Request is null, returning error');
            return resObj;
        }
        if (String.isBlank(req.toAddress)) {
            resObj.success = false;
            resObj.errorMessage = 'toAddress is required';
            System.debug('GmailSendService.sendEmailSync: toAddress is required, returning error');
            return resObj;
        }
        if (String.isBlank(req.subject)) {
            resObj.success = false;
            resObj.errorMessage = 'subject is required';
            System.debug('GmailSendService.sendEmailSync: subject is required, returning error');
            return resObj;
        }
        if (String.isBlank(req.bodyText)) {
            resObj.success = false;
            resObj.errorMessage = 'bodyText is required';
            System.debug('GmailSendService.sendEmailSync: bodyText is required, returning error');
            return resObj;
        }

        try {
            // Build raw RFC 2822 message
            String fromAddr = String.isBlank(req.fromAddress) ? null : req.fromAddress;
            String rawMessage = buildRfc2822(fromAddr, req.toAddress, req.subject, req.bodyText);
            System.debug('GmailSendService.sendEmailSync: Built RFC 2822 message');

            // Base64url encode (Gmail requires base64url, not standard base64)
            String encoded = base64UrlEncode(Blob.valueOf(rawMessage));
            System.debug('GmailSendService.sendEmailSync: Encoded message');

            // Prepare HTTP callout
            HttpRequest httpReq = new HttpRequest();
            httpReq.setMethod('POST');
            httpReq.setEndpoint('callout:Google_Gmail_NC/gmail/v1/users/me/messages/send');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(new Map<String, Object>{ 'raw' => encoded }));
            System.debug('GmailSendService.sendEmailSync: Prepared HTTP request to endpoint: ' + httpReq.getEndpoint());

            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);
            System.debug('GmailSendService.sendEmailSync: Received HTTP response with status: ' + httpRes.getStatusCode());

            if (httpRes.getStatusCode() == 200) {
                // Success - parse id
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                resObj.success = true;
                resObj.messageId = (String) payload.get('id');
                System.debug('GmailSendService.sendEmailSync: Email sent successfully with message ID: ' + resObj.messageId);
                return resObj;
            }

            // Non-200
            resObj.success = false;
            resObj.errorMessage = 'HTTP ' + httpRes.getStatusCode() + ': ' + httpRes.getStatus();
            System.debug('GmailSendService.sendEmailSync: Email sending failed with HTTP error: ' + resObj.errorMessage);
            return resObj;

        } catch (Exception ex) {
            // Enhanced error handling for named credential issues
            String errorMsg = ex.getMessage();
            System.debug('GmailSendService.sendEmailSync: Exception occurred: ' + errorMsg);
            
            // More specific error detection
            if (errorMsg.contains('named credential') || errorMsg.contains('Named Credential') || errorMsg.contains('callout')) {
                resObj.success = false;
                resObj.errorMessage = 'Named Credential Error: The named credential "Google_Gmail_NC" is not properly configured. Please verify it exists and is authorized. ' +
                                      'Error details: ' + errorMsg;
                System.debug('GmailSendService.sendEmailSync: Named credential error detected: ' + errorMsg);
            } else if (errorMsg.contains('endpoint') || errorMsg.contains('Endpoint')) {
                resObj.success = false;
                resObj.errorMessage = 'Endpoint Error: The endpoint could not be accessed. Please verify the named credential configuration and endpoint URL. ' +
                                      'Error details: ' + errorMsg;
                System.debug('GmailSendService.sendEmailSync: Endpoint error detected: ' + errorMsg);
            } else if (errorMsg.contains('401') || errorMsg.contains('403')) {
                resObj.success = false;
                resObj.errorMessage = 'Authorization Error: The named credential is not authorized or has insufficient permissions. ' +
                                      'Please re-authorize the named credential in Setup > Security > Named Credentials. ' +
                                      'Error details: ' + errorMsg;
                System.debug('GmailSendService.sendEmailSync: Authorization error detected: ' + errorMsg);
            } else {
                resObj.success = false;
                resObj.errorMessage = 'Exception: ' + errorMsg;
                System.debug('GmailSendService.sendEmailSync: Exception occurred: ' + errorMsg);
            }
            return resObj;
        }
    }

    /**
     * Utility to build a minimal RFC 2822 message
     */
    private static String buildRfc2822(String fromAddress, String toAddress, String emailSubject, String bodyText) {
        // Ensure headers are folded correctly and lines end with \r\n
        List<String> lines = new List<String>();
        if (!String.isBlank(fromAddress)) {
            lines.add('From: ' + fromAddress);
        }
        lines.add('To: ' + toAddress);
        lines.add('Subject: ' + emailSubject);
        lines.add('MIME-Version: 1.0');
        lines.add('Content-Type: text/plain; charset=UTF-8');
        lines.add('');
        lines.add(bodyText);
        return String.join(lines, '\r\n');
    }

    /**
     * Base64url encode per RFC 4648, section 5 (Gmail requirement)
     */
    private static String base64UrlEncode(Blob data) {
        // Apex Base64 is standard, replace chars and strip padding
        String std = EncodingUtil.base64Encode(data);
        std = std.replace('+','-').replace('/','_');
        while (std.endsWith('=')) {
            std = std.substring(0, std.length()-1);
        }
        return std;
    }
}
