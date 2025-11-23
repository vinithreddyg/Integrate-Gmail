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
    public static List<EmailResponse> sendEmailInvocable(List<EmailRequest> requests) {
        List<EmailResponse> results = new List<EmailResponse>();
        if (requests == null || requests.isEmpty()) {
            EmailResponse r = new EmailResponse();
            r.success = false;
            r.errorMessage = 'No requests provided';
            results.add(r);
            return results;
        }
        for (EmailRequest req : requests) {
            results.add(sendEmailSync(req));
        }
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
    public static System.Id enqueueSend(EmailRequest req) {
        return System.enqueueJob(new GmailSendQueueable(req));
    }

    /**
     * Core sync sender. Returns EmailResponse indicating success/failure.
     */
    public static EmailResponse sendEmailSync(EmailRequest req) {
        EmailResponse resObj = new EmailResponse();
        // Validate required fields
        if (req == null) {
            resObj.success = false;
            resObj.errorMessage = 'Request is null';
            return resObj;
        }
        if (String.isBlank(req.toAddress)) {
            resObj.success = false;
            resObj.errorMessage = 'toAddress is required';
            return resObj;
        }
        if (String.isBlank(req.subject)) {
            resObj.success = false;
            resObj.errorMessage = 'subject is required';
            return resObj;
        }
        if (String.isBlank(req.bodyText)) {
            resObj.success = false;
            resObj.errorMessage = 'bodyText is required';
            return resObj;
        }

        try {
            // Build raw RFC 2822 message
            String fromAddr = String.isBlank(req.fromAddress) ? null : req.fromAddress;
            String rawMessage = buildRfc2822(fromAddr, req.toAddress, req.subject, req.bodyText);

            // Base64url encode (Gmail requires base64url, not standard base64)
            String encoded = base64UrlEncode(Blob.valueOf(rawMessage));

            // Prepare HTTP callout
            HttpRequest httpReq = new HttpRequest();
            httpReq.setMethod('POST');
            httpReq.setEndpoint('callout:Google_Gmail_NC/gmail/v1/users/me/messages/send');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(new Map<String, Object>{ 'raw' => encoded }));

            Http http = new Http();
            HttpResponse httpRes = http.send(httpReq);

            if (httpRes.getStatusCode() == 200) {
                // Success - parse id
                Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                resObj.success = true;
                resObj.messageId = (String) payload.get('id');
                return resObj;
            }

            // Non-200
            resObj.success = false;
            resObj.errorMessage = 'HTTP ' + httpRes.getStatusCode() + ': ' + httpRes.getStatus();
            return resObj;

        } catch (Exception ex) {
            resObj.success = false;
            resObj.errorMessage = 'Exception: ' + ex.getMessage();
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
